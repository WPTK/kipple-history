# Settings grouping and list-layout proposals, 2026-09-27 night (delivered 2026-09-28)

Design-meeting prework for issues #55 (settings restructuring) and #57 (layout differentiation) from the beta.1
feedback ([../human-feedback/beta1-feedback-2026-09-27.md](../human-feedback/beta1-feedback-2026-09-27.md)). The
owner asked at 23:17 ET on 2026-09-27: "Bring me a grouping proposal for settings. A few ideas works. Mockups help.
Come up with some fresh or improved layout ideas. Mockups help here too." The deliverable was one Artifact (a
design canvas of five artboards) plus two code surveys. The artifact itself lives outside this repository and is not
reproduced here; this file records what it proposed and what was built. The artifact type's own rule forbids
opening the finished canvas to self-check, so it was delivered unverified and flagged for review together.

## What the code survey found (22:06 to 22:10 ET)

- **Settings** was one long scrolling page of sections: Appearance, Accessibility, Lists and reading, Keyboard,
  the server-defined groups (Reading, Sync, Library, Images, Statistics), Advanced (the only collapsible), your
  statistics data, Filters, Saved searches, Devices, Account. The server already had a setting-group concept;
  the client had no navigation between them.
- **Editorial versus Cards** and **Compact versus Email - Compact** genuinely differed in code (grid versus one
  column; a single truncated line versus a two-line clamp), but on a narrow screen the single-column fallback of Cards
  looked the same as Editorial, and Email - Compact and Compact looked alike. A perception problem, so the owner's eyes
  were needed before any CSS.

## Settings: the grouping proposals

The canvas held three settings artboards, and the recorded summaries describe them as three information-architecture
options (the record does not spell out the third):

1. **Master-detail** (recommended): a list of groups on the left and the chosen group beside it on a wide screen, and
   on a phone a list of groups that drills into one page per group with a back button. It reuses the app's own
   sidebar-and-drill-down idiom instead of introducing tabs or an accordion. Shown as a desktop artboard and a mobile
   drill-down artboard.
2. **A lighter alternative** ("option B, minimal"): the sections reordered logically on a single scrolling page with
   jump chips at the top; cheaper to build.

The agent's subagent also raised two small naming and placement questions for the owner, still open the next
morning: the convention for group names, and where a "Manage feeds and folders" link belongs. At the 2026-09-29
meeting the answers were Title Case with ampersands and the link in Sync & Feeds.

## Layouts: what was proposed

- **Cards** gets real card chrome (border, shadow, margin, an inset image with rounded corners) instead of the
  edge-to-edge look that converges with Editorial.
- **Compact versus Headlines/Email - Compact** sharpened: one always shows a favicon, the other never does.

## What was built

- Master-detail Settings in six groups, PR #70 (Appearance & Reading; Sync & Feeds; Statistics; Filters & Saved
  Searches; Account & Devices; Advanced), each group with its own address.
- Cards shell and Email - Compact without a favicon, PR #68.
- Related feedback items 5 to 9 became PRs #65 (mobile folder collapse, Edit mode), #66 (Manage this feed, Feed Health
  bulk select), #63 and #64.

Issue #57 stays open until the owner confirms the layouts on his phone.
