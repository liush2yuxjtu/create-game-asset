#!/usr/bin/env python3
"""Hypit 竖屏视频的字幕版式与时间对齐验证（games/<game>/<ver>/hypit/screens.json 驱动）。

用法：
  python3 scripts/verify-hypit-video.py games/momen-rencai/v3 [--video <成片.mp4>] [--out verification/hypit-v3]

检查（任一 FAIL 则退出码 1）：
  A 生成一致：momen.svml / momen.svs 必须与 screens.json 经 tools/gen_svml.py 生成的结果逐字一致
  B 时间轴：各屏首尾相接、总长 = Timeline end；源帧区间在素材范围内；事件帧落在本屏源区间内
  C 字幕时间：每条字幕在「事件帧对应的节目帧」出现、在本屏结束时消失；显示时长 ≥ max(1.0s, 字数/7 字每秒)
  D 版式：字幕带/标题带不与手机框重叠、在画布内；≤2 行；估算行宽 ≤ 带宽；带高够放下全部行
  E 事件标注：源片在事件帧 ±3 帧内有该窗口（±9 帧）里最大的画面变化，证明事件帧不是拍脑袋写的
  F 成片（给了 --video 时）：规格、时长、响度；字幕带在字幕出现前 ≤ 3 帧为空、出现后有字；每句口播在成片里的开口帧处真的出现（音频包络相关）；导出核对图
  G 口播（screens.json 有 voice 时必查）：每屏有口播且含本屏字幕的主句；开口帧 = 窗口开口（主句 = 字幕出现帧）、
    说完不越过窗口；每行字幕都能在主句里原样找到；语速 ≤ max_rate 且 ≤ 8 字每秒；人声比 BGM 响 ≥ min_speech_over_music_lu
依赖：python3、ffmpeg、ffprobe（无第三方 Python 包）。
"""
import argparse
import importlib.util
import json
import math
import pathlib
import re
import subprocess
import sys

RESULTS = []


def record(name, ok, detail):
    RESULTS.append((name, ok, detail))
    print(f"{'PASS' if ok else 'FAIL'}  {name}: {detail}")


def gray_frames(path, start_f, count, fps, w=90, h=160, crop=None):
    """返回 [bytes]，每帧 w*h 灰度。crop=(x,y,cw,ch) 先裁剪再缩放。"""
    vf = []
    if crop:
        vf.append("crop={2}:{3}:{0}:{1}".format(*crop))
    vf.append(f"scale={w}:{h}:flags=area,format=gray")
    cmd = ["ffmpeg", "-v", "error", "-ss", f"{max(0, start_f) / fps:.4f}", "-i", str(path),
           "-frames:v", str(count), "-vf", ",".join(vf), "-f", "rawvideo", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    n = w * h
    return [raw[i * n:(i + 1) * n] for i in range(len(raw) // n)]


def mad(a, b):
    return sum(abs(x - y) for x, y in zip(a, b)) / len(a)


def stdev(a):
    m = sum(a) / len(a)
    return math.sqrt(sum((x - m) ** 2 for x in a) / len(a))


def seg_rms_db(path, t0, t1):
    """音频片段 RMS（dBFS），用 ffmpeg astats。"""
    err = subprocess.run(["ffmpeg", "-v", "info", "-ss", f"{t0:.3f}", "-to", f"{t1:.3f}", "-i", str(path), "-vn",
                          "-af", "astats=measure_overall=RMS_level:measure_perchannel=0", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    vals = re.findall(r"RMS level dB:\s+(-?[\d.]+|-inf)", err)
    return float(vals[-1]) if vals and vals[-1] != "-inf" else -120.0


def envelope(path, t0, dur, rate=8000, hop=160):
    """20ms 一格的 RMS 包络（单声道 8kHz）。"""
    raw = subprocess.run(["ffmpeg", "-v", "error", "-ss", f"{t0:.3f}", "-t", f"{dur:.3f}", "-i", str(path), "-vn",
                          "-ac", "1", "-ar", str(rate), "-f", "s16le", "-"], capture_output=True, check=True).stdout
    n = len(raw) // 2
    vals = [int.from_bytes(raw[2 * i:2 * i + 2], "little", signed=True) for i in range(n)]
    return [math.sqrt(sum(v * v for v in vals[i:i + hop]) / hop) for i in range(0, n - hop + 1, hop)]


def pearson(a, b):
    n = min(len(a), len(b))
    if n < 5:
        return 0.0
    a, b = a[:n], b[:n]
    ma, mb = sum(a) / n, sum(b) / n
    va = math.sqrt(sum((x - ma) ** 2 for x in a))
    vb = math.sqrt(sum((y - mb) ** 2 for y in b))
    if va == 0 or vb == 0:
        return 0.0
    return sum((x - ma) * (y - mb) for x, y in zip(a, b)) / (va * vb)


def file_lufs(path):
    err = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(path), "-af", "ebur128", "-f", "null", "-"],
                         capture_output=True, text=True).stderr
    return float(re.findall(r"I:\s+(-?[\d.]+) LUFS", err)[-1])


def vo_windows(spec):
    """与 tools/tts_vo.py 相同的窗口规则：{屏-序号: (句, 开口帧, 截止帧, 是否主句, 屏id)}"""
    out, at = {}, 0
    for s in spec["screens"]:
        n = s["src_out"] - s["src_in"]
        starts = [(at + s["event_src_f"] - s["src_in"] if ln["at"] == "event" else at) + ln.get("delay_f", 0)
                  for ln in s.get("vo", [])]
        for k, ln in enumerate(s.get("vo", [])):
            later = [x for x in starts if x > starts[k]]
            out[f"{s['id']}-{k}"] = (ln, starts[k], (min(later) - 2 if later else at + n - 2), bool(ln.get("main")), s["id"])
        at += n
    return out


def probe(path, entries):
    out = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
                          "-show_entries", entries, "-of", "json", str(path)],
                         capture_output=True, text=True, check=True).stdout
    return json.loads(out)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("version_dir")
    ap.add_argument("--video")
    ap.add_argument("--out", default=None)
    ap.add_argument("--asr", action="store_true", help="用 faster-whisper 转写成片，核对每句主句在它的窗口里被说出来（需 pip install faster-whisper，首次会下模型）")
    args = ap.parse_args()

    vdir = pathlib.Path(args.version_dir).resolve()
    hdir = vdir / "hypit"
    spec = json.loads((hdir / "screens.json").read_text())
    fps = spec["fps"]
    out = pathlib.Path(args.out or f"verification/hypit-{vdir.name}").resolve()
    out.mkdir(parents=True, exist_ok=True)

    # A 生成一致
    gen_path = hdir / "tools" / "gen_svml.py"
    mod_spec = importlib.util.spec_from_file_location("gen_svml", gen_path)
    gen = importlib.util.module_from_spec(mod_spec)
    mod_spec.loader.exec_module(gen)
    svml, svs = gen.build(spec)
    same = (hdir / "momen.svml").read_text() == svml and (hdir / "momen.svs").read_text() == svs
    record("A 生成一致", same, "momen.svml/momen.svs 与 screens.json 一致" if same else "已过期：运行 tools/gen_svml.py")

    # B 时间轴
    footage = hdir / "assets" / "footage" / "gameplay_clean.mp4"
    src_frames = int(probe(footage, "stream=nb_read_frames")["streams"][0]["nb_read_frames"])
    at, bad = 0, []
    starts = {}
    for s in spec["screens"]:
        starts[s["id"]] = at
        if not (0 <= s["src_in"] < s["src_out"] <= src_frames):
            bad.append(f"{s['id']} 源区间越界")
        if not (s["src_in"] <= s["event_src_f"] < s["src_out"]):
            bad.append(f"{s['id']} 事件帧不在本屏源区间内")
        at += s["src_out"] - s["src_in"]
    total = at
    m = re.search(r'<time:Timeline id="program"[^>]*end="(\d+)f"', svml)
    if not m or int(m.group(1)) != total:
        bad.append(f"Timeline end ≠ 各屏总和 {total}f")
    items = [(i, int(a), int(f)) for i, a, f in re.findall(r'<mt:Item id="(\w+)"[^>]*at="(\d+)f" for="(\d+)f"', svml)]
    cur = 0
    for i, a, f in items:
        if a != cur:
            bad.append(f"{i} 与上一屏不相接（{a}f ≠ {cur}f）")
        cur = a + f
    record("B 时间轴", not bad, "; ".join(bad) or f"{len(items)} 屏首尾相接，总长 {total}f = {total / fps:.2f}s，素材 {src_frames} 帧")

    # C 字幕时间
    caps = {i: (int(a), int(f), body) for i, a, f, body in
            re.findall(r'<typo:Area id="cap-(\w+)"[^>]*at="(\d+)f" for="(\d+)f"><typo:P>(.*?)</typo:P>', svml)}
    bad, rows = [], []
    for s in spec["screens"]:
        a, f, body = caps.get(s["id"], (None, None, ""))
        want_at = starts[s["id"]] + s["event_src_f"] - s["src_in"]
        want_end = starts[s["id"]] + s["src_out"] - s["src_in"]
        chars = len(re.sub(r"[，。？！、：「」…\s]", "", "".join(s["caption"])))
        need = max(fps, math.ceil(chars / 7 * fps))
        if a != want_at:
            bad.append(f"{s['id']} 字幕在 {a}f 出现，应在事件帧 {want_at}f")
        if a is not None and a + f != want_end:
            bad.append(f"{s['id']} 字幕在 {a + f}f 消失，应在屏尾 {want_end}f")
        if f is not None and f < need:
            bad.append(f"{s['id']} 字幕只显示 {f}f，{chars} 字至少要 {need}f")
        rows.append((s, want_at, want_end))
    record("C 字幕时间", not bad, "; ".join(bad) or "每条字幕都在事件帧出现、屏尾消失，阅读时长足够")

    # D 版式
    def overlap(r1, r2):
        return not (r1[2] <= r2[0] or r2[2] <= r1[0] or r1[3] <= r2[1] or r2[3] <= r1[1])
    fr, W, H = spec["frames"], spec["canvas"][0], spec["canvas"][1]
    bad = []
    for band in ("title", "cap"):
        if overlap(fr[band], fr["phone"]):
            bad.append(f"{band} 带与手机框重叠")
        b = fr[band]
        if not (0 <= b[0] < b[2] <= W and 0 <= b[1] < b[3] <= H):
            bad.append(f"{band} 带超出画布")
    if overlap(fr["title"], fr["cap"]):
        bad.append("标题带与字幕带重叠")
    cw, ch, size = fr["cap"][2] - fr["cap"][0], fr["cap"][3] - fr["cap"][1], spec["caption_size"]
    for s in spec["screens"]:
        if len(s["caption"]) > 2:
            bad.append(f"{s['id']} 超过 2 行")
        for line in s["caption"]:
            width = len(line) * size + 16  # 像素字体近似等宽，外描边 8px
            if width > cw:
                bad.append(f"{s['id']}「{line}」估算 {width}px > 带宽 {cw}px")
        if len(s["caption"]) * size * 1.2 > ch:
            bad.append(f"{s['id']} {len(s['caption'])} 行放不进 {ch}px 高的字幕带")
    tw = len(spec["title"]) * spec["title_size"] + 12
    if tw > fr["title"][2] - fr["title"][0]:
        bad.append(f"标题估算 {tw}px 超宽")
    record("D 版式", not bad, "; ".join(bad) or "字幕带/标题带在手机框上方且互不重叠，行数与行宽都放得下")

    # E 事件标注
    bad, notes = [], []
    for s in spec["screens"]:
        e = s["event_src_f"]
        lo = max(0, e - 9)
        fr_ = gray_frames(footage, lo, 19, fps)
        diffs = [mad(fr_[i], fr_[i + 1]) for i in range(len(fr_) - 1)]
        k = max(range(len(diffs)), key=lambda i: diffs[i])
        peak = lo + k + 1  # 变化后的第一帧
        notes.append(f"{s['id']}:{peak - e:+d}")
        if abs(peak - e) > 3 and s["event_src_f"] != s["src_in"]:
            bad.append(f"{s['id']} 最大变化在源帧 {peak}，标注 {e}")
        elif abs(peak - e) > 3:
            bad.append(f"{s['id']} 屏首事件 {e} 附近没有明显画面变化（最大变化在 {peak}）")
    record("E 事件标注", not bad, "; ".join(bad) or "事件帧 ±3 帧内即最大画面变化（偏移 " + " ".join(notes) + "）")

    # G 口播
    voice = spec.get("voice")
    timing_path = hdir / "assets" / "vo" / "vo_timing.json"
    timing = json.loads(timing_path.read_text()) if timing_path.exists() else {}
    wins = vo_windows(spec)
    if voice is None:
        record("G 口播", False, "screens.json 没有 voice / vo：成片无人声")
    else:
        bad = []
        for s in spec["screens"]:
            lines = s.get("vo", [])
            if not lines:
                bad.append(f"{s['id']} 没有口播")
            elif sum(1 for ln in lines if ln.get("main")) != 1:
                bad.append(f"{s['id']} 主句数量 ≠ 1")
        for key, (ln, start, end, main, sid) in wins.items():
            t = timing.get(key)
            wav = hdir / "assets" / "vo" / f"{key}.wav"
            if not t or not wav.exists():
                bad.append(f"{key} 缺 wav 或 vo_timing（运行 tools/tts_vo.py）")
        record("G1 口播齐全", not bad, "; ".join(bad) or f"{len(wins)} 句口播，每屏 1 句主句，wav 与 vo_timing 齐全")

        bad = []
        for key, (ln, start, end, main, sid) in wins.items():
            t = timing.get(key)
            if not t:
                continue
            if t["text"] != ln["text"]:
                bad.append(f"{key} vo_timing 文案过期")
            if t["start_f"] != start:
                bad.append(f"{key} 开口 {t['start_f']}f ≠ 窗口 {start}f")
            if main and start != caps.get(sid, (None,))[0]:
                bad.append(f"{key} 主句开口 {start}f ≠ 字幕出现 {caps.get(sid, (None,))[0]}f")
            real = float(subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0",
                                         str(hdir / "assets" / "vo" / f"{key}.wav")], capture_output=True, text=True).stdout)
            if start + math.ceil(real * fps) > end + 1:
                bad.append(f"{key} 说到 {start + math.ceil(real * fps)}f，越过窗口 {end}f")
            if f'at="{start}f"' not in re.search(rf'<audio:Item id="vo-{key}-line"[^>]*>', svml).group(0):
                bad.append(f"{key} momen.svml 里的口播位置与 vo_timing 不一致")
        record("G2 口播时间", not bad, "; ".join(bad) or "每句在窗口开口处开口、在窗口内说完；主句与字幕同帧")

        bad = []
        strip = lambda x: re.sub(r"[，。？！、：「」…\s]", "", x)
        for s in spec["screens"]:
            mains = [ln for ln in s.get("vo", []) if ln.get("main")]
            if not mains:
                continue
            for line in s["caption"]:
                if strip(line) not in strip(mains[0]["text"]):
                    bad.append(f"{s['id']} 字幕「{line}」不在主句「{mains[0]['text']}」里")
        record("G3 字幕即口播", not bad, "; ".join(bad) or "每行字幕都能在同屏主句里原样找到")

        bad = []
        for key, t in timing.items():
            chars = len(strip(t["text"]))
            cps = chars / max(0.01, t["dur_f"] / fps)
            if t["rate"] > voice["max_rate"] or cps > 8:
                bad.append(f"{key} +{t['rate']}% · {cps:.1f} 字/秒")
        record("G4 语速", not bad, "; ".join(bad) or f"全部 ≤ +{voice['max_rate']}% 且 ≤ 8 字/秒")

        vo_l = [file_lufs(hdir / "assets" / "vo" / f"{k}.wav") for k in timing]
        bgm_l = file_lufs(hdir / "assets" / "audio" / "bgm_loop.wav") + 20 * math.log10(voice["bgm_gain_under_vo"])
        gap = min(vo_l) - bgm_l if vo_l else -99
        record("G5 人声压过音乐", gap >= voice["min_speech_over_music_lu"],
               f"最轻一句口播比 BGM 响 {gap:.1f} LU（要求 ≥ {voice['min_speech_over_music_lu']}）")

    # H 设计同步
    design = vdir / "design" / "StoryStudio.dc.html"
    if design.exists():
        root = pathlib.Path(__file__).resolve().parent
        try:
            out_js = subprocess.run(["node", str(root / "render-story-studio.cjs"), str(design)],
                                    capture_output=True, text=True, check=True).stdout
            d = json.loads(out_js)
            bad = []
            scr = d["screens"]
            if len(scr) != len(spec["screens"]):
                bad.append(f"设计稿 {len(scr)} 屏 ≠ 成片 {len(spec['screens'])} 屏")
            for a, b in zip(scr, spec["screens"]):
                if a["cap"].split("\n") != b["caption"]:
                    bad.append(f"{b['id']} 字幕：设计「{a['cap']}」≠ 成片「{'/'.join(b['caption'])}」")
                vo_design = (a.get("vo") or "").replace("口播：", "").replace(" ", "")
                vo_video = "".join(x["text"] for x in b.get("vo", []))
                if vo_design != vo_video:
                    bad.append(f"{b['id']} 口播：设计「{vo_design}」≠ 成片「{vo_video}」")
                t0, t1 = [float(x) for x in a["t"].rstrip("s").split("–")]
                n = (b["src_out"] - b["src_in"]) / fps
                if abs((t1 - t0) - n) > 0.11:
                    bad.append(f"{b['id']} 时长：设计 {t1 - t0:.1f}s ≠ 成片 {n:.1f}s")
            record("H 设计同步", not bad, "; ".join(bad) or
                   f"画布默认值渲染出 {len(scr)} 屏，字幕、口播、时长与成片一致（{d['chain'][0]}）")
        except (FileNotFoundError, subprocess.CalledProcessError) as e:
            record("H 设计同步", False, f"无法无头渲染设计稿：{e}")

    # F 成片
    if args.video:
        video = pathlib.Path(args.video).resolve()
        info = probe(video, "stream=width,height,sample_aspect_ratio,nb_read_frames")["streams"][0]
        n = int(info["nb_read_frames"])
        sar = info.get("sample_aspect_ratio", "1:1")
        ok = info["width"] == W and info["height"] == H and sar in ("1:1", "N/A", "0:1") and abs(n - total) <= 3
        record("F1 成片规格", ok, f"{info['width']}x{info['height']} SAR {sar} · {n} 帧（期望 {total}±3）")
        lf = subprocess.run(["ffmpeg", "-hide_banner", "-i", str(video), "-af", "ebur128", "-f", "null", "-"],
                            capture_output=True, text=True).stderr
        lufs = float(re.findall(r"I:\s+(-?[\d.]+) LUFS", lf)[-1])
        record("F2 响度", -15.5 <= lufs <= -13.0, f"{lufs} LUFS（目标 -14 ±1）")
        c = fr["cap"]
        crop = (c[0], c[1], c[2] - c[0], c[3] - c[1])
        bad = []
        sheet_times = []
        for s, a, end in rows:
            band_before = gray_frames(video, a - 3, 1, fps, 200, 32, crop)[0] if a - 3 >= starts[s["id"]] else None
            band_after = gray_frames(video, a + 6, 1, fps, 200, 32, crop)[0]
            on = stdev(band_after)
            if on < 12:
                bad.append(f"{s['id']} 字幕出现后 6 帧字幕带像空的（σ={on:.1f}）")
            if band_before is not None and stdev(band_before) > 8:
                bad.append(f"{s['id']} 字幕应在 {a}f 出现，但 {a - 3}f 字幕带已有内容（σ={stdev(band_before):.1f}）")
            sheet_times.append((a + 6) / fps)
        f3_bad = bad
        if voice and timing:
            weak, rs = [], []
            for key, t in timing.items():
                a = envelope(video, t["start_f"] / fps, t["dur_f"] / fps)
                b = envelope(hdir / "assets" / "vo" / f"{key}.wav", 0, t["dur_f"] / fps)
                r = max(pearson(a[max(0, lag):], b[max(0, -lag):]) for lag in range(-3, 4))
                rs.append(r)
                if r < 0.6:
                    weak.append(f"{key} r={r:.2f}")
            record("F4 成片口播可闻", not weak, "; ".join(weak) or
                   f"{len(timing)} 句口播：成片音频包络与口播 wav 在开口帧处相关，最低 r={min(rs):.2f}（门槛 0.6；无声版最高 0.52）")
        if args.asr and voice and timing:
            import difflib
            from faster_whisper import WhisperModel
            segs, _ = WhisperModel("small", device="cpu", compute_type="int8").transcribe(str(video), language="zh")
            words = [(sg.start, sg.end, sg.text) for sg in segs]
            strip2 = lambda x: re.sub(r"[，。？！、：「」…\s]", "", x)
            miss = []
            for key, t in timing.items():
                a0, a1 = t["start_f"] / fps - 0.2, (t["start_f"] + t["dur_f"]) / fps + 0.3
                heard = "".join(w[2] for w in words if w[0] < a1 and w[1] > a0)
                ratio = difflib.SequenceMatcher(None, strip2(t["text"]), strip2(heard)).ratio()
                if ratio < 0.6:
                    miss.append(f"{key} 期望「{t['text']}」听到「{heard}」({ratio:.2f})")
            record("F5 转写核对", not miss, "; ".join(miss) or f"Whisper 在每句窗口里听到的文字与口播稿相似度 ≥ 0.6（{len(timing)} 句）")
        bad = f3_bad
        record("F3 成片字幕对齐", not bad, "; ".join(bad) or "每条字幕在事件帧出现（出现前字幕带为空、出现后有字）")
        sel = "+".join(f"between(n\\,{round(t * fps)}\\,{round(t * fps)})" for t in sheet_times)
        sheet = out / "caption-sync-sheet.png"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(video), "-vf",
                        f"select='{sel}',scale=240:-1,tile={len(sheet_times)}x1", "-frames:v", "1", str(sheet)], check=True)
        print(f"INFO  核对图（每条字幕出现后 6 帧，人工看字幕与画面是否对题）：{sheet}")

    report = {"version": vdir.name, "results": [{"check": n, "pass": ok, "detail": d} for n, ok, d in RESULTS]}
    (out / "report.json").write_text(json.dumps(report, ensure_ascii=False, indent=1) + "\n")
    failed = [n for n, ok, _ in RESULTS if not ok]
    print(f"\n{'FAIL' if failed else 'PASS'}：{len(RESULTS) - len(failed)}/{len(RESULTS)}  报告 {out / 'report.json'}")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
