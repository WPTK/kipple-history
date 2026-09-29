# Release readiness: v0.3.0-beta.2, 2026-09-29

The pre-tag checks from `docs/RELEASING.md` ("Before the tag", steps 1 to 6), run on `main` at `bf851be` on
2026-09-29 between 13:18 and 13:50 ET, plus the state of the promotion gates. Sources: the transcript of the day, PR
#88, the UAT run reports in `web/uat/results/`. The tag itself, the off-box database copy, the deploy and the GitHub
Release (steps 7 to 11) were not done at the time of writing: they touch production and each waits for the owner's
go-ahead.

## Why beta.2 and not rc.1

The morning meeting decided the next tag is a second beta. The beta.1 soak produced real fixes (the review findings
in [review-high-2026-09-29.md](review-high-2026-09-29.md), the offline "Read the original" bug, the favorited-folder
bug), and per `docs/RELEASING.md` a regression found in a soak resets that soak's clock. Beta to rc.1 needs Suites 1,
2 and 4 re-verified on the beta build plus a one-week soak with zero new P0 or P1 defects.

## Checks

| Step | Result |
|---|---|
| 1 CI green on the exact commit | Green on `bf851be` (the merge of #87). The runs on earlier merge commits showed "cancelled" only because a later push superseded them |
| 2 Fuzz, all targets, 60 s each | All 26 targets clean; no regression seeds written. Ran in the background from about 13:19 to 13:48 |
| 2 UAT Suite 1 against a seeded local instance | First run 13:22: no findings but exit code 2, because the seeded feeds had not fetched and there was no article to open (the runner will not pass a screen it could not check). Second run 13:26: 126 of 126 checks complete (21 screens, 2 themes, 3 widths), S1 to S6 no failures, the same 8 waived `target-size` items (issue #50). Exit code 0 |
| 3 `/code-review high` on the diff since the last deployed tag | `v0.3.0-beta.1..main`: no findings. The changes in between had each been reviewed, and their findings fixed, before merging |
| 4 CHANGELOG | 19 pending fragments folded into `## [0.3.0-beta.2] - 2026-09-29` with `node scripts/changelog.mjs release` (`--dry-run` first), an intro paragraph and the compare links updated. First real use of the tool; the diff was the whole change |
| 5 THIRD_PARTY_NOTICES.md | No dependency changes since beta.1, so unchanged; no govulncheck rerun needed |
| 6 Commit `chore(release): 0.3.0-beta.2`, CI on it | PR #88 opened with CI running |

## Gate status

- Suite 1: clean (above). Suites 2 and 4 were last executed 2026-09-27 (see [uat-results-2026-09-27.md](uat-results-2026-09-27.md));
  neither has been re-run on the beta build, which the rc.1 gate requires. The 22 cases of Suite 2 have not been
  re-walked since the settings, layout, Manage Feeds and Feed Health rewrites of 2026-09-28, so this is a real gap
  to close before rc.1.
- Suite 3: passed on the owner's phone for beta.1; not a gate. The owner's phone pass of the beta.1 fixes (whether #57
  and #62 can close) was pending on 2026-09-29.
- Open issues that are not roadmap items: #57 (layout differentiation; the fix is merged, awaiting the owner's
  confirmation), #62 (tab-bar seam; first pass merged, needs a real-device check). The roadmap issues #33 to #39 are
  deferred by decision.
- Not yet done: soak clock for rc.1 (starts at beta.2 deploy), Reader API regression replay against the deployed
  build, the owner's design call on the Cocoa Mid contrast gap (see the UAT record).

## Findings

None new from these checks. The only blemish was the first UAT run's exit code 2, which was a timing issue with the
seeded feeds and not a defect; the runner's refusal to call an unchecked screen clean worked as designed.
