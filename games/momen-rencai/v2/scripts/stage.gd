extends Node2D
## 俯视舞台（270×160）：Kenney CC0 像素地块做场景，人物一律是圆圈 + 一个字。
## 也是俯视 2D 战斗场：圆圈追逐、碰撞、背刺、护卫。

signal battle_done(skill: bool)

const W := 270
const SH := 160
const INK := Color("14101c")
const T := 16

var font: Font
var town: Texture2D
var dungeon: Texture2D
var scene_id := "court"
var tint := Color(1, 1, 1)
var tiles: Array = []          # [[atlas_tex, Vector2i src, Vector2 pos]]
var actors := {}               # id -> Dictionary
var parts: Array = []          # 粒子 {p, v, c, life}
var slashes: Array = []        # {a, b, c, life}
var shake := 0.0
var flash := 0.0
var flash_col := Color(1, 0.2, 0.25)
var time := 0.0
# ---- 战斗 ----
var in_battle := false
var bt := 0.0
var bcfg := {}
var stance := "atk"
var blocked := false
var betray_done := false
var battle_len := 6.0
var fog := 0.0


func _ready() -> void:
	town = load("res://assets/sprites/town.png")
	dungeon = load("res://assets/sprites/dungeon.png")


# ======================= 场景 =======================

const SCENES := {
	"court":   {"tint": Color(0.95, 0.92, 1.0), "fog": 0.0},
	"forest":  {"tint": Color(0.62, 0.72, 0.80), "fog": 0.35},
	"yaotang": {"tint": Color(0.85, 0.75, 0.62), "fog": 0.0},
	"garden":  {"tint": Color(0.45, 0.55, 0.85), "fog": 0.15},
	"arena":   {"tint": Color(0.95, 0.70, 0.66), "fog": 0.0},
	"gate":    {"tint": Color(0.96, 0.92, 0.85), "fog": 0.0},
	"altar":   {"tint": Color(0.95, 0.38, 0.40), "fog": 0.1},
}


func set_scene(id: String) -> void:
	if id == "" or id == scene_id and tiles.size() > 0:
		return
	scene_id = id
	var s: Dictionary = SCENES.get(id, SCENES.court)
	tint = s.tint
	fog = s.fog
	tiles = []
	var r := RandomNumberGenerator.new()
	r.seed = hash(id)
	var cols := 17
	var rows := 10
	for y in rows:
		for x in cols:
			var p := Vector2(x * T - 1, y * T)
			match id:
				"court", "gate":
					_t(town, Vector2i(r.randi() % 3, 0) if r.randf() < 0.25 else Vector2i(0, 0), p)
				"forest", "garden":
					_t(town, Vector2i([0, 1, 2][r.randi() % 3], 0) if r.randf() < 0.3 else Vector2i(0, 0), p)
				"yaotang":
					_t(dungeon, Vector2i(1 + r.randi() % 3, 4), p)
				"arena":
					_t(dungeon, Vector2i(r.randi() % 3, 3), p)
				"altar":
					_t(dungeon, Vector2i(0, 0) if r.randf() < 0.8 else Vector2i(1, 0), p)
	match id:
		"court":
			for x in cols:
				_t(town, Vector2i(1 + (x % 2), 4), Vector2(x * T - 1, 0))
				_t(town, Vector2i(1 + (x % 2), 7), Vector2(x * T - 1, T))
			for yy in range(4, 9):
				for xx in range(5, 12):
					_t(town, Vector2i(1, 1), Vector2(xx * T - 1, yy * T))
			for p in [Vector2(0, 64), Vector2(0, 112), Vector2(254, 72), Vector2(254, 120)]:
				_t(town, Vector2i(4, 0), p)
		"forest":
			for i in 26:
				var p := Vector2(r.randi_range(0, 16) * T - 1, r.randi_range(0, 9) * T)
				if absf(p.x - 135) < 40 and p.y > 40:
					continue
				_t(town, [Vector2i(4, 0), Vector2i(4, 2), Vector2i(3, 0), Vector2i(3, 2)][r.randi() % 4], p)
			_t(town, Vector2i(5, 2), Vector2(60, 130))
		"garden":
			for i in 10:
				_t(town, Vector2i(5, 2), Vector2(r.randi_range(1, 15) * T - 1, r.randi_range(1, 9) * T))
			for i in 6:
				_t(town, Vector2i(5, 0), Vector2(r.randi_range(0, 16) * T - 1, r.randi_range(0, 2) * T))
			for x in cols:
				_t(town, Vector2i(9, 6), Vector2(x * T - 1, 144))
		"yaotang":
			for x in cols:
				_t(dungeon, Vector2i(10, 4), Vector2(x * T - 1, 0))
				if x % 3 == 1:
					_t(dungeon, Vector2i(3, 5), Vector2(x * T - 1, T))
				else:
					_t(dungeon, Vector2i(10, 4), Vector2(x * T - 1, T))
			for i in 7:
				_t(dungeon, Vector2i(5 + i % 4, 9), Vector2(20 + i * 34, 36))
			_t(dungeon, Vector2i(0, 6), Vector2(40, 100))
			_t(dungeon, Vector2i(0, 6), Vector2(214, 100))
		"arena":
			for x in cols:
				_t(dungeon, Vector2i(10, 4), Vector2(x * T - 1, 0))
			for x in range(6, 11):
				_t(dungeon, Vector2i(6, 4), Vector2(x * T - 1, T))
			_t(dungeon, Vector2i(8, 2), Vector2(8 * T - 1, T))
			for yy in [2, 9]:
				for xx in range(1, 16):
					_t(dungeon, Vector2i(6, 6), Vector2(xx * T - 1, yy * T))
		"gate":
			for x in cols:
				if x < 6 or x > 10:
					_t(town, Vector2i(4, 8), Vector2(x * T - 1, 0))
					_t(town, Vector2i(4, 9), Vector2(x * T - 1, T))
			_t(town, Vector2i(3, 9), Vector2(7 * T - 1, T))
			_t(town, Vector2i(4, 10), Vector2(8 * T - 1, T))
			for p in [Vector2(10, 90), Vector2(244, 110), Vector2(20, 130)]:
				_t(town, Vector2i(4, 0), p)
		"altar":
			for yy in 3:
				for xx in 3:
					_t(dungeon, Vector2i(9 + xx, 5 + yy), Vector2((7 + xx) * T - 1, yy * T + 4))
			for p in [Vector2(30, 40), Vector2(224, 40), Vector2(30, 120), Vector2(224, 120)]:
				_t(dungeon, Vector2i(5, 1), p)
	queue_redraw()


func _t(tex: Texture2D, src: Vector2i, pos: Vector2) -> void:
	tiles.append([tex, src, pos])


# ======================= 角色 =======================

func _cast_info(id: String) -> Dictionary:
	return Story.D.cast.get(id, {"glyph": "?", "color": "ffffff", "r": 7, "name": id})


func add_actor(id: String, pos: Vector2, team := "npc", key := "") -> Dictionary:
	var k := key if key != "" else id
	var ci := _cast_info(id)
	var a := {"id": id, "pos": pos, "target": pos, "color": Color(ci.color), "r": float(ci.r), "glyph": ci.glyph,
		"alpha": 0.0, "hp": 3.0, "hp_max": 3.0, "flash": 0.0, "dead": false, "team": team, "bubble": "",
		"bubble_t": 0.0, "mark": "", "cd": 0.0, "speed": 40.0, "tactic": "assist", "flicker": 0.0, "think": ""}
	actors[k] = a
	return a


func set_cast(ids: Array) -> void:
	var keep := {}
	var others := ids.filter(func(i): return i != "me")
	var n := others.size()
	for i in n:
		var id: String = others[i]
		var x := 135.0 if n == 1 else lerpf(70.0, 200.0, float(i) / float(max(1, n - 1)))
		var y := 100.0 if id != "elder" else 90.0
		if id == "elder" and n > 1:
			x = 135.0
			y = 84.0
		if not actors.has(id):
			var a := add_actor(id, Vector2(x, y + 10))
			a.target = Vector2(x, y)
		else:
			actors[id].target = Vector2(x, y)
			actors[id].dead = false
		keep[id] = true
	if ids.has("me"):
		if not actors.has("me"):
			add_actor("me", Vector2(135, 144), "me")
		actors.me.target = Vector2(135, 138)
		actors.me.dead = false
		keep["me"] = true
	for k in actors.keys():
		if not keep.has(k):
			actors[k].leaving = true


func say(id: String, text: String, dur := 2.6) -> void:
	if actors.has(id):
		actors[id].bubble = text
		actors[id].bubble_t = dur


func think(id: String, text: String) -> void:
	if actors.has(id):
		actors[id].think = text


func mark(id: String, m: String) -> void:
	if actors.has(id):
		actors[id].mark = m


func flicker(id: String, t := 1.5) -> void:
	if actors.has(id):
		actors[id].flicker = t


func hit_fx(p: Vector2, c: Color, n := 8) -> void:
	for i in n:
		var ang := randf() * TAU
		parts.append({"p": p, "v": Vector2(cos(ang), sin(ang)) * randf_range(30, 80), "c": c, "life": randf_range(0.25, 0.5)})


func do_flash(c := Color(1, 0.2, 0.25), t := 0.35) -> void:
	flash_col = c
	flash = t


func kill(id: String) -> void:
	if actors.has(id):
		actors[id].dead = true
		hit_fx(actors[id].pos, actors[id].color, 14)


# ======================= 战斗 =======================

## cfg: {kind, foes, allies:[ids], rival, betray, tactic, allies_join}
func start_battle(cfg: Dictionary) -> void:
	bcfg = cfg
	in_battle = true
	bt = 0.0
	blocked = false
	betray_done = false
	stance = "atk"
	battle_len = float(cfg.get("len", 6.5))
	if not actors.has("me"):
		add_actor("me", Vector2(135, 138), "me")
	actors.me.hp = 5.0
	actors.me.hp_max = 5.0
	var fc := int(cfg.get("foes", 3))
	var foe_id := "bone" if cfg.get("kind", "") == "ritual" else "foe"
	for i in fc:
		var side := -12.0 if i % 2 == 0 else 282.0
		var a := add_actor(foe_id, Vector2(side, 76 + (i / 2) * 22 + (i % 2) * 8), "foe", "foe%d" % i)
		a.alpha = 0.0
		a.speed = 22.0 + i * 2
		a.hp = 2.0
	for al in cfg.get("allies", []):
		if actors.has(al):
			actors[al].team = "ally"
			actors[al].tactic = cfg.get("tactic", "assist")
	if cfg.has("rival") and actors.has(cfg.rival):
		actors[cfg.rival].team = "foe"
		actors[cfg.rival].hp = 4.0
		actors[cfg.rival].speed = 34.0
		battle_len = 4.2


func set_stance(s: String) -> void:
	stance = s


func _nearest(from: Vector2, team: String) -> String:
	var best := ""
	var bd := 1e9
	for k in actors:
		var a = actors[k]
		if a.team == team and not a.dead and not a.get("leaving", false):
			var d: float = from.distance_to(a.pos)
			if d < bd:
				bd = d
				best = k
	return best


func _battle_step(d: float) -> void:
	bt += d
	var me = actors.get("me")
	if me == null:
		return
	var kind: String = bcfg.get("kind", "")
	# 背刺
	if bcfg.get("betray", false) and bcfg.get("allies", []).size() > 0:
		var tr: String = bcfg.allies[0]
		if actors.has(tr):
			var a = actors[tr]
			if bt > 2.4 and bt < 3.5:
				a.mark = "!"
				a.target = me.pos + Vector2(-22, -18)
			elif bt >= 3.5 and not betray_done:
				betray_done = true
				a.mark = ""
				a.pos = me.pos + Vector2(0, -12)
				if stance == "def":
					blocked = true
					Sfx.play("hit")
					hit_fx(me.pos + Vector2(0, -8), Color("ffd65c"), 16)
					a.target = me.pos + Vector2(0, -48)
					slashes.append({"a": a.pos, "b": me.pos, "c": Color("ffd65c"), "life": 0.3})
				else:
					Sfx.play("slash")
					do_flash()
					shake = 0.4
					me.flash = 0.4
					slashes.append({"a": a.pos + Vector2(-10, -6), "b": me.pos + Vector2(10, 8), "c": Color("e23440"), "life": 0.35})
					hit_fx(me.pos, Color("e23440"), 18)
				a.team = "traitor"
	# 仪式：记得你的人冲进来
	if kind == "ritual" and bcfg.get("allies_join", []).size() > 0 and bt > 1.6 and not bcfg.get("_joined", false):
		bcfg["_joined"] = true
		var js: Array = bcfg.allies_join
		for i in js.size():
			var side := -20.0 if i % 2 == 0 else 290.0
			var a := add_actor(js[i], Vector2(side, 60 + i * 18), "ally")
			a.alpha = 1.0
			a.tactic = "assist"
			a.speed = 70.0
			say(js[i], ["我记得你！", "这次换我！", "师弟！", "别怕。"][i % 4], 1.6)
		Sfx.play("whoosh")
	# 移动与攻击
	for k in actors:
		var a = actors[k]
		if a.dead or a.get("leaving", false):
			continue
		a.cd -= d
		var tgt := ""
		if a.team == "foe":
			tgt = "me"
			for kk in actors:
				var b = actors[kk]
				if b.team == "ally" and not b.dead and b.pos.distance_to(a.pos) < a.pos.distance_to(me.pos) * 0.7:
					tgt = kk
		elif a.team == "ally":
			if a.tactic == "guard":
				var f := _nearest(me.pos, "foe")
				if f != "" and actors[f].pos.distance_to(me.pos) < 50:
					tgt = f
				else:
					a.target = me.pos + Vector2(0, -20)
			elif a.tactic == "assist":
				tgt = _nearest(a.pos, "foe")
		elif a.team == "me":
			if stance == "atk":
				tgt = _nearest(a.pos, "foe")
			elif stance == "flee":
				a.target = Vector2(clampf(a.pos.x, 20, 250), 150)
			else:
				a.target = a.pos
		if tgt != "" and actors.has(tgt):
			var tp: Vector2 = actors[tgt].pos
			if a.pos.distance_to(tp) > a.r + actors[tgt].r + 2:
				a.target = tp
			else:
				a.target = a.pos
				if a.cd <= 0:
					a.cd = 0.55
					_strike(k, tgt)
		var sp: float = a.speed * (1.6 if a.team == "me" and stance == "atk" else 1.0)
		a.pos = a.pos.move_toward(a.target, sp * d)
		a.pos.x = clampf(a.pos.x, -30, 300)
		a.pos.y = clampf(a.pos.y, 6, 152)
	var foes_left := 0
	for k in actors:
		if actors[k].team == "foe" and not actors[k].dead:
			foes_left += 1
	var stabbed: bool = betray_done and not blocked and bcfg.get("end_after_betray", false) and bt > 4.1
	if stabbed or bt >= battle_len or (foes_left == 0 and bt > 2.0 and (not bcfg.get("betray", false) or betray_done)):
		in_battle = false
		for k in actors:
			var a = actors[k]
			if a.team in ["ally", "traitor"]:
				a.team = "npc"
		battle_done.emit(blocked)


func _strike(src: String, dst: String) -> void:
	var a = actors[src]
	var b = actors[dst]
	var dmg := 1.0
	if dst == "me" and stance == "def":
		dmg = 0.4
	if dst == "me" and bcfg.get("kind", "") == "ritual" and bcfg.get("allies_join", []).size() == 0:
		dmg = 0.9
	if dst == "me" and bcfg.get("protect_me", false):
		dmg = 0.0
	b.hp -= dmg
	b.flash = 0.2
	slashes.append({"a": a.pos, "b": b.pos, "c": a.color.lightened(0.3), "life": 0.18})
	hit_fx(b.pos, b.color, 5)
	Sfx.play("hit", -6.0, randf_range(0.9, 1.2))
	if b.hp <= 0 and dst != "me":
		kill(dst)
		if src == "me":
			Story.add_metric(Story.metric_key(), 0)


# ======================= 帧 =======================

func _process(d: float) -> void:
	time += d
	if in_battle:
		_battle_step(d * float(bcfg.get("speed", 1.0)))
	else:
		for k in actors:
			var a = actors[k]
			a.pos = a.pos.move_toward(a.target, 60.0 * d)
	for k in actors.keys():
		var a = actors[k]
		if a.get("leaving", false):
			a.alpha -= d * 3.0
			if a.alpha <= 0:
				actors.erase(k)
				continue
		else:
			a.alpha = minf(1.0, a.alpha + d * 3.0)
		a.flash = maxf(0.0, a.flash - d)
		a.flicker = maxf(0.0, a.flicker - d)
		if a.bubble_t > 0:
			a.bubble_t -= d
			if a.bubble_t <= 0:
				a.bubble = ""
	for p in parts:
		p.p += p.v * d
		p.v *= 0.9
		p.life -= d
	parts = parts.filter(func(p): return p.life > 0)
	for s in slashes:
		s.life -= d
	slashes = slashes.filter(func(s): return s.life > 0)
	shake = maxf(0.0, shake - d)
	flash = maxf(0.0, flash - d)
	queue_redraw()


func _draw() -> void:
	var off := Vector2(randf_range(-2, 2), randf_range(-2, 2)) * (shake / 0.4) if shake > 0 else Vector2.ZERO
	draw_rect(Rect2(0, 0, W, SH), Color("1a1426"))
	for t in tiles:
		draw_texture_rect_region(t[0], Rect2(t[2] + off, Vector2(T, T)), Rect2(t[1] * T, Vector2(T, T)), tint)
	if fog > 0:
		for i in 5:
			var y := fmod(time * 6.0 + i * 37.0, 180.0) - 10.0
			draw_rect(Rect2(0, y, W, 10), Color(0.8, 0.85, 0.95, fog * 0.18))
	# 阴影 + 圆圈
	var order := actors.keys()
	order.sort_custom(func(a, b): return actors[a].pos.y < actors[b].pos.y)
	for k in order:
		var a = actors[k]
		var p: Vector2 = a.pos + off
		var al: float = a.alpha
		if a.flicker > 0 and int(time * 20) % 2 == 0:
			al *= 0.35
		draw_circle(p + Vector2(0, a.r * 0.6), a.r * 0.9, Color(0, 0, 0, 0.35 * al))
		if a.dead:
			draw_arc(p, a.r, 0, TAU, 20, Color(a.color, 0.5 * al), 1.0)
			draw_line(p + Vector2(-a.r, -a.r) * 0.6, p + Vector2(a.r, a.r) * 0.6, Color(a.color, 0.6 * al), 1.0)
			continue
		var c: Color = a.color
		if a.flash > 0:
			c = Color(1, 1, 1)
		draw_circle(p, a.r + 1, Color(INK, al))
		draw_circle(p, a.r, Color(c, al))
		draw_circle(p + Vector2(-a.r * 0.35, -a.r * 0.35), a.r * 0.3, Color(1, 1, 1, 0.35 * al))
		if k == "me" and in_battle and stance == "def":
			draw_arc(p, a.r + 4, 0, TAU, 24, Color("ffd65c"), 1.0)
		var gs := 12 if a.r >= 8 else 8
		if font:
			var tw := font.get_string_size(a.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs).x
			draw_string(font, p + Vector2(-tw / 2.0, gs * 0.36), a.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, gs, Color(INK, al))
		if in_battle and a.team != "npc":
			var wbar: float = a.r * 2
			draw_rect(Rect2(p + Vector2(-a.r, -a.r - 5), Vector2(wbar, 2)), Color(INK, al))
			draw_rect(Rect2(p + Vector2(-a.r, -a.r - 5), Vector2(wbar * clampf(a.hp / a.hp_max, 0, 1), 2)), Color("e23440") if a.team == "foe" else Color("5ce8c4"))
		if a.mark != "" and font:
			var bob := sin(time * 12) * 1.5
			draw_string(font, p + Vector2(-3, -a.r - 7 + bob), a.mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("e23440"))
	for s in slashes:
		draw_line(s.a + off, s.b + off, Color(s.c, clampf(s.life * 4, 0, 1)), 2.0)
	for p in parts:
		draw_rect(Rect2(p.p + off, Vector2(2, 2)), Color(p.c, clampf(p.life * 3, 0, 1)))
	# 气泡（最后画，盖在上面）
	for k in order:
		var a = actors[k]
		if a.dead:
			continue
		if a.bubble != "" and font:
			_bubble(a.pos + off + Vector2(0, -a.r - 4), a.bubble, Color("f4f0e6"), INK)
		elif a.think != "" and font:
			_bubble(a.pos + off + Vector2(0, -a.r - 4), a.think, Color("2c223e"), Color("968caa"))
	if flash > 0:
		draw_rect(Rect2(0, 0, W, SH), Color(flash_col, flash * 1.2))


func _bubble(anchor: Vector2, text: String, bg: Color, fg: Color) -> void:
	var fs := 12
	var sz := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var w := sz.x + 6
	var r := Rect2(Vector2(clampf(anchor.x - w / 2, 2, W - w - 2), anchor.y - 16), Vector2(w, 15))
	draw_rect(r.grow(1), INK)
	draw_rect(r, bg)
	draw_rect(Rect2(anchor + Vector2(-1, -2), Vector2(3, 2)), bg)
	draw_string(font, r.position + Vector2(3, 12), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, fg)
