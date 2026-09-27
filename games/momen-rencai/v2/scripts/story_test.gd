extends Node
## --storytest：用 tools/verify_story.py 穷举出的路线（data/story_routes.json）驱动 GDScript 剧情引擎，
## 逐世回放，断言每一步的节点、每一层冲突、每个结局与 Python 语义一致。

var fails := 0
var checks := 0


func ok(c: bool, msg: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("  ✘ ", msg)


func run(_main) -> void:
	await get_tree().process_frame
	print("== storytest ==")
	ok(GS.save_path().ends_with("_test.json"), "自测只写隔离存档")
	var R = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_routes.json"))
	var n_routes := 0
	for kind in ["endings", "layers"]:
		for key in R[kind]:
			n_routes += 1
			var ok_route := replay(R[kind][key].route, kind, key)
			if ok_route:
				print("  ✔ %s %s（%d 世）" % [kind, key, R[kind][key].route.size()])
	print("RESULT: storytest %s" % ("PASS" if fails == 0 else "FAIL"))
	print("storytest: %d 条路线 · %d 项检查 · %s" % [n_routes, checks, "PASS" if fails == 0 else "FAIL (%d)" % fails])
	get_tree().quit(0 if fails == 0 else 1)


func _settle() -> void:
	var guard := 0
	while guard < 50:
		guard += 1
		var n := Story.node()
		if n.has("auto") or n.has("chapter_end"):
			Story.advance()
		else:
			return


func replay(route: Array, kind: String, key: String) -> bool:
	var f0 := fails
	Story.new_game(1)
	for i in route.size():
		var life: Dictionary = route[i]
		ok(Story.awake.size() == life.awake_before.size(), "%s/%s 第%d世 铭刻数 %d≠%d" % [kind, key, i + 1, Story.awake.size(), life.awake_before.size()])
		ok(_same(Story.echo_prev, life.echo_prev), "%s/%s 第%d世 回响不一致 %s vs %s" % [kind, key, i + 1, Story.echo_prev, life.echo_prev])
		if i == 0:
			Story.begin_life()
		for step in life.path:
			_settle()
			var what: String = step[0]
			match what:
				"breathe":
					ok(Story.cur == step[1], "%s/%s 应在 %s 实在 %s" % [kind, key, step[1], Story.cur])
					Story.add_metric("qi", int(step[2]))
				"choose":
					ok(Story.cur == step[1], "%s/%s 应在 %s 实在 %s" % [kind, key, step[1], Story.cur])
					var avail := Story.choices().map(func(c): return c.id)
					ok(avail.has(step[2]), "%s/%s %s 没有可见选项 %s（有 %s）" % [kind, key, step[1], step[2], avail])
					if not avail.has(step[2]):
						return false
					Story.choose(step[2])
				"use":
					ok(Story.cur == step[1], "%s/%s use 应在 %s" % [kind, key, step[1]])
					var r := Story.use_frag(step[2])
					ok(r == "reveal", "%s/%s 在 %s 使用 %s → %s" % [kind, key, step[1], step[2], r])
				"battle":
					ok(Story.cur == step[1], "%s/%s battle 应在 %s 实在 %s" % [kind, key, step[1], Story.cur])
					Story.finish_battle(step[2] == "block")
				"reach":
					_settle()
		_settle()
		var end: Array = life.end
		match end[0]:
			"death":
				ok(Story.cur == end[1], "%s/%s 第%d世 应死于 %s 实在 %s" % [kind, key, i + 1, end[1], Story.cur])
			"ending":
				ok(Story.node().get("ending", "") == end[1], "%s/%s 应达成 %s 实在 %s" % [kind, key, end[1], Story.cur])
			"reach":
				ok(Story.layers.has(end[1]), "%s/%s 应揭开 %s" % [kind, key, end[1]])
		if life.has("awaken") and life.awaken != null:
			ok(Story.awaken(life.awaken), "%s/%s 铭刻 %s" % [kind, key, life.awaken])
		if i < route.size() - 1:
			Story.next_life()
	if kind == "layers":
		ok(Story.layers.has(key), "%s 最终应已揭开" % key)
	if kind == "endings":
		ok(Story.endings.has(key), "%s 最终应达成" % key)
	return fails == f0


func _same(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for x in a:
		if not b.has(x):
			return false
	return true


# ======================= --storydemo：按真结局路线实机演示（可用 Movie Maker 录下来） =======================

func run_demo(main, route_kind := "endings", key := "e_true") -> void:
	await get_tree().process_frame
	var R = JSON.parse_string(FileAccess.get_file_as_string("res://data/story_routes.json"))
	var route: Array = R[route_kind][key].route
	# 前几世瞬间过完（只跑剧情引擎），最后一世带界面实机演示
	main.mode = "title"
	Story.new_game(99)
	for i in route.size() - 1:
		var life: Dictionary = route[i]
		if i == 0:
			Story.begin_life()
		for step in life.path:
			_settle()
			match step[0]:
				"breathe": Story.add_metric("qi", int(step[2]))
				"choose": Story.choose(step[2])
				"use": Story.use_frag(step[2])
				"battle": Story.finish_battle(step[2] == "block")
		_settle()
		if life.has("awaken") and life.awaken != null:
			Story.awaken(life.awaken)
		Story.next_life()
	Story.life = 99 + route.size()
	Mem.life = Story.life
	main.begin_play()
	Story.begin_life()
	var last: Dictionary = route[route.size() - 1]
	for step in last.path:
		await _demo_settle(main)
		await _typed(main)
		await get_tree().create_timer(0.5).timeout
		match step[0]:
			"breathe":
				for i in 12:
					main.press("breathe")
					await get_tree().create_timer(0.08).timeout
				Story.add_metric("qi", maxi(0, int(step[2]) - 12))
				await get_tree().create_timer(0.4).timeout
			"choose":
				if not main.press("choice:" + step[2]):
					Story.choose(step[2])
			"use":
				main.open_bag("play")
				await get_tree().create_timer(0.5).timeout
				main.press("frag:" + step[2])
				await get_tree().create_timer(0.8).timeout
				main.press("use_btn")
				await get_tree().create_timer(1.0).timeout
			"battle":
				var t0 := Time.get_ticks_msec()
				while Story.cur == step[1] and Time.get_ticks_msec() - t0 < 20000:
					var a = main.stage.actors.get("lihan")
					if step[2] == "block" and a and a.mark == "!":
						main.press("stance:def")
					await get_tree().process_frame
	await _demo_settle(main)
	await get_tree().create_timer(5.0).timeout
	main.open_layers()
	await get_tree().create_timer(3.0).timeout
	get_tree().quit()


func _typed(main) -> void:
	while main.typing:
		await get_tree().process_frame


func _demo_settle(main) -> void:
	for guard in 40:
		await _typed(main)
		if main.overlay and is_instance_valid(main.overlay):
			await get_tree().create_timer(1.2).timeout
			for k in ["card_next", "card_start"]:
				if main.press(k):
					break
			await get_tree().create_timer(0.3).timeout
			continue
		var n := Story.node()
		if n.has("auto") or (n.has("chapter_end") and main.pending_card.is_empty()):
			await get_tree().create_timer(0.7).timeout
			main.press("cont")
			await get_tree().process_frame
			continue
		if n.has("chapter_end"):
			await get_tree().process_frame
			continue
		return
