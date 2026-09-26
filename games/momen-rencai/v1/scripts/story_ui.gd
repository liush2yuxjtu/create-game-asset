extends Control
## 剧情表现层：对白框、选项、章节标题卡、《底特律》式章节流程图、结局画面
## 只负责「显示 + 收集输入」，推进逻辑在 Story（autoload）

const W := 270
const H := 480
const INK := Color("14101c")
const PANEL := Color("201a2c")
const GOLD := Color("ffd65c")
const JADE := Color("5ce8c4")
const BLOOD := Color("e23440")
const WHITE := Color("f4f0e6")
const DIM := Color("968caa")
const TYPE_COL := {"scene": Color("8a7fa0"), "choice": Color("ffd65c"), "battle": Color("e23440"), "ledger": Color("d8a23a"),
	"death": Color("b8303c"), "converge": Color("f4f0e6"), "ending": Color("c792ff"), "option": Color("5ce8c4")}
const TONE_BG := {"dark": Color("2a1215"), "warm": Color("16281f"), "bitter": Color("231f2e"), "loop": Color("1c1a20"), "true": Color("2a2210")}
const TONE_FG := {"dark": Color("e0533c"), "warm": Color("4fd1b0"), "bitter": Color("c792ff"), "loop": Color("968caa"), "true": Color("ffd65c")}

var font: Font
var sheet: Texture2D = preload("res://assets/sprites/dungeon.png")
var layer: Control
var _lines: Array = []
var _li := 0
var _on_done: Callable
var _text_lbl: Label
var _name_lbl: Label
var _portrait: TextureRect
var _typing: Tween
var _timer_bar: ColorRect
var _timer_left := 0.0
var _timer_total := 0.0
var _on_timeout: Callable
var flow_graph: Control


func setup(f: Font) -> void:
	font = f
	size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer = Control.new()
	layer.size = size
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(layer)


func clear() -> void:
	for c in layer.get_children():
		c.queue_free()
	_timer_bar = null
	_timer_total = 0.0
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if _timer_total > 0.0 and _timer_bar and is_instance_valid(_timer_bar):
		_timer_left -= delta
		_timer_bar.size.x = (W - 12) * clampf(_timer_left / _timer_total, 0, 1)
		_timer_bar.color = GOLD if _timer_left > 5 else BLOOD
		if _timer_left <= 0:
			_timer_total = 0.0
			var cb := _on_timeout
			clear()
			if cb.is_valid():
				cb.call()


# ───────────── 小工具 ─────────────

func _label(t: String, pos: Vector2, col := WHITE, sz := 12, parent: Node = null, outline := 0) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else layer).add_child(l)
	return l


func _panel(r: Rect2, fill: Color, border: Color, parent: Node = null) -> Panel:
	var p := Panel.new()
	p.position = r.position
	p.size = r.size
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(1)
	p.add_theme_stylebox_override("panel", sb)
	(parent if parent else layer).add_child(p)
	return p


func _button(t: String, cb: Callable, border := JADE, fill := INK, sz := 12) -> Button:
	var b := Button.new()
	b.text = t
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", sz)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", GOLD)
	b.add_theme_color_override("font_disabled_color", DIM)
	for s in ["normal", "hover", "pressed", "disabled"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = fill if s != "hover" else fill.lightened(0.08)
		if s == "pressed":
			sb.bg_color = border.darkened(0.55)
		sb.border_color = border if s != "disabled" else DIM.darkened(0.3)
		sb.set_border_width_all(1)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 2
		sb.content_margin_bottom = 2
		b.add_theme_stylebox_override(s, sb)
	b.pressed.connect(cb)
	return b


func _tile_tex(tile: int) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = sheet
	a.region = Rect2((tile % 12) * 16, (tile / 12) * 16, 16, 16)
	return a


func char_info(name: String) -> Dictionary:
	return Story.data.characters.get(name, {"tile": null, "color": "#f4f0e6"})


# ───────────── 对白 ─────────────

## lines: [[说话人, 台词], ...]，逐行点击推进
func show_lines(lines: Array, on_done: Callable, header := "") -> void:
	clear()
	_lines = lines
	_li = 0
	_on_done = on_done
	if lines.is_empty():
		on_done.call()
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	var box := _panel(Rect2(6, 300, W - 12, 150), PANEL, JADE.darkened(0.3))
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if header != "":
		_label(header, Vector2(10, 284), GOLD, 12, null, 3)
	_portrait = TextureRect.new()
	_portrait.position = Vector2(8, 8)
	_portrait.size = Vector2(32, 32)
	_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_portrait)
	_name_lbl = _label("", Vector2(46, 6), GOLD, 12, box)
	_text_lbl = _label("", Vector2(46, 24), WHITE, 12, box)
	_text_lbl.size = Vector2(W - 12 - 56, 110)
	_text_lbl.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	var hint := _label("▼ 点击继续", Vector2(W - 12 - 72, 132), DIM, 12, box)
	hint.name = "Hint"
	_show_line()


func _show_line() -> void:
	var ln: Array = _lines[_li]
	var who: String = ln[0]
	var ci := char_info(who)
	_name_lbl.text = "" if who == "旁白" else who
	_name_lbl.add_theme_color_override("font_color", Color(ci.get("color", "#f4f0e6")))
	_portrait.texture = _tile_tex(int(ci.tile)) if ci.get("tile") != null else null
	var is_narr := who == "旁白"
	_text_lbl.position = Vector2(46 if not is_narr or _portrait.texture else 10, 24 if not is_narr else 16)
	_text_lbl.add_theme_color_override("font_color", DIM.lightened(0.35) if is_narr else (GOLD if who == "魔种" else WHITE))
	_text_lbl.text = ln[1]
	_text_lbl.visible_ratio = 0.0
	if _typing:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text_lbl, "visible_ratio", 1.0, max(0.15, ln[1].length() / 22.0))


func _gui_input(ev: InputEvent) -> void:
	if _lines.is_empty() or _li >= _lines.size():
		return
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		next_line()


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev.pressed and not ev.echo and (ev.keycode == KEY_SPACE or ev.keycode == KEY_ENTER) and not _lines.is_empty() and _li < _lines.size():
		next_line()


func next_line() -> void:
	if _typing and _typing.is_running():
		_typing.kill()
		_text_lbl.visible_ratio = 1.0
		return
	_li += 1
	if _li >= _lines.size():
		_lines = []
		var cb := _on_done
		clear()
		cb.call()
	else:
		_show_line()


# ───────────── 选项 ─────────────

## opts: Story.options() 的结果
func show_choices(prompt: String, opts: Array, on_pick: Callable, timer := 0.0, on_timeout := Callable()) -> void:
	clear()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var n_lines := 0
	for o in opts:
		n_lines += 2 if not o.ok else 1
	var h := 30 + n_lines * 16 + opts.size() * 6
	var top: float = max(262.0, H - 10 - h)
	var box := _panel(Rect2(6, top, W - 12, H - 10 - top), PANEL, GOLD.darkened(0.3))
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	var p := _label(prompt, Vector2(8, 5), GOLD, 12, box)
	p.size = Vector2(W - 28, 16)
	p.clip_text = true
	var v := VBoxContainer.new()
	v.position = Vector2(6, 24)
	v.size = Vector2(W - 24, 0)
	v.add_theme_constant_override("separation", 4)
	box.add_child(v)
	for o in opts:
		var txt: String = ("◆ " if o.key else "") + o.label
		if not o.ok:
			txt = "锁 " + o.label + "\n   " + o.need
		var b := _button(txt, func(): on_pick.call(o.i), GOLD if o.key and o.ok else (JADE if o.ok else DIM.darkened(0.2)))
		b.disabled = not o.ok
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(W - 24, 18 if o.ok else 34)
		b.clip_text = true
		v.add_child(b)
	if timer > 0:
		_timer_total = timer
		_timer_left = timer
		_on_timeout = on_timeout
		_timer_bar = ColorRect.new()
		_timer_bar.position = Vector2(6, top - 5)
		_timer_bar.size = Vector2(W - 12, 3)
		_timer_bar.color = GOLD
		layer.add_child(_timer_bar)


# ───────────── 章节标题卡 ─────────────

func show_chapter_card(ch: Dictionary, idx: int, on_done: Callable) -> void:
	clear()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.04, 0.08, 0.96)
	bg.size = size
	layer.add_child(bg)
	var nums := ["第一章", "第二章", "第三章", "第四章", "第五章", "第六章", "第七章"]
	var a := _label(nums[idx], Vector2(0, 170), GOLD, 12, null)
	a.size = Vector2(W, 14)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := _label(ch.title, Vector2(0, 190), WHITE, 36, null, 4)
	t.size = Vector2(W, 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var s := _label(ch.subtitle, Vector2(0, 238), DIM, 12, null)
	s.size = Vector2(W, 14)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(layer, "modulate:a", 1.0, 0.35)
	tw.tween_interval(1.4)
	tw.tween_property(layer, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func():
		layer.modulate.a = 1.0
		clear()
		on_done.call())


# ───────────── 轮回记忆提示 ─────────────

func toast_memory(text: String) -> void:
	var p := _panel(Rect2(20, 120, W - 40, 48), Color("13231f"), JADE, self)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var a := _label("轮回记忆 +1", Vector2(0, 6), JADE, 12, p)
	a.size = Vector2(W - 40, 14)
	a.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var b := _label("「%s」" % text, Vector2(0, 24), WHITE, 12, p)
	b.size = Vector2(W - 40, 14)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tw := create_tween()
	tw.tween_interval(2.2)
	tw.tween_property(p, "modulate:a", 0.0, 0.4)
	tw.tween_callback(p.queue_free)


# ───────────── 《底特律》式章节流程图 ─────────────

func show_flowchart(ch: Dictionary, idx: int, on_continue: Callable, button_text := "继续") -> void:
	clear()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var bg := ColorRect.new()
	bg.color = Color("0f0d14")
	bg.size = size
	layer.add_child(bg)
	var nums := ["第一章", "第二章", "第三章", "第四章", "第五章", "第六章", "第七章"]
	_label(nums[idx] + " · " + ch.title, Vector2(10, 8), WHITE, 24, null, 3)
	var pr: Vector2i = Story.chapter_progress(ch)
	_label("流程图 · 已探索 %d / %d" % [pr.x, pr.y], Vector2(10, 40), GOLD)
	flow_graph = load("res://scripts/flow_graph.gd").new()
	flow_graph.position = Vector2(6, 60)
	flow_graph.size = Vector2(W - 12, 330)
	layer.add_child(flow_graph)
	var info := _label("点节点查看。？ = 还没走到的分支", Vector2(10, 396), DIM, 12)
	info.size = Vector2(W - 20, 34)
	info.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	flow_graph.setup(font, ch, func(t): info.text = t)
	var b := _button(button_text, on_continue, GOLD)
	b.position = Vector2(W / 2.0 - 60, 440)
	b.custom_minimum_size = Vector2(120, 26)
	layer.add_child(b)


# ───────────── 结局 ─────────────

func show_ending(n: Dictionary, on_flow: Callable, on_ng: Callable, on_title: Callable) -> void:
	clear()
	mouse_filter = Control.MOUSE_FILTER_STOP
	var tone: String = n.get("tone", "dark")
	var bg := ColorRect.new()
	bg.color = TONE_BG.get(tone, INK)
	bg.size = size
	layer.add_child(bg)
	var e := _label("结局", Vector2(0, 40), TONE_FG.get(tone, WHITE), 12)
	e.size = Vector2(W, 14)
	e.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var t := _label(n.title, Vector2(0, 60), WHITE, 36, null, 4)
	t.size = Vector2(W, 44)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var y := 130.0
	var delay := 0.4
	for ln in n.lines:
		var who: String = ln[0]
		var txt: String = ln[1] if who == "旁白" else "%s：%s" % [who, ln[1]]
		var l := _label(txt, Vector2(20, y), WHITE if who != "魔种" else GOLD, 12)
		l.size = Vector2(W - 40, 30)
		l.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
		l.modulate.a = 0.0
		create_tween().tween_property(l, "modulate:a", 1.0, 0.6).set_delay(delay)
		delay += 0.9
		y += 34
	var ep := _label(n.epilogue, Vector2(20, y + 10), TONE_FG.get(tone, WHITE), 12)
	ep.size = Vector2(W - 40, 30)
	ep.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	ep.modulate.a = 0.0
	create_tween().tween_property(ep, "modulate:a", 1.0, 0.8).set_delay(delay + 0.4)
	var got: int = Story.st.endings.size()
	var cnt := _label("已解锁结局 %d / 8 · 轮回记忆 %d / 7" % [got, Story.st.mem.size()], Vector2(0, 360), DIM, 12)
	cnt.size = Vector2(W, 14)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var v := VBoxContainer.new()
	v.position = Vector2(W / 2.0 - 90, 382)
	v.add_theme_constant_override("separation", 4)
	layer.add_child(v)
	for pair in [["看本章流程图", on_flow, JADE], ["带着记忆，重来一世", on_ng, GOLD], ["回到标题", on_title, DIM]]:
		var b := _button(pair[0], pair[1], pair[2])
		b.custom_minimum_size = Vector2(180, 24)
		v.add_child(b)
