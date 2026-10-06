# Kipple reading color schemes (research, round 1)

Status: proposal for agenda items 3 and 4. Contrast ratios computed with WCAG 2.x relative luminance (script run; raw numbers in `ui-color-schemes.json`). Every listed pair passes AA (4.5:1) on the first computation; nothing needed fixing.

## Summary table

| # | Name (alt) | Kind | bg | text | Follows-system role |
|---|---|---|---|---|---|
| 1 | Paper (Chalk) | light | #ffffff | #1b1b1a | default light |
| 2 | Linen (Vellum) | light, off-white | #faf8f3 | #26241f | optional light |
| 3 | Parchment (Manuscript) | sepia | #f4ecd8 | #4a3b28 | optional light |
| 4 | Fern (Meadow) | Kindle-like green | #d8e8d2 | #1f2d1b | - |
| 5 | Cocoa (Umber) | warm dark | #3b2f27 | #eadfd2 | optional dark |
| 6 | Graphite (Dusk) | regular dark | #121212 | #e8e8e6 | default dark |
| 7 | Midnight (Onyx) | OLED true black | #000000 | #e0e0e0 | optional dark |
| 8 | Signal (High Contrast) | accessibility | #ffffff | #000000 | - |

Changes vs prototype: Fern is deeper than the old soft green (#e8f0e4) so it reads as green, like Kindle, rather than tinted white; secondary text is set to clear 5:1 everywhere; Midnight and Signal are new. White, off-white, sepia, brown and dark backgrounds and text are kept from the prototype ("close enough").

## Tokens (hex)

bg, surface (cards), text, text2 (secondary), border, accent, link, unread, star, danger, selection, meta (iOS theme-color, set equal to bg so the status bar blends in).

| Scheme | bg | surface | text | text2 | border | accent | link | unread | star | danger | selection | meta |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Paper | #ffffff | #f6f6f4 | #1b1b1a | #5c5c58 | #dcdcd8 | #1a5fb4 | #1a5fb4 | #1a5fb4 | #b25e00 | #b3261e | #cfe0f7 | #ffffff |
| Linen | #faf8f3 | #f2efe7 | #26241f | #5f5b52 | #e0dbcf | #0f5c8c | #0f5c8c | #0f5c8c | #a85a00 | #b3261e | #d6e6ee | #faf8f3 |
| Parchment | #f4ecd8 | #ece2c8 | #4a3b28 | #6b5a42 | #d9cba8 | #8a4b14 | #7a4310 | #8a4b14 | #9a5200 | #a8321f | #e6d4a6 | #f4ecd8 |
| Fern | #d8e8d2 | #cbdfc4 | #1f2d1b | #3e5237 | #b3ccaa | #1f6b3a | #17603a | #1f6b3a | #8a5a00 | #a52a1f | #b4d6a8 | #d8e8d2 |
| Cocoa | #3b2f27 | #463930 | #eadfd2 | #c4b5a3 | #5a4a3e | #e8a75c | #f0b878 | #e8a75c | #f2c14e | #ff8a80 | #6b5443 | #3b2f27 |
| Graphite | #121212 | #1c1c1e | #e8e8e6 | #a3a3a0 | #2c2c2e | #7cb7ff | #8ec1ff | #7cb7ff | #f2c14e | #ff8a80 | #2b4a6f | #121212 |
| Midnight | #000000 | #0b0b0c | #e0e0e0 | #9a9a9a | #232325 | #6db0ff | #7db9ff | #6db0ff | #f2c14e | #ff8a80 | #1f3b5c | #000000 |
| Signal | #ffffff | #ffffff | #000000 | #2b2b2b | #000000 | #0033cc | #0033cc | #0033cc | #7a4a00 | #a00000 | #ffe066 | #ffffff |

Unread indicator uses the accent as a dot (plus bold title, so it is not color alone). Signal uses a 1px black card border and underlined links.

## WCAG contrast (ratio : 1)

Targets: text, secondary and link 4.5; accent 3 (UI). All pass 4.5.

| Scheme | text/bg | text2/bg | accent/bg | link/bg | link/surface | text2/surface | star/bg | danger/bg | text/selection |
|---|---|---|---|---|---|---|---|---|---|
| Paper | 17.24 | 6.72 | 6.29 | 6.29 | 5.81 | 6.21 | 4.67 | 6.54 | 12.85 |
| Linen | 14.61 | 6.37 | 6.75 | 6.75 | 6.24 | 5.89 | 4.79 | 6.16 | 12.12 |
| Parchment | 9.16 | 5.63 | 5.76 | 6.76 | 6.17 | 5.14 | 4.98 | 5.68 | 7.36 |
| Fern | 11.31 | 6.65 | 5.09 | 5.92 | 5.37 | 6.04 | 4.63 | 5.56 | 9.06 |
| Cocoa | 9.86 | 6.47 | 6.24 | 7.30 | 6.27 | 5.55 | 7.72 | 5.67 | 5.37 |
| Graphite | 15.27 | 7.41 | 8.99 | 10.01 | 9.09 | 6.73 | 11.16 | 8.21 | 7.40 |
| Midnight | 15.91 | 7.46 | 9.30 | 10.26 | 9.61 | 6.99 | 12.51 | 9.20 | 8.65 |
| Signal | 21.00 | 14.16 | 8.95 | 8.95 | 8.95 | 14.16 | 7.48 | 8.42 | 16.11 |

Signal is AAA (7:1) on every text and link pair. Other schemes deliberately stay well below 21:1; extreme contrast is what causes glare and halation.

## Research: what popular readers do

Most apps do not publish hex values. Only what was actually sourced is marked; I did not sample screenshots, so no sampled values are claimed. Some fetches were blocked (403), which limits sourcing.

| App / theme | What is known | Hex | Status |
|---|---|---|---|
| Kindle (iOS/Android/macOS) | Page colors White, Black, Sepia, Green; iOS has an automatic theme switch | Sepia bg #FBF0D9, text #5F4B32 | Third-party blog via search snippet (page not fetchable): estimated. White/Black/Green hex not found. Fern is my estimate of a Kindle-like green, not measured |
| Kindle Paperwhite (device) | warm cream | #f6efdf | third-party paint site, estimated |
| Apple Books | Original, Quiet, Paper, Bold, Calm, Focus; each bundles background, font and spacing; Paper, Bold, Focus are newer | not found | descriptive only |
| Instapaper | Light, sepia, dark, and a true-black theme added in 7.7 for OLED iPhones; reviewer praised it as leaving "nothing between you and the text" | not found | The Sweet Setup review |
| Readwise Reader | Dark theme #000000 bg, #F5F5F5 text; a user-made sepia style uses #f2ebe1 bg | as listed | community pages, estimated |
| client B | Built-in Sepia plus community theme collection; follows system light/dark | not found | descriptive only |
| Kobo, Google Play Books, Libby, Pocket, Matter, Medium, iA Writer, Ulysses, Bear, Safari Reader, client A | Not researched to a citable level in this pass | - | gap |
| Solarized, Nord, Gruvbox | From memory, not fetched: Solarized light #fdf6e3 / #657b83 (about 4.1:1, a common complaint); Nord #2e3440 / #d8dee9; Gruvbox dark #282828 / #ebdbb2, light #fbf1c7 / #3c3836. Cocoa accents (#e8a75c, #f2c14e) are Gruvbox-adjacent | as listed | estimated |

Recurring themes (generic articles, not one authority):
- True black on OLED looks striking and saves power, but bright white on #000 causes halation (glow; worse with astigmatism, roughly 30% of people per one source) and tires eyes on long reads.
- OLED black smear: near-black pixels lag on scroll; sources suggest about #050505 to #121212 avoids it. That argues for offering both Midnight and Graphite.
- Advice converges on muted text (#e0e0e0 to #e8e8e8) rather than #fff on dark.
- Sepia is liked for evenings and paper feel; complaints are low contrast (Solarized-style) and muddy yellow casts.

## Notes

**OLED true black.** Midnight is #000 with #e0e0e0 text (15.9:1, deliberately under pure white to limit halation). Cards are #0b0b0c, barely distinct from bg, so the #232325 border carries separation. If smear shows while scrolling, Graphite is the fallback; both stay available.

**Follow system.** Proposal: "Follow system" maps light to a chosen light scheme and dark to a chosen dark scheme, and the owner picks each half of the pair (light: Paper, Linen or Parchment; dark: Graphite, Midnight or Cocoa). Defaults Paper / Graphite. Use `prefers-color-scheme` with a `matchMedia` listener so it switches live, and update `<meta name="theme-color">` on every change (media-qualified tags for system mode; a single JS-set tag for explicit picks).

**Auto-night / schedule.** Parking lot. A PWA cannot know sunset without location; a fixed clock window is simple. Recommend deferring: follow-system plus iOS's own Auto appearance schedule covers it for free.

**Images in dark themes.** Card image placeholders use the `surface` token (Midnight #0b0b0c with border, Graphite #1c1c1e), never bright gray, so loading does not flash. Dim images in dark schemes with `filter: brightness(.85) contrast(.95)` (about 15%), lifted on open/tap, and off for Signal. Do not invert. Transparent diagrams that vanish on dark get a light plate only when needed. Skip `mix-blend-mode: multiply` on sepia/Fern in round 1.

**Accessibility.** Signal is white/black, underlined links, black 1px borders, yellow selection. A dark high-contrast variant (#000 / #fff) is possible later.

## Questions for the owner

1. Kindle iOS green: match it closely? A screenshot would let me sample it; Fern is an estimate.
2. Is Fern (deeper) right, or keep the softer #e8f0e4?
3. Keep both Paper and Linen, or drop one to reach 7 schemes?
4. Cocoa: a real dark option in follow-system, or a manual warm night theme only?
5. Follow system: fixed Paper/Graphite pair, or user-selectable pair as proposed?
6. Midnight text #e0e0e0, or slightly brighter (#ececec)?
7. Image dimming in dark themes on by default, with a toggle?
8. Auto-night schedule in the parking lot, OK?
9. Accent: blue everywhere, or a warm Kipple identity color?
10. Names OK, or prefer the alternates?
