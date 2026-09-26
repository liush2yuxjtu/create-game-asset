extends Node2D
## 俯视角 2D 战斗（GBA 240x160 手感）：世界坐标 135x105，以 ×2 画到竖屏上
## 主角默认自动战斗（挂机），点/拖屏幕可手动走位，【魔焰】为范围技能

signal wave_cleared(n: int)
signal hero_died
signal betrayal(dodged: bool)
signal elder_burned
signal speak(actor: String, text: String)
signal float_text(text: String, world_pos: Vector2, color: Color)
signal loot_dropped

const WW := 135
const WH := 105
const T_HERO := 88
const T_SENIOR := 111
const T_ELDER := 84
const ENEMY_TILES := [108, 120, 121, 122, 110]
const FLOOR_TILES := [48, 49, 50, 51]

var sheet: Texture2D = preload("res://assets/sprites/dungeon.png")
var units: Array = []
var hero: Dictionary = {}
var senior: Dictionary = {}
var elder: Dictionary = {}
var fx: Array = []
var floor_map: Array = []
var running := false
var scripted := false          # 新手引导/录屏时由 Director 控制波次
var manual_target = null
var move_dir := Vector2.ZERO
var fire_cd := 0.0
var shake := 0.0
var betray_armed := false
var betray_done := false
var used_fire_on_elder := false
var rng := RandomNumberGenerator.new()
var allow_pills := true
const BOSS := {"elder": {"tile": 84, "name": "血骨"}, "gu": {"tile": 97, "name": "顾长风"}, "master": {"tile": 110, "name": "夜无归"}}
const ALLY_TILES := {"厉寒": 111, "苏晚": 99, "血骨": 84, "顾长风": 97}


func _ready() -> void:
	rng.seed = 7
	for y in 7:
		var row := []
		for x in 9:
			row.append(FLOOR_TILES[rng.randi() % 4])
		floor_map.append(row)
	rng.randomize()
	reset_hero()


func reset_hero() -> void:
	units.clear()
	hero = _mk("hero", "hero", T_HERO, Vector2(60, 62), GS.hero_hp(), GS.hero_atk(), 34.0)
	units.append(hero)
	senior = {}
	elder = {}


func _mk(kind: String, team: String, tile: int, pos: Vector2, hp: float, atk: float, spd: float) -> Dictionary:
	return {"kind": kind, "team": team, "tile": tile, "pos": pos, "hp": hp, "max_hp": hp, "atk": atk, "spd": spd,
		"cd": rng.randf_range(0.1, 0.6), "flash": 0.0, "alive": true, "tactic": "assist", "leaving": false, "rot": 0.0}


# ---------------- 生成 ----------------

func spawn_senior(at := Vector2(140, 62)) -> Dictionary:
	if not senior.is_empty() and senior.alive:
		return senior
	senior = _mk("senior", "ally", T_SENIOR, at, GS.hero_hp() * 0.9, GS.hero_atk() * 0.8, 30.0)
	units.append(senior)
	betray_done = false
	return senior


func spawn_elder(boss: bool, at := Vector2(140, 40)) -> Dictionary:
	var w: int = GS.wave
	var hp := 60.0 * pow(1.3, w) * (6.0 if boss else 1.0)
	elder = _mk("elder", "enemy" if boss else "npc", T_ELDER, at, hp, 3.0 * pow(1.22, w) * 2.5, 20.0)
	units.append(elder)
	return elder


func start_wave(n: int, count := -1) -> void:
	running = true
	var c: int = count if count > 0 else mini(2 + n, 12)
	if hero.hp < hero.max_hp:
		hero.hp = min(hero.max_hp, hero.hp + hero.max_hp * 0.35)
	for i in c:
		var ang := float(i) / c * TAU + rng.randf() * 0.4
		var p := Vector2(60, 58) + Vector2(cos(ang), sin(ang) * 0.75) * rng.randf_range(58, 72)
		var t: int = ENEMY_TILES[(n + i) % 4] if n % 5 != 0 else 122
		var hp := 12.0 * pow(1.28, n)
		var atk := 1.8 * pow(1.24, n)
		units.append(_mk("enemy", "enemy", t, p, hp, atk, rng.randf_range(16, 26)))
	if n % 5 == 0 and not scripted:
		spawn_elder(true, Vector2(140, 30))
		speak.emit("elder", "外门弟子，也配见本座？")


func enemies_alive() -> int:
	var c := 0
	for u in units:
		if u.team == "enemy" and u.alive:
			c += 1
	return c


func set_senior_tactic(t: String) -> void:
	if senior.is_empty():
		return
	senior.tactic = t
	if t == "betray":
		betray_armed = true


func force_betray() -> void:
	if senior.is_empty():
		return
	senior.tactic = "betray"
	betray_armed = true
	senior.cd = 0.0
	senior.pos = hero.pos + Vector2(26, 0)


func spawn_scripted_foe(tile: int, at: Vector2, spd: float) -> Dictionary:
	var foe := _mk("enemy", "enemy", tile, at, 999999, 0, spd)
	foe.kind = "prop"
	foe.team = "prop"
	units.append(foe)
	return foe


func kill_hero_scripted() -> void:
	_slash(hero.pos, Color.WHITE)
	fx.append({"type": "line", "t": 0.0, "dur": 0.15, "a": hero.pos + Vector2(-4, -4), "b": hero.pos + Vector2(20, 20), "color": Color.WHITE})
	hero.hp = 0
	_hero_dead(true)


func clear_enemies() -> void:
	units = units.filter(func(u): return u.team != "enemy")


# ---------------- 技能 ----------------

func cast_fire() -> bool:
	if fire_cd > 0 or not hero.alive:
		return false
	fire_cd = 6.0
	fx.append({"type": "ring", "t": 0.0, "dur": 0.5, "a": hero.pos + Vector2(8, 8), "color": Color(1, 0.45, 0.2), "r": 34.0})
	for u in units:
		if u.team == "enemy" and u.alive and u.pos.distance_to(hero.pos) < 36:
			var dmg: float = hero.atk * 3.0
			if u.get("boss_id", "") == "elder" and (GS.has_perk("fire_vs_elder") or Story.st.mem.has("mem_fire")):
				dmg *= 3.0
				float_text.emit("怕火！", u.pos + Vector2(0, -12), Color(1, 0.6, 0.2))
			if u.kind == "elder":
				if GS.has_perk("fire_vs_elder"):
					dmg *= 3.0
				if not used_fire_on_elder:
					used_fire_on_elder = true
					elder_burned.emit()
			_hit(u, dmg, Color(1, 0.55, 0.2))
	shake = 0.2
	return true


# ---------------- 主循环 ----------------

func _process(delta: float) -> void:
	fire_cd = max(0.0, fire_cd - delta)
	shake = max(0.0, shake - delta)
	for e in fx:
		e.t += delta
	fx = fx.filter(func(e): return e.t < e.dur)
	for u in units:
		u.flash = max(0.0, u.flash - delta)
	if hero.alive:
		_step_hero(delta)
	for u in units:
		if not u.alive or u == hero:
			continue
		if u.kind == "senior":
			_step_senior(u, delta)
		elif u.team == "enemy":
			_step_enemy(u, delta)
		elif u.kind == "elder":
			u.pos = u.pos.move_toward(Vector2(96, 36), 40 * delta)
		elif u.kind == "ally_npc":
			u.cd -= delta
			_ai_fight(u, delta)
		elif u.kind == "prop":
			if u.pos.distance_to(hero.pos) > 20:
				u.pos = u.pos.move_toward(hero.pos + Vector2(20, 0), u.spd * delta)
	units = units.filter(func(u): return u.alive or u.kind == "hero" or u.get("corpse", 0.0) > 0)
	for u in units:
		if not u.alive and u.has("corpse"):
			u.corpse -= delta
	if running and enemies_alive() == 0 and hero.alive:
		running = false
		wave_cleared.emit(GS.wave)
	queue_redraw()


func _nearest(from: Vector2, team: String) -> Dictionary:
	var best := {}
	var bd := INF
	for u in units:
		if u.alive and u.team == team and not u.leaving:
			var d: float = from.distance_to(u.pos)
			if d < bd:
				bd = d
				best = u
	return best


func _clamp_pos(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 2, WW - 18), clampf(p.y, 12, WH - 18))


func _step_hero(delta: float) -> void:
	hero.cd -= delta
	var target := _nearest(hero.pos, "enemy")
	if move_dir != Vector2.ZERO:
		hero.pos = _clamp_pos(hero.pos + move_dir.normalized() * hero.spd * 1.3 * delta)
	elif manual_target != null:
		hero.pos = hero.pos.move_toward(manual_target, hero.spd * 1.3 * delta)
		if hero.pos.distance_to(manual_target) < 1.0:
			manual_target = null
	elif not target.is_empty() and hero.pos.distance_to(target.pos) > 13:
		hero.pos = _clamp_pos(hero.pos.move_toward(target.pos, hero.spd * delta))
	if not target.is_empty() and hero.pos.distance_to(target.pos) < 17 and hero.cd <= 0:
		hero.cd = 0.5
		var dmg: float = hero.atk
		if GS.has_perk("wave5_bonus") and GS.wave == 5:
			dmg *= 1.5
		_slash(target.pos, Color.WHITE)
		_hit(target, dmg, Color(1, 0.84, 0.36))


func _step_senior(u: Dictionary, delta: float) -> void:
	u.cd -= delta
	if u.leaving:
		u.pos += Vector2(60, -10) * delta
		if u.pos.x > WW + 20:
			u.alive = false
		return
	match u.tactic:
		"betray":
			if betray_armed and not betray_done:
				u.pos = u.pos.move_toward(hero.pos + Vector2(10, 0), u.spd * 2.2 * delta)
				if u.pos.distance_to(hero.pos) < 13 and u.cd <= 0:
					_do_betray(u)
			else:
				_ai_fight(u, delta)
		"idle":
			u.pos = u.pos.move_toward(Vector2(110, 30), u.spd * delta)
		"hold":
			u.pos = u.pos.move_toward(u.get("hold", Vector2(104, 62)), u.spd * 1.6 * delta)
		"guard":
			var t := _nearest(hero.pos, "enemy")
			if not t.is_empty() and t.pos.distance_to(hero.pos) < 30:
				_ai_fight(u, delta)
			else:
				u.pos = u.pos.move_toward(hero.pos + Vector2(14, 6), u.spd * delta)
		_:
			_ai_fight(u, delta)


func _ai_fight(u: Dictionary, delta: float) -> void:
	var t := _nearest(u.pos, "enemy")
	if t.is_empty():
		u.pos = u.pos.move_toward(hero.pos + Vector2(16, 4), u.spd * delta)
		return
	if u.pos.distance_to(t.pos) > 13:
		u.pos = u.pos.move_toward(t.pos, u.spd * delta)
	elif u.cd <= 0:
		u.cd = 0.8
		_slash(t.pos, Color(0.6, 0.9, 1))
		_hit(t, u.atk, Color(0.6, 0.9, 1))


func _do_betray(u: Dictionary) -> void:
	betray_done = true
	betray_armed = false
	fx.append({"type": "flash", "t": 0.0, "dur": 0.35, "color": Color(0.9, 0.2, 0.25, 0.45)})
	speak.emit("senior", "师弟，魔门的规矩你懂的。")
	if GS.has_perk("dodge_betrayal"):
		# 记忆带来的先知：闪身 + 反击
		hero.pos = _clamp_pos(hero.pos + Vector2(-22, 0))
		float_text.emit("我记得。", hero.pos + Vector2(0, -10), Color(0.36, 0.91, 0.77))
		var tw := create_tween()
		tw.tween_interval(0.6)
		tw.tween_callback(func():
			_slash(u.pos, Color(1, 0.84, 0.36))
			fx.append({"type": "line", "t": 0.0, "dur": 0.3, "a": hero.pos + Vector2(8, 8), "b": u.pos + Vector2(8, 8), "color": Color(1, 0.84, 0.36)})
			_hit(u, u.max_hp * 0.6, Color(1, 0.84, 0.36))
			shake = 0.3
			u.leaving = true
			u.team = "gone")
		betrayal.emit(true)
	else:
		_hit(hero, hero.max_hp * 0.55, Color(0.9, 0.2, 0.25))
		u.leaving = true
		u.team = "gone"
		betrayal.emit(false)


func _step_enemy(u: Dictionary, delta: float) -> void:
	u.cd -= delta
	var tgt := hero
	if not senior.is_empty() and senior.alive and senior.team == "ally" and u.pos.distance_to(senior.pos) < u.pos.distance_to(hero.pos) * 0.6:
		tgt = senior
	for a in units:
		if a.kind == "ally_npc" and a.alive and u.pos.distance_to(a.pos) < u.pos.distance_to(tgt.pos) * 0.6:
			tgt = a
	if u.pos.distance_to(tgt.pos) > 12:
		u.pos = u.pos.move_toward(tgt.pos, u.spd * delta)
	elif u.cd <= 0:
		u.cd = 1.3 if u.kind != "elder" else 1.6
		_hit(tgt, u.atk, Color(0.9, 0.2, 0.25))


func _hit(u: Dictionary, dmg: float, col: Color) -> void:
	if not u.alive or dmg <= 0.0:
		return
	u.hp -= dmg
	u.flash = 0.12
	float_text.emit(GS.fmt(dmg), u.pos + Vector2(rng.randf_range(0, 8), -4), col)
	if u.hp <= 0:
		if u == hero:
			_hero_dead(false)
			return
		u.alive = false
		u.corpse = 0.25
		fx.append({"type": "box", "t": 0.0, "dur": 0.3, "a": u.pos, "color": Color(1, 0.84, 0.36)})
		if u.team == "enemy":
			var reward := 4.0 * pow(1.3, GS.wave) * (8.0 if u.kind == "elder" else 1.0)
			GS.add_qi(reward)
			if u.kind == "elder":
				speak.emit("elder", "……本座记住你了。")
				Mem.remember("elder", "被第%d世的弟子击败" % GS.life, 5, -2)


func _hero_dead(scripted_death: bool) -> void:
	if not scripted_death and allow_pills and GS.pills > 0:
		GS.pills -= 1
		hero.hp = hero.max_hp * 0.5
		float_text.emit("保命丹！", hero.pos, Color(0.36, 0.91, 0.77))
		return
	hero.alive = false
	hero.rot = PI / 2
	running = false
	shake = 0.4
	fx.append({"type": "flash", "t": 0.0, "dur": 0.2, "color": Color(1, 1, 1, 0.55)})
	for i in 10:
		fx.append({"type": "blood", "t": 0.0, "dur": 0.8, "a": hero.pos + Vector2(8, 8), "b": Vector2(cos(i * 0.63), sin(i * 0.63) * 0.6), "color": Color(0.89, 0.2, 0.25)})
	if not scripted_death:
		hero_died.emit()


func _slash(at: Vector2, col: Color) -> void:
	fx.append({"type": "slash", "t": 0.0, "dur": 0.15, "a": at + Vector2(8, 8), "color": col, "r": rng.randf() * TAU})


func add_ring(at: Vector2, col: Color, r: float, dur := 0.8) -> void:
	fx.append({"type": "ring", "t": 0.0, "dur": dur, "a": at, "color": col, "r": r})


func add_flash(col: Color, dur := 0.35) -> void:
	fx.append({"type": "flash", "t": 0.0, "dur": dur, "color": col})


func add_shards(dur := 1.6) -> void:
	for i in 14:
		fx.append({"type": "shard", "t": 0.0, "dur": dur, "a": hero.pos + Vector2(8, 8), "r": float(i) / 14.0 * TAU, "color": Color(0.36, 0.91, 0.77)})


func screen_pos(world: Vector2) -> Vector2:
	return position + world * scale


func revive_hero() -> void:
	hero.alive = true
	hero.rot = 0.0
	hero.hp = GS.hero_hp()
	hero.max_hp = GS.hero_hp()
	hero.atk = GS.hero_atk()
	units = units.filter(func(u): return u.kind == "hero")
	senior = {}
	elder = {}


func refresh_hero_stats() -> void:
	var ratio: float = hero.hp / max(1.0, hero.max_hp)
	hero.max_hp = GS.hero_hp()
	hero.atk = GS.hero_atk()
	hero.hp = hero.max_hp * ratio


# ---------------- 绘制 ----------------

func _tile_rect(i: int) -> Rect2:
	return Rect2((i % 12) * 16, (i / 12) * 16, 16, 16)


func _draw() -> void:
	var off := Vector2.ZERO
	if shake > 0:
		off = Vector2(rng.randi_range(-2, 2), rng.randi_range(-2, 2))
	draw_rect(Rect2(Vector2(-4, -8), Vector2(WW + 8, WH + 16)), Color(0.1, 0.08, 0.15))
	for y in 7:
		for x in 9:
			draw_texture_rect_region(sheet, Rect2(Vector2(x * 16 - 4, y * 16 + 6) + off, Vector2(16, 16)), _tile_rect(floor_map[y][x]))
	for x in 9:
		draw_texture_rect_region(sheet, Rect2(Vector2(x * 16 - 4, -8) + off, Vector2(16, 16)), _tile_rect(40))
	draw_texture_rect_region(sheet, Rect2(Vector2(20, -2) + off, Vector2(16, 16)), _tile_rect(29))
	draw_texture_rect_region(sheet, Rect2(Vector2(100, -2) + off, Vector2(16, 16)), _tile_rect(29))
	var sorted := units.duplicate()
	sorted.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for u in sorted:
		var p: Vector2 = u.pos + off
		var mod := Color.WHITE
		if u.flash > 0:
			mod = Color(3, 3, 3)
		if u.kind == "senior" and u.tactic == "betray" and (betray_armed or betray_done):
			mod = mod * Color(1.6, 0.8, 0.8)
		if not u.alive and u.kind != "hero":
			mod.a = u.get("corpse", 0.0) * 4.0
		if u.rot != 0.0:
			draw_set_transform(p + Vector2(8, 12), u.rot, Vector2.ONE)
			draw_texture_rect_region(sheet, Rect2(Vector2(-8, -8), Vector2(16, 16)), _tile_rect(u.tile), mod)
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		else:
			draw_texture_rect_region(sheet, Rect2(p, Vector2(16, 16)), _tile_rect(u.tile), mod)
		if u.alive and u.hp < u.max_hp and u.team != "npc":
			var w: float = 14.0 * clampf(u.hp / u.max_hp, 0, 1)
			draw_rect(Rect2(p + Vector2(1, -3), Vector2(14, 2)), Color(0.08, 0.06, 0.1))
			var c := Color(0.36, 0.91, 0.77) if u.team != "enemy" else Color(0.89, 0.2, 0.25)
			draw_rect(Rect2(p + Vector2(1, -3), Vector2(w, 2)), c)
	for e in fx:
		var k: float = e.t / e.dur
		match e.type:
			"slash":
				draw_arc(e.a + off, 9.0, e.r, e.r + 2.2, 6, e.color, 1.5)
			"ring":
				draw_arc(e.a + off, e.r * (0.2 + k), 0, TAU, 24, Color(e.color, 1.0 - k), 1.5)
			"box":
				draw_rect(Rect2(e.a + Vector2(4, 4) + off, Vector2(8, 8)), Color(e.color, 1.0 - k), false, 1.0)
			"line":
				draw_line(e.a + off, e.b + off, Color(e.color, 1.0 - k), 2.0)
			"blood":
				var bp: Vector2 = e.a + e.b * (4 + k * 36) + Vector2(0, k * k * 26)
				draw_rect(Rect2(bp, Vector2(1.5, 1.5)), e.color)
			"shard":
				var rad := 70.0 * (1.0 - clampf(k * 1.1, 0, 1))
				var ang: float = e.r + e.t * 2.0
				draw_rect(Rect2(e.a + Vector2(cos(ang), sin(ang)) * rad - Vector2(1, 1), Vector2(2.5, 2.5)), e.color)
	for e in fx:
		if e.type == "flash":
			var c: Color = e.color
			c.a *= 1.0 - e.t / e.dur
			draw_rect(Rect2(Vector2(-4, -8), Vector2(WW + 8, WH + 16)), c)


# ---------------- 剧情模式 ----------------

## 舞台：对白时把说话的角色摆上台（不战斗）
func set_stage(names: Array) -> void:
	running = false
	units = units.filter(func(u): return u.kind == "hero")
	senior = {}
	elder = {}
	hero.alive = true
	hero.rot = 0.0
	hero.pos = Vector2(38, 62)
	var slots := [Vector2(84, 58), Vector2(104, 70), Vector2(96, 40), Vector2(114, 50)]
	var i := 0
	for n in names:
		if n in ["你", "旁白", "魔种"]:
			continue
		var tile: int = int(Story.data.characters.get(n, {}).get("tile", 88) if Story.data.characters.get(n, {}).get("tile") != null else 88)
		var a := _mk("actor", "prop", tile, slots[min(i, slots.size() - 1)], 1, 0, 0)
		a.actor = n
		units.append(a)
		i += 1


func actor_pos(name: String) -> Vector2:
	for u in units:
		if u.get("actor", "") == name:
			return u.pos
	return Vector2(-1, -1)


func spawn_ally(name: String, pos: Vector2) -> Dictionary:
	var a := _mk("ally_npc", "ally", ALLY_TILES.get(name, 88), pos, GS.hero_hp() * 0.7, GS.hero_atk() * 0.6, 30.0)
	a.actor = name
	units.append(a)
	return a


func spawn_boss(id: String, level: int, hp_mul := 1.0, atk_mul := 1.0) -> Dictionary:
	var b: Dictionary = BOSS.get(id, BOSS.elder)
	var hp := 60.0 * pow(1.3, level) * 6.0 * (1.5 if id == "master" else 1.0) * hp_mul
	var u := _mk("boss", "enemy", b.tile, Vector2(110, 40), hp, 3.0 * pow(1.22, level) * 2.5 * atk_mul, 18.0)
	u.boss_id = id
	u.actor = b.name
	units.append(u)
	running = true
	return u


func sacrifice() -> void:
	## 舍身：故意战死（死亡也是线索）
	if hero.alive:
		_hit(hero, hero.hp + 1.0, Color(0.9, 0.2, 0.25))
