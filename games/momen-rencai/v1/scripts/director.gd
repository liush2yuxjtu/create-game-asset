extends Node
## Director：用 data/viral_script.json（和视频渲染器同一份分镜）驱动游戏
##   interactive=true  → 新手引导：同样的镜头，关键处等玩家操作（gate）
##   interactive=false → 录屏模式：严格按视频时间轴自动播放，玩家直接录屏即可复刻爆款视频

signal finished(interactive: bool, action: String)

var m: Node2D
var S: Dictionary
var interactive := false
var t := 0.0
var beat_i := -1
var fired := {}
var blocked := false
var gate_count := 0
var perks_backup: Array = []
var agent_lines := {}
var cta: Control = null
var progress: ColorRect
var done := false
var hint_t := 0.0
var first_run := false


func begin(main: Node2D, is_interactive: bool) -> void:
	m = main
	interactive = is_interactive
	S = m.script_data
	perks_backup = GS.perks.duplicate()
	GS.perks = []
	GS.paused = true
	first_run = not GS.tutorial_done
	m.btn_row.visible = interactive
	m.lbl_log.visible = false
	m.lbl_driver.visible = interactive
	m.hint.text = ""
	m.display = {"life": 99, "life_glow": false, "realm": "炼气", "mem_n": 0, "mem_max": 3, "qi": 12.0, "rate": 1.2}
	var b = m.battle
	b.scripted = true
	b.revive_hero()
	b.hero.pos = Vector2(60, 62)
	progress = ColorRect.new()
	progress.color = m.GOLD
	progress.position = Vector2(0, m.H - 3)
	progress.size = Vector2(0, 3)
	progress.visible = not interactive
	m.ui.add_child(progress)
	if interactive:
		if first_run:
			GS.life = 100
			Mem.life = 100
			Mem.npc["senior"] = [{"life": 99, "text": "上一世你抢了我的丹药", "importance": 5, "valence": -2}]
		_prefetch_agent_lines()


## 提前请求 Haiku（有 key 时），让引导里的台词是真·AI 生成的
func _prefetch_agent_lines() -> void:
	var r1: Dictionary = await Agent.decide("senior", "wave_start", {"wave": 3, "realm": "炼气", "player_hp_ratio": 1.0, "enemies": 6, "note": "新手引导：师弟刚重生，你表面要装友善"})
	for c in r1.calls:
		if c.name == "say":
			agent_lines["senior"] = str(c.input.get("text", "")).substr(0, 20)
	var r2: Dictionary = await Agent.decide("elder", "burned", {"wave": 3, "player_used_fire": true, "note": "师弟一眼看穿了你怕火的秘密"})
	for c in r2.calls:
		if c.name == "say":
			agent_lines["elder"] = str(c.input.get("text", "")).substr(0, 22)


func _process(delta: float) -> void:
	if done:
		return
	hint_t += delta
	if blocked:
		m.hint.modulate.a = 0.5 + 0.5 * sin(hint_t * 8.0)
		return
	t += delta
	progress.size.x = m.W * clampf(t / S.duration, 0, 1)
	var bi := _beat_index(t)
	if bi != beat_i:
		if beat_i >= 0 and _post_gate_pending(beat_i):
			t = S.beats[beat_i].t1 - 0.001
			_block(S.beats[beat_i].gate)
			return
		beat_i = bi
		_enter_beat(S.beats[bi])
		if blocked:
			return
	_run_actions(S.beats[beat_i])
	_continuous(S.beats[beat_i])
	if t >= S.duration and not done:
		if _post_gate_pending(beat_i):
			t = S.duration - 0.001
			_block(S.beats[beat_i].gate)
			return
		_finish_timeline()


func _beat_index(tt: float) -> int:
	for i in S.beats.size():
		if tt < S.beats[i].t1:
			return i
	return S.beats.size() - 1


func _post_gate_pending(i: int) -> bool:
	var b: Dictionary = S.beats[i]
	return interactive and b.has("gate") and b.gate.at == "post" and not fired.has("gate_" + b.id) and b.gate.type != "choose_start"


func _block(g: Dictionary) -> void:
	blocked = true
	gate_count = 0
	m.hint.text = g.get("hint", "")


func _unblock(id: String) -> void:
	fired["gate_" + id] = true
	blocked = false
	m.hint.text = ""


func on_gate_event(kind: String) -> void:
	if not blocked or beat_i < 0:
		return
	var b: Dictionary = S.beats[beat_i]
	if not b.has("gate") or b.gate.type != kind:
		return
	match kind:
		"tap_tuna":
			gate_count += 1
			if b.id == "paperclips":
				m.ledger.set_state({"qi": float(gate_count), "rate": 0.0, "pressed": true, "cursor": false,
					"log": ["你吐纳了一次。"] if gate_count == 1 else ["你吐纳了一次。", "你又吐纳了一次。"],
					"caption": b.gate.hint if gate_count < int(b.gate.get("count", 3)) else ""})
				get_tree().create_timer(0.1).timeout.connect(func(): if m.ledger.state.has("pressed"): m.ledger.state.pressed = false)
			else:
				m.display.qi = float(m.display.qi) + 30.0
				m._float_world("+30", m.battle.hero.pos + Vector2(0, -6), m.GOLD)
			if gate_count >= int(b.gate.get("count", 3)):
				_unblock(b.id)
		_:
			_unblock(b.id)


func _enter_beat(b: Dictionary) -> void:
	m.caption(b.caption, b.sub, m.WHITE)
	# 每个镜头开始时清掉上一镜头的气泡，保证与视频一致
	for k in m.bubbles.keys():
		if is_instance_valid(m.bubbles[k]):
			m.bubbles[k].queue_free()
	if b.id == "breakthrough":
		var bt = m.battle
		bt.units = bt.units.filter(func(u): return u.kind == "hero")
		bt.senior = {}
		bt.hero.pos = Vector2(60, 62)
	if b.id == "paperclips":
		# 硬切：整屏变成 Paperclips 式账本
		m.ledger.show_close = false
		m.ledger.visible = true
		m.ledger.set_state(ledger_state(0.0, b))
		m.caption("")
	elif b.id == "cta":
		m.ledger.visible = false
	if interactive and b.has("gate") and b.gate.at == "pre" and not fired.has("gate_" + b.id):
		t = b.t0
		_block(b.gate)
		if b.id == "paperclips":
			m.ledger.set_state({"qi": 0.0, "rate": 0.0, "cursor": true, "caption": b.gate.hint})


func _at(action: String) -> float:
	var i := action.rfind("@")
	return float(action.substr(i + 1)) if i >= 0 else -1.0


func _run_actions(b: Dictionary) -> void:
	for a in b.actions:
		var key: String = b.id + "|" + a
		if fired.has(key):
			continue
		var at := _at(a)
		if at >= 0 and t < at:
			continue
		fired[key] = true
		_do(a.split("@")[0], b)


func _do(a: String, b: Dictionary) -> void:
	var bt = m.battle
	var parts := a.split(":")
	match parts[0]:
		"hero_idle":
			bt.spawn_scripted_foe(110, Vector2(130, 62), 50.0)
		"slash_kill_hero":
			bt.kill_hero_scripted()
			bt.hero.hp = 0
			bt.hero.alive = false
			bt.hero.rot = PI / 2
			bt.fx.append({"type": "flash", "t": 0.0, "dur": 0.15, "color": Color(1, 1, 1, 0.55)})
			for i in 10:
				bt.fx.append({"type": "blood", "t": 0.0, "dur": 1.0, "a": bt.hero.pos + Vector2(8, 8), "b": Vector2(cos(i * 0.63), sin(i * 0.63) * 0.6), "color": m.BLOOD})
			m.flash(Color(1, 1, 1, 0.55), 0.15)
		"shake":
			m.shake_screen(3, 0.4)
		"memory_shards":
			bt.revive_hero()
			bt.hero.pos = Vector2(60, 62)
			bt.add_shards(1.6)
		"life_counter":
			get_tree().create_timer(0.8).timeout.connect(func():
				m.display.life = 100
				m.display.life_glow = true)
		"memory_cards":
			_show_cards()
		"npc_enter":
			if parts[1] == "senior":
				var s = bt.spawn_senior(Vector2(140, 62))
				s.tactic = "hold"
				s.hold = Vector2(104, 62)
			else:
				bt.spawn_elder(false, Vector2(140, 42))
		"npc_say":
			var line: String = parts[2]
			if interactive and agent_lines.has(parts[1]):
				line = agent_lines[parts[1]]
			m.say(parts[1], line)
		"npc_think":
			var txt: String = parts[2]
			if interactive:
				var r: Array = Mem.recall(parts[1], 1)
				if r.size() > 0:
					txt = r[0].text
			if m.bubbles.has(parts[1]) and is_instance_valid(m.bubbles[parts[1]]):
				m.bubbles[parts[1]].queue_free()
			m.say(parts[1] + "_think", txt, "记忆: ", true, Color("d2faf0"))
		"hero_say":
			m.say("hero", parts[1])
		"wave":
			bt.hero.atk = 40.0
			bt.hero.max_hp = 9999.0
			bt.hero.hp = 9999.0
			bt.senior.tactic = "assist"
			GS.wave = GS.wave if not interactive else GS.wave
			bt.start_wave(3, int(parts[1]))
			for u in bt.units:
				if u.team == "enemy":
					u.atk = 0.0
					u.hp = 60.0
					u.max_hp = 60.0
		"npc_betray":
			GS.perks.append("dodge_betrayal")
			bt.force_betray()
			m.flash(Color(0.89, 0.2, 0.25, 0.35), 0.4)
		"caption_swap":
			if b.id != "paperclips":
				m.caption(parts[1], b.sub, m.JADE)
		"counter_explode":
			m.display.qi_big = true
		"upgrades_popin":
			var names := ["[吐纳] 自动化", "[聚灵阵] ×12", "[夺舍] 解锁", "[魔种] 分裂"]
			for i in names.size():
				get_tree().create_timer(0.4 + i * 0.5).timeout.connect(func(): _add_upgrade_row(names[i]))
		"realm":
			get_tree().create_timer(0.2).timeout.connect(func(): m.display.realm = parts[1].split(">")[1])
		"gold_flash":
			m.flash(Color(1, 0.84, 0.36, 0.7), 0.4)
			bt.add_ring(bt.hero.pos + Vector2(8, 8), m.GOLD, 90, 2.4)
			m.display.qi_big = false
		"title_card", "cta_tutorial":
			if cta == null:
				_show_cta()
		"counter_hit", "hero_dodge", "hero_autobattle":
			pass  # 由战斗系统真实完成（记忆 perk → 闪避 + 反击）


func _beat(id: String) -> Dictionary:
	for b in S.beats:
		if b.id == id:
			return b
	return {}


func _continuous(b: Dictionary) -> void:
	# HUD 数字：与 render_viral.py 的 hud_qi() 同一公式
	var tb: float = _beat("breakthrough").t0
	m.display.qi = 12.0 + t * 37.0 if t < tb else 12.0 + tb * 37.0 + (t - tb) * 10.8
	m.display.rate = 1.2 if t < tb else 10.8
	if t >= 2.2:
		m.display.mem_n = min(3, int((t - 2.2) * 3) + 1)
	if b.id == "paperclips":
		m.ledger.set_state(ledger_state(t - b.t0, b))
	m.ui_refresh = 0.0


## Paperclips 段在 r 秒时的状态 —— render_viral.py 的 ledger_state() 的 GDScript 版
func ledger_state(r: float, b: Dictionary) -> Dictionary:
	var L: Dictionary = b.ledger
	var taps := 0
	var pressed := false
	for x in L.taps:
		if r >= x:
			taps += 1
		if r - x >= 0.0 and r - x < 0.12:
			pressed = true
	var qi: float = float(taps) if r < 1.2 else 4.0 + pow(10.0, (r - 1.2) * 4.6)
	var rows := []
	for row in L.rows:
		if r >= row[0]:
			rows.append([row[1], row[2]])
	var phases := []
	if r >= L.rows[-1][0]:
		for ph in L.phases:
			phases.append([ph[0], clampf((r - ph[1]) / (ph[2] - ph[1]), 0.0, 1.0)])
	var log := []
	for e in L.log:
		if r >= e[0]:
			log.append(e[1])
	log = log.slice(max(0, log.size() - 6))
	var cap: String = b.caption
	for a in b.actions:
		if a.begins_with("caption_swap:") and t >= _at(a):
			cap = a.substr(13, a.rfind("@") - 13)
	return {"qi": qi, "rate": 0.0 if r < 1.2 else qi * 1.06, "seeds": 0.0 if r < 2.4 else pow(2.0, (r - 2.4) * 14.0),
		"rows": rows, "phases": phases, "log": log, "pressed": pressed, "cursor": r < 1.3, "caption": cap,
		"flash": 0.78 if r < 0.15 else 0.0}


func _show_cards() -> void:
	for c in m.cards_box.get_children():
		c.queue_free()
	var cards: Array = S.memory_cards
	for i in cards.size():
		var c: Dictionary = cards[i]
		var w: Control
		if interactive:
			var btn: Button = m._button(c.text, func(): _pick_card(i), Color("183a3c"), m.JADE)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.custom_minimum_size = Vector2(137, 15)
			w = btn
		else:
			w = m._card_widget(c.text, false)
		w.modulate.a = 0.0
		m.cards_box.add_child(w)
		var tw := create_tween()
		tw.tween_interval(0.4 + i * 0.5)
		tw.tween_property(w, "modulate:a", 1.0, 0.2)
		if interactive:
			Mem.learn(c.id, c.text, c.perk, "")


func _pick_card(i: int) -> void:
	if not blocked or S.beats[beat_i].id != "memory":
		return
	if i != 0:
		m._toast("先带「%s」——这一世马上用得上" % S.memory_cards[0].text, m.GOLD)
		return
	var w: Control = m.cards_box.get_child(0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("5a1e28")
	sb.border_color = m.BLOOD
	sb.set_border_width_all(1)
	w.add_theme_stylebox_override("normal", sb)
	fired["picked"] = S.memory_cards[0].id
	on_gate_event("pick_card")


func _add_upgrade_row(text: String) -> void:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(114, 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = m.INK
	sb.border_color = m.JADE
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	m._label(text, Vector2(5, 0), m.WHITE, 12, p)
	m.ups_box.add_child(p)


func _show_cta() -> void:
	cta = Control.new()
	cta.size = Vector2(m.W, m.H)
	m.ui.add_child(cta)
	m.ui.move_child(progress, -1)
	var dim := ColorRect.new()
	dim.color = Color(0.055, 0.04, 0.086, 0.0)
	dim.size = Vector2(m.W, m.H)
	cta.add_child(dim)
	create_tween().tween_property(dim, "color:a", 0.9, 0.4)
	for k in m.bubbles.keys():
		if is_instance_valid(m.bubbles[k]):
			m.bubbles[k].queue_free()
	var title: Label = m._label(S.title, Vector2(0, 80), m.GOLD, 48, cta, 6)
	title.size = Vector2(m.W, 56)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	create_tween().tween_property(title, "position:y", 120.0, 0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	var rows := [[S.tagline, m.JADE, 24, 190], [S.beats[-1].caption, m.WHITE, 24, 250], [S.beats[-1].sub, m.DIM, 12, 290],
		["▶ 新手引导 = 这条视频\n进游戏一键复刻", m.GOLD, 12, 320], [" ".join(S.hashtags.slice(0, 4)), m.DIM, 12, 372]]
	for i in rows.size():
		var r: Array = rows[i]
		var l: Label = m._label(r[0], Vector2(0, r[3]), r[1], r[2], cta, 4 if r[2] > 12 else 2)
		l.size = Vector2(m.W, 40)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if i == 3:
			l.modulate.a = 0.0
			var tw := l.create_tween()
			tw.tween_interval(1.0)
			tw.tween_property(l, "modulate:a", 1.0, 0.0)
			tw.tween_callback(func(): l.create_tween().set_loops().tween_property(l, "self_modulate", Color(1.4, 1.2, 0.6), 0.33).from(Color.WHITE))
	m.caption("")


func _finish_timeline() -> void:
	done = true
	m.hint.text = ""
	if interactive:
		_cta_buttons([["开始第 %d 世（带着记忆）" % (GS.life + 1), "play"], ["录屏模式 · 复刻视频", "record"], ["返回标题", "title"]])
	else:
		get_tree().create_timer(1.5).timeout.connect(_share_panel)


func _cta_buttons(opts: Array) -> void:
	var v := VBoxContainer.new()
	v.position = Vector2(45, 396)
	v.add_theme_constant_override("separation", 4)
	cta.add_child(v)
	for o in opts:
		var b: Button = m._button(o[0], func(): _end(o[1]), m.INK, m.GOLD if o[1] == "play" else m.JADE)
		b.custom_minimum_size = Vector2(180, 22)
		v.add_child(b)


func _share_panel() -> void:
	var cap_text := "我在魔门死了99次，但每一世都带着记忆。第100世，AI 师兄果然在第3波背刺了——但我记得。你能活到第几世？评论区：你会带哪条记忆 " + " ".join(S.hashtags)
	var l: Label = m._label("录好了？发抖音 / TikTok：", Vector2(0, 384), m.GOLD, 12, cta, 2)
	l.size = Vector2(m.W, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cta_buttons([["复制视频文案 + 话题", "copy"], ["再录一次", "record"], ["进入游戏", "play_or_title"]])
	var v: Control = cta.get_child(cta.get_child_count() - 1)
	v.position.y = 400
	v.add_theme_constant_override("separation", 3)
	for c in v.get_children():
		c.custom_minimum_size.y = 20
	set_meta("share", cap_text)


func _end(action: String) -> void:
	if action == "copy":
		DisplayServer.clipboard_set(get_meta("share", ""))
		m._toast("已复制文案，贴到发布页即可", m.JADE)
		return
	GS.perks = perks_backup
	GS.paused = false
	m.ledger.visible = false
	m.ledger.show_close = true
	if is_instance_valid(cta):
		cta.queue_free()
	progress.queue_free()
	m.hint.text = ""
	m.lbl_driver.visible = true
	for k in m.bubbles.keys():
		if is_instance_valid(m.bubbles[k]):
			m.bubbles[k].queue_free()
	if interactive and action == "play":
		GS.tutorial_done = true
		# 教程里的数值馈赠不带走，只带走记忆 —— 这正是游戏的核心
		var carry := [fired.get("picked", S.memory_cards[0].id)]
		GS.reincarnate(carry)
	if action == "play_or_title":
		action = "play" if GS.tutorial_done else "title"
	if interactive and action != "play":
		GS.tutorial_done = true
		GS.save_game()
	finished.emit(interactive, action)
