#!/usr/bin/env python3
"""合成 GBA 风 8-bit 音乐与音效 → assets/audio/*.wav（确定性，可重复生成）。
打击/界面音效另外借用 Kenney CC0（经 gdquest godot-open-rpg 仓库）：chop / impactWood / confirmation / error / doorOpen / drop。
"""
import os, wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(7)


def note(n):  # MIDI -> Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def t_(d):
    return np.arange(int(SR * d)) / SR


def sq(f, d, duty=0.5):
    ph = (t_(d) * f) % 1.0
    return np.where(ph < duty, 1.0, -1.0)


def tri(f, d):
    ph = (t_(d) * f) % 1.0
    return 4 * np.abs(ph - 0.5) - 1


def noise(d):
    # GBA 风：采样保持的噪声
    n = rng.uniform(-1, 1, int(SR * d / 4) + 1)
    return np.repeat(n, 4)[: int(SR * d)]


def env(x, a=0.005, r=0.08):
    n = len(x)
    e = np.ones(n)
    na, nr = int(SR * a), int(SR * r)
    if na: e[:na] = np.linspace(0, 1, na)
    if nr and nr < n: e[-nr:] *= np.linspace(1, 0, nr)
    return x * e


def put(buf, x, at):
    i = int(at * SR)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i]


def save(name, x, vol=0.8):
    x = np.clip(x / max(1e-9, np.max(np.abs(x))) * vol, -1, 1)
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype(np.int16).tobytes())


def bgm():
    bpm = 96
    beat = 60 / bpm
    bars = 8
    L = bars * 4 * beat
    buf = np.zeros(int(SR * L) + SR)
    prog = [50, 46, 48, 45, 50, 46, 43, 45]  # D Bb C A D Bb G A（D 小调，阴一点）
    minor = {50: [62, 65, 69], 46: [58, 62, 65], 48: [60, 64, 67], 45: [57, 61, 64], 43: [55, 58, 62]}
    for b, root in enumerate(prog):
        t0 = b * 4 * beat
        for k in range(8):  # 八分音符低音脉冲
            put(buf, env(sq(note(root - 12), beat / 2 * 0.9, 0.25), r=0.03) * 0.30, t0 + k * beat / 2)
        arp = minor[root]
        for k in range(16):  # 十六分琶音
            n = arp[k % 3] + (12 if k % 8 >= 6 else 0)
            put(buf, env(tri(note(n), beat / 4 * 0.8), r=0.02) * 0.16, t0 + k * beat / 4)
        for k in range(4):
            put(buf, env(noise(0.03), r=0.02) * 0.07, t0 + k * beat + beat / 2)
            if k in (0, 2):
                kick = np.sin(2 * np.pi * np.cumsum(np.linspace(120, 40, int(SR * 0.12))) / SR)
                put(buf, env(kick, r=0.05) * 0.35, t0 + k * beat)
    # 旋律（方波 12.5% 占空比，GBA 味）
    mel = [(74, 1), (72, 0.5), (70, 0.5), (69, 2), (70, 1), (69, 0.5), (67, 0.5), (65, 2),
           (67, 1), (69, 1), (70, 1), (72, 1), (69, 3), (0, 1),
           (74, 1), (77, 1), (76, 0.5), (74, 0.5), (72, 1), (70, 1), (69, 1), (67, 1), (65, 1),
           (62, 1), (64, 1), (65, 1), (69, 4)]
    t = 0
    for n, d in mel:
        if n:
            put(buf, env(sq(note(n), d * beat * 0.92, 0.125), a=0.01, r=0.06) * 0.13, t)
        t += d * beat
    return buf[: int(SR * L)]


def main():
    os.makedirs(OUT, exist_ok=True)
    save("bgm_loop.wav", bgm(), 0.55)
    # 死亡：下滑方波 + 噪声
    d = 1.0
    f = np.linspace(440, 60, int(SR * d))
    x = np.sign(np.sin(2 * np.pi * np.cumsum(f) / SR)) * np.linspace(1, 0, int(SR * d)) * 0.6
    y = np.zeros(int(SR * d)); put(y, env(noise(0.35), r=0.3) * 0.6, 0)
    save("sfx_death.wav", x + y)
    # 铭刻：上行琶音 + 闪烁
    buf = np.zeros(int(SR * 1.0))
    for i, n in enumerate([62, 66, 69, 74, 78, 81]):
        put(buf, env(tri(note(n), 0.25), r=0.15) * 0.5, i * 0.07)
        put(buf, env(sq(note(n + 12), 0.08, 0.125), r=0.06) * 0.15, i * 0.07 + 0.03)
    save("sfx_awaken.wav", buf)
    # 揭开一层：和弦 + 钟
    buf = np.zeros(int(SR * 1.4))
    for n in (50, 57, 62, 65, 69):
        put(buf, env(sq(note(n), 1.2, 0.25), a=0.01, r=0.9) * 0.18, 0)
    bell = np.sin(2 * np.pi * note(86) * t_(1.2)) * np.exp(-t_(1.2) * 4)
    put(buf, bell * 0.5, 0.05)
    save("sfx_reveal.wav", buf)
    save("sfx_blip.wav", env(sq(note(84), 0.05, 0.25), r=0.02), 0.5)
    save("sfx_type.wav", env(sq(note(96), 0.018, 0.5), r=0.01), 0.3)
    thump = np.sin(2 * np.pi * np.cumsum(np.linspace(90, 30, int(SR * 0.25))) / SR)
    save("sfx_heart.wav", env(thump, r=0.15), 0.9)
    wh = noise(0.35) * np.sin(np.linspace(0, np.pi, int(SR * 0.35)))
    save("sfx_whoosh.wav", wh, 0.4)
    buf = np.zeros(int(SR * 0.16)); put(buf, env(sq(note(88), 0.06, 0.25), r=0.02), 0); put(buf, env(sq(note(93), 0.08, 0.25), r=0.04), 0.06)
    save("sfx_coin.wav", buf, 0.45)
    buf = np.zeros(int(SR * 0.5))
    for i, n in enumerate([57, 53, 50]):
        put(buf, env(sq(note(n), 0.14, 0.5), r=0.05) * 0.5, i * 0.13)
    save("sfx_wrong.wav", buf, 0.5)
    print("audio ok")


if __name__ == "__main__":
    main()
