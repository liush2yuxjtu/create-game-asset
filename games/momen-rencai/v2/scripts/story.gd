extends Node
## 剧情引擎（与 tools/verify_story.py 同一套语义）
## 一世 = 从第一章走到死亡或结局；记忆碎片：本世拿到的是「未铭刻」，死亡时玩家主动选一片铭刻，之后每一世可用。
## echo 回响：本世设下的回响，只影响下一世。冲突层：一旦揭开，永久记录（跨世）。

signal node_entered(node: Dictionary)
signal layer_found(layer_id: String)
signal frag_gained(frag_id: String)
signal metric_changed(key: String, delta: int)
signal died(node: Dictionary)
signal chapter_finished(n: int)
signal chapter_started(n: int)
signal ending_reached(ending_id: String)

var D: Dictionary
var nodes: Dictionary
var chapters := {}
var all_layers: Array = []

# ---- 跨世（永久） ----
var life := 1
var awake: Array = []          # 已铭刻碎片
var frag_log := {}             # fid -> {life, ch}  所有见过的碎片（残影可回看）
var layers: Array = []         # 已揭开的冲突层
var endings: Array = []        # 已达成结局
var echo_prev: Array = []      # 上一世留下的回响
var deaths := 0
# ---- 本世 ----
var flags: Array = []
var m := {}                    # 数值：只在本世有效
var fresh: Array = []          # 本世新得、尚未铭刻的碎片
var echo_cur: Array = []
var ch := 1
var cur := ""                  # 当前节点
var used_here: Array = []      # 本节点主动使用过的碎片
var chapter_snapshot := {}     # 回溯本章用
var last_death := {}


func _ready() -> void:
	D = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	nodes = D.nodes
	for c in D.chapters:
		chapters[int(c.n)] = c
		for l in c.layers:
			all_layers.append(l.id)


func node() -> Dictionary:
	return nodes.get(cur, {})


func frag(fid: String) -> Dictionary:
	return D.frags.get(fid, {})


func chapter(n := -1) -> Dictionary:
	return chapters.get(ch if n < 0 else n, {})


func metric_key(n := -1) -> String:
	return str(chapter(n).get("metric", ""))


# ======================= 条件与效果 =======================

func cond(c, skill := false) -> bool:
	if c == null or (c is Dictionary and c.is_empty()):
		return true
	for f in c.get("flag", []):
		if not flags.has(f): return false
	for f in c.get("noflag", []):
		if flags.has(f): return false
	for f in c.get("echo", []):
		if not echo_prev.has(f): return false
	for f in c.get("noecho", []):
		if echo_prev.has(f): return false
	var mm: Dictionary = c.get("m", {})
	for k in mm:
		var op: String = mm[k][0]
		var n := int(mm[k][1])
		var v := int(m.get(k, 0))
		var ok := false
		match op:
			">=": ok = v >= n
			"<=": ok = v <= n
			">": ok = v > n
			"<": ok = v < n
			"==": ok = v == n
		if not ok: return false
	if c.has("skill") and not (c.skill == "block" and skill):
		return false
	return true


func add_metric(k: String, d: int) -> void:
	if d == 0: return
	m[k] = int(m.get(k, 0)) + d
	metric_changed.emit(k, d)


func apply_fx(fx) -> void:
	if fx == null or not (fx is Dictionary): return
	var mm: Dictionary = fx.get("m", {})
	for k in mm:
		add_metric(k, int(mm[k]))
	for r in fx.get("m_if", []):
		if cond(r["if"]):
			for k in r.m:
				add_metric(k, int(r.m[k]))
	for f in fx.get("set", []):
		if not flags.has(f): flags.append(f)
	for f in fx.get("echo", []):
		if not echo_cur.has(f): echo_cur.append(f)
	if fx.has("frag"):
		gain_frag(fx.frag)
	if fx.has("layer") and not layers.has(fx.layer):
		layers.append(fx.layer)
		layer_found.emit(fx.layer)
	for mem in fx.get("mem", []):
		Mem.remember(mem.a, mem.text, int(mem.get("i", 3)), int(mem.get("v", 0)))


func gain_frag(fid: String) -> void:
	if not frag_log.has(fid):
		frag_log[fid] = {"life": life, "ch": ch}
	if awake.has(fid) or fresh.has(fid):
		return
	fresh.append(fid)
	frag_gained.emit(fid)


# ======================= 流程 =======================

func new_game(start_life := 99) -> void:
	life = start_life
	awake = []; frag_log = {}; layers = []; endings = []; echo_prev = []; deaths = 0
	Mem.reset()
	Mem.life = life
	_reset_life()


func _reset_life() -> void:
	flags = []; m = {}; fresh = []; echo_cur = []; ch = 1; cur = ""; used_here = []
	last_death = {}


## 开始一世（从第一章）
func begin_life() -> void:
	_reset_life()
	start_chapter(1)


func next_life() -> void:
	life += 1
	Mem.life = life
	echo_prev = echo_cur.duplicate()
	begin_life()


func start_chapter(n: int) -> void:
	ch = n
	var mk := metric_key(n)
	if not m.has(mk):
		m[mk] = int(D.metrics[mk].start)
	chapter_snapshot = {"flags": flags.duplicate(), "m": m.duplicate(), "fresh": fresh.duplicate(), "echo_cur": echo_cur.duplicate()}
	chapter_started.emit(n)
	enter(str(chapter(n).start))


## 回溯：回到本章开头（本世状态回到进本章时；已铭刻的碎片、已揭开的层保留）
func rewind_chapter() -> void:
	flags = chapter_snapshot.flags.duplicate()
	m = chapter_snapshot.m.duplicate()
	fresh = chapter_snapshot.fresh.duplicate()
	echo_cur = chapter_snapshot.echo_cur.duplicate()
	last_death = {}
	chapter_started.emit(ch)
	enter(str(chapter().start))


func enter(nid: String) -> void:
	cur = nid
	used_here = []
	var n := node()
	apply_fx(n.get("fx"))
	if n.has("check"):
		for r in n.check:
			if cond(r.get("if")):
				enter(r.to)
				return
	node_entered.emit(n)
	if n.has("death"):
		deaths += 1
		gain_frag(n.death.frag)
		last_death = n
		died.emit(n)
	elif n.has("chapter_end"):
		chapter_finished.emit(ch)
	elif n.has("ending"):
		if not endings.has(n.ending):
			endings.append(n.ending)
		ending_reached.emit(n.ending)


func advance() -> void:  # auto 节点点一下
	var n := node()
	if n.has("auto"):
		enter(n.auto)
	elif n.has("chapter_end"):
		start_chapter(int(n.chapter_end))


func is_usable(fid: String) -> bool:
	return awake.has(fid)


## 当前可见的选项。隐藏选项（req.frag）只在本节点主动使用过该碎片后出现
func choices() -> Array:
	var out := []
	for c in node().get("choices", []):
		if _choice_ok(c, false):
			out.append(c)
	return out


func _choice_ok(c: Dictionary, allow_unused_frag: bool) -> bool:
	var req: Dictionary = c.get("req", {}).duplicate()
	if req.has("frag"):
		var f: String = req.frag
		if not is_usable(f): return false
		if not allow_unused_frag and not used_here.has(f): return false
		req.erase("frag")
	return cond(req)


## 自由输入可以命中的选项：可见的 + 已铭刻碎片能解开的隐藏选项
func free_candidates() -> Array:
	var out := []
	for c in node().get("choices", []):
		if _choice_ok(c, true):
			out.append(c)
	return out


func find_choice(cid: String) -> Dictionary:
	for c in node().get("choices", []):
		if c.id == cid:
			return c
	return {}


## 主动使用一片碎片。返回 "reveal"（解开隐藏选项）/"known"（已用过）/"useless"/"locked"（未铭刻）
func use_frag(fid: String) -> String:
	if not awake.has(fid):
		return "locked"
	var n := node()
	if not n.get("hook", []).has(fid):
		return "useless"
	if used_here.has(fid):
		return "known"
	var any := false
	for c in n.get("choices", []):
		if c.get("req", {}).get("frag", "") == fid:
			var req: Dictionary = c.req.duplicate()
			req.erase("frag")
			if cond(req):
				any = true
	if not any:
		return "useless"
	used_here.append(fid)
	return "reveal"


func choose(cid: String) -> void:
	var c := find_choice(cid)
	if c.is_empty():
		push_warning("no choice " + cid)
		return
	var f: String = c.get("req", {}).get("frag", "")
	if f != "" and not used_here.has(f):
		used_here.append(f)  # 自由输入直接说中 = 主动想起
	apply_fx(c.get("fx"))
	enter(c.to)


## 战斗：返回命中的 outcome（不推进）。skill=玩家在背刺前一刻切到「守」
func battle_outcome(skill: bool) -> Dictionary:
	for r in node().get("battle", {}).get("outcomes", []):
		if cond(r.get("if"), skill):
			return r
	return {}


func battle_will_betray() -> bool:
	# 若任何 outcome 带 betray，且前面的非背刺分支都不成立，则会背刺
	for r in node().get("battle", {}).get("outcomes", []):
		if r.has("if") and r["if"].has("skill"):
			continue
		if cond(r.get("if")):
			return bool(r.get("betray", false))
	return false


func finish_battle(skill: bool) -> void:
	var r := battle_outcome(skill)
	enter(r.to)


## 死亡时铭刻一片
func awaken(fid: String) -> bool:
	if not fresh.has(fid):
		return false
	fresh.erase(fid)
	if not awake.has(fid):
		awake.append(fid)
	return true


func chapter_layers(n: int) -> Array:
	var out := []
	for l in chapter(n).layers:
		out.append({"id": l.id, "title": l.title, "found": layers.has(l.id)})
	return out


func remembered_count() -> int:
	return int(m.get("yi", 0))


# ======================= 存档 =======================

func to_dict() -> Dictionary:
	return {"life": life, "awake": awake, "frag_log": frag_log, "layers": layers, "endings": endings,
		"echo_prev": echo_prev, "deaths": deaths, "flags": flags, "m": m, "fresh": fresh, "echo_cur": echo_cur,
		"ch": ch, "cur": cur, "snap": chapter_snapshot}


func from_dict(d: Dictionary) -> void:
	life = int(d.get("life", 99)); awake = d.get("awake", []); frag_log = d.get("frag_log", {})
	layers = d.get("layers", []); endings = d.get("endings", []); echo_prev = d.get("echo_prev", [])
	deaths = int(d.get("deaths", 0)); flags = d.get("flags", []); m = d.get("m", {}); fresh = d.get("fresh", [])
	echo_cur = d.get("echo_cur", []); ch = int(d.get("ch", 1)); cur = str(d.get("cur", ""))
	chapter_snapshot = d.get("snap", {"flags": [], "m": {}, "fresh": [], "echo_cur": []})
	for k in m.keys():
		m[k] = int(m[k])
