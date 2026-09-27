extends Node
## 导演：data/viral_script.json 是爆款视频与新手引导的唯一分镜。
##   interactive=false → 录屏模式：按时间轴自动演出（手指光标自动点），视频就是用这个模式 + Godot Movie Maker 逐帧录出来的
##   interactive=true  → 新手引导：同样的镜头与字幕，每个「点」都停下来等玩家亲手点；输入框预填台词，玩家可改
## 两种模式跑的是同一套真实游戏逻辑（剧情引擎、记忆背包、战斗、数值），不是预渲染动画。

var m: Node2D
var S: Dictionary
var interactive := false
var t := 0.0
var fired := {}
var blocked := false
var gate := {}
var battle_speed := 0.0
var cap_label: Label
var cap_bg: ColorRect
var hint_label: Label
var hl: Panel
var pointer: Node2D
var ptr_from := Vector2(200, 400)
var ptr_to := Vector2(200, 400)
var ptr_t := 1.0
var ring := 0.0
var cur_cap := -1
var done := false
var cta: Control = null
var typing := {}
var wait_target := {}      # 录屏：目标还没出现时顺延


func begin(main: Node2D, is_interactive: bool) -> void:
	m = main
	interactive = is_interactive
	S = JSON.parse_string(FileAccess.get_file_as_string("res://data/viral_script.json"))
	S.events.sort_custom(func(a, b): return a.t < b.t)
	Agent.force_offline = not interactive
	m.lock_input = true
	m.skip_cards = true
	m.ov_y = 72.0
	m.quiet_banner = true
	m.show_badge = interactive
	m._close_overlay()
	m.begin_play()
	_build()
	m.tapped.connect(_on_tapped)


func _build() -> void:
	var L: Control = m.cap_layer
	for c in L.get_children():
		c.queue_free()
	cap_bg = ColorRect.new()
	cap_bg.color = Color(0, 0, 0, 0)
	cap_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(cap_bg)
	cap_label = Label.new()
	cap_label.add_theme_font_override("font", m.font)
	cap_label.add_theme_font_size_override("font_size", 24)
	cap_label.add_theme_color_override("font_color", Color.WHITE)
	cap_label.add_theme_constant_override("outline_size", 6)
	cap_label.add_theme_color_override("font_outline_color", m.INK)
	cap_label.add_theme_constant_override("line_spacing", 2)
	cap_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap_label.position = Vector2(0, 26)
	cap_label.custom_minimum_size = Vector2(m.W, 60)
	cap_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	L.add_child(cap_label)
	hl = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = m.GOLD
	sb.set_border_width_all(2)
	hl.add_theme_stylebox_override("panel", sb)
	hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hl.visible = false
	L.add_child(hl)
	hint_label = Label.new()
	hint_label.add_theme_font_override("font", m.font)
	hint_label.add_theme_font_size_override("font_size", 12)
	hint_label.add_theme_color_override("font_color", m.GOLD)
	hint_label.add_theme_constant_override("outline_size", 3)
	hint_label.add_theme_color_override("font_outline_color", m.INK)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.visible = false
	L.add_child(hint_label)
	pointer = load("res://scripts/pointer.gd").new()
	pointer.visible = not interactive
	pointer.position = ptr_from
	var cl := CanvasLayer.new()
	cl.layer = 6
	add_child(cl)
	cl.add_child(pointer)


# ======================= 时间轴 =======================

func _process(d: float) -> void:
	if done:
		return
	_anim_pointer(d)
	_run_typing(d)
	if blocked:
		_pulse()
		return
	t += d
	_captions()
	for i in S.events.size():
		if fired.has(i):
			continue
		var e: Dictionary = S.events[i]
		var lead := 0.35 if e.do == "tap" and not interactive else 0.0
		if t + lead >= float(e.t) and e.do == "tap" and not interactive and not wait_target.has(i):
			wait_target[i] = true
			_aim(e.target)
		if t >= float(e.t):
			if e.do == "tap" and not _target_ready(e.target):
				continue   # 目标还没出现（比如打字/战斗没完），等它
			fired[i] = true
			_fire(e)
			if blocked:
				return


func _captions() -> void:
	var idx := -1
	for i in S.captions.size():
		var c: Dictionary = S.captions[i]
		if t >= float(c.t0) and t < float(c.t1):
			idx = i
	if interactive and idx == -1 and cur_cap >= 0:
		return
	if idx == cur_cap:
		return
	cur_cap = idx
	if idx < 0:
		cap_label.text = ""
		return
	var c: Dictionary = S.captions[idx]
	cap_label.text = c.text
	var big: bool = c.get("style", "") in ["hook", "cta"]
	cap_label.add_theme_font_size_override("font_size", 24)
	cap_label.position = Vector2(0, 30 if big else 26)
	cap_label.pivot_offset = Vector2(m.W / 2.0, 20)
	cap_label.scale = Vector2(1.25, 1.25)
	var tw := create_tween()
	tw.tween_property(cap_label, "scale", Vector2(1, 1), 0.12)
	Sfx.play("whoosh", -12.0)


func _target_ready(key: String) -> bool:
	if key == "cont":
		return not m.typing and Story.node().has("auto") or Story.node().has("chapter_end")
	var b = m.targets.get(key)
	if b == null or not is_instance_valid(b) or not b.is_visible_in_tree():
		return false
	if key.begins_with("choice:") and m.typing:
		return false
	return true


func _fire(e: Dictionary) -> void:
	if e.do == "tap" and e.target == "rebirth_btn":
		m.quiet_banner = false
	match e.do:
		"prologue":
			_prologue(float(e.get("speed", 1.8)))
		"tap":
			if e.has("speed"):
				battle_speed = float(e.speed)
			if interactive:
				_gate(e.target, str(e.get("hint", "点这里")))
			else:
				ring = 1.0
				if not m.press(e.target):
					push_warning("director: 无法点击 " + e.target)
		"type":
			if interactive:
				m.input.text = e.text
				m.input.caret_column = e.text.length()
			else:
				typing = {"text": e.text, "dur": float(e.dur), "t": 0.0}
		"cards":
			m.skip_cards = not bool(e.on)
		"cta":
			_show_cta()
		"end":
			_end()


func _prologue(speed: float) -> void:
	GS.isolated = true
	Story.new_game(99)
	# 前世残影：你在第57世、第81世也记住过一些事，但没有铭刻
	Story.frag_log["frag_crane"] = {"life": 57, "ch": 1}
	Story.frag_log["frag_99"] = {"life": 81, "ch": 1}
	Mem.remember("lihan", "那一世，他跟我去了后山", 2, -1)
	Mem.life = 99
	battle_speed = speed
	Story.ch = 1
	Story.m = {"qi": 0}
	Story.chapter_snapshot = {"flags": [], "m": {"qi": 0}, "fresh": [], "echo_cur": []}
	m.stage.actors.clear()
	m.stage.set_scene("forest")
	Story.enter("c1_hunt")
	for k in m.stage.actors:
		m.stage.actors[k].alpha = 1.0
		m.stage.actors[k].pos = m.stage.actors[k].target
	m.text_shown = 999.0


# ======================= 新手引导：等玩家亲手点 =======================

func _gate(key: String, hint: String) -> void:
	blocked = true
	gate = {"key": key, "hint": hint, "node": Story.cur}
	m.gate_key = key
	hint_label.text = "▼ " + hint
	hint_label.visible = true
	hl.visible = true
	if key == "cont":
		m.gate_key = "cont"


func _on_tapped(key: String) -> void:
	if not blocked or key != gate.get("key", ""):
		return
	if key == "cont" and Story.cur == gate.get("node", ""):
		return   # 只是把打字点完了，还没真正往下走
	blocked = false
	m.gate_key = ""
	hl.visible = false
	hint_label.visible = false
	gate = {}


func _pulse() -> void:
	var r: Rect2 = m.target_rect(gate.key) if gate.key != "cont" else Rect2(0, m.STAGE_Y, m.W, m.STAGE_H)
	if r.size == Vector2.ZERO:
		return
	var a := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 120.0)
	hl.position = r.position - Vector2(3, 3)
	hl.size = r.size + Vector2(6, 6)
	hl.modulate.a = a
	hint_label.position = Vector2(clampf(r.position.x, 4, m.W - 120), r.position.y - 16 if r.position.y > 40 else r.end.y + 4)
	hint_label.modulate.a = 0.6 + 0.4 * a


# ======================= 录屏：手指光标 =======================

func _aim(key: String) -> void:
	ptr_from = pointer.position
	var r: Rect2 = m.target_rect(key) if key != "cont" else Rect2(100, 90, 70, 40)
	if r.size == Vector2.ZERO:
		r = Rect2(Vector2(160, 300), Vector2(40, 20))
	ptr_to = r.position + r.size * Vector2(0.7, 0.6)
	ptr_t = 0.0


func _anim_pointer(d: float) -> void:
	if interactive:
		return
	ptr_t = minf(1.0, ptr_t + d / 0.3)
	var k := 1.0 - pow(1.0 - ptr_t, 3)
	pointer.position = ptr_from.lerp(ptr_to, k)
	ring = maxf(0.0, ring - d * 3.0)
	pointer.ring = ring
	pointer.queue_redraw()


func _run_typing(d: float) -> void:
	if typing.is_empty():
		return
	typing.t += d
	var n := int(clampf(typing.t / typing.dur, 0, 1) * typing.text.length())
	var s: String = typing.text.substr(0, n)
	if s != m.input.text:
		m.input.text = s
		Sfx.play("type", -8.0)
	if typing.t >= typing.dur:
		m.input.text = typing.text
		typing = {}


# ======================= 结尾 CTA =======================

func _show_cta() -> void:
	cta = Control.new()
	cta.size = Vector2(m.W, m.H)
	cta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.cap_layer.add_child(cta)
	m.cap_layer.move_child(cap_label, m.cap_layer.get_child_count() - 1)
	var bg := ColorRect.new()
	bg.size = Vector2(m.W, m.H)
	bg.color = Color(0.05, 0.03, 0.08, 0.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cta.add_child(bg)
	create_tween().tween_property(bg, "color:a", 0.96, 0.4)
	pointer.visible = false
	var y := 120.0
	for l in Story.chapter_layers(1):
		var lb := _cta_label(("■ " + l.title) if l.found else "□ ？？？", Vector2(70, y), m.GOLD if l.found else m.DIM, 12)
		y += 18
	_cta_label("评论区：你会带哪段记忆进下一世？", Vector2(0, 220), m.WHITE, 12, true)
	var t1 := _cta_label("魔门人材", Vector2(0, 268), m.GOLD, 36, true)
	_cta_label("· 忆 ·", Vector2(0, 308), m.WHITE, 24, true)
	_cta_label("开局就是这段 · 新手引导可以亲手复刻", Vector2(0, 350), m.DIM, 12, true)
	_cta_label(" ".join(S.hashtags.slice(0, 4)), Vector2(0, 372), m.JADE, 12, true)
	Sfx.play("reveal")
	if interactive:
		m.skip_cards = false
		var y2 := 404.0
		for spec in [["继续 · 第二章", func(): _finish_tutorial(), m.GOLD], ["录屏模式（复刻这个视频）", func(): _restart(false), m.JADE], ["复制文案 + 话题", func(): _copy(), m.DIM]]:
			var b: Button = m._button(spec[0], spec[1], "", m.PANEL2, spec[2])
			b.alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.position = Vector2(36, y2)
			b.size = Vector2(m.W - 72, 20)
			cta.add_child(b)
			y2 += 24
		cta.mouse_filter = Control.MOUSE_FILTER_STOP
		m.lock_input = false


func _cta_label(text: String, pos: Vector2, col: Color, size: int, center := false) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_override("font", m.font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_constant_override("outline_size", 4 if size > 12 else 2)
	l.add_theme_color_override("font_outline_color", m.INK)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if center:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.custom_minimum_size = Vector2(m.W, size + 2)
	cta.add_child(l)
	return l


func _copy() -> void:
	DisplayServer.clipboard_set(S.copy + "\n" + " ".join(S.hashtags))
	m.toast("文案已复制", m.JADE)


func _restart(inter: bool) -> void:
	_cleanup()
	m.start_director(inter)


func _cleanup() -> void:
	done = true
	for c in m.cap_layer.get_children():
		c.queue_free()
	m.gate_key = ""
	m.lock_input = false
	m.skip_cards = false
	m.ov_y = 0.0
	m.quiet_banner = false
	m.show_badge = true
	if m.tapped.is_connected(_on_tapped):
		m.tapped.disconnect(_on_tapped)


func _finish_tutorial() -> void:
	## 新手引导的状态就是真实第100世：接着进第二章正式游玩
	_cleanup()
	GS.isolated = false
	GS.tutorial_done = true
	GS.has_game = true
	Agent.force_offline = false
	GS.save_game()
	m._close_overlay()
	m.mode = "play"
	m._build_choices()
	if Story.node().has("chapter_end"):
		Story.advance()
	queue_free()


func _end() -> void:
	if interactive:
		return
	done = true
	if OS.get_cmdline_user_args().has("--movie"):
		await get_tree().create_timer(0.1).timeout
		get_tree().quit()
