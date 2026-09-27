#!/usr/bin/env python3
"""魔门人材 v2 ·「忆」—— 唯一剧情源。

运行：python3 tools/build_story.py  →  data/story.json

结构
- 5 章线性推进；每章一个唯一冲突，冲突分 2–5 层（layers），首世只看得到第 1 层（最多第 2 层）。
- 更深的层要靠：①后续章节拿到的记忆碎片（在关键节点主动「使用」）；②上一世后续章节的选择
  （echo 回响标记，只影响下一世）；③本世更早章节的标记。
- 记忆碎片：本世拿到的是「未铭刻」，只能回看；死亡时从中选一片「铭刻」，之后每一世都能在钩子节点主动使用。
- 每章一个新的单一数值（metric），只显示字形和数字，不解释；旧章数值保留但只剩微弱影响。

节点字段
  id, ch, scene, cast[], text[]（"名：台词" 为对白，其余为旁白）
  npc      自由输入/AI 选项的对话对象
  hook     [碎片 id...] —— 在此节点「使用」这些碎片可显出隐藏选项（◆ 似曾相识）
  tease    {关键词: 台词} —— 自由输入说中了隐藏话题、但玩家没有对应碎片时的回应
  choices  [{id, text[变体], kw[关键词], to, req, fx}]
  other    自由输入没对上任何选项时的回应
  auto     无选项，点一下继续 → 下一个节点
  check    [{if, to}] 按条件自动分流（最后一条无 if）
  battle   {kind, foes, allies[], betray?, outcomes:[{if, to}]}  —— if 里可写 skill:block（玩家在背刺前一刻切到「守」）
  death    {hint, frag}  —— 死亡：提示一段记忆，玩家须从背包里主动选出并「铭刻」
  fx       {m:{metric:+n}, m_if:[{if, m}], set[], echo[], frag, layer, mem:[{a,text,v,i}]}
  ui       "breathe"：一键吐纳（Paperclips 式），数值自己涨
  chapter_end: 下一章号 | ending: 结局 id
req / if 条件
  flag[] noflag[] echo[]（上一世留下的回响） noecho[] layer[] m:{k:[op,n]} frag（须在本节点主动使用该碎片）
  skill（仅战斗）
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "data", "story.json")

CAST = {
    "me":      {"name": "我",     "glyph": "我", "color": "f4f0e6", "r": 8},
    "lihan":   {"name": "厉寒",   "glyph": "厉", "color": "ff9a3c", "r": 8,
                "persona": "魔门外门师兄厉寒。精明、嘴甜、记仇。你被困在轮回里已经九十九世——你记得每一世，但从不承认。你在药堂押了一条命，长老答应只要你每一世亲手取走师弟的魔元，就放你出轮回。"},
    "xiaoman": {"name": "小满",   "glyph": "满", "color": "7fe07a", "r": 6,
                "persona": "药堂小药童小满，看着九岁。胆小、嘴硬。其实是长老亡女的魂，被一层层纸折回人形，靠续命丹维持。"},
    "zhou":    {"name": "周衡",   "glyph": "周", "color": "b58cff", "r": 8,
                "persona": "药堂主事周衡。账房出身，一切都记在账上，包括每个人第几世欠了什么。冷淡，讲规矩，不沾血。"},
    "elder":   {"name": "血骨长老", "glyph": "骨", "color": "c8324a", "r": 11,
                "persona": "魔门血骨长老。阴沉、多疑，怕火。腰间挂着一个纸人，是他死去女儿小满。他烧了一百世的百世炉，只为让她真的活过来。"},
    "suqing":  {"name": "苏清",   "glyph": "苏", "color": "5ce8f0", "r": 8,
                "persona": "正道女剑修苏清，化名散修潜入魔门，奉命寻找百世炉。直率、骄傲，不愿再当任何人的薪柴。"},
    "foe":     {"name": "妖",     "glyph": "妖", "color": "e23440", "r": 6},
    "bone":    {"name": "骨人",   "glyph": "?", "color": "d8d0c0", "r": 7},
    "mute":    {"name": "哑巴",   "glyph": "哑", "color": "a0a0a0", "r": 7},
}

METRICS = {  # 每章一个新数值；只显示字形，不解释
    "qi":   {"glyph": "元", "name": "魔元", "ch": 1, "start": 0},
    "qing": {"glyph": "情", "name": "人情", "ch": 2, "start": 0},
    "ming": {"glyph": "名", "name": "名声", "ch": 3, "start": 0},
    "wei":  {"glyph": "伪", "name": "伪装", "ch": 4, "start": 3},
    "yi":   {"glyph": "忆", "name": "记得你的人", "ch": 5, "start": 0},
}

FRAGS = {
    "frag_zhusha":    {"title": "袖口的朱砂", "ch": 1,
                       "text": "厉寒刺进来那一刻，袖口翻起，露出一枚朱砂印。药堂记账时，就盖这种印。"},
    "frag_crane":     {"title": "纸鹤", "ch": 1,
                       "text": "窗缝里塞进来的纸鹤，写着「别看师兄，看他身后」。纸摸起来是温的，像人皮。落款：小满。"},
    "frag_fire":      {"title": "骨人怕火", "ch": 1,
                       "text": "树影里的无脸骨人，被火一燎就散了。散之前，它用长老的声音说了一句：「好弟子。」"},
    "frag_99":        {"title": "他念的数", "ch": 1,
                       "text": "厉寒死前嘴里念着一个数：「九十九……」不是在数伤口。"},
    "frag_ledger":    {"title": "药堂账本", "ch": 2,
                       "text": "周衡的账本上，同一个名字写了一百遍，每一遍后面跟着「第N世」。有厉寒的，也有你的。"},
    "frag_paper":     {"title": "纸做的手腕", "ch": 2,
                       "text": "小满的手腕裂开，里面没有血，是一层层叠起来的纸。她说：「爹爹把我折回来的。」"},
    "frag_kehen":     {"title": "九十九道刻痕", "ch": 3,
                       "text": "厉寒倒在擂台上，左腕翻过来——密密麻麻，刻了九十九道痕。"},
    "frag_paperdoll": {"title": "长老的纸人", "ch": 3,
                       "text": "长老出手时，一直用另一只手护着腰间的小纸人。纸人的脸，和小满一模一样。"},
    "frag_furnace":   {"title": "擂台下的炉", "ch": 3,
                       "text": "擂台的石缝里透出血光。台下是一口炉子，吃的是每一世死在台上的人。"},
    "frag_voluntary": {"title": "薪者须自愿", "ch": 4,
                       "text": "正道密录：「百世炉，以一人百世之魔元为薪。薪者须自愿。」"},
    "frag_tassel":    {"title": "剑穗上的魔纹", "ch": 4,
                       "text": "苏清的剑穗扫过你手背。正道的剑穗上，绣着和炉壁一样的魔纹。"},
    "frag_hand":      {"title": "牵过的小手", "ch": 5,
                       "text": "炉火吞没你之前，你想起很久以前，有一只很小的手牵着你。那只手，凉得像纸。"},
    "frag_first":     {"title": "第一世", "ch": 5,
                       "text": "第一世，你是小满的哥哥。是你求长老造了这口炉，也是你第一个走了进去。"},
}

CHAPTERS = [
    {"n": 1, "title": "后山", "metric": "qi", "start": "c1_start", "scene": "forest",
     "conflict": "师兄约我去后山",
     "layers": [{"id": "c1_l1", "title": "师兄要杀我"},
                {"id": "c1_l2", "title": "师兄的命押在药堂"},
                {"id": "c1_l3", "title": "树影里有人在看"},
                {"id": "c1_l4", "title": "师兄也记得"}]},
    {"n": 2, "title": "药堂之夜", "metric": "qing", "start": "c2_start", "scene": "yaotang",
     "conflict": "药堂丢了一颗续命丹",
     "layers": [{"id": "c2_l1", "title": "我被诬陷偷丹"},
                {"id": "c2_l2", "title": "偷丹的是药童小满"},
                {"id": "c2_l3", "title": "小满是纸做的"}]},
    {"n": 3, "title": "血骨擂台", "metric": "ming", "start": "c3_start", "scene": "arena",
     "conflict": "外门大比，只留一个",
     "layers": [{"id": "c3_l1", "title": "长老要我杀死师兄"},
                {"id": "c3_l2", "title": "长老在护着一个纸人"},
                {"id": "c3_l3", "title": "擂台下面是炉子"}]},
    {"n": 4, "title": "正道来客", "metric": "wei", "start": "c4_start", "scene": "gate",
     "conflict": "山门外来了个女剑修",
     "layers": [{"id": "c4_l1", "title": "我要亲手抓住奸细"},
                {"id": "c4_l2", "title": "炉子的薪柴是自愿的"}]},
    {"n": 5, "title": "血月祭", "metric": "yi", "start": "c5_start", "scene": "altar",
     "conflict": "血月之夜，我被绑上祭坛",
     "layers": [{"id": "c5_l1", "title": "我是祭品"},
                {"id": "c5_l2", "title": "炉子是为小满烧的"},
                {"id": "c5_l3", "title": "师兄的交易"},
                {"id": "c5_l4", "title": "正道也想要炉子"},
                {"id": "c5_l5", "title": "点火的是第一世的我"}]},
]

ENDINGS = {
    "e_true":    {"title": "焚炉", "sub": "第一百零一世，不会来了", "true": True},
    "e_xiaoman": {"title": "续命", "sub": "她醒了，不记得你"},
    "e_master":  {"title": "新宗主", "sub": "炉火还在烧"},
    "e_sword":   {"title": "正道之剑", "sub": "炉子换了主人"},
}

NODES = {}


def N(id, ch, text, scene=None, cast=None, **kw):
    assert id not in NODES, id
    n = {"id": id, "ch": ch, "text": text}
    if scene:
        n["scene"] = scene
    if cast is not None:
        n["cast"] = cast
    n.update(kw)
    NODES[id] = n
    return n


def C(id, text, to, kw=None, req=None, fx=None):
    c = {"id": id, "text": text if isinstance(text, list) else [text], "to": to, "kw": kw or []}
    if req:
        c["req"] = req
    if fx:
        c["fx"] = fx
    return c


# ============================== 第一章 · 后山 ==============================
N("c1_start", 1, ["魔门外门，卯时。", "你醒了。胸口还残留着被刺穿的幻痛。"],
  scene="court", cast=["me"],
  check=[{"if": {"echo": ["saved_xiaoman"]}, "to": "c1_crane"}, {"to": "c1_breathe"}])

N("c1_crane", 1, ["窗缝里塞进来一只纸鹤。", "纸鹤上写：「别看师兄。看他身后。——小满」",
                  "你不认识叫小满的人。至少这一世不认识。"],
  cast=["me"], fx={"set": ["saw_crane"], "frag": "frag_crane"}, auto="c1_breathe")

N("c1_breathe", 1, ["外门弟子每日须吐纳。", "魔门里只有一个道理：魔元。"],
  cast=["me"], ui="breathe",
  choices=[C("leave", ["收功，去见师兄。", "够了，出门。", "差不多了，去后山。"], "c1_invite",
             kw=["够", "走", "出门", "师兄", "去"])])

N("c1_invite", 1, ["厉寒：师弟，后山出了只妖狐，内丹值三百魔元。", "厉寒：同去？得手了五五分。"],
  scene="forest", cast=["me", "lihan"], npc="lihan",
  hook=["frag_zhusha", "frag_99", "frag_kehen"],
  tease={"死": "厉寒：……你说什么胡话？", "九十九": "厉寒：……九十九什么？没头没脑的。",
         "药堂": "厉寒：药堂？我跟药堂可不熟。", "朱砂": "厉寒：（把袖口往里掖了掖）什么朱砂。"},
  choices=[
      C("go", ["好，同去。", "师兄带路。", "五五分，成交。"], "c1_hunt", kw=["好", "去", "同去", "走", "成交"]),
      C("refuse", ["今日闭关，不去了。", "改天吧。"], "c1_refuse", kw=["不去", "闭关", "改天", "算了"]),
      C("ask", ["师兄怎么不找别人？", "为何偏偏找我？"], "c1_ask", kw=["为什么", "为何", "别人", "怎么"],
        req={"noflag": ["asked_lihan"]}, fx={"set": ["asked_lihan"]}),
      C("debt", "「你袖口那点朱砂，是药堂的印吧？」", "c1_debt", kw=["朱砂", "药堂", "袖口", "欠"],
        req={"frag": "frag_zhusha"}),
      C("loop", "「你刚才……在数第几世？」", "c1_loop", kw=["九十九", "99", "几世", "数"],
        req={"frag": "frag_99"}),
      C("loop2", "「你左腕的刻痕，第几道了？」", "c1_loop", kw=["刻痕", "左腕", "九十九", "99", "死过", "记得"],
        req={"frag": "frag_kehen"}),
  ],
  other=["厉寒：少废话。去不去？", "厉寒：（笑）师弟今天话真多。", "厉寒：天黑前得进山。"])

N("c1_ask", 1, ["厉寒：别人？别人没你命硬。", "他笑了一下。你觉得那句话哪里不对。"],
  cast=["me", "lihan"], auto="c1_invite")

N("c1_refuse", 1, ["你说今日要闭关。", "厉寒：……行。那师兄自己去。", "当夜，你被一阵药味惊醒。床边站着一个人。"],
  cast=["me", "lihan"], fx={"layer": "c1_l1"}, auto="c1_death_night")

N("c1_death_night", 1, ["刀落下来之前，你看见他袖口有一点红。", "厉寒：……对不住。这一世，还是得你死。"],
  cast=["me", "lihan"],
  death={"hint": "他袖口那一点红……在哪里见过？", "frag": "frag_zhusha"})

N("c1_hunt", 1, ["后山。妖狐的眼睛在雾里亮了一下。", "厉寒站到了你身后。"],
  scene="forest", cast=["me", "lihan"],
  battle={"kind": "hunt", "foes": 3, "allies": ["lihan"],
          "outcomes": [
              {"if": {"flag": ["ally_lihan"]}, "to": "c1_after_ally", "tactics": ["guard", "assist"]},
              {"if": {"flag": ["debt_talked"]}, "to": "c1_after_spared", "tactics": ["assist", "idle"]},
              {"if": {"m": {"qi": [">=", 30]}}, "to": "c1_survive", "tactics": ["betray"], "betray": True},
              {"if": {"skill": "block"}, "to": "c1_survive", "tactics": ["betray"], "betray": True},
              {"to": "c1_death_hunt", "tactics": ["betray"], "betray": True}]},
  fx={"layer": "c1_l1"})

N("c1_death_hunt", 1, ["刀从背后进来的时候，你闻到一股药味。", "厉寒：……对不住。这一世，还是得你死。"],
  cast=["me", "lihan"],
  death={"hint": "那股药味……还有他袖口的一点红。", "frag": "frag_zhusha"})

N("c1_survive", 1, ["那一刀，卡在了你的肋骨上。", "厉寒的脸白了：……你怎么会……"],
  cast=["me", "lihan"], npc="lihan", hook=["frag_zhusha", "frag_99", "frag_kehen"],
  choices=[
      C("kill", ["把刀送回他胸口。", "杀了他。"], "c1_kill", kw=["杀", "刀", "报仇"]),
      C("letgo", ["放他走。", "滚吧。"], "c1_letgo", kw=["放", "走", "滚"]),
      C("why", ["为什么？", "谁让你来的？"], "c1_why", kw=["为什么", "谁", "为何"]),
      C("debt", "「药堂逼你的？」", "c1_debt_late", kw=["药堂", "朱砂", "欠"], req={"frag": "frag_zhusha"}),
      C("loop", "「你也在数，对吗？」", "c1_loop_late", kw=["数", "九十九", "刻痕", "记得"], req={"frag": "frag_99"}),
      C("loop2", "「第几道了？你左腕的刻痕。」", "c1_loop_late", kw=["刻痕", "左腕", "九十九"], req={"frag": "frag_kehen"}),
  ],
  other=["厉寒：（握刀的手在抖）……别过来。"])

N("c1_kill", 1, ["你把刀送回了他的胸口。", "他倒下时，嘴里念着一个数：「九十九……」"],
  cast=["me"], fx={"m": {"qi": 50}, "frag": "frag_99", "set": ["killed_lihan"],
                   "mem": [{"a": "lihan", "text": "那一世，你杀了我", "v": -2, "i": 5}]},
  auto="c1_shadow_check")
N("c1_letgo", 1, ["你让他走了。", "他回头看了你一眼，像在确认什么。"],
  cast=["me", "lihan"], fx={"mem": [{"a": "lihan", "text": "那一世，你放了我", "v": 1, "i": 3}]},
  auto="c1_shadow_check")
N("c1_why", 1, ["厉寒：为什么？魔门里还需要为什么？", "他转身跑进雾里。"],
  cast=["me", "lihan"], auto="c1_shadow_check")
N("c1_debt_late", 1, ["厉寒：……药堂周主事那儿，我押了一条命。", "厉寒：你的魔元，刚好够还。",
                      "他丢下刀，跑进了雾里。"],
  cast=["me", "lihan"], fx={"layer": "c1_l2"}, auto="c1_shadow_check")
N("c1_loop_late", 1, ["厉寒愣住了。", "厉寒：……原来不是只有我记得。", "厉寒：下一世，别跟我去后山。"],
  cast=["me", "lihan"], fx={"layer": "c1_l4", "mem": [{"a": "lihan", "text": "他也记得轮回", "v": 2, "i": 5}]},
  auto="c1_shadow_check")

N("c1_debt", 1, ["厉寒的手抖了一下。", "厉寒：……药堂周主事那儿，我押了一条命。还不上，死的就是我。",
                 "厉寒：你的魔元，刚好够还。"],
  cast=["me", "lihan"], npc="lihan", fx={"layer": "c1_l2"},
  choices=[
      C("help", ["我帮你还。", "我们一起想办法。"], "c1_hunt", kw=["帮", "一起", "还", "办法"],
        fx={"set": ["debt_talked"], "mem": [{"a": "lihan", "text": "那一世，他说要帮我还债", "v": 2, "i": 4}]}),
      C("threat", ["那你现在就动手试试。", "来啊。"], "c1_hunt", kw=["动手", "来", "试试", "杀"]),
  ],
  tease={"死": "厉寒：（盯着你）……你到底知道多少？", "九十九": "厉寒：（盯着你）……你到底知道多少？"},
  other=["厉寒：别绕弯子，你到底想怎样？"])

N("c1_loop", 1, ["厉寒盯着你看了很久。", "厉寒：九十九。你也数到了？", "厉寒：……原来不是只有我记得。",
                 "厉寒：这一世，我不杀你。后山，我们换个活法。"],
  cast=["me", "lihan"],
  fx={"layer": "c1_l4", "set": ["ally_lihan"], "mem": [{"a": "lihan", "text": "他也记得轮回，我们结盟了", "v": 2, "i": 5}]},
  auto="c1_hunt")

N("c1_after_spared", 1, ["妖狐倒下了。", "厉寒握着刀站在你背后，很久没有动。", "厉寒：……这一世，就算了。",
                         "你没问「这一世」是什么意思。"],
  cast=["me", "lihan"], fx={"m": {"qi": 30}}, auto="c1_shadow_check")
N("c1_after_ally", 1, ["妖狐倒下了。", "一根骨刺从树影里射来，厉寒侧身替你挡了。", "厉寒：看见了吗？一直有人在看。"],
  cast=["me", "lihan", "bone"], fx={"m": {"qi": 30}}, auto="c1_shadow_look")

N("c1_shadow_check", 1, ["雾散了一些。"], cast=["me"],
  check=[{"if": {"flag": ["saw_crane"]}, "to": "c1_shadow_look"}, {"to": "c1_end"}])
N("c1_shadow_look", 1, ["「看他身后。」", "你看向树影。那里站着一个没有脸的骨人。"],
  cast=["me", "bone"],
  choices=[
      C("fire", ["掷出火折子。", "点火。"], "c1_shadow", kw=["火", "烧", "掷", "点"]),
      C("ignore", ["装作没看见。", "快走。"], "c1_end", kw=["走", "装", "没看见", "跑"]),
  ],
  other=["骨人没有脸，但你知道它在看你。"])
N("c1_shadow", 1, ["火一燎，骨人发出了长老的声音：「……好弟子。」", "它散成一地碎骨。碎骨上刻着两个字：血骨。"],
  cast=["me"], fx={"layer": "c1_l3", "frag": "frag_fire", "set": ["saw_bone"]}, auto="c1_end")
N("c1_end", 1, ["第一章 · 完"], chapter_end=2)

# ============================== 第二章 · 药堂之夜 ==============================
N("c2_start", 2, ["药堂失窃，一颗续命丹不见了。", "周衡：昨夜谁到过药堂？", "所有人都看向你。你身上有药味。"],
  scene="yaotang", cast=["me", "zhou"], npc="zhou", hook=["frag_zhusha"],
  fx={"layer": "c2_l1", "m_if": [{"if": {"m": {"qi": [">=", 60]}}, "m": {"qing": 1}}]},
  choices=[
      C("deny", ["不是我。", "我没偷。", "给我一夜，我把贼找出来。"], "c2_night", kw=["不是", "没偷", "找", "冤"]),
      C("ledger", "「周主事，厉寒欠的账，也记在这本上吧？」", "c2_ledger", kw=["账", "厉寒", "朱砂", "欠"],
        req={"frag": "frag_zhusha"}),
  ],
  tease={"账": "周衡：（合上账本）账本不是给外门看的。"},
  other=["周衡：天亮之前找不出贼，就拿你抵。", "周衡：药堂只认账，不认嘴。"])

N("c2_ledger", 2, ["周衡的眼角跳了一下。", "他把账本翻给你看：厉寒名下，一行一行，写着「第N世 · 未偿」。",
                   "再往后翻一页，是你的名字。写了一百遍。"],
  cast=["me", "zhou"], fx={"frag": "frag_ledger", "set": ["saw_ledger"]}, auto="c2_night")

N("c2_night", 2, ["周衡：天亮之前找不出贼，就拿你抵命。", "你有一夜的时间。"],
  scene="yaotang", cast=["me"],
  choices=[
      C("lihan", ["去找厉寒。", "找师兄帮忙。"], "c2_lihan", kw=["厉寒", "师兄"], req={"noflag": ["v_lihan"]},
        fx={"set": ["v_lihan"]}),
      C("kitchen", ["去伙房帮忙。", "去伙房。"], "c2_kitchen", kw=["伙房", "哑巴", "帮忙"], req={"noflag": ["v_kitchen"]},
        fx={"set": ["v_kitchen"]}),
      C("garden", ["去药圃看看。", "去药圃。"], "c2_garden", kw=["药圃", "看看", "贼"], req={"noflag": ["v_garden"]},
        fx={"set": ["v_garden"]}),
      C("wait", ["回屋，等天亮。", "等天亮。"], "c2_dawn", kw=["等", "天亮", "睡"]),
  ])

N("c2_lihan", 2, ["你敲开了厉寒的门。"], cast=["me"],
  check=[{"if": {"flag": ["killed_lihan"]}, "to": "c2_lihan_dead"},
         {"if": {"flag": ["ally_lihan"]}, "to": "c2_lihan_yes"},
         {"if": {"flag": ["debt_talked"]}, "to": "c2_lihan_yes"},
         {"to": "c2_lihan_no"}])
N("c2_lihan_dead", 2, ["门后是空的。", "床铺叠得整整齐齐，像从来没人住过。"], cast=["me"], auto="c2_night")
N("c2_lihan_yes", 2, ["厉寒：放心。天亮我替你说话。"], cast=["me", "lihan"],
  fx={"m": {"qing": 1}, "set": ["lihan_vouch"]}, auto="c2_night")
N("c2_lihan_no", 2, ["厉寒：你偷没偷，关我什么事？", "门关上了。"], cast=["me", "lihan"], auto="c2_night")

N("c2_kitchen", 2, ["伙房的老哑巴在剁骨头。", "你帮他挑了一夜的水。他什么也没说，给你留了半个馒头。"],
  scene="yaotang", cast=["me", "mute"], fx={"m": {"qing": 1}}, auto="c2_night")

N("c2_garden", 2, ["药圃里，一个小药童蹲在地上，在埋什么东西。"],
  scene="garden", cast=["me", "xiaoman"],
  choices=[
      C("call", ["喊人：贼在这！", "叫周衡来。"], "c2_expose", kw=["喊", "抓", "贼", "周衡"]),
      C("near", ["悄悄走过去。", "蹲下来问她。"], "c2_xiaoman", kw=["过去", "问", "蹲", "你"]),
      C("leave", ["当没看见，走开。"], "c2_night", kw=["走", "没看见", "算了"]),
  ])

N("c2_xiaoman", 2, ["小药童吓得一抖。她手里攥着的，正是那颗续命丹。", "小满：……别说出去。求你。",
                    "小满：师父没有它，天亮就会散掉的。"],
  cast=["me", "xiaoman"], npc="xiaoman", fx={"layer": "c2_l2"},
  hook=["frag_crane", "frag_fire", "frag_paperdoll", "frag_hand"],
  tease={"纸": "小满：（把手缩进袖子）你、你看错了。", "长老": "小满：……我不认识什么长老。"},
  choices=[
      C("cover", ["我替你瞒着。", "快走，我什么都没看见。"], "c2_cover", kw=["瞒", "走", "没看见", "帮"]),
      C("hand", ["跟我去见周衡。", "对不住，我得活。"], "c2_expose", kw=["周衡", "交", "对不住", "活"]),
      C("paper", "「窗缝里那只纸鹤，是你折的吧？」", "c2_paper", kw=["纸鹤", "纸", "折"], req={"frag": "frag_crane"}),
      C("paper2", "「你师父……是不是会用骨头说话？」", "c2_paper", kw=["骨", "长老", "师父"], req={"frag": "frag_fire"}),
      C("paper3", "「长老腰间那个纸人，跟你长得一样。」", "c2_paper", kw=["纸人", "长老", "一样"], req={"frag": "frag_paperdoll"}),
      C("paper4", "（握住她的手）「……我们是不是见过？」", "c2_paper", kw=["手", "见过", "握"], req={"frag": "frag_hand"}),
  ],
  other=["小满：（攥紧了丹药，一句话也不说）"])

N("c2_cover", 2, ["小满跑了。跑出三步，又回头：", "小满：……下一世，我会记得你。"],
  cast=["me", "xiaoman"],
  fx={"m": {"qing": 2}, "set": ["saved_xiaoman"], "echo": ["saved_xiaoman"],
      "mem": [{"a": "xiaoman", "text": "那一世，他替我瞒了续命丹", "v": 2, "i": 5}]},
  auto="c2_night")

N("c2_paper", 2, ["小满低下头。她的手腕裂开一道缝——", "里面没有血，是一层一层叠起来的纸。",
                  "小满：我死了很多年了。爹爹把我折回来的。", "小满：续命丹续的不是他的命，是我的。",
                  "小满：……爹爹，就是血骨长老。"],
  cast=["me", "xiaoman"], fx={"layer": "c2_l3", "frag": "frag_paper", "set": ["knows_paper"]},
  choices=[
      C("cover", ["我替你瞒着。"], "c2_cover", kw=["瞒", "帮", "走"]),
      C("hand", ["……还是得交出去。"], "c2_expose", kw=["交", "周衡"]),
  ])

N("c2_expose", 2, ["你喊来了周衡。小满被拖走的时候，没有哭。", "周衡：好。你洗清了。"],
  cast=["me", "zhou", "xiaoman"],
  fx={"m": {"qing": -2}, "set": ["exposed_xiaoman"], "echo": ["exposed_xiaoman"],
      "mem": [{"a": "xiaoman", "text": "那一世，他把我交了出去", "v": -2, "i": 5}]},
  auto="c2_end")

N("c2_dawn", 2, ["天亮了。药堂前站满了人。"], scene="yaotang", cast=["me", "zhou"],
  check=[{"if": {"m": {"qing": [">=", 3]}}, "to": "c2_dawn_saved"}, {"to": "c2_death_dawn"}])
N("c2_dawn_saved", 2, ["伙房的哑巴、厉寒……一个个站出来替你作保。", "周衡盯着你看了很久，把账本合上了。",
                       "周衡：这次，算你人缘好。"],
  cast=["me", "zhou", "mute"], auto="c2_end")
N("c2_death_dawn", 2, ["没有一个人站出来。", "周衡在账本上划掉了你的名字。那一页，你的名字写了一百遍。"],
  cast=["me", "zhou"],
  death={"hint": "账本那一页……为什么你的名字写了那么多遍？", "frag": "frag_ledger"})
N("c2_end", 2, ["第二章 · 完"], chapter_end=3)

# ============================== 第三章 · 血骨擂台 ==============================
N("c3_start", 3, ["外门大比。血骨长老坐在高台上，像一截枯骨。", "长老：今年，只留一个。"],
  scene="arena", cast=["me", "elder"], npc="elder", fx={"layer": "c3_l1"},
  choices=[
      C("join", ["上台。", "报名。"], "c3_round1", kw=["上", "报名", "打"]),
      C("sick", ["装病。", "我肚子疼。"], "c3_sick", kw=["病", "疼", "装"]),
  ],
  other=["长老：（没有看你）下一个。"])
N("c3_sick", 3, ["你说你病了。长老看了你一眼。", "长老：病了，就上台去养。", "你被抬上了擂台。"],
  cast=["me", "elder"], fx={"m": {"ming": -2}}, auto="c3_final")
N("c3_round1", 3, ["第一轮，对面是个壮汉。"], cast=["me", "foe"],
  fx={"m_if": [{"if": {"m": {"qi": [">=", 60]}}, "m": {"ming": 1}}]},
  choices=[
      C("fair", ["正面打。", "堂堂正正地赢。"], "c3_final", kw=["正面", "打", "堂堂"], fx={"m": {"ming": 2}}),
      C("dirty", ["撒一把石灰。", "下黑手。"], "c3_final", kw=["石灰", "黑", "阴"], fx={"m": {"ming": 3}, "set": ["dirty"]}),
  ])
N("c3_final", 3, ["决赛。对面站着厉寒。", "长老：谁活着下来，谁进内门。"],
  scene="arena", cast=["me", "lihan", "elder"], npc="lihan",
  hook=["frag_fire"],
  tease={"火": "你摸了摸怀里——什么都没有。", "演": "厉寒：（冷笑）演？你当我是戏子？"},
  choices=[
      C("fight", ["动手。", "拔刀。"], "c3_fight", kw=["动手", "刀", "杀", "打"]),
      C("drop", ["把刀扔在地上。", "我不打。"], "c3_drop", kw=["扔", "不打", "放下"]),
      C("fake", ["（使个眼色）演一场。", "我们演一场给他看。"], "c3_fake", kw=["演", "眼色", "假"],
        req={"flag": ["ally_lihan"]}),
      C("fire", "（摸出火折子，朝高台扬了扬）", "c3_fire", kw=["火", "火折子", "烧"], req={"frag": "frag_fire"}),
      C("fire2", "（摸出后山剩下的火折子）", "c3_fire", kw=["火", "火折子", "烧"], req={"flag": ["saw_bone"]}),
  ],
  other=["厉寒：（压低声音）师弟，别怪我。"])

N("c3_fight", 3, ["刀光一闪。"], cast=["me", "lihan", "elder"],
  battle={"kind": "duel", "foes": 0, "allies": [], "rival": "lihan",
          "outcomes": [{"to": "c3_kill", "tactics": ["assist"]}]})
N("c3_kill", 3, ["厉寒倒在你脚下。", "他的左腕翻了过来——上面密密麻麻，刻了九十九道痕。"],
  cast=["me", "elder"],
  fx={"m": {"ming": 3}, "frag": "frag_kehen", "set": ["killed_lihan3"],
      "mem": [{"a": "lihan", "text": "那一世，你在擂台上杀了我", "v": -2, "i": 5}]},
  auto="c3_judge")
N("c3_judge", 3, ["长老缓缓站了起来。"], cast=["me", "elder"],
  check=[{"if": {"m": {"ming": [">=", 5]}}, "to": "c3_inner"}, {"to": "c3_death_weak"}])
N("c3_inner", 3, ["长老：好。从今日起，你是内门。", "他腰间挂着的一个小纸人，晃了一下。"],
  cast=["me", "elder"], fx={"set": ["inner"]}, auto="c3_end")
N("c3_death_weak", 3, ["长老：名不副实。", "他抬手的时候，另一只手护住了腰间的小纸人。"],
  cast=["me", "elder"],
  death={"hint": "他出手时，为什么要护着腰间那个纸人？", "frag": "frag_paperdoll"})
N("c3_drop", 3, ["你把刀扔在了地上。", "长老：……魔门，不养废物。"], cast=["me", "elder"],
  auto="c3_death_elder")
N("c3_death_elder", 3, ["血骨从地底钻出来。长老出手的时候，一直护着腰间的小纸人。"],
  cast=["me", "elder"],
  death={"hint": "他出手时，为什么要护着腰间那个纸人？", "frag": "frag_paperdoll"})

N("c3_fire", 3, ["你擦亮了火折子。", "长老整个人弹了起来——不是护自己，是护腰间的一个小纸人。",
                 "长老：……你从哪知道的？！", "满场死寂。"],
  cast=["me", "lihan", "elder"], npc="elder",
  fx={"layer": "c3_l2", "frag": "frag_paperdoll", "m": {"ming": 3}},
  choices=[
      C("threat", ["拿纸人要挟他。", "放了厉寒，不然我烧了它。"], "c3_threat", kw=["要挟", "烧", "放"]),
      C("put", ["收起火折子。", "弟子失手。"], "c3_put", kw=["收", "失手", "算了"]),
  ],
  other=["长老：（死死盯着你手里的火）"])
N("c3_threat", 3, ["长老：好……好。今年，两个都留。", "他看你的眼神，像看一个死人。"],
  cast=["me", "lihan", "elder"], fx={"set": ["elder_grudge", "lihan_lives"],
                                   "mem": [{"a": "elder", "text": "他拿小满要挟我", "v": -2, "i": 5}]},
  auto="c3_end")
N("c3_put", 3, ["你收起火折子，跪下了。", "长老沉默了很久。", "长老：……你欠本座一条命。本座，也欠你一次。"],
  cast=["me", "elder"], fx={"set": ["elder_owes", "lihan_lives"],
                            "mem": [{"a": "elder", "text": "他看见了小满，却没有烧", "v": 1, "i": 4}]},
  auto="c3_end")

N("c3_fake", 3, ["你们打得很难看，谁也没下死手。", "擂台开始发烫。石缝里亮起血光——台下，是一口炉子。",
                 "厉寒（低声）：每一世都得有一个人死在这儿，炉子才会满。", "厉寒：今年，我们让它空着。"],
  cast=["me", "lihan", "elder"],
  fx={"layer": "c3_l3", "frag": "frag_furnace", "set": ["furnace_starved", "lihan_lives"], "m": {"ming": -1}},
  auto="c3_end")
N("c3_end", 3, ["第三章 · 完"], chapter_end=4)

# ============================== 第四章 · 正道来客 ==============================
N("c4_start", 4, ["山门外来了个女剑修，自称散修，要拜入魔门。", "长老（传音）：她是正道的人。盯住她，找到证据，杀了。"],
  scene="gate", cast=["me", "suqing"], fx={"layer": "c4_l1"}, auto="c4_meet")
N("c4_meet", 4, ["苏清：你就是那个……死不掉的外门弟子？"],
  cast=["me", "suqing"], npc="suqing",
  choices=[
      C("probe", ["套她的话。", "师姐从哪里来？"], "c4_probe", kw=["哪", "来", "套", "问"], fx={"m": {"wei": 1}}),
      C("seize", ["直接拔刀。", "拿下她。"], "c4_capture", kw=["刀", "拿", "抓"]),
      C("truth", ["说实话：长老让我盯着你。", "长老知道你是谁。"], "c4_truth", kw=["实话", "长老", "知道", "盯"],
        fx={"m": {"wei": -2}}),
  ],
  other=["苏清：（手按在剑上）有话直说。"])
N("c4_truth", 4, ["苏清愣了一下，笑了。", "苏清：魔门里，你是头一个跟我说实话的。"],
  cast=["me", "suqing"], fx={"set": ["honest_suqing"], "mem": [{"a": "suqing", "text": "他跟我说了实话", "v": 2, "i": 4}]},
  auto="c4_probe")
N("c4_probe", 4, ["苏清：我来找一样东西。", "苏清：一口炉子。"],
  cast=["me", "suqing"], npc="suqing", hook=["frag_furnace", "frag_ledger"],
  tease={"炉": "苏清：你知道？那你说，炉子在哪？", "账": "苏清：账？什么账？"},
  choices=[
      C("report", ["去报告长老。", "师姐稍等。（转身去找长老）"], "c4_capture", kw=["报告", "长老", "告"], fx={"m": {"wei": 1}}),
      C("cover", ["我帮你找。", "我替你遮掩。"], "c4_cover", kw=["帮", "遮", "找"], fx={"m": {"wei": -1}}),
      C("record", "「擂台下面那口？」", "c4_record", kw=["擂台", "炉", "下面"], req={"frag": "frag_furnace"}),
      C("record2", "「你找的，是写满「第N世」的那本账？」", "c4_record", kw=["账", "第N世", "一百遍"], req={"frag": "frag_ledger"}),
  ],
  other=["苏清：（打量你）你到底站哪边？"])
N("c4_record", 4, ["苏清展开一卷正道密录：", "「百世炉，以一人百世之魔元为薪。薪者，须自愿。」",
                   "苏清：自愿。听懂了吗？有人自己走进了那口炉子，一百次。"],
  cast=["me", "suqing"], fx={"layer": "c4_l2", "frag": "frag_voluntary", "m": {"wei": -1}},
  choices=[
      C("cover", ["我帮你。"], "c4_cover", kw=["帮", "一起"]),
      C("report", ["……我得去见长老。"], "c4_capture", kw=["长老", "报告"]),
  ])
N("c4_cover", 4, ["你带她绕开了巡山弟子。", "身后，长老的血骨傀儡一直跟着。"],
  cast=["me", "suqing", "bone"], fx={"set": ["helped_suqing"]},
  check=[{"if": {"m": {"wei": [">=", 2]}}, "to": "c4_escape"}, {"to": "c4_death_exposed"}])
N("c4_escape", 4, ["你把苏清送出了山门。没有人起疑。", "苏清：血月那晚，我会回来。"],
  cast=["me", "suqing"],
  fx={"set": ["suqing_ally"], "mem": [{"a": "suqing", "text": "他送我出了山门", "v": 2, "i": 5}]},
  auto="c4_end")
N("c4_death_exposed", 4, ["骨人拦在山门前，发出长老的声音：", "「伪装得不错。可惜，本座盯了你一百世。」",
                          "苏清的剑穗在你眼前一晃。"],
  cast=["me", "suqing", "bone"],
  death={"hint": "她剑穗上的纹路……你在哪里见过？", "frag": "frag_tassel"})
N("c4_capture", 4, ["你拿下了苏清。", "她被押走时，剑穗扫过你的手背——上面绣着一道魔纹。"],
  cast=["me", "suqing"],
  fx={"m": {"wei": 2}, "frag": "frag_tassel", "set": ["captured_suqing"],
      "mem": [{"a": "suqing", "text": "他把我交给了长老", "v": -2, "i": 5}]},
  auto="c4_end")
N("c4_end", 4, ["第四章 · 完"], chapter_end=5)

# ============================== 第五章 · 血月祭 ==============================
YI = [{"if": {"flag": ["ally_lihan"]}, "m": {"yi": 1}},
      {"if": {"flag": ["lihan_lives"], "noflag": ["ally_lihan"]}, "m": {"yi": 1}},
      {"if": {"flag": ["saved_xiaoman"]}, "m": {"yi": 1}},
      {"if": {"flag": ["suqing_ally"]}, "m": {"yi": 1}},
      {"if": {"flag": ["elder_owes"]}, "m": {"yi": 1}},
      {"if": {"flag": ["lihan_vouch"]}, "m": {"yi": 1}}]
N("c5_start", 5, ["血月升起。你被绑在祭坛中央。", "长老：第一百世。薪，够了。"],
  scene="altar", cast=["me", "elder"], fx={"layer": "c5_l1", "m_if": YI}, auto="c5_hub")
N("c5_hub", 5, ["炉火映红了长老的脸。"],
  scene="altar", cast=["me", "elder"], npc="elder",
  hook=["frag_paper", "frag_paperdoll", "frag_kehen", "frag_99", "frag_tassel", "frag_voluntary", "frag_first"],
  tease={"小满": "长老：（手一顿）……住口。", "自愿": "长老：自愿？薪柴也配谈自愿？", "纸": "长老：（把腰间的纸人按紧了）"},
  choices=[
      C("struggle", ["挣断绳子。", "拼了。"], "c5_battle", kw=["挣", "拼", "打", "逃"]),
      C("give", ["认命。", "闭上眼。"], "c5_death_give", kw=["认命", "算了", "闭眼"]),
      C("xm", "「你烧了一百世，是为了小满吧？」", "c5_xiaoman", kw=["小满", "女儿", "纸人"],
        req={"frag": "frag_paper", "noflag": ["c5_xm"]}),
      C("xm2", "「你腰间那个纸人，是小满。」", "c5_xiaoman", kw=["纸人", "小满", "腰"],
        req={"frag": "frag_paperdoll", "noflag": ["c5_xm"]}),
      C("lh", "（朝人群喊）「厉寒！他答应放你走，是骗你的！」", "c5_lihan", kw=["厉寒", "骗", "放你走"],
        req={"frag": "frag_kehen", "noflag": ["c5_lh"]}),
      C("lh2", "（朝人群喊）「厉寒！第九十九次了，你还信他？」", "c5_lihan", kw=["厉寒", "九十九", "信"],
        req={"frag": "frag_99", "noflag": ["c5_lh"]}),
      C("sq", "「苏清，你剑穗上的魔纹，和这炉子一模一样。」", "c5_suqing", kw=["苏清", "剑穗", "魔纹", "正道"],
        req={"frag": "frag_tassel", "noflag": ["c5_sq"]}),
      C("truth", "「薪者须自愿……第一个走进炉子的，是谁？」", "c5_truth", kw=["自愿", "第一个", "谁"],
        req={"frag": "frag_voluntary", "flag": ["c5_xm"], "noflag": ["c5_truth"]}),
      C("truth2", "「……哥哥回来了，小满。」", "c5_truth", kw=["哥哥", "第一世"],
        req={"frag": "frag_first", "noflag": ["c5_truth"]}),
  ],
  other=["长老：到了这一步，还有什么好说的。", "炉火又旺了一些。"])
N("c5_xiaoman", 5, ["长老的手停住了。", "长老：……你怎么知道她的名字。",
                    "长老：她死的那年九岁。我折了她一百次，每一次都散。", "长老：炉子烧满一百世，她就能真的活。"],
  cast=["me", "elder"], fx={"layer": "c5_l2", "set": ["c5_xm"]}, auto="c5_hub")
N("c5_lihan", 5, ["人群里，厉寒停下了脚步。", "厉寒：……放我走？这句话，他跟我说了九十九次。", "厉寒拔出了刀——对着长老。"],
  cast=["me", "elder", "lihan"], fx={"layer": "c5_l3", "set": ["c5_lh"], "m": {"yi": 1}}, auto="c5_hub")
N("c5_suqing", 5, ["祭坛外，一柄剑停在了半空。", "苏清：……正道要的从来不是毁掉它。是拿走它。",
                   "苏清：可我，不想再当谁的薪了。"],
  cast=["me", "elder", "suqing"], fx={"layer": "c5_l4", "set": ["c5_sq"], "m": {"yi": 1}}, auto="c5_hub")
N("c5_truth", 5, ["你想起来了。不是碎片，是全部。", "第一世，你是小满的哥哥。", "是你求长老造了这口炉。",
                  "是你，第一个走了进去。", "长老：……你终于记起来了。徒儿。"],
  cast=["me", "elder"], fx={"layer": "c5_l5", "frag": "frag_first", "set": ["c5_truth"]}, auto="c5_hub")
N("c5_battle", 5, ["你挣断了绳子。血骨从祭坛四面涌上来。"],
  cast=["me", "elder"],
  battle={"kind": "ritual", "foes": 5, "allies": ["remembered"],
          "outcomes": [{"if": {"m": {"yi": [">=", 3]}}, "to": "c5_rescued", "tactics": ["guard"]},
                       {"to": "c5_death_ritual", "tactics": ["idle"]}]})
N("c5_death_ritual", 5, ["没有人来。", "炉火吞没你之前，你看见长老从怀里掏出一个纸人，贴在了炉壁上。"],
  cast=["me", "elder"],
  death={"hint": "那个纸人……长老为什么要把它贴在炉上？", "frag": "frag_paperdoll"})
N("c5_death_give", 5, ["你闭上了眼睛。", "炉火很暖，像很久很久以前，有人牵着你的手。"],
  cast=["me", "elder"],
  death={"hint": "很久以前牵着你的那只手……是谁？", "frag": "frag_hand"})
N("c5_rescued", 5, ["记得你的人，一个接一个冲上了祭坛。", "长老跪在炉前：……还差一点。小满就能回来了。"],
  cast=["me", "elder", "lihan", "xiaoman", "suqing"], npc="elder",
  fx={"m_if": [{"if": {"m": {"qi": [">=", 100]}}, "m": {"yi": 1}}]},
  choices=[
      C("kill", ["杀了长老。", "结束这一切。"], "e_master_n", kw=["杀", "结束"]),
      C("sword", ["让苏清来处置炉子。"], "e_sword_n", kw=["苏清", "正道", "处置"],
        req={"flag": ["suqing_ally"], "noflag": ["c5_sq"]}),
      C("self", ["走进炉子，让小满回来。"], "e_xiaoman_n", kw=["炉", "小满", "走进"], req={"flag": ["c5_xm"]}),
      C("burn", ["按住炉火，把它熄灭。", "我点的火，我来灭。"], "e_true_n", kw=["熄", "灭", "按"],
        req={"flag": ["c5_truth"]}),
  ],
  other=["长老：（抱着纸人，一动不动）"])

N("e_master_n", 5, ["长老倒下了。炉火还在烧。", "你坐上了他的位置。", "台下的外门弟子里，有一个人，左腕刻着一道新痕。"],
  cast=["me"], ending="e_master")
N("e_sword_n", 5, ["苏清一剑斩断了锁链。", "然后，她把剑指向了你。", "苏清：对不住。炉子，正道要了。"],
  cast=["me", "suqing"], ending="e_sword")
N("e_xiaoman_n", 5, ["你走进了炉子。第一百零一次。", "小满睁开了眼睛。", "她不记得你。"],
  cast=["xiaoman", "elder"], ending="e_xiaoman")
N("e_true_n", 5, ["你把手按进炉火。这一次，是你自己把它熄灭的。", "小满变成一只纸鹤，停在长老肩上。",
                  "厉寒的左腕上，第一百道刻痕，没有出现。"],
  cast=["me", "elder", "lihan", "xiaoman", "suqing"], ending="e_true")


def validate():
    ids = set(NODES)
    layers = {l["id"] for c in CHAPTERS for l in c["layers"]}
    for n in NODES.values():
        for c in n.get("choices", []):
            assert c["to"] in ids, (n["id"], c["to"])
            if "frag" in c.get("req", {}):
                assert c["req"]["frag"] in FRAGS
                assert c["req"]["frag"] in n.get("hook", []), (n["id"], c["id"], "frag 选项必须在 hook 里")
        for k in ("auto",):
            if k in n:
                assert n[k] in ids, (n["id"], n[k])
        for r in n.get("check", []) + n.get("battle", {}).get("outcomes", []):
            assert r["to"] in ids, (n["id"], r["to"])
        fx = n.get("fx", {})
        if "frag" in fx:
            assert fx["frag"] in FRAGS
        if "layer" in fx:
            assert fx["layer"] in layers
        if "death" in n:
            assert n["death"]["frag"] in FRAGS
        for h in n.get("hook", []):
            assert h in FRAGS, (n["id"], h)
        if "ending" in n:
            assert n["ending"] in ENDINGS
        exits = [k for k in ("choices", "auto", "check", "battle", "death", "chapter_end", "ending") if k in n]
        assert len(exits) == 1, (n["id"], exits)
    for c in CHAPTERS:
        assert 2 <= len(c["layers"]) <= 5
        assert c["start"] in ids


if __name__ == "__main__":
    validate()
    data = {"version": 2, "cast": CAST, "metrics": METRICS, "frags": FRAGS, "chapters": CHAPTERS,
            "endings": ENDINGS, "nodes": NODES}
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(f"story.json: {len(NODES)} 节点 · {len(CHAPTERS)} 章 · "
          f"{sum(len(c['layers']) for c in CHAPTERS)} 层冲突 · {len(FRAGS)} 记忆碎片 · {len(ENDINGS)} 结局")
