extends Node2D
## 魔门人材 v2 ·「忆」—— 主场景（竖屏 270×480，×4 = 1080×1920，与爆款视频同构图）
## 上：俯视舞台（圆圈角色 / 战斗）   中：文字框   下：N 个生成选项 + 1 个自由输入框   底：忆 / 层 / 设

signal tapped(key: String)

const W := 270
const H := 480
const STAGE_Y := 18
const STAGE_H := 160
const INK := Color("14101c")
const BG := Color("1a1426")
const PANEL := Color("2c223e")
const PANEL2 := Color("221a30")
const GOLD := Color("ffd65c")
const BLOOD := Color("e23440")
const JADE := Color("5ce8c4")
const WHITE := Color("f4f0e6")
const DIM := Color("968caa")
const CN_NUM := ["零", "一", "二", "三", "四", "五", "六"]

var font: FontFile
var stage: Node2D
var ui: Control
var top_life: Label
var top_ch: Label
var metric_box: HBoxContainer
var old_metrics: Label
var text_panel: Panel
var text_lbl: RichTextLabel
var aside_lbl: Label
var choice_box: VBoxContainer
var input: LineEdit
var send_btn: Button
var bag_btn: Button
var layer_btn: Button
var set_btn: Button
var overlay: Control = null        # 当前全屏面板
var cap_layer: Control             # 导演字幕层（最上层）
var toast_box: VBoxContainer
var flash_rect: ColorRect
var tap_catcher: Button

var mode := "title"                # title | play | death | card | ending
var bag_mode := "play"             # play | awaken
var text_full := ""
var text_shown := 0.0
var typing := false
var type_speed := 38.0
var lines_log: Array = []
var breathe_taps := 0
var breathe_auto := 0.0
var shown_past := {}
var last_node_id := ""
var pending_card := {}             # 章节卡片排队
var lock_input := false            # 导演：锁住非目标输入
var gate_key := ""                 # 新手引导：只允许点这个目标
var targets := {}                  # key -> Control（导演用）
var director: Node = null
var skip_cards := false
var metric_prev := {}
var ai_badge: Label
var ov_y := 0.0                    # 导演模式：覆盖层内容整体下移，给顶部字幕让位
var quiet_banner := false
var show_badge := true
var pending_banners: Array = []


func _ready() -> void:
	font = load("res://assets/fonts/pixel.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	RenderingServer.set_default_clear_color(BG)
	stage = load("res://scripts/stage.gd").new()
	stage.font = font
	stage.position = Vector2(0, STAGE_Y)
	add_child(stage)
	stage.battle_done.connect(_on_battle_done)
	_build_ui()
	Story.node_entered.connect(_on_node)
	Story.died.connect(_on_died)
	Story.chapter_finished.connect(_on_chapter_finished)
	Story.chapter_started.connect(_on_chapter_started)
	Story.ending_reached.connect(_on_ending)
	Story.layer_found.connect(_on_layer)
	Story.frag_gained.connect(_on_frag)
	Story.metric_changed.connect(_on_metric)
	var args := OS.get_cmdline_user_args()
	if args.has("--record") or args.has("--movie"):
		start_director(false)
	elif args.has("--autotest"):
		var t = load("res://scripts/autotest.gd").new()
		add_child(t)
		t.run(self)
	elif args.has("--storydemo"):
		var sd = load("res://scripts/story_test.gd").new()
		add_child(sd)
		sd.run_demo(self)
	elif args.has("--storytest"):
		var t2 = load("res://scripts/story_test.gd").new()
		add_child(t2)
		t2.run(self)
	else:
		show_title()


# ======================= 小工具 =======================

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


func _panel(r: Rect2, fill: Color, border := INK, parent: Node = null) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	(parent if parent else ui).add_child(p)
	return p


func _button(text: String, cb: Callable, key := "", fill := PANEL2, border := JADE, size := 12) -> Button:
	var b := Button.new()
	b.text = text
	b.clip_text = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_pressed_color", GOLD)
	b.add_theme_color_override("font_disabled_color", DIM)
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill
		if st == "hover": sb.bg_color = fill.lightened(0.08)
		if st == "pressed": sb.bg_color = border.darkened(0.55)
		sb.border_color = border if st != "disabled" else DIM.darkened(0.4)
		sb.set_border_width_all(1)
		sb.content_margin_left = 5
		sb.content_margin_right = 4
		sb.content_margin_top = 1
		sb.content_margin_bottom = 2
		if st == "focus": sb.draw_center = false
		b.add_theme_stylebox_override(st, sb)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(func():
		if not _allowed(key):
			return
		Sfx.play("blip")
		cb.call()
		if key != "":
			tapped.emit(key))
	if key != "":
		targets[key] = b
	return b


func _allowed(key: String) -> bool:
	if gate_key != "":
		return key == gate_key or (gate_key == "send" and key == "input")
	return not lock_input


func press(key: String) -> bool:
	## 导演/自测：模拟点击某个目标（走和玩家一样的回调）
	var b = targets.get(key)
	if b == null or not is_instance_valid(b) or not b.is_visible_in_tree():
		return false
	if b is LineEdit:
		b.grab_focus()
		tapped.emit(key)
		return true
	var saved := gate_key
	var saved_lock := lock_input
	gate_key = ""
	lock_input = false
	b.emit_signal("pressed")
	gate_key = saved
	lock_input = saved_lock
	return true


func press_as_player(key: String) -> bool:
	## 自测：像玩家一样点（受新手引导 gate 限制）
	var b = targets.get(key)
	if b == null or not is_instance_valid(b) or not b.is_visible_in_tree():
		return false
	if b is LineEdit:
		if _allowed(key):
			b.grab_focus()
			tapped.emit(key)
		return true
	b.emit_signal("pressed")
	return true


func target_rect(key: String) -> Rect2:
	var b = targets.get(key)
	if b == null or not is_instance_valid(b):
		return Rect2()
	return b.get_global_rect()


func toast(text: String, color := JADE, dur := 2.2) -> void:
	var l := _label(text, Vector2.ZERO, color, 12, toast_box, 2)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(W - 20, 14)
	var tw := create_tween()
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func do_flash(c: Color, t := 0.4) -> void:
	flash_rect.color = Color(c, 0.55)
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, t)


# ======================= UI 构建 =======================

func _build_ui() -> void:
	ui = Control.new()
	ui.size = Vector2(W, H)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cl := CanvasLayer.new()
	add_child(cl)
	cl.add_child(ui)
	# 顶栏
	var top := _panel(Rect2(0, 0, W, STAGE_Y), INK, INK)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_life = _label("第99世", Vector2(4, 2), GOLD)
	top_ch = _label("", Vector2(62, 2), WHITE)
	metric_box = HBoxContainer.new()
	metric_box.position = Vector2(150, 1)
	metric_box.size = Vector2(118, 16)
	metric_box.alignment = BoxContainer.ALIGNMENT_END
	metric_box.add_theme_constant_override("separation", 5)
	metric_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(metric_box)
	old_metrics = _label("", Vector2(120, STAGE_Y + 2), DIM, 12, null, 2)
	old_metrics.custom_minimum_size = Vector2(146, 12)
	old_metrics.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 舞台透明点击层（点一下继续）
	tap_catcher = _button("", func(): _tap_continue(), "cont", Color(0, 0, 0, 0), Color(0, 0, 0, 0))
	tap_catcher.position = Vector2(0, STAGE_Y)
	tap_catcher.size = Vector2(W, STAGE_H + 124)
	ui.add_child(tap_catcher)
	# 文字框
	text_panel = _panel(Rect2(3, STAGE_Y + STAGE_H + 2, W - 6, 106), PANEL2, DIM.darkened(0.3))
	text_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_lbl = RichTextLabel.new()
	text_lbl.bbcode_enabled = true
	text_lbl.scroll_active = true
	text_lbl.scroll_following = true
	text_lbl.get_v_scroll_bar().modulate.a = 0.0
	text_lbl.position = Vector2(6, 4)
	text_lbl.size = Vector2(W - 18, 98)
	text_lbl.add_theme_font_override("normal_font", font)
	text_lbl.add_theme_font_size_override("normal_font_size", 12)
	text_lbl.add_theme_color_override("default_color", WHITE)
	text_lbl.add_theme_constant_override("line_separation", 3)
	text_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_panel.add_child(text_lbl)
	aside_lbl = _label("", Vector2(6, STAGE_Y + STAGE_H + 109), GOLD)
	ai_badge = _label("", Vector2(W - 70, STAGE_Y + STAGE_H - 14), JADE, 12, null, 2)
	ai_badge.custom_minimum_size = Vector2(64, 12)
	ai_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# 选项
	choice_box = VBoxContainer.new()
	choice_box.position = Vector2(6, 304)
	choice_box.size = Vector2(W - 12, 116)
	choice_box.add_theme_constant_override("separation", 3)
	ui.add_child(choice_box)
	# 自由输入
	input = LineEdit.new()
	input.position = Vector2(6, 424)
	input.size = Vector2(W - 54, 22)
	input.placeholder_text = "自己说点什么…"
	input.add_theme_font_override("font", font)
	input.add_theme_font_size_override("font_size", 12)
	input.add_theme_color_override("font_color", WHITE)
	input.add_theme_color_override("font_placeholder_color", DIM)
	var isb := StyleBoxFlat.new()
	isb.bg_color = INK
	isb.border_color = GOLD.darkened(0.3)
	isb.set_border_width_all(1)
	isb.content_margin_left = 4
	input.add_theme_stylebox_override("normal", isb)
	input.add_theme_stylebox_override("focus", isb)
	input.text_submitted.connect(func(_t): if _allowed("send"): _send_free())
	input.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			if not _allowed("input"):
				input.accept_event()
			else:
				tapped.emit("input"))
	ui.add_child(input)
	targets["input"] = input
	send_btn = _button("说", func(): _send_free(), "send", INK, GOLD)
	send_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	send_btn.position = Vector2(W - 46, 424)
	send_btn.size = Vector2(40, 22)
	ui.add_child(send_btn)
	# 底栏
	var bot := _panel(Rect2(0, 452, W, 28), INK, INK)
	bot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_btn = _button("忆 · 记忆", func(): open_bag("play"), "bag_btn", PANEL2, GOLD)
	bag_btn.position = Vector2(4, 455)
	bag_btn.size = Vector2(96, 22)
	layer_btn = _button("层 · 真相", func(): open_layers(), "layer_btn", PANEL2, DIM)
	layer_btn.position = Vector2(104, 455)
	layer_btn.size = Vector2(96, 22)
	set_btn = _button("设", func(): open_settings(), "set_btn", PANEL2, DIM)
	set_btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
	set_btn.position = Vector2(204, 455)
	set_btn.size = Vector2(62, 22)
	for b in [bag_btn, layer_btn, set_btn]:
		ui.add_child(b)
	toast_box = VBoxContainer.new()
	toast_box.position = Vector2(10, STAGE_Y + 124)
	toast_box.size = Vector2(W - 20, 30)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(toast_box)
	flash_rect = ColorRect.new()
	flash_rect.size = Vector2(W, H)
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(flash_rect)
	var cl2 := CanvasLayer.new()
	cl2.layer = 5
	add_child(cl2)
	cap_layer = Control.new()
	cap_layer.size = Vector2(W, H)
	cap_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl2.add_child(cap_layer)
	_play_chrome(false)


func _play_chrome(on: bool) -> void:
	for c in [text_panel, choice_box, input, send_btn, bag_btn, layer_btn, set_btn, metric_box, old_metrics, top_life, top_ch, aside_lbl, ai_badge]:
		c.visible = on


# ======================= 标题 =======================

func show_title() -> void:
	mode = "title"
	_close_overlay()
	_play_chrome(false)
	stage.set_scene("forest")
	stage.actors.clear()
	stage.set_cast(["me", "lihan", "elder"])
	Sfx.music(true)
	var o := _overlay(Color(0.1, 0.08, 0.15, 0.55))
	var t := _label("魔门人材", Vector2(0, 56), GOLD, 36, o, 4)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(W, 40)
	var s := _label("· 忆 ·", Vector2(0, 100), WHITE, 24, o, 3)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.custom_minimum_size = Vector2(W, 26)
	var s2 := _label("死一次，记住一件事。", Vector2(0, 196), DIM, 12, o, 2)
	s2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s2.custom_minimum_size = Vector2(W, 14)
	var y := 250.0
	if not GS.tutorial_done:
		_obtn(o, "开始（新手引导）", func(): start_director(true), y, "t_tutorial", GOLD); y += 34
	if GS.has_game:
		_obtn(o, "继续 · 第%d世" % Story.life, func(): continue_game(), y, "t_continue", GOLD); y += 34
	if GS.tutorial_done:
		_obtn(o, "新的轮回（清空重来）", func(): new_game_confirm(), y, "t_new"); y += 34
		_obtn(o, "重看新手引导", func(): start_director(true), y, "t_tutorial"); y += 34
	_obtn(o, "录屏模式 · 复刻爆款视频", func(): start_director(false), y, "t_record", JADE); y += 34
	_obtn(o, "设置 / AI 驱动", func(): open_settings(), y, "t_settings", DIM)
	var v := _label("v2 · Godot 4.4 · 角色驱动：" + Agent.driver_label(), Vector2(0, 462), DIM, 12, o)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.custom_minimum_size = Vector2(W, 12)


func _obtn(o: Control, text: String, cb: Callable, y: float, key := "", border := JADE) -> Button:
	var b := _button(text, cb, key, PANEL2, border)
	b.alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.position = Vector2(40, y)
	b.size = Vector2(W - 80, 26)
	o.add_child(b)
	return b


func new_game_confirm() -> void:
	GS.has_game = false
	Story.new_game(99)
	GS.has_game = true
	_close_overlay()
	begin_play()
	Story.begin_life()


func continue_game() -> void:
	_close_overlay()
	begin_play()
	if Story.cur == "" or not Story.nodes.has(Story.cur):
		Story.begin_life()
	else:
		var n := Story.node()
		if n.has("death"):
			_on_died(n)
		else:
			_on_node(n)


func begin_play() -> void:
	mode = "play"
	_play_chrome(true)
	Sfx.music(true)
	_refresh_top()


# ======================= 节点显示 =======================

func _on_node(n: Dictionary) -> void:
	if mode == "title":
		return
	last_node_id = n.id
	if n.has("scene"):
		stage.set_scene(n.scene)
	elif Story.chapter().has("scene") and stage.scene_id == "":
		stage.set_scene(Story.chapter().scene)
	if n.has("cast"):
		stage.set_cast(n.cast)
	aside_lbl.text = ""
	ai_badge.text = ""
	ai_badge.visible = show_badge
	for k in stage.actors:
		stage.actors[k].think = ""
		stage.actors[k].mark = ""
	breathe_taps = 0
	breathe_auto = 0.0
	_refresh_top()
	_set_text(n.get("text", []))
	_past_life_glance(n)
	_build_choices()
	if n.has("battle"):
		_start_battle(n)
	if not GS.isolated or OS.get_cmdline_user_args().has("--autotest"):
		GS.has_game = true
		GS.save_game()


func _fmt_line(l: String) -> String:
	var i := l.find("：")
	if i > 0 and i <= 5 and not l.begins_with("（"):
		var who := l.substr(0, i)
		var col := WHITE
		for k in Story.D.cast:
			if Story.D.cast[k].name == who or who.begins_with(Story.D.cast[k].name):
				col = Color(Story.D.cast[k].color)
		return "[color=#%s]%s[/color]：%s" % [col.to_html(false), who, l.substr(i + 1)]
	if l.begins_with("（"):
		return "[color=#968caa]%s[/color]" % l
	return l


func _set_text(lines: Array) -> void:
	lines_log = lines.duplicate()
	var bb := "\n".join(lines.map(func(l): return _fmt_line(str(l))))
	text_lbl.text = bb
	text_lbl.visible_characters = 0
	text_full = text_lbl.get_parsed_text()
	text_shown = 0.0
	typing = true


func append_line(l: String) -> void:
	lines_log.append(l)
	while lines_log.size() > 7:
		lines_log.pop_front()
	var already := text_lbl.get_parsed_text().length() if not typing else int(text_shown)
	text_lbl.text = "\n".join(lines_log.map(func(x): return _fmt_line(str(x))))
	text_full = text_lbl.get_parsed_text()
	text_shown = float(mini(already, text_full.length() - l.length() - 1))
	text_shown = maxf(0.0, text_shown)
	typing = true


func _past_life_glance(n: Dictionary) -> void:
	var npc: String = n.get("npc", "")
	if npc == "" or shown_past.get(npc, -1) == Story.life:
		return
	var e := Mem.strongest_past(npc)
	if e.is_empty():
		return
	shown_past[npc] = Story.life
	var name: String = Story.D.cast[npc].name
	var how := "像在看一个仇人" if int(e.valence) < 0 else "像在看一个很久以前的朋友"
	append_line("（%s看你的眼神，%s。）" % [name, how])
	stage.think(npc, "……")


func _build_choices() -> void:
	for c in choice_box.get_children():
		c.queue_free()
	for k in targets.keys():
		if str(k).begins_with("choice:") or k == "breathe":
			targets.erase(k)
	var n := Story.node()
	var has_choices := n.has("choices") and mode == "play"
	input.editable = has_choices and n.has("npc")
	input.placeholder_text = "对%s说点什么…" % Story.D.cast[n.npc].name if n.has("npc") else "（此刻没人可说话）"
	send_btn.disabled = not input.editable
	if not has_choices:
		return
	if n.get("ui", "") == "breathe":
		var bb := _button("吐 纳", func(): _breathe(), "breathe", INK, GOLD, 12)
		bb.alignment = HORIZONTAL_ALIGNMENT_CENTER
		bb.custom_minimum_size = Vector2(0, 30)
		choice_box.add_child(bb)
	var chs := Story.choices()
	var texts := Agent.offline_options(chs)
	for c in chs:
		var hidden: bool = c.get("req", {}).has("frag")
		var t: String = ("◆ " + str(c.text[0])) if hidden else ("▸ " + str(texts[c.id]))
		var b := _button(t, func(): _choose(c.id), "choice:" + c.id, PANEL if hidden else PANEL2, GOLD if hidden else JADE)
		b.custom_minimum_size = Vector2(0, 22)
		if hidden:
			b.add_theme_color_override("font_color", GOLD)
		choice_box.add_child(b)
	# 有能用的记忆 → 轻轻提示（只说「似曾相识」，不说是哪一片）
	var usable := false
	for f in n.get("hook", []):
		if Story.is_usable(f) and not Story.used_here.has(f) and _frag_would_reveal(f):
			usable = true
	aside_lbl.text = "◆ 这一幕……似曾相识。（打开「忆」）" if usable else ""
	if n.has("npc") and Agent.ai_live():
		_ai_options(n.id, n.npc, chs)


func _frag_would_reveal(f: String) -> bool:
	for c in Story.node().get("choices", []):
		if c.get("req", {}).get("frag", "") == f:
			var r: Dictionary = c.req.duplicate()
			r.erase("frag")
			if Story.cond(r):
				return true
	return false


func _ai_options(nid: String, npc: String, chs: Array) -> void:
	var visible := chs.filter(func(c): return not c.get("req", {}).has("frag"))
	ai_badge.text = "AI 生成中…"
	var res: Dictionary = await Agent.offer_options(npc, visible)
	if Story.cur != nid:
		return
	for c in visible:
		var b = targets.get("choice:" + c.id)
		if b and is_instance_valid(b) and res.has(c.id):
			b.text = "▸ " + str(res[c.id])
	ai_badge.text = "选项 · " + Agent.last_driver


func _choose(cid: String) -> void:
	if mode != "play":
		return
	var c := Story.find_choice(cid)
	append_line("我：" + str(targets["choice:" + cid].text).trim_prefix("▸ ").trim_prefix("◆ "))
	Sfx.play("ok", -8.0)
	Story.choose(cid)


func _breathe() -> void:
	breathe_taps += 1
	Story.add_metric("qi", 1)
	if breathe_taps == 10:
		append_line("（呼吸自己动了起来。）")
		toast("自动吐纳", GOLD)
	if int(Story.m.get("qi", 0)) == 30:
		append_line("（胸口那道旧伤，不疼了。）")


func _tap_continue() -> void:
	if mode != "play":
		return
	if typing:
		text_shown = float(text_full.length())
		return
	var n := Story.node()
	if n.has("auto"):
		Story.advance()
	elif n.has("chapter_end") and pending_card.is_empty():
		Story.advance()


# ======================= 自由输入 =======================

func _send_free() -> void:
	var n := Story.node()
	var t := input.text.strip_edges()
	if t == "" or not n.has("npc") or not n.has("choices") or mode != "play":
		return
	input.text = ""
	input.release_focus()
	append_line("我：" + t)
	send_btn.disabled = true
	var npc: String = n.npc
	var nid: String = n.id
	var r: Dictionary = await Agent.interpret(npc, t, Story.free_candidates(), n.get("tease", {}), n.get("other", []))
	send_btn.disabled = false
	if Story.cur != nid:
		return
	ai_badge.text = "回应 · " + str(r.get("driver", Agent.last_driver))
	var cid: String = r.get("choice_id", "")
	if cid != "":
		var c := Story.find_choice(cid)
		var f: String = c.get("req", {}).get("frag", "")
		if f != "":
			_reveal_fx(f)
			await get_tree().create_timer(0.9).timeout
		if str(r.get("reply", "")) != "":
			append_line(Story.D.cast[npc].name + "：" + str(r.reply))
			await get_tree().create_timer(1.0).timeout
		if Story.cur == nid:
			Story.choose(cid)
		return
	append_line(str(r.get("reply", "……")) if str(r.get("reply", "")).contains("：") else Story.D.cast[npc].name + "：" + str(r.get("reply", "……")))
	if r.get("tease", false) or Agent.ai_live():
		stage.flicker(npc, 1.4)
		stage.think(npc, "？？？")
		Sfx.play("heart")
	Mem.note("玩家说：" + t)


func _reveal_fx(f: String) -> void:
	Sfx.play("reveal")
	do_flash(GOLD, 0.5)
	toast("◆ 你想起了「%s」" % Story.frag(f).title, GOLD, 2.0)


# ======================= 数值（每章一个，不解释） =======================

func _refresh_top() -> void:
	top_life.text = "第%d世" % Story.life
	var ch := Story.chapter()
	top_ch.text = "%s·%s" % [CN_NUM[Story.ch], ch.get("title", "")] if not ch.is_empty() else ""
	for c in metric_box.get_children():
		c.queue_free()
	# 本章数值在顶栏（亮）；旧章数值挪到舞台右上角一行暗字——还在，但不再重要
	var old := []
	for n in range(1, Story.ch + 1):
		var k := Story.metric_key(n)
		if not Story.m.has(k):
			continue
		var txt := "%s%d" % [Story.D.metrics[k].glyph, int(Story.m[k])]
		if n == Story.ch:
			var l := Label.new()
			l.text = txt
			l.add_theme_font_override("font", font)
			l.add_theme_font_size_override("font_size", 12)
			l.add_theme_color_override("font_color", GOLD)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			metric_box.add_child(l)
		else:
			old.append(txt)
	old_metrics.text = " ".join(old)


func _on_metric(k: String, d: int) -> void:
	_refresh_top()
	if d == 0 or mode == "title":
		return
	var cur := k == Story.metric_key()
	var l := _label(("+%d" if d > 0 else "%d") % d, Vector2(236, 16), (GOLD if d > 0 else BLOOD) if cur else DIM, 12, null, 2)
	var tw := create_tween()
	tw.tween_property(l, "position:y", 30.0, 0.7)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.7)
	tw.tween_callback(l.queue_free)
	if cur and d > 0:
		Sfx.play("coin", -10.0)


# ======================= 战斗 =======================

func _start_battle(n: Dictionary) -> void:
	var b: Dictionary = n.battle
	var r0 := {}
	for r in b.outcomes:
		if r.has("if") and r["if"].has("skill"):
			continue
		if Story.cond(r.get("if")):
			r0 = r
			break
	var cfg := {"kind": b.kind, "foes": int(b.get("foes", 0)), "allies": [], "betray": bool(r0.get("betray", false)),
		"tactic": "assist", "end_after_betray": true}
	if director and director.battle_speed > 0:
		cfg["speed"] = director.battle_speed
	var allowed: Array = r0.get("tactics", ["assist"])
	for a in b.get("allies", []):
		if a != "remembered" and stage.actors.has(a):
			cfg.allies.append(a)
	if b.has("rival"):
		cfg["rival"] = b.rival
	if b.kind == "ritual" and r0.get("tactics", []).has("guard"):
		cfg["allies_join"] = _remembered_people()
		cfg["protect_me"] = true
	if b.kind == "hunt" and not cfg.betray:
		cfg["protect_me"] = true
	_build_stance()
	if cfg.allies.size() > 0:
		var who: String = cfg.allies[0]
		var dec: Dictionary = await Agent.battle_tactic(who, allowed, {"battle": b.kind, "foes": cfg.foes})
		cfg.tactic = dec.tactic if dec.tactic != "betray" else "guard"  # 要背刺的人，会先贴到你身后
		stage.say(who, str(dec.say), 1.8)
	stage.start_battle(cfg)


func _remembered_people() -> Array:
	var out := []
	var f: Array = Story.flags
	if f.has("ally_lihan") or f.has("lihan_lives") or f.has("c5_lh"): out.append("lihan")
	if f.has("saved_xiaoman"): out.append("xiaoman")
	if f.has("suqing_ally") or f.has("c5_sq"): out.append("suqing")
	if f.has("elder_owes") or f.has("lihan_vouch"): out.append("mute")
	return out


func _build_stance() -> void:
	for c in choice_box.get_children():
		c.queue_free()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	choice_box.add_child(row)
	for s in [["攻", "atk"], ["守", "def"], ["退", "flee"]]:
		var b := _button(s[0], func(): _set_stance(s[1]), "stance:" + s[1], INK, BLOOD if s[1] == "atk" else (GOLD if s[1] == "def" else DIM), 12)
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.custom_minimum_size = Vector2(82, 30)
		row.add_child(b)
	var tip := _label("战斗中 · 随时切换姿态", Vector2.ZERO, DIM, 12, choice_box)
	tip.custom_minimum_size = Vector2(0, 14)


func _set_stance(s: String) -> void:
	stage.set_stance(s)
	for k in ["atk", "def", "flee"]:
		var b = targets.get("stance:" + k)
		if b and is_instance_valid(b):
			b.modulate = Color(1, 1, 1) if k == s else Color(0.6, 0.6, 0.6)


func _on_battle_done(skill: bool) -> void:
	if Story.node().has("battle"):
		Story.finish_battle(skill)


# ======================= 死亡 → 记忆 =======================

func _on_died(n: Dictionary) -> void:
	if mode == "title":
		return
	mode = "death"
	Sfx.play("death")
	stage.kill("me")
	stage.shake = 0.5
	do_flash(BLOOD, 0.6)
	await get_tree().create_timer(0.35).timeout
	if Story.cur != n.id:
		return
	_show_death(n)


func _show_death(n: Dictionary, after := "") -> void:
	var o := _overlay(Color(0.16, 0.02, 0.05, 0.93))
	var y := 60.0 + ov_y * 0.6
	var t := _label("你死了", Vector2(0, y), BLOOD, 24, o, 3)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(W, 26)
	var t2 := _label("第%d世 · 第%s章" % [Story.life, CN_NUM[Story.ch]], Vector2(0, y + 30), DIM, 12, o)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.custom_minimum_size = Vector2(W, 14)
	y += 62
	for l in n.text:
		var ll := _label(str(l), Vector2(18, y), WHITE, 12, o)
		ll.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		ll.custom_minimum_size = Vector2(W - 36, 0)
		ll.size = Vector2(W - 36, 0)
		y += 16 * ceili(str(l).length() / 19.0) + 4
	y += 10
	if after == "":
		var h := _label("临死前，你好像想起了什么——", Vector2(18, y), DIM, 12, o)
		y += 18
		var h2 := _label("「%s」" % n.death.hint, Vector2(18, y), GOLD, 12, o)
		h2.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		h2.custom_minimum_size = Vector2(W - 36, 0)
		h2.size = Vector2(W - 36, 0)
		y += 16 * ceili(n.death.hint.length() / 18.0) + 18
		if Story.fresh.size() > 0:
			var tip := _label("记忆会随死亡散去。从背包里选出一段，铭刻它。", Vector2(18, y), WHITE, 12, o)
			tip.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
			tip.custom_minimum_size = Vector2(W - 36, 0)
			tip.size = Vector2(W - 36, 0)
			y += 40
			_obtn(o, "◆ 打开记忆背包", func(): open_bag("awaken"), y, "open_bag", GOLD)
			return
	else:
		var a := _label(after, Vector2(18, y), GOLD, 12, o)
		a.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		a.custom_minimum_size = Vector2(W - 36, 0)
		a.size = Vector2(W - 36, 0)
		y += 40
	_obtn(o, "轮回 · 第%d世（从头再活）" % (Story.life + 1), func(): _rebirth(), y, "rebirth_btn", GOLD)
	_obtn(o, "回溯 · 重来这一章", func(): _rewind(), y + 34, "rewind_btn", DIM)


func _rebirth() -> void:
	_close_overlay()
	mode = "play"
	Sfx.play("whoosh")
	stage.actors.clear()
	Story.next_life()
	do_flash(WHITE, 0.5)
	_refresh_top()
	var tw := create_tween()
	top_life.pivot_offset = Vector2(20, 7)
	tw.tween_property(top_life, "scale", Vector2(1.6, 1.6), 0.15)
	tw.tween_property(top_life, "scale", Vector2(1, 1), 0.25)


func _rewind() -> void:
	_close_overlay()
	mode = "play"
	stage.actors.clear()
	Story.rewind_chapter()


# ======================= 记忆背包 =======================

func open_bag(m := "play") -> void:
	if not _allowed("bag_btn") and m == "play" and gate_key != "bag_btn":
		return
	bag_mode = m
	var o := _overlay(Color(0.08, 0.06, 0.12, 0.97))
	var t := _label("忆 · 记忆碎片" if m == "play" else "铭刻哪一段？", Vector2(10, 22 + ov_y), GOLD, 12, o)
	var sub := _label("◆ 已铭刻（关键处可用） ◇ 本世所得 · 残影", Vector2(10, 38 + ov_y), DIM, 12, o)
	sub.add_theme_font_size_override("font_size", 12)
	sub.visible = m == "play"
	var box := VBoxContainer.new()
	box.position = Vector2(8, 56 + ov_y)
	box.size = Vector2(W - 16, 360 - ov_y)
	box.add_theme_constant_override("separation", 3)
	o.add_child(box)
	var ids := Story.frag_log.keys()
	ids.sort_custom(func(a, b): return _frag_order(a) < _frag_order(b))
	if ids.is_empty():
		_label("（还什么都不记得。）", Vector2.ZERO, DIM, 12, box)
	for fid in ids:
		var st := _frag_state(fid)
		var mark: String = {"awake": "◆", "fresh": "◇", "ghost": "·"}[st]
		var col: Color = {"awake": GOLD, "fresh": WHITE, "ghost": DIM}[st]
		var info: Dictionary = Story.frag_log[fid]
		var b := _button("%s %s  第%d世" % [mark, Story.frag(fid).title, int(info.life)], func(): _frag_detail(fid), "frag:" + fid,
			PANEL2, col if st != "ghost" else DIM.darkened(0.3))
		b.add_theme_color_override("font_color", col)
		b.custom_minimum_size = Vector2(0, 22)
		if m == "awaken" and st != "fresh":
			b.modulate = Color(1, 1, 1, 0.45)
		box.add_child(b)
	if m == "play":
		var cb := _obtn(o, "返回", func(): _close_overlay(), 420, "bag_close", DIM)
		cb.size.x = W - 80


func _frag_order(fid: String) -> int:
	var st := _frag_state(fid)
	return {"fresh": 0, "awake": 1, "ghost": 2}[st] * 100 + int(Story.frag(fid).get("ch", 0))


func _frag_state(fid: String) -> String:
	if Story.awake.has(fid):
		return "awake"
	if Story.fresh.has(fid):
		return "fresh"
	return "ghost"


func _frag_detail(fid: String) -> void:
	var o := _overlay(Color(0.08, 0.06, 0.12, 0.98))
	var f := Story.frag(fid)
	var st := _frag_state(fid)
	var info: Dictionary = Story.frag_log.get(fid, {"life": Story.life, "ch": Story.ch})
	var oy := ov_y
	_label({"awake": "◆ 已铭刻", "fresh": "◇ 本世所得 · 未铭刻", "ghost": "· 残影（曾经知道，已经忘了）"}[st], Vector2(14, 40 + oy), GOLD if st == "awake" else DIM, 12, o)
	_label(f.title, Vector2(14, 60 + oy), WHITE, 24, o, 2)
	var tx := _label(f.text if st != "ghost" else _ghostify(f.text), Vector2(14, 96 + oy), WHITE if st != "ghost" else DIM, 12, o)
	tx.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	tx.custom_minimum_size = Vector2(W - 28, 0)
	tx.size = Vector2(W - 28, 0)
	_label("得于 第%d世 · 第%s章" % [int(info.life), CN_NUM[int(info.ch)]], Vector2(14, 170 + oy), DIM, 12, o)
	var y := 220.0 + oy
	if bag_mode == "awaken" and st == "fresh":
		_obtn(o, "◆ 铭刻（带进下一世）", func(): _do_awaken(fid), y, "awaken_btn", GOLD)
		y += 34
	elif bag_mode == "play" and st == "awake" and Story.node().has("choices") and mode == "play":
		_obtn(o, "◆ 此刻想起它", func(): _do_use(fid), y, "use_btn", GOLD)
		y += 34
	elif st == "fresh":
		_label("死亡时才能铭刻。没铭刻的，下一世就忘了。", Vector2(14, y), DIM, 12, o)
		y += 30
	_obtn(o, "返回", func(): open_bag(bag_mode), y, "detail_back", DIM)


func _ghostify(t: String) -> String:
	var out := ""
	for i in t.length():
		out += t[i] if (i % 3 == 0 or t[i] in "，。「」：") else "…"
	return out


func _do_awaken(fid: String) -> void:
	if not Story.awaken(fid):
		return
	Sfx.play("awaken")
	do_flash(GOLD, 0.6)
	_close_overlay()
	GS.save_game()
	_show_death(Story.last_death, "「%s」铭刻了。\n它会跟着你，到下一世。" % Story.frag(fid).title)


func _do_use(fid: String) -> void:
	var r := Story.use_frag(fid)
	_close_overlay()
	match r:
		"reveal":
			_reveal_fx(fid)
			_build_choices()
			var b = targets.get(_hidden_key_for(fid))
			if b and is_instance_valid(b):
				b.modulate = Color(1, 1, 1, 0)
				create_tween().tween_property(b, "modulate:a", 1.0, 0.5)
		"known":
			toast("你已经想起过它了。", DIM)
		_:
			Sfx.play("wrong")
			toast("……不是这段记忆。", DIM)


func _hidden_key_for(fid: String) -> String:
	for c in Story.node().get("choices", []):
		if c.get("req", {}).get("frag", "") == fid:
			return "choice:" + c.id
	return ""


# ======================= 层 / 设置 =======================

func open_layers() -> void:
	var o := _overlay(Color(0.08, 0.06, 0.12, 0.97))
	_label("层 · 每一章都藏着不止一层", Vector2(10, 22), GOLD, 12, o)
	var total := 0
	var found := 0
	var y := 44.0
	for c in Story.D.chapters:
		var n := int(c.n)
		var reached := n <= Story.ch or Story.layers.any(func(l): return str(l).begins_with("c%d_" % n))
		var ls := Story.chapter_layers(n)
		var bar := ""
		for l in ls:
			total += 1
			if l.found:
				found += 1
			bar += "■" if l.found else "□"
		_label("第%s章 %s  %s" % [CN_NUM[n], c.title if reached else "？？？", bar], Vector2(10, y), WHITE if reached else DIM, 12, o)
		y += 16
		if reached:
			for l in ls:
				_label(("  ■ " + l.title) if l.found else "  □ ？？？", Vector2(10, y), GOLD if l.found else DIM, 12, o)
				y += 14
		y += 6
	_label("已揭开 %d/%d 层 · 第%d世 · 死过 %d 次 · 结局 %d/4" % [found, total, Story.life, Story.deaths, Story.endings.size()], Vector2(10, 410), DIM, 12, o)
	var cb := _obtn(o, "返回", func(): _close_overlay(), 430, "layers_close", DIM)


func open_settings() -> void:
	var o := _overlay(Color(0.08, 0.06, 0.12, 0.97))
	_label("设置 · AI 角色驱动", Vector2(10, 22), GOLD, 12, o)
	var d := _label("当前：" + Agent.driver_label(), Vector2(10, 44), JADE, 12, o)
	var info := _label("填入你自己的 Anthropic API key，师兄、长老等角色会由 Claude Haiku 4.5 驱动：生成选项、理解你的自由输入、决定战斗行为。key 只存在本机。不填也能完整游玩（离线规则）。", Vector2(10, 64), WHITE, 12, o)
	info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	info.custom_minimum_size = Vector2(W - 20, 0)
	info.size = Vector2(W - 20, 0)
	var k := LineEdit.new()
	k.position = Vector2(10, 170)
	k.size = Vector2(W - 20, 22)
	k.secret = true
	k.placeholder_text = "sk-ant-…"
	k.text = GS.driver_key
	k.add_theme_font_override("font", font)
	k.add_theme_font_size_override("font_size", 12)
	o.add_child(k)
	_obtn(o, "保存 key", func():
		GS.driver_key = k.text.strip_edges()
		GS.save_game()
		d.text = "当前：" + Agent.driver_label(), 200, "save_key", GOLD)
	_obtn(o, "静音：" + ("开" if Sfx.muted else "关"), func():
		Sfx.muted = not Sfx.muted
		Sfx.music(not Sfx.muted)
		open_settings(), 240, "mute", DIM)
	_obtn(o, "清空存档（记忆、层、结局全部清掉）", func():
		GS.wipe()
		show_title(), 290, "wipe", BLOOD)
	_obtn(o, "回到标题", func(): show_title(), 330, "to_title", DIM)
	_obtn(o, "返回", func(): _close_overlay(), 420, "settings_close", DIM)


# ======================= 章节 / 结局 =======================

func _on_chapter_finished(n: int) -> void:
	if mode == "title":
		return
	if skip_cards:
		pending_card = {"kind": "end", "n": n}
		_show_chapter_end(n)
		return
	pending_card = {"kind": "end", "n": n}
	await get_tree().create_timer(0.6).timeout
	_show_chapter_end(n)


func _show_chapter_end(n: int) -> void:
	var o := _overlay(Color(0.05, 0.04, 0.08, 0.95))
	var t := _label("第%s章 · 完" % CN_NUM[n], Vector2(0, 110), WHITE, 24, o, 3)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(W, 26)
	var y := 150.0
	var hid := 0
	for l in Story.chapter_layers(n):
		var lb := _label(("■ " + l.title) if l.found else "□ ？？？", Vector2(60, y), GOLD if l.found else DIM, 12, o)
		if not l.found:
			hid += 1
		y += 18
	var tip := _label("还有 %d 层没被看见。" % hid if hid > 0 else "这一章，你看透了。", Vector2(0, y + 16), BLOOD if hid > 0 else JADE, 12, o)
	tip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tip.custom_minimum_size = Vector2(W, 14)
	_obtn(o, "继续", func():
		pending_card = {}
		_close_overlay()
		Story.advance(), 380, "card_next", GOLD)


func _on_chapter_started(n: int) -> void:
	_refresh_top()
	if skip_cards or mode == "title":
		return
	var c := Story.chapter(n)
	var mk: String = c.metric
	Sfx.play("door", -6.0)
	var o := _overlay(Color(0.05, 0.04, 0.08, 0.92))
	var t := _label("第%s章" % CN_NUM[n], Vector2(0, 110), DIM, 12, o)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(W, 14)
	var t2 := _label(c.title, Vector2(0, 130), WHITE, 36, o, 4)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.custom_minimum_size = Vector2(W, 40)
	var t3 := _label(c.conflict, Vector2(0, 186), GOLD, 12, o)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t3.custom_minimum_size = Vector2(W, 14)
	var bar := ""
	for l in Story.chapter_layers(n):
		bar += "■" if l.found else "□"
	var t4 := _label(bar, Vector2(0, 210), GOLD, 12, o)
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t4.custom_minimum_size = Vector2(W, 14)
	var g := _label(Story.D.metrics[mk].glyph, Vector2(0, 250), GOLD, 36, o, 3)
	g.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	g.custom_minimum_size = Vector2(W, 40)
	g.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_property(g, "modulate:a", 1.0, 0.6)
	var t5 := _label("（一个新的数字出现了。）" if n > 1 else "（你只有一个数字。）", Vector2(0, 296), DIM, 12, o)
	t5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t5.custom_minimum_size = Vector2(W, 14)
	_obtn(o, "开始", func(): _close_overlay(), 380, "card_start", GOLD)


func _on_ending(eid: String) -> void:
	await get_tree().create_timer(2.5).timeout
	if Story.cur == "" or not Story.node().has("ending"):
		return
	mode = "ending"
	var e: Dictionary = Story.D.endings[eid]
	var o := _overlay(Color(0.03, 0.02, 0.05, 0.95))
	var t := _label("结局", Vector2(0, 80), DIM, 12, o)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(W, 14)
	var t2 := _label(e.title, Vector2(0, 100), GOLD if e.get("true", false) else WHITE, 36, o, 4)
	t2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t2.custom_minimum_size = Vector2(W, 40)
	var t3 := _label(e.sub, Vector2(0, 150), WHITE, 12, o)
	t3.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t3.custom_minimum_size = Vector2(W, 14)
	var found := Story.layers.size()
	var t4 := _label("已揭开 %d/%d 层真相 · 结局 %d/4" % [found, Story.all_layers.size(), Story.endings.size()], Vector2(0, 200), DIM, 12, o)
	t4.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t4.custom_minimum_size = Vector2(W, 14)
	if not e.get("true", false):
		var t5 := _label("有些事，这一世的你还不知道。", Vector2(0, 230), BLOOD, 12, o)
		t5.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		t5.custom_minimum_size = Vector2(W, 14)
	_obtn(o, "轮回 · 第%d世" % (Story.life + 1), func(): _rebirth(), 330, "ending_rebirth", GOLD)
	_obtn(o, "回到标题", func(): show_title(), 364, "ending_title", DIM)


func _on_layer(lid: String) -> void:
	if mode == "title":
		return
	Sfx.play("reveal")
	var chn := int(lid.substr(1, 1))
	var ls := Story.chapter_layers(chn)
	var idx := 0
	var bar := ""
	for i in ls.size():
		bar += "■" if ls[i].found else "□"
		if ls[i].id == lid:
			idx = i + 1
	var title := ""
	for l in ls:
		if l.id == lid:
			title = l.title
	if overlay and is_instance_valid(overlay):
		pending_banners.append(["第%s章 · 第%d层" % [CN_NUM[chn], idx], title, bar])
	else:
		layer_banner("第%s章 · 第%d层" % [CN_NUM[chn], idx], title, bar)


func layer_banner(head: String, title: String, bar: String) -> void:
	if quiet_banner:
		return
	var p := _panel(Rect2(10, STAGE_Y + 92, W - 20, 64), Color(0.08, 0.05, 0.1, 0.94), GOLD)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := _label(head + "  " + bar, Vector2(0, 6), GOLD, 12, p)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	a.custom_minimum_size = Vector2(W - 20, 14)
	var b := _label(title, Vector2(0, 26), WHITE, 24, p, 3)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.custom_minimum_size = Vector2(W - 20, 26)
	p.scale = Vector2(1, 0)
	p.pivot_offset = Vector2((W - 20) / 2.0, 32)
	var tw := create_tween()
	tw.tween_property(p, "scale:y", 1.0, 0.18)
	tw.tween_interval(2.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


func _on_frag(fid: String) -> void:
	if mode == "title" or Story.node().has("death"):
		return
	toast("◇ 你记下了：「%s」" % Story.frag(fid).title, WHITE, 2.4)
	var tw := create_tween()
	tw.tween_property(bag_btn, "modulate", Color(2, 2, 1), 0.15)
	tw.tween_property(bag_btn, "modulate", Color(1, 1, 1), 0.4)


# ======================= 覆盖层 =======================

func _overlay(bg: Color) -> Control:
	_close_overlay()
	var o := Control.new()
	o.size = Vector2(W, H)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	var r := ColorRect.new()
	r.size = Vector2(W, H)
	r.color = bg
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(r)
	ui.add_child(o)
	ui.move_child(flash_rect, ui.get_child_count() - 1)
	overlay = o
	return o


func _close_overlay() -> void:
	if overlay and is_instance_valid(overlay):
		overlay.queue_free()
	overlay = null
	if pending_banners.size() > 0:
		var b: Array = pending_banners.pop_front()
		get_tree().create_timer(0.3).timeout.connect(func(): layer_banner(b[0], b[1], b[2]))


# ======================= 导演（新手引导 / 录屏） =======================

func start_director(interactive: bool) -> void:
	if director and is_instance_valid(director):
		director.queue_free()
	director = load("res://scripts/director.gd").new()
	add_child(director)
	director.begin(self, interactive)


# ======================= 帧 =======================

func _process(d: float) -> void:
	if typing:
		text_shown += d * type_speed
		var n := int(text_shown)
		if n >= text_full.length():
			n = text_full.length()
			typing = false
		if n != text_lbl.visible_characters:
			text_lbl.visible_characters = n
			if n % 2 == 0:
				Sfx.play("type", -14.0)
	if mode == "play" and Story.node().get("ui", "") == "breathe" and breathe_taps >= 10:
		breathe_auto += d
		if breathe_auto >= 0.5:
			breathe_auto = 0.0
			Story.add_metric("qi", 1)
			if int(Story.m.get("qi", 0)) == 30:
				append_line("（胸口那道旧伤，不疼了。）")
