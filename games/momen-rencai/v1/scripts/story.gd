extends Node
## 剧情引擎（autoload "Story"）—— 读 data/story.json（与流程图设计稿同源）
## 规则：分支 → 章末收束；死亡授予轮回记忆并回到本章开头（本章标记回滚、记忆保留）；
##       记忆/标记锁住选项（《底特律》式线索）；终章选项由累计标记解锁 → 8 结局。

signal node_entered(node: Dictionary)
signal chapter_started(chapter: Dictionary)
signal chapter_finished(chapter: Dictionary)
signal memory_gained(mem_id: String, text: String)
signal ending_reached(node: Dictionary)

var data: Dictionary
var nodes := {}          # id -> node
var chapter_of := {}     # node id -> chapter dict
var st := {}             # 可存档的剧情状态


func _ready() -> void:
	data = JSON.parse_string(FileAccess.get_file_as_string("res://data/story.json"))
	for ch in data.chapters:
		for n in ch.nodes:
			nodes[n.id] = n
			chapter_of[n.id] = ch
	if st.is_empty():
		reset_state(false)


func reset_state(keep_meta: bool) -> void:
	var seen_all: Dictionary = st.get("seen_all", {}) if keep_meta else {}
	var endings: Dictionary = st.get("endings", {}) if keep_meta else {}
	var snaps: Dictionary = st.get("snaps", {}) if keep_meta else {}
	var mem: Array = st.get("mem", []) if keep_meta else []
	var runs: int = int(st.get("runs", 0)) if keep_meta else 0
	st = {"node": "", "flags": data.flags.duplicate(true), "mem": mem.duplicate(), "pills": 0,
		"seen": {}, "seen_all": seen_all, "endings": endings, "snaps": snaps, "chapter_snap": {},
		"runs": runs, "deaths": 0, "active": false}


func to_dict() -> Dictionary:
	return st.duplicate(true)


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return
	reset_state(false)
	for k in d:
		st[k] = d[k]


# ───────────── 查询 ─────────────

func node() -> Dictionary:
	return nodes.get(st.node, {})


func chapter() -> Dictionary:
	return chapter_of.get(st.node, data.chapters[0])


func chapter_index(ch: Dictionary = {}) -> int:
	var c := ch if not ch.is_empty() else chapter()
	return data.chapters.find(c)


func mem_text(id: String) -> String:
	return str(data.memories.get(id, id))


func flag(k: String):
	if k == "mems":
		return st.mem.size()
	return st.flags.get(k, data.flags.get(k))


func cond_ok(c: Array) -> bool:
	var k: String = c[0]
	var op: String = c[1]
	var v = c[2]
	if op == "has":
		return st.mem.has(v)
	var x = flag(k)
	match op:
		"==": return x == v
		"!=": return x != v
		">=": return float(x) >= float(v)
		"<=": return float(x) <= float(v)
		"<": return float(x) < float(v)
		">": return float(x) > float(v)
		"in": return (v as Array).has(x)
	return false


func all_ok(conds) -> bool:
	for c in (conds if conds is Array else []):
		if not cond_ok(c):
			return false
	return true


func cond_text(c: Array) -> String:
	if c[1] == "has":
		return "记忆「%s」" % mem_text(c[2])
	var names := {"senior": "厉寒", "suwan": "苏晚", "elder": "血骨", "gu": "顾长风", "seed": "魔种", "seed_feed": "喂养", "mems": "记忆数",
		"know_seed": "知晓魔种", "elder_respect": "长老青睐", "senior_rel": "厉寒好感"}
	var vals := {"loyal": "同袍", "debt": "欠命", "saved": "得救", "ally": "盟友", "blackmailed": "被要挟", "merged": "相融",
		"refused": "抗拒", "sealed": "封印", "turned": "反噬", "true": "是"}
	var k: String = names.get(c[0], c[0])
	var v = c[2]
	if v is Array:
		v = "/".join(v.map(func(x): return vals.get(str(x), str(x))))
	else:
		v = vals.get(str(v).to_lower(), str(v))
	var op: String = {"==": "=", "in": "∈", "!=": "≠"}.get(c[1], c[1])
	return "%s%s%s" % [k, op, v]


## 选项列表（含锁定信息），供 UI 显示
func options() -> Array:
	var n := node()
	var out := []
	if n.get("type", "") != "choice":
		return out
	for i in n.options.size():
		var o: Dictionary = n.options[i]
		var ok := all_ok(o.get("req", []))
		var need := []
		if not ok:
			for c in o.get("req", []):
				if not cond_ok(c):
					need.append(cond_text(c))
		out.append({"i": i, "label": o.label, "ok": ok, "need": "需要：" + "；".join(need) if need.size() else "", "key": o.get("key", false)})
	return out


# ───────────── 推进 ─────────────

func start_new(keep_memories: bool) -> void:
	reset_state(true)
	if not keep_memories:
		st.mem = []
	st.runs = int(st.runs) + 1
	st.active = true
	goto("ch1_open")


func start_chapter(idx: int) -> void:
	var ch: Dictionary = data.chapters[idx]
	var snap: Dictionary = st.snaps.get(ch.id, {})
	if not snap.is_empty():
		st.flags = snap.duplicate(true)
	st.seen = {}
	st.active = true
	goto(ch.nodes[0].id)


func goto(id: String) -> void:
	if not nodes.has(id):
		push_error("story: missing node " + id)
		return
	var ch: Dictionary = chapter_of[id]
	var first: bool = ch.nodes[0].id == id
	var prev_ch: Dictionary = chapter_of.get(st.node, {})
	st.node = id
	st.seen[id] = true
	st.seen_all[id] = true
	if first:
		st.chapter_snap = st.flags.duplicate(true)
		st.snaps[ch.id] = st.flags.duplicate(true)
		if prev_ch != ch:
			chapter_started.emit(ch)
	var n := node()
	if n.type == "ending":
		st.endings[id] = true
		st.active = false
		ending_reached.emit(n)
	node_entered.emit(n)


func apply_set(sets) -> void:
	if not (sets is Dictionary):
		return
	for k in sets:
		var v = sets[k]
		if k == "+mem":
			if not st.mem.has(v):
				st.mem.append(v)
				memory_gained.emit(v, mem_text(v))
		elif k == "pills":
			st.pills = int(st.pills) + int(v)
		elif v is bool or v is String:
			st.flags[k] = v
		else:
			st.flags[k] = int(st.flags.get(k, data.flags.get(k, 0))) + int(v)


## scene / converge 的「下一步」
func advance() -> void:
	var n := node()
	match n.type:
		"scene":
			apply_set(n.get("set", {}))
			_mark_opt_seen("")
			goto(n.next)
		"converge":
			chapter_finished.emit(chapter())
		"death":
			var g: String = n.grant
			st.deaths = int(st.deaths) + 1
			st.flags = st.chapter_snap.duplicate(true)
			if not st.mem.has(g):
				st.mem.append(g)
				memory_gained.emit(g, mem_text(g))
			goto(n.rewind)


## 收束点之后进入下一章
func next_chapter() -> void:
	var n := node()
	if n.type == "converge":
		goto(n.next)


func choose(i: int) -> bool:
	var n := node()
	if n.type != "choice" or i < 0 or i >= n.options.size():
		return false
	var o: Dictionary = n.options[i]
	if not all_ok(o.get("req", [])):
		return false
	var nxt: String = o.get("next", "")
	for pair in o.get("next_if", []):
		if all_ok(pair[0]):
			nxt = pair[1]
			break
	apply_set(o.get("set", {}))
	_mark_opt_seen("%s#%d" % [n.id, i])
	goto(nxt)
	return true


func timeout() -> void:
	var n := node()
	if n.get("timeout_next", "") != "":
		goto(n.timeout_next)


func battle_result(win: bool) -> void:
	var n := node()
	if n.type == "battle":
		goto(n.win if win else n.lose)


func ledger_result(taps: int) -> void:
	var n := node()
	if n.type == "ledger":
		st.flags.seed_feed = int(st.flags.get("seed_feed", 0)) + taps * 3
		goto(n.next)


func _mark_opt_seen(vid: String) -> void:
	if vid != "":
		st.seen[vid] = true
		st.seen_all[vid] = true


## 第六章：谁会站到你身边
func allies() -> Array:
	var out := []
	if st.flags.senior in ["loyal", "debt"]:
		out.append("厉寒")
	if st.flags.suwan == "saved":
		out.append("苏晚")
	if st.flags.elder == "ally":
		out.append("血骨")
	if st.flags.gu == "ally":
		out.append("顾长风")
	return out


func chapter_progress(ch: Dictionary) -> Vector2i:
	var total := 0
	var seen := 0
	for v in ch.layout.nodes:
		total += 1
		if st.seen_all.has(v.vid):
			seen += 1
	return Vector2i(seen, total)


func reached_chapters() -> Array:
	var out := []
	for ch in data.chapters:
		if st.seen_all.has(ch.nodes[0].id):
			out.append(ch)
	return out
