# Anti-Patterns + Pre-Delivery Checklists

Referenced by `team-uiux-master.md`. Load on demand during review and before finalizing proposals.

## Anti-Patterns (BANNED)

### Visual
- No emojis as structural icons — use SVG icons (Lucide, Heroicons, Phosphor)
- No pure black (`#000000`) — use off-black (Zinc-950, Charcoal)
- No oversaturated accents — desaturate to blend with neutrals
- No excessive gradient text on large headers
- No neon/outer glows — use inner borders or tinted shadows

### Layout
- No generic 3-column equal card layouts — use asymmetric grid or zig-zag
- No horizontal scroll on mobile
- No `h-screen` for heroes — use `min-h-[100dvh]`

### Content
- No generic placeholder names ("John Doe", "Acme Corp")
- No AI copywriting cliches ("Elevate", "Seamless", "Unleash", "Next-Gen")
- No broken Unsplash links — use reliable placeholders

---

## Pre-Delivery Checklists (MUST verify before finalizing)

### Visual Quality
- [ ] No emojis used as icons
- [ ] Consistent icon family and style throughout
- [ ] Semantic theme tokens used (no raw hex in components)
- [ ] Press states don't shift layout bounds

### Responsive
- [ ] Verified on 375px (small phone) + landscape
- [ ] Safe areas respected for headers and bottom bars
- [ ] Content readable on large devices (no edge-to-edge paragraphs)

### Dark/Light Mode
- [ ] Both themes designed together (not one as afterthought)
- [ ] Contrast verified independently for each theme
- [ ] Dividers/borders visible in both themes

### Forms (when applicable)
- [ ] Visible labels (not placeholder-only)
- [ ] Error messages near field with recovery guidance
- [ ] Required field indicators
- [ ] Mobile input height ≥ 44px
- [ ] Confirm before destructive actions

### Interaction States (from output format)
- [ ] Loading states defined (skeleton/shimmer, not spinner)
- [ ] Empty states designed with guidance text + action
- [ ] Error states with inline feedback + recovery path
- [ ] Disabled states visually distinct (opacity 0.38–0.5)
- [ ] Success feedback (checkmark, toast, color flash)

### Performance
- [ ] Animations use transform/opacity only
- [ ] Images use WebP/AVIF with lazy loading
- [ ] Lists with 50+ items use virtualization
- [ ] No layout-shifting animations
