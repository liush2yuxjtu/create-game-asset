extends Node
## headless 自动验收：godot --headless -- --autotest
## 1) 新手引导全流程（含所有 gate）  2) 正式游戏：打波次→死亡→选记忆→轮回  3) 录屏模式跑完整时间轴

var m
var fails := []


func check(cond: bool, what: String) -> void:
	print(("  ✔ " if cond else "  ✘ ") + what)
	if not cond:
		fails.append(what)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec, true, false, true).timeout


func run(main) -> void:
	m = main
	GS.wipe()
	GS.driver_key = ""
	Engine.time_scale = 4.0
	print("== 1. 新手引导（interactive director）")
	m.start_director(true)
	var d = m.director
	var gates_seen := []
	var guard := 0
	while m.director != null and guard < 4000:
		guard += 1
		await wait(0.05)
		if d.blocked:
			var b: Dictionary = d.S.beats[d.beat_i]
			gates_seen.append(b.gate.type)
			match b.gate.type:
				"pick_card":
					d._pick_card(1)  # 错误的卡应被拒绝
					check(d.blocked, "选错记忆卡时引导不放行")
					d._pick_card(0)
				"tap_tuna":
					for i in 3:
						m._on_tuna()
				"tap_break":
					m._on_break()
		if d.done and m.director != null:
			check(d.cta != null, "CTA 标题卡出现")
			d._end("play")
	check(gates_seen.has("pick_card") and gates_seen.has("tap_tuna") and gates_seen.has("tap_break"), "三个引导 gate 都触发: %s" % str(gates_seen))
	check(d.fired.keys().any(func(k): return str(k).begins_with("betray|npc_betray")), "背刺镜头触发")
	check(GS.tutorial_done, "tutorial_done 已写入")
	check(GS.life == 101, "引导后进入第 101 世 (实际 %d)" % GS.life)
	check(GS.has_perk("dodge_betrayal"), "带入记忆 perk=dodge_betrayal")
	check(Mem.library.size() >= 3, "记忆库有 3 张卡")
	check(m.mode == "story" and Story.st.node != "", "序幕结束后进入第一章剧情 (%s)" % Story.st.node)
	m.start_cultivate(-1, {})

	print("== 2. 正式游戏：波次 / Agent 决策 / 死亡轮回")
	Engine.time_scale = 6.0
	await wait(20.0)
	if m.loot_waiting:
		await wait(7.0)
	check(GS.wave >= 4, "不买升级也能打到第 4 波以上 (wave=%d mode=%s)" % [GS.wave, m.mode])
	check(Agent.tick >= 1, "师兄 agent 被调用 %d 次 (离线兜底)" % Agent.tick)
	check(Mem.npc.has("senior"), "师兄有记忆条目 %d" % Mem.npc.get("senior", []).size())

	print("== 2a. 掉落计时器只结算自己的那次选择")
	Engine.time_scale = 1.0
	if m.loot_waiting:
		await wait(7.0)
	m._loot_choice()
	m._overlay_panel(Rect2(20, 150, 230, 76), "（验收）模拟打开设置面板")
	var other = m.overlay
	await wait(6.5)
	check(not m.loot_waiting, "被设置面板盖住的掉落选择超时后仍会结算")
	check(is_instance_valid(other) and m.overlay == other, "掉落超时不会关掉后打开的面板")
	m._close_overlay()
	m._loot_choice()
	await wait(1.0)
	var btns: Array = m.overlay.find_children("*", "Button", true, false)
	btns[1].pressed.emit()  # 快速选「分给师兄」
	check(not m.loot_waiting, "手动选择立即结算")
	m._loot_choice()  # 紧接着下一次掉落
	var second = m.overlay
	await wait(5.5)  # 第一次的 6 秒计时器此时已触发
	check(m.loot_waiting and is_instance_valid(second) and m.overlay == second, "旧计时器不会结算/关闭新的掉落选择")
	await wait(1.5)
	check(not m.loot_waiting, "新的掉落选择按自己的计时器结算")
	Engine.time_scale = 6.0
	GS.pills = 0
	m.battle._hit(m.battle.hero, 1e12, Color.RED)
	await wait(2.0)
	check(m.mode == "rebirth", "死亡进入轮回界面")
	var life_before := GS.life
	GS.reincarnate([Mem.library.keys()[0]])
	m.start_play()
	check(GS.life == life_before + 1, "轮回后 life+1")
	check(GS.perks.size() == 1, "新一世只带入 1 条记忆")
	check(Mem.relation("senior") != 0.0, "师兄对你的好感跨世保留 (%d)" % int(Mem.relation("senior")))
	GS.add_qi(1e6)
	check(GS.buy("juling"), "可购买聚灵阵")
	check(GS.breakthrough(), "可突破境界")
	GS.save_game()
	check(FileAccess.file_exists(GS.SAVE_PATH), "存档写入")

	print("== 2b. Paperclips：账本 / 炼化 / 结局")
	Story.st.active = false  # 纯挂机（无进行中的剧情）时，炼化结局走轮回
	m._on_ledger()
	check(m.ledger.visible, "账本界面可打开")
	GS.add_qi(1e5)
	check(GS.buy("mozhong"), "购买魔种分裂")
	check(GS.ledger.has("魔种开始自我复制。"), "纪事出现冷峻旁白")
	var st: Dictionary = GS.ledger_state()
	check(st.phases.size() == 4, "账本显示 4 个炼化阶段")
	GS.seeds = 1e14
	await wait(1.5)
	check(GS.phases_done() >= 2, "魔种炼化外门/魔门 (完成 %d 阶段)" % GS.phases_done())
	check(GS.ledger.has("外门：炼化完毕。"), "阶段完成写入纪事")
	GS.seeds = 1e17
	await wait(3.0)
	check(GS.ended, "三千世界炼化完毕 → 结局")
	check(Mem.library.has("universe_memory"), "结局记忆「我炼化过三千世界」可带入下一世")
	await wait(4.5)
	check(m.mode == "rebirth", "结局后进入轮回")

	print("== 3. 录屏模式（复刻视频时间轴）")
	Engine.time_scale = 4.0
	m.start_director(false)
	var rd = m.director
	var beats_hit := {}
	guard = 0
	while not rd.done and guard < 4000:
		guard += 1
		await wait(0.05)
		beats_hit[rd.S.beats[rd.beat_i].id] = true
		if rd.S.beats[rd.beat_i].id == "paperclips" and rd.t > rd.S.beats[rd.beat_i].t0 + 6.5:
			beats_hit["ledger_ok"] = m.ledger.visible and m.ledger.state.get("phases", []).size() == 4 and m.ledger.state.phases[3][1] >= 1.0
		if rd.blocked:
			check(false, "录屏模式不应等待输入")
	check(beats_hit.get("ledger_ok", false), "录屏模式：账本硬切 + 三千世界 100%")
	beats_hit.erase("ledger_ok")
	check(beats_hit.size() == rd.S.beats.size(), "8 个镜头全部播放: %s" % str(beats_hit.keys()))
	check(absf(rd.t - rd.S.duration) < 0.3, "时长与视频一致 (%.2fs)" % rd.t)
	print("== 4. 回归：存档隔离 / 清档 / 一次性升级")
	check(GS.SAVE_PATH == GS.TEST_SAVE_PATH, "验收只写隔离存档 (%s)" % GS.SAVE_PATH)
	Story.st.active = true
	Story.st.node = "ch2_open"
	Story.st.endings = {"true": 1}
	GS.wipe()
	check(Story.st.node == "" and not Story.st.active and Story.st.endings.is_empty(), "清空存档同时清空剧情进度")
	var saved = JSON.parse_string(FileAccess.get_file_as_string(GS.SAVE_PATH))
	check(typeof(saved) == TYPE_DICTIONARY and str(saved.get("story", {}).get("node", "?")) == "", "清档后写盘的剧情进度为空")
	GS.add_qi(1e6)
	check(GS.buy("tuna_auto"), "首次购买自动吐纳")
	var q_before: float = GS.qi
	check(not GS.buy("tuna_auto") and GS.qi == q_before and GS.level("tuna_auto") == 1, "已拥有的自动吐纳不再扣费")
	print("RESULT: %s" % ("AUTOTEST PASS" if fails.is_empty() else "FAIL " + str(fails)))
	get_tree().quit(0 if fails.is_empty() else 1)
