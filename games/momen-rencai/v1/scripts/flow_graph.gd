extends Control
## 章节流程图（游戏内）：读 story.json 里预计算好的 layout（与设计稿同一份坐标）
## 本世走过 = 亮；以前某世走过 = 暗亮；从没走到 = 剪影 + 「？」

const TYPE_COL := {"scene": Color("8a7fa0"), "choice": Color("ffd65c"), "battle": Color("e23440"), "ledger": Color("d8a23a"),
	"death": Color("b8303c"), "converge": Color("f4f0e6"), "ending": Color("c792ff"), "option": Color("5ce8c4")}

var font: Font
var ch: Dictionary
var rects := {}   # vid -> Rect2
var on_info: Callable
var sel := ""


func setup(f: Font, chapter: Dictionary, info_cb: Callable) -> void:
	font = f
	ch = chapter
	on_info = info_cb
	mouse_filter = Control.MOUSE_FILTER_STOP
	_layout()
	queue_redraw()


func _layout() -> void:
	rects.clear()
	var L: Dictionary = ch.layout
	var span := 0.0
	for v in L.nodes:
		span = max(span, absf(float(v.x)))
	var col_w: float = min(64.0, (size.x - 8) / (2.0 * span + 1.0))
	var row_h: float = min(40.0, (size.y - 8) / float(L.rows))
	var w: float = clampf(col_w - 5, 12, 56)
	var h: float = clampf(row_h * 0.55, 8, 16)
	for v in L.nodes:
		var cx: float = size.x / 2.0 + float(v.x) * col_w
		var cy: float = 4 + float(v.y) * row_h + row_h / 2.0
		var ww := w * (0.8 if v.kind == "option" else 1.0)
		rects[v.vid] = Rect2(cx - ww / 2.0, cy - h / 2.0, ww, h)


func _kind(v: Dictionary) -> String:
	if v.kind == "option":
		return "option"
	return Story.nodes[v.ref].type


func _title(v: Dictionary) -> String:
	var n: Dictionary = Story.nodes[v.ref]
	if v.kind == "option":
		return n.options[int(v.opt)].label
	return n.title


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("120f18"))
	var L: Dictionary = ch.layout
	var seen: Dictionary = Story.st.seen
	var seen_all: Dictionary = Story.st.seen_all
	for e in L.edges:
		if not rects.has(e[0]) or not rects.has(e[1]):
			continue
		var a: Rect2 = rects[e[0]]
		var b: Rect2 = rects[e[1]]
		var lit: bool = seen.has(e[0]) and seen.has(e[1])
		var col := Color("ffd65c") if lit else Color("3a3346")
		if e[2] == "rewind":
			var gx := 2.0
			var pts := PackedVector2Array([Vector2(a.position.x, a.get_center().y), Vector2(gx, a.get_center().y), Vector2(gx, b.get_center().y), Vector2(b.position.x, b.get_center().y)])
			draw_polyline(pts, Color("b8303c") if lit else Color("4a2a30"), 1.0)
			continue
		var p0 := Vector2(a.get_center().x, a.end.y)
		var p1 := Vector2(b.get_center().x, b.position.y)
		var my := (p0.y + p1.y) / 2.0
		draw_polyline(PackedVector2Array([p0, Vector2(p0.x, my), Vector2(p1.x, my), p1]), col, 1.5 if lit else 1.0)
	for v in L.nodes:
		var r: Rect2 = rects[v.vid]
		var k := _kind(v)
		var col: Color = TYPE_COL.get(k, Color.WHITE)
		if seen.has(v.vid):
			draw_rect(r, col.darkened(0.55))
			draw_rect(r, col, false, 1.5)
		elif seen_all.has(v.vid):
			draw_rect(r, col.darkened(0.8))
			draw_rect(r, col.darkened(0.35), false, 1.0)
		else:
			draw_rect(r, Color("18141f"))
			draw_rect(r, Color("3a3346"), false, 1.0)
			if r.size.x >= 10:
				draw_string(font, Vector2(r.get_center().x - 3, r.get_center().y + 5), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("5b5268"))
		if v.vid == sel:
			draw_rect(r.grow(2), Color.WHITE, false, 1.0)


func _gui_input(ev: InputEvent) -> void:
	if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
		return
	for v in ch.layout.nodes:
		if (rects[v.vid] as Rect2).grow(4).has_point(ev.position):
			sel = v.vid
			queue_redraw()
			var known: bool = Story.st.seen_all.has(v.vid)
			var t := _title(v) if known else "？？？"
			var extra := ""
			if not known and v.kind == "option":
				var o: Dictionary = Story.nodes[v.ref].options[int(v.opt)]
				if o.has("req"):
					extra = "  （需要：%s）" % "；".join(o.req.map(func(c): return Story.cond_text(c)))
			if on_info.is_valid():
				on_info.call(t + extra + ("" if Story.st.seen.has(v.vid) or not known else "  · 前世走过"))
			accept_event()
			return
