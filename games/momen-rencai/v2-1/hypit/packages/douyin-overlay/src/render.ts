import { sealVisualTrack } from "@hypit/hypit/composition";
import type { VisualElement } from "@hypit/hypit/composition";
import { browserProgram } from "@hypit/hypit/hyperframes";
import type { FontStackRef } from "@hypit/hypit/media";
import type { Timeline } from "@hypit/hypit/timeline";
import type { CanvasSpace } from "@hypit/hypit/spatial";
import { assertTemporalWindowFor } from "@hypit/hypit/temporal";
import type { TemporalInstant, TemporalWindow } from "@hypit/hypit/temporal";

export const CUE_KINDS = ["hook", "cap", "bubble", "counter", "badge", "flash"] as const;
export type CueKind = typeof CUE_KINDS[number];
export type Cue = { id: string; kind: CueKind; text: string; hold: { seconds?: number; frames?: number };
  side: string; y: number | null; size: number | null; color: string; label: string; at: TemporalInstant };
export type OverlayOptions = { id: string };

type Token = { text: string; t: number; em: boolean; br: boolean };

/** "这个@0|*NPC@0.4|/|杀了我@1.3" → tokens; times are seconds after the cue starts. */
export function parseTokens(text: string): Token[] {
  if (!text.trim()) return [];
  return text.split("|").map(raw => {
    if (raw === "/") return { text: "", t: 0, em: false, br: true };
    let body = raw, t = 0;
    const at = raw.lastIndexOf("@");
    if (at > 0 && /^\d+(\.\d+)?$/.test(raw.slice(at + 1))) { body = raw.slice(0, at); t = Number(raw.slice(at + 1)); }
    const em = body.startsWith("*");
    return { text: em ? body.slice(1) : body, t, em, br: false };
  });
}

const DEFAULTS: Record<CueKind, { y: number; size: number }> = {
  hook: { y: 0.16, size: 150 }, cap: { y: 0.405, size: 86 }, bubble: { y: 0.64, size: 92 },
  counter: { y: 0.09, size: 56 }, badge: { y: 0.33, size: 50 }, flash: { y: 0.5, size: 0 },
};
const YELLOW = "#FFD84A", INK = "#111014";

/** Every overlay shares one browser program so pops, shakes and handoffs stay frame-exact. */
export function renderOverlay(timeline: Timeline, canvas: CanvasSpace, window: TemporalWindow,
  font: FontStackRef, display: FontStackRef, cues: readonly Cue[], options: OverlayOptions) {
  assertTemporalWindowFor(window, { subjectId: options.id, space: timeline });
  const fps = timeline.frameRate.numerator / timeline.frameRate.denominator;
  const W = canvas.widthPx, H = canvas.heightPx;
  let order = 0;
  const text = (id: string, value: string, fonts: FontStackRef, size: number, fill: string, stroke = 0, strokeColor = INK): VisualElement => ({
    id, kind: "text", parent: "overlay", order: ++order, text: value, fonts: fonts.faces,
    style: [{ name: "font-size", value: `${size}px` }, { name: "line-height", value: 1.12 }, { name: "white-space", value: "pre" }],
    paints: [...(stroke > 0 ? [{ kind: "stroke" as const, paint: { kind: "solid" as const, color: strokeColor }, widthPx: stroke, placement: "outside" as const }] : []),
      { kind: "fill" as const, paint: { kind: "solid" as const, color: fill } }],
  } as VisualElement);

  const children: VisualElement[] = [];
  const data: { kind: string; start: number; end: number; side: string; tokens: number[]; lines: number[] }[] = [];
  const blocks: string[] = [];
  cues.forEach((cue, ci) => {
    const start = cue.at.frame - window.span.startFrame;
    const holdFrames = cue.hold.frames ?? Math.round((cue.hold.seconds ?? 0) * fps);
    const end = Math.min(start + holdFrames, window.span.endFrameExclusive - window.span.startFrame);
    if (start < 0 || holdFrames < 1) throw new Error(`Cue ${cue.id} must start inside the scene and last at least one frame.`);
    const d = DEFAULTS[cue.kind], y = cue.y ?? d.y, size = cue.size ?? d.size;
    const tokens = parseTokens(cue.text);
    const times = tokens.filter(tok => !tok.br).map(tok => Math.round(tok.t * fps));
    const lineStarts: number[] = []; { let first = true, ti = 0;
      for (const tok of tokens) { if (tok.br) { first = true; continue; } if (first) { lineStarts.push(times[ti]!); first = false; } ti++; } }
    data.push({ kind: cue.kind, start, end, side: cue.side, tokens: times, lines: lineStarts });
    let wi = 0, lines: string[][] = [[]];
    for (const tok of tokens) {
      if (tok.br) { lines.push([]); continue; }
      const slot = `c${ci}w${wi++}`;
      let fill = tok.em ? YELLOW : "#FFFFFF", stroke = 0, fonts = font;
      if (cue.kind === "hook") { fonts = display; stroke = Math.round(size * 0.11); }
      else if (cue.kind === "cap") { stroke = Math.round(size * 0.13); }
      else if (cue.kind === "bubble") { fill = tok.em ? "#E0182D" : "#111111"; }
      else if (cue.kind === "counter") { fill = tok.em ? YELLOW : "#FFFFFF"; stroke = 8; }
      else if (cue.kind === "badge") { fill = tok.em ? INK : "#FFFFFF"; }
      children.push(text(slot, tok.text, fonts, size, fill, stroke));
      lines.at(-1)!.push(`<span class="tk">{{${slot}}}</span>`);
    }
    const label = cue.label ? (() => { const slot = `c${ci}label`;
      children.push(text(slot, cue.label, font, cue.kind === "counter" ? Math.round(size * 0.62) : Math.round(size * 0.46),
        cue.kind === "counter" ? "#FFB3B3" : "#E8E8E8", cue.kind === "counter" ? 6 : 5)); return `<div class="label">{{${slot}}}</div>`; })() : "";
    const body = lines.map(line => `<div class="line">${line.join("")}</div>`).join("");
    const top = Math.round(y * H);
    if (cue.kind === "flash") blocks.push(`<div class="cue flash" data-cue="${ci}" style="background:${cue.color || "#E0182D"}"></div>`);
    else if (cue.kind === "bubble") blocks.push(`<div class="cue bubble ${cue.side === "left" ? "left" : "right"}" data-cue="${ci}" style="top:${top}px">${label}<div class="box">${body}</div></div>`);
    else if (cue.kind === "counter") blocks.push(`<div class="cue counter" data-cue="${ci}" style="top:${top}px">${label}<div class="num">${body}</div></div>`);
    else if (cue.kind === "badge") blocks.push(`<div class="cue badge" data-cue="${ci}" style="top:${top}px"><div class="pill" style="background:${cue.color || "linear-gradient(90deg,#FF2D55,#FF7A00)"}">${body}</div></div>`);
    else blocks.push(`<div class="cue ${cue.kind}" data-cue="${ci}" style="top:${top}px">${body}</div>`);
  });

  const program = browserProgram({
    html: blocks.join(""),
    css: `:scope{overflow:hidden;pointer-events:none}
      .cue{position:absolute;left:0;width:${W}px;display:none;transform-origin:50% 50%}
      .line{display:flex;justify-content:center;align-items:baseline;flex-wrap:nowrap}
      .tk{display:inline-block;transform-origin:50% 70%}
      .hook,.cap{translate:0 -50%}
      .cap .line{width:fit-content;margin:0 auto;padding:10px 34px 16px;border-radius:26px;background:rgba(8,6,12,.62);box-shadow:0 8px 24px rgba(0,0,0,.35)}
      .hook .line+.line{margin-top:6px}
      .flash{top:0;height:${H}px}
      .bubble{translate:0 -50%;padding:0 70px;box-sizing:border-box}
      .bubble .label{margin:0 18px 10px}
      .bubble .box{display:inline-block;max-width:820px;padding:30px 42px;border-radius:44px;box-shadow:0 14px 0 rgba(0,0,0,.35)}
      .bubble .box .line{justify-content:flex-start}
      .bubble.right{text-align:right;transform-origin:88% 100%}.bubble.right .box{background:#95EC69;border-bottom-right-radius:10px}
      .bubble.left{text-align:left;transform-origin:12% 100%}.bubble.left .box{background:#FFFFFF;border-bottom-left-radius:10px}
      .counter{left:56px;width:auto;display:none;padding:14px 30px 16px;border-radius:22px;background:rgba(10,8,12,.72);border:4px solid #E0182D;transform-origin:0 50%;translate:0 -50%}
      .counter .num{position:relative;height:1.15em}.counter .num .line{justify-content:flex-start}
      .counter .num .tk{position:absolute;left:0;top:0}
      .badge{translate:0 -50%;text-align:center}
      .badge .pill{display:inline-block;padding:16px 40px 18px;border-radius:999px;box-shadow:0 10px 30px rgba(0,0,0,.45)}`,
    data: { cues: data },
    setup: `const els=[...root.querySelectorAll('.cue')];
      const ease=t=>1-Math.pow(1-t,3), back=t=>{const c=1.9;return 1+(c+1)*Math.pow(t-1,3)+c*Math.pow(t-1,2);};
      const cl=t=>Math.max(0,Math.min(1,t));
      return frame=>{
        els.forEach(el=>{
          const d=data.cues[Number(el.dataset.cue)], age=frame-d.start, left=d.end-frame;
          if(age<0||left<=0){el.style.display='none';return;}
          el.style.display=d.kind==='counter'?'inline-block':'block';
          const out=cl(left/4), tks=[...el.querySelectorAll('.tk')];
          if(d.kind==='flash'){el.style.opacity=String(0.9*(1-ease(cl(age/Math.max(1,d.end-d.start)))));return;}
          if(d.kind==='counter'){
            let cur=0; d.tokens.forEach((t,i)=>{if(age>=t)cur=i;});
            tks.forEach((tk,i)=>{tk.style.visibility=i===cur?'visible':'hidden';});
            const pop=cl((age-d.tokens[cur])/5), s=1.5-0.5*back(pop);
            tks[cur].style.transform='scale('+s+')';
            const inT=cl(age/6); el.style.opacity=String(Math.min(inT*2,out));
            el.style.transform='translateX('+(-40*(1-ease(inT)))+'px)'; return;
          }
          if(d.kind==='cap'){const ls=[...el.querySelectorAll('.line')];let cur=0;d.lines.forEach((t,i)=>{if(age>=t)cur=i;});
            ls.forEach((l,i)=>{l.style.display=(i===cur&&age>=d.lines[0])?'flex':'none';});}
          tks.forEach((tk,i)=>{const a=age-d.tokens[i];
            if(a<0){tk.style.opacity='0';return;}
            const p=cl(a/5), s=d.kind==='bubble'?1:(1.45-0.45*back(p));
            tk.style.opacity=String(cl(a/2)); tk.style.transform='scale('+s+')';});
          if(d.kind==='hook'){
            const p=cl(age/7), s=0.55+0.45*back(p), shake=age<14?Math.sin(age*2.7)*10*(1-age/14):0;
            el.style.transform='scale('+s+') rotate('+(-5*(1-ease(p))+shake*0.25)+'deg) translateX('+shake+'px)';
            el.style.opacity=String(out);
          } else if(d.kind==='bubble'){
            const p=cl(age/7), s=0.5+0.5*back(p);
            el.style.transform='scale('+(s*(0.9+0.1*out))+')'; el.style.opacity=String(Math.min(cl(age/3),out));
          } else if(d.kind==='badge'){
            const p=cl(age/8); el.style.transform='translateX('+(-1100*(1-ease(p)))+'px)'; el.style.opacity=String(out);
          } else { el.style.opacity=String(out); el.style.transform='none'; }
        });
      };`,
  });
  return sealVisualTrack({ id: options.id, programSpaceId: timeline.id, visualIr: "hypit.visual-ir@1",
    presents: [{ id: options.id, span: window.span, stacking: { order: 100, tieBreak: options.id },
      elements: [{ id: "overlay", kind: "program", order: 0, program,
        style: [{ name: "position", value: "absolute" }, { name: "inset", value: 0 },
          { name: "width", value: `${W}px` }, { name: "height", value: `${H}px` }] }, ...children] }] });
}
