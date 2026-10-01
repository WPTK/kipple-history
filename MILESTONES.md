# Milestones

One section per release or phase. Sizes are from git in the Kipple repo: cumulative commit counts from
`git rev-list --count`, line counts from `git diff --shortstat` between tags (added and removed lines, all files
including generated files, docs, tests and lock files). They measure volume, not quality or effort. Ancestors of
merge commits are counted, so merge commits and agent-worktree commits inflate commit counts slightly.

Totals at `v0.2.0`: 354 commits on `main` history, 544 files, 114,242 lines added. Of that, Go code 63,527 lines
in 264 files (31,146 lines of it in 128 test files), web app about 34,780 lines in 176 files (includes
`package-lock.json`, bundled fonts metadata and scripts), docs 13,156 lines in 37 files.

See also: [TIMELINE.md](TIMELINE.md), [DECISIONS.md](DECISIONS.md), [CHALLENGES.md](CHALLENGES.md).

## Planning (2026-09-24), no tag

- Shipped: `CLAUDE.md` decisions, 21 research documents, open-question triage, `docs/design.md`, `docs/plan.md`,
  kickoff prompt. Files: [plans/history/](plans/history/), [research/](research/).
- Shaping decisions: Go + SQLite + embedded React; Google Reader API only (no Fever); Reeder Classic as the primary
  client; prior art lemon24/reader used for internals, not copied from Reeder; one image, one container, one port.
- Cost: the planning session ran everything at max effort on Fable 5.1 (about 110 subagents, well over 10M
  tokens) and hit the usage limit repeatedly. See [CHALLENGES.md](CHALLENGES.md) item on model and effort.

## Phase 1: `v0.1.0` (2026-09-25 07:06 ET, `d6e285d`)

- What shipped: feed fetch with conditional requests and backoff, SQLite store (WAL, three pools, commit gate,
  `PRAGMA user_version` migrations), retention with tombstones, scheduler and SSE hub, OPML import and export,
  the Google Reader API (ClientLogin, item id codec, streams, edit-tag, mark-all-as-read), sessions and login
  lockout, a status page, nightly maintenance. Deployed on Host-A, replacing yarr (paused, not removed).
- Size: 64 commits, 29,080 lines added in 161 files (from the empty tree).
- Decisions that shaped it: login lockout kept (10 failures per 15 minutes per IP), cookie 90 days, separate
  generated API password, stats inference off, restore window capped at 180 days, yarr paused via a compose profile.
- Process: eight-reviewer Opus code review, 15 fixes before deploy; a differential-fuzz style review of the
  Reader API form parser caught a regression (see [CHALLENGES.md](CHALLENGES.md)).
- Later reviewed again: `/code-review ultra` on phase 1 (four review-only PRs #5 to #8) found more; fixed overnight
  into phase 2.

## Phase 2 alpha 1: `v0.2.0-alpha.1` (2026-09-25 20:08 ET, `4d14ca8`)

- What shipped: first web UI (magazine list, article view), search (FTS5), image proxy with SSRF guard, full-text
  extraction, feed CRUD, settings API, backup export and restore, gesture layer, 20 colour schemes, keymap, undo.
  Migrations 0002 and 0003. Intermediate deploy to Host-A so the phone behaviour could be checked early.
- Size: 216 cumulative commits (+152 since v0.1.0); 46,272 lines added and 1,363 removed in 277 files.
- Decisions: [UI design rounds 1 and 2](MEETINGS.md) (docs/ui-decisions.md), settings in the app not config files,
  SemVer with prereleases, Keep a Changelog, CI gates (govulncheck, staticcheck, gosec, gitleaks, Trivy).

## Phase 2 alpha 2: `v0.2.0-alpha.2` (2026-09-25 22:57 ET, `b74170d`)

- What shipped: fixes from the owner's real-device testing (iPhone and PC) and two Opus review rounds.
- Size: 233 cumulative commits (+17); 5,467 lines added and 533 removed in 83 files.
- Evidence: [human-feedback/phase2testing.md](human-feedback/phase2testing.md) and the Reeder log under
  [human-feedback/evidence/](human-feedback/evidence/). The debug logs for Reeder's mark-all-as-read `ts` question
  from alpha.1 were lost by a container recreate.

## Phase 2 alpha 3: `v0.2.0-alpha.3` (2026-09-26 06:27 ET, deployed about 06:39, `59c7deb`)

- What shipped: everything built overnight: migrations 0004 (filters, muted items, device profiles, auto-read) and
  0005 (FTS porter stemming rebuild), image cache with thumbnails, keyword filters and highlights, saved searches,
  search v2, phase 1 ultra-review fixes, and the corrected docs from the 285-item audit.
- Size: 323 cumulative commits (+90); 35,238 lines added and 1,295 removed in 268 files.
- Deploy discipline: off-box database copy, compose and `.env` backups, tag on the exact green commit, migration
  rehearsed on a copy of the real database (schema 1 to 5 in about 1.4 s), named-service deploy only. Result:
  health 200, 48 MiB memory against a 256 MiB limit.

## Phase 2 alpha 4: `v0.2.0-alpha.4` (2026-09-26 09:12 ET, `b7d0219`)

- What shipped: the ultra-review fixes (13 cloud reviews, roughly a third of findings were real) and the list
  virtualizer fix found on the owner's phone.
- Size: 352 cumulative commits (+29); 1,656 lines added and 285 removed in 77 files.
- Decision: shorten the test day ("I aggressively test when the time comes"), deploy, merge and tag right away.

## Phase 2 release: `v0.2.0` (2026-09-26 09:27 ET, `55743ca`)

- What shipped: `phase-2` merged into `main` with a merge commit (`2059af9`), then `chore(release): 0.2.0`. Same
  content as alpha.4; the release commit changes 2 files (7 lines added).
- Size: 354 cumulative commits. Review branches and PRs #24 to #37 closed and deleted.
- Deferred to the first commits of phase 3, so the tag matches what the owner tested: reserved settings, auto-read on
  disabled feeds.

## Release prep after v0.2.0 (2026-09-26, branches not on `main` when this was written)

| Branch | Commits | Content |
|---|---:|---|
| `relprep-docker` | 2 | `kipple healthcheck` subcommand; Docker HEALTHCHECK, OCI labels, hardened compose options |
| `relprep-license` | 3 | LICENSE (PolyForm Noncommercial first, then Blue Oak Model License 1.0.0), generated third-party notices |
| `relprep-restore` | 4 | Restore rejects non-flat zip names, undo hint fixed, snapshots created 0600, deploy doc updates |
| `relprep-fuzz` | 1 | Fuzz targets for untrusted-input parsers, `fuzz.ps1` runner |

These four branches were cut from `main` after `v0.2.0` and are open work at the time of writing.

## Public release: `v0.3.0-alpha.1` (2026-09-26 11:03 ET, `7497c4c`)

- What shipped: the code repository made public with rewritten history (hostnames, addresses, names removed; the
  original kept private as `WPTK/kipple-archive`), Blue Oak Model License 1.0.0, generated third-party notices,
  `kipple healthcheck` and a Docker HEALTHCHECK, hardened compose options, native fuzz targets, restore and snapshot
  fixes, local CI. Size: 362 commits (fresh history). Deployed: not until alpha.2.

## Phase 3: `v0.3.0-alpha.2` (2026-09-26 13:34 ET, deployed about 13:35, `640fe2c`)

- What shipped: the two reserved Reader API settings (`greader.ot_includes_user_changes`,
  `greader.subscribe_fetch_now`), installable app (manifest, generated icons), a hand-written service worker (offline
  launch, cached reads, image cache), an IndexedDB queue for offline star and read changes with the server's `at`,
  unread prefetch, an offline notice, `include=content`, the `X-Kipple-API` handshake, root static files. Plus a
  phase 2 bug found in the console: fonts inlined as `data:` URIs were blocked by the page's own CSP.
- Size: 373 commits; about 4,000 lines net over alpha.1 (three feature commits and review fixes).
- Deployed with hardened compose options (read-only root, dropped capabilities) after a real read-only test in a
  scratch container; version now reported correctly via a build argument.
- Verified in real Chrome: worker registered, offline launch, offline star replayed with its timestamp.

## Review fixes: `v0.3.0-alpha.3` (2026-09-26 18:13 ET, deployed 18:57, `42fd5c8`)

- What shipped: about 65 findings from a local eight-agent deep review fixed (credentials no longer carried across
  redirect migrations, private-network exceptions scoped to a feed's own host, ClientLogin brute-force budget,
  atomic feed delete, batched trim and delete, filter preview/apply correctness, regex cost limits with visible
  disabled reasons, image proxy failure handling, offline queue races, sign-in-expired handling, ops and docs), the
  favicon finder (migration 0006), and unread/unstar in the Reader API `ot` filter (migration 0007).
- Size: 492 commits; `v0.2.0` to `v0.3.0-alpha.3`: 274 files, 19,184 lines added, 969 removed. At alpha.3 the repository
  has 615 tracked files, 75,394 lines of Go (38,830 of them in test files) and 30,461 lines under `web/src`.
- Process: 8 fixers in parallel worktrees, a second review of the merged diff (found ClientLogin locking out correct
  passwords, subdomain redirects dropping Basic auth, stored filters no longer compiling, a partial feed delete),
  a second fix round, 26 fuzz targets clean, GitHub CI with `-race` green, a migration rehearsal on a copy of the
  live database. Two migrations, so a rollback goes through the pre-migration snapshot.

## Phase 4 step 1: `v0.3.0-alpha.4` (2026-09-26 22:36 ET, tag on merge commit `56fc6ad`, PRs #17 and #18)

- What shipped: the reading statistics sender. The web app records `read_time` (active time only: tab visible and
  focused, article open, idle after 2 minutes), `scroll`, `open_original` and `share` events, each with a random
  `event_id` so a replayed batch is dropped; Settings > Statistics with `stats.enabled` and `stats.week_start`. With
  statistics off the server records nothing, including stars from sync apps. Migration 0008 (`event_id` plus a partial
  unique index).
- Size: 5 commits since alpha.3; 35 files, 2,986 lines added and 81 removed. PR #17 alone: 2,979 added, 80 removed.
- What shaped it: the phase 4 pre-meeting (see [MEETINGS.md](MEETINGS.md)) chose an event id over the first-draft
  sequence number, so migration 0008 was edited in place before it was ever deployed.
- Process: the app's permission classifier denied the agent's merge of PR #17, so the owner merged #17 and #18 himself
  (see [CHALLENGES.md](CHALLENGES.md) items 24 and 34). Fuzz clean (26 targets), off-box copy of the live database, a
  migration rehearsal on a scratch copy (0008 in about 11 ms), then a named-service deploy: healthy, 56 MiB.

## Phase 4 steps 2 and 3: `0.3.0-alpha.5` and `0.3.0-alpha.6` (2026-09-27, no tags, never deployed on their own)

- Both were built overnight (from about 23:00 ET Saturday) while the owner slept, merged in the small hours of Sunday and
  folded into alpha.7. `CHANGELOG.md` has a section for each; there is no git tag and no deploy for either. They are
  listed here because each was a separate branch, a separate review round and a separate pair of PRs.
- alpha.5 (PRs #19 and #20, merged 00:03 and 00:14 ET): the Stats screen and `GET /api/stats/summary` (totals, daily
  series, streaks, weekday-by-hour heatmap, per-source figures, feeds never opened), a free-disk-space check before any
  schema migration, and migration 0009 (three covering indexes). PR #19: 31 files, 3,345 lines added, 18 removed. Two
  Sonnet build agents, three Opus reviewers (about 25 findings) and a second round (about 12 more), all fixed. Checked
  at phone size against a seeded local instance: the heatmap and sources table needed sideways scrolling on a phone.
- alpha.6 (PRs #21 and #22, merged 01:33 and 01:44 ET): statistics export (CSV, JSON, JSON Lines; raw events or a
  summary; formula-injection prefixing for spreadsheet cells; `X-Kipple-Rows` so a cut-off file is detectable), a data
  dictionary endpoint, delete a range or everything (typed confirmation, dry run, bounded batches). No migration. PR
  #21: 27 files, 2,999 lines added, 64 removed.
- Between them, five Dependabot GitHub Actions bumps (PRs #2 to #6) were merged (00:40 to 01:22 ET), then a Dependabot
  config tidy (PR #24).

## Phase 4 step 4: `v0.3.0-alpha.7` (2026-09-27 08:55 ET, `00510e3`, PRs #23 and #25)

- What shipped: Wrapped, a yearly summary at `/stats/wrapped` (year picker, seven cards, an opt-in share sheet) and the
  `stats.wrapped_enabled` setting. It is also the first build deployed after alpha.4: it carries alpha.5 and alpha.6, so
  the upgrade ran migration 0009. Phase 4 was complete.
- Size: 32 commits and 7,981 lines added, 42 removed in 62 files since alpha.4 (all of alpha.5 to alpha.7); 10,960 added, 116 removed in 83 files since alpha.3. PR #23 alone: 16 files, 1,639 lines added.
- Deployed to Host-A on Sunday morning (live by about 09:30 ET): off-box copy, migration rehearsal, named-service
  deploy, healthy at 41.6 MiB, GitHub pre-release published. kipple.cc and this repository were made public that
  morning (this repository was later found to contain real hostnames; see [CHALLENGES.md](CHALLENGES.md) item 26).

## Phase 5: release readiness (2026-09-27 daytime, merged between `00510e3` and `12121c7`, no tag of its own)

- What shipped, by PR: #26 the full code audit (scoping, scheduler starvation, stats and web fixes, changelog review;
  53 files, 1,086 lines added); #40 optional Cloudflare Access token validation and an optional web password (27
  files, 2,258 lines added); #41 the scheduled auto-night theme (20 files, 1,106 lines added); #42 the documentation
  run (14 files, 275 lines added, 152 removed); #45 UAT Suite 2 findings; #46 UAT Suite 1, a Playwright plus axe-core
  walk of every screen (`npm run uat`, 1,151 lines added); #51 the CodeQL follow-up to #46.
- What shaped it: the phase 5 planning meeting (MEETINGS item 28) set a UAT plan, an IEEE 730-shaped SQA plan,
  promotion criteria for alpha to beta to rc to 1.0, a risk register and an audit-first order, with Kipple-only scope and
  minimal owner involvement. UAT Suite 4 (a restore drill onto a throwaway volume and a migration rehearsal) passed;
  Suite 3 (real-device checks) is not a promotion gate. See [audits/](audits/) and [human-feedback/](human-feedback/).
- Process: agents ran in parallel in worktrees, one PR each, with auto-fix monitoring on every PR; reviewers were Opus.

## Beta 1: `v0.3.0-beta.1` (2026-09-27 21:35 ET, `12121c7`, PRs #53 and #54)

- What shipped: the Phase 5 content above, plus the fixes from a pre-tag `/code-review high` of the whole alpha.7 to
  main diff (six confirmed bugs, one a real SSRF-guard escape; PR #54, 33 files, 1,313 lines added), a batch of race
  regression tests and UAT accessibility fixes (PR #53), and a README Quickstart. No schema migration (still 9). From
  here `-beta.N` and `-rc.N` builds change only fixes, not features.
- Size: 70 commits, 8,241 lines added and 532 removed in 148 files since alpha.7; 202 files, 19,173 lines added and 620
  removed since alpha.3. 26 fuzz targets clean.
- Deploy prep was interrupted by a Cloudflare tunnel incident (CHALLENGES item 29); the build then went to Host-A (the
  exact deploy time is not recorded in the sources used here). Issue #52 (Unread dominated by one feed, others stale)
  was closed after the deploy: the scheduler starvation fix from PR #26 was in `main` but not yet on Host-A when the
  owner first saw it.

## Beta 1 feedback round (2026-09-27 evening to 2026-09-29 morning, no tag)

- Source: the owner's own phone-testing notes on beta.1 (ten items), triaged into issues #55 to #62 and shipped as PRs
  #63 to #70. See [diary/2026-09-28.md](diary/2026-09-28.md).
- What shipped: the "N new articles" pill only after a manual refresh (#63), a softer mobile tab-bar seam (#64), mobile
  folder collapse and an edit-mode toggle in Manage Feeds (#65), Feed Health bulk actions and a "Manage this feed" entry
  in the article menu (#66), a two-pane Settings in six groups (#70), Cards and Compact list layouts made more
  distinct (#68), two README rewrites (#67, #69).
- What shaped it: overnight mockups (three settings structures, layout redesigns), approved at the 2026-09-28 morning
  meeting; the owner rejected the first README revamp and asked for it to be redone plainly.
- Size: the merge commits for #63 to #70 add about 1,400 lines in total (a rough figure: merge-commit diffs against the
  first parent). Issues #71 (blurry thumbnails) and #72 (stale scroll position marking new rows read) were filed from the
  soak; #73 fixed the imgproxy CI hang (CHALLENGES item 27), #74 and #75 fixed #72 and #71.

## Beta 2 (in progress, 2026-09-29): release PR #88, not yet tagged

- What is in it: ten fixes from a `/code-review high` of everything since beta.1 (#76, #77, #79, #82, #83, #84 and the
  interval label #81); the offline "Read the original" bug the owner reported (#78, PR #80); the favorited-folder
  collapse bug (#86, PR #87); and the changelog fragment tooling (PR #85: one file per PR in `changes/`, folded into
  `CHANGELOG.md` by `scripts/changelog.mjs` at release time). See CHALLENGES items 30 to 35.
- Size so far: 46 commits, 2,605 lines added and 432 removed in 84 files since beta.1 (release PR #88 itself: 20 files,
  34 added, 20 removed). Fuzz clean, UAT Suite 1 clean, review clean; waiting on CI for the release commit at the time of
  writing. #88 merged 14:01 ET and #89 (the daily-history rule) 14:08. Tagged 15:21 on `0fa8450`, deployed to Host-A 15:22 and released on GitHub 15:24 (see diary/2026-09-29.md).

## v0.3.0-beta.3 (2026-09-29, evening)

- Fixes only, from the beta.2 UAT re-run (Suites 1, 2, 4, 5): 13 commits, 48 files, 992 lines added and 111 removed since
  beta.2. Backup dialog date, OPML import announcement, list gaps and position on return, offline article screen,
  Feed Health select mode, Manage this feed in the reader menu, list header width, empty-state copy, the wide-row sideways
  scroll, and the archive feed hidden everywhere. Tagged 18:43 on `46da6a6`, deployed 18:44, no schema migration.
  Soak clock kept from beta.2 (earliest rc.1 2026-10-06).
- The owner decided beta.2 is next, not rc.1: the changes since beta.1 are feature-sized, and per `docs/RELEASING.md` an
  rc needs Suites 1, 2 and 4 re-verified plus a soak week.

## Setup wizard stack on `main` (2026-09-29, evening, no tag)

- Merged 21:40 to 22:33 ET with green CI on each exact head: design #91, test fix #117, release workflow #111, build info
  and About screen #114, docs #121, wizard UI #119 and backend #118 (the whole stack, combined commit `c4161c3`, CI green
  including `-race`), then the stats read-definition fix #122. `main` at `14960f2`, no open PRs. Not tagged and not
  deployed; target is `0.5.0-beta.1` (milestone 7), and it restarts the soak.
- Size: #118 as merged is 117 files, 9,653 lines added and 436 removed (it carries #119 and the others' base work through
  the stacked branches; the per-PR figures are 47 files and 4,232 added for #119 as merged into its base, 11 files and 621
  added for #121, 11 files and 514 added for #122).
- What it contains: first-run wizard (account with optional password, theme, time zone, OPML import, starter feeds,
  "Run setup again" in Settings), open mode (no password, refuses other LAN devices unless `security.open_lan`), migration
  0010, a time zone resolver (new installs default to UTC), default port 1919 with existing databases keeping 7080
  through 0.x, a release workflow that publishes a signed multi-arch image to GHCR, build info (OCI labels,
  `kipple version -v`, About screen with copy-debug-info, stale-PWA banner, downgrade guard, what's-new after an
  upgrade), and the new read definition for stats. No update check, by decision.
- The overnight audit found further defects in it (audits/overnight-2026-09-30.md); fixes were pending at the time of
  writing.

## v0.5.0-beta.1 (2026-09-30, 12:21 ET, `2a2e261`, release commit #155)

- Contents: the setup wizard stack (see the section above) plus the review fixes and the real starter list. Merged
  between the stack and the tag: #137 (release workflow), #150 (backend and security), #151 (wizard frontend), #152 (the
  real recommended feeds, pinned by a test, with a liveness script), #153 (reading-font choice back in Settings, Search
  and the wizard), #158 (setup code always checked from a locked address; favicon candidates that do not re-parse are
  dropped) and #155 (the release commit).
- Pre-tag verification: 28 of 29 fuzz targets clean; the 29th (`FuzzIconLinks`) and a review found two bugs, #156 and
  #157, both fixed in #158 before the tag.
- First real run of the Release workflow: green (gate, CI, build amd64 and arm64, Trivy scans, smoke tests on both,
  publish, cosign signing and provenance), 16 minutes. Image `ghcr.io/wptk/kipple:0.5.0-beta.1`, digest
  `sha256:9dc95af346053eb0f1515fd29684676b6c2d6eb0788e83990317e071ea2da18b`. GitHub pre-release published 12:38:
  https://github.com/WPTK/Kipple/releases/tag/v0.5.0-beta.1
- Deployed to Host-A about 12:44, built from the tag on Host-A: `v0.5.0-beta.1`, commit `2a2e261`, schema 10, migration
  0010 applied, healthy, existing account signs in with no wizard, still on port 7080 with the expected legacy-port
  warning.
- Soak for rc.1 restarts at this deploy: rc.1 not before 2026-10-07.
- Not yet: the GHCR package is private until the owner makes it public by hand, so anonymous pulls fail; the repository
  ruleset restricting who can create `v*` tags is still owed by him.

## Size of the repository at beta.2 prep

At the beta.2 release branch: 645 commits (492 at alpha.3), 712 tracked files, about 83,800 lines of Go (about 43,200 of
them in test files) and about 40,000 lines under `web/src`.

## Not built yet

The setup wizard and pull-and-run image (#33) is now milestone 7 and on `main`, unreleased. Still post-1.0: user-chosen Google Fonts (#34), design system, demo site and brand
identity (#35), reading stats for Reader API clients (#36), further Stats screen views (#37), filters follow-ups (#38),
more reading layouts (#39): all labelled Roadmap. Before 1.0: a beta soak week with zero incidents, `-rc.1`
(Suites 1, 2 and 4 re-verified), Suite 3 on real devices, and the final go/no-go meeting. See
[plans/HANDOFF-PHASE4.md](plans/HANDOFF-PHASE4.md) and [parking-lot.md](parking-lot.md).


## Since `v0.5.0-beta.1`: unreleased on `main` (2026-09-30 to 2026-10-01)

- `main` is at `aec4961`, past the beta.1 release commit. Changes: #159 (docs), #160 and #161 (badges, Scorecard workflow,
  Codecov upload), #162 (`CONTRIBUTING.md`), #163 (solid cover for the iOS status-bar strip; the only behaviour change,
  with a changelog fragment) and #164 (the Best Practices badge).
- Repository protection: tag ruleset "Protect Release Tags" and branch ruleset "Protect main" in force (DECISIONS.md).
- OpenSSF Best Practices passing badge earned 2026-10-01 (project 15120). Scorecard was 7.1, then 7.3 on the owner's
  reading; Branch-Protection scores 3 of 10 and cannot go higher without a second reviewer.
- The GHCR package is public (anonymous manifest fetch returns 200 on 10-01).
- Not tagged. The #163 fix would go into beta.2.
