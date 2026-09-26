> STATUS 2026-09-26 evening: everything below is DONE and released (v0.3.0-alpha.2 and alpha.3, deployed). Superseded by
> docs/HANDOFF-PHASE4.md. Kept for history.

# Handoff: phase 3 (local, private notes; git-ignored, copy kept in WPTK/kipple-history)

Written 2026-09-26 at the end of the phase 2 session. Read this, `CLAUDE.md`, and the memory index
(`C:\Users\user\.claude\projects\C--kipple\memory\MEMORY.md`) before doing anything.

## State (updated 2026-09-26, after going public)

- The repository is public at `WPTK/Kipple`. Its history was rewritten to remove personal and deployment details
  (hostnames, addresses, names, the diary, research and kickoff documents, which live in the private
  `WPTK/kipple-history`). All commit hashes changed; tags `v0.1.0` to `v0.2.0` and `v0.2.0-alpha.1` to `-alpha.4`
  were recreated on the rewritten commits. The unrewritten original is the private `WPTK/kipple-archive`
  (read-only reference, never push there).
- Latest tag: `v0.3.0-alpha.1`. Host-A runs `v0.2.0-alpha.4` until the owner approves the deploy of `v0.3.0-alpha.1`.
  Deploying it needs `git fetch --tags --force` on Host-A (the old tags point at different commits), the hardened
  compose diff in `docs/deploy.md`, and a real read-only-filesystem test with thumbnails first.
- Off-box copies of the Host-A database before each deploy go to `P:\ServerBackups\kipple\` on Host-B.
  Debug logging (`KIPPLE_LOG_LEVEL`, `KIPPLE_LOG_GREADER_FORMS` in `/home/user/stack/.env`) is still on; turn it off
  after the owner's testing.
- GitHub Actions is free again now that the repository is public. Keep `scripts/ci-local.ps1` for a fast local
  check before pushing.
- Never put the owner's real name, surname or personal email anywhere. Start phase 3 on a new branch off `main`.

## Decided, not yet built (do these first in phase 3)

- **Reserved settings:** build `greader.ot_includes_user_changes` and `greader.subscribe_fetch_now` (stored and
  validated, read by nothing today). `stats.api_single_read_is_open` waits for phase 4 stats.
- **Auto-read and disabled feeds:** best practice, the owner delegated it: include disabled feeds (they can never
  clear themselves), leave archived feeds alone. Check the current behavior in `internal/store/autoread.go`
  first, and add a test.
- **Refresh-all:** no exception. The Reader API has no such call and CLAUDE.md now says clients never trigger
  fetches.
- **Follow-up meeting** planned with the owner after this close-out.

## Release readiness backlog (added 2026-09-26)

Done and public (`v0.3.0-alpha.1`): Blue Oak Model License 1.0.0 (`LICENSE`), generated
`THIRD_PARTY_NOTICES.md` (`scripts/gen-notices.mjs`, shipped in the image under `/licenses/`), `kipple
healthcheck` plus a `HEALTHCHECK` and hardened compose options, native fuzz targets (`scripts/fuzz.ps1`),
`docs/RELEASING.md`, three restore/snapshot fixes from a real restore and rollback rehearsal, `scripts/ci-local.ps1`,
and the public repository itself (scrubbed history).

Still to do, in rough order:

1. **Deploy `v0.3.0-alpha.1` to Host-A** once the owner approves. At that deploy: apply the hardened compose diff
   in `docs/deploy.md`, test the read-only root filesystem with real image-cache writes and thumbnails first (only
   code inspection covers that today), and pass a `VERSION` build arg so `kipple version` and backup manifests stop
   saying `dev`. Version plan: `0.3.0-alpha.1`, then `0.3.1` and later for follow-ups.
2. **Host-A backup of its own.** Host-B's nightly jobs now pull Kipple's newest snapshot, `docker-compose.yml` and
   `.env` from Host-A to `P:\ServerBackups\Kipple` (14 dated copies) and into the Proton archive (up to about 24 h
   behind: Kipple writes its snapshot around 04:10 Eastern). The owner wants a Host-A-side job that pushes to Proton
   Drive too; that is outside this repo.
3. **GitHub Releases.** None exist yet. Create them from the tags, with the CHANGELOG section as the notes
   (`docs/RELEASING.md`).
4. **Public-repo housekeeping:** confirm Actions runs on the public repository, turn on secret scanning and
   Dependabot alerts, and run `scripts/fuzz.ps1` before each release.
5. **Not doing (the owner's decisions):** accessibility testing beyond the automated checks; a scale test (Host-A
   already runs the real feeds). Diaries and meeting notes live in the private `WPTK/kipple-history`; add to them at
   each milestone.

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
