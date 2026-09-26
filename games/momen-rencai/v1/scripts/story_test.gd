extends Node
## godot --headless -- --storytest
## 1) 用 tools/verify_story.py 求出的 8 条路线，逐步驱动 GDScript 版 Story 引擎，确认 8 个结局都能到达（两种实现一致）
## 2) 剧情 UI 冒烟：从第一章开始，真的点对白、选选项、打仗，一路推进到第三章

var fails := []


func check(c: bool, what: String) -> void:
	print(("  ✔ " if c else "  ✘ ") + what)
	if not c:
		fails.append(what)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func run(m) -> void:
	print("== 1. 8 条结局路线回放")
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_routes.json"))
	for end_id in routes:
		Story.reset_state(false)
		Story.st.active = true
		Story.goto("ch1_open")
		var ok := true
		for step in routes[end_id]:
			var s: String = step
			var cur: String = Story.st.node
			if s.contains("#"):
				var idx := int(s.get_slice("#", 1).get_slice(":", 0))
				ok = Story.choose(idx)
			elif s.ends_with(":胜") or s.ends_with(":败"):
				Story.battle_result(s.ends_with(":胜"))
			elif s.contains(":吐纳"):
				Story.ledger_result(int(s.get_slice(":吐纳", 1)) / 3)
			elif s.ends_with(":超时"):
				Story.timeout()
			elif s.contains("→"):
				Story.advance()
			elif s == end_id:
				pass
			else:
				var t: String = Story.node().type
				if t == "converge":
					Story.next_chapter()
				else:
					Story.advance()
			if not ok:
				break
		check(ok and Story.st.node == end_id, "%s ← %d 步（实际停在 %s）" % [Story.nodes[end_id].title, routes[end_id].size(), Story.st.node])
	check(Story.st.endings.size() >= 1, "结局记录写入")

	print("== 2. 剧情 UI 冒烟（第一章 → 第三章）")
	Story.reset_state(false)
	GS.tutorial_done = true
	GS.realm = 3
	Engine.time_scale = 4.0
	m.story_mode.begin_new(false)
	var ui = m.story_ui
	var steps := 0
	var seen_types := {}
	var flow_shown := false
	while steps < 900 and Story.chapter_index() < 2:
		steps += 1
		await wait(0.05)
		var n: Dictionary = Story.node()
		seen_types[n.get("type", "")] = true
		if not ui._lines.is_empty():
			ui.next_line()
			ui.next_line()
			continue
		if ui.flow_graph and is_instance_valid(ui.flow_graph) and ui.flow_graph.is_visible_in_tree():
			flow_shown = true
			for c in ui.layer.get_children():
				if c is Button:
					c.pressed.emit()
			continue
		if n.get("type", "") == "choice" and ui.layer.get_child_count() > 0:
			var opts: Array = Story.options()
			var pick := 0
			for o in opts:
				if o.ok:
					pick = o.i
					break
			m.story_mode._pick(pick)
			continue
		if n.get("type", "") == "battle" and not m.story_mode.bctx.is_empty() and not m.story_mode.bctx.get("done", false):
			m.battle.clear_enemies()
			if m.story_mode.bctx.waves_left <= 0:
				m.story_mode._battle_done(true)
	check(Story.chapter_index() >= 2, "UI 推进到第三章（%s）" % Story.chapter().title)
	check(seen_types.has("scene") and seen_types.has("choice") and seen_types.has("battle"), "经历了场景/选项/战斗 %s" % str(seen_types.keys()))
	check(flow_shown, "章末弹出流程图")
	check(Story.st.mem.size() >= 1, "带入了序章记忆 (%d)" % Story.st.mem.size())
	print("RESULT: %s" % ("STORYTEST PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit(0 if fails.is_empty() else 1)


## godot -- --storydemo：按真结局路线自动演示（录屏/截图用）
func run_demo(m) -> void:
	var routes: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_routes.json"))
	var route: Array = routes["end_true"]
	var picks := {}      # node -> [选项序号...]（按访问顺序）
	var fights := {}     # node -> [胜/败...]
	for s in route:
		if s.contains("#"):
			var nid: String = s.get_slice("#", 0)
			picks[nid] = picks.get(nid, []) + [int(s.get_slice("#", 1).get_slice(":", 0))]
		elif s.ends_with(":胜") or s.ends_with(":败"):
			var nid2: String = s.get_slice(":", 0)
			fights[nid2] = fights.get(nid2, []) + [s.ends_with(":胜")]
	Story.reset_state(false)
	GS.tutorial_done = true
	GS.realm = 3
	m.story_mode.begin_new(false)
	var ui = m.story_ui
	var sacrificed := {}
	while Story.node().get("type", "") != "ending":
		await gwait(0.25 if not m.story_mode.bctx.is_empty() else 0.9)
		var n: Dictionary = Story.node()
		if not ui._lines.is_empty():
			ui.next_line()
			continue
		if ui.flow_graph and is_instance_valid(ui.flow_graph) and ui.flow_graph.is_visible_in_tree():
			await gwait(1.5)
			for c in ui.layer.get_children():
				if c is Button:
					c.pressed.emit()
			continue
		if n.type == "choice" and ui.layer.get_child_count() > 0:
			await gwait(1.2)
			var lst: Array = picks.get(n.id, [0])
			var i: int = lst.pop_front() if lst.size() > 0 else 0
			picks[n.id] = lst
			m.story_mode._pick(i)
			continue
		if n.type == "battle" and not m.story_mode.bctx.is_empty() and not m.story_mode.bctx.get("done", false):
			var key := str(n.id) + ":" + str(Story.st.deaths)
			if not sacrificed.has(key):
				var fl: Array = fights.get(n.id, [true])
				sacrificed[key] = fl.pop_front() if fl.size() > 0 else true
				fights[n.id] = fl
				if sacrificed[key] == false:
					await gwait(0.4)
					m.story_mode.sacrifice()
			continue
		if m.story_mode.cultivate_req >= 0:
			GS.realm = max(GS.realm, m.story_mode.cultivate_req)
			m.story_mode.continue_after_cultivate()
	await gwait(8.0)
	get_tree().quit(0)


func gwait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout
