# ui-layouts-keymap-density-round2

Round 2 research and spec draft, 2026-09-25. No source changes. Inputs: `CLAUDE.md`, and from branch
`design/ui-round-1` (not in the phase-2 working tree; read with `git show`): `docs/ui-decisions.md`
(authoritative), `docs/research/ui-gestures-and-layouts.md`, `ui-principles-and-accessibility.md`; plus
`docs/design.md` for ids, cursors and retention.

Evidence: **D** = the owner decided (ui-decisions.md). **R1** = round-1 file. **K** = background knowledge of
other apps, not re-verified this session (no web fetches were done this round; check before quoting).
**P** = proposal for the owner. Numbers in this file are design proposals, not measurements of other apps.

Global rules carried over: appearance is per device (D); nothing starts within 24 px of the left edge (D);
every gesture has a button (D); no haptics, visual snap plus undo toast (D); mark-read-on-scroll stays a
setting, off by default (D); enabling any option must never break layout (D); text in `rem`, hit areas 44 pt
on coarse pointers.

---

## 1. Layouts

### 1.1 Recommendation

Ship five in phase 2 (per device, one global choice, Magazine default): **Magazine, Cards, Compact,
Inbox, Headlines.** Park three: Columns, Reader list, Expanded stream.

Two concerns are separate and should stay separate in code and settings:

- **Row layout** (what a list item looks like): the five above.
- **Desktop shell** (panes): sidebar | list | reading pane. Setting "Reading pane": Right / Off, default Right
  at container width >= 900 px. Works with Inbox, Magazine, Compact and Headlines. Cards is a grid, so it
  opens the article full width and ignores the pane setting. Inbox simply defaults to Right and its
  desktop spec below assumes it.

Compact and Headlines are the same component with a `lines` parameter (2 vs 1), so the fifth layout is nearly
free. Inbox is the only one with new structure (three-pane, sender/subject/snippet hierarchy).

**Per-folder override:** modestly worth it (photo blogs want Cards, newsletters want Inbox) and cheap if the
data model allows it from day one: setting key `layout` plus optional `layout.folder.<id>` / `layout.feed.<id>`,
resolved feed > folder > global, all per device. Recommend: store the resolution in phase 2, ship the UI for
it in phase 3 (a "Layout for this folder" item in the list header menu with "Use default"). Ask the owner.

### 1.2 Comparison of the candidates

| Layout | Shows | Best for | Density (iPhone rows visible, D3 step) | Verdict |
|---|---|---|---|---|
| Magazine | favicon, source, time, title (3 lines), 2-line excerpt, right thumb, star | Default scanning of mixed feeds (Feedly reference, D) | 6-7 | Ship, default |
| Cards | 16:9 lead image, source, time, title (3), 3-line excerpt, footer actions | Photo/visual feeds, tablets, browsing | 1.5 | Ship |
| Compact | favicon, source and time line, title (1-2 lines), unread dot, no image | Fast triage, NNW/Reeder style | 12-14 | Ship |
| Inbox (email style) | source as bold "sender", title as "subject", 2-line snippet, right time, unread dot, optional thumb; 3-pane on desktop | the owner's request; people who triage like mail; newsletters | 7-8 | Ship |
| Headlines | one line: title, source right or leading, time; no image, no snippet | Huge unread backlogs, "just clear it" sessions | 18-22 phone, 30+ desktop | Ship (Compact variant) |
| Columns (newspaper) | multi-column masonry on wide screens | Wide monitors, browsing | n/a | Park: CSS columns break reading order, keyboard j/k order and virtualization; Inoreader's version is really 3-pane (K), which Inbox already covers |
| Reader list (Readwise, Pocket) | thumb, title, site, reading time, progress bar | Read-later queues | 6 | Park: needs reading-time and progress data Kipple does not track. Reading time is cheap to compute at ingest (words/230) if the owner wants it as an optional metadata chip in Magazine/Inbox instead |
| Expanded stream (Feedly "full article", Inoreader "expanded") | full text inline in list | Short-form feeds | 1 | Park: unbounded row height wrecks virtualization, scroll restore and mark-read semantics |
| Hey/Superhuman split inbox | categories/tabs above one list | Email | n/a | Not applicable; folders already do this |

### 1.3 Specs per layout (phone 375, tablet 768, desktop 1280)

Widths are CSS px. Row heights are at density step D3 and text size 100 % (see section 2 for other steps).
"Container" means the list pane, so layouts respond to their own width via container queries, not viewport
media queries (keeps 200 % text and split view honest).

| | 375 phone | 768 tablet | 1280 desktop |
|---|---|---|---|
| **Magazine** | 1 column, full width, row 112 px: meta line (favicon 16, source, time) over title 3 lines, 2-line excerpt, thumb right 88x88 1:1 r8. No thumb: text runs full width | 2 panes: list 340 + reader (sidebar is a drawer). Row 112 px, thumb 88 | 3 panes: sidebar 240, list 400, reader flex (measure-capped). Row 104 px, title 2 lines, thumb 112x84 4:3. With pane Off: single column max 800 |
| **Cards** | 1 column, image 343x193, card ~320 px | 2 columns, gap 16, card ~360 | grid of 3 (sidebar 240 + 1040 wide: 3 x ~320), card min 280, max 360; pane ignored |
| **Compact** | 1 column, row 56 px: unread dot, meta line (source, time) 12 px, title 1 line, star only when starred | Same, in a 340 list pane beside reader | List pane 360-420 beside reader, row 52 px; hover shows star/read at right |
| **Inbox** | 1 column push nav. Row 88 px: unread dot 8 px leading (or 8 px spacer), line 1 = source bold (weight 700 unread, 500 read) + time right-aligned; line 2 = title (subject, 1 line, weight 600 unread); lines 3-4 = snippet 2 lines secondary; optional thumb 56x56 r8 trailing when present (setting "Thumbnails in Inbox": Auto/Off) | 2 panes: list 320 + reader; rows 88 | 3 panes: sidebar 240, list 380, reader ~660 (measure-capped, centered). Row 84. Selected row filled with the accent surface token; reader shows a header block with source, title, time like a mail header |
| **Headlines** | 1 line row 44 px (touch floor): dot, title (1 line, ellipsis), time right 12 px; source as leading 16 px favicon only. Optional "Show source name" adds a second small line only at D4-D5 | List pane 340, 44 px | Table-like row 32 px on fine pointers: source column 160, title flex, time 64; pane Right optional |

Unread indication is dot AND weight AND color, never color alone (R1). Read rows: secondary text color,
weight normal, thumb opacity 0.6 (no dimming of images in dark themes for other reasons, D: that decision
is about dark-theme image dimming; read-state opacity is a different thing and stays).

Data each layout needs from the list API (one shape for all): `id, feed_id, feed_title, favicon,
title, published/sort_at, read, starred, excerpt (server-computed once, ~200 chars plain), thumb_url
(proxied), reading_minutes (optional)`. Layouts choose which to render; none needs full content.

Inbox-specific rules:

- "Sender" is the feed title; if the item has an author and the feed title is generic (author in title
  is common on multi-author feeds), show `Feed title` only. Author goes in the reader header.
- Snippet skips boilerplate ("The post ... appeared first on") at ingest, same as R1.
- Unread dot lives at the leading edge inside the 44 pt row, not in the 24 px edge zone: dot x = 12..20 px,
  swipe ignore zone is 0..24 px of the *screen*, which the row's left padding (16 px) never reaches into for
  gesture starts, since the row inset is 0 on phone. The dot is decoration; the whole row is the target.
- Desktop keyboard: `j/k` move selection and open it in the reader pane (selection = open, Mail style);
  the row stays in the list. `Enter` moves focus into the reader.

### 1.4 Virtualization note

All five have predictable row heights per (layout, step, has-thumb), so `@tanstack/react-virtual` with
measured but memoized sizes works (R1). Cards use fixed aspect + clamped text. Headlines and Compact are
fixed height. Inbox has two variants (with thumb / without) that are the same height by design (thumb 56 fits
inside the 4 lines), so Inbox is fixed height too.

---

## 2. Density

Two independent scales plus one accessibility switch. All values are tokens on `:root`, per device.

- **Text size** (existing 5 steps, R1): `--kp-scale` = 0.875, 1, 1.125, 1.25, 1.5 applied to `html`
  font-size (16 px base), so every `rem` grows.
- **List density** (rows): D1..D5, default D3.
- **Reading density** (article text): T1..T5, default T3. One control in Settings > Appearance
  "Density" with two rows, "Lists" and "Reading", each 5 steps. A single "Link both" toggle (default on)
  makes one slider move both. Names: **Dense, Snug, Standard, Relaxed, Airy** for both.
- **Accessibility "Roomy text spacing"** (switch, off by default): applies WCAG 1.4.12 spacing on top of
  any step. See 2.4.

### 2.1 Reading text (article body), font size `1.0625rem` (17 px) x scale

| Step | line-height (unitless) | measure `max-width` | paragraph gap (`margin-block-end`) | heading gap above | letter-spacing |
|---|---|---|---|---|---|
| T1 Dense | 1.4 | 78ch | 0.6em | 1.2em | 0 |
| T2 Snug | 1.5 | 72ch | 0.8em | 1.4em | 0 |
| **T3 Standard** | **1.6** | **66ch** | **1em** | **1.6em** | **0** |
| T4 Relaxed | 1.7 | 62ch | 1.25em | 1.8em | 0.005em |
| T5 Airy | 1.8 | 58ch | 1.5em | 2em | 0.01em |

- Measure is capped by `min(var(--kp-measure), 100% - 2 * var(--kp-gutter))`, gutter 16 px phone, 24 px
  tablet+; absolute cap 46rem so a wide monospace fallback never runs long.
- Set the measure on the text container and let images/tables/code bleed to 100 % of the pane.
- Titles: line-height 1.2 at all steps; that is a heading exemption in practice, but 1.4.12 has no
  exemption, so title blocks must simply not clip when spacing is overridden (no fixed heights, no
  `overflow: hidden` on titles except line-clamp in lists, section 2.2).

### 2.2 List rows

Tokens: `--row-py` vertical padding, `--row-gap` meta-to-title gap, `--thumb` thumbnail edge (Magazine/Inbox),
`--title-lines`, `--snippet-lines`, `--row-min` minimum row height.

| Step | `--row-py` | `--row-gap` | Magazine `--thumb` | Magazine title/excerpt lines | Inbox snippet lines | Compact row (1-2 line) | Headlines row |
|---|---|---|---|---|---|---|---|
| D1 Dense | 0.25rem | 0.125rem | 3.5rem (56) | 2 / 0 | 0 | 44 px | 44 px coarse, 28 px fine |
| D2 Snug | 0.5rem | 0.125rem | 4.5rem (72) | 2 / 1 | 1 | 48 px | 44 px coarse, 32 px fine |
| **D3 Standard** | **0.75rem** | **0.25rem** | **5.5rem (88)** | **3 / 2** | **2** | **56 px** | **48 px coarse, 36 px fine** |
| D4 Relaxed | 1rem | 0.25rem | 6rem (96) | 3 / 2 | 2 | 64 px | 56 px |
| D5 Airy | 1.25rem | 0.375rem | 7rem (112) | 3 / 3 | 3 | 72 px | 64 px |

Resulting Magazine row heights at scale 1: D1 64, D2 88, D3 112, D4 128, D5 152 px (`thumb + 2 * py`).
Row height is `max(--row-min, content)`, never a fixed `height`, so text that wraps more (larger text size,
Roomy spacing) grows the row instead of clipping.

### 2.3 Touch targets, text size and density together

- **Coarse pointer (`@media (pointer: coarse)`)**: every row is at least `min-height: 44px` and the whole row
  is the hit target. Dense (D1) is therefore 44 px, not less. Density on phones is bought with fewer lines
  and smaller thumbs, never with a sub-44 hit area. This satisfies the 44 pt rule (R1) with no
  pseudo-element tricks, so adjacent hit areas never overlap.
- **Fine pointer**: floor 28 px on Headlines/Compact (above WCAG 2.5.8 24 px, with 4 px spacing), which is
  what makes desktop Headlines dense (32-36 px).
- **Row controls** (star, overflow, read toggle) are 44x44 hit areas via padding, visually 20-24 px icons, on
  coarse pointers; 32x32 on fine pointers with hover reveal plus keyboard focus reveal.
- **Text size** multiplies `rem`, so padding, thumb and row-min grow with it; `44px` floor is in `px` and
  does not shrink at 0.875. At scale >= 1.25 or container width < 360: thumbs cap at 25 % of container width,
  Magazine snippet drops one line, Inbox drops the trailing thumb. At 200 % zoom/320 px width nothing scrolls
  horizontally (1.4.10). Line clamps use `-webkit-line-clamp` in `lh` units, so they follow line-height.
- Density never changes tap semantics or which controls exist; it only changes spacing, thumb size and
  clamps. Selecting any combination cannot hide an action (D: options must not break anything).

### 2.4 WCAG 1.4.12 (Text Spacing) position

1.4.12 requires that content survives user overrides (line-height 1.5, paragraph 2x, letter 0.12em, word
0.16em) without loss or overlap. It does not require those values at rest. So:

| Setting | Survives overrides (must, all steps) | Meets the four values at rest |
|---|---|---|
| T1 Dense | Yes | No: line-height 1.4 (< 1.5), paragraph 0.6em. **Trades it away** |
| T2 Snug | Yes | Line-height yes; paragraph, letter, word no |
| T3 Standard | Yes | Line-height yes; others no |
| T4, T5 | Yes | Line-height yes; paragraph 1.25em and 1.5em still under 2em |
| **Roomy text spacing on** | Yes | **All four**: sets line-height `max(step, 1.5)`, paragraph 2em, letter 0.12em, word 0.16em, measure 60ch, in the article AND in list snippets/titles |

- "Survives overrides" is a test requirement: a Playwright test injects the 1.4.12 override stylesheet at every
  (layout x density x text size 1.0/1.5) combination on 375 and 1280 and asserts no clipped text (scrollHeight
  vs clientHeight on titles/snippets excepting deliberate clamps, which must still show the full first line),
  no overlap, no horizontal scroll.
- Density steps trade something away only in that D1/T1 are tighter than the 1.4.12 values at rest; an
  accessible option exists (Roomy) and enabling it does not break layout, which is the owner's rule (D).
- Roomy in lists: row-py +25 %, `letter-spacing: 0.12em` on snippets/titles (rows are fixed-height-free so
  wrap happens), Headlines temporarily shows two-line titles (clamp 2) so titles are not cut off. Named in
  Settings > Accessibility "Roomy text spacing" ("Adds space between letters, words, lines and paragraphs.").
- `prefers-contrast`/scale interaction is independent.

Settings copy: Density > Lists: "How much fits on screen." Density > Reading: "How much space between lines
and paragraphs."

---

## 3. Gesture spec, final

Scope: touch and pointer gestures for lists and articles. Tap zones are **not in scope**; they remain
parked as an optional article "page mode" (R1 Scheme 3) and are not specified here.

### 3.1 Row swipe (list rows, all layouts, touch only)

The owner (D): **full swipe with undo. Swipe left = mark read. Swipe right = mark unread.** Note this is the
opposite of iOS Mail (right = read, K); a "Swap swipe directions" switch in Settings > Gestures costs
nothing (P).

Recognition:

- `touch-action: pan-y` on rows; pointer events with `pointerType === 'touch'`. Mouse/pen never swipe (they
  use hover buttons).
- Ignore touches starting < 24 px from the screen's left edge (and < 8 px from the right edge to avoid
  the edge zone the same way on gesture-nav Android).
- Direction lock after 8 px of travel: if `|dx| > 1.5 * |dy|` lock horizontal (row tracks the finger,
  `touchmove` preventDefault via non-passive listener on the row only), else release to vertical scroll.
  Once locked, stays locked for the touch; the list scroller ignores the touch (no pull-to-refresh).
- Ignore when a long-press menu is open, when multi-select mode is on, or on a second finger.

Thresholds (row width W, at 375: 375 px):

| Event | Rule |
|---|---|
| Panel starts revealing | first px after the direction lock, follows the finger 1:1 |
| Icon and label fade in | at 24 px travel |
| **Armed** (commit point) | `dx >= clamp(96 px, 40% of W, 176 px)`; at 375 that is 150 px. Panel deepens in color, icon scales 1.0 to 1.15 (ease-out 100 ms), label switches to the action verb |
| Release armed | commit |
| Release short of armed | commit only if velocity >= 0.6 px/ms in the swipe direction AND travel >= 64 px (a flick) |
| Reverse velocity | if velocity >= 0.4 px/ms back toward origin at release, cancel even when armed |
| Cancel | spring back 200 ms `cubic-bezier(0.2, 0, 0, 1)`; with reduced motion, no travel animation, instant |
| Rubber band beyond 60 % of W | resistance 0.5, so the row cannot be thrown off screen by accident |

Action panels (color tokens per theme; contrast of label vs panel >= 4.5:1 in every scheme, verified when
color tokens are set; defaults shown for light/dark):

| Swipe | Reveals on | Action | Panel color token | Icon | Label |
|---|---|---|---|---|---|
| Left | right side | Mark read | `--act-read` (light `#1f5fbf`, dark `#7fb0ff` with dark label) | filled circle-check | "Read" (when row is already read: "Already read", panel neutral, row springs back, no toast) |
| Right | left side | Mark unread | `--act-unread` (light `#b45309`, dark `#f5b86a` with dark label) | empty circle with dot | "Unread" (already unread: "Already unread") |

Icons plus text label always, never color alone. Actions are idempotent per direction (left always ends
read, right always ends unread) because that is what the owner's mapping implies; toggling is the `m` key and the
row menu. Star is not a swipe (3.3).

Commit animation:

1. Row completes its slide off in the swipe direction over 160 ms ease-in (panel stays behind it).
2. In **Unread view** (and any filter that excludes the new state): row height collapses to 0 over 180 ms and
   siblings move up. Elsewhere (All, Starred, search, folder): row slides back into place with the new
   read style (dot removed / weight normal / dim) over 160 ms; no removal.
3. Toast appears with the row's departure.
- Reduced motion: no slide; a 120 ms cross-fade of the row to the read style or, in Unread view, opacity to
  0 then instant collapse.

Undo toast:

- Bottom, above the toolbar/tab bar and safe area, max-width 480 px, role `status`. Text: "Marked read" or
  "Marked unread", plus a text button "Undo" (44 pt tall, focusable, not stealing focus on appearance).
- Duration **5 s**, paused while pointer hovers, finger holds it, or its button has focus. Setting
  Accessibility > "Keep undo messages until dismissed" (default off) for screen-reader/motor users.
- **Stacking rule:** one toast slot. Consecutive same-kind swipes within the window coalesce into one toast
  ("Marked 3 as read") and reset the 5 s timer; Undo undoes the whole coalesced batch. A different-kind
  action replaces the toast, and the earlier action moves onto the undo stack (depth 20, 60 s) reachable by
  `z`. Bulk actions (mark above/below/all) are one action with "Marked 42 as read" copy.
- **Keyboard:** `z` undoes the most recent undoable action, with or without the toast visible (within 60 s
  of it). `Ctrl/Cmd+Z` is not bound (browsers and text fields own it); there is a visible Undo button in the
  list header overflow menu, enabled when the stack is non-empty.
- **VoiceOver:** the toast text is announced through a persistent polite live region ("Marked read. Undo
  available.") and the region is never removed from the DOM; the Undo button is the next focusable element in
  DOM order after the list toolbar so it is reachable, plus the row's custom actions include "Undo last
  action" when relevant. Screen readers cannot be reliably detected, so no detection: the switch above plus
  the 60 s `z`/menu window cover it.
- Undo is a real state reversal (writes read state back for exactly the ids that flipped; ids already in
  the target state are untouched), and it re-inserts the row in sort order with an expand animation.

In the **Unread view**, scroll behavior:

- Removed rows above the viewport are compensated with a scroll adjustment equal to their height so the
  viewport content does not jump (virtualizer anchor = first fully visible row).
- Rows below simply move up. A swiped row leaves a gap that closes; the user's next row lands under the
  finger.
- **Position kept** on undo: the row returns at its original place by sort key, not at the top.
- Non-swipe actions in Unread view (`m`, article toolbar): the row stays in place, dimmed, until the user
  leaves the list or refreshes (R1's "remove on next refresh" rule), so `j/k` sequences don't lose their
  place. Swipe removes immediately because the swipe animation already communicates it. (P, ask the owner: or
  should everything behave the swipe way?)
- **Swipe on the last item** (the list has one row, or the bottom row): the row leaves, list shrinks, scroll
  clamps to the new end; if that empties the list the empty state (section 6) fades in over 200 ms and
  focus moves to the list heading. If more pages exist below (cursor not exhausted), prefetch the next page
  before collapsing.

### 3.2 First-run peek

- Trigger once per device, the first time a list with at least one row is shown at coarse pointer (touch).
  Wait 600 ms after first paint, only if the user has not touched the screen.
- Sequence on the first row (no state change): slide left 72 px with the "Read" panel revealed (320 ms
  ease-out), hold 700 ms, spring back (240 ms), then slide right 72 px revealing "Unread" (320 ms), hold
  700 ms, spring back. ~2.9 s total. A caption fades in above the list: "Swipe left to mark read,
  right to mark unread." (visible 4 s, dismissible, `role="status"`).
- Any touch cancels the peek immediately and marks it seen. Never plays if `prefers-reduced-motion`; the
  caption still shows as a static hint once. Replay: Settings > Gestures > "Show swipe tips".
- Stored as a per-device setting (D: appearance is per device), not server state.

### 3.3 Star

- **Tap target**: a 44x44 star button trailing on rows in Magazine, Cards and Inbox (Cards: footer);
  Compact/Headlines show a star only when starred and get the action via `s`, row menu, article toolbar.
  Always in the article toolbar. Star toggles immediately (optimistic), no toast (reversal is one tap), but
  the star button announces "Starred"/"Unstarred" via the live region.
- **Key** `s`. **Long-press** (500 ms, touch, list rows only; `-webkit-touch-callout: none` to suppress the
  iOS link preview; not in article text where it fights selection) opens a menu: Star/Unstar, Mark
  read/unread, Mark above as read, Mark below as read, Open original, Copy link, Share. The same menu is
  the overflow (three dots) button on hover/keyboard focus and is the VoiceOver custom-actions set.

### 3.4 Navigation stack and article swipe

Stack (D: swipe returns to the screen you came from):

```
Feeds (sources/folders)  ->  List (scope + filter + sort)  ->  Article
   /                         /l/<scope>?f=unread&o=desc         /i/<id>?from=<scope-hash>
```

- Each drill-in is `history.pushState` with `state = {scope, filter, sort, anchorId, offset, asOfId}`.
  Search opens as a List entry. The article route carries the list it came from, so back returns to
  Unread, a folder, Starred or a search, not to Feeds.
- **Prev/next inside an article uses `replaceState`**, never `pushState`, so back is always one step to the
  list regardless of how many articles were read. Prev/next follow the list's order and snapshot (the ids
  as of open time, including items since marked read) so `j/k` doesn't skip.
- Back always ends in `history.back()`: the OS edge-swipe, browser back, the header back button, `u`/`Esc`
  and the in-app swipe all go through it, so scroll and selection restore is a single code path (restore
  `offset` and focus `anchorId`, keep the read-dimmed item visible).
- Deep link with no history (cold open of `/i/<id>`): back replaces with the list route for that item's
  feed (fallback scope), or All.
- Desktop and any width where the reader is a pane (container >= 900 px with Reading pane on): no route
  push for articles, no swipe, list keeps selection.

In-app right-swipe pop (article route, touch only, single-pane):

| Rule | Value |
|---|---|
| Start | x >= 24 px from the left edge (dead band 0-24 belongs to iOS). Any y |
| Lock | after 10 px, horizontal-dominant (`|dx| > 2 * |dy|`, i.e. within ~27 degrees), rightward only |
| Ignore when touch target is inside | any ancestor with `overflow-x: auto/scroll` and `scrollWidth > clientWidth` (tables, `pre`, code blocks, wide figures, carousels); `[data-no-swipe]`; an image in zoom/lightbox; `video`/`iframe` (events not delivered anyway); text selection active (non-collapsed `getSelection()`); form control; more than one touch (pinch) |
| Commit | travel >= 35 % of W, or velocity >= 0.5 px/ms with travel >= 64 px |
| Feedback | article translates with the finger, list beneath at -20 % parallax, dim overlay; cancel springs back 200 ms |
| Reduced motion | no drag tracking; on commit, 120 ms cross-fade to the list |

The horizontal-scroll test must be evaluated at touchstart on the actual target's ancestor chain and again
if the target's own scroll offset is non-zero (a scrolled table can still be scrolled left, so ignore while
`scrollLeft > 0` as well as when it can scroll right). This is what prevents the "fires by accident" class
in R1.

Buttons: back chevron (44 pt) in the article header; bottom toolbar with previous, next, star, read/unread,
original, and overflow. Keys: `j/k`, `u`/`Esc`. Next on the last item shows a toast "End of list".

### 3.5 Pull to refresh

- Applies to list screens on touch only. Not on article, Feeds or Settings screens. Desktop uses `r` and the
  button.
- Preconditions: `scrollTop === 0` at `touchstart`, and still 0 throughout, lock is vertical downward
  (`dy > 0`, `|dy| > |dx|`). If the list scrolls at any time, the pull is cancelled. If the row-swipe
  direction lock triggers first, PTR is dead for that touch.
- Feedback: indicator appears at 16 px, resistance 0.5, **armed at 72 px** (label switches "Pull to
  refresh" to "Release to refresh"), max travel 120 px. Release armed: list snaps to 56 px, spinner runs
  until the manual refresh run finishes (D: refresh fetches all now), then closes and announces "12 new
  articles" or "No new articles". Failures: "Couldn't refresh 2 feeds. See Health."
- Scroll container has `overscroll-behavior-y: contain`. Installed PWA on iOS has no native PTR (R1), so no
  double trigger. In a Safari tab, native rubber-band exists: PTR listens only when `scrollTop === 0` and
  calls `preventDefault` on `touchmove` (non-passive, list scroller only) once pull exceeds 12 px so the
  native bounce does not fight it. Known limit: Safari tab chrome overscroll may still tug; accept, refresh
  button is always available.
- Reduced motion: no elastic travel; a static "Refreshing" bar at the top with a spinner; still armed at
  72 px.
- Offline: arming shows "Can't refresh while offline" and does not start a run.
- Search results and per-item lists refresh the underlying run but do not re-run the search query mid-view
  (list stays stable; a "n new" pill appears instead).

---

## 4. Keymap

Design rules:

- **No modified shortcuts** (Ctrl, Cmd, Alt are never bound) so nothing collides with browser or OS
  shortcuts. Shift is allowed for capital-letter and symbol keys.
- WCAG 2.1.4 (Character Key Shortcuts): a switch "Single-key shortcuts" in Settings > Accessibility
  (default on; off disables every key including `?`, and the overlay stays reachable from a
  "Keyboard shortcuts" menu item). Remapping is parked to phase 3 (P) if the owner wants.
  Screen-reader browse modes (NVDA/JAWS) and macOS VoiceOver Quick Nav consume letter keys, so do not depend
  on them.
- **Disabled while typing**: any `input`, `textarea`, `select`, `contenteditable`, `role=textbox/searchbox/
  combobox`, while IME composition is active, while a modal dialog other than the help overlay is open
  (only `Esc` and `?` work), and when any of Ctrl/Cmd/Alt is held. `Esc` in the search box blurs it.
- Two-key chords: `g` then a key within 1.2 s; a small "g..." indicator appears bottom-left listing the
  choices (same as Gmail).
- Every key has a visible button equivalent (last column). `?` opens an overlay grouped by scope, searchable,
  reachable also from the header menu; it is a real dialog (focus trapped, `Esc` closes).
- Browser conflicts to know about: `/` and `'` open Firefox quick find when focus is on the page (we
  `preventDefault` `/` only outside inputs; `'` is unused); `Space` scrolls natively and is left alone; `Backspace`
  is browser-back in some browsers and is not bound; `?` is Shift+/ and needs layout awareness (bind by
  `event.key`, not `code`); `{` `}` are layout dependent (buttons exist). iOS with a hardware keyboard:
  letters reach web pages normally; Cmd-hold shortcut sheet is native only and does not list ours, hence `?`.

Scope: L list, A article (or reader pane), G global.

| Key | Action | Scope | Button equivalent |
|---|---|---|---|
| `j` / `Down` | Next item (L: move selection/focus; A: next article) | L, A | Next arrow in toolbar |
| `k` / `Up` | Previous item | L, A | Previous arrow |
| `n` | Next unread item (crosses to the next feed/folder with unread when the list is exhausted, with a toast) | L, A | "Next unread" in toolbar overflow |
| `Enter` | Open selected item | L | Row tap |
| `o` | Open original in a new tab | L, A | "Open original" |
| `v` | Open original in a background tab (best effort: Chrome/Firefox honor it, Safari and iOS open it as `o`) | L, A | "Open original" menu item |
| `m` | Toggle read/unread | L, A | Read toggle in toolbar/row menu |
| `s` | Toggle star | L, A | Star button |
| `r` | Refresh all (manual run) | G | Refresh button; pull to refresh |
| `u` / `Esc` | Up one level: article to list, list to Feeds, close overlay/deselect | G | Back chevron |
| `g` `g` | Jump to top of list (`Home` too) | L | "Top" floating button |
| `G` (Shift+g) | Jump to bottom of loaded list (`End` too) | L | none needed; scroll |
| `g` `i` | Go to Unread ("Inbox") | G | Sidebar > Unread |
| `g` `a` | Go to All | G | Sidebar > All |
| `g` `s` | Go to Starred | G | Sidebar > Starred |
| `g` `f` | Go to Feeds (sources) | G | Sidebar > Feeds |
| `g` `h` | Go to Health | G | Sidebar/Settings > Health |
| `g` `,` | Open Settings | G | Settings button |
| `[` / `]` | Previous / next feed (or folder when a folder scope is active) in sidebar order | L | Feed switcher arrows in list header |
| `/` | Focus search (scoped to the current list; `Esc` blurs) | G | Search field/button |
| `?` | Keyboard shortcuts overlay | G | Menu > Keyboard shortcuts |
| `Shift+A` | Mark all in the current list as read (no confirm; undo toast, `z`) | L | List overflow > Mark all as read |
| `{` (Shift+[) | Mark above the selected item as read (section 5) | L | Row menu, list overflow |
| `}` (Shift+]) | Mark below the selected item as read | L | Row menu, list overflow |
| `x` | Toggle selection of the focused row; with a selection, `m`, `s`, `{`, `}` act on the set. `Shift+Down/Up` extends | L | Row check circle in select mode, "Select" in overflow |
| `z` | Undo last action (60 s) | G | Undo in toast; list overflow > Undo |
| `f` | Toggle full text for the article (extract or show feed version) | A | "Full text" toggle in toolbar |
| `c` | Toggle Compact layout (swaps to Compact and back to the layout you had) | L | Layout menu |
| `Shift+L` | Cycle layouts | L | Layout menu |
| `+` / `-` | Text size up / down in the article | A | Reading menu (Aa) |
| `Space` / `Shift+Space` | Native page down/up in the article; unbound elsewhere (P: option "Space advances to next unread at the end", off) | A | scroll |
| `p` | Read aloud play/pause (reserved for phase 3) | A | Read aloud button |

Reserved, unused: `e`, `d`, `h`, `l`, `t`, `w`, `y`, `b`. Nothing is bound in Settings screens except `Esc`/`?`.

Design note: `Shift+A` is confirm-free by decision; the undo toast plus `z` is the safety, and mark-all
uses the `ts` cutoff semantics (5.3) so items that arrived after the list loaded are not swept up.

---

## 5. Mark above / below

### 5.1 Semantics

Defined only in terms of the **list's own displayed order**, so "above" is always what the user sees above:

- Order key = `(sort_at, id)` descending by default (newest first, D), ascending when the device's sort is
  oldest-first. "Above" = rows earlier in that displayed order than the anchor; "below" = later. So with
  oldest-first, "above" means older items. No special casing in the UI: the server receives the order and
  derives the comparison.
- Anchor is **excluded**; its own state is unchanged (it's the item the user is looking at or is acting on
  separately). Menu labels: "Mark above as read", "Mark below as read". Only read variants exist (P: unread
  variants are rare; add later if asked).
- Scope = the whole query behind the current list, not just loaded rows or the rendered window: feed,
  folder (a merge across feeds in the same order), All, Starred, Unread, search results. The list's filters
  (unread-only, keyword mute, search text) are part of the query, so hidden rows are never touched:
  mute-filtered items are not in the list and are never marked.
- Search results: only available when results are sorted by date; date sort is the default for search
  (relevance order is unstable and "above" has no meaning there). With relevance sort, only "Mark all
  results as read" is offered.
- Folder views: works exactly as in a feed; day headers are ignored (they are not rows).
- **Unread view** (default): "below" is common ("I've read down to here, clear the rest" is more likely "above": everything I already scrolled past). Both work; rows leave the view via the collapse animation as one batch.

### 5.2 API sketch

```
POST /api/items/mark-range
{
  "scope":  {"type": "feed|folder|all|starred", "id": 12},
  "filter": {"unread": true, "q": "ferry", "mute": true},   // same object the list query used
  "order":  "desc",                                           // "desc" | "asc"
  "anchor": {"sort_at": 1758812345, "id": 1758812345123456},  // keyset of the anchor row
  "direction": "above",                                       // "above" | "below"
  "read": true,
  "as_of": 1758812999000000                                   // max item id when the list loaded
}
-> 200 {"changed": 42, "batch": "b_9f3a", "expires_in": 120}

POST /api/items/mark-range/undo   {"batch": "b_9f3a"}   -> 200 {"restored": 42}
```

- Server: one transaction, `UPDATE ... WHERE <scope predicate> AND <filter predicate> AND read=0 AND
  id <= as_of AND (sort_at, id) < (anchor)` (comparison direction from `order` and `direction`), using
  `idx_items_unread_sort` for the unread case, `idx_items_feed_sort` for feeds, `idx_items_sort` for All.
- **`as_of` guard**: item ids are crawl time in microseconds (design.md), and a newly crawled item can sort
  into the middle of the list because sort is by `published`. Without a bound, "mark above" run after a
  refresh would silently mark items the user never saw. `id <= as_of` restricts to what the list knew.
  The same bound is what the Reader API calls `ts` on `mark-all-as-read` (a crawl-time cutoff), so
  "Mark all as read" (`Shift+A`) sends the same `as_of`.
- Undo: server keeps the batch ids in a memory-bounded table (cap 50 000 ids across batches, TTL 2 min);
  undo restores read=0 for exactly the ids that flipped. If the batch expired, the UI says "Can't undo
  that anymore" (section 6). Client undo does not send thousands of ids.
- Stats: bulk marking never counts as reading (CLAUDE.md); the endpoint writes no stats events.
- Client cost: no per-row round trips; optimistic UI marks loaded rows, the count badge reconciles from the
  response.

### 5.3 Retention and Reader API interplay

- Retention trims per feed to the newest N by the same `(sort_at, id)` rank the UI uses (design.md §5).
  Trimmed items are not in the list, so mark-range never touches them; their ledger rows keep read state
  for API consistency and the "trimmed unread" counter is unchanged by it. Practical effect: "mark below as
  read" in a feed does not reduce trimmed-unread, and a feed near its cap loses those unread items at the
  next trim anyway, which the UI can mention in a confirm-free summary ("Marked 42 as read").
- Restored-by-unread items (`retain_until`) appear in the list and behave as normal rows.
- Reader API: mark-range writes the same `read` column the `edit-tag` endpoint writes and stamps the same
  change marker (the state row's `ot/nt` equivalent), so Reeder and NNW pick the change up on their next
  sync as ordinary read-state changes, with no special-casing. Clients do not receive "ranges"; they see
  ids flip. For very large batches (thousands) make sure `stream/items/ids` with `xt=user/-/state/com.google/read`
  stays paged, which design.md already requires.
- Concurrency with a running fetch: fetch inserts new rows with higher ids, mark-range excludes them via
  `as_of`; both run in separate transactions, SQLite WAL single writer serializes them.

---

## 6. Empty, error, loading, offline, first-run

Copy rules (P, none found in the repo): sentence case, plain verbs, say what happened and what to do next,
no exclamation points, no "successfully", no "please", no jargon, no blame, times in Eastern in the user's
locale format. Buttons are verbs.

| Screen | Headline | Body | Actions |
|---|---|---|---|
| First run, no feeds | No feeds yet | Add a feed by its address, or import an OPML file from another reader. | Add feed / Import OPML |
| First run, importing | Adding your feeds | Articles appear as each feed finishes. A large import can take a few minutes. | Show progress |
| First run, feeds added, first fetch | Fetching your first articles | This only takes a moment for most feeds. | none (auto-dismiss) |
| Unread empty | All caught up | No unread articles. New ones appear after the next refresh. | Refresh / Show all |
| All empty (feeds exist) | No articles yet | Kipple hasn't fetched anything from these feeds yet. | Refresh |
| Starred empty | No starred articles | Star an article to keep it here. Retention never removes starred articles. | none |
| Folder empty | This folder has no feeds | Move feeds here from the Feeds screen. | Manage feeds |
| Search, no results | No results for "ferry" | Try fewer words, or search All instead of just this feed. | Search all |
| Search, too short | Keep typing | Search needs at least two characters. | none |
| Filters hide everything | Everything is hidden | Your mute filters hide all articles in this view. | Review filters |
| List loading | (skeleton rows, no text) | `aria-busy`, row-shaped placeholders at the current layout's height; after 10 s "Still loading" appears | none |
| List load error | Couldn't load articles | Kipple couldn't reach the server. Your place in the list is saved. | Try again |
| Server error | Something went wrong | The server returned an error. Try again, and check the Kipple logs if it keeps happening. | Try again |
| Article load error | Couldn't open this article | The article couldn't be loaded. You can read the original instead. | Try again / Open original |
| Article removed by retention | This article was removed | Kipple keeps the newest 100 articles for this feed. Open the original to read it. | Open original |
| Full text failed | Couldn't load full text | Showing the version from the feed instead. | Try again |
| Image failed | (no error UI) | Layout collapses to the text-only variant, no broken image icon | none |
| Refresh result | 12 new articles / No new articles | shown as a status line under the header for 3 s and in the live region | none |
| Refresh partly failed | Couldn't refresh 2 feeds | The rest updated. See Health for details. | Open Health |
| Offline at launch | You're offline | You can read what's already on this device. Changes sync when you're back online. | none |
| Offline banner (session) | Offline | Reading and marking still work. 3 changes are waiting to sync. | none |
| Back online, syncing | Back online | Syncing 3 changes. | none |
| Offline and nothing cached | Nothing to show offline | Open Kipple online once to download your articles. | Try again |
| Session expired | Sign in again | Your session ended. Sign in to keep syncing. Nothing on this device is lost. | Sign in |
| Undo unavailable | Can't undo that | It's been too long. Mark them unread from the list if needed. | none |
| Swipe tips (first run peek) | Swipe left to mark read, right to mark unread. | | Dismiss |
| End of list | You've reached the end | That's every article in this list. | Back to top |
| Mark all done toast | Marked 42 as read | | Undo |
| Text copy failure (clipboard) | Couldn't copy the link | Your browser blocked it. Long-press the link to copy it. | none |

Focus behavior: on empty and error screens focus moves to the headline (`tabindex=-1`, `role="status"` for
non-error, `role="alert"` for errors); loading uses `aria-busy`, never a spinner-only screen.

---

## 7. Questions for the owner

1. Ship the five layouts (Magazine, Cards, Compact, Inbox, Headlines) and park Columns, Reader list and
   Expanded stream? Add reading time as an optional chip instead of the Reader list layout?
2. Per-folder layout overrides: store the setting from phase 2, UI in phase 3, or skip entirely?
3. Density: names Dense/Snug/Standard/Relaxed/Airy with two independent sliders (Lists, Reading) and a
   "Link both" toggle. OK, or should it be one slider only?
4. Swipe direction is left = read, right = unread (opposite of iOS Mail). Add a "Swap swipe directions" switch?
   And confirm swipe is idempotent (left always leaves it read), toggling being `m`?
5. In Unread view: swipe removes the row immediately, but `m` and the article toolbar leave the row dimmed in
   place until you leave the list. Keep that difference, or make everything remove immediately (or everything
   keep)?
6. Mark above/below: anchor excluded, read-only variants, disabled for relevance-sorted search. OK?
7. Single-key shortcuts need an off switch for WCAG 2.1.4; is a global on/off enough, or do you want per-key
   remapping in phase 3?
8. `c` is defined as "toggle Compact layout" (swap and return). Is that what you meant, or did you mean
   toggle density?
9. Undo model: one coalescing toast slot plus `z` stack of 20 for 60 s, and an optional "keep undo messages
   until dismissed". Fine?
10. Mark-all (`Shift+A`) is confirm-free with an `as_of` cutoff; OK that items that arrive after the list loaded
    are never swept up?
