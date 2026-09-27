extends Node
## NPC 情景记忆（给 agent 当上下文）：每个 AI 角色记得你做过什么，跨世按 ×0.6 衰减。
## 玩家自己的记忆是「记忆碎片」，在 story.gd 里；这里只管角色那一侧——角色记得住，玩家得靠碎片记住。

const DECAY := 0.6

var npc := {}          # actor -> Array[{life, text, importance, valence}]
var chronicle := []    # 最近事件，喂给 agent
var life := 99


func remember(actor: String, text: String, importance := 3, valence := 0) -> void:
	if not npc.has(actor):
		npc[actor] = []
	var arr: Array = npc[actor]
	arr.append({"life": life, "text": text.substr(0, 40), "importance": clampi(importance, 1, 5), "valence": clampi(valence, -2, 2)})
	if arr.size() > 40:
		arr.sort_custom(func(a, b): return _sal(a) > _sal(b))
		arr.resize(30)


func _sal(e: Dictionary) -> float:
	return float(e.importance) * pow(DECAY, life - int(e.life))


func recall(actor: String, n := 5) -> Array:
	var arr: Array = npc.get(actor, []).duplicate()
	arr.sort_custom(func(a, b): return _sal(a) > _sal(b))
	var out := []
	for e in arr.slice(0, n):
		var ago := life - int(e.life)
		out.append({"text": e.text, "when": "本世" if ago == 0 else "%d世前" % ago, "weight": snappedf(_sal(e), 0.01), "valence": e.valence})
	return out


## 前世留下的最强烈的一条（用于「似曾相识」）
func strongest_past(actor: String) -> Dictionary:
	var best := {}
	var bw := 0.0
	for e in npc.get(actor, []):
		if int(e.life) >= life:
			continue
		var w := _sal(e) * absf(float(e.valence))
		if w > bw:
			bw = w
			best = e
	return best if bw >= 1.0 else {}


func relation(actor: String) -> float:
	var r := 0.0
	for e in npc.get(actor, []):
		r += float(e.valence) * float(e.importance) * 4.0 * pow(DECAY, life - int(e.life))
	return clampf(r, -100.0, 100.0)


func note(text: String) -> void:
	chronicle.append({"life": life, "text": text})
	if chronicle.size() > 60:
		chronicle = chronicle.slice(chronicle.size() - 40)


func recent(n := 5) -> Array:
	var out := []
	for e in chronicle.slice(max(0, chronicle.size() - n)):
		out.append(e.text)
	return out


func to_dict() -> Dictionary:
	return {"npc": npc, "chronicle": chronicle, "life": life}


func from_dict(d: Dictionary) -> void:
	npc = d.get("npc", {}); chronicle = d.get("chronicle", []); life = int(d.get("life", 99))


func reset() -> void:
	npc = {}; chronicle = []; life = 99
