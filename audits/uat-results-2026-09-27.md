# UAT results, Suites 1 to 5 (2026-09-27, Suite 1 re-run 2026-09-29)

Source of the plan and the per-case records: Kipple `docs/uat-plan.md` (written 2026-09-27 from the owner's request
to add UAT to the release process; adapted from a standard UAT guide) and the Suite 1 tool in `web/uat/`. This
file collects the outcomes with severities and what happened to each finding. Severity scale from the plan: P0
blocker, P1 high, P2 medium, P3 low. The exit criteria: every case executed or waived by the owner, no open P0 or
P1, P2 and P3 fixed or explicitly waived, owner sign-off.

The plan considered and declined the third-party `webapp-uat` skill (its install command pulled a package from a
different owner than the GitHub repository, and its i18n checks do not apply); the same ideas were built in-repo
with Playwright (Apache-2.0) and axe-core (MPL-2.0). The plan first said "MIT-licensed dependencies only", which
neither tool is; the wording was corrected in place and flagged for the owner.

## Suite 1: scripted Playwright and axe-core (`npm run uat`, PR #46)

Checks S1 console errors, S2 API failures, S3 axe WCAG A/AA, S4 sideways scroll and clipping at phone and tablet
widths, S5 literal `undefined`/`NaN`/`[object Object]`/`Invalid Date`, S6 the theme contrast script over all 20
schemes. Each screen runs in Paper and Midnight at 1280, 768 and 390 px.

First real run, 2026-09-27 16:17 ET, seeded local instance: 90 of 90 screen checks completed, S1, S2, S4, S5, S6
clean, S3 38 findings from four distinct issues. All four were filed the same evening and fixed in PR #53 (merged
21:03 ET):

| Issue | Finding | Severity | Resolution |
|---|---|---|---|
| #47 | Manage Feeds "Select" button had no accessible name below 400 px (axe `button-name`) | axe critical (graded P1) | Fixed: `aria-label` carries the state ("Select"/"Done"); `aria-pressed` removed because a changing name plus pressed state announces twice |
| #48 | Midnight secondary text on the selection colour was 4.05:1, needs 4.5:1 (`color-contrast`) | axe serious (graded P2) | Fixed: Midnight text2 `#9a9a9a` to `#a6a6a6`. The new check (text2 on selection, added to `scripts/contrast.mjs` and `theme.test.ts`) found three more schemes under 4.5:1 (Graphite, Carbon, Lamplight), also fixed. **Cocoa Mid (4.00) is not fixed**: its selection is lighter than its page, so any fix trades one contrast for another. It is listed as a known gap and awaits the owner's design call |
| #49 | Your year scroll region not keyboard focusable (`scrollable-region-focusable`) | axe serious (graded P2) | Fixed: `role="region"` named by the h1, `tabIndex=0` while cards show, focus ring drawn inside the pane |
| #50 | Row title links 19 to 21 px tall (`target-size`) | axe serious; judged a false positive (P3) | Waived with a reason in `web/uat/waivers.json`: the link's `::after` stretches over the whole row (44 px or more on touch), axe measures only the text box. Issue closed with PR #53 |

PR #46's own review notes: `/code-review high` ran eight times on the runner; five late findings were left open in
the PR text (a row could be marked ok before late events arrive, a crash of the contrast check was filed as an S6
finding, an unused waiver scoped to `boot` was not reported, a link probe could wait 3 s, a synthetic router entry
depended on React Router's history-state shape). CodeQL then flagged two more in the runner, see
[codeql-findings-2026-09-27.md](codeql-findings-2026-09-27.md).

Re-runs: 2026-09-29 13:22 ET, 21 screens by 2 themes by 3 widths (126 checks): zero failures, but exit code 2
because no article had been fetched yet to open (the run refuses to pass a screen it could not check). Second run
13:26 ET: 126 of 126 complete, S1 to S6 no failures, 8 waived target-size items (#50). That is the beta.2 pre-tag
result, see [release-readiness-beta2-2026-09-29.md](release-readiness-beta2-2026-09-29.md).

## Suite 2: agent-driven scenario walkthroughs (PR #45)

Driven in the desktop app's built-in browser pane against a throwaway local instance (its own data dir, a local test
feed for controlled arrivals). Side effects of the pane being hidden are recorded in the plan (no focus, stalled
`ResizeObserver` and transitions, no reading time); none is a Kipple defect. Twenty-two cases carry results in the
plan (PR #45's text says 20 passes; the count in the plan record was not reconciled), all pass or pass with the
qualifier noted; Reeder Classic and NetNewsWire cases TC-A1 to A3 were skipped (they need the owner's devices).

Qualified passes: TC-F2 used a 6-feed fixture instead of the owner's 138-feed export; TC-R3 passed after a fix;
TC-R6 auto-read-after-N-days could not show matches on a fresh instance (covered by store tests); TC-T1 was a
short session; TC-C1 tested only the negative case (no Access configured; an empty password is refused even with a
forged assertion header); TC-P2 was checked statically because the pane refuses every service worker.

| Finding | Severity | Resolution |
|---|---|---|
| `/` from another screen focused the Search heading, not the box (TC-R3) | Medium (P2) | Fixed in PR #45: the shell is the single writer of arrival focus; the hotkey asks for the box through router state |
| Highlight filters always said "Hasn't matched anything yet" (TC-R6); the server never counts highlight hits | Low (P3) | Fixed in PR #45: a highlight rule now describes what it does |
| OPML import summary mixed singular and plural (TC-F2) | Low (P3) | Fixed in PR #45 |
| #43 "Only 1 day of reading" contradicts "No days with reading" when a year has opens but no reads (TC-T4) | Low (P3), copy | Filed for the owner, fixed in `686cde8` (19:02 ET), closed |
| #44 Unread empty state says new ones appear after the next refresh while the "1 new article" pill is showing (TC-R7) | Low (P3), copy | Filed for the owner, fixed in `686cde8`, closed |

The PR review also left one pre-existing issue unchanged and noted it: `FeedsScreen` reads a one-shot `state.open`
that it never clears, so Back or Forward can reopen the Add dialog.

## Suite 3: owner-only, real device

Not a promotion gate (decided 2026-09-27): the owner checks these informally as he uses each build. Tooling was
considered and rejected for this suite: both suggested iOS simulator skills need macOS and Xcode, and a simulator has
no real lock screen, background behavior, touch swipes or Add-to-Home-Screen flow, which is what the suite tests.
Result: passed, from the owner's phone on beta.1 ("all Suite 3 testing seems to indicate 'pass' from my phone",
beta.1 feedback item 10, recorded 2026-09-27 evening). Covers TC-D1 to D4 (install and relaunch, swipe gestures,
Web Share, and `document.hasFocus()` in the installed app). TC-D4 closed risk R1 and issue #30. No findings.

## Suite 4: migration rehearsal and restore drill (2026-09-27)

The live nightly snapshot (schema 8, 138 feeds, 6,594 items) was copied off the running container without touching the
live database and restored onto a throwaway volume with the deployed image. `kipple restore` reported the backup
passed its integrity checks; starting a container on it applied migration 0009 automatically and went healthy on
`/healthz`. The live container was never stopped or touched. This satisfied TC-C3 and the standing migration
rehearsal item. Findings: none. Throwaway artifacts removed.

## Suite 5: fresh-machine Docker walkthrough (2026-09-27)

A clean clone of the public repository was followed using only `README.md`, on one host with no SSH step, in an
isolated container, image and volume. Finding (medium, P2): the README had no clone-to-login sequence and the compose
example's own comment told the reader not to use it standalone and to see `CLAUDE.md`, which is written for the
project's contributors. The path itself worked (`.env`, compose copy, password, build, up; 9 migrations, health OK,
login through the API). Fixed: the README gained a Quickstart with the exact sequence and the compose comment was
corrected. The plan itself says to run this suite as a single-host self-hoster, since the owner's two-host setup is his own
convenience. Everything torn down afterwards.

## Not yet done from the plan

The Reader API regression replay (recorded Reeder Classic and NetNewsWire request sequences against a deployed
build) and TC-A1 to A3 remain with the owner's client testing. There is no separate `uat-findings` file; this record
and the plan's executed sections are the findings record.

## Update 2026-09-29: rc.1 re-verification on v0.3.0-beta.2

Suites 2, 4 and 5 were re-run and Suite 1 twice (once on beta.2, once on the beta.3 candidate). Suite 2: 21 of 26 cases
pass, 1 fails, 4 skipped or blocked; nine defects (B2-1 to B2-9) filed as #92 to #100, none P0 or P1, all fixed in beta.3;
the one follow-up is the offline-reads issue #108. Suites 4 and 5 passed (Suite 5 with a P3 note, #102). Suite 1 on the
beta.3 candidate found a latent wide-row overflow (fixed in #115) and then exited 0. The full records are in
`docs/uat-plan.md` of the code repository.
