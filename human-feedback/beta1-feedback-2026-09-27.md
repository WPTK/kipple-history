# beta.1 phone-testing feedback, 2026-09-27 (evening)

The owner tested `v0.3.0-beta.1` on his phone after the 21:35 ET deploy and kept a running list in a notes file, which
he attached to a new session at 22:06 ET ("our first session about 0.3.0 beta.1 feedback"; he warned he might
share the same file more than once, so duplicates were expected). He asked for three things: triage each item (parking
lot, work now, or work later and when), a plan, and any further areas the feedback suggested inspecting. The file had
ten items and an empty eleventh bullet. Item 5 was clarified at 22:17 ET; the same message told the agent to do a
screenshot pass first, then execute the plan, merge as it saw fit (later withdrawn, see below), update this history
repository, and open and label issues and pull requests with the existing taxonomy.

The wording below is the owner's, lightly shortened.

## The ten items, triage and outcome

| # | What the owner wrote | Triage (22:10 ET) | Issue | Fix | Status on 2026-09-29 |
|---|---|---|---|---|---|
| 1 | Settings "needs to be rearranged. I don't know how, but it seems clunky, disjointed, and not in any logical order" | Work later: a real information-architecture change; needs a concrete grouping proposal first. The survey found one long page of sections with only "Advanced" collapsed, although the server already had a setting-group concept | #55 | Mockups asked for at 23:17 ("A few ideas works. Mockups help"); master-detail Settings in six groups, PR #70 | Closed 2026-09-28 11:39 |
| 2 | Turn the "N new articles" toast off "unless the user does a manual refresh" | Work now: confirmed bug, the announcement also fired on the periodic background poll | #56 | PR #63 (trigger-based pill), later corrected for two edge cases in PR #79 | Closed 2026-09-28 07:16 |
| 3 | "better differentiation between editorial and cards layouts" | Work later, needs the owner's eyes: the code differs but the perception does not | #57 (3 and 4 together) | Mockups, then PR #68 (Cards get real card chrome; Email - Compact sharpened) | Issue #57 still open: waiting for the owner's phone check |
| 4 | "Better differentiation between 'compact' and 'email - compact' layouts" | as 3 | #57 | PR #68 | as 3 |
| 5 | "feeds need to be collapsible on the sidebar" | Already implemented on desktop; needed clarification | #58 | Clarified 22:17: "They do not collapse on mobile. Tapping them brings you to the feed with all of that cateogories story, but does not expand/collapse." Mobile folder collapse in Manage Feeds, PR #65 | Closed 2026-09-28 11:38 |
| 6 | Feeds "do not always have to have the button to the left that indicates dragging (or an individual edit button). When a user presses an 'edit' button, then they can display" | Work now-ish: it is the Manage Feeds screen, which always showed a grip handle | #59 | Edit-mode toggle, PR #65 | Closed 2026-09-28 11:38 |
| 7 | A "manage this feed" option on an article's three dots menu to adjust how it is downloaded and how often, or disable or delete the feed. "Don't need to make a new setting menu for this, can probably just do it in feed health" | Work later: new plumbing | #60 | PR #66 | Closed 2026-09-27 23:19 |
| 8 | In Feed Health, "a multi select option to make changes to many feeds at once, including deleting or disabling them" | Work later: real feature, group with 6 and 7 as one feed-management pass | #61 | PR #66 | Closed 2026-09-27 23:19. A bug in its selection handling was found later, see the 2026-09-29 review |
| 9 | A screenshot of the mobile bottom tab bar: "This gap/spacing/border seems janky/too small" | Work now: a real visual bug, needs a live reproduction. The screenshot showed a thin seam of the background between the content and the black tab bar | #62 | First pass, PR #64 (softened boundary). The agent could not reproduce his exact screenshot and asked for a device check | **Open**: waiting on the owner's phone |
| 10 | "all Suite 3 testing seems to indicate 'pass' from my phone" | Not an action item; record as passing | closes #30 | none needed | Closed 2026-09-27 22:28; recorded in the UAT plan and risk register |

The image for item 9 was an embedded note-app image the agent could not resolve; the owner attached the screenshot
directly at 22:08 ET. The agent noticed one further thing in the list: items 6, 7 and 8 were really one need (a
coherent feed-management mode with bulk select, contextual edit affordances and an entry point from articles), so they
were designed together rather than as three patches.

## Working arrangements set in the same messages

- 22:17 ET: the agent said it could not merge code pull requests (an earlier classifier denial) and would hand merges
  to the owner; he merged #66 first that night, then the others as the CI came green. The permission to merge green-CI
  pull requests after discussion came on 2026-09-29 09:24.
- 23:17 ET: "Bring me a grouping proposal for settings. A few ideas works. Mockups help. Come up with some fresh or
  improved layout ideas. Mockups help here too." Delivered overnight as one Artifact with five artboards, see
  [../audits/overnight-2026-09-28.md](../audits/overnight-2026-09-28.md).
- 2026-09-28 11:37: he asked for the order to merge the remaining four pull requests; the answer was #69, #68, #65, #70.
  The diary for 2026-09-29 records them all merged.

## Same evening, earlier: reports on the alpha.7 deploy day

Recorded here because they are testing feedback from real use of a deployed build.

- **Stale Unread list (19:09 ET, on alpha.7)**: "Something is off. I seem to only be seeing a ton of sports posts as
  unread. When I went to refresh other feeds, some of the posts are 3+ days old and I know they're popular content
  posters with new content. Can you add it to the queue? Could this be a deployment issue?" Filed as #52. He also said
  "We may need to create a 'verbose' log level for testing purposes"; the agent recommended targeted debug lines in
  fetch and scheduler instead of a new level, and he agreed ("we will go with your recommendations"). After the beta.1
  deploy: "Issue #52 can be closed. Seems to be working normally." (21:45). The probable cause was the scheduler
  starvation fix in PR #26, which beta.1 was the first deploy to include; not proven with logs.
- **Deploy side effects (21:22 and 21:28 ET)**: "Why did you pull my entire docker stack down" and "I'm getting error
  1033 from cloudflare for all my sites tunneled through them. This happens every time we deploy". Covered in
  CHALLENGES.md (the Docker stack and the tunnel stall); not a Kipple defect.
- **Release page (21:41)**: "It doesn't show it's the most recent release. Shouldn't it?" (a pre-release does not
  get GitHub's "Latest" badge); the agent explained that this is GitHub's standard behavior (the badge skips pre-releases and pointed at v0.2.0) and left it as is; the owner: "Works for me."
