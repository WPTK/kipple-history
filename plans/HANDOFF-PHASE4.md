# Handoff: phase 4, the stats UI (local, private notes; git-ignored, copy kept in WPTK/kipple-history)

Written 2026-09-26 evening, after `v0.3.0-alpha.3` shipped. Read this, `CLAUDE.md`, and the memory index
(`C:\Users\user\.claude\projects\C--kipple\memory\MEMORY.md`) before doing anything.

## State

- `main` is at `v0.3.0-alpha.3` (tag, GitHub Release, deployed to Host-A 2026-09-26 18:57 ET, healthy, schema 7).
  Host-A runs it from `/home/user/stack` compose (hardened options, `KIPPLE_VERSION` build arg); its `/home/user/kipple`
  checkout is on `main` after deploys (deploy = `git checkout <tag>`, build, then `git checkout main`).
- GitHub Actions is the CI of record (it runs `go test -race`, which the dev box cannot: CGO is off, no gcc; two
  test-only races reached CI that way). `scripts/ci-local.ps1` is the fast pre-push check. Every PR: branch, PR, CI
  green, merge. The permission classifier denies pushing to shared branches from agents.
- Schema: 7 migrations (0006 feed icon checks, 0007 `items.state_changed_at`). Older binaries refuse a newer schema:
  a rollback across a migration goes through the pre-migration snapshot (`docs/deploy.md`).
- Debug logging (`KIPPLE_LOG_LEVEL`, `KIPPLE_LOG_GREADER_FORMS` in `/home/user/stack/.env`) is still on; turn it off
  when the owner says testing is done.
- Off-box database copies before each deploy go to `P:\ServerBackups\kipple\pre-<release>-<stamp>\` on Host-B
  (this machine): live `kipple.db` + `-wal` + `-shm` (via a busybox container reading the volume) and the nightly snapshot.

## Phase 4 scope (stats UI)

From `docs/plan.md`: views from the `stats_events` table: most-read sources, hour/weekday heatmap, time per source,
never-opened feeds, streaks; CSV export. Exit: a week of real reading shown.

What exists (design section 8, `internal/stats`, `internal/store/stats.go`, `internal/api/items.go`):
- Table `stats_events` (append-only, never trimmed, no FKs; feed title, folder, item title and URL snapshotted;
  `local_date/hour/weekday` computed at write time in the `tz` setting). Kinds: `open`, `read_time`, `scroll`, `star`,
  `unstar`, `open_original`, `share`. There is deliberately no `read` kind: bulk marks and mark-read-on-scroll are not reads.
- Written today: `open` (web open), `star`/`unstar` (web and Reader API). Server-side ingest and validation of
  `read_time`, `scroll`, `open_original`, `share` via `POST /api/stats/events` is done (session_key of an open within 12 h,
  cumulative `read_time` cap, one `scroll` per session, 64 KiB / 200 events per body; the body carries `client`
  `web|pwa`, because a `sendBeacon` flush cannot send `X-Kipple-Client`).
- **Not built (this is phase 4):**
  1. The web sender: nothing in `web/src` sends `read_time`, `scroll`, `open_original` or `share` yet. Contract
     (design section 8 rule 5): active reading time = tab visible AND focused AND the article route is active; pauses on
     `visibilitychange`, `blur`, route change; flush every 15 s and on `pagehide`/route change via `sendBeacon`; list
     scrolling never counts. Put `client: clientKind()` in the body. Offline: events for a later flush must not break the
     offline queue rules (see `web/src/lib/offline.ts`).
  2. `GET /api/stats/summary` and `GET /api/stats/export.csv` (the same-origin guard already covers the CSV path;
     design section 7 has the shapes: RFC 4180, keyset paging, `?from=&to=`, `include_inferred`).
  3. The stats screen(s) and navigation entry; heatmap, time per source, never-opened feeds, streaks, most-read sources.
  4. `stats.api_single_read_is_open` is reserved and read by nothing. It stays off unless the owner decides otherwise
     after looking at real Reeder traffic; do not build API read inference without asking.

Standing decisions that apply (CLAUDE.md, do not relitigate): stats events are never trimmed (kept forever, apart
from the id ledger); bulk mark-as-read and mark-read-on-scroll are not reads; no monitoring/notifications/social
features (non-goals). Per-device appearance profiles are not multi-user.

## Process for this phase

- Phases: the owner uses each phase for a day before the next starts. UI meeting first (like round 1 and 2): the
  stats screens are a product decision, so propose layouts and ask before building the frontend (see
  `docs/ui-decisions.md` for how earlier rounds were run). Verify iOS layout in the browser pane at the mobile
  preset before calling a UI phase done; the pane cannot run service workers, use Claude in Chrome (installed) for
  anything that needs one.
- Reviews: the billed `/code-review ultra` is retired (the owner has no credits). Use `/code-review high` on the
  diff before every deploy, plus the local multi-agent review pattern in `C:\kipple-history\audits\local-review-2026-09-26.md`
  (read-only Opus finders per area, then fix agents with disjoint file ownership, then a second review of the MERGED
  diff, because fixers introduce regressions). Fix every finding, minor ones included (owner's rule).
- Models: never Haiku. Sonnet for routine code, Opus as advisor/reviewer and for anything touching live services.
  Pass `model` and effort explicitly to subagents.
- Deploys: ask first, every time. Tag the exact commit; deploy only the named `kipple` service; off-box DB copy first;
  rehearse migrations on a copy of the live database in a scratch container (worked well for alpha.3); verify health,
  logs, memory. The ssh alias is `host-a` (committed docs say Host-A / `host-a`).
- Never put the owner's real name, surname or personal email anywhere; hostnames, addresses and paths stay generic in
  anything committed. Commit trailer: `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`.
- Diaries, meeting notes, timeline and milestones go to the private `WPTK/kipple-history` (local clone
  `C:\kipple-history`), updated at each milestone.
- Environment gotchas: Node is not on git-bash PATH (use the PowerShell tool for npm/node); long foreground `sleep` is
  blocked (poll GitHub with short loops or run in the background); bash heredocs containing apostrophes can fail in
  this tool (write a script file with the Write tool, then run it); CRLF working copies hide gofmt failures (check an
  LF copy); use the GitHub REST API with the token from `git credential fill` (no `gh` CLI); `-race` cannot run locally.

## Still with the owner (do not do these for him)

- Turn on GitHub private vulnerability reporting (repo Settings > Code security); `SECURITY.md` already points to it.
- Approve or reject `docs/audits/claude-md-proposed-edits.md` (copy in `kipple-history/audits`).
- Say when to turn off the debug logging flags on Host-A.
- The Host-A-side backup job that pushes Kipple's data to Proton Drive (outside this repo; Host-B's nightly jobs already
  pull Kipple's snapshot, compose file and `.env` into `P:\ServerBackups\Kipple` and the Proton archive).
- Cloudflare changes (he does them).
- Decide whether/when to run the release steps 8 onward: full audit (done as the local review), changelog review,
  documentation run, first-time Docker setup walkthrough, how to retain and back up settings and Kipple, final go/no-go
  meeting; plus the pre-public meeting items already done (repo is public).
- Parking lot, do not raise until the end: Cloudflare Access JWT validation, passwordless login, design system, demo
  site, pull-and-run image, scheduled auto-night, user-chosen Google Fonts (2.0.0).
