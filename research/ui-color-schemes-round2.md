# Kipple color schemes, round 2

Base: `ui-color-schemes.md`/`.json` (round 1) and `ui-decisions.md` (authoritative). Paper, Linen, Parchment, Graphite, Midnight and Signal are unchanged. Numbers are computed (WCAG 2.x luminance; raw values in `ui-color-schemes-round2.json`). Thresholds: text, text2, link, danger 4.5:1; accent, unread, star 3:1. Every scheme below passes; the only failures on first pass (Cocoa Mid: text2/surface 4.18, link/surface 4.38, text/selection 4.33) were fixed before the tables.

Token order: bg, surface, text, text2, border, accent, link, unread, star, danger, selection, meta (meta = bg).

## 1. Fern renamed, ranked

| # | Name | Rationale |
|---|---|---|
| 1 | **Directory** | The phone book's green government pages; plain, period-accurate, sits well beside Paper/Linen |
| 2 | Greenbar | Green-striped fanfold computer paper; strong print identity, one word |
| 3 | Ledger | Green accounting ledger paper; already on the owner's list |
| 4 | Registry | Civic/municipal records feel, close to the listings theme |
| 5 | Bulletin | Notice-board and public bulletin paper; a little vague on color |
| 6 | Gazette | Official listings, but reads as newsprint/gray more than green |

Bond was dropped: bond paper is white, so the name says nothing about green.

Softer green, tiny change: bg #d8e8d2 to **#dcead6**, surface #cbdfc4 to #cfe2c8, border #b3ccaa to #b8cfae, selection #b4d6a8 to #b9d9ad. Text and accents are unchanged.

## 2. Cocoa, lighter (two variants)

- **Cocoa Kraft**: kraft-paper mid-tone, dark text on tan (a light-kind scheme).
- **Cocoa Mid**: dark text lifted to a mid-dark brown with light text (still a dark-kind scheme, about 40 percent lighter than the old #3b2f27).

## 3. Gray, paper-themed

**Newsprint** (recommended; warm gray, not blue). Alternatives: Onionskin (thin translucent gray-white, lighter), Carbon Copy, Pewter, Ash.

## 4. New candidates (10)

Accessibility: Foolscap, Tracing, Carbon, Lamplight, Inkwell, Teletype. Pretty: Airmail, Stationery, Tissue, Fountain.

| Scheme | Idea |
|---|---|
| Foolscap | Cream, low glare, neutral charcoal text (not brown, so unlike Parchment). BDA guidance: white "can appear too dazzling"; recommends cream or soft pastel backgrounds ([BDA Style Guide 2023](https://cdn.bdadyslexia.org.uk/uploads/documents/Advice/style-guide/BDA-Style-Guide-2023.pdf?v=1680514568); also summarized in [ResearchGate comparative study](https://www.researchgate.net/publication/347481260_A_Comparative_Study_of_Dyslexia_Style_Guides_in_Improving_Readability_for_People_With_Dyslexia)). Pairs with the Atkinson "Easy to read" font |
| Tracing | Tracing paper, cool near-white. Color-blind-safe accents: blue (accent/link/unread), orange (star), magenta (danger); no red/green pairing anywhere |
| Carbon | Carbon-paper dark version of Tracing: sky blue, amber, pink. Color-blind-safe |
| Lamplight | Warm, low-blue-light night: text #e8cfa6, all accents amber/orange, no cool hues |
| Inkwell | High-contrast dark (Signal's counterpart): white on black, AAA everywhere, white borders |
| Teletype | Yellow on black, cyan links, white star. AAA on text |
| Airmail | Pale blue airmail-letter paper |
| Stationery | Lavender writing paper |
| Tissue | Blush tissue paper, rose accent |
| Fountain | Warm dark navy, fountain-pen blue-black with warm off-white text |

## 5. Tokens

| Scheme | bg | surface | text | text2 | border | accent | link | unread | star | danger | selection | meta |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Directory | #dcead6 | #cfe2c8 | #1f2d1b | #3e5237 | #b8cfae | #1f6b3a | #17603a | #1f6b3a | #8a5a00 | #a52a1f | #b9d9ad | #dcead6 |
| Newsprint | #e6e5e1 | #dbdad5 | #1f1f1d | #4d4d49 | #c4c3bd | #2c5d8f | #23558a | #2c5d8f | #8f5500 | #a82a20 | #c5d3e3 | #e6e5e1 |
| Cocoa Kraft | #d2b48e | #c6a67e | #2b1c0f | #4f3a25 | #ad8d63 | #6b2e0a | #5e2708 | #6b2e0a | #7a4700 | #8f1d12 | #e6cf9f | #d2b48e |
| Cocoa Mid | #58463a | #665244 | #f6eee3 | #e0d2c0 | #7a6552 | #f0b36a | #ffd0a0 | #f0b36a | #f5c85a | #ffb3a6 | #75604d | #58463a |
| Foolscap | #f8f0d6 | #efe6c8 | #2d2a24 | #5a5548 | #dcd2b0 | #24598a | #1f5283 | #24598a | #8f5200 | #a52a20 | #e5d9a8 | #f8f0d6 |
| Tracing | #f7f8fa | #edeff3 | #1a1d21 | #565c66 | #d5d9e0 | #0a5ba8 | #0a5ba8 | #0a5ba8 | #9a4a00 | #a3195b | #cde0f5 | #f7f8fa |
| Carbon | #15181d | #1e2228 | #e6e8eb | #a0a6b0 | #2f353d | #56b4e9 | #74c3f0 | #56b4e9 | #f0b000 | #ff8fc0 | #27476b | #15181d |
| Lamplight | #1d140e | #271b13 | #e8cfa6 | #b89a72 | #3a2a1e | #e39a4a | #eeaa60 | #e39a4a | #f0c060 | #f09078 | #4a3420 | #1d140e |
| Inkwell | #000000 | #000000 | #ffffff | #d9d9d9 | #ffffff | #66b3ff | #66b3ff | #66b3ff | #ffd23f | #ff8080 | #0b3d91 | #000000 |
| Teletype | #000000 | #0d0d00 | #ffe600 | #d4c400 | #ffe600 | #4fd8ff | #4fd8ff | #4fd8ff | #ffffff | #ff8a8a | #4a4400 | #000000 |
| Airmail | #e2ecf5 | #d5e3f0 | #16212e | #435466 | #b8cbde | #1c5490 | #1c5490 | #1c5490 | #8f4a00 | #a82a20 | #c3d8ee | #e2ecf5 |
| Stationery | #ece8f6 | #e0dbef | #211c2e | #52496a | #c9c1e0 | #5a3d9e | #4f3591 | #5a3d9e | #8a4f00 | #a82a3a | #d3c8ee | #ece8f6 |
| Tissue | #f9e9e7 | #f1dbd8 | #3a2424 | #6e4a4a | #e3c3bf | #9b2f5e | #8a2856 | #9b2f5e | #8a4f00 | #b3261e | #f0c9cc | #f9e9e7 |
| Fountain | #16202f | #1e2a3d | #e9e4d8 | #aeb4c0 | #2c3a52 | #8fb8f5 | #9dc0f5 | #8fb8f5 | #f0b660 | #ff9a8f | #2e4870 | #16202f |

Signal keeps its round-1 tokens; Inkwell and Teletype use the border color as a 1px outline, as Signal does. Unread is always a dot plus bold title, never color alone.

## 6. WCAG contrast (ratio : 1), all pass

| Scheme | text | text2 | text2/surf | link | link/surf | danger | accent | star | text/sel |
|---|---|---|---|---|---|---|---|---|---|
| Directory | 11.58 | 6.8 | 6.23 | 6.06 | 5.55 | 5.69 | 5.21 | 4.74 | 9.38 |
| Newsprint | 13.1 | 6.74 | 6.07 | 6.08 | 5.48 | 5.52 | 5.43 | 4.8 | 10.85 |
| Cocoa Kraft | 8.36 | 5.43 | 4.66 | 6.02 | 5.17 | 4.53 | 5.28 | 3.91 | 10.81 |
| Cocoa Mid | 7.76 | 6.02 | 4.96 | 6.28 | 5.18 | 5.21 | 4.83 | 5.65 | 5.16 |
| Foolscap | 12.55 | 6.52 | 5.95 | 7.11 | 6.49 | 6.24 | 6.42 | 5.46 | 10.1 |
| Tracing | 15.92 | 6.34 | 5.85 | 6.43 | 5.93 | 6.94 | 6.43 | 5.89 | 12.55 |
| Carbon | 14.49 | 7.27 | 6.52 | 9.16 | 8.22 | 8.42 | 7.71 | 9.25 | 7.78 |
| Lamplight | 12.0 | 6.82 | 6.31 | 9.11 | 8.43 | 7.74 | 7.76 | 10.71 | 7.71 |
| Inkwell | 21.0 | 14.88 | 14.88 | 9.46 | 9.46 | 8.65 | 9.46 | 14.54 | 10.04 |
| Teletype | 16.57 | 11.7 | 10.88 | 12.6 | 11.72 | 9.25 | 12.6 | 21.0 | 7.82 |
| Airmail | 13.59 | 6.5 | 5.96 | 6.45 | 5.91 | 5.82 | 6.45 | 5.58 | 11.14 |
| Stationery | 13.73 | 6.92 | 6.17 | 7.75 | 6.91 | 5.7 | 6.72 | 5.45 | 10.44 |
| Tissue | 12.24 | 6.51 | 5.79 | 7.08 | 6.3 | 5.55 | 6.02 | 5.58 | 9.56 |
| Fountain | 12.91 | 7.87 | 6.94 | 8.81 | 7.77 | 8.01 | 8.07 | 9.02 | 7.27 |

Cocoa Kraft star is 3.91 (UI threshold 3, passes; star is an icon, not text). Foolscap, Tissue and Lamplight are deliberately below 21:1 to limit glare.

## 7. Color-blind check

Method: token colors simulated with the Machado 2009 matrices (severity 1.0, linear RGB), then CIE76 delta E between the pairs that must stay distinguishable: accent vs star, accent vs danger, star vs danger. Delta E of 15 or more is counted clear (about 2.3 is just noticeable; 15 is comfortably separate at icon size). Numbers below are the worst of the three pairs.

| Scheme | Deutan | Protan | Tritan | Verdict |
|---|---|---|---|---|
| **Tracing** | 46.3 | 32.1 | 15.6 | safe, all three |
| **Carbon** | 37.0 | 16.6 | 15.7 | safe, all three |
| **Inkwell** | 47.3 | 54.7 | 40.5 | safe, all three |
| **Teletype** | 36.2 | 28.6 | 49.3 | safe, all three |
| **Stationery** | 21.2 | 34.3 | 29.6 | safe, all three |
| Fountain | 26.2 | 36.2 | 13.8 | safe for deutan/protan; tritan borderline |
| Graphite / Midnight | 33.3 | 49.5 | 27.7 | safe, all three (round 1) |
| Newsprint | 9.0 | 21.1 | 32.5 | accent vs star weak for deutan |
| Foolscap | 9.6 | 20.7 | 29.7 | star vs danger weak for deutan |
| Airmail | 7.5 | 17.4 | 26.2 | weak for deutan |
| Directory, Lamplight | 9.3, 10.2 | 11.4, 12.8 | 37.1, 7.4 | not claimed |
| Paper / Linen | 14.5 / 11.4 | 25.5 / 23.0 | 25.1 / 27.5 | marginal for deutan |
| Cocoa Kraft, Cocoa Mid, Tissue, Parchment | 2 to 13.5 | 7 to 18 | 4 to 17 | not claimed |
| Signal | 0.6 | 13.0 | 45.6 | star and danger both dark brown/red, nearly identical under deuteranopia |

Findings worth a decision: Signal (round 1) has a real deuteranopia weakness between star and danger; both also differ by icon and label, but I suggest changing Signal's danger to a magenta such as #a0006a if the owner wants Signal fully safe (not applied, Signal is unchanged). Anywhere else, star and danger are never shown by color alone (filled star icon vs error text/icon). "Safe" here means the accent set holds up; it does not replace the non-color cues (bold title plus dot for unread).

Caveat: CIE76 and the Machado model are approximations, and no test with real color-vision-deficient viewers was done.

## 8. Follow-system logic

- **Default pair:** day Paper, night Midnight (the owner's "paper/onyx"; Onyx assumed to be Midnight, please confirm).
- **Custom pair:** Settings offers two independent pickers, "Day theme" and "Night theme".
- **Decision: the day picker lists only light-kind schemes and the night picker only dark-kind schemes.** Reason: `prefers-color-scheme` means the OS is asking for light or dark, and a night theme that is bright would defeat iOS's sunset switch and the low-light purpose. Signal counts as light (day). Cocoa Kraft is light; Cocoa Mid is dark. Any scheme can still be chosen as a fixed manual theme regardless of kind.
- Fixed manual theme turns follow-system off; follow-system is the first entry in the picker.
- Implementation: one `matchMedia('(prefers-color-scheme: dark)')` listener resolves day/night and applies the scheme; the same code sets a single `<meta name="theme-color">` to the resolved scheme's `meta` on load, on change of system appearance, and on every manual pick (live, no reload). The static tag in `index.html` is a Paper/Midnight media-qualified fallback for first paint. Settings are per device.

Picker membership:

- Day (light): Paper, Linen, Newsprint, Parchment, Directory, Cocoa Kraft, Airmail, Stationery, Tissue, Foolscap, Tracing, Signal
- Night (dark): Graphite, Midnight, Cocoa Mid, Fountain, Lamplight, Carbon, Inkwell, Teletype

## 9. Proposed roster and picker order

Kind: L = light, D = dark, A = accessibility (also L or D for the follow-system picker).

| Order | Group | Scheme | Kind | Status |
|---|---|---|---|---|
| 1 | Light | Paper | L | round 1 |
| 2 | Light | Linen | L | round 1 |
| 3 | Light | Newsprint | L | new |
| 4 | Light | Parchment | L | round 1 |
| 5 | Light | Directory | L | Fern renamed, softer |
| 6 | Light | Cocoa Kraft | L | Cocoa rework A |
| 7 | Color | Airmail | L | new |
| 8 | Color | Stationery | L | new |
| 9 | Color | Tissue | L | new |
| 10 | Dark | Graphite | D | round 1 |
| 11 | Dark | Midnight | D | round 1 |
| 12 | Dark | Cocoa Mid | D | Cocoa rework B |
| 13 | Dark | Fountain | D | new |
| 14 | Accessibility | Foolscap (low glare, cream) | A, day | new |
| 15 | Accessibility | Tracing (color-blind safe) | A, day | new |
| 16 | Accessibility | Signal (high contrast) | A, day | round 1 |
| 17 | Accessibility | Carbon (color-blind safe) | A, night | new |
| 18 | Accessibility | Lamplight (warm, low blue) | A, night | new |
| 19 | Accessibility | Inkwell (high-contrast dark) | A, night | new |
| 20 | Accessibility | Teletype (yellow on black) | A, night | new |

That is 20, if the owner keeps both Cocoas. Easy cuts to reach about 16: one Cocoa, Tissue, Teletype, Lamplight overlap.

## Questions for the owner

1. Fern rename: Directory first, or another from the list?
2. Cocoa: Kraft (light tan), Mid (dark brown) or both? If one, the follow-system night list loses or keeps a warm option.
3. Newsprint OK as the gray name?
4. Day/night picker restricted by kind (as decided above), or fully open?
5. Confirm Midnight is the night default (not Graphite).
6. 20 schemes is a lot: trim, or keep the accessibility group collapsed under "More"?
7. Change Signal's danger to magenta to fix the deuteranopia weakness?
8. Teletype (yellow on black) and Lamplight: keep both?
