extends Node
## --autotest：新手引导（逐个 gate 真点）→ 接进第二章；记忆背包 / 铭刻 / 使用；自由输入；战斗「守」；回溯；存档隔离；录屏时间轴。

var fails := 0
var checks := 0
var m


func ok(c: bool, msg: String) -> void:
	checks += 1
	if c:
		print("  ✔ ", msg)
	else:
		fails += 1
		print("  ✘ ", msg)


func wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func run(main) -> void:
	m = main
	await get_tree().process_frame
	print("== autotest ==")
	# §0 隔离存档（必须在任何清档前断言）
	ok(GS.isolated and GS.save_path().ends_with("_test.json"), "自测只写隔离存档")
	if not GS.save_path().ends_with("_test.json"):
		get_tree().quit(2)
		return
	await tutorial()
	await memory_flow()
	await free_input()
	await battle_block()
	await metrics_and_rewind()
	await record_timeline()
	print("RESULT: autotest %s" % ("PASS" if fails == 0 else "FAIL"))
	print("autotest: %d 项 · %s" % [checks, "PASS" if fails == 0 else "FAIL (%d)" % fails])
	get_tree().quit(0 if fails == 0 else 1)


# §1 新手引导：每个 gate 都要玩家亲手点；非目标按钮点了无效
func tutorial() -> void:
	print("§1 新手引导")
	GS.tutorial_done = false
	m.start_director(true)
	var d = m.director
	var gates := []
	var t0 := Time.get_ticks_msec()
	var tried_wrong := false
	while Time.get_ticks_msec() - t0 < 90000:
		await get_tree().process_frame
		if not is_instance_valid(d) or d.done:
			break
		if d.cta != null:
			break
		if d.blocked:
			var k: String = d.gate.key
			if not tried_wrong and k == "bag_btn":
				tried_wrong = true
				var before: String = Story.cur
				m.press_as_player("layer_btn")
				ok(m.overlay == null and Story.cur == before, "引导中点非目标按钮无效")
			if k == "cont":
				while m.typing:
					await get_tree().process_frame
			await wait(0.05)
			gates.append(k)
			if k == "send":
				ok(m.input.text == "我也死过99次", "输入框预填了视频里那句台词")
			m.press_as_player(k)
			await wait(0.1)
	ok(gates.has("open_bag") and gates.has("awaken_btn") and gates.has("use_btn") and gates.has("send"), "引导经过：开背包→铭刻→使用记忆→自由输入（%d 个 gate）" % gates.size())
	ok(d.cta != null, "引导走到结尾 CTA")
	ok(Story.life == 100 and Story.awake.has("frag_zhusha"), "第100世，朱砂已铭刻")
	ok(Story.layers.has("c1_l2"), "引导里揭开了第一章第2层")
	ok(Story.ch == 2, "引导结束时已进第二章")
	d._finish_tutorial()
	await wait(0.2)
	ok(GS.tutorial_done and not GS.isolated, "引导完成后转为正式存档")
	GS.isolated = true   # 自测继续写隔离档
	ok(Story.cur == "c2_start" and m.mode == "play", "引导无缝接进第二章正式游玩（%s）" % Story.cur)
	ok(Story.m.has("qing") and Story.m.has("qi"), "第二章出现新数值「情」，旧数值「元」保留")


# §2 背包：回看、铭刻、使用（对/错）
func memory_flow() -> void:
	print("§2 记忆碎片")
	_reset()
	m._close_overlay()
	Story.new_game(99)
	m.begin_play()
	Story.begin_life()
	m._close_overlay()
	_to("c1_invite")
	ok(m.aside_lbl.text == "", "没有铭刻的记忆时，不提示「似曾相识」")
	Story.frag_log["frag_zhusha"] = {"life": 98, "ch": 1}
	Story.awake.append("frag_zhusha")
	Story.enter("c1_invite")
	ok(m.aside_lbl.text.contains("似曾相识"), "有可用记忆时提示「似曾相识」（不说是哪片）")
	ok(not m.targets.has("choice:debt") or not is_instance_valid(m.targets["choice:debt"]) or not m.targets["choice:debt"].is_inside_tree(), "隐藏选项在主动使用前不可见")
	m.open_bag("play")
	await wait(0.05)
	ok(m.targets.has("frag:frag_zhusha"), "背包里能看到碎片（可回看）")
	m.press("frag:frag_zhusha")
	await wait(0.05)
	ok(m.targets.has("use_btn") and m.targets["use_btn"].is_visible_in_tree(), "详情页有「此刻想起它」")
	m.press("use_btn")
	await wait(0.1)
	ok(m.targets.has("choice:debt") and m.targets["choice:debt"].is_inside_tree(), "使用后隐藏选项出现")
	# 错的记忆
	Story.frag_log["frag_crane"] = {"life": 98, "ch": 1}
	Story.awake.append("frag_crane")
	ok(Story.use_frag("frag_crane") == "useless", "用错记忆 → 无效")
	ok(Story.use_frag("frag_ledger") == "locked", "未铭刻的记忆不能用")
	# 死亡 → 铭刻
	_to("c1_refuse")
	Story.advance()
	await wait(0.5)
	ok(m.mode == "death" and m.targets.has("open_bag"), "死亡界面出现，提示打开背包")
	var had_fresh := Story.fresh.duplicate()
	ok(had_fresh.has("frag_zhusha") == false and Story.frag_log.has("frag_zhusha"), "已铭刻的碎片不会重复进本世所得")
	# 造一个新碎片再死
	Story.new_game(99)
	Story.begin_life()
	_to("c1_refuse")
	Story.advance()
	await wait(0.5)
	ok(Story.fresh.has("frag_zhusha"), "死亡时临死所见进入本世所得")
	m.press("open_bag")
	await wait(0.05)
	m.press("frag:frag_zhusha")
	await wait(0.05)
	m.press("awaken_btn")
	await wait(0.05)
	ok(Story.awake.has("frag_zhusha") and not Story.fresh.has("frag_zhusha"), "铭刻成功")
	ok(m.targets.has("rebirth_btn") and m.targets.has("rewind_btn"), "铭刻后可选 轮回 / 回溯")
	m.press("rebirth_btn")
	await wait(0.1)
	ok(Story.life == 100 and Story.awake.has("frag_zhusha"), "轮回后记忆仍在")


# §3 自由输入：说中记忆里的东西 = 主动想起；没证据 = 搪塞；无关 = 角色回话
func free_input() -> void:
	print("§3 自由输入")
	_reset()
	Story.new_game(99)
	m.begin_play()
	Story.begin_life()
	m._close_overlay()
	_to("c1_invite")
	var r: Dictionary = Agent.offline_interpret("你是不是死过九十九次", Story.free_candidates(), Story.node().tease, Story.node().other)
	ok(r.choice_id == "" and r.get("tease", false), "没有记忆时说中秘密 → 厉寒搪塞")
	Story.awake.append("frag_kehen")
	r = Agent.offline_interpret("你左腕的刻痕是第几道", Story.free_candidates(), Story.node().tease, Story.node().other)
	ok(r.choice_id == "loop2", "有「九十九道刻痕」时直接说出来 → 命中隐藏选项")
	r = Agent.offline_interpret("今天天气不错", Story.free_candidates(), Story.node().tease, Story.node().other)
	ok(r.choice_id == "" and r.reply != "", "无关的话 → 角色照常回一句")
	r = Agent.offline_interpret("好，走吧", Story.free_candidates(), Story.node().tease, Story.node().other)
	ok(r.choice_id == "go", "自由输入也能对应普通选项")
	m.input.text = "你左腕的刻痕，第几道了？"
	m._send_free()
	await wait(2.5)
	ok(Story.layers.has("c1_l4") and Story.flags.has("ally_lihan"), "用输入框说出来 → 揭开第一章第4层、厉寒结盟")
	ok(Agent.driver_label() != "", "驱动标签：" + Agent.driver_label())


# §4 战斗：背刺前一刻切「守」能挡住
func battle_block() -> void:
	print("§4 战斗")
	_reset()
	Story.new_game(99)
	m.begin_play()
	Story.begin_life()
	m._close_overlay()
	Story.m["qi"] = 0
	ok(Story.battle_outcome(false).to == "c1_death_hunt" if _at("c1_hunt") else false, "魔元不足、没防住 → 死")
	ok(Story.battle_outcome(true).to == "c1_survive", "背刺前一刻切到「守」→ 活")
	Story.m["qi"] = 30
	ok(Story.battle_outcome(false).to == "c1_survive", "魔元≥30 → 那一刀要不了命（玩家自己体会）")
	# 实际跑一场：到时切守
	Story.m["qi"] = 0
	m.director = null
	Story.enter("c1_hunt")
	var blocked_in_time := false
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 15000 and Story.cur == "c1_hunt":
		await get_tree().process_frame
		var a = m.stage.actors.get("lihan")
		if a and a.mark == "!" and not blocked_in_time:
			blocked_in_time = true
			m.press("stance:def")
	ok(blocked_in_time, "背刺前出现「!」预警")
	await wait(0.2)
	ok(Story.cur == "c1_survive", "实战中切「守」挡住背刺 → %s" % Story.cur)


# §5 数值与回溯
func metrics_and_rewind() -> void:
	print("§5 数值 / 回溯")
	_reset()
	Story.new_game(99)
	Story.begin_life()
	for n in [2, 3, 4]:
		Story.start_chapter(n)
	ok(int(Story.m.wei) == 3 and Story.m.has("qing") and Story.m.has("ming"), "每章一个新数值，旧的保留（伪起始 3）")
	m._close_overlay()
	var snap: Dictionary = Story.m.duplicate()
	Story.add_metric("wei", -3)
	Story.flags.append("helped_suqing")
	Story.rewind_chapter()
	ok(int(Story.m.wei) == 3 and not Story.flags.has("helped_suqing"), "回溯：本章数值与标记回到章首")
	m._refresh_top()
	ok(m.metric_box.get_child_count() >= 1, "顶栏显示数值（只显示字形与数字）")


# §6 录屏时间轴：自动演出能走完、时长与分镜一致
func record_timeline() -> void:
	print("§6 录屏模式")
	m._close_overlay()
	m.start_director(false)
	var d = m.director
	var t0 := Time.get_ticks_msec()
	Engine.time_scale = 4.0
	while Time.get_ticks_msec() - t0 < 60000 and not d.done:
		await get_tree().process_frame
	Engine.time_scale = 1.0
	ok(d.done, "录屏模式时间轴走完（%.1f s / 分镜 %.1f s）" % [d.t, float(d.S.duration)])
	ok(absf(d.t - float(d.S.duration)) < 1.5, "实际时长与分镜时长一致")
	ok(Story.layers.has("c1_l2") and Story.ch == 2, "录屏演出的是真实剧情（揭开 c1_l2，进第二章）")


func _to(nid: String) -> void:
	Story.enter(nid)


func _at(nid: String) -> bool:
	Story.cur = nid   # 只定位，不触发战斗演出
	return true


func _reset() -> void:
	m.stage.in_battle = false
	m.stage.actors.clear()
	m._close_overlay()
	m.gate_key = ""
	m.lock_input = false
