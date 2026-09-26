extends Node
## 记忆系统
## 1) 玩家「记忆卡」：本世学到的真相，死亡时可选择带入下一世（变成 perk）
## 2) NPC 情景记忆：每个 AI 角色记得你做过什么，跨世衰减（似曾相识）
## 3) 编年史：本世与前世的事件日志，喂给 agent 作为上下文

signal card_learned(card: Dictionary)

const DECAY := 0.6  # 每隔一世，NPC 记忆权重 ×0.6

const CATALOG := {
	"elder_fears_fire": {"text": "长老怕火", "perk": "fire_vs_elder", "hint": "魔焰对长老 ×3"},
	"pill_cave": {"text": "后山洞里有丹药", "perk": "start_pill", "hint": "开局带一颗保命丹"},
	"spider_wave": {"text": "第5波是蛛群", "perk": "wave5_bonus", "hint": "第5波伤害 +50%"},
	"senior_saved_me": {"text": "师兄其实救过我", "perk": "senior_friend", "hint": "师兄好感 +40"},
	"realm_echo": {"text": "我曾到过筑基", "perk": "realm_echo", "hint": "开局即筑基"},
	"universe_memory": {"text": "我炼化过三千世界", "perk": "seed_start", "hint": "开局自带魔种"},
}

var library := {}      # id -> card (所有世学到过的)
var carried := []      # 本世带入的卡 id
var npc := {}          # actor -> Array[Dictionary]
var chronicle := []    # [{life, text}]
var life := 1


func card(id: String) -> Dictionary:
	return library.get(id, {})


func learn(id: String, text := "", perk := "", hint := "") -> void:
	if library.has(id):
		return
	var base: Dictionary = CATALOG.get(id, {})
	var c := {
		"id": id,
		"text": text if text != "" else str(base.get("text", id)),
		"perk": perk if perk != "" else str(base.get("perk", "")),
		"hint": hint if hint != "" else str(base.get("hint", "")),
		"life": life,
	}
	library[id] = c
	note("领悟记忆：「%s」" % c.text)
	card_learned.emit(c)


func learn_betrayal(wave: int) -> void:
	learn("senior_betrays_w%d" % wave, "师兄会在第%d波背刺" % wave, "dodge_betrayal", "识破背刺并反击")


## NPC 记住一件事。valence: -2(深仇) .. +2(大恩)，importance 1..5
func remember(actor: String, text: String, importance := 3, valence := 0) -> void:
	if not npc.has(actor):
		npc[actor] = []
	var arr: Array = npc[actor]
	arr.append({"life": life, "text": text.substr(0, 40), "importance": clampi(importance, 1, 5), "valence": clampi(valence, -2, 2)})
	if arr.size() > 40:
		arr.sort_custom(func(a, b): return _salience(a) > _salience(b))
		arr.resize(30)


func _salience(m: Dictionary) -> float:
	return float(m.importance) * pow(DECAY, life - int(m.life))


func recall(actor: String, n := 6) -> Array:
	var arr: Array = npc.get(actor, []).duplicate()
	arr.sort_custom(func(a, b): return _salience(a) > _salience(b))
	var out := []
	for m in arr.slice(0, n):
		var ago := life - int(m.life)
		out.append({"text": m.text, "when": "本世" if ago == 0 else "%d世前" % ago, "weight": snappedf(_salience(m), 0.01), "valence": m.valence})
	return out


func relation(actor: String) -> float:
	var r := 0.0
	for m in npc.get(actor, []):
		r += float(m.valence) * float(m.importance) * 4.0 * pow(DECAY, life - int(m.life))
	if GS.has_perk("senior_friend") and actor == "senior":
		r += 40.0
	return clampf(r, -100.0, 100.0)


func note(text: String) -> void:
	chronicle.append({"life": life, "text": text})
	if chronicle.size() > 80:
		chronicle = chronicle.slice(chronicle.size() - 60)


func recent(n := 6) -> Array:
	var out := []
	for e in chronicle.slice(max(0, chronicle.size() - n)):
		out.append(e.text)
	return out


func on_new_life(new_life: int, carried_ids: Array) -> void:
	life = new_life
	carried = carried_ids.duplicate()
	note("第 %d 世开始，带入：%s" % [life, ", ".join(carried_ids.map(func(i): return card(i).get("text", i)))])


func to_dict() -> Dictionary:
	return {"library": library, "carried": carried, "npc": npc, "chronicle": chronicle, "life": life}


func from_dict(d: Dictionary) -> void:
	library = d.get("library", {})
	carried = d.get("carried", [])
	npc = d.get("npc", {})
	chronicle = d.get("chronicle", [])
	life = int(d.get("life", 1))


func reset() -> void:
	library = {}; carried = []; npc = {}; chronicle = []; life = 1
