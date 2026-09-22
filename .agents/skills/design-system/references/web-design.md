# Web system extraction and evolution

Scope to one product surface before generalizing across an organization. Start with existing DESIGN.md, CSS variables, theme configuration, component variants and stories. Exclude generated bundles unless source is unavailable.

Capture actual role mappings rather than only hex values: page surface, text, action, focus, error, disabled. Keep primitive values separate from semantic and component aliases when that reflects the product. Match the existing token format. DTCG support requires validating the chosen DTCG version, not just using `$type` and `$value` keys.

Typography needs full fallback stacks, measured/computed sizes, line-height, weights and locale behavior. Distinguish declared fonts from loaded fonts. For spacing, list actual recurring values and exceptions; do not normalize a 6px rhythm to 4px without recording a proposed migration. Preserve source color formats, including OKLCH, instead of forcing hex-only conversion.

Component contract: anatomy, variants, content constraints, default/hover/focus/active/disabled/loading/error states, keyboard/focus behavior and responsive changes. If a state was not observed, mark it unknown or proposed. A screenshot cannot prove a working button, focus trap, form error or loading state.

Screen inventory: name and stable ID, implementation status, viewport/theme/locale, screenshot or source evidence, principal task, controls and related components. Flows connect these IDs with trigger, data/state transition, feedback and recovery. Do not invent a 14-screen game or dashboard because a generic inventory contains them.

Governance proportional to project size:
- identify canonical token files and owner;
- explain decisions and exceptions;
- give renames/removals a migration map;
- record which consumers were tested at which revision;
- retain user work and record proposed changes separately.

The DESIGN template follows the eight prose categories inspected in Google's alpha spec. Our companion inventory and evidence rules are project additions. No current parser in this skill validates full Google frontmatter or full DTCG compatibility.
