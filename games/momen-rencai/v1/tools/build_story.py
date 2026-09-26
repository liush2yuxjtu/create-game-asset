"""魔门人材 · 剧情源文件生成器
写出 data/story.json —— Godot 游戏 (scripts/story.gd) 与流程图设计稿 (tools/story_design.py) 共用的唯一剧情数据。

节点类型
  scene     台词若干 → next；可带 set
  choice    选项（req 条件锁 / set 标记 / next 或 next_if 条件跳转）
  battle    战斗段（waves / boss / allies_from_flags）→ win / lose
  ledger    Paperclips 账本段：限时吐纳，次数写入 seed_feed
  death     死亡：授予一条轮回记忆，回到本章开头（本章标记回滚，记忆保留）
  converge  本章收束点 → 下一章
  ending    结局

条件 cond：[flag, op, value]，op ∈ == != >= <= in has(记忆)；多个条件为 AND
"""
import json
from collections import defaultdict, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

MEMORIES = {
    "mem_betray": "师兄会在第3波背刺",
    "mem_fire": "长老怕火",
    "mem_pill": "后山洞里有丹药",
    "mem_patrol": "巡夜弟子子时换岗",
    "mem_elder37": "长老是第三十七世的我",
    "mem_gu": "顾长风是苏晚的哥哥",
    "mem_master": "宗主的魔种在左胸",
}

FLAGS = {
    "senior": "none", "senior_rel": 0, "suwan": "none", "elder": "none", "elder_respect": 0,
    "gu": "none", "seed": "none", "seed_feed": 0, "master": "alive", "know_seed": False,
    "ruthless": 0, "kindness": 0, "master_favor": 0, "trust": 0,
}

CHARACTERS = {
    "你": {"tile": 88, "color": "#f4f0e6", "desc": "外门弟子，死过九十九次"},
    "魔种": {"tile": None, "color": "#b0741c", "desc": "体内的声音，只会记账"},
    "厉寒": {"tile": 111, "color": "#7fb3ff", "desc": "外门师兄，记仇，也记恩"},
    "苏晚": {"tile": 99, "color": "#ff9ecb", "desc": "药堂师妹，血月祭的炉鼎"},
    "血骨": {"tile": 84, "color": "#c792ff", "desc": "考核长老，怕火，藏着秘密"},
    "夜无归": {"tile": 110, "color": "#e23440", "desc": "血河宗主，轮回的主人"},
    "顾长风": {"tile": 97, "color": "#9be7ff", "desc": "天衍剑宗弟子，潜入者"},
    "旁白": {"tile": None, "color": "#968caa", "desc": ""},
}


def S(id, title, lines, next, set=None):
    n = {"id": id, "type": "scene", "title": title, "lines": lines, "next": next}
    if set:
        n["set"] = set
    return n


def C(id, title, prompt, options, timer=0):
    n = {"id": id, "type": "choice", "title": title, "prompt": prompt, "options": options}
    if timer:
        n["timer"] = timer
    return n


def O(label, next=None, req=None, set=None, next_if=None, key=False):
    o = {"label": label}
    if next:
        o["next"] = next
    if req:
        o["req"] = req
    if set:
        o["set"] = set
    if next_if:
        o["next_if"] = next_if
    if key:
        o["key"] = True
    return o


def B(id, title, battle, win, lose, lines=None):
    n = {"id": id, "type": "battle", "title": title, "battle": battle, "win": win, "lose": lose}
    if lines:
        n["lines"] = lines
    return n


def D(id, title, lines, grant, rewind):
    return {"id": id, "type": "death", "title": title, "lines": lines, "grant": grant, "rewind": rewind}


def V(id, title, lines, next):
    return {"id": id, "type": "converge", "title": title, "lines": lines, "next": next}


def E(id, title, lines, epilogue, tone):
    return {"id": id, "type": "ending", "title": title, "lines": lines, "epilogue": epilogue, "tone": tone}


MEM = lambda m: ["mem", "has", m]

chapters = []

# ───────────────────────── 第一章 ─────────────────────────
chapters.append({"id": "ch1", "title": "第九十九次", "subtitle": "序章 · 新手引导", "realm_req": 0, "nodes": [
    S("ch1_open", "外门石台", [["旁白", "血河宗，外门石台。"], ["魔种", "你死了九十九次。"], ["魔种", "这是第一百次。"]], "ch1_fight"),
    B("ch1_fight", "第九十九次死亡", {"waves": 1, "scripted_death": True}, "ch1_wake", "ch1_wake"),
    S("ch1_wake", "醒来", [["旁白", "你又醒了。"], ["旁白", "这一次，你带着一些东西。"], ["旁白", "石台边躺着一具外门弟子的尸体，和你穿着同样的衣服。"]], "ch1_body"),
    C("ch1_body", "石台边的尸体", "他的储物袋还鼓着。", [
        O("翻他的储物袋", "ch1_body_loot", set={"pills": 1, "ruthless": 1}),
        O("替他合上眼", "ch1_body_close", set={"kindness": 1}),
    ]),
    S("ch1_body_loot", "翻找", [["旁白", "一颗回气丹，半块灵石。"], ["魔种", "苟住的第一课：死人的东西，也是东西。"]], "ch1_mem"),
    S("ch1_body_close", "合眼", [["旁白", "你替他合上了眼。"], ["旁白", "那张脸，和你第三十世时一模一样。"]], "ch1_mem"),
    C("ch1_mem", "带哪条记忆", "九十九世留下三段记忆，这一世只能带一段：", [
        O("「师兄会在第3波背刺」", "ch1_senior", set={"+mem": "mem_betray"}),
        O("「长老怕火」", "ch1_senior", set={"+mem": "mem_fire"}),
        O("「后山洞里有丹药」", "ch1_senior", set={"+mem": "mem_pill", "pills": 1}),
    ]),
    S("ch1_senior", "师兄厉寒", [["厉寒", "师弟，醒了？这一波我掩护你~"]], "ch1_battle"),
    B("ch1_battle", "外门试炼", {"waves": 2, "senior": "ally"}, "ch1_loot", "ch1_loot"),
    C("ch1_loot", "丹药", "掉落【筑基丹】×1。厉寒在看你。", [
        O("独吞（苟道）", "ch1_end", set={"pills": 1, "senior_rel": -2, "ruthless": 1}),
        O("分给师兄", "ch1_end", set={"senior_rel": 1, "kindness": 1}),
        O("「后山洞里还有，这颗给你。」", "ch1_end", req=[MEM("mem_pill")], set={"senior_rel": 2, "pills": 1, "trust": 1}),
    ]),
    V("ch1_end", "收束 · 考核将至", [["旁白", "三日后，外门考核。"]], "ch2_open"),
]})

# ───────────────────────── 第二章 ─────────────────────────
chapters.append({"id": "ch2", "title": "外门考核", "subtitle": "第三波", "realm_req": 0, "nodes": [
    S("ch2_open", "考核台", [["血骨", "外门弟子，活下来的，才算人材。"], ["厉寒", "（低声）师弟，跟紧我。"]], "ch2_vanguard"),
    C("ch2_vanguard", "谁打头阵", "血骨：「谁愿意打头阵？」", [
        O("上前一步：「弟子愿往。」", "ch2_front", set={"elder_respect": 1}),
        O("往人群里缩（苟道）", "ch2_back", set={"ruthless": 1}),
    ]),
    S("ch2_front", "请缨", [["血骨", "有胆。本座记住你了。"], ["厉寒", "（皱眉）你疯了？"]], "ch2_waves"),
    S("ch2_back", "缩后", [["旁白", "三个抢着出头的弟子，第一波就没了。"], ["魔种", "很好。活着才能记账。"]], "ch2_waves"),
    B("ch2_waves", "第一、二波", {"waves": 2, "senior": "ally"}, "ch2_w3", "ch2_w3"),
    C("ch2_w3", "第三波", "第三波。厉寒站到了你身后。", [
        O("闪身，反杀厉寒", "ch2_kill", req=[MEM("mem_betray")], set={"senior": "dead", "ruthless": 2}, key=True),
        O("闪身，饶他一命", "ch2_spare", req=[MEM("mem_betray")], set={"senior": "debt", "kindness": 1}, key=True),
        O("「长老，他要背刺我。」", "ch2_report", req=[MEM("mem_betray")], set={"senior": "enemy", "elder_respect": 1}),
        O("背对他，继续杀敌", "ch2_trust", next_if=[[[["senior_rel", "<", 0]], "ch2_death"]], set={"senior": "loyal"}),
    ]),
    D("ch2_death", "背后一凉", [["厉寒", "师弟，魔门的规矩你懂的。"], ["旁白", "背后一凉。"]], "mem_betray", "ch2_open"),
    S("ch2_kill", "反杀", [["旁白", "厉寒倒下，眼里全是不解。"], ["血骨", "有意思。"]], "ch2_end"),
    S("ch2_spare", "饶命", [["厉寒", "……你怎么知道？"], ["你", "我记得。"], ["厉寒", "你记得？记得什么？"], ["你", "记得你每一次都会后悔。"], ["厉寒", "这条命，算我欠你的。"]], "ch2_end"),
    S("ch2_report", "揭发", [["血骨", "背后出手，也得有本事。你，不错。"], ["厉寒", "（被拖走）我记住你了。"]], "ch2_end"),
    S("ch2_trust", "他没有出手", [["旁白", "他没有出手。"], ["厉寒", "丹药的事……我记着你的好。"]], "ch2_end"),
    V("ch2_end", "收束 · 入内门", [["旁白", "你成了内门弟子。"], ["旁白", "血骨长老多看了你一眼。"]], "ch3_open"),
]})

# ───────────────────────── 第三章 ─────────────────────────
chapters.append({"id": "ch3", "title": "药堂之夜", "subtitle": "炉鼎", "realm_req": 1, "nodes": [
    S("ch3_open", "子夜药堂", [["旁白", "内门药堂，子夜。"], ["苏晚", "师兄……血月祭，要用我做炉鼎。"], ["苏晚", "我还没见过药堂外面的春天。"], ["苏晚", "你能……带我走吗？"]], "ch3_gift"),
    C("ch3_gift", "一包药", "苏晚塞给你一个小药包：「若出事，吃这个。」", [
        O("收下", "ch3_gift_take", set={"pills": 1, "trust": 1}),
        O("推回去：「你比我更需要。」", "ch3_gift_back", set={"kindness": 1}),
    ]),
    S("ch3_gift_take", "收下", [["苏晚", "……谢谢你肯收。"]], "ch3_choice"),
    S("ch3_gift_back", "推回", [["苏晚", "（愣了一下）你和别的师兄不一样。"]], "ch3_choice"),
    C("ch3_choice", "苏晚的请求", "药炉咕嘟作响。", [
        O("「我带你走。」", "ch3_route", set={"suwan": "escape", "kindness": 1}, key=True),
        O("「厉寒会帮我们。」", "ch3_route_senior", req=[["senior", "in", ["debt", "loyal"]]], set={"suwan": "escape", "senior": "loyal"}),
        O("装作没听见", "ch3_ignore", set={"suwan": "ignored"}),
        O("向长老告密", "ch3_report", set={"suwan": "sacrificed", "ruthless": 1, "elder_respect": 1}, key=True),
    ]),
    C("ch3_route", "后山的路", "后山只有一条路，巡夜弟子来回走。", [
        O("趁子时换岗溜过去", "ch3_saved", req=[MEM("mem_patrol")], set={"suwan": "saved"}),
        O("硬闯", "ch3_fight"),
    ]),
    S("ch3_route_senior", "厉寒引开巡夜", [["厉寒", "巡夜的我来引开。"], ["厉寒", "师弟，这回换我还你。"]], "ch3_saved", set={"suwan": "saved"}),
    B("ch3_fight", "硬闯巡夜", {"waves": 1, "count": 8, "escort": "苏晚"}, "ch3_saved_fight", "ch3_death"),
    S("ch3_saved_fight", "杀出一条路", [["旁白", "血染了后山的雾。"]], "ch3_saved", set={"suwan": "saved", "ruthless": 1}),
    D("ch3_death", "巡夜的剑", [["旁白", "巡夜弟子的剑穿过你们两个。"], ["旁白", "倒下前你看清了——他们子时换岗。"]], "mem_patrol", "ch3_open"),
    S("ch3_saved", "苏晚离开", [["苏晚", "我会回来找你的。"], ["苏晚", "带着春天回来。"], ["旁白", "她消失在后山的雾里。"]], "ch3_end"),
    S("ch3_ignore", "转身", [["旁白", "你转身。药炉咕嘟作响。"], ["魔种", "苟住，很好。"]], "ch3_end"),
    S("ch3_report", "告密", [["血骨", "炉鼎跑不了。你，赏。"], ["旁白", "苏晚被带走时，没有看你。"]], "ch3_end"),
    V("ch3_end", "收束 · 四十九天", [["旁白", "血月祭，还有四十九天。"]], "ch4_open"),
]})

# ───────────────────────── 第四章 ─────────────────────────
chapters.append({"id": "ch4", "title": "血骨", "subtitle": "第三十七次", "realm_req": 2, "nodes": [
    S("ch4_open", "独见", [["旁白", "长老的洞府里只有一盏灯，离他很远。"], ["血骨", "坐。喝茶。"]], "ch4_tea"),
    C("ch4_tea", "一杯茶", "茶是红的。", [
        O("一饮而尽", "ch4_tea_drink", set={"elder_respect": 1}),
        O("不动", "ch4_tea_refuse", set={"ruthless": 1}),
    ]),
    S("ch4_tea_drink", "饮", [["血骨", "敢喝本座的茶……"], ["血骨", "你的眼神，本座见过。说吧，你到底是谁？"]], "ch4_choice"),
    S("ch4_tea_refuse", "不饮", [["血骨", "谨慎。好。"], ["血骨", "你的眼神，本座见过。说吧，你到底是谁？"]], "ch4_choice"),
    C("ch4_choice", "你到底是谁", "长老的指尖，停在你天灵盖上方一寸。", [
        O("我记得你第三十七世的样子。", "ch4_truth_ally", req=[MEM("mem_elder37")], set={"elder": "ally", "know_seed": True}, key=True),
        O("点燃火折子：「您怕这个。」", "ch4_blackmail", req=[MEM("mem_fire")]),
        O("「我在轮回。这是第一百世。」", "ch4_truth", next_if=[[[["elder_respect", "<", 1]], "ch4_death_truth"]]),
        O("装傻：「弟子只是运气好。」", "ch4_test"),
    ]),
    D("ch4_death_truth", "天灵盖", [["血骨", "第三十七次，也是这样开口的。"], ["旁白", "他的手按了下来。"]], "mem_elder37", "ch4_open"),
    B("ch4_test", "长老试手", {"waves": 1, "boss": "elder"}, "ch4_pass", "ch4_death_fire"),
    D("ch4_death_fire", "火把", [["旁白", "你倒下时，火把滚到他脚边——"], ["旁白", "他退了一步。"]], "mem_fire", "ch4_open"),
    S("ch4_pass", "运气好", [["血骨", "运气好？呵。滚吧。"]], "ch4_end", set={"elder": "suspicious"}),
    S("ch4_truth", "第三十七次的你", [["旁白", "血骨沉默了很久。"], ["血骨", "本座……是第三十七次的你。"], ["血骨", "那一世，我选择了跪下。"]], "ch4_end", set={"elder": "ally", "know_seed": True}),
    S("ch4_truth_ally", "你竟然记得", [["血骨", "……你竟然记得。"], ["血骨", "轮回的源头，是宗主体内的魔种。"]], "ch4_end"),
    C("ch4_blackmail", "火光", "他盯着火光，额头见汗。", [
        O("「告诉我轮回的秘密。」", "ch4_end", set={"elder": "blackmailed", "know_seed": True}),
        O("烧了他", "ch4_burn", set={"elder": "burned", "ruthless": 2}, key=True),
    ]),
    S("ch4_burn", "焚", [["血骨", "（在火里笑）你也会跪下的。"]], "ch4_end"),
    V("ch4_end", "收束 · 七天", [["旁白", "血月祭，还有七天。"]], "ch5_open"),
]})

# ───────────────────────── 第五章 ─────────────────────────
chapters.append({"id": "ch5", "title": "正道来客", "subtitle": "白衣", "realm_req": 2, "nodes": [
    S("ch5_open", "后山阵眼", [["旁白", "后山，一个白衣人在画阵。阵还差最后一笔。"], ["顾长风", "天衍剑宗，顾长风。魔门弟子，要杀便来。"]], "ch5_array"),
    C("ch5_array", "未成之阵", "阵眼在你脚边。", [
        O("替他补上最后一笔", "ch5_array_help", set={"trust": 1}),
        O("一脚踩碎阵眼", "ch5_array_break", set={"master_favor": 1, "ruthless": 1}),
        O("看着，不动", "ch5_choice"),
    ]),
    S("ch5_array_help", "补阵", [["顾长风", "……魔门弟子，会画天衍剑阵？"], ["你", "第六十世，我在剑宗扫过三年地。"]], "ch5_choice"),
    S("ch5_array_break", "碎阵", [["顾长风", "（剑已半出鞘）好。"]], "ch5_choice"),
    C("ch5_choice", "白衣人", "他的剑没有出鞘。", [
        O("苏晚从雾里走出来：「哥？」", "ch5_family", req=[["suwan", "==", "saved"]], set={"gu": "ally", "trust": 1}, key=True),
        O("「苏晚还活着。」", "ch5_family", req=[MEM("mem_gu"), ["suwan", "==", "saved"]], set={"gu": "ally"}),
        O("「血月祭那天，我给你开门。」", "ch5_ally", set={"gu": "ally"}),
        O("假意结盟，回头禀报宗主", "ch5_used", set={"gu": "used", "ruthless": 1, "master_favor": 1}, key=True),
        O("拔剑", "ch5_fight"),
    ]),
    B("ch5_fight", "剑与魔", {"waves": 1, "boss": "gu"}, "ch5_kill", "ch5_death"),
    D("ch5_death", "替我照顾晚儿", [["顾长风", "魔门也有不想杀人的……"], ["顾长风", "替我……照顾晚儿。"]], "mem_gu", "ch5_open"),
    S("ch5_kill", "白衣染血", [["顾长风", "晚儿……对不起。"], ["旁白", "你不知道他在说谁。"]], "ch5_end", set={"gu": "dead", "master_favor": 1}),
    S("ch5_ally", "盟约", [["顾长风", "若你骗我，剑宗会踏平血河。"]], "ch5_end"),
    S("ch5_used", "传音", [["夜无归", "（传音）做得好，人材。"]], "ch5_end"),
    S("ch5_family", "兄妹", [["顾长风", "晚儿……"], ["苏晚", "哥，他救过我。在这个地方，他救过我。"], ["顾长风", "这份恩，天衍剑宗记下了。"]], "ch5_end"),
    V("ch5_end", "收束 · 血月", [["旁白", "血月升起。"]], "ch6_open"),
]})

# ───────────────────────── 第六章 ─────────────────────────
chapters.append({"id": "ch6", "title": "血月祭", "subtitle": "收割", "realm_req": 3, "nodes": [
    S("ch6_open", "祭坛", [["夜无归", "一百世的魔元，今天收割。"], ["夜无归", "你以为你在轮回？你只是在替我养种。"], ["夜无归", "跪下。跪下的人，本座许他不痛。"]], "ch6_kneel"),
    C("ch6_kneel", "跪下", "满坛弟子都跪了下去。", [
        O("跪", "ch6_kneel_yes", set={"master_favor": 1}),
        O("站着", "ch6_kneel_no", set={"trust": 1}),
    ]),
    S("ch6_kneel_yes", "跪", [["夜无归", "好人材。"], ["魔种", "你吐纳了一次。"]], "ch6_ledger"),
    S("ch6_kneel_no", "不跪", [["旁白", "整座祭坛，只有你站着。"], ["夜无归", "……第一百世，终于有点意思了。"], ["魔种", "你吐纳了一次。"]], "ch6_ledger"),
    {"id": "ch6_ledger", "type": "ledger", "title": "账本：喂养魔种", "seconds": 12,
     "lines": [["魔种", "吐纳吧。每一次，我都会记下。"]], "next": "ch6_seed"},
    C("ch6_seed", "魔种在跳", "魔种在你体内跳动。", [
        O("把魔种引向宗主左胸", "ch6_allies", req=[["know_seed", "==", True], MEM("mem_master")], set={"seed": "turned"}, key=True),
        O("「长老，火！」", "ch6_allies", req=[["elder", "==", "ally"]], set={"seed": "sealed"}),
        O("抗拒它", "ch6_allies", set={"seed": "refused"}),
        O("与魔种相融", "ch6_merge", set={"seed": "merged"}, key=True),
    ]),
    S("ch6_merge", "相融", [["魔种", "很好。"], ["魔种", "我们开始炼化。"]], "ch6_boss"),
    S("ch6_allies", "有人站到你身边", [["旁白", "有人站到了你身边。"]], "ch6_boss"),
    B("ch6_boss", "宗主夜无归", {"waves": 1, "boss": "master", "allies_from_flags": True}, "ch6_end", "ch6_death"),
    D("ch6_death", "第一百零一次", [["夜无归", "第一百零一次，我等你。"], ["旁白", "倒下前你看见——他的魔种，在左胸。"]], "mem_master", "ch6_open"),
    V("ch6_end", "收束 · 掌心", [["旁白", "宗主倒下。"], ["旁白", "魔种在你掌心跳动。"]], "ch7_open"),
]})

# ───────────────────────── 第七章 ─────────────────────────
NOT_MERGED = ["seed", "!=", "merged"]
chapters.append({"id": "ch7", "title": "第一百世", "subtitle": "终章", "realm_req": 0, "nodes": [
    S("ch7_open", "掌心", [["魔种", "你吐纳了一次。"], ["魔种", "选之前，你可以回头看一眼。"]], "ch7_look"),
    C("ch7_look", "回头看谁", "身后站着的人，是你这一世的答案。", [
        O("看厉寒", "ch7_look_senior", req=[["senior", "in", ["loyal", "debt"]]]),
        O("看苏晚", "ch7_look_suwan", req=[["suwan", "==", "saved"]]),
        O("看血骨", "ch7_look_elder", req=[["elder", "in", ["ally", "blackmailed"]]]),
        O("看顾长风", "ch7_look_gu", req=[["gu", "==", "ally"]]),
        O("谁也不看", "ch7_look_none"),
    ]),
    S("ch7_look_senior", "厉寒", [["厉寒", "师弟，这回别再死了。我可记不住一百次。"]], "ch7_final"),
    S("ch7_look_suwan", "苏晚", [["苏晚", "外面的春天，我看到了。"]], "ch7_final"),
    S("ch7_look_elder", "血骨", [["血骨", "第三十七次的我没选对。第一百次的你，别学我。"]], "ch7_final"),
    S("ch7_look_gu", "顾长风", [["顾长风", "不管你选什么，剑宗欠你一个人情。"]], "ch7_final"),
    S("ch7_look_none", "无人", [["旁白", "你没有回头。"], ["魔种", "现在，选吧。"]], "ch7_final"),
    C("ch7_final", "最后的选择", "魔种在你掌心。所有人都在看你。", [
        O("放下魔种，让轮回停止", "end_true", req=[["mems", ">=", 6], ["senior", "==", "loyal"], ["suwan", "==", "saved"], ["elder", "==", "ally"], ["seed", "in", ["refused", "sealed", "turned"]], ["seed_feed", "<", 30]], key=True),
        O("与血骨一同焚尽魔种", "end_fire", req=[["elder", "in", ["ally", "blackmailed"]], MEM("mem_fire"), NOT_MERGED]),
        O("把魔种交给顾长风", "end_sword", req=[["gu", "==", "ally"], NOT_MERGED]),
        O("坐上宗主之位", "end_lord", req=[NOT_MERGED], next_if=[[[["senior", "==", "loyal"], ["suwan", "==", "saved"]], "end_family"]]),
        O("跪下，成为下一个血骨", "end_kneel"),
        O("吞下魔种，炼化万物", "end_all"),
    ], timer=20),
    E("end_all", "万物皆魔元", [["魔种", "外门：炼化完毕。"], ["魔种", "魔门：炼化完毕。"], ["魔种", "三千世界：炼化完毕。"], ["你", "万物皆成魔元。只有我还记得它们。"]], "账本最后一行：你吐纳了一次。", "dark"),
    E("end_lord", "新宗主", [["旁白", "你坐上了血河宗主之位。"], ["旁白", "身边没有人。"], ["魔种", "苟住，很好。"]], "血河宗换了宗主，炉鼎照旧。", "dark"),
    E("end_family", "同门", [["厉寒", "宗主？叫师兄。"], ["苏晚", "药堂，我来管。"], ["旁白", "血河宗第一次，没有炉鼎。"]], "魔门里，也可以有同门。", "warm"),
    E("end_sword", "正道之剑", [["旁白", "顾长风的剑斩碎魔种，也斩下了你的头。"], ["顾长风", "魔门弟子，终究是魔门弟子。"]], "后山有一块无字碑，每年血月，有人来扫。", "bitter"),
    E("end_fire", "焚火", [["旁白", "火从血骨身上烧到你身上。"], ["血骨", "第三十七次，第一百次——够了。"], ["旁白", "轮回，烧断了。"]], "没有第一百零一次。", "bitter"),
    E("end_loop", "第一百零一次", [["旁白", "你犹豫了。"], ["魔种", "你死了一百次。"], ["魔种", "这是第一百零一次。"]], "带着全部记忆，从外门石台重新开始。", "loop"),
    E("end_kneel", "替身", [["旁白", "你跪下。"], ["夜无归", "（魔种里传来笑声）好人材。"], ["旁白", "外门石台上，一个新弟子第一次死去。"]], "你成了下一个血骨。", "dark"),
    E("end_true", "真 · 飞升", [["旁白", "你放下魔种。"], ["旁白", "厉寒、苏晚、血骨、顾长风……每一世的他们，都在这里。"], ["魔种", "你吐纳了一次。"], ["旁白", "这一次，只是吐纳。"]], "轮回停了。你第一次，没有记账。", "true"),
]})
# ch7 超时（犹豫）→ 第一百零一次
next(n for n in chapters[-1]["nodes"] if n["id"] == "ch7_final")["timeout_next"] = "end_loop"


# ───────────── 自动布局（流程图坐标；设计稿与游戏共用） ─────────────
def succ(n):
    out = []
    if n["type"] == "choice":
        for o in n["options"]:
            for c, nx in o.get("next_if", []):
                out.append(nx)
            if o.get("next"):
                out.append(o["next"])
        if n.get("timeout_next"):
            out.append(n["timeout_next"])
    elif n["type"] == "battle":
        out += [n["win"], n["lose"]]
    elif n["type"] == "death":
        pass  # 回到本章开头：流程图画成虚线回环，不参与分层
    elif n["type"] in ("scene", "ledger", "converge"):
        out.append(n["next"])
    seen = []
    for x in out:
        if x not in seen:
            seen.append(x)
    return seen


def vis_graph(ch):
    """把选项展开成独立的流程图节点（《底特律》式：每个选项一张卡）"""
    vn, edges = [], []
    for n in ch["nodes"]:
        vn.append({"vid": n["id"], "kind": "node", "ref": n["id"]})
        if n["type"] == "choice":
            for i, o in enumerate(n["options"]):
                ov = f"{n['id']}#{i}"
                vn.append({"vid": ov, "kind": "option", "ref": n["id"], "opt": i})
                edges.append([n["id"], ov, "solid"])
                for c, nx in o.get("next_if", []):
                    edges.append([ov, nx, "cond"])
                if o.get("next"):
                    edges.append([ov, o["next"], "solid"])
            if n.get("timeout_next"):
                edges.append([n["id"], n["timeout_next"], "timeout"])
        elif n["type"] == "battle":
            edges.append([n["id"], n["win"], "win"])
            if n["lose"] != n["win"]:
                edges.append([n["id"], n["lose"], "lose"])
        elif n["type"] == "death":
            edges.append([n["id"], n["rewind"], "rewind"])
        elif n["type"] in ("scene", "ledger", "converge"):
            if n["next"] in {x["id"] for x in ch["nodes"]}:
                edges.append([n["id"], n["next"], "solid"])
    return vn, edges


for ch in chapters:
    vn, edges = vis_graph(ch)
    vids = {v["vid"]: v for v in vn}
    fwd = [e for e in edges if e[2] != "rewind" and e[1] in vids]
    depth = {vn[0]["vid"]: 0}
    for _ in range(len(vn) + 2):
        for a, b, _s in fwd:
            if a in depth and depth.get(b, -1) < depth[a] + 1:
                depth[b] = depth[a] + 1
    maxd = max(depth.values())
    for v in vn:
        if v["kind"] == "node" and next(n for n in ch["nodes"] if n["id"] == v["ref"])["type"] == "converge":
            depth[v["vid"]] = maxd
        depth.setdefault(v["vid"], maxd)
    rows = defaultdict(list)
    for v in vn:
        rows[depth[v["vid"]]].append(v["vid"])
    parents = defaultdict(list)
    for a, b, _s in fwd:
        parents[b].append(a)
    xpos = {}
    for d in sorted(rows):
        lst = rows[d]
        order = {vid: i for i, vid in enumerate(lst)}
        def bary(vid):
            ps = [xpos[p] for p in parents[vid] if p in xpos]
            return (sum(ps) / len(ps) if ps else 0.0, order[vid])
        lst.sort(key=bary)
        k = len(lst)
        for i, vid in enumerate(lst):
            xpos[vid] = i - (k - 1) / 2
    # 第二遍：按子节点重心微调，减少交叉
    for d in sorted(rows, reverse=True):
        lst = rows[d]
        kids = defaultdict(list)
        for a, b, _s in fwd:
            kids[a].append(b)
        lst.sort(key=lambda vid: (sum(xpos[c] for c in kids[vid]) / len(kids[vid]) if kids[vid] else xpos[vid], xpos[vid]))
        k = len(lst)
        for i, vid in enumerate(lst):
            xpos[vid] = i - (k - 1) / 2
    for v in vn:
        v["x"] = round(xpos[v["vid"]], 2)
        v["y"] = depth[v["vid"]]
    ch["layout"] = {"nodes": vn, "edges": edges, "rows": maxd + 1, "cols": max(len(r) for r in rows.values())}


story = {
    "title": "魔门人材",
    "reference": "Detroit: Become Human 式章节流程图：分支 → 收束点；轮回记忆 = 线索解锁；8 结局由累计标记 + 终章选择决定",
    "flags": FLAGS,
    "memories": MEMORIES,
    "characters": CHARACTERS,
    "chapters": chapters,
}

# ───────────── 校验：所有跳转目标存在 ─────────────
all_ids = {n["id"] for ch in chapters for n in ch["nodes"]}
for ch in chapters:
    for n in ch["nodes"]:
        targets = succ(n) + ([n["rewind"]] if n["type"] == "death" else [])
        for t in targets:
            assert t in all_ids, f"{n['id']} → {t} 不存在"
        if n["type"] == "death":
            assert n["grant"] in MEMORIES
endings = [n for ch in chapters for n in ch["nodes"] if n["type"] == "ending"]
assert len(endings) == 8, len(endings)
assert len(chapters) == 7

(ROOT / "data").mkdir(exist_ok=True)
(ROOT / "data/story.json").write_text(json.dumps(story, ensure_ascii=False, indent=1))
print("chapters", len(chapters), "nodes", len(all_ids), "endings", len(endings))
