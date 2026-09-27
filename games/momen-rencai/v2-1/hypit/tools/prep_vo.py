"""assets/vo/lines.tsv → l01..l12.wav + timing.json（TTS → 按词边界裁剪 → 每句 loudnorm −16）。"""
import csv, json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
VO = os.path.join(HERE, "..", "assets", "vo")
timing = {}
for lid, voice, rate, text in csv.reader(open(os.path.join(VO, "lines.tsv")), delimiter="\t"):
    mp3 = os.path.join(VO, lid + ".mp3")
    subprocess.run([sys.executable, os.path.join(HERE, "tts.py"), text, voice, mp3, rate], check=True)
    words = json.load(open(mp3 + ".json"))
    s = max(0, words[0][0] - 0.04)
    e = words[-1][0] + words[-1][1] + 0.12
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", mp3, "-ss", f"{s:.3f}", "-to", f"{e:.3f}",
                    "-af", "loudnorm=I=-16:TP=-2:LRA=7", "-ar", "48000", "-ac", "2",
                    os.path.join(VO, lid + ".wav")], check=True)
    timing[lid] = {"dur": round(e - s, 3), "words": [[round(a - s, 3), round(d, 3), t] for a, d, t in words]}
    os.remove(mp3); os.remove(mp3 + ".json")
json.dump(timing, open(os.path.join(VO, "timing.json"), "w"), ensure_ascii=False, indent=1)
print("ok", len(timing), "lines")
