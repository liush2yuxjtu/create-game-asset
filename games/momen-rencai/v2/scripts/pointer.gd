extends Node2D
## 录屏模式里的「手指」光标（像素箭头 + 点击波纹），让视频看得出每一步是点出来的。

var ring := 0.0
const PTS := [Vector2(0, 0), Vector2(0, 13), Vector2(3, 10), Vector2(6, 16), Vector2(8, 15), Vector2(5, 9), Vector2(9, 9)]


func _draw() -> void:
	if ring > 0:
		var r := (1.0 - ring) * 14.0 + 3.0
		draw_arc(Vector2.ZERO, r, 0, TAU, 20, Color(1, 0.84, 0.36, ring), 2.0)
	var out := PackedVector2Array()
	for p in PTS:
		out.append(p)
	var o2 := PackedVector2Array()
	for p in PTS:
		o2.append(p + Vector2(1, 1))
	draw_colored_polygon(o2, Color("14101c"))
	draw_colored_polygon(out, Color("f4f0e6"))
	draw_polyline(out + PackedVector2Array([PTS[0]]), Color("14101c"), 1.0)
