"""穷举 story.json 的所有走法：验证 8 个结局都可达，并给出每个结局的一条示例路线。
规则与 scripts/story.gd 一致：死亡授予记忆并回到本章开头（本章标记回滚，记忆保留）。"""
import json, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = json.loads((ROOT / "data/story.json").read_text())
NODES = {n["id"]: n for ch in S["chapters"] for n in ch["nodes"]}
CH_OF = {n["id"]: ch for ch in S["chapters"] for n in ch["nodes"]}


def val(state, k):
    if k == "mems":
        return len(state["mem"])
    return state["f"].get(k, S["flags"].get(k))


def cond_ok(state, c):
    k, op, v = c
    if op == "has":
        return v in state["mem"]
    x = val(state, k)
    return {"==": lambda: x == v, "!=": lambda: x != v, ">=": lambda: x >= v, "<=": lambda: x <= v,
            "<": lambda: x < v, ">": lambda: x > v, "in": lambda: x in v}[op]()


def all_ok(state, conds):
    return all(cond_ok(state, c) for c in conds or [])


def apply(state, sets):
    f = dict(state["f"]); mem = set(state["mem"])
    for k, v in (sets or {}).items():
        if k == "+mem":
            mem.add(v)
        elif isinstance(v, bool) or isinstance(v, str):
            f[k] = v
        else:
            f[k] = f.get(k, S["flags"].get(k, 0)) + v
    return {"f": f, "mem": frozenset(mem), "snap": state["snap"]}


# 只有出现在条件里的标记会影响可达性；其余（pills/trust/ruthless…）不进状态键，避免状态爆炸
COND_FLAGS = set()
for ch in S["chapters"]:
    for n in ch["nodes"]:
        for o in n.get("options", []):
            for c in o.get("req", []):
                COND_FLAGS.add(c[0])
            for conds, _ in o.get("next_if", []):
                for c in conds:
                    COND_FLAGS.add(c[0])


def norm(f):
    return tuple(sorted((k, v) for k, v in f.items() if k in COND_FLAGS))


def key(node, st):
    return (node, norm(st["f"]), st["mem"], norm(st["snap"]) if st["snap"] else None)


def explore():
    from collections import deque
    start = {"f": {}, "mem": frozenset(), "snap": {}}
    q = deque([("ch1_open", start)])
    parent = {key("ch1_open", start): (None, None)}
    found = {}
    while q:
        nid, st = q.popleft()
        k0 = key(nid, st)
        n = NODES[nid]
        if n is CH_OF[nid]["nodes"][0]:
            st = dict(st); st["snap"] = dict(st["f"])
        t = n["type"]
        succs = []
        if t == "ending":
            if nid not in found:
                steps = []
                k = k0
                while k is not None:
                    pk, label = parent[k]
                    steps.append(label)
                    k = pk
                found[nid] = [x for x in reversed(steps) if x] + [nid]
            continue
        if t == "scene":
            succs.append((n["next"], apply(st, n.get("set")), nid))
        elif t == "converge":
            succs.append((n["next"], st, nid))
        elif t == "battle":
            succs.append((n["win"], st, nid + ":胜"))
            if n["lose"] != n["win"]:
                succs.append((n["lose"], st, nid + ":败"))
        elif t == "ledger":
            for feed in (0, 20, 80):
                succs.append((n["next"], apply(st, {"seed_feed": feed}), f"{nid}:吐纳{feed}"))
        elif t == "death":
            rolled = {"f": dict(st["snap"]), "mem": st["mem"] | {n["grant"]}, "snap": st["snap"]}
            succs.append((n["rewind"], rolled, nid + "→" + n["grant"]))
        elif t == "choice":
            for i, o in enumerate(n["options"]):
                if not all_ok(st, o.get("req")):
                    continue
                st2 = apply(st, o.get("set"))
                nxt = o.get("next")
                for conds, alt in o.get("next_if", []):
                    if all_ok(st, conds):
                        nxt = alt
                        break
                succs.append((nxt, st2, f"{nid}#{i}:{o['label']}"))
            if n.get("timeout_next"):
                succs.append((n["timeout_next"], st, nid + ":超时"))
        for nx, s2, label in succs:
            k2 = key(nx, s2)
            if k2 not in parent:
                parent[k2] = (k0, label)
                q.append((nx, s2))
    return found


found = explore()
endings = [n["id"] for ch in S["chapters"] for n in ch["nodes"] if n["type"] == "ending"]
ok = True
for e in endings:
    if e in found:
        print(f"✔ {NODES[e]['title']:<8} 最短 {len(found[e])} 步")
    else:
        ok = False
        print(f"✘ {NODES[e]['title']} 不可达")
routes = {e: found[e] for e in found}
(ROOT / "data/story_routes.json").write_text(json.dumps(routes, ensure_ascii=False, indent=1))
sys.exit(0 if ok else 1)
