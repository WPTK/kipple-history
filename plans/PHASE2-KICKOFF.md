# Phase 2 kickoff prompt (reading UI)

Paste everything below the line into a fresh Claude Code session in `C:\kipple`
(Sonnet at medium effort; Opus only where noted).

---

Start Kipple phase 2 (the reading UI). Phase 1 is merged to `main`, deployed on Host-A, and in daily
use: client A and client B sync through `https://rss.example.com/api/greader.php`. Work on a
new branch `phase-2` cut from `main`.

**Read first:** CLAUDE.md; docs/plan.md ("Phase 2", "Deployment and cutover", "Model and effort for
execution"); your memory notes (kipple-project-state, subagent-model-and-effort, host-b-dev-gotchas,
host-b-gh-cli-missing). docs/design.md is the source of truth: read it by section with Grep/offset,
never whole. Phase 2 uses §7 (UI API), §5 (restore), §7.4 image proxy, §7.5 full-text, §8 (only the
stats recorder hooks), and §6.9 for feed add/unsubscribe semantics.

**Step 0, before any code: ask the owner for his day-of-use feedback.** Do not start until he has answered.
Ask for: anything broken or annoying in client A or client B; whether read/star changes propagate
between the two apps; and whether the retention and OPML round-trip checks passed (lower a feed's cap
and confirm a starred old item survives; export OPML and re-import). Then read the Host-A request log
(debug level) if the owner turned it on, to settle the open client A questions in
docs/research/open-questions.md (the `mark-all-as-read` `ts` unit above all). Update the design or
plan if the answers change anything.

**Scope (plan.md "Phase 2"):** Vite + React 19 + TypeScript + Tailwind v4 + shadcn + TanStack
Query/Virtual, replacing the scaffold in `web/`. Compact list and Feedly-style magazine/cards with
lead images, article view with full-text toggle and image proxy, search (FTS5), keyboard shortcuts
(j/k/s/o/r/m), swipe actions, pull-to-refresh, feed health view, settings (poll interval, retention,
per-feed overrides), add/edit/delete feeds and folders. Themes, fonts and the PWA are phase 3; stats
UI is phase 4. Do not start those.

**Backend work phase 2 needs** (the UI API in §7.1 is mostly unbuilt; phase 1 shipped login, status,
health, refresh, events and OPML only): bootstrap, items list and detail with keyset cursors, open,
star, mark-read, fulltext (go-readabilityV2, guarded client), feed icon, image proxy, feeds and
folders CRUD, per-feed refresh, settings GET/PATCH, account/password endpoints, fetch-log endpoint,
`POST /api/stats/events` (accept and record the phase-1 kinds only). Build it in small steps, each with
tests, before or alongside the UI it serves.

**Known items carried over from phase 1 (fix or schedule them, do not forget them):**
- `web/dist` is still the scaffold; `/` redirects to `/_status` via `placeholderApp = true` in
  `internal/web/handler.go`. Flip it and delete or fold in `internal/web/status.html` when the real UI
  ships. The SPA handler only serves `/assets/`; add real static-file handling before phase 3 needs
  root files (manifest, service worker).
- No feed-URL editing exists. 10 feeds sit behind temporary (302/307) redirects and NPR (timeout) and
  the FAA (HTTP 403) are failing. `PATCH /api/feeds/{id}` should let the owner change a feed's URL; the
  feed editor in phase 2 covers it.
- Settings validation: `retention.restore_days` is clamped to 0-180 on read (the nightly purge drops
  ledger rows at 180 days); the settings PATCH must enforce the same range.
- The stats recorder does not exist, so the Reader API's edit-tag writes no `star`/`unstar` rows
  (design §8). Build the recorder with the UI API; web opens are the only read signal (read inference
  stays off unless the request log shows a clean signal).
- `feed.changed` (URL migration, disabled on 410) and `counts` SSE events are specified but never
  published; the status page already subscribes to `counts`.
- A per-feed refresh request for a feed already in flight loses its `full`/trim/rekey intent
  (latent, `internal/sched/dispatcher.go`, see the comment); fix it when `POST /api/feeds/{id}/refresh`
  lands.
- A failed commit backs off from the snapshot's failure count, which never grows (in-memory
  `notBefore`); low priority.
- Label lookup for folders named `a b` and `a+b` can collide in the Reader API; low priority.
- SQLite page caches total about 32 MB outside the Go heap (design accepts it); recheck idle RSS on
  Host-A (`docker stats kipple`) after a day and after the UI is in.

**Process and rules (from CLAUDE.md and memory):**
- Implement each step yourself or with a subagent (`model: sonnet`, `effort: medium`); use `opus` +
  `high` for reviews and judging. Always pass `model` and `effort` explicitly. Never Haiku, never `max`,
  no workflows or multi-agent fan-outs unless the owner asks.
- Small conventional commits, push `phase-2` after each step, check CI on every push via the GitHub
  REST API with the token from `git credential fill` (no `gh` on Host-B; see memory). The race detector
  does not run on Host-B; CI runs it.
- After every two or three backend steps and again before the deploy: one Opus/high review subagent on
  that diff; fix what it confirms. `/code-review high` before every deploy.
- Frontend: `npm install --cache <scratchpad dir>` (shared npm cache throws EPERM). Verify the iPhone
  layout in the browser pane at the mobile preset (375x812) before calling a UI step done; use
  `127.0.0.1`, never `localhost`.
- Deploy is the same path as phase 1: `deploy-local/RUNBOOK.md` (gitignored, on Host-B) and the
  Host-A commands in CLAUDE.md; named service only (`docker compose ... kipple`), never a bare `up`;
  back up the compose file first; one writer on Host-A at a time. I cannot make Cloudflare changes;
  the owner does those.
- Stop and check with the owner before the first Host-A deploy of phase 2, if a step's gate cannot pass, or
  if a design decision turns out to be wrong.
