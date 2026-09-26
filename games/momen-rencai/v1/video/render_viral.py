"""Render the 9:16 viral video for 魔门人材 from data/viral_script.json.

Pixel canvas 270x480 -> nearest-neighbour x4 -> 1080x1920 (TikTok/抖音).
The SAME beat script drives the in-game 新手引导 (scripts/tutorial.gd), so the
tutorial reproduces this video beat for beat.
"""
import json, math, random, subprocess, sys, wave
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
S = json.loads((ROOT / "data/viral_script.json").read_text())
W, H = S["canvas"]
FPS = S["fps"]
DUR = S["duration"]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "video/momen_viral_9x16.mp4"

FONT = str(ROOT / "assets/fonts/pixel.ttf")
F12 = ImageFont.truetype(FONT, 12)
SHEET = Image.open(ROOT / "assets/sprites/dungeon.png").convert("RGBA")

# GBA-ish palette
INK = (20, 16, 28)
BG = (26, 20, 38)
PANEL = (44, 34, 62)
GOLD = (255, 214, 92)
BLOOD = (226, 52, 64)
JADE = (92, 232, 196)
WHITE = (244, 240, 230)
DIM = (150, 140, 170)


def tile(i):
    x, y = (i % 12) * 16, (i // 12) * 16
    return SHEET.crop((x, y, x + 16, y + 16))


HERO, SENIOR, ELDER = tile(88), tile(111), tile(84)
ENEMIES = [tile(i) for i in (108, 120, 121, 122, 110)]
PILL = tile(115)
FLOOR = [tile(i) for i in (48, 49, 50, 51)]
WALL = tile(40)
TORCH = tile(29)

# ---------- text helpers ----------

def text_img(s, color, scale=1, outline=INK):
    lines = s.split("\n")
    bw = max(int(F12.getlength(l)) for l in lines) + 2
    bh = 13 * len(lines) + 2
    im = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.fontmode = "1"
    for n, l in enumerate(lines):
        lw = int(F12.getlength(l))
        x = (bw - lw) // 2
        y = n * 13
        for dx, dy in ((-1, 0), (1, 0), (0, -1), (0, 1), (1, 1)):
            d.text((x + 1 + dx, y + 1 + dy - 1), l, font=F12, fill=outline)
        d.text((x + 1, y), l, font=F12, fill=color)
    if scale != 1:
        im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
    return im


def paste_center(canvas, im, cx, y):
    canvas.alpha_composite(im, (int(cx - im.width / 2), int(y)))


def bubble(canvas, text, cx, y, border=WHITE, fill=(250, 246, 236), color=INK):
    t = Image.new("RGBA", (1, 1))
    lw = int(F12.getlength(text))
    bw, bh = lw + 10, 17
    x0 = int(max(4, min(W - bw - 4, cx - bw / 2)))
    d = ImageDraw.Draw(canvas)
    d.rectangle((x0, y, x0 + bw, y + bh), fill=fill, outline=INK)
    d.polygon([(cx - 3, y + bh), (cx + 3, y + bh), (cx, y + bh + 5)], fill=fill, outline=INK)
    d.fontmode = "1"
    d.text((x0 + 5, y + 2), text, font=F12, fill=color)


def fmt(n):
    if n >= 1e24:
        e = int(math.floor(math.log10(n)))
        sup = str(e).translate(str.maketrans("0123456789", "⁰¹²³⁴⁵⁶⁷⁸⁹"))
        return f"{n / 10 ** e:.2f}×10{sup}"
    for v, u in ((1e20, "垓"), (1e16, "京"), (1e12, "兆")):
        if n >= v:
            return f"{n/v:.1f}{u}" if u != "兆" else f"{n/v:.2f}{u}"
    if n >= 1e8:
        return f"{n/1e8:.2f}亿"
    if n >= 1e4:
        return f"{n/1e4:.1f}万"
    if n >= 100:
        return str(int(n))
    return f"{n:.1f}"   # 与 GS.fmt 完全一致

# ---------- world (135x105 world px, drawn x2 into arena at y=44) ----------
AW, AH = 135, 105
AY = 44
random.seed(7)
FLOOR_MAP = [[random.choice(FLOOR) for _ in range(9)] for _ in range(7)]


def world_base():
    w = Image.new("RGBA", (AW, AH), BG)
    for ty in range(7):
        for tx in range(9):
            w.alpha_composite(FLOOR_MAP[ty][tx], (tx * 16 - 4, ty * 16 + 6))
    for tx in range(9):
        w.alpha_composite(WALL, (tx * 16 - 4, -8))
    w.alpha_composite(TORCH, (20, -2))
    w.alpha_composite(TORCH, (100, -2))
    return w


BASE = world_base()


def beat_at(t):
    for b in S["beats"]:
        if b["t0"] <= t < b["t1"]:
            return b
    return S["beats"][-1]


BEAT = {b["id"]: b for b in S["beats"]}


def act_time(beat_id, prefix):
    for a in BEAT[beat_id]["actions"]:
        if a.startswith(prefix) and "@" in a:
            return float(a.rsplit("@", 1)[1])
    return BEAT[beat_id]["t0"]


T_BETRAY = act_time("betray", "npc_betray")
T_DODGE = act_time("betray", "hero_dodge")
T_SWAP = act_time("betray", "caption_swap")
T_COUNTER = act_time("betray", "counter_hit")
T_BREAK = BEAT["breakthrough"]["t0"]
T_LEDGER = BEAT["paperclips"]["t0"]
L = BEAT["paperclips"]["ledger"]
LY = S["ledger_layout"]


def hexc(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def ledger_state(r):
    """Paperclips 段在 r 秒时的全部状态（游戏 director 用同一套公式）"""
    taps = sum(1 for x in L["taps"] if r >= x)
    if r < 1.2:
        qi = float(taps)
    else:
        qi = 4 + 10 ** ((r - 1.2) * 4.6)
    rate = 0.0 if r < 1.2 else qi * 1.06
    seeds = 0.0 if r < 2.4 else 2 ** ((r - 2.4) * 14)
    rows = [(n, v) for (at, n, v) in L["rows"] if r >= at]
    phases = [(n, max(0.0, min(1.0, (r - a) / (b - a)))) for (n, a, b) in L["phases"] if r >= L["rows"][-1][0]]
    log = [txt for (at, txt) in L["log"] if r >= at][-LY["log_n"]:]
    pressed = any(0 <= r - x < 0.12 for x in L["taps"])
    return dict(qi=qi, rate=rate, seeds=seeds, rows=rows, phases=phases, log=log, pressed=pressed)


def draw_ledger(cv, t):
    r = t - T_LEDGER
    st = ledger_state(r)
    paper, ink, dim, acc, track = (hexc(LY[k]) for k in ("paper", "ink", "dim", "accent", "track"))
    d = ImageDraw.Draw(cv)
    d.fontmode = "1"
    d.rectangle((0, 0, W, H), fill=paper)
    cv.alpha_composite(text_img("魔元：" + fmt(st["qi"]), ink, 2, outline=paper), tuple(LY["qi"]))
    d.text(tuple(LY["rate"]), "每秒 " + fmt(st["rate"]), font=F12, fill=dim)
    if st["seeds"] > 0:
        d.text(tuple(LY["seeds"]), "魔种 " + fmt(st["seeds"]), font=F12, fill=ink)
    bx, by, bw, bh = LY["button"]
    d.rectangle((bx, by, bx + bw, by + bh), fill=ink if st["pressed"] else paper, outline=ink)
    d.text((bx + 16, by + 2), "吐 纳", font=F12, fill=paper if st["pressed"] else ink)
    if r < 1.3:
        cx, cy = bx + bw - 10, by + bh - 4 + (1 if st["pressed"] else 0)
        d.polygon([(cx, cy), (cx, cy + 10), (cx + 3, cy + 7), (cx + 7, cy + 7)], fill=ink, outline=paper)
    if st["rows"]:
        d.text(tuple(LY["rows_hdr"]), "—— 功 法 ——", font=F12, fill=dim)
        for i, (n, v) in enumerate(st["rows"]):
            y = LY["rows_y"] + i * LY["row_h"]
            d.text((LY["rows_hdr"][0], y), n, font=F12, fill=ink)
            vw = int(F12.getlength(v))
            d.text((W - 12 - vw, y), v, font=F12, fill=acc)
    if st["phases"]:
        d.text(tuple(LY["phases_hdr"]), "—— 炼 化 ——", font=F12, fill=dim)
        x0, x1, bhgt = LY["bar"]
        for i, (n, pr) in enumerate(st["phases"]):
            y = LY["phases_y"] + i * LY["phase_h"]
            d.text((LY["phases_hdr"][0], y), n, font=F12, fill=ink)
            d.rectangle((x0, y + 4, x1, y + 4 + bhgt), fill=track)
            if pr > 0:
                d.rectangle((x0, y + 4, x0 + int((x1 - x0) * pr), y + 4 + bhgt), fill=acc if pr < 1 else ink)
            pt = f"{pr * 100:.0f}%" if pr < 1 else "100%"
            d.text((W - 12 - int(F12.getlength(pt)), y), pt, font=F12, fill=ink)
    if st["log"]:
        d.text(tuple(LY["log_hdr"]), "—— 纪 事 ——", font=F12, fill=dim)
        for i, line in enumerate(st["log"]):
            y = LY["log_y"] + i * LY["log_h"]
            last = i == len(st["log"]) - 1
            d.text((LY["log_hdr"][0], y), line, font=F12, fill=ink if last else dim)
            if last and int(t * 3) % 2 == 0:
                lx = LY["log_hdr"][0] + int(F12.getlength(line)) + 2
                d.rectangle((lx, y + 2, lx + 5, y + 12), fill=ink)
    cap = BEAT["paperclips"]["caption"]
    for act in BEAT["paperclips"]["actions"]:
        if act.startswith("caption_swap:"):
            txt, at = act[len("caption_swap:"):].rsplit("@", 1)
            if t >= float(at):
                cap = txt
    ci = text_img(cap, ink, 2, outline=paper)
    paste_center(cv, ci, W / 2, LY["caption_y"])
    if r < 0.15:
        cv.alpha_composite(Image.new("RGBA", (W, H), (255, 255, 255, 200)))


def ease(x):
    x = max(0.0, min(1.0, x))
    return 1 - (1 - x) ** 3


def typed(s, t, t0, cps=14):
    n = int(max(0, (t - t0)) * cps)
    return s[:n]


def hud_qi(t):
    """HUD 魔元（Paperclips 段之前），游戏 director 同公式"""
    if t < T_BREAK:
        return 12 + t * 37
    return 12 + T_BREAK * 37 + (t - T_BREAK) * 10.8


def draw_frame(t):
    b = beat_at(t)
    cv = Image.new("RGBA", (W, H), BG)
    wd = BASE.copy()
    wdr = ImageDraw.Draw(wd)
    hx, hy = 60, 62
    shake = 0
    flash = None
    hero_visible = True
    hero_tint = None

    # ---- world events by beat ----
    if b["id"] == "hook":
        if t < 1.1:
            e = ease((t) / 1.0)
            ex = int(130 - 50 * e)
            wd.alpha_composite(ENEMIES[4], (ex, hy))
            wd.alpha_composite(HERO, (hx, hy))
        else:
            k = t - 1.1
            wd.alpha_composite(ENEMIES[4], (80, hy))
            if k < 0.15:
                wdr.line((hx - 4, hy - 4, hx + 20, hy + 20), fill=WHITE, width=2)
                flash = (255, 255, 255, 140)
            hero_visible = False
            g = HERO.rotate(90, expand=True)
            wd.alpha_composite(g, (hx, hy + 4))
            for i in range(10):
                a = i * 0.63
                r = 4 + k * 40
                px, py = hx + 8 + math.cos(a) * r, hy + 8 + math.sin(a) * r * 0.6 + k * k * 30
                wdr.rectangle((px, py, px + 1, py + 1), fill=BLOOD)
            if k < 0.4:
                shake = 3
    elif b["id"] == "memory":
        k = t - b["t0"]
        wd.alpha_composite(HERO, (hx, hy))
        for i in range(14):
            a = i / 14 * math.tau + k
            r = max(0, 70 * (1 - ease(k / 1.6 + (i % 3) * 0.05)))
            px, py = hx + 8 + math.cos(a) * r, hy + 8 + math.sin(a) * r
            wdr.rectangle((px - 1, py - 1, px + 1, py + 1), fill=JADE)
        if k > 1.4:
            glow = int(80 + 60 * math.sin(k * 12))
            wdr.ellipse((hx - 4, hy - 4, hx + 20, hy + 20), outline=(92, 232, 196, glow))
    elif b["id"] in ("agent", "betray"):
        k = t - 4.8
        sx = int(140 - 36 * ease(k / 0.8)) if b["id"] == "agent" else 104
        sy = hy
        # wave
        if b["id"] == "betray":
            kk = t - b["t0"]
            for i in range(6):
                ang = i / 6 * math.tau + kk * 0.6
                rad = max(18, 60 - kk * 14)
                ex, ey = hx + math.cos(ang) * rad, hy + math.sin(ang) * rad * 0.7
                dead = kk > 0.6 + i * 0.35
                if not dead:
                    wd.alpha_composite(ENEMIES[i % 4], (int(ex), int(ey)))
                elif kk < 0.9 + i * 0.35:
                    wdr.rectangle((ex + 4, ey + 4, ex + 12, ey + 12), outline=GOLD)
            # hero slashes
            if int(kk * 6) % 2 == 0 and t < T_BETRAY:
                wdr.arc((hx - 10, hy - 10, hx + 26, hy + 26), int(kk * 700) % 360, int(kk * 700) % 360 + 120, fill=WHITE, width=2)
            if t >= T_BETRAY:
                # betrayal: senior lunges
                lk = t - T_BETRAY
                sx = int(104 - min(1, lk / 0.3) * 30)
                if T_BETRAY <= t < T_BETRAY + 0.4:
                    flash = (226, 52, 64, 90)
                if t >= T_DODGE:
                    hx = int(60 - 22 * ease((t - T_DODGE) / 0.2))
                if T_COUNTER <= t < T_COUNTER + 0.3:
                    wdr.line((hx + 16, hy, sx + 8, sy + 16), fill=GOLD, width=3)
                    shake = 3
            st = SENIOR
            if t >= T_BETRAY:
                st = SENIOR.copy()
                r, g, bb, a = st.split()
                st = Image.merge("RGBA", (r.point(lambda v: min(255, v + 90)), g, bb, a))
            wd.alpha_composite(st, (sx, sy if t < T_COUNTER else sy + int(min(1, (t - T_COUNTER) * 4) * 10)))
        else:
            wd.alpha_composite(SENIOR, (sx, sy))
        wd.alpha_composite(HERO, (hx, hy))
    elif b["id"] == "breakthrough":
        k = t - b["t0"]
        bob = int(math.sin(t * 6) * 1)
        wd.alpha_composite(HERO, (hx, hy + bob))
        if True:
            r = int(k * 90)
            wdr.ellipse((hx + 8 - r, hy + 8 - r, hx + 8 + r, hy + 8 + r), outline=GOLD, width=2)
            if k < 0.35:
                flash = (255, 214, 92, 170)
            if 0.3 < k < 0.8:
                shake = 2
    elif b["id"] == "elder":
        k = t - b["t0"]
        ex = int(140 - 40 * ease(k / 0.5))
        wd.alpha_composite(ELDER, (ex, hy - 20))
        wd.alpha_composite(HERO, (hx, hy))
    elif b["id"] == "cta":
        wd.alpha_composite(HERO, (hx, hy))
        wd.alpha_composite(SENIOR, (hx + 34, hy + 10))
        wd.alpha_composite(ELDER, (hx + 34, hy - 18))

    arena = wd.resize((AW * 2, AH * 2), Image.NEAREST)
    ox = random.randint(-shake, shake) if shake else 0
    oy = random.randint(-shake, shake) if shake else 0
    cv.alpha_composite(arena, (ox, AY + oy))

    d = ImageDraw.Draw(cv)
    d.fontmode = "1"
    # ---- speech bubbles (screen space, above arena sprites) ----
    for act in b["actions"]:
        if act.startswith(("npc_say:", "hero_say:", "npc_think:")):
            parts = act.split(":")
            at = float(act.split("@")[1]) if "@" in act else b["t0"]
            txt = parts[-1].split("@")[0]
            if t < at:
                continue
            nxt = [a for a in b["actions"] if a.startswith(("npc_say:", "npc_think:")) and "@" in a and at < float(a.split("@")[1]) <= t]
            if act.startswith("npc_say") and nxt:
                continue
            shown = typed(txt, t, at)
            if act.startswith("npc_think"):
                bubble(cv, "记忆: " + shown, 190, AY + 100, fill=(210, 250, 240))
            elif act.startswith("hero_say"):
                bubble(cv, shown, 60 * 2 + 16, AY + 104)
            else:
                who = parts[1]
                cx = 230 if who == "senior" else 220
                yy = AY + 100 if who == "senior" else AY + 70
                bubble(cv, shown, cx, yy)

    # ---- HUD top bar ----
    d.rectangle((0, 0, W, 40), fill=INK)
    life = 99 if t < 3.0 else 100
    realm = "炼气" if t < T_BREAK + 0.2 else "金丹"
    d.text((8, 6), f"第 {life} 世", font=F12, fill=JADE if life == 100 else DIM)
    d.text((8, 22), f"境界 {realm}", font=F12, fill=GOLD if realm == "金丹" else WHITE)
    title = text_img(S["title"], GOLD)
    cv.alpha_composite(title, (W - title.width - 8, 6))
    mem_n = 0 if t < 2.2 else min(3, int((t - 2.2) * 3) + 1)
    d.text((W - 80, 22), f"记忆 {mem_n}/3", font=F12, fill=JADE)

    # ---- resource panel (Paperclips-style) ----
    py0 = AY + AH * 2 + 6  # 260
    d.rectangle((6, py0, W - 6, py0 + 40), fill=PANEL, outline=INK)
    qi = hud_qi(t)
    d.text((14, py0 + 5), "魔元", font=F12, fill=DIM)
    num = text_img(fmt(qi), GOLD, 1)
    cv.alpha_composite(num, (54, py0 + 5))
    rate = 1.2 if t < T_BREAK else 10.8
    d.text((W - 90, py0 + 5), f"+{fmt(rate)}/秒", font=F12, fill=JADE)

    # ---- memory cards (memory beat onward, left column) ----
    if t >= 2.6:
        cards = S["memory_cards"]
        for i, c in enumerate(cards):
            appear = 2.6 + i * 0.5
            if t < appear:
                continue
            slide = ease((t - appear) / 0.3)
            x = int(-130 + 136 * slide)
            y = py0 + 44 + i * 16
            hl = b["id"] == "betray" and i == 0 and t > T_BETRAY
            d.rectangle((x, y, x + 136, y + 14), fill=(24, 58, 60) if not hl else (90, 30, 40), outline=JADE if not hl else BLOOD)
            d.text((x + 4, y + 1), c["text"], font=F12, fill=WHITE)

    # ---- big caption ----
    cap = b["caption"]
    sub = b["sub"]
    for act in b["actions"]:
        if act.startswith("caption_swap:"):
            txt, at = act[len("caption_swap:"):].split("@")
            if t >= float(at):
                cap = txt
    if b["id"] == "cta":
        k = t - b["t0"]
        overlay = Image.new("RGBA", (W, H), (14, 10, 22, int(230 * ease(k / 0.4))))  # 与游戏 director._show_cta 的 0.9 一致
        cv.alpha_composite(overlay)
        tt = text_img(S["title"], GOLD, 4)
        paste_center(cv, tt, W / 2, 120 - int((1 - ease(k / 0.5)) * 40))
        paste_center(cv, text_img(S["tagline"], JADE, 2), W / 2, 190)
        paste_center(cv, text_img(cap, WHITE, 2), W / 2, 250)
        paste_center(cv, text_img(sub, DIM, 1), W / 2, 290)
        if k > 1.0:
            blink = int(k * 3) % 2 == 0
            paste_center(cv, text_img("▶ 新手引导 = 这条视频\n进游戏一键复刻", GOLD if blink else WHITE, 1), W / 2, 320)
        paste_center(cv, text_img(" ".join(S["hashtags"][:4]), DIM, 1), W / 2, 372)
    elif cap:
        k = t - b["t0"]
        pop = 2 if k > 0.12 else 3
        ci = text_img(cap, WHITE if b["id"] != "betray" or t < T_SWAP else JADE, pop)
        y = AY + 14
        paste_center(cv, ci, W / 2, y + (0 if k > 0.12 else -6))
        if sub:
            paste_center(cv, text_img(sub, GOLD, 1), W / 2, y + ci.height + 2)

    if b["id"] == "paperclips":
        cv = Image.new("RGBA", (W, H), BG)
        draw_ledger(cv, t)
        flash = None
    if flash:
        cv.alpha_composite(Image.new("RGBA", (W, H), flash))
    # progress bar (retention trick)
    d = ImageDraw.Draw(cv)
    d.rectangle((0, H - 3, int(W * t / DUR), H), fill=GOLD)
    return cv.convert("RGB")


# ---------- chiptune audio ----------
SR = 44100


def sq(freq, n, duty=0.5, vol=0.2):
    tt = np.arange(n) / SR
    return vol * np.where((tt * freq) % 1 < duty, 1.0, -1.0)


def env(n, a=0.005, r=0.08):
    e = np.ones(n)
    na, nr = int(a * SR), int(r * SR)
    if na:
        e[:na] = np.linspace(0, 1, na)
    if nr and nr < n:
        e[-nr:] = np.linspace(1, 0, nr)
    return e


def add(buf, sig, at):
    i = int(at * SR)
    j = min(len(buf), i + len(sig))
    if i < len(buf):
        buf[i:j] += sig[: j - i]


def noise(n, vol=0.3):
    return vol * (np.random.rand(n) * 2 - 1)


def build_audio(path):
    N = int(DUR * SR)
    buf = np.zeros(N)
    bpm = 150
    step = 60 / bpm / 2
    notes = [220, 261.6, 329.6, 392, 440, 392, 329.6, 261.6]  # A minor arpeggio
    bass = [110, 110, 87.3, 98]
    t = 0.0
    i = 0
    T_END_PC = T_LEDGER + L["phases"][-1][2]  # 三千世界炼化完毕
    while t < T_END_PC:
        if 1.1 < t < 2.2:
            t += step; i += 1; continue  # 死亡后的静默
        in_pc = t >= T_LEDGER
        f = notes[i % 8] * (2 if T_BREAK <= t < T_LEDGER else 1)
        n = int(step * SR * 0.9)
        if not in_pc:
            add(buf, sq(f, n, 0.25, 0.06) * env(n), t)
        if i % 2 == 0:
            bf = bass[(i // 8) % 4]
            add(buf, sq(bf, n * 2, 0.5, 0.08 if not in_pc else 0.05) * env(n * 2), t)
        if i % 4 == 0 and not in_pc:
            add(buf, noise(1800, 0.25) * np.linspace(1, 0, 1800), t)
        t += step
        i += 1
    # SFX
    add(buf, noise(int(0.5 * SR), 0.5) * np.linspace(1, 0, int(0.5 * SR)), 1.1)
    add(buf, sq(55, int(0.6 * SR), 0.5, 0.2) * np.linspace(1, 0, int(0.6 * SR)), 1.1)
    for k in range(12):
        n = int(0.07 * SR)
        add(buf, sq(660 * 2 ** (k / 12), n, 0.5, 0.07) * env(n), 2.3 + k * 0.1)
    speech = [act_time("agent", "npc_say"), act_time("agent", "npc_think"), act_time("elder", "npc_say"), act_time("elder", "hero_say")]
    for at in speech:
        for k in range(12):
            n = int(0.02 * SR)
            add(buf, sq(900 + (k % 3) * 120, n, 0.5, 0.04), at + k / 14)
    tt = BEAT["betray"]["t0"] + 0.3
    while tt < T_BETRAY:
        add(buf, noise(2000, 0.18) * np.linspace(1, 0, 2000), tt)
        tt += 0.25
    n = int(0.5 * SR)
    add(buf, (sq(233, n, 0.5, 0.12) + sq(247, n, 0.5, 0.12)) * env(n), T_BETRAY)
    add(buf, noise(4000, 0.4) * np.linspace(1, 0, 4000), T_COUNTER)
    for f in (523, 659, 784, 1046):
        n = int(1.4 * SR)
        add(buf, sq(f, n, 0.5, 0.06) * env(n, r=1.0), T_BREAK)
    # Paperclips 段：点击声 → 越来越密的计数 tick → 每个炼化阶段完成的钟声 → 结尾低频嗡鸣
    for x in L["taps"]:
        add(buf, noise(600, 0.3) * np.linspace(1, 0, 600), T_LEDGER + x)
    tt = T_LEDGER + L["rows"][0][0]
    k = 0
    while tt < T_END_PC:
        n = int(0.02 * SR)
        add(buf, sq(1200 + (k % 5) * 40, n, 0.5, 0.03) * env(n), tt)
        tt += max(0.025, 0.16 - k * 0.004)
        k += 1
    for (at, txt) in L["log"]:
        n = int(0.05 * SR)
        add(buf, sq(660, n, 0.5, 0.05) * env(n), T_LEDGER + at)
    for j, (_, a, b2) in enumerate(L["phases"]):
        n = int(0.6 * SR)
        add(buf, (sq(392 * 2 ** (j / 4), n, 0.5, 0.05) + sq(587 * 2 ** (j / 4), n, 0.5, 0.04)) * env(n, r=0.5), T_LEDGER + b2)
    n = int((BEAT["cta"]["t0"] - T_END_PC) * SR)
    tt_ = np.arange(n) / SR
    add(buf, 0.09 * np.sin(2 * np.pi * 55 * tt_) * np.linspace(1, 0.2, n), T_END_PC)
    for f in (440, 523, 659, 880):
        n = int(3.0 * SR)
        add(buf, sq(f, n, 0.5, 0.05) * env(n, r=2.2), BEAT["cta"]["t0"])
    buf = np.clip(buf, -1, 1)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((buf * 32000).astype(np.int16).tobytes())


def main():
    np.random.seed(1)
    wav = OUT.with_suffix(".wav")
    build_audio(wav)
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "rawvideo", "-pix_fmt", "rgb24", "-s", f"{W}x{H}", "-r", str(FPS), "-i", "-",
           "-i", str(wav), "-vf", "scale=1080:1920:flags=neighbor", "-c:v", "libx264", "-preset", "medium", "-crf", "18",
           "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "160k", "-shortest", "-movflags", "+faststart", str(OUT)]
    p = subprocess.Popen(cmd, stdin=subprocess.PIPE)
    frames = int(DUR * FPS)
    for f in range(frames):
        t = f / FPS
        p.stdin.write(draw_frame(t).tobytes())
    p.stdin.close()
    p.wait()
    wav.unlink()
    print("wrote", OUT)


if __name__ == "__main__":
    if len(sys.argv) > 2 and sys.argv[2] == "--stills":
        for t in [10.5, 11.4, 13.0, 16.0, 17.5, 18.8, 20.3, 21.8, 23.8, 26.0]:
            draw_frame(t).resize((W * 2, H * 2), Image.NEAREST).save(Path(sys.argv[1]) / f"still_{t:05.1f}.png")
    else:
        main()
