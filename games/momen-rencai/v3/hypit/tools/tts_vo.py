#!/usr/bin/env python3
"""口播生成：读 screens.json 的 vo，用 Edge-TTS 合成，每句自动选语速放进它的时间窗。

- 时间窗：at=event 从事件帧开口，at=screen 从屏首（+delay_f）开口；截止到同屏下一句开口前 2 帧或屏尾前 2 帧。
- 语速从 voice.base_rate 起每次 +10%，直到裁掉首尾静音后的长度放得进窗口；到 voice.max_rate 还放不进就报错退出，
  这时应该改稿或加长这一屏的源片，而不是再提速。
- 输出 assets/vo/<屏>-<序号>.wav（48k 单声道，-16 LUFS）和 assets/vo/vo_timing.json（语速、帧长、词级时间）。
依赖：pip install edge-tts；走代理时读 HTTPS_PROXY，自签 CA 设 SSL_CERT_FILE。
用法：python3 tools/tts_vo.py
"""
import asyncio
import json
import math
import os
import pathlib
import subprocess
import sys
import tempfile

import certifi

if os.environ.get("SSL_CERT_FILE"):
    certifi.where = lambda: os.environ["SSL_CERT_FILE"]
import edge_tts  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent


async def synth(text, voice, rate, out):
    c = edge_tts.Communicate(text, voice, rate=f"+{rate}%", proxy=os.environ.get("HTTPS_PROXY"), boundary="WordBoundary")
    words = []
    with open(out, "wb") as f:
        async for ch in c.stream():
            if ch["type"] == "audio":
                f.write(ch["data"])
            elif ch["type"] == "WordBoundary":
                words.append([round(ch["offset"] / 1e7, 3), round(ch["duration"] / 1e7, 3), ch["text"]])
    return words


def windows(spec):
    """(屏, 序号, 句, 开口节目帧, 截止节目帧)"""
    fps, at, out = spec["fps"], 0, []
    for s in spec["screens"]:
        n = s["src_out"] - s["src_in"]
        starts = []
        for line in s.get("vo", []):
            if line["at"] == "event":
                starts.append(at + s["event_src_f"] - s["src_in"] + line.get("delay_f", 0))
            else:
                starts.append(at + line.get("delay_f", 0))
        for k, line in enumerate(s.get("vo", [])):
            later = [x for x in starts if x > starts[k]]
            end = min(later) - 2 if later else at + n - 2
            out.append((s, k, line, starts[k], end))
        at += n
    return out


def main():
    spec = json.loads((ROOT / "screens.json").read_text())
    fps, v = spec["fps"], spec["voice"]
    vo_dir = ROOT / "assets" / "vo"
    vo_dir.mkdir(parents=True, exist_ok=True)
    timing, failed = {}, []
    with tempfile.TemporaryDirectory() as tmp:
        for s, k, line, start, end in windows(spec):
            key = f"{s['id']}-{k}"
            budget = (end - start) / fps
            rate = v["base_rate"]
            while True:
                mp3 = pathlib.Path(tmp) / f"{key}-{rate}.mp3"
                words = asyncio.run(synth(line["text"], line.get("voice", v["name"]), rate, mp3))
                t0 = max(0.0, words[0][0] - 0.03)
                t1 = words[-1][0] + words[-1][1] + 0.12
                if t1 - t0 <= budget or rate >= v["max_rate"]:
                    break
                rate += 10
            dur = t1 - t0
            if dur > budget:
                failed.append(f"{key}「{line['text']}」在 +{rate}% 仍需 {dur:.2f}s，窗口只有 {budget:.2f}s")
            wav = vo_dir / f"{key}.wav"
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-ss", f"{t0:.3f}", "-to", f"{t1:.3f}", "-i", str(mp3),
                            "-af", f"loudnorm=I={v['lufs']}:TP=-1.5:LRA=7", "-ar", "48000", "-ac", "1", str(wav)], check=True)
            timing[key] = {"text": line["text"], "rate": rate, "start_f": start, "dur_f": math.ceil(dur * fps),
                           "window_end_f": end, "words": [[round(w[0] - t0, 3), w[1], w[2]] for w in words]}
            print(f"{key}: +{rate}% {dur:.2f}s / 窗口 {budget:.2f}s  {line['text']}")
    (vo_dir / "vo_timing.json").write_text(json.dumps(timing, ensure_ascii=False, indent=1) + "\n")
    if failed:
        print("放不下：\n  " + "\n  ".join(failed))
        sys.exit(1)


if __name__ == "__main__":
    main()
