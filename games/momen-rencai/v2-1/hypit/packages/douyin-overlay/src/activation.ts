import { assertAttributes, assertEmptyElement, canonicalize, createMarkupSurfaceHostFacet, sameType, sealGraphFragment, textAttribute } from "@hypit/hypit/author-kit";
import type { ComponentPackage, FragmentOperation, ModuleManifest, StructuredSurfaceHandler, SurfaceResolvedReference, TypeRef } from "@hypit/hypit/author-kit";
import { compositionTypes } from "@hypit/hypit/composition";
import { mediaTypes } from "@hypit/hypit/media";
import type { FontStackRef } from "@hypit/hypit/media";
import type { Timeline } from "@hypit/hypit/timeline";
import { timelineTypes } from "@hypit/hypit/timeline";
import { spatialTypes } from "@hypit/hypit/spatial";
import type { CanvasSpace } from "@hypit/hypit/spatial";
import { assertTemporalInstantFor, temporalTypes } from "@hypit/hypit/temporal";
import type { TemporalInstant, TemporalWindow } from "@hypit/hypit/temporal";
import { createTemporalInstantProjection, createTemporalWindowProjection, resolveTemporalContext,
  temporalContextAttributeVocabulary, temporalInstantAttributeNames, temporalInstantAttributeVocabulary,
  temporalWindowAttributeNames, temporalWindowAttributeVocabulary } from "@hypit/hypit/temporal-markup";
import { renderOverlay, CUE_KINDS } from "./render.js";
import type { Cue, OverlayOptions } from "./render.js";

const module = { name: "@momen/douyin-overlay", version: "1" } as const;
const types = Object.fromEntries(["Options", "Cue", "Cues"].map(name => [name, { module, name }])) as Record<"Options" | "Cue" | "Cues", TypeRef>;
const producers = Object.fromEntries(["empty", "append", "render"].map(name => [name, { module, name }])) as Record<"empty" | "append" | "render", { module: typeof module; name: string }>;

export const manifest: ModuleManifest = { format: "hypit.module@1", ...module,
  dependencies: [compositionTypes.visualTrack, mediaTypes.fontStack, timelineTypes.track, spatialTypes.canvas, temporalTypes.instant].map(type => ({ module: type.module })),
  types: Object.values(types).map(type => ({ name: type.name })), capabilities: [], producers: [
    { name: "empty", inputs: [], outputs: [{ name: "cues", type: types.Cues }], needs: [] },
    { name: "append", inputs: [{ name: "cues", type: types.Cues }, { name: "cue", type: types.Cue },
      { name: "at", type: temporalTypes.instant }, { name: "timeline", type: timelineTypes.track }], outputs: [{ name: "cues", type: types.Cues }], needs: [] },
    { name: "render", inputs: [{ name: "cues", type: types.Cues }, { name: "options", type: types.Options },
      { name: "timeline", type: timelineTypes.track }, { name: "canvas", type: spatialTypes.canvas },
      { name: "window", type: temporalTypes.window }, { name: "font", type: mediaTypes.fontStack },
      { name: "display", type: mediaTypes.fontStack }], outputs: [{ name: "track", type: compositionTypes.visualTrack }], needs: [] },
  ],
};

const inline = <T>(record: { value: { kind: string; value?: unknown } } | undefined): T => {
  if (record?.value.kind !== "inline") throw new Error("Overlay inputs must be inline values.");
  return record.value.value as T;
};
const value = (data: unknown) => ({ kind: "inline" as const, value: canonicalize(data) });

const component: ComponentPackage = { producers: [
  { producer: producers.empty, handler: () => ({ outputs: { cues: value([]) }, needs: {} }) },
  { producer: producers.append, handler: ({ inputs }) => {
    const cue = inline<Omit<Cue, "at">>(inputs.cue), at = inline<TemporalInstant>(inputs.at);
    const cues = inline<Cue[]>(inputs.cues);
    assertTemporalInstantFor(at, { subjectId: cue.id, space: inline<Timeline>(inputs.timeline) });
    if (cues.some(item => item.id === cue.id)) throw new Error(`Overlay cue id "${cue.id}" is repeated.`);
    return { outputs: { cues: value([...cues, { ...cue, at }]) }, needs: {} };
  } },
  { producer: producers.render, handler: ({ inputs }) => ({ outputs: { track: value(renderOverlay(inline<Timeline>(inputs.timeline),
    inline<CanvasSpace>(inputs.canvas), inline<TemporalWindow>(inputs.window), inline<FontStackRef>(inputs.font),
    inline<FontStackRef>(inputs.display), inline<Cue[]>(inputs.cues), inline<OverlayOptions>(inputs.options))) }, needs: {} }) },
] };

/** Parses "2.4s", "600ms" or "18f" into seconds (frames need the frame rate, resolved at render). */
const duration = (raw: string): { seconds?: number; frames?: number } => {
  const m = /^(\d+(?:\.\d+)?)(s|ms|f)$/.exec(raw.trim());
  if (!m) throw new Error(`Cue "for" must look like 2.4s, 600ms or 18f; got "${raw}".`);
  const n = Number(m[1]);
  return m[2] === "f" ? { frames: n } : { seconds: m[2] === "ms" ? n / 1000 : n };
};
const optional = (element: { attributes: Record<string, unknown> }, name: string): string | undefined => {
  const raw = element.attributes[name];
  return typeof raw === "string" ? raw : undefined;
};

export const decodeSurface: StructuredSurfaceHandler = ({ element, resolveReference }) => {
  assertAttributes(element, ["id", "timeline", "canvas", "font", "display", ...temporalWindowAttributeNames]);
  const id = textAttribute(element, "id"), context = resolveTemporalContext({ element, resolveReference });
  const window = createTemporalWindowProjection({ id: `${id}.window`, subjectId: id, element, ...context, resolveReference });
  const reference = (name: string, type: TypeRef): SurfaceResolvedReference => {
    const raw = element.attributes[name];
    if (typeof raw !== "object" || raw.kind !== "reference") throw new Error(`${name} must be a reference.`);
    const found = resolveReference(raw.path);
    if (found === undefined || !sameType(found.type, type)) throw new Error(`${name} has the wrong Type.`);
    return found;
  };
  const options: OverlayOptions = { id };
  const records = [...window.records, { id: `${id}.options`, type: types.Options, value: value(options), range: element.range }];
  const components = [...window.components], fragments = [...window.fragments];
  const inputs = [{ name: "timeline", type: timelineTypes.track }, { name: "canvas", type: spatialTypes.canvas },
    { name: "font", type: mediaTypes.fontStack }, { name: "display", type: mediaTypes.fontStack },
    { name: "window", type: temporalTypes.window }, { name: "options", type: types.Options }];
  const bindings: Record<string, SurfaceResolvedReference["ref"]> = { timeline: context.timeline.ref,
    canvas: reference("canvas", spatialTypes.canvas).ref, font: reference("font", mediaTypes.fontStack).ref,
    display: reference("display", mediaTypes.fontStack).ref, window: window.ref, options: { kind: "record", id: `${id}.options` } };
  const input = (name: string) => ({ kind: "fragment-input" as const, name });
  const operation = (name: string) => ({ kind: "fragment-operation" as const, operation: name });
  const operations: FragmentOperation[] = [{ id: "empty", producer: producers.empty, inputs: {}, result: { kind: "output", name: "cues" } }];
  let previous = "empty", index = 0;
  const cueAttributes = ["id", "kind", "text", "for", "side", "y", "size", "color", "label", ...temporalInstantAttributeNames];
  for (const child of element.children) {
    if (child.kind === "text") { if (child.value.trim()) throw new Error("Overlay Scene accepts Cue children."); continue; }
    if (child.name.split(":").at(-1) !== "Cue") throw new Error("Overlay Scene accepts Cue children.");
    assertAttributes(child, cueAttributes); assertEmptyElement(child);
    const cueId = textAttribute(child, "id"), kind = textAttribute(child, "kind");
    if (!(CUE_KINDS as readonly string[]).includes(kind)) throw new Error(`Cue kind must be one of ${CUE_KINDS.join(", ")}.`);
    const at = createTemporalInstantProjection({ id: `${id}.${cueId}`, subjectId: cueId, element: child, ...context, resolveReference });
    records.push(...at.records); components.push(...at.components); fragments.push(...at.fragments);
    const key = `cue-${++index}`;
    const cue = { id: cueId, kind, text: optional(child, "text") ?? "", hold: duration(textAttribute(child, "for")),
      side: optional(child, "side") ?? "right", y: optional(child, "y") === undefined ? null : Number(optional(child, "y")), size: optional(child, "size") === undefined ? null : Number(optional(child, "size")),
      color: optional(child, "color") ?? "", label: optional(child, "label") ?? "" };
    records.push({ id: `${id}.${key}`, type: types.Cue, value: value(cue), range: child.range });
    inputs.push({ name: key, type: types.Cue }, { name: `${key}-at`, type: temporalTypes.instant });
    bindings[key] = { kind: "record", id: `${id}.${key}` }; bindings[`${key}-at`] = at.ref;
    operations.push({ id: key, producer: producers.append, inputs: { cues: operation(previous), cue: input(key), at: input(`${key}-at`), timeline: input("timeline") }, result: { kind: "output", name: "cues" } });
    previous = key;
  }
  if (!index) throw new Error("Overlay Scene requires a Cue.");
  operations.push({ id: "render", producer: producers.render, inputs: { cues: operation(previous), options: input("options"),
    timeline: input("timeline"), canvas: input("canvas"), font: input("font"), display: input("display"), window: input("window") }, result: { kind: "output", name: "track" } });
  const fragment = sealGraphFragment({ inputs, operations, exports: [{ name: "track", type: compositionTypes.visualTrack, root: operation("render") }] });
  return { records, fragments: [...fragments, fragment], components: [...components,
    { id, fragment: fragment.id, inputs: bindings, outputs: { track: `${id}.track` }, range: element.range }], exports: [`${id}.track`] };
};

const declaration = { name: "scene", tag: "Scene", mode: "structured" as const,
  outputs: [compositionTypes.visualTrack, timelineTypes.track, temporalTypes.window, temporalTypes.instant, temporalTypes.windowSpec, temporalTypes.instantSpec, ...Object.values(types)],
  vocabulary: { summary: "Douyin-style overlay layer for a vertical game-clip video: hook titles, word-pop narration captions, chat bubbles, a death counter, badges and colour flashes, each on its own authored or semantic cue.", attributes: [
    ...temporalContextAttributeVocabulary, ...temporalWindowAttributeVocabulary,
    ...["id", "canvas"].map(name => ({ name, kind: "expression" as const, required: true, summary: name })),
    { name: "font", kind: "expression" as const, required: true, summary: "FontStack for captions, bubbles and badges (Chinese + emoji)." },
    { name: "display", kind: "expression" as const, required: true, summary: "FontStack for hook and CTA display titles." },
  ], children: [{ tag: "Cue", cardinality: "many" as const, summary: "One overlay element and the instant that starts it.", attributes: [
    { name: "id", kind: "literal" as const, required: true, summary: "Unique cue id." },
    { name: "kind", kind: "literal" as const, required: true, summary: `One of ${CUE_KINDS.join(", ")}.` },
    { name: "text", kind: "literal" as const, required: false, summary: "Tokens separated by |. token@1.2 appears 1.2 s after the cue starts; *token is emphasised; a lone / breaks the line." },
    { name: "for", kind: "literal" as const, required: true, summary: "How long the cue stays, e.g. 2.4s, 600ms or 18f." },
    { name: "side", kind: "literal" as const, required: false, summary: "bubble: left (NPC) or right (player)." },
    { name: "y", kind: "literal" as const, required: false, summary: "Vertical centre as a fraction of canvas height." },
    { name: "size", kind: "literal" as const, required: false, summary: "Font size in canvas pixels." },
    { name: "color", kind: "literal" as const, required: false, summary: "flash colour or badge accent." },
    { name: "label", kind: "literal" as const, required: false, summary: "bubble sender name or counter label." },
    ...temporalInstantAttributeVocabulary,
  ] }], ports: [{ name: "track", type: compositionTypes.visualTrack, summary: "The complete overlay layer." }],
    example: '<overlay:Scene id="ov" timeline={program.timeline} canvas={canvas} font={font} display={display} during="program"><overlay:Cue id="hook" kind="hook" text="这个NPC|/|杀了我*99次" at="0s" for="2.4s"/></overlay:Scene>',
  },
};
export const hypitPackage = { format: "hypit.node-package@1" as const, modules: [{ manifest }], components: [component],
  hostFacets: [createMarkupSurfaceHostFacet({ module, declaration, handler: decodeSurface })] };
export default hypitPackage;
