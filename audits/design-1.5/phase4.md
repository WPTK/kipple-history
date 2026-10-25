# Design review 1.5, Phase 4 (fixes by package)

Each open design-review issue has a phase 3 decision comment; Phase 4 implements them one package per pull request, with the
decision as the spec, a browser-driven check at phone and desktop sizes, and a changes/ entry.

## Wave 1 (merged 2026-10-23 to 2026-10-24)
- KIT: tokens, states and fields (#715)
- READ: reading pane fixes (#714)
- STATE: failures by cause, empty states, toasts, offline pill (#720)
- ACT: one item action table, Mark all always confirms with its count (#721)

## Wave 2 (merged 2026-10-24)
- NAV: one destinations table, 900 px breakpoint, in-memory arrival focus, resize handle outside the column (#725)
- FEED: feed repair, gone feeds revive on a corrected address, one delete wording (#726)
- SET: Settings regrouped, Restore from a backup row, retention preview, storage figures (#731)
- STATS: sources, share image, Your year, heat levels by rank (#733)
- Test fix after the Unread mark became unread-only (#734)

## Wave 3 (merged 2026-10-24 to 2026-10-25)
- KIT remainders: sheet focus, menu rows, number presets, field names (#751)
- STATE remainders: Stats add-a-feed in place, one offline message, row menu Undo (#750)
- Setup wizard: two steps, OPML restore, rerun keeps the account (#744)
- ROW: one row anatomy across layouts, search rows, header count beside the title (#746)

## Closed out
Phase 4 ended on a scope line. Every issue still open moved to the milestone "1.5 - Design review follow-ups"
(54 issues; the review milestone closed with 72 done). Phase 5 recaptures against the phase 0 baseline instead of chasing
the remainder.

## Lessons
- Browser UAT is not a required check but failed for real three times (tab labels clipped at Largest text, a stale
  test, tiles wider than their box with the CI font). Wait for it before merging a UI PR.
- A guessed character width is not a layout: size from the box.
- Review loop held to one review, one fix push, one delta review; leftovers became issues (#727-#730, #735, #736, #741, #743).
- The conflict churn came from lists every PR appended to. flows.json is one flow per line and merged by union, the
  eslint file list is one glob, and a new flow gets no npm script.
- A "moved N issues" count from a loop that hides errors proved nothing; check the milestone counts afterwards.
