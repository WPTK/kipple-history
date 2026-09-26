# UI principles and accessibility for Kipple

Research only. Nothing here changes a decision in CLAUDE.md. Sources: lawsofux.com (all 30 laws),
Deibler/universal-design-principles (42 principles, five plugin groups), romanlava/universal-rules
(cognition, behavior, gestalt, interaction, robustness, data, a11y/WCAG 2.2/COGA, content), and the
local ui-ux-pro-max skill data (ux-guidelines.csv, pro-rules.md). ui-styling and design-system skills
were loaded; they add nothing beyond: semantic tokens (never raw hex), Radix/shadcn focus and ARIA
behavior, `dark:` parity. Note: the two GitHub repos are index-style, so their detail is thinner than
lawsofux; where they add value it is noted.

## Part 1. Rule set (checklist)

### Apply

| Law / principle | Rule | Kipple decision |
|---|---|---|
| Fitts's law | Big, near targets for frequent actions | Min 44x44pt hit area on every tappable (visual icon may be smaller, pad the hit box). Primary actions (next, star, mark read) in the bottom third; thumb reach. 8px min gap between adjacent targets. |
| Hick's law / choice overload | Fewer choices per menu | Reading menu max ~7 items, grouped. Font list shows 4 curated "families" up front, rest behind "More fonts". Settings grouped into sections, not one long list. Progressive disclosure for per-feed overrides. |
| Miller / chunking / working memory | Group, do not count | Lists chunk by day headers ("Today", "Yesterday"), feed folders collapsed by default, no more than ~5 top-level nav destinations. Do not literally limit to 7 items. |
| Jakob's law / mental model | Match apps people already use | Follow Reeder/NNW/Feedly conventions: swipe right = mark read, swipe left = star, tap card = open, pull to refresh, back = swipe from left edge (do not override). Standard iOS share sheet. |
| Doherty threshold | Respond under 400 ms | Every tap gets visible feedback in under 100 ms. Optimistic UI for read/star/unread: update instantly, queue the write, roll back with a quiet toast only on failure. Skeletons over spinners for list load. Reserve image space (no layout shift). |
| Postel's law | Liberal in, conservative out | Accept messy input: OPML variants, feed URLs without scheme, site URL (autodiscover feed), pasted whitespace. Output strict: clean Reader API responses, normalized HTML after sanitizing. |
| Peak-end rule | Nail the peak and the end | End state: "You're all caught up" screen when the unread list empties (calm, one line, maybe last-refresh time). Peak: reading view typography. Errors end gracefully (retry, never a dead end). |
| Aesthetic-usability | Pretty reads as usable | Typography and spacing polish is worth spending on; the reading view is the product. |
| Cognitive load / Occam / Tesler | Remove what does not earn its place | One density preset, few toggles, sensible defaults; complexity that cannot go away (feed errors, retention) lives in Settings, not the main flow. |
| Law of proximity, common region, similarity | Group by space and boundary | Card = image + title + source + time grouped tightly; more space between cards than inside. Same style = same kind of control (all toggles look the same). |
| Selective attention / Von Restorff | One accent draws the eye | Unread indicator is the only accent in a list; do not bold or color anything else. Accent color reserved for state and the primary action. |
| Serial position | First and last are remembered | Bottom bar: put the two most-used actions at the ends; oldest/newest ordering explicit. |
| Goal-gradient / Zeigarnik | Show progress toward done | Unread count that ticks down, "n left" while reading through a feed, resume where I stopped (scroll position and last-open article). No streaks or gamification (non-goal). |
| Paradox of the active user | Nobody reads manuals | No onboarding tour. Empty states carry one line of help and the single next action. |
| Flow | Do not interrupt reading | No modals during reading, no popups, no auto-refresh that reorders the list under the thumb (new items go behind a "n new" pill). |
| Pareto | 80% of use is 20% of features | Reading view, mark read, star, next/prev, refresh, add feed. Everything else is secondary chrome. |
| Prägnanz / uniform connectedness | Simplest reading of the layout wins | Simple card shapes; connect a title to its metadata visually; avoid decorative borders. |
| Deibler: feedback, error prevention, visibility of status | Confirm every action, offer undo, show state | Undo toast (5-8 s) instead of confirm dialogs, for mark all read, unstar, delete feed (soft delete). Show refresh state and last-updated. |
| Deibler: consistency, signifiers | Same word, same place | One vocabulary: "Read/Unread", "Star", "Feed", "Folder". Icon plus label where the icon is ambiguous (text label on the top-level nav). |
| Deibler: stress testing | Empty, error, slow | Design the empty list, failing feed, offline, and 10k-item states explicitly. |

### Dropped (do not apply)

- Cognitive bias, Parkinson's law, Pareto-as-marketing, Choice architecture for pricing: no pricing, no funnel, single user.
- Merely exposure, emotional design, brand voice: no brand, no marketing.
- Data-ink/data density (romanlava "Data"): only relevant if the stats screen grows charts (phase 4).
- Loss aversion/behavioral-economics group: would push toward dark patterns (streaks, nudges); non-goal.

### Conflicts and tradeoffs

1. Jakob (swipe conventions) vs motor accessibility: swipe is expected but every swipe needs a visible button equivalent (WCAG 2.5.1/2.5.7). Resolve: swipe is a shortcut, never the only path.
2. Feedly-style image-rich cards vs Hick/cognitive load and vs data cost: images up front are the look decision; keep exactly one image per card, fixed aspect ratio, lazy load, text truncation consistent.
3. 44pt targets vs dense lists: a "compact" density cannot shrink hit areas below 44pt; it reduces visual padding only if hit area is padded back (pseudo-element).
4. Optimistic UI vs Reader API consistency: instant local state, but rollback path must exist; SSE reconciliation must not flip an item the user just changed (last-writer-wins by timestamp).
5. Undo toast vs VoiceOver: toasts vanish before a screen reader finishes; keep them in an `aria-live` region and extend the timeout when a screen reader or reduced-motion is detected, or use a persistent "Undo" button until the next action.
6. Ecosystem convention (fixed 16px min body) vs Dynamic Type: size in `rem`; never `px` for text; allow layout to reflow at 200%.
7. the owner's "one density preset" vs WCAG 1.4.12 (text spacing overrides): the reader must survive user stylesheets overriding spacing; it does not need to expose four spacing sliders. Use one reading-spacing preset plus font size.
8. Peak-end "all caught up" celebration vs no-notifications/no-gamification: keep it quiet, one line.
9. Reduced clutter vs discoverability: hiding features helps cognition but hurts Jakob; hide only secondary chrome, never core actions.

## Part 2. Accessibility feature set

Baseline: WCAG 2.2 AA. iOS Safari PWA realities: no OS-level Dynamic Type link from web (Safari text-size "aA" and Settings > Display > Text Size only affect Safari, not standalone PWA in every case; assume rem plus in-app size control); `prefers-reduced-motion`, `prefers-contrast`, `prefers-color-scheme`, `forced-colors` (not on iOS) supported; haptics through Web Vibration API are NOT available on iOS Safari; standalone PWA has no browser zoom UI, so `maximum-scale` must never be set; `speechSynthesis` exists but voice quality and behavior are restricted.

Effort S/M/L. Where: S = settings, R = reading menu, A = automatic (follows OS).

### Vision

| Feature | Detail | Effort | Where | Phase |
|---|---|---|---|---|
| Semantic structure | Landmarks (`header`, `nav`, `main`, `aside`), one `h1` per view, article as `<article>` with heading hierarchy, list of items as `<ul>`/`role=list` with real `<a>`/`<button>` (not clickable divs), labeled icon buttons (`aria-label`), `aria-pressed` on star, `aria-current` on the selected feed | M | A | 2 |
| Live regions for SSE | One polite `aria-live` region announcing "12 new items" (debounced, never per-item); never move focus or reorder under the user; "n new" pill is a focusable button | S | A | 2 |
| Focus management | Move focus to article heading on open, restore to list item on close; skip link; no keyboard trap in sheets/dialogs (Radix does most); focus not obscured by sticky bars (WCAG 2.4.11) via `scroll-padding` | M | A | 2 |
| Text scaling | All text in `rem`, layout reflows to 320 CSS px at 200% (1.4.4, 1.4.10); in-app text size slider (say 5 steps) in the reading menu; no fixed-height text boxes | S | R | 2 |
| Reduced motion | `prefers-reduced-motion`: no parallax, no slide transitions (cross-fade or none), no auto-playing GIF/animated images (pause via poster) | S | A | 2 |
| Contrast | Body 4.5:1 and UI/icon/focus 3:1 in every theme, including sepia, soft green, brown, OLED dark; check muted/secondary text specifically (the usual failure). Add automated check of theme tokens in tests | M | A (theme tokens) | 2 |
| High contrast | `prefers-contrast: more` bumps text to max-contrast pair, adds real borders on cards, thicker focus ring. Offer nothing manual. `forced-colors` mostly irrelevant on iOS but costs little: use system colors for focus and borders, avoid background images carrying meaning | S-M | A | 3 |
| Color-blind safe | Never color alone: unread = dot plus bold weight (or filled vs hollow icon shape), starred = filled vs outline icon, error = icon plus text. Accent choice must differ in lightness, not just hue (red/green pair check in sepia and soft green) | S | A | 2 |
| Dyslexia-friendly font | See below. Recommend Atkinson Hyperlegible Next as the one added face | S-M | S | 3 |
| Spacing controls | See below. Do not add four sliders | S | R | 2-3 |
| Alt text and images | Show feed-provided `alt`; when absent, decorative `alt=""` for card thumbnails duplicating the title; article images keep alt; do not synthesize alt (no AI) | S | A | 2 |
| Zoom | Never disable pinch-zoom; viewport `width=device-width, initial-scale=1` only | S | A | 2 |

Dyslexia font notes:
- Bundled fonts that help: Atkinson-like clarity comes from distinct letterforms (I/l/1, b/d/p/q). Of the current list, Inter and Source Sans 3 have moderately distinct forms; Literata and Source Serif 4 are readable with open apertures; Gentium Book Plus is open and legible. None are designed for dyslexia or low vision. Evidence for "dyslexia fonts" is mixed; spacing and size matter more than the face.
- Atkinson Hyperlegible Next: SIL OFL 1.1, released 2025 by the Braille Institute, variable weight, expanded language coverage. Fits the "bundled, self-hosted" decision; roughly 100-250 KB per variable woff2 (verify on download; subset to Latin to cut it). Cost is small.
- OpenDyslexic: license is OFL-style free but the font is heavy on personality, evidence of benefit is weak, and its metrics look odd in long text. Not recommended; only add if the owner asks. woff2 about 100-200 KB.
- Recommendation: add Atkinson Hyperlegible Next to the font list, labeled "Easy to read", in the sans group, and let it participate in the normal font picker. No separate "dyslexia mode".

Line, letter, word spacing vs "one density preset":
- Keep the single density preset for lists. For the reading view offer one "Reading spacing" 3-step control (Snug / Normal / Roomy) that moves line-height (1.5 / 1.65 / 1.8), paragraph gap, and a small letter-spacing (0 / 0.01em / 0.02em) together. That satisfies 1.4.12 need without four sliders. Not required for conformance: only that the layout tolerate user overrides (no clipping, no fixed heights).
- Line length: cap at 65-75ch; column width control is not needed on phone.

### Hearing

| Feature | Detail | Effort | Where | Phase |
|---|---|---|---|---|
| Embedded video | Feeds carry iframes (YouTube, Vimeo). Do not autoplay; sandboxed iframe; captions are the provider's; on YouTube append `cc_load_policy=1` if the owner wants captions on by default | S | S (one toggle, optional) | 3 |
| No sound-only cues | The app makes no sounds; keep it that way | none | - | - |
| Haptics | iOS Safari has no Vibration API; iOS PWA cannot do haptics reliably. Visual feedback (state change, toast) is the only channel. Do not promise haptics | none | - | Parking lot |
| Podcast / audio enclosures | Out of scope (RSS mostly text); show a plain link to the enclosure | S | A | Parking lot |

### Motor

| Feature | Detail | Effort | Where | Phase |
|---|---|---|---|---|
| Target size | 44x44pt hit area for all controls, 8px gaps (exceeds WCAG 2.5.8's 24 px) | S | A | 2 |
| Swipe alternatives | Every swipe action has a button in the item's overflow menu and in the reading view toolbar (2.5.1, 2.5.7) | M | A | 2 |
| Single-pointer | No path-based or multi-finger gestures; no drag-only reorder (folders: move up/down buttons or "Move to..." sheet) | S | A | 2 |
| Keyboard | Full keyboard operation (iPad keyboard, desktop): j/k next/prev, o open, s star, m toggle read, / search, ? shows shortcuts; visible focus ring 2 px, 3:1, never removed; `:focus-visible` | M | A (shortcuts list in a help sheet) | 2 |
| One-handed reach | Primary actions in the bottom bar; top area holds only titles; sheets slide from the bottom; large Back also as swipe from edge | M | A | 2 |
| Undo instead of confirm | Undo toast for mark all read, unstar, delete feed, unsubscribe; confirm dialogs only for irreversible (delete all data, remove account) | M | A | 2 |
| Timing | Long-press is a shortcut only (500 ms, not required); no timed interactions; toast undo window 6 s, with pause on focus/press (WCAG 2.2.1 spirit) | S | A | 2 |
| Scroll behaviors | Mark-read-on-scroll must be a setting, off by default, since it is an unintended action risk and breaks stats (already excluded from stats) | S | S | 2 |
| Pointer cancel | Actions fire on release (pointerup) not press, so slips can be cancelled by dragging off | S | A | 2 |

### Cognitive

| Feature | Detail | Effort | Where | Phase |
|---|---|---|---|---|
| Predictable navigation | Same bottom bar and back behavior on every screen, no layout that moves after load, no auto-reorder of the list (new items behind a pill) | M | A | 2 |
| Reduce clutter | A "Simple view" toggle that hides thumbnails/snippets/counts in lists and secondary chrome. Note: overlaps with the density preset. Recommend folding into one "Article list" choice (Cards / Compact / Titles only) rather than a separate mode | S | S | 3 |
| Plain language | Sentence-case labels, verbs for buttons ("Mark all as read"), errors say what happened and what to do ("Couldn't reach example.com. Kipple will try again at 3:30 PM.") | S | A | 2 |
| Reader mode extraction | Already in scope via readability; that is itself the biggest cognitive aid | - | - | 2 |
| Save reading position | Return to the same article and scroll offset | S | A | 2 |
| Consistent icons | Same icon = same meaning everywhere, with tooltips/labels in the desktop layout | S | A | 2 |

### Read aloud (Web Speech API)

- `speechSynthesis` works in Safari and the PWA on iOS, using system voices. Caveats: iOS Siri/"Enhanced" and "Premium" voices are only available if the user downloaded them (Settings > Accessibility > Spoken Content > Voices) and may not all be exposed to web pages; default compact voices sound robotic; speech stops when the app goes to background or the screen locks (no reliable background playback); long utterances get cut off in older iOS (chunk text by sentence/paragraph and queue); `pause`/`resume` are flaky; `onboundary` word events are unreliable so word highlighting is best-effort. No Media Session lock-screen controls for TTS.
- Alternative: iOS built-in "Speak Screen" / Safari Reader "Listen to page" already reads the page with better voices and lock-screen support; document it as the fallback and keep the in-app feature minimal.
- Design: a "Listen" button in the reading menu; play/pause, skip paragraph, speed (0.8x to 1.5x), voice picker filtered to the device's `en` voices with a note "Better voices: Settings > Accessibility > Spoken Content". Chunk by paragraph; highlight the current paragraph (not word). Uses only the client; no server cost, respects the "no AI features" non-goal.
- Effort M. Where: R for controls, S for default voice and speed. Phase 3 (do not block phase 2). Ship as beta with the caveats above.

## Phase summary

- Phase 2 (build in from the start; cheap now, costly to retrofit): semantics and landmarks, focus management, rem text with in-app size, reduced motion, contrast in all themes, never-color-only, 44pt targets, swipe alternatives, keyboard shortcuts, undo instead of confirm, live region for new items, plain-language copy, reading position, pinch-zoom.
- Phase 3 (with themes/fonts/PWA): Atkinson Hyperlegible Next, reading spacing control, `prefers-contrast` and forced-colors, article list layout choice (folds "reduce clutter"), read aloud, video caption default.
- Parking lot: haptics (unsupported on iOS), OpenDyslexic, podcast/audio playback, manual high-contrast theme, custom letter/word spacing sliders.

## Proposed "Accessibility" settings section

Kept to six controls. Everything else follows the OS or is always on.

| Label | Type | Help text |
|---|---|---|
| Text size | 5-step slider (also in the reading menu) | Makes all text larger or smaller. Also follows your zoom. |
| Easy-to-read font | Toggle, or an "Easy to read" entry in the font picker | Switches to Atkinson Hyperlegible, a font designed for clear letter shapes. |
| Reading spacing | Snug / Normal / Roomy | Changes space between lines and paragraphs. |
| Reduce motion | Follow system / On / Off | Turns off slides and fades. Follows your iPhone setting by default. |
| Mark as read while scrolling | Toggle (off) | Marks items read as they scroll past. Off by default so nothing gets marked by accident. |
| Listen to articles | Toggle plus voice and speed | Adds a Listen button to articles. Voices come from your iPhone. |

Automatic, no setting: contrast and high-contrast follow the OS; focus rings, labels, live announcements, 44pt targets, undo toasts, keyboard shortcuts, and button alternatives to swipes are always on. A single line under the section: "Kipple follows your iPhone's text, motion and contrast settings."

## Questions for the owner

1. Is a "Listen" (read aloud) button worth phase 3, given iOS voice caveats, or is Speak Screen good enough for you?
2. Add Atkinson Hyperlegible Next to the bundled fonts (OFL, small)? Or hold the font list at the current eleven?
3. Reading spacing as three steps (Snug/Normal/Roomy) acceptable, or should it be fully folded into the single density preset?
4. Should mark-read-on-scroll exist at all, and if so, off by default?
5. Swipe mapping: right = mark read, left = star (Reeder-like)? Or a different mapping?
6. Undo window: 6 s toast, or a persistent Undo until the next action?
7. Keyboard shortcuts: are you okay with Reeder/NNW-style j/k/o/s/m bindings for iPad or desktop use?
8. Do you want "Titles only" as a list layout choice (Cards / Compact / Titles only) in phase 3?
9. Should embedded YouTube captions default to on?
10. Do you use, or want to test with, VoiceOver, Larger Text or Increase Contrast on your own phone so we have a real check before phase 2 closes?
