# ui-gestures-and-layouts

Research date 2026-09-25. Read-only research; no source changes. Agenda 5 (gestures) and agenda 6 (layouts).

Evidence labels: **S** = cited web source fetched or returned by search this session; **K** = background knowledge of the apps (not re-verified this session, treat as "believed", check before relying). Sources are thin for per-app details: search returned few forum threads. Gaps are called out rather than papered over.

Sources used:
- Swipe-actions in client A are user-configurable (read / star / send-to): see the macworld and macsparky coverage of client A 5
- Two-finger swipe for mark above/below in client A 3: https://www.redmondpie.com/client-a-3.0-for-iphone-released-with-brand-new-ui-gestures-and-more-hands-on-review/
- Article-swipe complaint ("a feature that fires by accident 100% of the time"): https://www.goodreads.com/author_blog_posts/7972124-swipe-right-to-read-something-else
- Swipe/scroll mark-read is a recurring feature request and design tension: https://github.com/pietheinstrengholt/rssmonster/issues/277
- Undo-window approach to accidental swipes (The Current): https://www.terrygodier.com/current
- iOS edge-swipe cannot be disabled in an installed web app; JS touchstart preventDefault only works in some cases; manifest opt-out proposal: https://github.com/ionic-team/ionic-framework/issues/22299 , https://github.com/w3c/pointerevents/issues/358 , https://pqina.nl/blog/blocking-navigation-gestures-on-ios-13-4/ , https://news.ycombinator.com/item?id=29296713
- Feedly view modes (title-only, magazine, cards, full article; per-feed view; mobile density compact/comfortable): https://docs.feedly.com/article/276-how-do-i-change-the-views-of-my-feeds-and-source , https://devhd.wordpress.com/2013/11/14/the-new-title-only-and-card-views/
- Inoreader views (card, list, expanded, magazine, column): https://www.inoreader.com/blog/2015/04/presenting-magazine-view-clear-all.html , https://www.inoreader.com/blog/2015/02/inoreader-for-ios-30-debuting-card-view.html
- Readwise Reader mobile toolbar (swipe between documents vs classic triage buttons): https://docs.readwise.io/reader/docs/faqs/navigation , https://docs.readwise.io/reader/docs/faqs/appearance
- Existing repo research on client A sync behaviour: `docs/research/client-a.md`

---

# Part A. Gestures and navigation patterns

## A1. Hard iOS constraints (S)

- **Left-edge horizontal swipe = back/forward in Safari and in installed PWAs.** Cannot be disabled by a web app. `touchstart` + `preventDefault()` near the edge reportedly works in Safari tab mode only, unreliably in PWAs and Chrome iOS. A manifest opt-out has been proposed but is not shipped. **Design rule: nothing Kipple does may start within ~20-24 px of the left screen edge.** Row swipe must tolerate the OS gesture firing on the same touch (i.e. treat any touch that starts in the edge zone as not ours).
- Consequence: "swipe from left edge to return to list" is free only if Kipple uses real history entries (`pushState` per article) so the OS back gesture lands on the list. Recommended: article view is a history entry; list scroll position and selection restored on back.
- **Pull-to-refresh vs overscroll**: Safari tab has native rubber-band; an installed PWA has none of the native PTR, so a custom PTR is needed and it fights `overscroll-behavior`. Set `overscroll-behavior-y: contain` on the scroller, implement PTR only when `scrollTop === 0` and the touch began at the top, with a visible threshold (about 70 px) and a spinner. Pull in Safari tab mode may double-trigger with native bounce; test both.
- 44x44 pt minimum target (Apple HIG); 24 px CSS is the WCAG 2.2 AA floor, use 44.
- WCAG 2.2 SC 2.5.1 (Pointer Gestures) and 2.5.7 (Dragging Movements): every path/multipoint gesture and every drag needs a single-pointer alternative. Row swipe is a single-finger path gesture, so it must have a button or menu equivalent. This is the basis of the "every gesture has a button" rule.

## A2. Pattern catalogue

Discoverability: H high, M medium, L low. Accident risk: same scale.

| Pattern | What it does | Who uses it | Disc. | Accident risk | Accessible alternative | Known complaints |
|---|---|---|---|---|---|---|
| Row swipe, partial reveal (buttons appear, tap to commit) | Reveals 1-3 action buttons | iOS Mail/Messages/Notes, client A (K), NNW (K), Gmail (K, full swipe only) | M (M/H after first use; peek-on-first-run helps) | Low: commit needs second tap | VoiceOver custom actions, long-press menu, toolbar buttons | Few; mostly "too many buttons" |
| Row full swipe (past threshold commits, no tap) | One-shot destructive-ish action, e.g. archive, mark read | Mail, Gmail, client A, Inoreader, Feedly mobile (K), Apollo (K) | M | Medium-high on scroll flicks, especially diagonal scrolling | Same as above + undo toast | Undo missing is the complaint; The Current uses a few-second undo window (S) |
| Article horizontal swipe (next/prev article) | Advance/return between articles | Feedly mobile, client A (K), Pocket/Reader in some modes (S: Readwise "swipe between documents" option) | L-M | **High**: collides with horizontal scroll in code blocks/tables/images, with edge back gesture, and with text selection | Next/prev buttons, `j`/`k`, toolbar arrows | The "annoying" one: "fires by accident 100% of the time" (S, goodreads blog). the owner's own annoyance matches |
| Swipe from edge = back | Return to list | iOS system (Safari, apps), Apollo (K) | H | System-owned; can't change | Back button in header | Web apps cannot suppress it (S). Double navigation when app also handles the swipe (S) |
| Tap header/status bar = scroll to top | Scroll to top | iOS system on status bar; Twitter/X, Apple News (K) | M | Low | "Top" button on long lists; `g g` / Home key | Web: iOS does not deliver status-bar tap to web content in a PWA reliably (K) |
| Pull to refresh | Refresh | Universal (Mail, Twitter/X, Reddit, client A, Feedly) | H | Low-medium (accidental at top, cost small) | Refresh button; `r` key... see key map | Custom PTR jank in PWAs (S, iOS constraints) |
| Long-press context menu | Menu with all actions | iOS system (context menus), Twitter/X, Apple Mail (K), client A (K) | L-M | Low (haptic + preview) | Same actions in overflow menu | Conflicts with text selection in article body; only use on list rows, not article text |
| Double-tap | Like/star, zoom | Instagram/Twitter like (K); client A no | L | Medium (tap-then-navigate delay: single-tap must wait ~300 ms, hurting responsiveness) | Star button | Adds latency to every single-tap; not recommended on rows |
| Tap zones (left/right/center) | Page turn, chrome toggle | Kindle, Apple Books, Kobo (K); Readwise (K for EPUB) | M | Low for paginated content; high for scrolling text (taps on links) | Buttons; volume keys not available to web | Left-handed users want configurable zones; accidental page turns when holding device |
| Volume-key page turn | Page turn | Kindle Android, Kobo (K) | L | Low | n/a | Not available to web/PWA on iOS |
| Mark-read-on-scroll | Items scrolled past become read | client A (new, 2024, scroll-based tracking, S via repo doc), Feedly (option), Inoreader (option), NNW no (K) | L (invisible) | **High**: users report "where did my unread go" (S, rssmonster issue shows both demand and tension) | Setting off by default; explicit mark-read button | Trust erosion; Kipple non-goal counts it as not a read for stats (CLAUDE.md) |
| Mark above/below as read | Bulk read | client A two-finger swipe (S), NNW menu (K), Feedly (K), Inoreader (K) | L as gesture, M as menu | Medium | Overflow menu, `Shift+A` etc. | Swipe variant hard to discover; menu variant fine |
| Swipe-up-from-bottom mark-all-read (client A option) | Mark all read | client A (S Macworld/Sweet Setup) | L | High | Header button with confirm | Only if user configured |
| Pinch/zoom of list density | Change layout | Rare | L | n/a | Settings | Skip |
| Pull-down on article to close | Dismiss sheet | Apple News, Twitter/X media (K) | M | Medium (fights scroll at top) | Close button | Only appropriate for modal sheets |

Gaps: I did not find a single authoritative source per app for full-swipe thresholds or haptics; values below are the design recommendation, not measurements of those apps. MacRumors/Reddit "accidentally marked read" threads were not surfaced by search; the sources above are the ones that were actually returned. Worth a manual pass on r/rss and r/client-a if the owner wants more evidence.

## A3. Laws

- **Fitts**: large, edge-anchored targets are fast; supports bottom-anchored thumb-zone toolbar on iPhone, big row hit areas, and full-width swipe (target is huge). Also supports NOT using the tiny top-right header controls as the only path. Cuts against edge gestures on iOS: the left edge is contested.
- **Jakob**: users expect iOS Mail-style swipe (leading swipe = positive/read toggle, trailing = secondary/destructive), pull-to-refresh, and edge back. Supports keeping row swipe mail-like and NOT inventing a novel article-swipe. Cuts against tap zones outside a book-reader context (nobody expects them in a feed list).
- **Hick**: fewer choices = faster. Supports at most 2 actions per swipe direction (or 1 full + 1 partial), keeping long-press for the long tail, and hiding rare actions in an overflow menu.
- Not law, but relevant: error prevention + recoverability (undo) matter more than gesture cleverness. Every destructive-ish swipe gets an undo.

## A4. Recommended gesture map: three schemes

Common to all: nothing starts in the 24 px left edge; every gesture has a button; haptic (light impact via `navigator.vibrate` is not available on iOS Safari, so haptics are **not achievable in a web app**; use a brief visual snap and the undo toast instead. Note this to the owner.); undo toast 5 s, bottom, above the toolbar; respect `prefers-reduced-motion`.

### Scheme 1: Conservative (recommended default)

- List row: **partial swipe only**, no full-swipe commit. Swipe right reveals one button (Read/Unread toggle). Swipe left reveals two (Star, Save/Open original). Threshold ~64 px to latch the reveal, tap the button to commit. Zero accidental commits. Slightly slower than full swipe; Fitts fine because the button is large.
- Article: **no horizontal swipe at all.** Next/previous via toolbar buttons and `j`/`k`. Return via header back button and OS edge-back (article is a history entry).
- Pull to refresh: on, with threshold 70 px, refreshes all feeds (matches manual-refresh decision; API clients never trigger fetches).
- Scroll-to-top: header tap on the title area; also a Top button that appears after scrolling far.
- Long-press on row: menu with all actions incl. mark above/below as read, mark all read (with confirm).
- Double-tap: none. Tap zones: none. Mark-read-on-scroll: off by default, setting available (and per CLAUDE.md never counts as reading in stats).

### Scheme 2: client A-like

- List row: full swipe right = toggle read (commit at ~40% of width, partial reveal beforehand), full swipe left = star. Configurable per direction (client A lets users choose, S). Undo toast mandatory.
- Article: horizontal swipe from a non-edge start (>=40 px in) = next/previous, disabled when the touch begins inside a horizontally scrollable element (pre, table, figure with overflow) and when text is selected. Off by default; an opt-in setting.
- Two-finger swipe mark above/below is skipped (multi-touch path gesture, low discoverability); menu item instead.
- Risk: fast but accident-prone; direct source of the "annoying swipe" complaint category (S).

### Scheme 3: Tap-zone / Kindle-like (reading mode only)

- Applies to the article view only; list stays as Scheme 1.
- Tap right 30% of viewport = scroll down one page (minus 10% overlap), left 30% = up one page, centre 40% = toggle chrome. Links and images inside the article always win (tap zones only on non-interactive text).
- No swipes in article. Volume keys unavailable on iOS web.
- Risk: accidental page scroll when tapping to focus/select text, left-handed configurability. Discoverable only through an onboarding hint. Lower fit for RSS reading than for books. Offer as opt-in "page mode", not the default.

**Recommendation:** Scheme 1 as default, with Scheme 2's full swipe available as a setting per direction and Scheme 3 as an opt-in reading mode. This matches the owner's stated annoyance with article advance/return swipes: none by default.

## A5. Action to gesture / key / visible button

Keyboard: j = next item, k = previous, s = star toggle, o = open original in new tab, r = ... see note, m = read/unread toggle (planned set is j/k/s/o/r/m). Note: `r` is ambiguous (refresh vs read); recommendation `r` = refresh, `m` = mark read toggle, matching the planned list. Extra proposed keys are marked (+).

| Action | Gesture | Key | Visible button |
|---|---|---|---|
| Next item | none (S1); article swipe opt-in (S2) | `j` | Down/next arrow in article toolbar |
| Previous item | none (S1); article swipe opt-in (S2) | `k` | Up/prev arrow in article toolbar |
| Open article from list | tap row | `Enter` / `o`? see next row | Row itself |
| Open original in browser | long-press row > menu | `o` | "Open original" in article toolbar / row menu |
| Star / unstar | swipe left reveal (S1) or full swipe (S2) | `s` | Star icon on row (magazine/cards) and in article toolbar |
| Mark read / unread | swipe right reveal (S1) or full swipe (S2) | `m` | Check/circle icon in article toolbar; row menu |
| Refresh all | pull to refresh | `r` | Refresh button in list header |
| Return to list | OS edge-back (history entry), header tap on back label | `Esc` or `u` (+) | Back chevron in article header (44 pt) |
| Scroll to top | tap header | `g` `g` (+) / `Home` | "Top" floating button after long scroll |
| Mark above as read | long-press menu | `Shift+A` (+) | Row menu, list overflow menu |
| Mark below as read | long-press menu | `Shift+B` (+) | Row menu, list overflow menu |
| Mark all read (in view) | none | `Shift+M` (+) with confirm | List overflow menu, confirm dialog |
| Toggle layout | none | `v` (+) cycles compact/magazine/cards | Layout menu in list header |
| Row context menu | long-press | `.` (+) or context menu key | Ellipsis on row (hover on desktop; overflow in swipe-left reveal) |
| Undo last swipe | none | `z` (+) | Undo button in toast |
| Mark read on scroll | passive | none | Settings toggle (default off) |
| Page down in article (S3) | tap right zone | `Space` | none required, scroll works normally |

## A6. Details for the list row swipe

- Partial: right swipe reveals 1 button, ~80 px wide, latches at 64 px, snaps back if released earlier. Left swipe reveals 2 buttons, ~80 px each.
- Full swipe (opt-in): commit at 40% row width or a velocity threshold, indicator colour and icon change at the commit point so the user sees what will happen before release; releasing before threshold cancels.
- Lock direction after 8-10 px so vertical scroll wins on a diagonal drag; use `touch-action: pan-y` on rows.
- Ignore any touch that starts <24 px from the left edge.
- Undo toast: "Marked read. Undo" for 5 s; undo is per action, not stack.
- Accessibility: VoiceOver custom actions (`role="listitem"` with `aria-describedby` hint plus the same actions in a row menu), keyboard focus row gets the same actions, buttons always reachable without gestures (WCAG 2.5.1).

---

# Part B. Layouts

## B1. Feedly reference layout (S for view names and options; measurements K/approximate)

Sourced from Feedly docs and blog: four views (title-only, magazine, cards, full article), per-feed and per-category view setting, mobile adds Compact / Comfortable density. Exact pixel measurements below are approximate from memory of the web UI and should be confirmed with a screenshot before being treated as targets. I could not fetch a screenshot in this session, so the table is described, not measured.

| View | Layout | Image | Metadata | Text | Unread/read | Hover/expand |
|---|---|---|---|---|---|---|
| Title-only | One row per article, single line title | None | Source name (or favicon) + relative time on the same row, right side | Title only, one line, truncated | Unread: bold/dark title; read: lighter grey, not bold | Hover shows quick actions (save, mark read); click expands inline into full article (K) |
| Magazine | Row: small square/landscape thumbnail on the right (K, ~ 100-160 px), text left | Right-aligned thumbnail | Source + author + time above or below the title | Title 2 lines, excerpt ~2-3 lines | Same read dimming; image dims too | Hover actions row; click opens inline |
| Cards | Grid of cards, large lead image on top | Wide 16:9-ish crop at card top | Source + time under the image | Title 2-3 lines, excerpt short | Read cards dimmed | Hover actions |
| Full article | Full text inline | inline | - | full | - | - |

Mobile: cards and magazine stack single column; density compact reduces padding and excerpt.

## B2. Comparison with alternatives (mostly K; treat as approximate)

| App | Layout options | Notable choices |
|---|---|---|
| client A (Classic) | Text list with optional thumbnails, magazine-ish; icon + source, title 2 lines, excerpt 1-2 lines; separate article view | Very compact, swipe configurable (S); light image use |
| Inoreader | Card, list, expanded, magazine, column (S) | Most options; sometimes cluttered; column = 3-pane |
| client B | Compact text list with small leading favicon, unread dot, 1-3 line preview; 3-pane on iPad/Mac; no lead images by default | Deliberately plain; see `docs/research/client-b.md` |
| Apple News | Big lead-image cards, mixed sizes, editorial grid | Curated; not a feed list |
| Readwise Reader | Library list rows with small thumbnail, title, site, reading time, progress; mobile toolbar swipe-between-docs vs classic buttons (S) | Triage-oriented, shows reading time |
| Pocket | List rows with thumbnail right, title, domain, read time; grid option | Simple |

## B3. Kipple layout set (recommendation)

Three modes, chosen in a header menu, remembered globally, overridable per feed/folder later (Feedly does per-feed, S). Default: **magazine**, because the owner named Feedly as reference and magazine gives the best scanning to image balance on a phone. Option: cards.

### Common rules

- Row hit area at least 44 pt tall; whole row is the tap target.
- Metadata row (all modes): favicon 16 px, source name (truncate), relative time ("3h"), star indicator if starred, optional reading-time. Author only in cards/desktop.
- Unread: title in primary colour, weight 600, small accent dot (or left accent bar) in the leading position; Read: title in secondary text colour, weight 400, image opacity 0.6. Do not rely on colour alone (dot/weight also differ) for accessibility. Starred: filled star in metadata row.
- Section headers by day ("Today", "Yesterday", "Mon, Sep 22"), sticky, ~28 px, in Eastern time; separates in the scroll model as real rows so virtualization treats them as items.
- Image-less fallback: text-only row at full width (magazine) or a coloured/favicon block placeholder card of the same aspect ratio only in cards mode so grid alignment holds; magazine drops the thumbnail slot entirely and lets text run full width. Never show a broken or letter placeholder in magazine mode.
- Image loading: `loading="lazy"`, `decoding="async"`, explicit `width`/`height` to avoid layout shift, `object-fit: cover`; failed images collapse to the image-less layout. Images are hotlinked or proxied; a proxy decision is separate (privacy and referrer). Note for the owner.

### Specs

| | Compact list | Magazine (default) | Cards |
|---|---|---|---|
| 375 px width | single column, row height 56-64 px | single column, row ~96-112 px | single column, card ~ 300-340 px |
| Desktop width | single column max 720 px (or list pane 360-420 px in 2-pane) | 2-pane list ~420 px, or single column max 800 px | grid 2-3 columns, card min 280 px, max 360 px |
| Image | none, optional 24 px favicon only | thumb right, 88x88 (1:1) on phone, 128x96 (4:3) desktop, radius 8 | top, 16:9, full card width (343 px wide by 193 px tall at 375 minus 16 px gutters) |
| Title clamp | 1 line (2 on tap-to-expand? no; keep 1) | 3 lines phone, 2 lines desktop | 3 lines |
| Excerpt | none | 2 lines phone, 2-3 desktop, stripped HTML, ~140-200 chars | 3 lines, ~200 chars |
| Metadata | source + time on one line under title, 12 px | favicon + source + time above title, 12 px secondary | favicon + source + time under image, plus author on desktop |
| Density | ~14 rows visible on iPhone | ~6-7 rows | ~1.5 cards |
| Actions | swipe / menu; on desktop hover shows star/read icons at right | same | icons row in card footer on desktop; swipe on phone |

Excerpt: take the first N chars of sanitized plain text server-side (store once at ingest, do not compute in the client), skip leading boilerplate like "The post ... appeared first on".

### Virtualization for 10k+ items

- Windowed list is required; render only visible rows plus overscan (about 8 rows). Candidate: `@tanstack/react-virtual` (dynamic measurement) since magazine rows vary in height with and without image and with clamped lines. Avoid `content-visibility: auto` as the sole strategy (scroll bar jumpiness on iOS).
- Prefer fixed or predictable row heights per mode: compact fixed, magazine two variants (with/without image), cards fixed 16:9 image plus clamped text; makes scroll restore and jump-to-top deterministic.
- Data paging: keyset cursor by (published, id), page size 50-100, prefetch when within 2 screens of the end; never load 10k rows to the client. Day headers derived from the loaded window.
- Preserve scroll position, selected item and window when returning from an article (history entry + saved offset), and when marking-read removes an item from an "unread only" view: fade to read state, remove on next refresh rather than immediately, so rows do not jump under the finger.
- Image cost: cap concurrent image decodes, use small `srcset`/thumbnail variants if a proxy is added; keep memory bounded on iPhone.
- Selection/focus for `j`/`k` must survive virtualization (track by item id, scroll into view on move).

## B4. Options summary

- Layout default: **A) magazine (recommended)**, B) compact list, C) cards.
- Gestures: **1) conservative (recommended)**, 2) client A-like opt-in, 3) tap-zone reading mode opt-in.

---

# Summary and questions for the owner

See the final message; the same questions:

1. Confirm no article-level horizontal swipes by default (my recommendation), with only next/prev buttons and `j`/`k`.
2. Row swipe: partial-reveal only (safest) or full swipe with undo toast? Which direction should do read/unread and which star?
3. `r` = refresh and `m` = mark read (I assume this), correct?
4. Haptics are not available to iOS web apps; is visual snap plus undo toast acceptable?
5. Default layout magazine? Should layout be global or per feed/folder?
6. Image handling: hotlink lead images, or proxy/cache them through Kipple (privacy, speed, hotlink blocking)?
7. Mark-read-on-scroll: keep as an off-by-default setting, or drop it from the plan?
8. Do you want a one-time first-run "peek" animation to teach swipe reveal?
