extends Node2D
## 魔门人材 —— 主场景：竖屏 270x480（×4 = 1080x1920，与爆款视频同构图）

const W := 270
const H := 480
const AY := 44
const INK := Color("14101c")
const BG := Color("1a1426")
const PANEL := Color("2c223e")
const GOLD := Color("ffd65c")
const BLOOD := Color("e23440")
const JADE := Color("5ce8c4")
const WHITE := Color("f4f0e6")
const DIM := Color("968caa")

var font: FontFile
var battle: Node2D
var ui: Control
var lbl_life: Label
var lbl_realm: Label
var lbl_mem: Label
var lbl_title: Label
var lbl_qi: Label
var lbl_rate: Label
var lbl_log: Label
var lbl_driver: Label
var cap: Label
var cap_sub: Label
var hint: Label
var cards_box: VBoxContainer
var ups_box: VBoxContainer
var btn_row: HBoxContainer
var ledger: Control
var story_ui: Control
var story_mode: Node
var cont_btn: Button
var btns := {}
var bubbles := {}
var fx_layer: Control
var flash_rect: ColorRect
var overlay: Control = null
var director: Node = null
var mode := "title"            # title | play | director | rebirth
var display := {}              # Director 的显示覆盖（录屏/引导时不动存档数值）
var script_data: Dictionary
var next_wave_timer := -1.0
var loot_waiting := false
var loot_seq := 0  # 每次掉落选择一个编号，旧计时器不会误结算新的选择
var ui_refresh := 0.0


func _ready() -> void:
	script_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/viral_script.json"))
	font = load("res://assets/fonts/pixel.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	_build_ui()
	GS.log_line.connect(_log)
	GS.ending_reached.connect(_on_ending)
	GS.changed.connect(func(): ui_refresh = 0.0)
	Mem.card_learned.connect(func(c): _toast("新记忆：「%s」" % c.text, JADE))
	Agent.driver_changed.connect(func(l): lbl_driver.text = "角色驱动：" + l)
	var args := OS.get_cmdline_user_args()
	if args.has("--record"):
		start_director(false)
	elif args.has("--play"):
		GS.tutorial_done = true
		start_play()
	elif args.has("--storydemo"):
		var sd = load("res://scripts/story_test.gd").new()
		add_child(sd)
		sd.run_demo(self)
	elif args.has("--storytest"):
		var st = load("res://scripts/story_test.gd").new()
		add_child(st)
		st.run(self)
	elif args.has("--autotest"):
		var t = load("res://scripts/autotest.gd").new()
		add_child(t)
		t.run(self)
	else:
		show_title()


# ======================= UI 构建 =======================

func _label(text: String, pos: Vector2, color := WHITE, size := 12, parent: Node = null, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else ui).add_child(l)
	return l


func _box(r: Rect2, fill: Color, border := INK, parent: Node = null) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else ui).add_child(p)
	return p


func _button(text: String, cb: Callable, fill := INK, border := JADE, size := 12) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", DIM)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill if st != "pressed" else border.darkened(0.5)
		if st == "hover":
			sb.bg_color = fill.lightened(0.08)
		sb.border_color = border if st != "disabled" else DIM.darkened(0.4)
		sb.set_border_width_all(1)
		sb.content_margin_left = 3
		sb.content_margin_right = 3
		sb.content_margin_top = 0
		sb.content_margin_bottom = 1
		if st == "focus":
			sb.draw_center = false
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	b.focus_mode = Control.FOCUS_NONE
	return b


func _build_ui() -> void:
	ui = Control.new()
	ui.size = Vector2(W, H)
	add_child(ui)
	var bg := ColorRect.new()
	bg.color = BG
	bg.size = Vector2(W, H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(bg)
	# 竞技场（GBA 屏）
	var clip := Control.new()
	clip.position = Vector2(0, AY)
	clip.size = Vector2(W, 210)
	clip.clip_contents = true
	clip.mouse_filter = Control.MOUSE_FILTER_STOP
	clip.gui_input.connect(_arena_input)
	ui.add_child(clip)
	battle = load("res://scripts/battle.gd").new()
	battle.scale = Vector2(2, 2)
	clip.add_child(battle)
	battle.float_text.connect(_float_world)
	battle.speak.connect(func(a, t): if director == null: say(a, t))
	battle.wave_cleared.connect(_on_wave_cleared)
	battle.hero_died.connect(_on_hero_died)
	battle.betrayal.connect(_on_betrayal)
	battle.elder_burned.connect(_on_elder_burned)
	# HUD
	_box(Rect2(0, 0, W, 40), INK, INK)
	lbl_life = _label("第 1 世", Vector2(8, 3))
	lbl_realm = _label("境界 炼气", Vector2(8, 19))
	lbl_title = _label(script_data.title, Vector2(W - 60, 3), GOLD)
	lbl_mem = _label("记忆 0/1", Vector2(W - 80, 19), JADE)
	# 资源面板（Paperclips 式）
	_box(Rect2(6, 260, W - 12, 40), PANEL)
	_label("魔元", Vector2(14, 262), DIM)
	lbl_qi = _label("0", Vector2(54, 262), GOLD, 12, null, 2)
	lbl_rate = _label("+1/秒", Vector2(W - 90, 262), JADE)
	cards_box = VBoxContainer.new()
	cards_box.position = Vector2(6, 304)
	cards_box.size = Vector2(137, 90)
	cards_box.add_theme_constant_override("separation", 1)
	ui.add_child(cards_box)
	ups_box = VBoxContainer.new()
	ups_box.position = Vector2(150, 304)
	ups_box.size = Vector2(114, 90)
	ups_box.add_theme_constant_override("separation", 1)
	ui.add_child(ups_box)
	btn_row = HBoxContainer.new()
	btn_row.position = Vector2(6, 404)
	btn_row.size = Vector2(W - 12, 22)
	btn_row.add_theme_constant_override("separation", 3)
	ui.add_child(btn_row)
	btn_row.add_theme_constant_override("separation", 2)
	for pair in [["tuna", "吐纳", _on_tuna], ["fire", "魔焰", _on_fire], ["break", "突破", _on_break], ["ledger", "账本", _on_ledger], ["mem", "记忆", _on_mem_btn], ["cfg", "设置", _on_cfg]]:
		var b := _button(pair[1], pair[2], INK, GOLD if pair[0] == "tuna" else JADE)
		b.custom_minimum_size = Vector2(41, 22)
		btn_row.add_child(b)
		btns[pair[0]] = b
	lbl_log = _label("", Vector2(8, 432), DIM)
	lbl_log.size = Vector2(W - 16, 26)
	lbl_log.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	lbl_driver = _label("角色驱动：" + Agent.driver_label(), Vector2(8, 458), DIM)
	# 大字幕（与视频同位置同字号：12px 像素字 ×2）
	cap = _label("", Vector2(0, AY + 12), WHITE, 24, null, 4)
	cap.size = Vector2(W, 60)
	cap.add_theme_constant_override("line_spacing", 26 - int(font.get_height(24)))
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_sub = _label("", Vector2(0, AY + 64), GOLD, 12, null, 3)
	cap_sub.size = Vector2(W, 14)
	cap_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint = _label("", Vector2(0, 380), GOLD, 12, null, 3)
	hint.size = Vector2(W, 14)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fx_layer = Control.new()
	fx_layer.size = Vector2(W, H)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(fx_layer)
	flash_rect = ColorRect.new()
	flash_rect.size = Vector2(W, H)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)
	ledger = load("res://scripts/ledger.gd").new()
	ledger.setup(font, script_data.ledger_layout)
	ledger.visible = false
	ui.add_child(ledger)
	ledger.tuna_pressed.connect(_on_tuna)
	story_ui = load("res://scripts/story_ui.gd").new()
	story_ui.setup(font)
	ui.add_child(story_ui)
	story_mode = load("res://scripts/story_mode.gd").new()
	add_child(story_mode)
	story_mode.setup(self, story_ui)
	cont_btn = _button("继续剧情", func(): story_mode.continue_after_cultivate(), INK, GOLD)
	cont_btn.position = Vector2(6, 380)
	cont_btn.custom_minimum_size = Vector2(W - 12, 20)
	cont_btn.visible = false
	ui.add_child(cont_btn)
	ledger.close_pressed.connect(func(): if director == null: ledger.visible = false)
	ledger.row_pressed.connect(func(i):
		if director != null or mode != "play":
			return
		var ids: Array = GS.ledger_state().row_ids
		if i < ids.size() and GS.buy(ids[i]):
			battle.refresh_hero_stats()
			ui_refresh = 0.0)


# ======================= 通用表现 =======================

func caption(text: String, sub := "", color := WHITE) -> void:
	cap.text = text
	cap.add_theme_color_override("font_color", color)
	cap_sub.text = sub
	var lines := text.count("\n") + 1
	cap_sub.position.y = AY + 12 + lines * 26 + 2
	if text != "":
		cap.pivot_offset = Vector2(W / 2.0, 12)
		cap.scale = Vector2(1.25, 1.25)
		create_tween().tween_property(cap, "scale", Vector2.ONE, 0.12)


func flash(col: Color, dur := 0.35) -> void:
	flash_rect.color = col
	create_tween().tween_property(flash_rect, "color:a", 0.0, dur)


func shake_screen(amount := 3.0, dur := 0.35) -> void:
	var tw := create_tween()
	var steps := int(dur / 0.04)
	for i in steps:
		tw.tween_property(ui, "position", Vector2(randf_range(-amount, amount), randf_range(-amount, amount)), 0.04)
	tw.tween_property(ui, "position", Vector2.ZERO, 0.04)


func _float_world(text: String, wp: Vector2, col: Color) -> void:
	var sp: Vector2 = Vector2(0, AY) + battle.screen_pos(wp)
	var l := _label(text, sp, col, 12, fx_layer, 3)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", sp.y - 16, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _toast(text: String, col := GOLD) -> void:
	var l := _label(text, Vector2(0, 236), col, 12, fx_layer, 3)
	l.size = Vector2(W, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


## 气泡：跟随角色；typed=逐字打出（与视频 14 字/秒一致）
func say(actor: String, text: String, prefix := "", typed := true, fill := Color("faf6ec")) -> void:
	if bubbles.has(actor) and is_instance_valid(bubbles[actor]):
		bubbles[actor].queue_free()
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = INK
	sb.set_border_width_all(1)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 1
	sb.content_margin_bottom = 2
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", INK)
	var full := prefix + text
	l.text = full
	l.visible_characters = prefix.length() if typed else -1
	p.add_child(l)
	fx_layer.add_child(p)
	p.set_meta("actor", actor)
	bubbles[actor] = p
	if typed:
		var tw := create_tween()
		tw.tween_property(l, "visible_characters", full.length(), text.length() / 14.0)
	get_tree().create_timer(3.2 + text.length() / 14.0).timeout.connect(p.queue_free)


func _update_bubbles() -> void:
	for actor in bubbles.keys():
		var p = bubbles[actor]
		if not is_instance_valid(p):
			bubbles.erase(actor)
			continue
		var u: Dictionary = {}
		var who: String = actor.trim_suffix("_think")
		match who:
			"hero": u = battle.hero
			"senior": u = battle.senior
			"elder": u = battle.elder
		if who.begins_with("actor:"):
			var ap: Vector2 = battle.actor_pos(who.substr(6))
			if ap.x >= 0:
				u = {"pos": ap}
		if u.is_empty():
			continue
		var sp: Vector2 = Vector2(0, AY) + battle.screen_pos(u.pos)
		var y_off := -22.0 if not actor.ends_with("_think") else -42.0
		p.position = Vector2(clampf(sp.x + 16 - p.size.x / 2, 4, W - p.size.x - 4), clampf(sp.y + y_off, AY + 2, 250))


# ======================= 主循环 =======================

func _process(delta: float) -> void:
	_update_bubbles()
	ui_refresh -= delta
	if ui_refresh <= 0:
		ui_refresh = 0.2
		_refresh_ui()
	if mode == "play":
		var dir := Vector2(Input.get_axis("ui_left", "ui_right"), Input.get_axis("ui_up", "ui_down"))
		battle.move_dir = dir
		if Input.is_key_pressed(KEY_SPACE):
			_on_fire()
		if next_wave_timer > 0:
			next_wave_timer -= delta
			if next_wave_timer <= 0 and not loot_waiting:
				_begin_wave()
	btns.fire.text = "魔焰" if battle.fire_cd <= 0 else "%d" % ceil(battle.fire_cd)


func _on_ledger() -> void:
	if director or mode != "play":
		return
	ledger.visible = not ledger.visible
	ui_refresh = 0.0


## Paperclips 式结局：三千世界炼化完毕 → 万物皆成魔元 → 带着「炼化过三千世界」的记忆轮回
func _on_ending() -> void:
	if mode != "play" or Story.st.get("active", false):
		_toast("魔种炼化了三千世界……但故事还没结束", GOLD)
		return
	mode = "rebirth"
	ledger.visible = true
	ledger.set_state(GS.ledger_state().merged({"caption": "万物皆成魔元。\n只有我还记得它们。"}, true))
	Mem.learn("universe_memory")
	GS.dao_marks += 50
	get_tree().create_timer(4.0).timeout.connect(func():
		ledger.visible = false
		show_rebirth())


func _refresh_ui() -> void:
	if cont_btn and cont_btn.visible:
		var req: int = story_mode.cultivate_req
		cont_btn.disabled = GS.realm < req
		cont_btn.text = "▶ 继续剧情" if GS.realm >= req else "继续剧情（需【%s】，当前【%s】· 攒魔元点突破）" % [GS.REALMS[max(req, 0)], GS.REALMS[GS.realm]]
	if ledger.visible and director == null and mode == "play":
		ledger.set_state(GS.ledger_state())
	var d := display
	lbl_life.text = "第 %d 世" % int(d.get("life", GS.life))
	lbl_life.add_theme_color_override("font_color", JADE if d.get("life_glow", GS.life > 1) else DIM)
	var rname: String = d.get("realm", GS.REALMS[GS.realm])
	lbl_realm.text = "境界 " + rname
	lbl_realm.add_theme_color_override("font_color", GOLD if rname != "炼气" else WHITE)
	lbl_mem.text = "记忆 %d/%d" % [int(d.get("mem_n", GS.perks.size())), int(d.get("mem_max", GS.memory_slots()))]
	lbl_title.position.x = W - 8 - font.get_string_size(lbl_title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	var q: float = d.get("qi", GS.qi)
	lbl_qi.text = GS.fmt(q)
	var big: bool = d.get("qi_big", false)
	lbl_qi.add_theme_font_size_override("font_size", 24 if big else 12)
	lbl_qi.position.y = 258 if big else 262
	lbl_rate.text = "+%s/秒" % GS.fmt(d.get("rate", GS.qi_rate()))
	if mode == "play":
		lbl_rate.text += "  波%d" % GS.wave
		_rebuild_upgrades()
		_rebuild_cards()
		btns["break"].disabled = not GS.can_break()
		btns["break"].text = "突破" if GS.realm < GS.REALMS.size() - 1 else "飞升"


func _rebuild_upgrades() -> void:
	var want := []
	for id in GS.UPGRADES:
		if GS.upgrade_visible(id):
			want.append(id)
	want = want.slice(0, 5)
	if ups_box.get_child_count() != want.size():
		for c in ups_box.get_children():
			c.queue_free()
		for id in want:
			var b := _button("", func(): if GS.buy(id): battle.refresh_hero_stats(), INK, JADE)
			b.custom_minimum_size = Vector2(114, 15)
			b.set_meta("id", id)
			b.alignment = HORIZONTAL_ALIGNMENT_LEFT
			b.tooltip_text = GS.UPGRADES[id].desc
			ups_box.add_child(b)
	for b in ups_box.get_children():
		if not b.has_meta("id"):
			continue
		var id: String = b.get_meta("id")
		var lv := GS.level(id)
		b.text = "%s%s %s" % [GS.UPGRADES[id].name, ("" if lv == 0 else str(lv)), GS.fmt(GS.upgrade_cost(id))]
		b.disabled = GS.qi < GS.upgrade_cost(id)


func _rebuild_cards() -> void:
	var want: Array = Mem.carried.filter(func(i): return not Mem.card(i).is_empty())
	if cards_box.get_child_count() == want.size():
		return
	for c in cards_box.get_children():
		c.queue_free()
	for id in want:
		cards_box.add_child(_card_widget(Mem.card(id).text, false))


func _card_widget(text: String, danger: bool) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(137, 15)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("183a3c") if not danger else Color("5a1e28")
	sb.border_color = JADE if not danger else BLOOD
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := _label(text, Vector2(4, 0), WHITE, 12, p)
	return p


func _log(text: String) -> void:
	lbl_log.text = text
	Mem.note(text)


# ======================= 输入 =======================

func _arena_input(ev: InputEvent) -> void:
	if mode != "play":
		return
	if (ev is InputEventMouseButton and ev.pressed) or ev is InputEventScreenDrag or (ev is InputEventMouseMotion and ev.button_mask & MOUSE_BUTTON_MASK_LEFT):
		battle.manual_target = (ev.position) / 2.0 - Vector2(8, 8)


func _on_tuna() -> void:
	if mode == "story":
		story_mode.on_tuna()
		return
	if director:
		director.on_gate_event("tap_tuna")
		return
	GS.tuna(true)
	_float_world("+" + GS.fmt(GS.tuna_power() * 3), battle.hero.pos + Vector2(0, -6), GOLD)


func _on_fire() -> void:
	if director or mode != "play":
		return
	battle.cast_fire()


func _on_break() -> void:
	if director:
		director.on_gate_event("tap_break")
		return
	if GS.breakthrough():
		battle.refresh_hero_stats()
		battle.hero.hp = battle.hero.max_hp
		battle.add_ring(battle.hero.pos + Vector2(8, 8), GOLD, 60, 1.0)
		flash(Color(1, 0.84, 0.36, 0.65), 0.4)
		shake_screen(2)
		caption("%s → %s" % [GS.REALMS[GS.realm - 1], GS.REALMS[GS.realm]], "", WHITE)
		get_tree().create_timer(1.6).timeout.connect(func(): if mode == "play": caption(""))
		if GS.realm == 1:
			Mem.learn("realm_echo")


# ======================= 正式游戏循环 =======================

func start_play() -> void:
	_close_overlay()
	display = {}
	mode = "play"
	hint.text = ""
	caption("")
	btn_row.visible = true
	lbl_log.visible = true
	battle.scripted = false
	battle.revive_hero()
	battle.allow_pills = true
	story_layout(false)
	if not str(Story.flag("senior")) in ["dead", "enemy"]:
		battle.spawn_senior()
	_log("第 %d 世。外门弟子。先苟住。" % GS.life)
	next_wave_timer = 0.8


func _begin_wave() -> void:
	next_wave_timer = -1
	battle.refresh_hero_stats()
	if battle.senior.is_empty() or not battle.senior.alive or battle.senior.team != "ally":
		if GS.wave % 3 == 1:
			battle.spawn_senior()
	battle.start_wave(GS.wave)
	if GS.wave == 4 and not Mem.library.has("pill_cave"):
		GS.pills += 1
		Mem.learn("pill_cave")
	if not battle.senior.is_empty() and battle.senior.alive and battle.senior.team == "ally":
		_drive_senior("wave_start", {})


## Agent 决策 → 游戏校验 → 执行（receipt 写进编年史）
func _drive_senior(type: String, extra: Dictionary) -> void:
	var payload := {"wave": GS.wave, "realm": GS.REALMS[GS.realm], "player_hp_ratio": snappedf(battle.hero.hp / max(1.0, battle.hero.max_hp), 0.01),
		"enemies": battle.enemies_alive(), "player_perks": GS.perks}
	payload.merge(extra)
	var res: Dictionary = await Agent.decide("senior", type, payload)
	if battle.senior.is_empty() or not battle.senior.alive:
		return
	for c in res.calls:
		var inp: Dictionary = c.get("input", {})
		match c.name:
			"set_tactic":
				var t := str(inp.get("tactic", "assist"))
				if not t in ["assist", "guard", "idle", "betray"]:
					t = "assist"
				# 游戏是权威：好感不够低或太早，不允许背刺
				if t == "betray" and (GS.wave < 2 or Mem.relation("senior") > -10):
					t = "idle"
				battle.set_senior_tactic(t)
				if t == "guard" and not Mem.library.has("senior_saved_me") and GS.wave >= 2:
					Mem.learn("senior_saved_me")
			"say":
				say("senior", str(inp.get("text", "")).substr(0, 24))
			"remember":
				Mem.remember("senior", str(inp.get("text", "")), int(inp.get("importance", 3)), int(inp.get("valence", 0)))
	lbl_driver.text = "角色驱动：%s · 师兄=%s" % [res.driver, battle.senior.tactic]


func _on_wave_cleared(n: int) -> void:
	if mode == "story":
		story_mode.on_wave_cleared()
		return
	if mode != "play":
		return
	GS.add_qi(10.0 * pow(1.3, n))
	GS.wave += 1
	GS.best_wave = max(GS.best_wave, GS.wave - 1)
	if n == 5:
		Mem.learn("spider_wave")
	_log("第 %d 波清空。魔元 +%s" % [n, GS.fmt(10.0 * pow(1.3, n))])
	next_wave_timer = 1.2
	if n % 2 == 0 and not battle.senior.is_empty() and battle.senior.alive and battle.senior.team == "ally":
		_loot_choice()


func _loot_choice() -> void:
	loot_waiting = true
	loot_seq += 1
	var my_id := loot_seq
	GS.paused = false
	var o := _overlay_panel(Rect2(20, 150, 230, 76), "掉落【筑基丹】×1，师兄在看你。")
	var mine_id := overlay.get_instance_id()
	var row := HBoxContainer.new()
	row.position = Vector2(12, 40)
	row.add_theme_constant_override("separation", 8)
	o.add_child(row)
	var done := func(shared: bool):
		if not loot_waiting or loot_seq != my_id:
			return
		loot_waiting = false
		if overlay != null and overlay.get_instance_id() == mine_id:  # 玩家若已打开记忆/设置，不去关别人的面板
			_close_overlay()
		next_wave_timer = 0.8
		if shared:
			Mem.remember("senior", "第%d世师弟把丹药分给我" % GS.life, 3, 2)
		else:
			GS.pills += 1
			Mem.remember("senior", "第%d世师弟独吞了丹药" % GS.life, 4, -2)
		_drive_senior("loot_split", {"shared": shared})
	var b1 := _button("独吞（苟道）", func(): done.call(false), INK, BLOOD)
	var b2 := _button("分给师兄", func(): done.call(true), INK, JADE)
	b1.custom_minimum_size = Vector2(100, 20)
	b2.custom_minimum_size = Vector2(100, 20)
	row.add_child(b1)
	row.add_child(b2)
	get_tree().create_timer(6.0).timeout.connect(func(): done.call(false))


func _on_betrayal(dodged: bool) -> void:
	if mode == "play":
		Mem.learn_betrayal(GS.wave)
		Mem.remember("senior", "第%d世在第%d波背刺了师弟%s" % [GS.life, GS.wave, "，被识破" if dodged else ""], 4, -1)
		if dodged:
			caption("我记得。", "", JADE)
			get_tree().create_timer(1.2).timeout.connect(func(): if mode == "play": caption(""))


func _on_elder_burned() -> void:
	Mem.learn("elder_fears_fire")
	if mode != "play":
		return
	var res: Dictionary = await Agent.decide("elder", "burned", {"wave": GS.wave, "player_used_fire": true, "player_perks": GS.perks})
	for c in res.calls:
		if c.name == "say":
			say("elder", str(c.input.get("text", "")).substr(0, 24))
		elif c.name == "remember":
			Mem.remember("elder", str(c.input.get("text", "")), int(c.input.get("importance", 3)), int(c.input.get("valence", 0)))
	Mem.remember("elder", "被第%d世的弟子用火烧了" % GS.life, 4, -2)


func _on_hero_died() -> void:
	if mode == "story":
		story_mode.on_hero_died()
		return
	if mode != "play":
		return
	mode = "rebirth"
	GS.best_wave = max(GS.best_wave, GS.wave)
	Mem.note("第 %d 世，死于第 %d 波。" % [GS.life, GS.wave])
	get_tree().create_timer(1.0).timeout.connect(show_rebirth)


# ======================= 覆盖层 =======================

func _close_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null


func _overlay_panel(r: Rect2, title: String, dim := true) -> Panel:
	_close_overlay()
	overlay = Control.new()
	overlay.size = Vector2(W, H)
	ui.add_child(overlay)
	if dim:
		var d := ColorRect.new()
		d.color = Color(0.05, 0.04, 0.09, 0.82)
		d.size = Vector2(W, H)
		overlay.add_child(d)
	var p := _box(r, PANEL, JADE, overlay)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var l := _label(title, Vector2(10, 6), GOLD, 12, p)
	l.size = Vector2(r.size.x - 20, 30)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	return p


func show_title() -> void:
	mode = "title"
	story_layout(false)
	story_ui.clear()
	cont_btn.visible = false
	ledger.visible = false
	btn_row.visible = false
	var p := _overlay_panel(Rect2(18, 36, 234, 420), "")
	var t := _label(script_data.title, Vector2(0, 12), GOLD, 48, p, 6)
	t.size = Vector2(234, 56)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tg := _label(script_data.tagline, Vector2(0, 70), JADE, 12, p, 2)
	tg.size = Vector2(234, 14)
	tg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var info := _label("七章 · 八个结局 · 死亡即线索", Vector2(0, 90), DIM, 12, p)
	info.size = Vector2(234, 14)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var v := VBoxContainer.new()
	v.position = Vector2(22, 116)
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var reached: Array = Story.reached_chapters()
	if Story.st.get("active", false) and not Story.node().is_empty():
		v.add_child(_sized(_button("▶ 继续 · %s" % Story.chapter().title, func(): story_mode.resume(), INK, GOLD), 190, 24))
	var new_label := "新的一世（序幕：爆款视频）" if not GS.tutorial_done else ("新的一世（带着记忆）" if Story.st.mem.size() > 0 else "新的一世")
	v.add_child(_sized(_button(new_label, func():
		if not GS.tutorial_done:
			start_director(true)
		else:
			story_mode.begin_new(true), INK, GOLD if not Story.st.get("active", false) else JADE), 190, 24))
	if reached.size() > 0:
		v.add_child(_sized(_button("章节选择", _chapter_select, INK, JADE), 190, 24))
		v.add_child(_sized(_button("流程图 · 结局 %d/8 · 记忆 %d/7" % [Story.st.endings.size(), Story.st.mem.size()], func(): _flow_browser(0), INK, JADE), 190, 24))
	v.add_child(_sized(_button("修炼（挂机 · 账本）", func(): start_cultivate(-1, {}), INK, JADE), 190, 24))
	v.add_child(_sized(_button("录屏模式 · 复刻爆款视频", func(): start_director(false), INK, JADE), 190, 24))
	v.add_child(_sized(_button("设置 · Haiku 4.5 驱动", _on_cfg, INK, JADE), 190, 24))
	var cr := _label("素材 Kenney CC0 · 字体 Fusion Pixel\nAI 协议参考 OpenGameAgent", Vector2(0, 380), DIM, 12, p)
	cr.size = Vector2(234, 30)
	cr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _chapter_select() -> void:
	var p := _overlay_panel(Rect2(14, 50, 242, 380), "章节选择：从该章开头重玩（标记回到当时的状态，记忆保留）")
	var v := VBoxContainer.new()
	v.position = Vector2(10, 44)
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	var nums := ["第一章", "第二章", "第三章", "第四章", "第五章", "第六章", "第七章"]
	for i in Story.data.chapters.size():
		var ch: Dictionary = Story.data.chapters[i]
		var ok: bool = Story.reached_chapters().has(ch)
		var pr: Vector2i = Story.chapter_progress(ch)
		var b := _button("%s · %s   %d/%d" % [nums[i], ch.title, pr.x, pr.y] if ok else "%s · ？？？" % nums[i], func(): story_mode.start_chapter(i), INK, GOLD if ok else DIM)
		b.disabled = not ok
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		v.add_child(_sized(b, 222, 24))
	var back := _button("返回", show_title, INK, DIM)
	back.position = Vector2(81, 340)
	p.add_child(_sized(back, 80, 24))


func _flow_browser(i: int) -> void:
	_close_overlay()
	var reached: Array = Story.reached_chapters()
	if reached.is_empty():
		show_title()
		return
	var ch: Dictionary = reached[i % reached.size()]
	var idx: int = Story.data.chapters.find(ch)
	story_ui.show_flowchart(ch, idx, func():
		if i + 1 < reached.size():
			_flow_browser(i + 1)
		else:
			story_ui.clear()
			show_title(), "下一章 ▶" if i + 1 < reached.size() else "返回标题")


## 剧情 / 挂机两种布局
func story_layout(on: bool) -> void:
	cards_box.visible = not on
	ups_box.visible = not on
	btn_row.visible = not on
	lbl_log.visible = not on
	hint.visible = not on
	if on:
		cont_btn.visible = false
		ledger.visible = false


## 修炼：章节之间的挂机（一念逍遥），境界够了才能继续剧情
func start_cultivate(req: int, next_ch: Dictionary) -> void:
	story_ui.clear()
	start_play()
	if req >= 0:
		cont_btn.visible = true
		caption("修炼", "下一章「%s」需要【%s】" % [next_ch.get("title", ""), GS.REALMS[req]], WHITE)
		get_tree().create_timer(2.5).timeout.connect(func(): if mode == "play": caption(""))
	else:
		cont_btn.visible = false


func _sized(c: Control, w: float, h: float) -> Control:
	c.custom_minimum_size = Vector2(w, h)
	return c


func show_rebirth() -> void:
	var slots := GS.memory_slots()
	var p := _overlay_panel(Rect2(14, 60, 242, 360), "第 %d 世 · 终\n最远第 %d 波。选 %d 条记忆带进下一世：" % [GS.life, GS.best_wave, slots])
	var chosen := []
	var v := VBoxContainer.new()
	v.position = Vector2(10, 52)
	v.add_theme_constant_override("separation", 3)
	p.add_child(v)
	var ids: Array = Mem.library.keys()
	if ids.is_empty():
		_label("（这一世什么都没记住。下一世留意师兄、长老和第 5 波。）", Vector2(10, 60), DIM, 12, p).autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	for id in ids.slice(0, 9):
		var c: Dictionary = Mem.card(id)
		var b := _button("☐ %s\n   %s" % [c.text, c.hint], func(): pass, INK, JADE)
		b.custom_minimum_size = Vector2(222, 30)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func():
			if chosen.has(id):
				chosen.erase(id)
			elif chosen.size() < slots:
				chosen.append(id)
			b.text = ("☑ " if chosen.has(id) else "☐ ") + "%s\n   %s" % [c.text, c.hint])
		v.add_child(b)
	var go := _button("轮回 → 第 %d 世" % (GS.life + 1), func():
		GS.reincarnate(chosen)
		start_play(), INK, GOLD)
	go.position = Vector2(46, 322)
	go.custom_minimum_size = Vector2(150, 26)
	p.add_child(go)


func _on_mem_btn() -> void:
	if director:
		return
	var p := _overlay_panel(Rect2(14, 50, 242, 380), "记忆 · 第 %d 世" % GS.life)
	var lines := ["【师兄 · 好感 %d】" % int(Mem.relation("senior"))]
	for m in Mem.recall("senior", 5):
		lines.append(" %s：%s" % [m.when, m.text])
	lines.append("【长老 · 好感 %d】" % int(Mem.relation("elder")))
	for m in Mem.recall("elder", 3):
		lines.append(" %s：%s" % [m.when, m.text])
	lines.append("【已领悟记忆卡】")
	for id in Mem.library:
		lines.append(" %s%s" % ["★" if Mem.carried.has(id) else "·", Mem.card(id).text])
	lines.append("【编年史】")
	for e in Mem.recent(6):
		lines.append(" " + e)
	var l := _label("\n".join(lines), Vector2(10, 26), WHITE, 12, p)
	l.size = Vector2(222, 310)
	l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	l.clip_text = true
	var close := _button("关闭", func():
		_close_overlay(), INK, GOLD)
	close.position = Vector2(90, 346)
	close.custom_minimum_size = Vector2(60, 22)
	p.add_child(close)
	GS.paused = false


func _on_cfg() -> void:
	if director:
		return
	var back_to_title := mode == "title"
	var p := _overlay_panel(Rect2(14, 70, 242, 320), "角色驱动：Claude Haiku 4.5\n填入你自己的 Anthropic API key（只存本机）。不填 = 离线规则 AI。")
	var le := LineEdit.new()
	le.position = Vector2(10, 60)
	le.size = Vector2(222, 22)
	le.secret = true
	le.placeholder_text = "sk-ant-..."
	le.text = GS.driver_key
	le.add_theme_font_override("font", font)
	le.add_theme_font_size_override("font_size", 12)
	p.add_child(le)
	var status := _label("当前：" + Agent.driver_label() + ("" if Agent.last_error == "" else "\n上次错误：" + Agent.last_error.substr(0, 60)), Vector2(10, 90), DIM, 12, p)
	status.size = Vector2(222, 40)
	status.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var v := VBoxContainer.new()
	v.position = Vector2(30, 140)
	v.add_theme_constant_override("separation", 5)
	p.add_child(v)
	if Agent.account_ai_available():
		var on := Agent.account_ai_enabled()
		v.add_child(_sized(_button(("✔ " if on else "") + "用我的 Claude 账号驱动（免 key）", func():
			Agent.set_account_ai(not Agent.account_ai_enabled())
			lbl_driver.text = "角色驱动：" + Agent.driver_label()
			_on_cfg(), INK, GOLD), 180, 22))
	if OS.has_feature("web"):
		v.add_child(_sized(_button("用浏览器输入框填写（手机推荐）", func():
			var k = JavaScriptBridge.eval("window.prompt('Anthropic API key (sk-ant-...)') || ''")
			if typeof(k) == TYPE_STRING and k != "":
				le.text = k, INK, JADE), 180, 22))
	v.add_child(_sized(_button("保存", func():
		GS.driver_key = le.text.strip_edges()
		GS.save_game()
		lbl_driver.text = "角色驱动：" + Agent.driver_label()
		if back_to_title: show_title()
		else: _close_overlay(), INK, GOLD), 180, 22))
	v.add_child(_sized(_button("清空存档（保留 key）", func():
		GS.wipe()
		show_title(), INK, BLOOD), 180, 22))
	v.add_child(_sized(_button("返回", func():
		if back_to_title: show_title()
		else: _close_overlay(), INK, DIM), 180, 22))


# ======================= 新手引导 / 录屏（复刻视频） =======================

func start_director(interactive: bool) -> void:
	_close_overlay()
	mode = "director"
	director = load("res://scripts/director.gd").new()
	add_child(director)
	director.finished.connect(_on_director_finished)
	director.begin(self, interactive)


func _on_director_finished(interactive: bool, action: String) -> void:
	director.queue_free()
	director = null
	display = {}
	for c in cards_box.get_children():
		c.queue_free()
	for c in ups_box.get_children():
		c.queue_free()
	caption("")
	if action == "record":
		start_director(false)
	elif action == "title":
		show_title()
	elif action == "play":
		story_mode.begin_new(false)
	else:
		start_play()
