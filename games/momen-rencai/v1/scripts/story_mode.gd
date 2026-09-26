extends Node
## 剧情模式控制器：把 Story 的节点翻译成游戏里的表现（对白 / 选项 / 战斗 / 账本 / 死亡 / 收束 / 结局）

const LEVELS := [1, 2, 4, 6, 7, 9, 10]   # 各章敌人等级

var m: Node2D
var ui: Control
var pending_card := {}
var bctx := {}
var ledger_ctx := {}
var sacrifice_btn: Button
var cultivate_req := -1


func setup(main: Node2D, story_ui: Control) -> void:
	m = main
	ui = story_ui
	Story.node_entered.connect(_on_node)
	Story.chapter_started.connect(func(ch): pending_card = ch)
	Story.memory_gained.connect(func(_id, t): ui.toast_memory(t))
	sacrifice_btn = m._button("舍身（故意战死）", sacrifice, m.INK, m.BLOOD)
	sacrifice_btn.position = Vector2(150, 262)
	sacrifice_btn.custom_minimum_size = Vector2(112, 20)
	sacrifice_btn.visible = false
	m.ui.add_child(sacrifice_btn)


func active() -> bool:
	return m.mode == "story"


# ───────────── 入口 ─────────────

func begin_new(keep_memories: bool) -> void:
	_enter_mode()
	Story.start_new(keep_memories)


func resume() -> void:
	_enter_mode()
	var n := Story.node()
	if n.is_empty():
		Story.start_new(true)
	else:
		_on_node(n)


func start_chapter(i: int) -> void:
	_enter_mode()
	pending_card = {}
	Story.start_chapter(i)


func _enter_mode() -> void:
	m._close_overlay()
	m.mode = "story"
	m.story_layout(true)
	cultivate_req = -1


# ───────────── 节点分发 ─────────────

func _on_node(n: Dictionary) -> void:
	GS.save_game()
	if not active():
		return
	if not pending_card.is_empty():
		var ch := pending_card
		pending_card = {}
		m.battle.set_stage([])
		ui.show_chapter_card(ch, Story.chapter_index(ch), func(): _on_node(n))
		return
	m.caption("")
	m.display = {"mem_n": Story.st.mem.size(), "mem_max": 7}
	m.ui_refresh = 0.0
	match n.type:
		"scene":
			m.battle.set_stage(_speakers(n.lines))
			ui.show_lines(n.lines, Story.advance, _header())
			_ai_improv(n)
		"choice":
			if n.options.size() > 0 and m.battle.units.size() <= 1:
				m.battle.set_stage([])
			ui.show_choices(n.prompt, Story.options(), _pick, float(n.get("timer", 0)), Story.timeout)
		"battle":
			if n.has("lines"):
				ui.show_lines(n.lines, func(): _start_battle(n), _header())
			else:
				_start_battle(n)
		"ledger":
			m.battle.set_stage([])
			ui.show_lines(n.lines, func(): _start_ledger(n), _header())
		"death":
			m.flash(Color(0.9, 0.15, 0.2, 0.6), 0.6)
			m.shake_screen(3, 0.4)
			m.battle.set_stage(_speakers(n.lines))
			m.battle.hero.alive = false
			m.battle.hero.rot = PI / 2
			ui.show_lines(n.lines + [["旁白", "你死了。带着这一幕，回到本章开头。"]], Story.advance, "死亡")
		"converge":
			m.battle.set_stage([])
			ui.show_lines(n.lines, _chapter_done, "收束")
		"ending":
			_show_ending(n)


func _header() -> String:
	var idx := Story.chapter_index()
	return ["第一章", "第二章", "第三章", "第四章", "第五章", "第六章", "第七章"][idx] + " · " + Story.chapter().title


func _speakers(lines: Array) -> Array:
	var out := []
	for ln in lines:
		if not out.has(ln[0]):
			out.append(ln[0])
	return out


func _pick(i: int) -> void:
	if not Story.choose(i):
		m._toast("还不能选：缺少记忆或条件", m.BLOOD)


## Agent 即兴（只在有 Haiku key / Claude 账号驱动时）：厉寒在剧情场景里额外说一句，不改变剧情走向
func _ai_improv(n: Dictionary) -> void:
	if not (Agent.has_key() or Agent.account_ai_enabled()):
		return
	if not _speakers(n.lines).has("厉寒"):
		return
	var res: Dictionary = await Agent.decide("senior", "story_scene", {"scene": n.title, "your_state": Story.flag("senior"), "rel": Story.flag("senior_rel"), "lines_just_said": n.lines})
	for c in res.calls:
		if c.name == "say" and active() and Story.node().get("id") == n.id:
			m.say("actor:厉寒", str(c.input.get("text", "")).substr(0, 20))


# ───────────── 战斗 ─────────────

func _start_battle(n: Dictionary) -> void:
	var b: Dictionary = n.battle
	var bt = m.battle
	var lvl: int = LEVELS[Story.chapter_index()]
	bt.revive_hero()
	bt.hero.pos = Vector2(50, 62)
	bt.scripted = true
	bt.allow_pills = false
	bt.refresh_hero_stats()
	bt.hero.hp = bt.hero.max_hp
	if b.get("scripted_death", false):
		bt.spawn_scripted_foe(110, Vector2(130, 62), 50.0)
		get_tree().create_timer(1.2).timeout.connect(func():
			bt.kill_hero_scripted()
			bt.hero.alive = false
			bt.hero.rot = PI / 2
			m.flash(Color(1, 1, 1, 0.55), 0.2)
			m.shake_screen(3, 0.4)
			get_tree().create_timer(1.2).timeout.connect(func(): Story.battle_result(false)))
		return
	bctx = {"node": n.id, "waves_left": int(b.get("waves", 1)), "level": lvl, "count": int(b.get("count", -1)), "wave_i": 0, "done": false}
	if b.get("senior", "") == "ally":
		var s = bt.spawn_senior(Vector2(24, 70))
		s.tactic = "assist"
		if Agent.has_key() or Agent.account_ai_enabled():
			_senior_bark()
	if b.has("escort"):
		var e = bt.spawn_ally(b.escort, Vector2(30, 50))
		e.max_hp *= 0.5
		e.hp = e.max_hp
		e.atk *= 0.3
	if b.get("allies_from_flags", false):
		var slots := [Vector2(24, 50), Vector2(24, 76), Vector2(40, 40), Vector2(40, 86)]
		var names: Array = Story.allies()
		for i in names.size():
			bt.spawn_ally(names[i], slots[i % 4])
		if names.size() > 0:
			m._toast("站在你身边：" + "、".join(names), m.JADE)
	sacrifice_btn.visible = true
	if b.has("boss"):
		var hp_mul := 1.0
		var atk_mul := 1.0
		var seed: String = Story.flag("seed")
		if b.boss == "master":
			match seed:
				"turned": hp_mul = 0.5
				"sealed": atk_mul = 0.5
				"merged": bt.hero.atk *= 2.0
		bctx.waves_left = 0
		bt.spawn_boss(b.boss, lvl, hp_mul, atk_mul)
	else:
		_next_wave()


func _senior_bark() -> void:
	var res: Dictionary = await Agent.decide("senior", "wave_start", {"wave": 1, "story_state": Story.flag("senior"), "rel": Story.flag("senior_rel")})
	for c in res.calls:
		if c.name == "say" and active():
			m.say("senior", str(c.input.get("text", "")).substr(0, 20))


func _next_wave() -> void:
	bctx.waves_left -= 1
	bctx.wave_i += 1
	m.battle.start_wave(bctx.level + bctx.wave_i - 1, bctx.count)
	m.caption("第 %d 波" % bctx.wave_i if int(Story.node().battle.get("waves", 1)) > 1 else "", "", m.WHITE)
	get_tree().create_timer(1.0).timeout.connect(func(): if active(): m.caption(""))


func on_wave_cleared() -> void:
	if bctx.is_empty() or bctx.done:
		return
	if bctx.waves_left > 0:
		get_tree().create_timer(0.6).timeout.connect(_next_wave)
	else:
		_battle_done(true)


func on_hero_died() -> void:
	if bctx.is_empty() or bctx.done:
		return
	_battle_done(false)


func sacrifice() -> void:
	m.battle.sacrifice()


func _battle_done(win: bool) -> void:
	bctx.done = true
	sacrifice_btn.visible = false
	m.battle.running = false
	get_tree().create_timer(0.9).timeout.connect(func():
		m.battle.clear_enemies()
		bctx = {}
		Story.battle_result(win))


# ───────────── 账本（Paperclips）─────────────

func _start_ledger(n: Dictionary) -> void:
	ledger_ctx = {"taps": 0, "left": float(n.get("seconds", 12)), "total": float(n.get("seconds", 12)), "log": ["魔种：吐纳吧。每一次，我都会记下。"]}
	m.ledger.show_close = false
	m.ledger.visible = true
	_ledger_refresh()


func on_tuna() -> void:
	if ledger_ctx.is_empty():
		return
	ledger_ctx.taps += 1
	var lines := ["你吐纳了一次。", "你又吐纳了一次。", "魔种长大了一点。", "外门弟子开始注意到你。", "魔种开始自我复制。"]
	ledger_ctx.log.append(lines[min(ledger_ctx.taps - 1, lines.size() - 1)] if ledger_ctx.taps <= 5 else "你吐纳了第 %d 次。" % ledger_ctx.taps)
	_ledger_refresh(true)


func _process(delta: float) -> void:
	if ledger_ctx.is_empty():
		return
	ledger_ctx.left -= delta
	_ledger_refresh()
	if ledger_ctx.left <= 0:
		var taps: int = ledger_ctx.taps
		ledger_ctx = {}
		m.ledger.visible = false
		m.ledger.show_close = true
		Story.ledger_result(taps)


func _ledger_refresh(pressed := false) -> void:
	var t: int = ledger_ctx.taps
	var feed := t * 3
	var phases := []
	var names := ["外门", "魔门", "修仙界", "三千世界"]
	for i in 4:
		phases.append([names[i], clampf((feed - i * 25) / 25.0, 0, 1)])
	m.ledger.set_state({"qi": float(t), "rate": float(t) * 1.06, "seeds": pow(2.0, t / 3.0) if t > 0 else 0.0,
		"rows": [["魔种喂养", "%d" % feed]], "phases": phases, "log": ledger_ctx.log.slice(max(0, ledger_ctx.log.size() - 6)),
		"pressed": pressed, "cursor": t == 0, "caption": "吐纳，或者不。\n还剩 %d 秒" % ceil(max(0.0, ledger_ctx.left))})


# ───────────── 章末 / 修炼 / 结局 ─────────────

func _chapter_done() -> void:
	var ch := Story.chapter()
	GS.add_qi(GS.break_cost() * 0.6)
	ui.show_flowchart(ch, Story.chapter_index(ch), _after_flow)


func _after_flow() -> void:
	var n := Story.node()
	var next_ch: Dictionary = Story.chapter_of.get(n.next, {})
	var req: int = int(next_ch.get("realm_req", 0))
	if GS.realm < req:
		cultivate_req = req
		m.start_cultivate(req, next_ch)
	else:
		Story.next_chapter()


func continue_after_cultivate() -> void:
	if GS.realm < cultivate_req:
		return
	cultivate_req = -1
	_enter_mode()
	Story.next_chapter()


func _show_ending(n: Dictionary) -> void:
	m.battle.set_stage([])
	GS.save_game()
	var ch := Story.chapter()
	ui.show_ending(n,
		func(): ui.show_flowchart(ch, 6, func(): _show_ending(n), "返回结局"),
		func(): begin_new(true),
		func(): m.show_title())
