# Design — Alva Demo

A locked design system for this app. Every page redesign reads this file before
emitting code. Do not regenerate per page — extend or amend this file when the
system needs to grow.

## Genre
editorial

## Macrostructure family
Pages within a family share the family's shape; they vary only in component archetypes.

- Marketing pages: Specimen (large display face, hairline rules, editorial grid)
- App pages: Index Columns (dense, information-first lists, minimal chrome)
- Content pages: Long Document (asymmetric layout, deep focus on readable typography)

## Theme
- `--color-paper`   oklch(98% 0.01 256)
- `--color-paper-2` oklch(96% 0.01 256)
- `--color-ink`     oklch(22% 0.02 258)
- `--color-ink-2`   oklch(45% 0.01 258)
- `--color-rule`    oklch(90% 0.01 256)
- `--color-accent`  oklch(58% 0.20 256)
- `--color-accent-ink` #fff
- `--color-focus`   oklch(58% 0.20 256)
- `--color-danger`  oklch(50% 0.20 20)
- `--color-danger-surface` oklch(97% 0.02 20)
- `--color-danger-border` oklch(90% 0.04 20)
- `--color-warning` oklch(60% 0.16 65)
- `--color-warning-surface` oklch(97% 0.02 65)
- `--color-warning-border` oklch(90% 0.05 65)
- `--color-success` oklch(55% 0.14 150)
- `--color-success-surface` oklch(97% 0.02 150)
- `--color-success-border` oklch(90% 0.04 150)

## Typography
- Display: "Playfair Display", serif, weight 600, style normal
- Body: "Inter", sans-serif, weight 400
- Mono: "JetBrains Mono", monospace, weight 400
- Display tracking: -0.02em
- Type scale anchor: --text-display = clamp(2.5rem, 5vw, 4.5rem)

## Spacing
4-point named scale. The values are in `tokens.css`. Pages must use named
tokens (`var(--space-md)`), never raw values.

## Motion
- Easings: cubic-bezier(0.16, 1, 0.3, 1) named `--ease-out`
- Reveal pattern: none (Editorial is silent and static)
- Reduced-motion fallback: opacity-only, ≤ 150 ms.

## Microinteractions stance
- silent success
- hover delay 800 ms · focus delay 0 ms
- no overshoots, no bounces

## CTA voice
- Primary CTA: sharp corners (0px radius), solid fill, uppercase tracking
- Secondary CTA: sharp corners, hairline outline only, transparent fill

## Per-page allowances
- Marketing pages MAY use enrichment (Tier-B SVG).
- App pages MUST NOT use enrichment — function carries the page.
- Content pages: typography only.

## What pages MUST share
- The wordmark / logotype.
- The accent colour and its placement (≤ 5 % per viewport).
- The display + body fonts.
- The CTA voice (button shape, border-radius, padding rhythm).
- Section heading rhythm (numeral + label + display heading pattern).

## What pages MAY differ on
- Macrostructure within the page-type family.
- Hero archetype (within the family's allowance).
