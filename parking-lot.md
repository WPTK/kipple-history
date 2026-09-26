# Kipple parking lot

Ideas, follow-ups and decisions that are deliberately not being worked on yet. Updated 2026-09-26. The canonical copy
lives in the private `WPTK/kipple-history` repository (`parking-lot.md`); this local copy is git-ignored in the public
repo. Nothing here starts without the owner asking. The phase plan itself is in `docs/HANDOFF-PHASE3.md`.

## Follow-ups queued (concrete, owner-approved)

| # | Item | Notes |
|---|---|---|
| 1 | Deploy `v0.3.0-alpha.1` to the app host (Host-A) | Needs the owner's go-ahead. Before it: `git fetch --tags --force` on Host-A (old tags moved), apply the hardened compose diff in `docs/deploy.md`, test the read-only root filesystem with real image-cache writes and thumbnails, pass a `VERSION` build arg (`kipple version` says `dev`). |
| 2 | Turn off debug logging on Host-A | `KIPPLE_LOG_LEVEL` and `KIPPLE_LOG_GREADER_FORMS` in `/home/user/stack/.env`, after the owner's testing. |
| 3 | Reserved settings | Build `greader.ot_includes_user_changes` and `greader.subscribe_fetch_now`. `stats.api_single_read_is_open` waits for phase 4 stats. |
| 4 | Auto-read and disabled feeds | Best practice, delegated by the owner: include disabled feeds (they can never clear themselves), leave archived feeds alone. Check `internal/store/autoread.go` first; add a test. |
| 5 | GitHub Releases | None exist. Create them from the tags with the CHANGELOG section as notes (`docs/RELEASING.md`). |
| 6 | Host-A backup job of its own | The owner will build one that pushes to Proton Drive. Meanwhile Host-B's nightly jobs pull Kipple's snapshot, `docker-compose.yml` and `.env` to `<backup-dir>\Kipple` (14 dated copies, up to about 24 h behind) and into the Proton archive. |
| 7 | Public-repo housekeeping | Confirm Actions runs green on the public repo, review the first Dependabot PRs, run `scripts/fuzz.ps1` before each release. |
| 8 | Diary and meeting notes | Keep adding to `diary/` in `kipple-history` at each milestone: decisions, incidents, deploys, review results, model and usage notes. |
| 9 | Release steps 8+ (from CLAUDE.md Process) | Full audit and review, changelog review, documentation run, first-time Docker setup walkthrough, how to retain and back up settings and Kipple, final go/no-go meeting. |

## Deferred ideas (do not raise until the planned phases are done)

- **Cloudflare Access JWT validation**: `Cf-Access-Jwt-Assertion`, env `KIPPLE_ACCESS_TEAM_DOMAIN` and
  `KIPPLE_ACCESS_AUD`, verify RS256 against the team's certs URL, check iss/aud/exp, show the email in `/api/auth/me`.
  Nothing has changed in Cloudflare yet.
- **Passwordless or optional-password login**: only after the JWT check (the port is LAN-published). The API password
  stays on demand, with a generate-and-copy button.
- **Setup app and single pull-and-run image** (1.5.0 or 2.0.0): custom domain, optional Cloudflare OTP, a generated API
  password for Reeder and similar apps; first-time setup when using Docker.
- **User-chosen Google Fonts** (2.0.0, only if cheap).
- **Design system, static demo site, Kipple identity and accent color** (Kipple stays single-user).
- **Scheduled auto-night theme.**
- **Favicon finder and Access-JWT-related bits** noted in the design as not built.
- **Lossless WebP thumbnailing** limits and other image-pipeline follow-ups (see the thumbnail memory model notes).
- **Reader "refresh all"**: decided, no exception. The Reader API has no such call; clients never trigger fetches.
- **Host-A/Host-A accessibility testing beyond automated checks**: not doing (owner's decision). A scale test: not doing
  (Host-A already runs the real feeds).

## Rules and preferences the owner has set (standing)

- Never use the owner's real name, surname or personal email anywhere (license, notices, docs, commits, examples).
  Use "the owner"; committer name `WPTK`. Keep hostnames, addresses and paths generic in anything public.
- Open-source-style license: Blue Oak Model License 1.0.0 (decided). The owner was told real open-source licenses
  cannot forbid commercial use.
- Fix every review finding; no "won't fix" lists.
- Never Haiku. Ask before any Host-A/Host-A deploy. One writer at a time on the server.
- Multi-user is withdrawn, not parked. Per-device profiles are not multi-user.
- GitHub Actions: was out of minutes before the repo went public; `scripts/ci-local.ps1` remains the pre-push check.
- Public repo goes through independent hostile review before any history rewrite or release that could leak details.
