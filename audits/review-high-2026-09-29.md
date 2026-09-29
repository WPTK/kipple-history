# High-effort review of v0.3.0-beta.1..main, 2026-09-29, and the reviews around it

Reviews run on 2026-09-29 by the lead session while clearing the beta.1 soak backlog. All at `/code-review high`, the
standing gate. The owner's rule from earlier in the project applies: every finding is fixed, nothing goes on a
"not fixing" list. Times are ET.

## Review 1: `v0.3.0-beta.1..main` (diff about 1,715 lines), 07:53 to 08:01

Method: eight finder subagents, one per angle (correctness, removed behavior, cross-file tracing, reuse,
simplification, efficiency, altitude, conventions), then ten verifier subagents on the deduplicated candidates
(one vote each, recall-biased), capped at ten findings. The diff was mostly the day-before beta-feedback work (#63 to
#70) plus the two fixes for #71 and #72 (#74, #75), which had been merged minutes earlier. Ten findings were
reported; nine were CONFIRMED and one (the stale scroll-offset check) PLAUSIBLE. Five were defects in the reviewing
session's own just-merged fixes for #71 and #72.

| # | Finding | Verdict | Severity (graded here) | Fix and merge |
|---|---|---|---|---|
| 1 | `bestSrcset` in the lead-image picker split `srcset` on every comma, corrupting CDN transform URLs that legally contain commas (Cloudinary or imgix style), storing a bogus image URL and discarding a valid `src` (from #71/#75) | Confirmed | Medium (P2) | PR #76, merged 10:42. Now shares the comma-tolerant tokenizer `Absolutize` already used |
| 2 | An unsized hero image scored 0 and lost to any later image with even a tiny declared size (a 48 px avatar), the opposite of the point of #71 | Confirmed | Medium (P2) | PR #76 (unsized candidates get an assumed normal-photo width) |
| 3 | The scroll-restore staleness check (`offsetAsOf`) ran once at mount against a stale cached page and a global watermark, so a stale offset could still be restored over rows about to be replaced (from #72/#74) | Plausible | Medium (P2) | PR #77, merged 10:53. The check no longer trusts a stale cached page's watermark (details in the PR) |
| 4 | `seenIds` for mark-read-on-scroll came from the virtualizer's rendered rows, including the 8-row overscan on each side, so never-visible rows counted as seen | Confirmed | Medium (P2) | PR #77 (uses the virtualizer's visible range) |
| 5 | `seenIds` was not kept across a remount and the pending settle timer was dropped on unmount, so rows scrolled past just before opening an article (routine on a phone) were never marked read | Confirmed | Low (P3) | PR #77 (kept in list memory, flushed on unmount) |
| 6 | The trigger-based new-articles pill and announcement: Refresh all announced once per feed as well as the run total; and a manual refresh that joined an already running scheduled fetch got no pill (from #56/#63) | Confirmed | Medium (P2) | PR #79, merged 11:05. Frontend gate corrected; backend worker now captures its trigger when it starts, and a joined job reports the joiner's real trigger |
| 7 | Manage Feeds: a collapsed folder's feeds were unreachable in Edit and Select mode, yet Select all and shift-click ranges still ran over them, so a bulk delete could remove feeds never seen ticked (from #65) | Confirmed | High (P1): data loss path | PR #82, merged 11:31. Edit and Select render every folder open; the saved collapsed state is untouched |
| 8 | Feed Health: the selection survived search and filter changes, so bulk delete, turn on and turn off acted on feeds no longer on screen (from #66) | Confirmed | High (P1) | PR #83, merged 11:41. Counts and actions use only the ticked feeds still shown; ticks return if the filter widens |
| 9 | `intervalLabel` divided without rounding: a 100-minute interval showed "Every 1.6666666666666667 hours" | Confirmed | Low (P3) | PR #81, merged 11:53. Combined units ("1 hour 40 minutes") |
| 10 | `ToggleDialog` was a near copy of `DeleteDialog` (cleanup only) | Confirmed | Low (P3), maintainability | PR #84, merged 10:42. Shared `useBulkRun` hook and one report type; no behavior change |

Each fix except the refactor shipped with a regression test that was proved to fail without the fix. Merged in the
agreed order #84, #76, #77, #79, #80, #82, #83, #81 (#80 is the separate fix for the owner's offline-article report,
issue #78, see the human-feedback record), with the changelog conflicts between them resolved by hand for each,
which is what motivated the changelog fragments below.

Items the ten-finding cap dropped, handed to the follow-up PR: duplicate `### Changed` headings under Unreleased
(resolved by the fragments tooling in #85), a missing `url` in the local dev-server config (added), the two
booleans `editMode` and `selecting` in Manage Feeds that are really one three-way mode (still two booleans), and an
effect in `ListPane` that resets state on a key change that never happens (not recorded as done).

## Review 2: independent reviews of the fixes, 09:30 and 10:41

Before merging, three read-only reviews (#76, #77, #79) were run at the owner's request ("Review first, then let's
meet back and discuss the plan again") and the fixes were then reviewed again.

| PR | Finding | Severity (graded here) | Resolution |
|---|---|---|---|
| #76 | Wide, short banner images (a 728 x 90 leaderboard ad or divider) beat the hero photo because scoring used width only; a gap from #71 already on `main`. Also an integer overflow in the shape check | Medium (P2) | Fixed: banners rank below unsized images and photos but above tiny icons; a 2000 x 450 panorama no longer loses to a 16 px icon |
| #77 | The snap-to-top check never disarmed, so any later data change (a resync, a bulk mark, an offline replay) threw the reader back to the top mid-read, worst on wide screens where the list stays beside the article | High (P1), introduced by the reviewing session | Fixed: disarms once the list settles |
| #77 | Turning mark-read-on-scroll off still flushed pending rows as read | Low (P3) | Fixed |
| #77 | The infinite-scroll effect could fetch a next page while a refetch was in flight, cancelling the on-mount refetch at a deep restored offset | Medium (P2) | Fixed; no regression test possible in jsdom, said so in the commit |
| #79 | An OPML import that joined a scheduled fetch was labelled manual, so the pill showed imported items; a new feed's first fetch could be labelled `feed_manual` in a narrow race | Medium (P2) | Fixed: only a joining request that is a real manual refresh promotes the joined job; `docs/design.md` notes the event's trigger can differ from the logged one |
| #76, #77 | Focused re-review of the two fixes above | none | Clean |

## Review 3: the changelog tooling, PR #85, 12:00

Two findings: the default release date came from the UTC clock, so a release run at 21:00 EDT would be stamped the
next day (Medium, P2); and the release CLI's argument parsing had no test (test coverage). Both fixed before merge.
CodeQL also flagged a regex built from a heading string, see [codeql-findings-2026-09-27.md](codeql-findings-2026-09-27.md).
PR #85 replaced editing `CHANGELOG.md` by hand with one file per change under `changes/` and `scripts/changelog.mjs`
(`check`, `preview`, `release`, `notes`); it merged 12:55 after the owner was asked, because it adds two steps to the
CI web job.

## Review 4: the favorited-folder fix, PR #87, 12:56

One finding (reuse, Low, P3): the collapse chevron button was hand-copied twice in `FeedsScreen` and once as
`CollapseToggle` in the sidebar. Fixed by sharing `CollapseToggle` and a shared feed row before merge.

## Review 5: the pre-tag review for beta.2, 13:19

No findings. See [release-readiness-beta2-2026-09-29.md](release-readiness-beta2-2026-09-29.md).

## Process notes

- The owner granted the agent permission to merge pull requests with green CI on the head commit "as long as we
  discuss first" (09:24), and the allow rule was written to the local settings file at 09:26 with his approval. The
  first eight merges of the day were made under that rule.
- Standing lesson repeated by this day: five of the ten findings in review 1 were in fixes merged an hour earlier
  without an independent review. Review 2 exists for that reason and found one more serious bug (the never-disarmed
  snap-to-top) that would have shipped.
