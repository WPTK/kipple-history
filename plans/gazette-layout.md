# Gazette layout: build plan (issue #39, scoped 2026-10-06)

Decisions are in `docs/ui-decisions.md`, section "Additional layouts (#39)". This file is the build plan. Web only, no server change, no migration. Built 2026-10-07 as three PRs: planner #299, renderer #308, wiring with the paper name setting #313 (shipped in 0.8.0-beta.5). The checklists below are the original split; the setting landed in PR 3, not PR 2.

## Design
- **Planner (pure function, no React):** input is the articles, feeds, favorites, list scope and screen class (wide or phone). Output is pages made of slots: lead, co-lead, column story, photo, brief. Same input, same page. One golden fixture per front-page type.
- **Renderer:** one story component with variants, a CSS grid for columns, DOM order equals reading order.
- **List screen:** a layout may supply a page renderer. The list screen then hands it the whole list and skips the row virtualizer.
- **Paging:** all loaded pages stack in one scroll with a page rule and folio line. Existing load-more near the end keeps running. A page is fixed once planned, so loading more never reflows earlier pages. The last page and "That's the Gazette." appear when the server has no more articles.
- **Lead:** newest image article from a Favorite (feed, or any feed in a favorited folder) among the first 100 loaded. None means a no-lead type. In a single feed or folder list, the newest image article in that list.
- **Order:** always newest first; the per-device sort order is ignored.
- **Reading:** a story marked read fades in place; no reflow; re-plan on refresh or on leaving and returning.
- **Sections:** by folder (parent folder or everything); by feed name inside a single folder.
- **Front-page types, first match wins:** co-leads, lead with image, big headline (no image, or longest recent headline when no pinned feed has news), quiet day, busy day, text-only day. Picture day dropped (no image sizes stored).

## PR 1: planner and fixtures (no UI)
- [ ] Types: `PagePlan`, `Slot`, `FrontType`
- [ ] Lead and co-lead selection from favorites and the folder tree
- [ ] Front-page type chooser and column-count rules (2 to 4); briefs overflow
- [ ] Inner pages: section grouping by folder or feed, at most one picture feature per section, last page is briefs only
- [ ] Golden tests per type, determinism test (shuffle input order that does not matter), phone class (single column, same order)
- [ ] Review the planner on Opus before merge

## PR 2: renderer, id and settings
- [ ] `gazette` added to `LAYOUT_IDS`, label, hint, `c` toggle returns correctly
- [ ] Masthead, folio, rules, story variants, theme tokens only (accent from the theme), dark and light
- [ ] Setting for the paper's name (default "The Gazette"), per device, synced through the device profile, text field in Settings
- [ ] Layout menu entry and per-feed/folder override work
- [ ] Phone layout: one column, compact masthead, no folio row

## PR 3: list-screen integration, docs
- [ ] Page-renderer contract beside the row contract; skip the virtualizer
- [ ] Snapshot: read stories fade in place; no leaving after 1.5 s; undo still works
- [ ] Selection and `j`/`k` in reading order; focus restore; open article full width and return to the same place
- [ ] Phone swipe on stories (read right, star left); desktop uses keys and menu
- [ ] Load more near the end; end of the paper
- [ ] Empty and error states; offline cache behaves as other layouts
- [ ] `changes/` entry, `docs/design.md` section, `docs/ui-decisions.md` already updated
- [ ] Verify in the browser at desktop and the mobile preset, a dark theme, a very light theme, large text; a11y pass (headings, landmarks, focus order)

## Each PR
`go test ./...`, `cd web && npm test`, `pwsh scripts/ci-local.ps1`, CI green on the exact commit. Sonnet builds; `/code-review` medium, high before any deploy.

## Later (not in this plan)
Source rows, triage stack, Inbox and Email - Compact mail look, daily edition (parked). Each needs its own scope.
