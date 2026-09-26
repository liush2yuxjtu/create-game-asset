extends Node
## 全局状态：一念逍遥式挂机数值 + Universal Paperclips 式渐进解锁 + 轮回存档

signal changed
signal log_line(text: String)
signal ledger_line(text: String)
signal ending_reached

# Paperclips 式尺度跃迁：魔种把世界一层层「炼化」成魔元
const PHASES := [["外门", 1.0e3], ["魔门", 1.0e6], ["修仙界", 1.0e10], ["三千世界", 1.0e15]]

const SAVE_PATH := "user://momen_save.json"
const REALMS := ["炼气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫", "飞升"]

# Paperclips 式：每个升级在「累计魔元」到达 reveal 时才出现
const UPGRADES := {
	"tuna_auto": {"name": "吐纳自动化", "cost": 30.0, "grow": 0.0, "reveal": 15.0, "desc": "每秒自动吐纳一次"},
	"juling": {"name": "聚灵阵", "cost": 80.0, "grow": 2.6, "reveal": 50.0, "desc": "魔元产出 ×2"},
	"xuejian": {"name": "血剑", "cost": 60.0, "grow": 2.2, "reveal": 40.0, "desc": "攻击 ×1.5"},
	"hufa": {"name": "护体魔罡", "cost": 90.0, "grow": 2.2, "reveal": 70.0, "desc": "气血 ×1.5"},
	"mozhong": {"name": "魔种分裂", "cost": 2500.0, "grow": 3.0, "reveal": 1500.0, "desc": "魔种每 10 秒自我复制"},
	"duoshe": {"name": "夺舍秘术", "cost": 20000.0, "grow": 8.0, "reveal": 8000.0, "desc": "轮回时多带 1 条记忆"},
}

var life := 1
var qi := 0.0
var qi_total := 0.0          # 本世累计（用于渐进解锁）
var realm := 0
var wave := 1
var best_wave := 0
var upgrades := {}           # id -> level
var seeds := 0.0             # 魔种（Paperclips 式指数增长）
var dao_marks := 0           # 道痕：跨世永久加成（prestige）
var perks := []              # 本世生效的记忆 perk
var pills := 0               # 丹药：死亡时复活一次
var tutorial_done := false
var driver_key := ""         # Anthropic API key（仅存在玩家本机 user://）
var last_saved_unix := 0
var _tuna_timer := 0.0
var _seed_timer := 0.0
var _save_timer := 0.0
var paused := false
var conv := 0.0              # 已炼化总量
var ledger := []             # 纪事（冷峻旁白）
var milestones := {}         # 已触发的里程碑
var ended := false


func _ready() -> void:
	load_game()


func _process(delta: float) -> void:
	if paused:
		return
	var gain := qi_rate() * delta
	add_qi(gain)
	if level("tuna_auto") > 0:
		_tuna_timer += delta
		if _tuna_timer >= 1.0:
			_tuna_timer = 0.0
			tuna(false)
	if seeds > 0.0 and not ended:
		var before := phases_done()
		conv += seeds * 2.0 * realm_mult() * delta
		var after := phases_done()
		for i in range(before, after):
			dao_marks += 5 * (i + 1)
			note("%s：炼化完毕。" % PHASES[i][0])
		if after >= PHASES.size():
			ended = true
			note("万物皆成魔元。")
			ending_reached.emit()
		if seeds >= 1024.0:
			milestone("seeds_1024", "外门弟子已全部转化为魔种。")
	if qi_total >= 100.0:
		milestone("qi_100", "外门弟子开始注意到你。")
	if level("mozhong") > 0:
		_seed_timer += delta
		if _seed_timer >= 10.0:
			_seed_timer = 0.0
			seeds = max(1.0, seeds * (1.0 + 0.5 * level("mozhong")))
			changed.emit()
	_save_timer += delta
	if _save_timer > 5.0:
		_save_timer = 0.0
		save_game()


func level(id: String) -> int:
	return int(upgrades.get(id, 0))


func realm_mult() -> float:
	return pow(3.0, realm)


func qi_rate() -> float:
	var r := 1.2 * realm_mult() * pow(2.0, level("juling")) + seeds * 5.0
	r *= pow(10.0, phases_done())
	return r * (1.0 + 0.1 * dao_marks)


func tuna_power() -> float:
	return (1.0 + realm * 2.0) * pow(2.0, level("juling")) * (1.0 + 0.1 * dao_marks)


func tuna(manual := true) -> void:
	add_qi(tuna_power() * (3.0 if manual else 1.0))
	if manual:
		milestone("first_tuna", "你吐纳了一次。")


func note(text: String) -> void:
	ledger.append(text)
	if ledger.size() > 30:
		ledger = ledger.slice(ledger.size() - 20)
	ledger_line.emit(text)
	log_line.emit(text)


func milestone(id: String, text: String) -> void:
	if milestones.has(id):
		return
	milestones[id] = true
	note(text)


func phase_progress(i: int) -> float:
	var start := 0.0
	for j in i:
		start += PHASES[j][1]
	return clampf((conv - start) / PHASES[i][1], 0.0, 1.0)


func phases_done() -> int:
	var n := 0
	for i in PHASES.size():
		if phase_progress(i) >= 1.0:
			n += 1
	return n


## 账本数据（play 模式）：与视频/导演共用 ledger.gd 的 state 结构
func ledger_state() -> Dictionary:
	var rows := []
	for id in UPGRADES:
		if upgrade_visible(id) or level(id) > 0:
			var lv := level(id)
			var val := ""
			if id == "tuna_auto" and lv > 0:
				val = "已自动化"
			else:
				val = ("Lv%d  " % lv if lv > 0 else "") + fmt(upgrade_cost(id))
			rows.append([UPGRADES[id].name, val, qi >= upgrade_cost(id) or (id == "tuna_auto" and lv > 0), id])
	var phases := []
	if seeds > 0.0 or conv > 0.0:
		for i in PHASES.size():
			phases.append([PHASES[i][0], phase_progress(i)])
	return {"qi": qi, "rate": qi_rate(), "seeds": seeds, "rows": rows.slice(0, 4), "row_ids": rows.slice(0, 4).map(func(r): return r[3]),
		"phases": phases, "log": ledger.slice(max(0, ledger.size() - 6))}


func add_qi(v: float) -> void:
	qi += v
	qi_total += v
	changed.emit()


func hero_atk() -> float:
	return 9.0 * realm_mult() * pow(1.5, level("xuejian"))


func hero_hp() -> float:
	return 90.0 * realm_mult() * pow(1.5, level("hufa"))


func upgrade_cost(id: String) -> float:
	var u: Dictionary = UPGRADES[id]
	if u.grow <= 0.0:
		return u.cost
	return u.cost * pow(u.grow, level(id))


func upgrade_visible(id: String) -> bool:
	if id == "tuna_auto" and level(id) > 0:
		return false
	return qi_total >= UPGRADES[id].reveal or level(id) > 0


func buy(id: String) -> bool:
	var c := upgrade_cost(id)
	if qi < c:
		return false
	qi -= c
	upgrades[id] = level(id) + 1
	if id == "mozhong" and seeds < 1.0:
		seeds = 1.0
	log_line.emit("习得【%s】Lv%d" % [UPGRADES[id].name, level(id)])
	match id:
		"tuna_auto": milestone("auto", "吐纳已自动化。")
		"juling": milestone("juling", "聚灵阵成。")
		"mozhong": milestone("mozhong", "魔种开始自我复制。")
	changed.emit()
	return true


func break_cost() -> float:
	return 150.0 * pow(14.0, realm)


func can_break() -> bool:
	return realm < REALMS.size() - 1 and qi >= break_cost()


func breakthrough(free := false) -> bool:
	if not free and not can_break():
		return false
	if not free:
		qi -= break_cost()
	realm += 1
	log_line.emit("突破！%s → %s" % [REALMS[realm - 1], REALMS[realm]])
	changed.emit()
	return true


func memory_slots() -> int:
	return 1 + level("duoshe") + int(dao_marks / 10)


func has_perk(p: String) -> bool:
	return perks.has(p)


## 死亡 → 轮回。carried = 选中带入下一世的记忆卡 id 列表
func reincarnate(carried: Array) -> void:
	var gained := int(best_wave / 3) + realm * 2
	dao_marks += gained
	life += 1
	qi = 0.0
	qi_total = 0.0
	realm = 0
	wave = 1
	seeds = 0.0
	conv = 0.0
	ended = false
	milestones = {}
	ledger = []
	upgrades = {}
	perks = []
	pills = 0
	for id in carried:
		var c: Dictionary = Mem.card(id)
		if c.is_empty():
			continue
		perks.append(c.perk)
		if c.perk == "start_pill":
			pills += 1
		if c.perk == "realm_echo":
			realm = 1
		if c.perk == "seed_start":
			seeds = 1.0
			upgrades["mozhong"] = 1
	Mem.on_new_life(life, carried)
	log_line.emit("第 %d 世。道痕 +%d。你决定先苟住。" % [life, gained])
	save_game()
	changed.emit()


func fmt(n: float) -> String:
	if n >= 1e24:
		var e := int(floor(log(n) / log(10.0)))
		var sup := ""
		for ch in str(e):
			sup += "⁰¹²³⁴⁵⁶⁷⁸⁹"[int(ch)]
		return "%.2f×10%s" % [n / pow(10.0, e), sup]
	if n >= 1e20:
		return "%.1f垓" % (n / 1e20)
	if n >= 1e16:
		return "%.1f京" % (n / 1e16)
	if n >= 1e12:
		return "%.2f兆" % (n / 1e12)
	if n >= 1e8:
		return "%.2f亿" % (n / 1e8)
	if n >= 1e4:
		return "%.1f万" % (n / 1e4)
	if n >= 100:
		return str(int(n))
	return "%.1f" % n


func to_dict() -> Dictionary:
	return {
		"life": life, "qi": qi, "qi_total": qi_total, "realm": realm, "wave": wave, "best_wave": best_wave,
		"upgrades": upgrades, "seeds": seeds, "conv": conv, "ledger": ledger, "milestones": milestones, "ended": ended, "dao_marks": dao_marks, "perks": perks, "pills": pills,
		"tutorial_done": tutorial_done, "driver_key": driver_key, "saved_unix": int(Time.get_unix_time_from_system()),
		"memory": Mem.to_dict(),
		"story": Story.to_dict(),
	}


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(d) != TYPE_DICTIONARY:
		return
	life = int(d.get("life", 1))
	qi = float(d.get("qi", 0))
	qi_total = float(d.get("qi_total", 0))
	realm = int(d.get("realm", 0))
	wave = int(d.get("wave", 1))
	best_wave = int(d.get("best_wave", 0))
	upgrades = d.get("upgrades", {})
	seeds = float(d.get("seeds", 0))
	conv = float(d.get("conv", 0))
	ledger = d.get("ledger", [])
	milestones = d.get("milestones", {})
	ended = bool(d.get("ended", false))
	dao_marks = int(d.get("dao_marks", 0))
	perks = d.get("perks", [])
	pills = int(d.get("pills", 0))
	tutorial_done = bool(d.get("tutorial_done", false))
	driver_key = str(d.get("driver_key", ""))
	Mem.from_dict(d.get("memory", {}))
	Story.from_dict(d.get("story", {}))
	# 离线收益（一念逍遥式挂机）：最多 8 小时，五折
	var away: float = clamp(Time.get_unix_time_from_system() - float(d.get("saved_unix", 0)), 0.0, 8 * 3600.0)
	if away > 30:
		var g := qi_rate() * away * 0.5
		add_qi(g)
		call_deferred("emit_signal", "log_line", "闭关 %d 分钟，得魔元 %s" % [int(away / 60), fmt(g)])


func wipe() -> void:
	var dk := driver_key
	life = 1; qi = 0; qi_total = 0; realm = 0; wave = 1; best_wave = 0; upgrades = {}
	seeds = 0; conv = 0; ledger = []; milestones = {}; ended = false; dao_marks = 0; perks = []; pills = 0; tutorial_done = false
	driver_key = dk
	Mem.reset()
	save_game()
	changed.emit()
