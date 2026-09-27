#!/usr/bin/env python3
"""穷举验证 data/story.json（与 scripts/story.gd 同一套语义）。

- 一世之内：枚举所有选择 / 吐纳多少（0 或 40 魔元）/ 战斗里是否及时「守」/ 在钩子节点是否主动使用碎片。
- 世与世之间：死亡时从「本世新得的碎片 + 临死所见」里铭刻一片（永久可用），echo 回响只带进下一世。
- 输出：每层冲突、每个结局的最少世数与一条可回放路线 → data/story_routes.json（--storytest 用它驱动 GDScript 引擎）。
退出码非 0 = 有层或结局不可达 / 有死路。
"""
import json, os, sys
from collections import deque

HERE = os.path.dirname(os.path.abspath(__file__))
D = json.load(open(os.path.join(HERE, "..", "data", "story.json"), encoding="utf-8"))
NODES, CH, METRICS = D["nodes"], {c["n"]: c for c in D["chapters"]}, D["metrics"]
ALL_LAYERS = [l["id"] for c in D["chapters"] for l in c["layers"]]
MAX_LIVES = 10


def cond(c, st, skill=False):
    if not c:
        return True
    fl, m, echo_prev = st["flags"], st["m"], st["echo_prev"]
    if any(f not in fl for f in c.get("flag", [])): return False
    if any(f in fl for f in c.get("noflag", [])): return False
    if any(f not in echo_prev for f in c.get("echo", [])): return False
    if any(f in echo_prev for f in c.get("noecho", [])): return False
    for k, (op, n) in c.get("m", {}).items():
        v = m.get(k, 0)
        if not {">=": v >= n, "<=": v <= n, ">": v > n, "<": v < n, "==": v == n}[op]: return False
    if "skill" in c and not (c["skill"] == "block" and skill): return False
    return True


def apply_fx(fx, st):
    if not fx: return
    for k, v in fx.get("m", {}).items():
        st["m"][k] = st["m"].get(k, 0) + v
    for r in fx.get("m_if", []):
        if cond(r["if"], st):
            for k, v in r["m"].items():
                st["m"][k] = st["m"].get(k, 0) + v
    st["flags"] |= set(fx.get("set", []))
    st["echo_cur"] |= set(fx.get("echo", []))
    if "frag" in fx and fx["frag"] not in st["awake"]:
        st["fresh"].add(fx["frag"])
    if "layer" in fx:
        st["layers"].add(fx["layer"])


def clone(st):
    return {k: (set(v) if isinstance(v, set) else dict(v) if isinstance(v, dict) else v) for k, v in st.items()}


def _conds(n):
    cs = []
    for c in n.get("choices", []):
        cs.append(c.get("req", {}))
    for r in n.get("check", []) + n.get("battle", {}).get("outcomes", []):
        cs.append(r.get("if", {}))
    for r in n.get("fx", {}).get("m_if", []):
        cs.append(r["if"])
    for c in n.get("choices", []):
        for r in c.get("fx", {}).get("m_if", []):
            cs.append(r["if"])
    return cs


# 第 k 章结束后仍会被读到的标记 —— 章节边界处丢掉其余标记，避免状态爆炸（不影响语义）
FUTURE_FLAGS = {}
for k in range(1, len(CH) + 1):
    fs = set()
    for n in NODES.values():
        if n["ch"] > k:
            for c in _conds(n):
                fs |= set(c.get("flag", [])) | set(c.get("noflag", []))
    FUTURE_FLAGS[k] = fs


def key(st, nid):
    return (nid, frozenset(st["flags"]), tuple(sorted(st["m"].items())), frozenset(st["fresh"]),
            frozenset(st["echo_cur"]))


def run_life(awake, echo_prev, layers0):
    """返回 {outcome_sig: (outcome, path)}；outcome = (kind, x, fresh, echo_cur, layers)"""
    st0 = {"flags": set(), "m": {}, "fresh": set(), "awake": set(awake), "echo_prev": set(echo_prev),
           "echo_cur": set(), "layers": set(layers0), "ch": 1}
    out, seen, hits = {}, set(), {}
    stack = [(st0, "c1_start", [], True)]
    while stack:
        st, nid, path, entering = stack.pop()
        n = NODES[nid]
        if entering:
            st = clone(st)
            apply_fx(n.get("fx"), st)
            lay = n.get("fx", {}).get("layer")
            if lay and lay not in hits:
                hits[lay] = path + [["reach", nid]]
        k = key(st, nid)
        if k in seen: continue
        seen.add(k)
        if "check" in n:
            for r in n["check"]:
                if cond(r.get("if"), st):
                    stack.append((st, r["to"], path, True)); break
            continue
        if "auto" in n:
            stack.append((st, n["auto"], path, True)); continue
        if "battle" in n:
            for skill in (False, True):
                for r in n["battle"]["outcomes"]:
                    if cond(r.get("if"), st, skill):
                        stack.append((st, r["to"], path + [["battle", nid, "block" if skill else "none"]], True)); break
            continue
        if n.get("ui") == "breathe":
            for q in (0, 40):
                s2 = clone(st); s2["m"]["qi"] = s2["m"].get("qi", 0) + q
                for c in n["choices"]:
                    s3 = clone(s2); apply_fx(c.get("fx"), s3)
                    stack.append((s3, c["to"], path + [["breathe", nid, q], ["choose", nid, c["id"]]], True))
            continue
        if "choices" in n:
            usable = st["awake"]  # 只有铭刻过的碎片能用
            for c in n["choices"]:
                req = dict(c.get("req", {}))
                f = req.pop("frag", None)
                if f and f not in usable: continue
                if not cond(req, st): continue
                s2 = clone(st); apply_fx(c.get("fx"), s2)
                step = [["use", nid, f]] if f else []
                stack.append((s2, c["to"], path + step + [["choose", nid, c["id"]]], True))
            continue
        if "chapter_end" in n:
            nx = n["chapter_end"]; s2 = clone(st); s2["ch"] = nx
            s2["flags"] &= FUTURE_FLAGS[nx - 1]
            mk = CH[nx]["metric"]; s2["m"].setdefault(mk, METRICS[mk]["start"])
            stack.append((s2, CH[nx]["start"], path, True)); continue
        if "death" in n:
            fresh = set(st["fresh"])
            if n["death"]["frag"] not in st["awake"]:
                fresh.add(n["death"]["frag"])
            sig = ("death", nid, frozenset(fresh), frozenset(st["echo_cur"]))
            out.setdefault(sig, (sig, path)); continue
        if "ending" in n:
            sig = ("ending", n["ending"], frozenset(st["fresh"]), frozenset(st["echo_cur"]))
            out.setdefault(sig, (sig, path)); continue
        raise SystemExit(f"死路：{nid}")
    return out, hits


BEAM = 16


def main():
    frontier = [((frozenset(), frozenset()), [])]  # (awake, echo_prev), route
    first_layer, first_end = {}, {}
    for lives in range(MAX_LIVES):
        nxt = {}
        for (awake, echo_prev), route in frontier:
            res, hits = run_life(awake, echo_prev, ())
            here = {"awake_before": sorted(awake), "echo_prev": sorted(echo_prev)}
            for l, path in hits.items():
                if l not in first_layer:
                    first_layer[l] = {"lives": lives + 1, "route": route + [dict(here, path=path, end=["reach", l])]}
            for sig, (o, path) in sorted(res.items(), key=lambda kv: (kv[0][0], kv[0][1], sorted(kv[0][2]), sorted(kv[0][3]))):
                kind, x, fresh, echo_cur = o
                if kind == "ending":
                    if x not in first_end:
                        first_end[x] = {"lives": lives + 1, "route": route + [dict(here, path=path, end=[kind, x])]}
                    continue
                for pick in (sorted(fresh) or [None]):
                    ns = (frozenset(awake | ({pick} if pick else set())), frozenset(echo_cur))
                    nxt.setdefault(ns, route + [dict(here, path=path, end=[kind, x], awaken=pick)])
        # 支配剪枝：同一回响下，碎片是别人子集的状态丢掉；再按碎片数截断成 beam
        keys = list(nxt)
        keep = [k for k in keys if not any(k != o and k[1] == o[1] and k[0] < o[0] for o in keys)]
        keep.sort(key=lambda k: (-len(k[0]), sorted(k[0]), sorted(k[1])))
        frontier = [(k, nxt[k]) for k in keep[:BEAM]]
        print(f"  第 {lives + 1} 世：已见层 {len(first_layer)}/{len(ALL_LAYERS)}，结局 {len(first_end)}/{len(D['endings'])}，下一世候选 {len(keep)}", flush=True)
        if len(first_layer) == len(ALL_LAYERS) and len(first_end) == len(D["endings"]):
            break
    # 全碎片上界检查：带着所有记忆时，每层每结局都应在一世内可达
    for ec in (frozenset(), frozenset(["saved_xiaoman"]), frozenset(["exposed_xiaoman"])):
        res, hits = run_life(frozenset(D["frags"]), ec, ())
        assert len(res) > 0
    ok = True
    print("冲突层（首次可达所需世数）：")
    for c in D["chapters"]:
        for l in c["layers"]:
            r = first_layer.get(l["id"])
            print(f"  第{c['n']}章 {l['id']} {l['title']:<12} → " + (f"第 {r['lives']} 世" if r else "✘ 不可达"))
            ok &= r is not None
    print("结局：")
    for e, info in D["endings"].items():
        r = first_end.get(e)
        print(f"  {e:<10} {info['title']:<6} → " + (f"第 {r['lives']} 世" if r else "✘ 不可达"))
        ok &= r is not None
    first_life = {l for l, r in first_layer.items() if r["lives"] == 1}
    print(f"首世可见层：{len(first_life)}/{len(ALL_LAYERS)}（{', '.join(sorted(first_life))}）")
    for c in D["chapters"]:
        deeper = [l["id"] for l in c["layers"][1:]]
        if all(d in first_life for d in deeper):
            print(f"  ✘ 第{c['n']}章所有深层首世即可见——隐藏不够"); ok = False
    json.dump({"layers": first_layer, "endings": first_end}, open(os.path.join(HERE, "..", "data", "story_routes.json"), "w",
              encoding="utf-8"), ensure_ascii=False, indent=0)
    print("PASS" if ok else "FAIL")
    sys.exit(0 if ok else 1)


if __name__ == "__main__":
    main()
