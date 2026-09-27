"""Generate momen.svml from the VO timing (assets/vo/timing.json) and the edit plan below.

Program time is authored (no Script / WhisperX): every VO line is an independent audio Item, and the
caption tokens reuse Edge-TTS word boundaries, so captions pop exactly on the spoken words.
"""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
T = json.load(open(os.path.join(ROOT, "assets/vo/timing.json")))
FPS = 30
END = 31.0

# VO line -> program start (seconds)
VO = {"l01": 0.15, "l02": 2.75, "l03": 5.55, "l04": 8.25, "l05": 10.55, "l06": 13.40,
      "l07": 15.75, "l08": 17.55, "l09": 19.45, "l10": 21.65, "l11": 25.30, "l12": 28.25}

# How spoken words are displayed: word -> (display text, emphasised)
DISPLAY = {"九十九": ("99", True), "一百": ("100", True), "九十九次": ("99次", True), "朱砂": ("朱砂", True),
           "师兄": ("师兄", True), "记忆": ("记忆", True), "AI": ("AI", True), "四": ("4", True), "第二": ("第2", True),
           "没有": ("没有", True), "下手": ("下手", True), "一件事": ("一件事", True), "第几": ("第几", True),
           "刀": ("刀", True), "第一百": ("第100", True), "四层": ("4层", True), "记得": ("记得", True)}

def wav_dur(name):
    import wave
    with wave.open(os.path.join(ROOT, f"assets/audio/{name}.wav")) as w:
        return int(w.getnframes() / w.getframerate() * FPS) / FPS

def fs(x):
    return f"{x:.3f}".rstrip("0").rstrip(".") + "s"

def phrase_breaks(line):
    """Character offsets (in spoken words, punctuation removed) where the script has a comma/colon."""
    import csv
    text = {r[0]: r[3] for r in csv.reader(open(os.path.join(ROOT, "assets/vo/lines.tsv")), delimiter="\t")}[line]
    out, n = set(), 0
    for ch in text:
        if ch in "，：。？！、":
            out.add(n)
        elif ch not in "…":
            n += 1
    return out

def cap_tokens(line, max_chars=10):
    """One caption phrase at a time: break at the script's punctuation, or when a phrase gets too wide."""
    words = T[line]["words"]
    breaks = phrase_breaks(line)
    toks, cur, spoken = [], 0, 0
    for start, _dur, w in words:
        if cur and spoken in breaks:
            toks.append("/"); cur = 0
        spoken += len(w)
        disp, em = DISPLAY.get(w, (w, False))
        if w == "第一百世": disp, em = "第100世", True
        width = sum(1 if ord(c) > 255 else 0.55 for c in disp)
        if cur and cur + width > max_chars:
            toks.append("/"); cur = 0
        toks.append(("*" if em else "") + disp + "@" + f"{max(0, start):.2f}")
        cur += width
    return "|".join(toks)

def per_char(text, t0, step):
    out, t = [], t0
    for ch in text:
        if ch == "/": out.append("/"); continue
        em = ch in "99"
        out.append(("*" if em else "") + ch + f"@{t:.2f}"); t += step
    return "|".join(out)

# footage: id, file, program start, window seconds, playback, sampling (zoom, x, y) start/end
# footage: id, png start frame (clean recording), program start, window s, playback, sampling (zoom,x,y) start/end
CLIPS = [
    # stage-fill framing: zoom z with y = 960 + 300 z puts the stage's bottom edge (source y 660) on the canvas bottom
    ("hook-battle", 12, 0.00, 1.60, "once-start", (2.2, 0, 1620), (2.35, 0, 1665)),
    ("hook-death", 68, 1.60, 1.15, "hold-start", (1.8, 0, 1090), (1.9, 0, 1150)),
    ("same-hill", 0, 2.75, 0.80, "once-start", (2.2, 0, 1620), (2.3, 0, 1650)),
    ("same-brother", 24, 3.55, 0.80, "once-start", (2.7, 260, 1770), (2.9, 280, 1830)),
    ("same-blade", 50, 4.35, 1.20, "hold-start", (2.7, 200, 1770), (3.2, 240, 1920)),
    ("engrave", 102, 5.45, 2.80, "hold-start", (1.0, 0, 0), (1.05, 0, 0)),
    ("meet", 192, 8.25, 2.30, "once-start", (1.0, 0, 0), (1.04, 0, 0)),
    ("recall", 270, 10.55, 2.85, "hold-start", (1.0, 0, 0), (1.05, 0, 0)),
    ("reply", 426, 13.40, 5.95, "hold-start", (1.0, 0, 0), (1.06, 0, 0)),
    ("spare", 570, 19.35, 5.95, "hold-start", (1.25, 0, 560), (1.35, 0, 600)),
    ("layer", 345, 25.30, 2.95, "hold-start", (1.25, 0, 420), (1.32, 0, 440)),
    ("end", 845, 28.25, 2.75, "hold-start", (1.0, 0, 260), (1.03, 0, 270)),
]
PNG_TOTAL = 964

SFX = [  # id, file, at, gain
    ("hit-hook", "chop", 0.05, 0.9), ("death-boom", "sfx_death", 1.55, 0.8),
    ("tick-97", "impactWood_light_002", 2.75, 0.9), ("tick-98", "impactWood_light_002", 3.62, 0.9),
    ("tick-99", "chop", 4.55, 1.0), ("blade-flash", "sfx_death", 4.9, 0.6),
    ("engrave", "sfx_awaken", 6.6, 0.7), ("century", "sfx_whoosh", 8.2, 0.8),
    ("recall", "sfx_reveal", 11.6, 0.8), ("hidden", "sfx_coin", 12.05, 0.7),
    ("send", "sfx_blip", 17.25, 0.9), ("reply-heart", "sfx_heart", 17.5, 1.0),
    ("spare", "sfx_reveal", 19.4, 0.6), ("ai-badge", "sfx_whoosh", 21.6, 0.7),
    ("layer", "sfx_awaken", 25.3, 0.7), ("cta", "confirmation_002", 28.2, 0.8),
]
TYPE_TICKS = [15.80 + i * 0.16 for i in range(7)]

def cut_clips(png_dir):
    import subprocess
    os.makedirs(os.path.join(ROOT, "assets/footage"), exist_ok=True)
    for cid, src, _at, dur, *_ in CLIPS:
        n = min(int(round(dur * FPS)) + 2, PNG_TOTAL - src)
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-framerate", "30", "-start_number", str(src), "-i",
                        os.path.join(png_dir, "f%08d.png"), "-frames:v", str(n), "-vf",
                        "scale=1080:1920:flags=neighbor,format=yuv420p", "-c:v", "libx264", "-crf", "15",
                        "-r", "30", os.path.join(ROOT, f"assets/footage/{cid}.mp4")], check=True)

def main():
    L = []
    a = L.append
    a('<?svml using="@hypit/markup@1"?>')
    a("<!-- GENERATED by tools/gen_svml.py — edit the plan there, then regenerate. -->")
    a("<svml>")
    for imp in ['as="asset" from="@hypit/media@1"', 'as="pipeline" from="@hypit/media-pipeline@1"',
                'as="program" from="@hypit/program-space@1"', 'as="time" from="@hypit/timeline-author@1"',
                'as="space" from="@hypit/spatial@1"', 'as="fonts" from="@hypit/fonts-open@1"',
                'as="media-track" from="@hypit/media-track@1"', 'as="audio-track" from="@hypit/audio-track@1"',
                'as="overlay" from="@momen/douyin-overlay@1"', 'as="film" from="@hypit/film@1"',
                'as="render" from="@hypit/render-hyperframes@1"', 'as="look" source="./momen.svs"']:
        a(f"  <import {imp}/>")
    a('  <program:Clock id="clock" frame-rate="30"/>')
    a(f'  <time:Timeline id="program" clock={{clock}} end="{fs(END)}"/>')
    a('  <space:Canvas id="vertical" width="1080" height="1920"/>')
    a('  <space:Frame id="full" within={vertical} left="0%" top="0%" right="100%" bottom="100%"/>')
    a('  <fonts:Stack id="caption-font" family="noto-sans-sc" weight="900" style="normal" emoji="color"/>')
    a("")
    a("  <!-- Game footage: clean plate recorded from the v2 录屏模式 with --clean (no baked captions). -->")
    for cid, *_ in CLIPS:
        a(f'  <asset:Video id="{cid}-file" src="./assets/footage/{cid}.mp4"/>')
        a(f'  <pipeline:Normalize id="{cid}-clip" source={{{cid}-file}} video="primary-moving" audio="none" span-authority="video" clock={{clock}}/>')
    a('  <media-track:Track id="footage" timeline={program.timeline} canvas={vertical}>')
    for cid, _src, at, dur, pb, s0, s1 in CLIPS:
        a(f'    <media-track:Item id="v-{cid}" media={{{cid}-clip.media}} frame={{full}} at="{fs(at)}" for="{fs(dur)}"'
          f' appearance={{look.media.{pb}}}>')
        a(f'      <media-track:Sampling at="start" zoom="{s0[0]}" x="{s0[1]}" y="{s0[2]}" easing="ease-out"/>')
        a(f'      <media-track:Sampling at="end" zoom="{s1[0]}" x="{s1[1]}" y="{s1[2]}"/>')
        a("    </media-track:Item>")
    a("  </media-track:Track>")
    a("")
    a("  <!-- Narration: Edge-TTS zh-CN-YunxiNeural (师兄: YunjianNeural), trimmed to word boundaries. -->")
    for lid in VO:
        a(f'  <asset:Audio id="{lid}-file" src="./assets/vo/{lid}.wav"/>')
        a(f'  <pipeline:Normalize id="{lid}" source={{{lid}-file}} video="none" audio="default" span-authority="audio" clock={{clock}}/>')
    a('  <audio-track:Track id="voice" timeline={program.timeline}>')
    for lid, at in VO.items():
        a(f'    <audio-track:Item id="vo-{lid}" source={{{lid}.media}} at="{fs(at)}" for="{fs(T[lid]["dur"])}" playback="once" gain="1.0"/>')
    a("  </audio-track:Track>")
    a("")
    files = sorted({s[1] for s in SFX} | {"sfx_type", "bgm_loop"})
    for f in files:
        a(f'  <asset:Audio id="{f}-file" src="./assets/audio/{f}.wav"/>')
        a(f'  <pipeline:Normalize id="{f}" source={{{f}-file}} video="none" audio="default" span-authority="audio" clock={{clock}}/>')
    a('  <audio-track:Track id="music" timeline={program.timeline}>')
    a(f'    <audio-track:Item id="bgm" source={{bgm_loop.media}} during="program" playback="loop" gain="0.32" fade-in="200ms" fade-out="900ms"/>')
    a("  </audio-track:Track>")
    a('  <audio-track:Track id="sfx" timeline={program.timeline}>')
    for sid, f, at, g in SFX:
        d = min(1.0, wav_dur(f))
        fade = ' fade-out="3f"' if d > 0.3 else ""
        a(f'    <audio-track:Item id="s-{sid}" source={{{f}.media}} at="{fs(at)}" for="{fs(d)}" playback="once" gain="{round(g * 0.5, 2)}"{fade}/>')
    for i, t in enumerate(TYPE_TICKS):
        a(f'    <audio-track:Item id="type-{i}" source={{sfx_type.media}} at="{fs(round(t, 2))}" for="{fs(wav_dur("sfx_type"))}" playback="once" gain="0.45"/>')
    a("  </audio-track:Track>")
    a("")
    cues = [
        ("hook", "hook", "这个NPC|/|杀了我|*99次", 0.0, 1.62, {"y": "0.13", "size": "132"}),
        ("flash-death", "flash", "", 1.6, 0.4, {"color": "#E0182D"}),
        ("deaths", "counter", "💀 97@0|💀 98@0.87|*💀 99@1.8", 2.75, 5.5, {"label": "死亡次数"}),
        ("flash-blade", "flash", "", 4.9, 0.35, {"color": "#FFFFFF"}),
        ("century", "counter", "*第100世", 8.25, 28.2 - 8.25, {"label": "这一世"}),
        ("hidden", "badge", "✨ 隐藏选项出现", 12.05, 1.3, {"y": "0.515", "color": "linear-gradient(90deg,#B8860B,#FFB800)"}),
        ("me", "bubble", per_char("我也死过99次", 0.08, 0.16), 15.72, 3.55, {"side": "right", "y": "0.555", "label": "我（自由输入）"}),
        ("brother", "bubble", "……你到底|/|知道|*多少？", 17.52, 1.8, {"side": "left", "y": "0.70", "label": "师兄 · 厉寒"}),
        ("ai", "badge", "🧠 AI 驱动 · 他会记得你", 21.65, 3.5, {"y": "0.52"}),
        ("cta", "hook", "你能挖到|/|第|*几层|？", 28.2, END - 28.2, {"y": "0.13", "size": "132"}),
        ("comment", "badge", "👇 评论区报出你的层数", 28.95, END - 28.95, {"y": "0.625", "color": "linear-gradient(90deg,#FF2D55,#FF7A00)"}),
    ]
    for lid in ["l02", "l03", "l04", "l05", "l06", "l09", "l10", "l11"]:
        extra = {"y": "0.45"} if lid in ("l09", "l10") else {"y": "0.3"} if lid == "l11" else {}
        cues.append((f"cap-{lid}", "cap", cap_tokens(lid), VO[lid], T[lid]["dur"] + 0.12, extra))
    cues.sort(key=lambda c: c[3])
    a('  <overlay:Scene id="overlay" timeline={program.timeline} canvas={vertical} font={caption-font} display={caption-font} during="program">')
    for cid, kind, text, at, dur, extra in cues:
        attrs = "".join(f' {k}="{v}"' for k, v in extra.items())
        a(f'    <overlay:Cue id="o-{cid}" kind="{kind}" text="{text}" at="{fs(at)}" for="{fs(dur)}"{attrs}/>')
    a("  </overlay:Scene>")
    a("")
    a('  <film:Film id="main" canvas={vertical} timeline={program.timeline} appearance={look.film.main}>')
    for src in ["footage.visual", "overlay.track", "voice.audio", "music.audio", "sfx.audio"]:
        a(f"    <film:Track source={{{src}}}/>")
    a("  </film:Film>")
    a('  <render:Video id="final" composition={main.composition} timeline={program.timeline}/>')
    a("</svml>")
    open(os.path.join(ROOT, "momen.svml"), "w").write("\n".join(L) + "\n")

if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1:
        cut_clips(sys.argv[1])  # python3 tools/gen_svml.py <png-seq-dir from `godot --write-movie f.png -- --movie --clean`>
    main()
