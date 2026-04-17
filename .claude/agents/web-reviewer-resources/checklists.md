# Web Quality Checklists

Full checklists for the 5 categories. Load on demand when reviewing.

## Category 1: Accessibility (Weight 25%, 16 items)

### Semantic HTML
- [ ] Single `<h1>` per page, sequential h2–h6
- [ ] Landmark elements used (`main`, `nav`, `aside`, `footer`, `header`)
- [ ] Lists use `ol`/`ul`/`li` (no div chains for list structures)
- [ ] Buttons are `<button>`, links are `<a>` (not div + onClick)
- [ ] Tables have `thead`/`tbody`/`th` when rendering tabular data

### Keyboard & Focus
- [ ] Every interactive element reachable via Tab
- [ ] Visible focus indicator present (not `outline: none` without replacement)
- [ ] Tab order matches visual order
- [ ] Escape closes modals and popups
- [ ] No keyboard traps (can Tab out of every component)

### ARIA & Labels
- [ ] Images have alt text (meaningful) or `alt=""` (decorative)
- [ ] Form inputs have labels (`label[for]` or `aria-label`)
- [ ] Dynamic content uses `aria-live` regions
- [ ] Icon-only buttons have `aria-label`
- [ ] Error messages linked via `aria-describedby`

### Color & Contrast
- [ ] Text contrast ≥ 4.5:1 (normal) or ≥ 3:1 (large text ≥ 18pt / 14pt bold)
- [ ] Information not conveyed by color alone
- [ ] Focus indicators have ≥ 3:1 contrast

---

## Category 2: Performance (Weight 25%, 16 items)

### Core Web Vitals (measured values REQUIRED)
- [ ] FCP < 1.8s — measured: ___ s
- [ ] LCP < 2.5s — measured: ___ s
- [ ] TBT < 200ms — measured: ___ ms
- [ ] CLS < 0.1 — measured: ___

### Bundle & Loading
- [ ] Bundle ≤ 200KB gzipped per route — measured: ___ KB
- [ ] Code splitting for routes (dynamic imports exist)
- [ ] Tree shaking active (no dead code visible in bundle analyzer)
- [ ] Third-party scripts loaded with `async` or `defer`

### Images & Media
- [ ] Next-gen formats (WebP/AVIF) or framework image optimization
- [ ] Explicit width/height OR aspect-ratio on every `<img>`
- [ ] Lazy loading on below-fold images (`loading="lazy"`)
- [ ] Responsive images (`srcset` or `<picture>`) when needed

### Fonts & CSS
- [ ] `font-display: swap` on every custom font
- [ ] Critical CSS inlined OR preloaded
- [ ] Fonts preloaded (`<link rel="preload" as="font">`)
- [ ] Non-critical CSS is not render-blocking

---

## Category 3: SEO (Weight 15%, 12 items)

### Meta & Structured Data
- [ ] Unique `<title>` (50–60 chars)
- [ ] Unique `<meta name="description">` (120–160 chars)
- [ ] Open Graph tags (`og:title`, `og:description`, `og:image`, `og:type`)
- [ ] JSON-LD structured data for content type (Article/Product/FAQ/Organization)
- [ ] Canonical URL set via `<link rel="canonical">`

### Content Structure
- [ ] Single `<h1>`, sequential hierarchy
- [ ] Meaningful link text (no "click here", no context-less "read more")
- [ ] Alt text on informational images

### Technical SEO
- [ ] Clean URLs (no unnecessary query params)
- [ ] Proper 404 handling
- [ ] `robots.txt` present and correct
- [ ] `sitemap.xml` generated for content pages

---

## Category 4: Design Quality (Weight 20%, 18 items)

### Visual Hierarchy
- [ ] Clear focal point per page/section
- [ ] Consistent 4px/8px spacing grid
- [ ] Logical visual flow (F-pattern or Z-pattern)
- [ ] No visual clutter (adequate whitespace)

### Typography
- [ ] Max 2–3 fonts total
- [ ] Clear type scale (body, h1–h6, caption are distinguishable)
- [ ] Body line-height 1.4–1.6
- [ ] Max body line width ≈ 65–75 characters

### Responsiveness
- [ ] Mobile-first breakpoints
- [ ] Touch targets ≥ 44×44 px
- [ ] No horizontal scroll on mobile
- [ ] Breakpoints are content-based (not pinned to device widths)

### Interaction States
- [ ] Hover state for interactive elements
- [ ] Active/pressed state
- [ ] Disabled state visually distinct + `aria-disabled`
- [ ] Loading state (skeleton or spinner)
- [ ] Error state with clear message + recovery action
- [ ] Empty state with guidance + call to action

---

## Category 5: AI Slop Detection (Weight 15%)

Flag each pattern detected:

- [ ] Purple/violet gradients as primary decoration
- [ ] 3-column feature grid (icon circle + title + description, repeated)
- [ ] Everything centered with no variation
- [ ] Uniform bubbly `border-radius` on all elements
- [ ] Decorative blobs/circles/wavy dividers without purpose
- [ ] Emoji used as design icons (not proper SVG icons)
- [ ] Colored left-border cards as the only card variant
- [ ] Generic hero copy ("Welcome to...", "Unlock the power of...", "Revolutionize your...")
- [ ] Cookie-cutter section rhythm (identical spacing/layout repeated)

**Scoring** (invert — fewer detections = higher score):
- 0–1 detected → 95+
- 2–3 detected → 80–94
- 4–5 detected → 65–79
- 6+ detected → < 65

---

## Overall Score Formula

```
Overall = (A11y × 0.25) + (Performance × 0.25) + (SEO × 0.15) + (Design × 0.20) + (AISlop × 0.15)

Grade mapping:
  90+      → A
  85–89    → A-
  80–84    → B+
  75–79    → B
  70–74    → B-
  65–69    → C+
  60–64    → C
  50–59    → D
  < 50     → F
```
