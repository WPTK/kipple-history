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

## Not built yet

Phase 3 (PWA: manifest, service worker, install, offline) and phase 4 (stats), then release steps 8 onward per the Kipple `CLAUDE.md` Process section; the first phase 3 tasks are in the handoff, the setup app and single pull-and-run image (roadmap 1.5.0 or 2.0.0),
user-chosen Google Fonts (2.0.0), Cloudflare Access JWT validation, passwordless login. See
[plans/HANDOFF-PHASE3.md](plans/HANDOFF-PHASE3.md) and the parking lot in [DECISIONS.md](DECISIONS.md).
