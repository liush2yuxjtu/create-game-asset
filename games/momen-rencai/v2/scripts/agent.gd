extends Node
## Agent 驱动角色 —— OpenGameAgent 协议：
##   GameInput{sessionId, actorId, type, payloadJson, moment{timeline, tick}, inputId}
##   → 模型输出 typed tool calls → 游戏校验后执行（游戏始终是权威方）
## 驱动：Claude Haiku 4.5（claude-haiku-4-5）。三层自动降级：自己的 key → claude.ai 账号（Artifact 内）→ 离线规则。
## 离线规则输出同一套 tool calls，游戏逻辑只有一条路径。
##
## 本版用到的工具：
##   offer_options  为玩家生成 N 个选项的措辞（每条必须对应游戏给的 choice_id）
##   interpret      把玩家的自由输入映射到一个 choice_id（或空=没对上），并以角色身份回一句
##   set_tactic     战斗中行动（只能从游戏允许的集合里选）
##   say / remember 台词 / 写进角色的跨世记忆

signal driver_changed(label: String)

const MODEL := "claude-haiku-4-5"
const API := "https://api.anthropic.com/v1/messages"
const TIMEOUT := 8.0

const TOOLS := [
	{"name": "offer_options", "description": "为玩家（主角「我」）写出本节点的选项措辞。每条 choice_id 必须来自 GameInput 给的列表，一条都不能多、不能少；text 是主角会说/做的话，口语，不超过14个汉字，保持该选项的意图。",
		"input_schema": {"type": "object", "properties": {"options": {"type": "array", "items": {"type": "object", "properties": {"choice_id": {"type": "string"}, "text": {"type": "string"}}, "required": ["choice_id", "text"]}}}, "required": ["options"]}},
	{"name": "interpret", "description": "玩家在输入框里自由说了一句话。判断它最接近哪个 choice_id（只能从 candidates 里选；都不沾边就填空字符串），再以你的角色身份回一句不超过24字的话。deflect_topics 里的话题：玩家没有证据时你要搪塞。",
		"input_schema": {"type": "object", "properties": {"choice_id": {"type": "string"}, "reply": {"type": "string"}}, "required": ["choice_id", "reply"]}},
	{"name": "set_tactic", "description": "决定本场战斗里你的行动，只能从 allowed_tactics 里选。assist=帮忙杀敌; guard=贴身护卫; idle=袖手旁观; betray=背刺。",
		"input_schema": {"type": "object", "properties": {"tactic": {"type": "string"}, "say": {"type": "string"}}, "required": ["tactic", "say"]}},
	{"name": "remember", "description": "把这件事记进你的长期记忆（会跨世保留、逐渐淡去）。valence -2 深仇 … +2 大恩；importance 1..5。",
		"input_schema": {"type": "object", "properties": {"text": {"type": "string"}, "importance": {"type": "integer"}, "valence": {"type": "integer"}}, "required": ["text", "importance", "valence"]}},
]

var session_id := ""
var tick := 0
var last_driver := "离线规则"
var last_error := ""
var calls_made := 0
var force_offline := false   # 录屏/自测时强制离线，保证可复现


func _ready() -> void:
	session_id = "s%d" % Time.get_unix_time_from_system()


func has_key() -> bool:
	return GS.driver_key.strip_edges().begins_with("sk-")


func driver_label() -> String:
	if force_offline:
		return "离线规则"
	if has_key():
		return "Haiku 4.5"
	if account_ai_enabled():
		return "Claude 账号"
	return "离线规则"


func ai_live() -> bool:
	return not force_offline and (has_key() or account_ai_enabled())


func account_ai_enabled() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("window.momenAIEnabled === true", true))


func persona(actor: String) -> String:
	return str(Story.D.cast.get(actor, {}).get("persona", ""))


func _game_input(actor: String, type: String, payload: Dictionary) -> Dictionary:
	tick += 1
	payload["your_memories"] = Mem.recall(actor, 5)
	payload["relation_to_player"] = snappedf(Mem.relation(actor), 1.0)
	payload["recent_events"] = Mem.recent(4)
	payload["life"] = Story.life
	return {"sessionId": session_id, "actorId": actor, "type": type, "payloadJson": JSON.stringify(payload),
		"moment": {"timeline": "life_%d" % Story.life, "tick": tick}, "inputId": "%s-%d" % [session_id, tick]}


func _node_ctx() -> Dictionary:
	var n := Story.node()
	return {"chapter": Story.chapter().get("title", ""), "scene_text": n.get("text", [])}


# ======================= 对外接口 =======================

## 返回 {cid: text}
func offer_options(actor: String, choices: Array) -> Dictionary:
	var out := offline_options(choices)
	if not ai_live() or actor == "":
		_set_driver("离线规则")
		return out
	var p := _node_ctx()
	p["choices"] = choices.map(func(c): return {"choice_id": c.id, "intent": c.text[0]})
	var calls := await _call(actor, _game_input(actor, "offer_options", p), "offer_options", 400)
	for c in calls:
		if c.name == "offer_options":
			for o in c.input.get("options", []):
				var cid := str(o.get("choice_id", ""))
				if out.has(cid) and str(o.get("text", "")).strip_edges() != "":
					out[cid] = str(o.text).strip_edges().substr(0, 18)
	return out


## 返回 {choice_id, reply, driver}
func interpret(actor: String, text: String, candidates: Array, teases: Dictionary, others: Array) -> Dictionary:
	var off := offline_interpret(text, candidates, teases, others)
	if not ai_live() or actor == "":
		_set_driver("离线规则")
		return off
	var p := _node_ctx()
	p["player_said"] = text
	p["candidates"] = candidates.map(func(c): return {"choice_id": c.id, "intent": c.text[0]})
	p["deflect_topics"] = teases.keys()
	var calls := await _call(actor, _game_input(actor, "player_free_input", p), "interpret", 300)
	for c in calls:
		if c.name == "interpret":
			var cid := str(c.input.get("choice_id", ""))
			var ok := false
			for cc in candidates:
				if cc.id == cid:
					ok = true
			var reply := str(c.input.get("reply", "")).substr(0, 30)
			if reply == "":
				reply = off.reply
			return {"choice_id": cid if ok else "", "reply": reply, "driver": last_driver}
		elif c.name == "remember":
			Mem.remember(actor, str(c.input.get("text", "")), int(c.input.get("importance", 2)), int(c.input.get("valence", 0)))
	return off


## 战斗前：返回 {tactic, say}；tactic 必在 allowed 里（游戏权威）
func battle_tactic(actor: String, allowed: Array, ctx: Dictionary) -> Dictionary:
	var off := offline_tactic(actor, allowed)
	if not ai_live() or actor == "" or not Story.D.cast.has(actor):
		return off
	ctx["allowed_tactics"] = allowed
	var calls := await _call(actor, _game_input(actor, "battle_start", ctx), "set_tactic", 200)
	for c in calls:
		if c.name == "set_tactic":
			var t := str(c.input.get("tactic", ""))
			return {"tactic": t if allowed.has(t) else off.tactic, "say": str(c.input.get("say", off.say)).substr(0, 20)}
	return off


# ======================= 离线规则（同一套输出） =======================

func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash("%s|%d|%d" % [Story.cur, Story.life, tick])
	return r


func offline_options(choices: Array) -> Dictionary:
	var r := _rng()
	var out := {}
	for c in choices:
		var arr: Array = c.text
		out[c.id] = str(arr[r.randi() % arr.size()]) if not GS.isolated else str(arr[0])
	return out


func offline_interpret(text: String, candidates: Array, teases: Dictionary, others: Array) -> Dictionary:
	var best := ""
	var best_score := 0
	for c in candidates:
		var s := 0
		for k in c.get("kw", []):
			if text.contains(str(k)):
				s += 2 + str(k).length()
		if c.get("req", {}).has("frag") and s > 0:
			s += 3  # 说中了记忆里的东西，优先
		if s > best_score:
			best_score = s
			best = c.id
	if best != "":
		return {"choice_id": best, "reply": "", "driver": "离线规则"}
	for k in teases:
		if text.contains(str(k)):
			return {"choice_id": "", "reply": str(teases[k]), "driver": "离线规则", "tease": true}
	var r := _rng()
	var reply := str(others[r.randi() % others.size()]) if others.size() > 0 else "……"
	return {"choice_id": "", "reply": reply, "driver": "离线规则"}


func offline_tactic(actor: String, allowed: Array) -> Dictionary:
	var t: String = allowed[0] if allowed.size() > 0 else "idle"
	var lines := {"betray": "师弟，小心身后~", "assist": "一起上！", "guard": "站我后面。", "idle": "……"}
	if actor == "lihan" and t == "assist" and Mem.strongest_past("lihan").get("valence", 0) < 0:
		lines["assist"] = "上一世的账，先记着。"
	return {"tactic": t, "say": lines.get(t, "……")}


func _set_driver(l: String) -> void:
	if l != last_driver:
		last_driver = l
		driver_changed.emit(l)


# ======================= 模型调用 =======================

func _call(actor: String, gi: Dictionary, tool: String, max_tokens: int) -> Array:
	if has_key():
		var r := await _call_haiku(actor, gi, tool, max_tokens)
		if r.size() > 0:
			_set_driver("Haiku 4.5")
			return r
	elif account_ai_enabled():
		var r2 := await _call_account(actor, gi, tool)
		if r2.size() > 0:
			_set_driver("Claude 账号")
			return r2
	_set_driver("离线规则")
	return []


func _call_haiku(actor: String, gi: Dictionary, tool: String, max_tokens: int) -> Array:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var sys := persona(actor) + "\n你在一个魔门修仙文字游戏里扮演这个角色。只能根据 GameInput 里的状态和你的记忆行动；说话简短、口语、有魔门味。你不知道玩家没说出口的事。"
	var tools := TOOLS.filter(func(t): return t.name == tool or t.name == "remember")
	var body := {"model": MODEL, "max_tokens": max_tokens, "system": sys, "tools": tools,
		"tool_choice": {"type": "any"},
		"messages": [{"role": "user", "content": "GameInput:\n" + JSON.stringify(gi)}]}
	var headers := ["content-type: application/json", "x-api-key: " + GS.driver_key.strip_edges(),
		"anthropic-version: 2023-06-01", "anthropic-dangerous-direct-browser-access: true"]
	var err := http.request(API, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		last_error = "request err %d" % err
		return []
	var r: Array = await http.request_completed
	http.queue_free()
	calls_made += 1
	var code: int = r[1]
	var txt: String = (r[3] as PackedByteArray).get_string_from_utf8()
	if code != 200:
		last_error = "HTTP %d %s" % [code, txt.substr(0, 120)]
		push_warning("Haiku: " + last_error)
		return []
	var d = JSON.parse_string(txt)
	if typeof(d) != TYPE_DICTIONARY:
		return []
	var out := []
	for b in d.get("content", []):
		if b.get("type", "") == "tool_use":
			out.append({"name": b.name, "input": b.input})
	last_error = ""
	return out


func _call_account(actor: String, gi: Dictionary, tool: String) -> Array:
	var tools := TOOLS.filter(func(t): return t.name == tool)
	var prompt := persona(actor) + "\n可用工具(JSON Schema)：" + JSON.stringify(tools) + \
		"\n只回复一个 JSON：{\"calls\":[{\"name\":\"" + tool + "\",\"input\":{...}}]}\nGameInput:\n" + JSON.stringify(gi)
	var id := "q%d" % tick
	JavaScriptBridge.eval("window.momenAsk && window.momenAsk(%s, %s)" % [JSON.stringify(id), JSON.stringify(prompt)], true)
	for i in 100:
		await get_tree().create_timer(0.2).timeout
		var r = JavaScriptBridge.eval("window.momenTake ? window.momenTake(%s) : ''" % JSON.stringify(id), true)
		if typeof(r) == TYPE_STRING and r != "":
			if r.begins_with("ERR"):
				last_error = r
				return []
			var d = JSON.parse_string(r)
			if typeof(d) == TYPE_DICTIONARY and d.get("calls") is Array:
				calls_made += 1
				return d.calls
			return []
	last_error = "timeout"
	return []
