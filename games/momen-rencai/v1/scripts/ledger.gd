extends Control
## 账本 —— Universal Paperclips 式纯文字界面（与视频 render_viral.py 的 draw_ledger 同一布局：data/viral_script.json 的 ledger_layout）
## state = {qi, rate, seeds, rows:[[名, 值]], phases:[[名, 0..1]], log:[...], pressed, caption, cursor}

signal tuna_pressed
signal row_pressed(index: int)
signal close_pressed

var font: Font
var LY: Dictionary
var state: Dictionary = {}
var show_close := true
var blink := 0.0


func setup(f: Font, layout: Dictionary) -> void:
	font = f
	LY = layout
	size = Vector2(270, 480)
	mouse_filter = Control.MOUSE_FILTER_STOP


func set_state(s: Dictionary) -> void:
	state = s
	queue_redraw()


func _process(delta: float) -> void:
	if visible:
		blink += delta
		queue_redraw()


func _c(key: String) -> Color:
	return Color(LY[key])


func _text(pos: Vector2, t: String, col: Color, sz := 12) -> void:
	draw_string(font, pos + Vector2(0, font.get_ascent(sz)), t, HORIZONTAL_ALIGNMENT_LEFT, -1, sz, col)


func _text_right(x_right: float, y: float, t: String, col: Color) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	_text(Vector2(x_right - w, y), t, col)


func _draw() -> void:
	if LY.is_empty():
		return
	var paper := _c("paper")
	var ink := _c("ink")
	var dim := _c("dim")
	var acc := _c("accent")
	draw_rect(Rect2(Vector2.ZERO, size), paper)
	_text(Vector2(LY.qi[0] + 1, LY.qi[1] + 1), "魔元：" + GS.fmt(float(state.get("qi", 0))), ink, 24)
	_text(Vector2(LY.rate[0], LY.rate[1]), "每秒 " + GS.fmt(float(state.get("rate", 0))), dim)
	if float(state.get("seeds", 0)) > 0:
		_text(Vector2(LY.seeds[0], LY.seeds[1]), "魔种 " + GS.fmt(float(state.seeds)), ink)
	var b: Array = LY.button
	var pressed := bool(state.get("pressed", false))
	draw_rect(Rect2(b[0], b[1], b[2], b[3]), ink if pressed else paper)
	draw_rect(Rect2(b[0], b[1], b[2], b[3]), ink, false, 1.0)
	_text(Vector2(b[0] + 16, b[1] + 2), "吐 纳", paper if pressed else ink)
	if state.get("cursor", false):
		var cx: float = b[0] + b[2] - 10
		var cy: float = b[1] + b[3] - 4 + (1 if pressed else 0)
		var pts := PackedVector2Array([Vector2(cx, cy), Vector2(cx, cy + 10), Vector2(cx + 3, cy + 7), Vector2(cx + 7, cy + 7)])
		draw_colored_polygon(pts, ink)
	var rows: Array = state.get("rows", [])
	if rows.size() > 0:
		_text(Vector2(LY.rows_hdr[0], LY.rows_hdr[1]), "—— 功 法 ——", dim)
		for i in rows.size():
			var y: float = LY.rows_y + i * LY.row_h
			var r: Array = rows[i]
			_text(Vector2(LY.rows_hdr[0], y), str(r[0]), ink if r.size() < 3 or r[2] else dim)
			_text_right(size.x - 12, y, str(r[1]), acc)
	var phases: Array = state.get("phases", [])
	if phases.size() > 0:
		_text(Vector2(LY.phases_hdr[0], LY.phases_hdr[1]), "—— 炼 化 ——", dim)
		var bar: Array = LY.bar
		for i in phases.size():
			var y: float = LY.phases_y + i * LY.phase_h
			var pr: float = clampf(float(phases[i][1]), 0, 1)
			_text(Vector2(LY.phases_hdr[0], y), str(phases[i][0]), ink)
			draw_rect(Rect2(bar[0], y + 4, bar[1] - bar[0] + 1, bar[2] + 1), _c("track"))
			if pr > 0:
				draw_rect(Rect2(bar[0], y + 4, (bar[1] - bar[0]) * pr + 1, bar[2] + 1), acc if pr < 1 else ink)
			_text_right(size.x - 12, y, "%d%%" % int(pr * 100) if pr < 1 else "100%", ink)
	var log: Array = state.get("log", [])
	if log.size() > 0:
		_text(Vector2(LY.log_hdr[0], LY.log_hdr[1]), "—— 纪 事 ——", dim)
		for i in log.size():
			var y: float = LY.log_y + i * LY.log_h
			var last: bool = i == log.size() - 1
			_text(Vector2(LY.log_hdr[0], y), str(log[i]), ink if last else dim)
			if last and int(blink * 3) % 2 == 0:
				var lx: float = LY.log_hdr[0] + font.get_string_size(str(log[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 2
				draw_rect(Rect2(lx, y + 2, 6, 11), ink)
	var cap := str(state.get("caption", ""))
	if cap != "":
		var lines := cap.split("\n")
		for i in lines.size():
			var w := font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
			_text(Vector2((size.x - w) / 2.0, LY.caption_y + i * 26), lines[i], ink, 24)
	if show_close:
		_text(Vector2(size.x - 44, 8), "[返回]", dim)
	if float(state.get("flash", 0)) > 0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, float(state.flash)))


func _gui_input(ev: InputEvent) -> void:
	var pos: Vector2
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pos = ev.position
	else:
		return
	accept_event()
	var b: Array = LY.button
	if Rect2(b[0] - 4, b[1] - 4, b[2] + 8, b[3] + 8).has_point(pos):
		tuna_pressed.emit()
		return
	if show_close and pos.x > size.x - 56 and pos.y < 28:
		close_pressed.emit()
		return
	var rows: Array = state.get("rows", [])
	for i in rows.size():
		var y: float = LY.rows_y + i * LY.row_h
		if pos.y >= y - 1 and pos.y < y + LY.row_h - 1:
			row_pressed.emit(i)
			return
