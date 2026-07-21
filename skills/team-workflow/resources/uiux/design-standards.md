# UI/UX Design Standards

Detailed standards referenced by `team-uiux-master.md`. Load on demand when proposing design modifications.

## Typography

- Display/Headlines: `tracking-tighter leading-none`, distinctive font choices
- Body: `text-base leading-relaxed max-w-[65ch]`
- Font scale: consistent system (e.g., 12 14 16 18 24 32)
- Line-height 1.5–1.75 for body text
- **ANTI-SLOP**: Avoid generic fonts. Recommend distinctive, characterful alternatives
- Serif fonts are BANNED for Dashboard/Software UIs — use high-end Sans-Serif

## Color Calibration

- Max 1 accent color. Saturation < 80%
- **THE AI-PURPLE BAN**: Purple/blue gradient aesthetic is strictly banned
- Use neutral bases (Zinc/Slate) with high-contrast singular accents
- Define semantic color tokens (primary, secondary, error, surface, on-surface)
- Dark mode uses desaturated/lighter tonal variants, not inverted colors
- All foreground/background pairs MUST meet 4.5:1 (AA) contrast minimum

## Layout & Spatial Composition

- Unexpected layouts: asymmetry, overlap, diagonal flow, grid-breaking elements
- **ANTI-CENTER BIAS**: Centered hero sections banned when variance is high — use split screen, left-aligned, or asymmetric structures
- Use 4pt/8dp incremental spacing system
- Mobile-first breakpoints (375 / 768 / 1024 / 1440)
- Generous negative space OR controlled density — never mediocre middle ground

## Motion & Animation

- Duration 150–300ms for micro-interactions; complex transitions ≤400ms
- Use transform/opacity only; NEVER animate width/height/top/left
- Every animation MUST express a cause-effect relationship, not decoration
- Spring/physics-based curves for natural feel
- Exit animations shorter than enter (~60–70% of enter duration)
- Respect `prefers-reduced-motion`

## Backgrounds & Visual Details

- Create atmosphere and depth — never default to solid colors
- Gradient meshes, noise textures, geometric patterns, layered transparencies
- **NEVER** use generic AI aesthetics: overused fonts, cliched color schemes, predictable layouts

## Accessibility Standards (CRITICAL — Priority 1)

| Rule | Standard |
|------|----------|
| Color contrast | ≥ 4.5:1 normal text, ≥ 3:1 large text |
| Focus states | Visible focus rings (2–4px) on all interactive elements |
| Alt text | Descriptive alt for meaningful images |
| Aria labels | `aria-label` for icon-only buttons |
| Keyboard nav | Tab order matches visual order; full keyboard support |
| Color not only | Don't convey info by color alone — add icon/text |
| Reduced motion | Respect `prefers-reduced-motion` |
| Dynamic type | Support system text scaling without layout breakage |

## Touch & Interaction Standards (CRITICAL — Priority 2)

| Rule | Standard |
|------|----------|
| Touch target | ≥ 44×44pt (iOS) / 48×48dp (Android) |
| Touch spacing | ≥ 8px gap between touch targets |
| Hover vs tap | Use click/tap for primary interactions; never rely on hover alone |
| Loading feedback | Disable button during async; show spinner or progress |
| Tap feedback | Visual feedback within 100ms of tap |
| Press feedback | Subtle scale (0.95–1.05) on press for tappable elements |
