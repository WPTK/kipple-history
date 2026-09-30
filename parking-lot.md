# Kipple parking lot

Ideas, follow-ups and decisions that are deliberately not being worked on yet. Updated 2026-09-29 (reconciled against
the Kipple repo's git-ignored `docs/parking-lot.md`, the agent's parking-lot memory note and the GitHub issue list). The
canonical copy lives in the `WPTK/kipple-history` repository (`parking-lot.md`); the Kipple working copy is git-ignored
in the public repo. Nothing here starts without the owner asking. Roadmap items now also exist as GitHub issues (#33 to
#39, milestone Roadmap).

## Follow-ups queued (status as of 2026-09-29)

| # | Item | Status |
|---|---|---|
| 1 | Deploy `v0.3.0-alpha.1` to the app host (Host-A) | Done. Superseded: alpha.2 went out 2026-09-26, then alpha.3, alpha.4, alpha.7 and beta.1. |
| 2 | Turn off debug logging on Host-A | Still open at 2026-09-27 21:46 ET (`KIPPLE_LOG_LEVEL=debug` and the Reader API form logging in the stack `.env`); the owner said he would flip it. Not recorded as done. Related: issue #52 showed Kipple has no debug-level lines for routine fetches, so a lower level would add nothing; targeted tick and fetch-summary debug logging is a queued idea, not built. |
| 3 | Reserved settings | Done for `greader.ot_includes_user_changes` and `greader.subscribe_fetch_now` (alpha.2). `stats.api_single_read_is_open` is still reserved: stored and validated, read by no code (design.md section 8); it waits for issue #36. |
| 4 | Auto-read and disabled feeds | Done, pinned by a test (phase 3). |
| 5 | GitHub Releases | Done. Releases exist for every tag (the older ones were created 2026-09-26; alpha.4, alpha.7 and beta.1 as pre-releases with the CHANGELOG section as notes). alpha.5 and alpha.6 have no tag. |
| 6 | Host-A backup job of its own | Open, outside the repo. The owner has not asked for the job to be drafted; Host-B's nightly jobs still pull Kipple's snapshot, compose file and `.env` (14 dated copies) and into the Proton archive. |
| 7 | Public-repo housekeeping | Done: Actions is green as the CI of record; the first Dependabot PRs (#2 to #6) merged 2026-09-27 and its config was tidied (#24); the 2026-09-28 hygiene pass found tags, branches and settings clean; fuzz ran before alpha.4, beta.1 and beta.2. Open observation: Actions `sha_pinning_required` is off and all merge methods are allowed (not urgent). |
| 8 | Diary and meeting notes | Now a standing rule: update this repository at least daily (owner, 2026-09-29), and Kipple's `CLAUDE.md` says so (PR #89). |
| 9 | Release steps 8+ | Full audit: done (local deep review 2026-09-26, phase 5 code audit PR #26). Changelog review: done (in #26). Documentation run: done (PR #42). First-time Docker setup walkthrough: done as UAT Suite 5 (produced the README Quickstart). Backup and restore: done as UAT Suite 4 (restore drill and migration rehearsal). Final go/no-go meeting: open, after the beta soak and an rc. |

## Owner's checklist items from phase 3

- Private vulnerability reporting switch: done (confirmed on by the GitHub API on 2026-09-27).
- `claude-md-proposed-edits.md`: dropped (removed from this repository 2026-09-27; marked dropped in the tracking list).
- Debug logging off: see item 2. Proton job: see item 6. Cloudflare changes: done for Access JWT (below).

## Built since the last update (formerly deferred)

- **Cloudflare Access JWT validation**: built in PR #40 (beta.1), off unless both `KIPPLE_ACCESS_TEAM_DOMAIN` and
  `KIPPLE_ACCESS_AUD` are set. Whether the owner has enabled it in Cloudflare is not recorded.
- **Optional-password login**: built in PR #40, only with Access validation on (remove the web password from Settings).
- **Scheduled auto-night theme**: built in PR #41 (issue #32).
- **Favicon finder**: built (alpha.3, migration 0006).
- **Lossless WebP thumbnailing**: already supported.
- **Phase 4 (stats)**: complete (alpha.4 to alpha.7). **Phase 5 (release readiness)**: complete in beta.1; beta.2 in prep.

## Deferred ideas (do not raise until the planned phases are done)

- **Setup app and single pull-and-run image** (1.5.0 or 2.0.0, issue #33): custom domain, optional Cloudflare OTP, a
  generated API password for Reeder and similar apps; first-time setup when using Docker.
- **All config-file settings move in-app** (added 2026-09-28): every `.env` variable Kipple reads at startup (username
  and password, public URL, trusted proxy IPs, Access team domain and audience, scheduler tuning, log level, etc.) should be
  configurable from the app, not a file edited before first run. Likely needs a first-run setup flow, since some are
  required before the server will start. Folds into the setup app rather than being separate work.
- **User-chosen Google Fonts** (2.0.0, only if cheap; issue #34).
- **Design system, static demo site, Kipple identity and accent colour** (issue #35; Kipple stays single-user).
- **Stats extensions** (added 2026-09-26): stats for Reeder and other Reader API clients (issue #36; read inference),
  reading pace (words per minute), period comparison, per-feed drill-down, monthly charts, read rate per feed (issue #37).
- **Filters follow-ups** (issue #38: only-show-matching, reading-time UI, per-feed view and order) and **more reading
  layouts** (issue #39: Columns, Reader list, Expanded stream).
- **Lossless WebP limits and other image-pipeline follow-ups** (see the thumbnail memory model notes).
- **Targeted fetch and scheduler debug logging** (added 2026-09-27, from issue #52): a tick summary and per-feed fetch
  outcomes at debug level, rather than a new log level.
- **Reader "refresh all"**: decided, no exception. The Reader API has no such call; clients never trigger fetches.
- **Accessibility testing on real hardware beyond automated checks**: not doing (owner's decision). A scale test: not
  doing (Host-A already runs the real feeds).

## Open GitHub issues at 2026-09-29 (besides the Roadmap ones above)

- #57 list layouts need clearer differentiation and #62 mobile tab-bar seam: both have shipped first-pass fixes (#68,
  #64); the owner closes them after checking on his phone, which is part of the beta.2 plan.

## Rules and preferences the owner has set (standing)

- Never use the owner's real name, surname or personal email anywhere (license, notices, docs, commits, examples).
  Use "the owner"; committer name `WPTK`. Keep hostnames, addresses and paths generic in anything public.
- Open-source-style license: Blue Oak Model License 1.0.0 (decided). The owner was told real open-source licenses
  cannot forbid commercial use.
- Fix every review finding; no "won't fix" lists (a code review at high effort now runs before every tag).
- Never Haiku. Ask before any Host-A deploy. One writer at a time on the server.
- Multi-user is withdrawn, not parked. Per-device profiles are not multi-user.
- GitHub Actions: on and free since the repository went public; it is the CI of record. `scripts/ci-local.ps1` is the
  fast pre-push check.
- Public repo goes through independent hostile review before any history rewrite or release that could leak details.
  Both public repositories (Kipple and this one) have had their history rewritten for that reason (item 26 of
  [CHALLENGES.md](CHALLENGES.md) for this one).
- Ultra reviews: retired 2026-09-26 (no credits); the local multi-agent review replaced them.
- Merges: the agent may merge a PR whose CI is green on its exact head commit, only after discussing it with the owner
  (2026-09-29). Tags, releases, deploys and anything touching workflows, deploy files or repo settings always ask.
- Auto-fix monitoring on for every PR (2026-09-27).
- Changelog: one fragment file per change in `changes/`, never edit `CHANGELOG.md` directly (PR #85, 2026-09-29).
- Update kipple-history at least daily (2026-09-29).
- Beta and rc builds change only fixes. Beta 2 comes before rc.1; rc.1 needs Suites 1, 2 and 4 re-verified plus a soak
  week with zero incidents (2026-09-29).

## Phase 6 candidates (added 2026-09-27)

- **Systematic root-cause debugging protocol in `CLAUDE.md`.** The owner asked whether Kipple's dev process was
  missing anything a "software dev pipeline/agents" checklist would cover: framework/boilerplate blueprint,
  linter/type-check enforcement, test-driven generation, systematic debugging, refactoring/clean-code patterns.
  Assessment: the first, second and fifth are already covered, and more robustly than an installed Skill would
  do it (`CLAUDE.md`'s Decisions/Layout sections, CI's gofmt/vet/staticcheck/ESLint/tsc gates, and the fixed
  package layout plus `/code-review`/`/simplify`). Test-driven generation is substantially covered in outcome
  (high real coverage, ~91% on web, tests shipped alongside every phase 5 feature) even though tests aren't
  written strictly test-first. The one real gap: no documented "inspect traceback → isolate → check state/types
  → minimal targeted patch" debugging protocol for Kipple itself, unlike the Host-B-level `CLAUDE.md` which has
  good root-causing patterns for known ops failure modes. Recommendation given and accepted: don't install a
  third-party debugging Skill (same reasoning as declining `webapp-uat`); instead add a short, Kipple-specific
  debugging-protocol section directly to `CLAUDE.md` when phase 6 starts.

## Added 2026-09-29: setup wizard and pull-and-run image (roadmap #33, now scheduled)

Scheduled, no longer parked: first-run setup wizard plus one-command Docker install, as a beta (0.5.0-beta.1, or 0.4.1
if the numbering changes; an exception to "beta adds no features", soak clock restarts on it).

- Default port **1919** (IANA: IBM Tivoli only, no common app); fallback 1138. Host-A keeps 7080 by override.
- Account creation (username, optional password) moves into the wizard. No password required, with a notice to keep it
  behind Tailscale or localhost only; passwordless mode needs Host/Origin validation. Setup claim protected by a
  one-time token in the container log.
- Wizard steps: account, theme, OPML import (skippable), recommended feeds (skippable, from a separate editable data
  file; the owner supplies the list). Later steps: custom domain, Cloudflare OTP, other config that is env-only today.
- Build info: OCI labels, richer `kipple version`, About screen with copy-debug-info, service-worker vs server version
  banner, downgrade guard (refuse a database newer than the binary), image digest, what's-new after upgrade. No
  update-check (no phoning home).
- GHCR is the first registry (multi-arch, cosign, SBOM). **Where else to host is parked until 1.0**: Docker Hub, Quay,
  Unraid Community Apps, CasaOS/Umbrel/Runtipi, awesome-selfhosted, selfh.st, Portainer/TrueNAS templates.

## Added 2026-09-29 (evening)

- **Font selection in Settings > Appearance & Reading and in the wizard.** Today it exists only in the "Aa" reading menu
  in the article header (`ReadingMenu`). Also find out whether the Aa button is actually missing somewhere in the owner's
  build. Not decided.
- **A repository ruleset restricting who can create `v*` tags**, since a pushed tag now publishes a signed image.
- **Registries beyond GHCR until 1.0** (Docker Hub, Quay and the others listed above): still parked.
- **Status of the setup wizard item above:** built and merged 2026-09-29 (milestone 7), unreleased; the overnight audit
  issues #124 to #135 are open in that milestone (audits/overnight-2026-09-30.md). #108 (offline queries) remains open.


## Added 2026-09-30 (after the `v0.5.0-beta.1` release)

- **Make the GHCR package public** (owner, by hand). Until then anonymous pulls of `ghcr.io/wptk/kipple:0.5.0-beta.1`
  fail and the pull-and-run quickstart cannot work for anyone else.
- **Repository ruleset restricting who can create `v*` tags** (owner): still not done; a pushed tag publishes a signed
  image.
- **rc.1** not before 2026-10-07 (soak restarted by the beta.1 deploy), with Suites 1, 2 and 4 re-verified.
- **Release step to add:** compare the deploy host's compose file with the repository's example (build args) before a
  tag that changes build info (CHALLENGES 47).
- **#154:** flaky `TestApplyBudgetEndsTheRun` under `-shuffle`, open. #108 (offline queries) still not scheduled.
- **Closed or settled:** the font question (#153; it was in the "Aa" menu all along); the commit-author name question (the
  GitHub display name "BK" is fine); the starter feed list (#152); the wizard audit issues #124 to #149 (fixed and merged).
- **Access rules** moved to a deterministic hook (MEETINGS 46); not to be edited by the agent.
