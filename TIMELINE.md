# Timeline

Dated chronology of building Kipple with an AI coding agent, 2026-09-24 to 2026-09-29.

Sources: `git log --date=iso` in the Kipple repo (times are the author's local clock, US Eastern, UTC-4),
annotated tags, the diary in [diary/](diary/), and the session transcripts. The diary and the transcripts
record UTC; where they differ, the git time is given here. Commit counts are `git rev-list --count <tag>`
(all ancestors, merges included), so they are cumulative.

Tags in the Kipple repo (dates are the commit dates the tag points at; deploy times can be later):

| Tag | Commit date (ET) | Commit | Cumulative commits |
|---|---|---|---:|
| `v0.1.0` | 2026-09-25 07:06 | `d6e285d` | 64 |
| `v0.2.0-alpha.1` | 2026-09-25 20:08 | `4d14ca8` | 216 |
| `v0.2.0-alpha.2` | 2026-09-25 22:57 | `b74170d` | 233 |
| `v0.2.0-alpha.3` | 2026-09-26 06:27 | `59c7deb` | 323 |
| `v0.2.0-alpha.4` | 2026-09-26 09:12 | `b7d0219` | 352 |
| `v0.2.0` | 2026-09-26 09:27 | `55743ca` | 354 |
| `v0.3.0-alpha.1` | 2026-09-26 11:03 | `7497c4c` | 362 |
| `v0.3.0-alpha.2` | 2026-09-26 13:34 | `640fe2c` | 373 |
| `v0.3.0-alpha.3` | 2026-09-26 18:13 | `42fd5c8` | 492 |
| `v0.3.0-alpha.4` | 2026-09-26 22:26 | `56fc6ad` | 497 |
| `v0.3.0-alpha.7` | 2026-09-27 02:26 | `00510e3` | 529 |
| `v0.3.0-beta.1` | 2026-09-27 21:12 | `12121c7` | 599 |

`v0.3.0-alpha.5` and `v0.3.0-alpha.6` were merged (PRs #20 and #22) but never tagged; they shipped inside alpha.7. The
tag objects were created a little after these commits: alpha.4 at 22:36, alpha.7 at 08:55 and beta.1 at 21:35. Beta.2's
release commit (`585e961`, 2026-09-29 13:49, PR #88) merged at 14:01 (squash commit `95173b8`); not yet tagged at the time of writing.

## 2026-09-24 (Thursday): planning and research

- 11:00 First commits: `.gitignore`, then `CLAUDE.md` with the standing decisions (Go, React, SQLite, Google
  Reader API only, no Fever, Reeder Classic as primary client).
- Session 1 (transcript starts 10:34 ET): the owner pastes the kickoff prompt: build a self-hosted RSS reader to replace
  yarr, "Start in plan mode. Ultracode is on for this project." The planning session runs on Fable 5.1 at max
  effort. Large research workflows fan out (about 110 agents). Repeated usage-limit hits.
- 21:01 Kickoff prompt committed (`docs/KICKOFF.md`). 21:25 to 22:52: research reports, open-question triage,
  lemon24/reader prior-art report, phase 1 design and project plan.
- 23:08 `.gitattributes` and line-ending renormalisation.
- 23:10 to 23:56 Phase 1 implementation begins: config, embedded frontend, Dockerfile, SQLite store and
  migrations, feed fetch, sanitizer.

## 2026-09-25 (Friday): phase 1 finished, deployed; phase 2 built; two alphas

Carried over from the night before (transcript times converted to ET): at about 21:38 on 09-24 the owner notices the
token burn ("everything is burning at max/ultracode speed"), and at 23:04 tells the agent to begin phase 1 with
the model policy discussed; a start prompt for a fresh implementation session follows.

- 00:02 to 01:07 Fetch, scheduler, OPML, Reader API (item ids, streams, edit-tag), sessions and login lockout,
  status page.
- 05:18 to 05:34 Phase 1 review fixes (from an eight-reviewer Opus code review): OPML, fetch, auth, Reader API
  hardening. 15 fixes.
- 07:06 Maintenance goroutine, nightly job. 07:29 Merge of phase 1 to `main` (PR #3, merge commit `4a688f2`).
- Early morning to 07:30 (the owner answers a bullet list, then is mostly away): keeps the login lockout, cookie at 90 days,
  approves a read-only deploy key, pauses yarr. the owner makes the Cloudflare Access bypass and tunnel changes himself.
  Phase 1 is deployed on Host-A, 138 feeds imported; Reeder Classic and NetNewsWire both sync. Tag `v0.1.0`.
- 11:44 ET (15:44 UTC): the owner pastes the phase 2 kickoff brief. Step 0: he answers five feedback questions in
  one line.
- 11:50 to 13:29 Phase 2 backend: stats recorder, card lists, search (FTS5), image proxy, full-text extraction,
  feed CRUD.
- 13:39 CI expanded: govulncheck, staticcheck, gosec, gitleaks, Trivy, gofmt, shuffled race tests. Dependabot,
  delete-branch-on-merge, release tags, SemVer, Keep a Changelog.
- 14:01 to 16:25 Settings API, browser user-agent fallback, ingest-side full-text extraction, Reader API hold
  for pending full-text items.
- 14:54 Settings-direction discussion (in-app settings; multi-user raised and withdrawn). the owner's UI
  meeting agenda arrives at 16:30, with round 1 answers at 16:53 and round 2 at 17:05 to 17:15. the owner tests the first
  real-device build after alpha.1.
- 16:54 UI design meeting round 1 (prework, audit, decision log); 17:10 round 2 (colours, layouts, keymap,
  density, backend additions); 17:13 merged as PR #4.
- 17:34 to 18:58 Frontend: Vite 8, React 19, Tailwind 4, 20-scheme theme system, list and article view, gestures,
  five layouts, keymap, undo, backup export and restore, settings screen, feed management.
- 20:08 `v0.2.0-alpha.1` commit, deployed to Host-A (intermediate deploy: migrations 0002 and 0003).
- 22:57 `v0.2.0-alpha.2` commit, deployed after the owner's phone and PC testing and two Opus review rounds.
- Night (about 23:24 ET): the owner: "im going to sleep, continue to work as much as you can." Agent builds backend
  steps 8 to 17 (filters, device profiles, image cache, thumbnails, search stemming, saved searches, auto-read),
  does not deploy. Phase 1 ultra review PRs #5 to #8 run in separate sessions.

## 2026-09-26 (Saturday): review, docs audit, alpha 3 and 4, v0.2.0, release prep

- Overnight: ultra review results for phase 1 come back; agent fixes findings and runs a git hygiene pass.
- 05:22 ET (09:22 UTC) the owner: "Quick status update meeting for the morning, please? Give it to me at manager
  level." Five calls made.
- 06:06 to 06:27 Docs audit: eight agents, 285 discrepancies between docs and code, all addressed; merged as
  PR #9.
- About 06:39 `v0.2.0-alpha.3` deployed to Host-A (migrations 0004 and 0005 applied, health 200, 48 MiB RSS).
- 06:45 to 07:19 Phase 3 handoff written, CLAUDE.md proposals applied, diary added, 14 review-only draft PRs
  (#10 to #23) prepared.
- About 07:07 ET (11:07 UTC) the owner runs `/code-review ultra 10`: rejected (444 files, 84,636 lines against limits of 500 files and
  8,000 lines). PRs rebuilt as `main` plus one area each; old PRs closed; new PRs #24 to #37.
- About 07:20 to 08:30 ET: 13 cloud reviews (r1 to r8 backend, w1 to w5 web). the owner starts with $214 in credits and
  ends with about $17. Findings fixed on `phase-2` (07:39 to 08:43 commits).
- About 08:58 ET: the owner reports a list rendering bug on his phone (overlapping rows after opening an article and
  going back). Diagnosed in the browser pane, fixed in `b7d0219` (09:12).
- 09:12 `v0.2.0-alpha.4` commit; deployed after the owner's go-ahead at about 09:19. 09:27 `phase-2` merged to `main` (merge commit `2059af9`), `v0.2.0` tagged
  (`chore(release): 0.2.0`, `55743ca`). 09:28 phase 2 close-out diary.
- Phase 2 follow-up meeting ("what do we have left?"): release-prep list (backups, health check, license, fuzz
  tests, real-feed status). the owner asks for a licence recommendation; rejects any licence carrying his real name;
  compares Apache 2 and MIT, then Blue Oak and PolyForm; picks Blue Oak.
- 09:41 to 10:12 Four release-prep branches (not merged into `main` at the time of writing): `relprep-docker`
  (healthcheck subcommand, HEALTHCHECK, OCI labels), `relprep-license` (LICENSE first PolyForm Noncommercial,
  changed to Blue Oak Model License 1.0.0 at 09:50), `relprep-restore` (restore hardening, snapshot
  permissions), `relprep-fuzz` (fuzz targets for untrusted-input parsers).
- Seven Dependabot bump branches appear on `origin` during the day.
- About 10:07 ET the owner: GitHub Actions minutes are exhausted. Concurrency cancellation added earlier.
- About 10:10 ET the owner: asks whether to go public now with a preliminary "first public publish" to clear
  secrets, hostnames, IPs and names, and asks for this repo, `kipple-history`. This repo is the result.

## 2026-09-26 (Saturday), late morning to evening: public repo, phase 3, review, alpha.3

- 10:15 to 11:03 The code repository goes public: history rewritten with `git filter-repo` on a scratch mirror, an
  independent hostile audit found leaks the first pass missed, the original became the private `WPTK/kipple-archive`,
  a fresh public `WPTK/Kipple` was published with 362 commits and 7 tags; `v0.3.0-alpha.1` at 11:03 (Blue Oak license,
  notices, health check, hardened compose options, fuzz targets, restore fixes, local CI).
- 11:16 New session (handoff prompt): phase 3. Branch `phase3-pwa`; the two reserved Reader API settings, a test for
  auto-read on disabled feeds, then manifest and generated icons, root static files, `include=content`, star `at`,
  the `X-Kipple-API` handshake, a hand-written service worker, an IndexedDB queue for offline star and read changes,
  unread prefetch, an offline notice.
- 11:49 to 11:58 The built-in browser pane cannot register a service worker; the owner installs Claude in Chrome. In real
  Chrome the worker registers, the app launches offline, and an offline star reaches the server with its `at`.
  PR #8 opened.
- 12:06 "Follow your recommendations ... including clearing out the backlog": `/code-review high` on phase 3
  (four Opus finders) finds 15 real bugs in the agent's own work, all fixed; GitHub Releases created for all seven
  existing tags; favicon finder (PR #9) and lossless-WebP tests (PR #10) built by two agents (lossless WebP was already
  supported, the backlog item was stale). 13:04 the owner asks for the web password reset command (only a hash is stored;
  the CLI sets a new one).
- 13:07 the owner: phone tests passed, "deploy to host-a instead of host-a". PRs #8 and #10 merged, `chore(release)` PR #11,
  26-target fuzz run (23 at the time) clean, off-box database copy, a real read-only-filesystem container test,
  hardened compose applied, `v0.3.0-alpha.2` tagged (13:34) and deployed to Host-A: healthy in under a minute.
- 13:45 the owner: the ultra reviews cannot run (no credits); "if there's some internal way ... that would be fine". Eight
  read-only Opus agents audit `main` by area (about 65 findings, no critical); report in
  [audits/local-review-2026-09-26.md](audits/local-review-2026-09-26.md). the owner also notes CI can be turned back on
  (it already was; PR #12 fixed the docs line).
- 14:10 the owner: "All findings must be fixed. Even the minor ones. Spool up multiple agents." Eight fixer agents in
  parallel worktrees (disjoint file ownership) merged into PR #13; a second review of the merged diff (three agents)
  plus one on the favicon PR found regressions the fixes introduced; second fix round; GitHub CI (with `-race`) then
  caught a data race in a test the fixers wrote. See [audits/local-review-round2-2026-09-26.md](audits/local-review-round2-2026-09-26.md).
- Afternoon merges (ET): PR #8 phase 3 and #10 lossless WebP tests 13:07; #11 release alpha.2 13:34; #12 CI docs 14:11;
  #13 review fixes 16:27; #14 test-race fix 17:04; #9 favicon finder (after its ten review findings) 17:14; #15 `ot`
  unread/unstar with migration 0007 (reviewed first) 17:44; #16 release alpha.3 18:13, tagged and released on GitHub.
- 18:45 Migration rehearsal on a copy of the live database on Host-A (0006 and 0007 in about 30 ms). 18:57 the owner's
  go-ahead ("Deploy alpha.3"); off-box copy to Host-B; alpha.3 deployed: healthy, version `0.3.0-alpha.3`, no
  warnings, 51 MiB. History repo updated; phase 4 handoff written.

## 2026-09-26 to 27: phase 4 begins

- Evening: stats pre-meeting (nine topics), decisions recorded. the owner approves two CLAUDE.md edits (web app is the intended
  client; a simple opt-in Wrapped is allowed under "no social").
- Alpha.4 built and reviewed twice (see diary/2026-09-27.md); PR #17 opened. Not deployed.
- 2026-09-26 22:37 (ET): alpha.4 deployed to Host-A (tag v0.3.0-alpha.4, commit 56fc6ad, schema 8). Release published.
- 2026-09-27 00:00 (ET): alpha.5 (Stats screen, PR #19) reviewed twice and fixed; alpha.6 (export and data controls)
  started on branch phase4-stats-export.

## 2026-09-27 (Sunday): alpha.5 to alpha.7, phase 5, beta.1

Overnight (00:00 to 02:37 ET, first session; details in diary/2026-09-27.md):

- 00:04 PR #19 (alpha.5 Stats screen) merged, release PR #20. 00:26 a test run inside Docker on Host-B briefly restarted
  Docker Desktop: public services down 20 to 50 s (CHALLENGES.md #25).
- 01:12 CI `-race` catches five new export tests timing out (25,000 single-row inserts in one write); fixed by chunking.
  01:33 PR #21 (alpha.6 export and data controls) merged, release PR #22. PR #23 (alpha.7 Wrapped), #24 (Dependabot config)
  and #25 (release) merged by 02:26; main at `00510e3`, zero open PRs. 02:37 morning brief.

Daytime and evening (diary/2026-09-27-sunday.md; commit times from git, PR merge times from the merge commits):

- 08:32 Morning meeting. 08:53 the owner authorises the deploy, vulnerability reporting and HTTPS for the site. 08:55
  `v0.3.0-alpha.7` tagged. 09:22 stuck worktree process killed. About 09:27 alpha.7 deployed to Host-A after the off-box
  copy, migration rehearsal (0009) and 26-target fuzz run.
- 09:32 to 09:52 kipple-history scrub, first pass: private original renamed to an archive, rewritten history published as
  a new public repository; my own write-up briefly reintroduced two hostnames (under two minutes).
- 10:18 to 10:42 user-level settings commands; DNS instructions for the project site; certificate found already issued,
  HTTPS enforced (301). 11:00 Docker guard hook handed over.
- 11:01 New session. Phase 5 planning meeting; 11:17 decisions recorded (`d2ea1c8`); code audit and Access JWT work start
  in the background.
- 11:30 to 11:43 audit fixes on `phase5-code-audit`; 12:20 PR #26 merged (24 defects). 11:51 to 12:10 UAT plan, SQA plan,
  release ladder and risk register written (third-party UAT skill declined). 12:17 to 12:30 PR labels, milestones,
  backfill of 25 PRs, issues #27 to #39 filed.
- 13:03 PR #40 (Access JWT, optional password) merged. 13:18 to 14:36 auto-night theme, six review rounds; PR #41 merged 14:36.
- 14:41 UAT Suite 4 (restore drill, migration rehearsal). 14:55 to 15:08 docs run, PR #42 merged (hostnames removed from
  four docs; the project domain kept). 15:10 to 15:11 CodeQL alerts examined; a mistaken dismissal with a placeholder
  comment, then the classifier blocks further attempts.
- 16:10 to 16:17 UAT Suite 2 findings, PR #45 merged. 16:35 UAT Suite 1 (PR #46) merged; 16:39 CodeQL follow-up PR #51 merged.
- 16:40 the owner asks for the next version. 16:42 to 18:04 UAT Suite 5 walkthrough on Host-A (interrupted once by a
  declined browser navigation). 18:04 README Quickstart fix; recommendation `v0.3.0-beta.1`.
- 18:07 to 18:19 pre-tag `/code-review high` finds six confirmed bugs, one critical SSRF-guard escape; fix agents start.
- 18:50 all open issues checked against the code. 19:02 to 19:15 wording fixes and phase 5 issue batch. 19:09 the owner
  reports stale feeds, filed as #52.
- 19:21 PR #53 and 20:33 PR #54 opened (regression tests and accessibility fixes; the six review fixes, with a second
  SSRF hole found by the fix agent's own reviews). 21:03 both merged.
- 21:05 the owner: go to `0.3.0-beta.1`. 21:12 release commit. About 21:22 to 21:35 the tunnel outage (error 1033 on every
  tunnelled site, stuck QUIC dial, fixed by a plain restart). 21:35 tag pushed, deployed to Host-A, GitHub pre-release.
- 21:45 the owner closes #52. 21:57 CodeQL alerts recorded as R8 and R9 (`1158ca3`). 21:59 the owner starts a new
  session for the beta feedback meeting.

## 2026-09-28 (Monday): beta feedback, overnight tasks, the public-repository incident, README

Sources: diary/2026-09-28.md, CHALLENGES.md #26. Times ET.

- 22:06 (Sunday night) New session. The owner's phone-testing notes for beta.1 (ten items) triaged into issues #55 to #62.
- 22:36 to 23:19 fixes committed: N-new pill only after a manual refresh (`c9b47b0`), mobile tab-bar seam (`d20a0b4`),
  mobile folder collapse and Manage Feeds edit mode (`6a1470a`), Feed Health bulk actions and Manage-this-feed menu
  (`7d972bc`); PR #66 merged 23:19. Conflicts on `CHANGELOG.md` between PRs #63 to #65 begin.
- 23:38 README revamp (`9ac56fe`), PR #67. The owner sleeps with a fixed task list: mockups for #55 and #57, git hygiene,
  README, a visual check of the project site, keeping this repository current.
- Overnight: five mockup artboards; ten stale worktrees and their branches removed; the kipple-website check finds one stale
  status paragraph (kipple-website#1). Following its link to this repository shows real hostnames and a local path in
  it; scrubbed, then the history rewritten and force-pushed after the owner's go-ahead (CHALLENGES.md #26).
- 07:14 The owner: scrub it, "that should have been the logical conclusion". 07:16 PRs #67 and #63 merged.
- 07:28 to about 08:00 Morning meeting: mockups approved; repository history rewrite approved; a question about four
  related repositories leads to deleting the redundant archive (blocked on a missing `delete_repo` scope).
- 07:46 to 09:18 Second session: README rounds (08:00 blunt critique, 08:08 parking-lot item, 08:12 to 08:36 specific
  edits). Commits 08:05 to 08:37. Layout differentiation `8a5cc47` 08:02; master-detail Settings `409d595` 08:35.
- 09:30 PR #64 (tab-bar seam) merged after its deleted branch was recovered from the PR reference. 09:57 second imgproxy
  CI 900 s timeout, on PR #70.
- 11:25 status. 11:37 to 11:39 PRs #69, #68, #65, #70 merged in that order. 11:42 issue #71 filed. 15:50 issue #72 filed.
- After 15:51 no session activity is recorded until Tuesday 07:02.

## 2026-09-29 (Tuesday): review of the day's own merges, changelog fragments, beta.2 preparation

Sources: diary/2026-09-29.md, CHALLENGES.md #27. Times ET.

- 07:02 The owner: Go tests failing CI on `main`. 07:05 PR #73 (imgproxy test fix, root cause) opened; 07:06 merged.
  07:06 to 07:18 morning-meeting brief written and a handoff prompt for a new session.
- 07:23 New session. Meeting decisions: beta.2 next, not rc.1; #71 and #72 into Phase 5; #31 closed; archive repository
  deleted; changelog tooling queued. 07:35 to 07:52 PRs #74 (`b862081`, scroll restore and mark-read) and #75
  (`0082d37`, lead image by size) merged.
- 07:52 to 08:01 `/code-review high` on `v0.3.0-beta.1..main`: ten findings, five of them regressions in #74 and #75 (fixed in #76 and #77).
- 08:07 to 08:54 fixes as PRs #76, #77, #79, #82, #83, #84, #81; #80 for the owner's offline "read the original" report
  (#78). 08:45 the owner asks whether the workflow is typical; review-before-merge adopted.
- 09:23 to 09:28 merge permission for green-CI PRs after discussion; rule saved; `gh pr merge` allowed in local settings.
  09:32 to 10:14 per-PR reviews find a serious bug in #77 (snap-to-top never disarms) and gaps in #76, #79; fixed.
- 10:42 to 11:53 merges in order: #84 (10:42), #76 (10:42), #77 (10:53), #79 (11:05), #80 (11:15), #82 (11:31),
  #83 (11:41), #81 (11:53).
- 11:57 to 12:55 changelog fragment tooling, PR #85 merged 12:55. 13:09 PR #87 (favorited folder, #86) merged.
- 13:18 to 13:49 beta.2 preparation: fuzz clean, UAT Suite 1 clean, final review clean, release commit `585e961` (PR #88, merged 14:01). 14:08 PR #89 (the daily-history rule) merged.
- 13:53 The owner asks for a full check of this repository ("I don't see any entries from Sunday"); four writers fill
  the gaps. Beta.2 tag, off-box copy, deploy and GitHub Release not yet done at the time of writing.
