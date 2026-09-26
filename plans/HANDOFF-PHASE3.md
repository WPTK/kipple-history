# Handoff: phase 2 close-out and phase 3

Written 2026-09-26 at the end of the phase 2 session. Read this, `CLAUDE.md`, and the memory index
(`C:\Users\user\.claude\projects\C--kipple\memory\MEMORY.md`) before doing anything.

## State (updated 2026-09-26, after the merge)

- **Phase 2 is closed.** `phase-2` was merged into `main` with a merge commit (`2059af9`) and tagged `v0.2.0`
  (`55743ca`, the release commit: CHANGELOG moved, CLAUDE.md wording). Host-A runs `v0.2.0-alpha.4`
  (`b7d0219`), which has the same code as `v0.2.0`; the only difference is docs and the CHANGELOG, so no
  redeploy is needed for the tag.
- All 13 phase 2 ultra reviews were read and every real finding fixed (see `docs/diary/2026-09-26.md`). The
  14 review-only PRs (#24 to #37) are closed and their branches deleted. Remote branches: `main`, `phase-2`
  (kept until the owner says to delete it). Start phase 3 on a new branch off `main`.
- Off-box copies of the Host-A database before each deploy: `P:\HostBBackups\kipple\`. The alpha.4 copy is
  `kipple-20260926-092622.db`. Debug logging (`KIPPLE_LOG_LEVEL`, `KIPPLE_LOG_GREADER_FORMS` in
  `/home/user/stack/.env`) is still on; turn it off after the owner's testing.
- the owner will test alpha.4 hard on his own; a fix found there ships as a new tag (alpha.5, or 0.2.1 if final).
- GitHub Actions minutes are running low. CI now cancels superseded runs on the same ref. Push sparingly and
  batch commits.

## Decided, not yet built (do these first in phase 3)

- **Reserved settings:** build `greader.ot_includes_user_changes` and `greader.subscribe_fetch_now` (stored and
  validated, read by nothing today). `stats.api_single_read_is_open` waits for phase 4 stats.
- **Auto-read and disabled feeds:** best practice, the owner delegated it: include disabled feeds (they can never
  clear themselves), leave archived feeds alone. Check the current behavior in `internal/store/autoread.go`
  first, and add a test.
- **Refresh-all:** no exception. The Reader API has no such call and CLAUDE.md now says clients never trigger
  fetches.
- **Follow-up meeting** planned with the owner after this close-out.

## Rules that bite

- Fix every review finding (memory `feedback-fix-review-findings`).
- Commits: small, conventional, `Co-Authored-By: Claude Sonnet 5 <noreply@anthropic.com>`. CI must be
  green on every push. No `gh` CLI: use the GitHub REST API with the token from `git credential fill`.
- CRLF working copies hide gofmt failures; verify from an LF worktree. Shared npm cache gives EPERM: pass
  `--cache <dir>`. Node is not on git-bash PATH (use PowerShell). No `-race` locally (no gcc).
- The permission classifier denies pushing to shared branches from agents; use a branch plus PR.
- Never Haiku. Named compose services only. Stop and get the owner's go-ahead before Host-A deploys.

## Phase 3 scope

PWA manifest, service worker, offline reading plus queued actions and an "offline" notice, root static
files, `include=content`, `X-Kipple-API` handshake, star `at`, `sw.js` headers.

Backlog: favicon finder; decide whether the reserved settings get built; `client.*` keys; auto-read on
disabled feeds (the owner's call); lossless WebP thumbnailing.
Parking lot (do not raise until the end): Cloudflare Access JWT, passwordless login, design system,
demo site, pull-and-run image, scheduled auto-night.

## Awaiting the owner

- Approve or reject `docs/audits/claude-md-proposed-edits.md`.
- Decide auto-read on disabled feeds and the reserved settings.
- Go-ahead to run the ultra reviews.
