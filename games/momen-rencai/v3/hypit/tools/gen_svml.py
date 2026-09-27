#!/usr/bin/env python3
"""由 screens.json 生成 momen.svml 与 momen.svs（不要手改这两个文件）。

规则：
- 每屏一个 media-track Item，按源帧 [src_in, src_out) 原速播放，屏与屏首尾相接；
- 每屏字幕从 event_src_f 对应的节目帧开始，到该屏结束，与画面事件对齐；
- 字幕放在手机框上方的字幕带里，不压游戏画面。
用法：python3 tools/gen_svml.py [--check]   （--check：只比较，不写文件；不一致时退出码 1）
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent


def px(v):
    return f"{v}px"


def build(spec):
    fps = spec["fps"]
    fr = spec["frames"]
    phone_css = ('stack-order: 2; fit: cover; clip: rounded; radius: 28; border-width: 5; '
                 'border-color: #F2C14E; frame-paint: #120D1A; shadows: "0 0 40 6 #F2C14E44";')
    svs = ['<?svml using="@hypit/svs@1"?>', '<sheet version="1">', '  film.main { background: #120D1A; }']
    items, caps, sfx = [], [], []
    at = 0
    z = spec["zoom"]["to"]
    zx = round((z - 1) * (fr["phone"][2] - fr["phone"][0]) / 2)
    zy = round((z - 1) * (fr["phone"][3] - fr["phone"][1]) / 2)
    for s in spec["screens"]:
        n = s["src_out"] - s["src_in"]
        svs.append(f"  media.{s['id']} {{ {phone_css} trim-start: {s['src_in']}; trim-end: {s['src_out']}; }}")
        items.append(
            f'    <mt:Item id="{s["id"]}" media={{gameplay.media}} frame={{phone}} appearance={{look.media.{s["id"]}}} at="{at}f" for="{n}f">\n'
            f'      <mt:Sampling at="start" zoom="1" easing="ease-in-out"/>\n'
            f'      <mt:Sampling at="end" zoom="{z}" x="{zx}" y="{zy}"/>\n'
            f'    </mt:Item>')
        cap_at = at + (s["event_src_f"] - s["src_in"])
        cap_for = at + n - cap_at
        style = "cta-style" if s.get("cta") else "cap-style"
        body = "<typo:Break/>".join(s["caption"])
        caps.append(f'    <typo:Area id="cap-{s["id"]}" placement={{cap-band}} style={{{style}}} motion={{pop}} '
                    f'at="{cap_at}f" for="{cap_for}f"><typo:P>{body}</typo:P></typo:Area>')
        src = {"whoosh": ("whoosh", "0.4"), "reveal": ("reveal", "0.6"), "slam": ("slam", "0.9")}.get(s.get("sfx"))
        if src:
            sfx.append(f'    <audio:Item id="sfx-{s["id"]}" source={{{src[0]}.media}} at="{cap_at}f" for="24f" playback="once" gain="{src[1]}"/>')
        at += n
    total = at
    svs += [
        f'  text.title {{ size: {spec["title_size"]}; line-height: 1.2; stack-order: 20; align: center; block-align: center; }}',
        f'  text.cap {{ size: {spec["caption_size"]}; line-height: 1.2; stack-order: 25; align: center; block-align: center; }}',
        f'  text.cta {{ size: {spec["caption_size"]}; line-height: 1.2; stack-order: 26; align: center; block-align: center; }}',
        '</sheet>', '']
    t, c, p = fr["title"], fr["cap"], fr["phone"]
    svml = f'''<?svml using="@hypit/markup@1"?>
<svml>
  <!-- 由 tools/gen_svml.py 从 screens.json 生成，勿手改。 -->
  <import as="asset" from="@hypit/media@1"/>
  <import as="pipeline" from="@hypit/media-pipeline@1"/>
  <import as="program" from="@hypit/program-space@1"/>
  <import as="time" from="@hypit/timeline-author@1"/>
  <import as="space" from="@hypit/spatial@1"/>
  <import as="mt" from="@hypit/media-track@1"/>
  <import as="audio" from="@hypit/audio-track@1"/>
  <import as="typo" from="@hypit/typography-track@1"/>
  <import as="film" from="@hypit/film@1"/>
  <import as="render" from="@hypit/render-hyperframes@1"/>
  <import as="look" source="./momen.svs"/>

  <asset:Video id="gameplay-file" src="./assets/footage/gameplay_clean.mp4"/>
  <asset:Font id="pixel" src="./assets/fonts/pixel-v3-subset.ttf" weight="400" style="normal"/>
  <asset:Audio id="bgm-file" src="./assets/audio/bgm_loop.wav"/>
  <asset:Audio id="whoosh-file" src="./assets/audio/sfx_whoosh.wav"/>
  <asset:Audio id="reveal-file" src="./assets/audio/sfx_reveal.wav"/>
  <asset:Audio id="slam-file" src="./assets/audio/impactWood_light_002.ogg"/>

  <program:Clock id="clock" frame-rate="{fps}"/>
  <pipeline:Normalize id="gameplay" source={{gameplay-file}} clock={{clock}} video="primary-moving" audio="none" span-authority="video"/>
  <pipeline:Normalize id="bgm" source={{bgm-file}} clock={{clock}} video="none" audio="default" span-authority="audio"/>
  <pipeline:Normalize id="whoosh" source={{whoosh-file}} clock={{clock}} video="none" audio="default" span-authority="audio"/>
  <pipeline:Normalize id="reveal" source={{reveal-file}} clock={{clock}} video="none" audio="default" span-authority="audio"/>
  <pipeline:Normalize id="slam" source={{slam-file}} clock={{clock}} video="none" audio="default" span-authority="audio"/>

  <time:Timeline id="program" clock={{clock}} end="{total}f"/>
  <space:Canvas id="canvas" width="{spec["canvas"][0]}" height="{spec["canvas"][1]}"/>
  <space:Frame id="title-band" within={{canvas}} left="{px(t[0])}" top="{px(t[1])}" right="{px(t[2])}" bottom="{px(t[3])}"/>
  <space:Frame id="cap-band" within={{canvas}} left="{px(c[0])}" top="{px(c[1])}" right="{px(c[2])}" bottom="{px(c[3])}"/>
  <space:Frame id="phone" within={{canvas}} left="{px(p[0])}" top="{px(p[1])}" right="{px(p[2])}" bottom="{px(p[3])}"/>

  <mt:Track id="game" timeline={{program.timeline}} canvas={{canvas}}>
{chr(10).join(items)}
  </mt:Track>

  <typo:Style id="title-style" recipe={{look.text.title}} font={{pixel}}>
    <typo:Stroke color="#120D1A" width="6" placement="outside"/>
    <typo:Fill color="#F2C14E"/>
  </typo:Style>
  <typo:Style id="cap-style" recipe={{look.text.cap}} font={{pixel}}>
    <typo:Stroke color="#120D1A" width="8" placement="outside"/>
    <typo:Fill color="#FFFFFF"/>
  </typo:Style>
  <typo:Style id="cta-style" recipe={{look.text.cta}} font={{pixel}}>
    <typo:Glow color="#4FB8A6" blur="20"/>
    <typo:Stroke color="#120D1A" width="8" placement="outside"/>
    <typo:Fill color="#4FB8A6"/>
  </typo:Style>
  <typo:Motion id="pop">
    <typo:ItemKeyframe at="0" scale="1.12" opacity="0" easing="ease-out"/>
    <typo:ItemKeyframe at="4" scale="1" opacity="1"/>
  </typo:Motion>

  <typo:Track id="captions" timeline={{program.timeline}}>
    <typo:Area id="title" placement={{title-band}} style={{title-style}} during="program">{spec["title"]}</typo:Area>
{chr(10).join(caps)}
  </typo:Track>

  <audio:Track id="sound" timeline={{program.timeline}}>
    <audio:Item id="music" source={{bgm.media}} during="program" playback="loop" gain="0.55" fade-out="30f"/>
{chr(10).join(sfx)}
  </audio:Track>

  <film:Film id="main" canvas={{canvas}} timeline={{program.timeline}} appearance={{look.film.main}}>
    <film:Track source={{game.visual}}/>
    <film:Track source={{captions.track}}/>
    <film:Track source={{sound.audio}}/>
  </film:Film>
  <render:Video id="final" composition={{main.composition}} timeline={{program.timeline}}/>
</svml>
'''
    return svml, "\n".join(svs)


def main():
    spec = json.loads((ROOT / "screens.json").read_text())
    svml, svs = build(spec)
    targets = {ROOT / "momen.svml": svml, ROOT / "momen.svs": svs}
    if "--check" in sys.argv:
        stale = [p.name for p, text in targets.items() if not p.exists() or p.read_text() != text]
        if stale:
            print("STALE:", ", ".join(stale), "— 运行 python3 tools/gen_svml.py 重新生成")
            sys.exit(1)
        print("OK: momen.svml / momen.svs 与 screens.json 一致")
        return
    for p, text in targets.items():
        p.write_text(text)
    print("wrote", ", ".join(p.name for p in targets))


if __name__ == "__main__":
    main()
