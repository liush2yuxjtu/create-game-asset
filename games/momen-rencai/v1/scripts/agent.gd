extends Node
## Agent-driven character behavior —— 按 OpenGameAgent 的协议组织：
##   GameInput{sessionId, actorId, type, payloadJson, moment{timeline,tick}}
##   → 模型流式输出 typed tool calls
##   → 游戏代码校验并执行（游戏始终是权威方），返回 receipt
## 驱动模型：Claude Haiku 4.5（claude-haiku-4-5）。没有 key / 网络失败时降级为离线规则策略，
## 离线策略输出同样的 tool calls，所以游戏逻辑只有一条路径。

signal driver_changed(label: String)

const MODEL := "claude-haiku-4-5"
const API := "https://api.anthropic.com/v1/messages"
const TIMEOUT := 8.0

const PERSONAS := {
	"senior": "你是魔门外门师兄「厉寒」。性格：精明、记仇、会审时度势；嘴上叫师弟，心里只看利益。魔门规矩是弱肉强食，背刺同门不算罪，被发现才算。",
	"elder": "你是魔门「血骨长老」，外门考核官。阴沉、多疑，最怕火（这是秘密）。你会考验、敲打弟子，也会记住谁冒犯过你。",
}

const TOOLS := [
	{"name": "set_tactic", "description": "决定本波战斗中你的行动。assist=帮师弟杀敌; guard=贴身护卫; idle=袖手旁观; betray=趁乱背刺师弟; test=(长老)出手试探; crush=(长老)全力镇压。", "input_schema": {"type": "object", "properties": {"tactic": {"type": "string", "enum": ["assist", "guard", "idle", "betray", "test", "crush"]}, "reason": {"type": "string"}}, "required": ["tactic", "reason"]}},
	{"name": "say", "description": "对师弟说一句话（不超过 20 个汉字，口语、有魔门味）。", "input_schema": {"type": "object", "properties": {"text": {"type": "string"}}, "required": ["text"]}},
	{"name": "remember", "description": "把这件事记进你的长期记忆（会跨世保留并逐渐淡去）。valence: -2 深仇 … +2 大恩；importance 1..5。", "input_schema": {"type": "object", "properties": {"text": {"type": "string"}, "importance": {"type": "integer"}, "valence": {"type": "integer"}}, "required": ["text", "importance", "valence"]}},
]

var session_id := ""
var tick := 0
var last_driver := "离线规则"
var last_error := ""
var calls_made := 0


func _ready() -> void:
	session_id = "s%d" % Time.get_unix_time_from_system()


func has_key() -> bool:
	return GS.driver_key.strip_edges().begins_with("sk-")


func driver_label() -> String:
	if has_key():
		return "Haiku 4.5"
	if account_ai_enabled():
		return "Claude 账号(quick)"
	return "离线规则"


## 作为 claude.ai Artifact 运行时：用观看者自己的 Claude 账号（sample 能力，quick 档）驱动，无需 key
func account_ai_available() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("!!window.__momenSample", true))


func account_ai_enabled() -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("window.momenAIEnabled === true", true))


func set_account_ai(on: bool) -> bool:
	if not OS.has_feature("web"):
		return false
	return bool(JavaScriptBridge.eval("window.momenSetAI(%s)" % ("true" if on else "false"), true))


func _call_account_claude(actor: String, gi: Dictionary) -> Array:
	var tools_txt := JSON.stringify(TOOLS)
	var prompt: String = str(PERSONAS.get(actor, "")) + "\n你在一个魔门修仙游戏里扮演这个角色。可用工具(JSON Schema)：" + tools_txt + \
		"\n根据下面的 GameInput 和你的记忆做决定。只回复一个 JSON：{\"calls\":[{\"name\":\"set_tactic\",\"input\":{...}},{\"name\":\"say\",\"input\":{\"text\":\"...\"}}]}，必须含 set_tactic，台词不超过20字。\nGameInput:\n" + JSON.stringify(gi)
	var id := "q%d" % tick
	JavaScriptBridge.eval("window.momenAsk(%s, %s)" % [JSON.stringify(id), JSON.stringify(prompt)], true)
	for i in 150:
		await get_tree().create_timer(0.2).timeout
		var r = JavaScriptBridge.eval("window.momenTake(%s)" % JSON.stringify(id), true)
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


func build_input(actor: String, type: String, payload: Dictionary) -> Dictionary:
	tick += 1
	payload["your_memories"] = Mem.recall(actor, 6)
	payload["relation_to_player"] = snappedf(Mem.relation(actor), 1.0)
	payload["recent_events"] = Mem.recent(5)
	return {
		"sessionId": session_id,
		"actorId": actor,
		"type": type,
		"payloadJson": JSON.stringify(payload),
		"moment": {"timeline": "life_%d" % GS.life, "tick": tick},
	}


## 返回 {"driver": String, "calls": Array[{name, input}]}
func decide(actor: String, type: String, payload: Dictionary) -> Dictionary:
	var gi := build_input(actor, type, payload)
	if has_key():
		var res := await _call_haiku(actor, gi)
		if res.size() > 0:
			last_driver = "Haiku 4.5"
			driver_changed.emit(last_driver)
			return {"driver": last_driver, "calls": res}
	elif account_ai_enabled():
		var res2 := await _call_account_claude(actor, gi)
		if res2.size() > 0:
			last_driver = "Claude 账号(quick)"
			driver_changed.emit(last_driver)
			return {"driver": last_driver, "calls": res2}
	last_driver = "离线规则"
	driver_changed.emit(last_driver)
	return {"driver": last_driver, "calls": offline_policy(actor, type, JSON.parse_string(gi.payloadJson))}


func _call_haiku(actor: String, gi: Dictionary) -> Array:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT
	add_child(http)
	var sys: String = str(PERSONAS.get(actor, "")) + "\n规则：你只能根据 GameInput 中提供的状态和你的记忆做决定；必须调用 set_tactic，最好再调用 say；如果发生了值得记住的事，调用 remember。台词用中文，简短。"
	var body := {
		"model": MODEL,
		"max_tokens": 300,
		"system": sys,
		"tools": TOOLS,
		"tool_choice": {"type": "any"},
		"messages": [{"role": "user", "content": "GameInput:\n" + JSON.stringify(gi)}],
	}
	var headers := [
		"content-type: application/json",
		"x-api-key: " + GS.driver_key.strip_edges(),
		"anthropic-version: 2023-06-01",
		"anthropic-dangerous-direct-browser-access: true",
	]
	var err := http.request(API, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		last_error = "request err %d" % err
		return []
	var r: Array = await http.request_completed
	http.queue_free()
	calls_made += 1
	var code: int = r[1]
	var text: String = (r[3] as PackedByteArray).get_string_from_utf8()
	if code != 200:
		last_error = "HTTP %d %s" % [code, text.substr(0, 120)]
		push_warning("Haiku: " + last_error)
		return []
	var d = JSON.parse_string(text)
	if typeof(d) != TYPE_DICTIONARY:
		return []
	var out := []
	for block in d.get("content", []):
		if block.get("type", "") == "tool_use":
			out.append({"name": block.name, "input": block.input})
	last_error = ""
	return out


## 离线兜底：与模型同一套 tool calls
func offline_policy(actor: String, type: String, p) -> Array:
	var rel: float = float(p.get("relation_to_player", 0))
	var wave: int = int(p.get("wave", 1))
	var calls := []
	if actor == "senior":
		var tactic := "assist"
		var line := "一起上！"
		if rel <= -20 and wave >= 3:
			tactic = "betray"; line = "师弟，魔门的规矩你懂的。"
		elif rel < 0:
			tactic = "idle"; line = "你自己打吧，我看着。"
		elif rel >= 30:
			tactic = "guard"; line = "师弟，这一波我掩护你~"
		if type == "loot_split":
			tactic = "idle"
			line = "算你有良心。" if bool(p.get("shared", false)) else "好，好得很。我记住了。"
		calls.append({"name": "set_tactic", "input": {"tactic": tactic, "reason": "relation=%d" % int(rel)}})
		calls.append({"name": "say", "input": {"text": line}})
	elif actor == "elder":
		var fire := bool(p.get("player_used_fire", false))
		calls.append({"name": "set_tactic", "input": {"tactic": "crush" if rel < -10 else "test", "reason": "考核"}})
		calls.append({"name": "say", "input": {"text": "你……为何知道本座的秘密？" if fire else "外门弟子，也配见本座？"}})
	return calls
