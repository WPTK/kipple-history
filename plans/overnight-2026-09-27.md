# Overnight plan, 2026-09-27 (about 8 to 10 hours, until the morning review meeting)

Written 2026-09-26 at about 23:15 ET after the owner went to bed. I follow this in order and record where I am in the
status log at the bottom. Rules first, then the work.

## Rules while the owner sleeps

- **No deploys, no tags, no Host-A changes.** Host-A stays on v0.3.0-alpha.4. Read-only ssh is fine. A tag is made at
  deploy time on the exact deployed commit (RELEASING.md), so tags wait for the morning go-ahead.
- **Merges:** the owner said in chat he approves any merge I present. I open PRs, wait for CI on GitHub (the CI of
  record, with `-race`), fix review findings, then attempt the merge once through the normal REST call. If the
  permission classifier denies it again I do not route around it: I leave the PR ready and record it here.
- Every change: branch, `scripts/ci-local.ps1`, Opus review of the diff (fix every finding, minor ones included), PR,
  CI green. Never Haiku. Sonnet for routine code, Opus for review and anything subtle. One writer per file set.
- No real names, hostnames or personal paths in committed files. Diaries and meeting notes go to this repo.
- Each alpha is deployable on its own; schema changes are noted (0009 in alpha.5).
- Stop and leave a note (not a guess) if a decision belongs to the owner.

## Work, in order

**Block 1 (hours 0 to 2): finish alpha.5 (Stats screen, branch `phase4-stats-screen`, commit 461cfbf).**
Three Opus reviews are running (SQL and definitions; web correctness and UX; migration, security, conventions). Fix
every finding with agents (disjoint files), re-run local CI and a second review of the merged diff, push, open the PR,
wait for GitHub CI, attempt the merge. Then prepare (do not run) the alpha.5 release: CHANGELOG move on a release
branch, deploy inputs listed in the morning note.

**Block 2 (hours 2 to 5): alpha.6 (export and data controls), new branch off alpha.5.**
- Server: `GET /api/stats/export` (CSV RFC 4180 and JSON, array or JSON Lines; raw events or summary; range week,
  month, year, all or custom; toggle to omit item titles and URLs; data dictionary included; keyset paging, no read
  transaction held across a write); `POST /api/stats/delete` (a date range, with the count shown first through a
  dry-run) and delete-all (typed confirmation). Stats events only; never items, read state or the id ledger. Same-origin
  guard and login as the other stats endpoints.
- Web: Export button under the range selector (dialog with format, contents, range, titles toggle); Settings >
  Statistics gets Delete range (shows the count, confirms) and Delete all stats (typed confirmation).
- Tests, docs (design section 7/8, deploy, CHANGELOG), Opus review, fixes, CI, PR.

**Block 3 (hours 5 to 8): alpha.7 (Wrapped), new branch off alpha.6.**
Yearly summary (totals, top sources, popular days and times, longest streak, longest read) with the simple opt-in
share sheet (aggregates only by default), a Wrapped on/off setting next to the stats switch, its screen and empty
states. Same process: agents, Opus review, fixes, CI, PR.

**Block 4 (hours 8 to 10): wrap-up.**
Re-run everything on each branch, update the docs and the history repo (diary, timeline, decisions, this log), write the
morning brief: what is merged, what is open, what needs his decision, and a recommended deploy order (my
recommendation: alpha.5 first, since it has migration 0009; then use it before 6 and 7). Leave the working tree clean
and every branch pushed.

## Morning brief will contain

PR list with CI state, anything denied or blocked, decisions needed from the owner, the alpha.5 deploy steps ready to
run on his go-ahead (off-box copy, migration rehearsal on a copy of live data, `up -d kipple` only, verify), the iPhone
`hasFocus()` check result if he has read on the phone since alpha.4 (checked read-only from a scratch copy of the
database, deleted after), and known risks.

## Status log

- 23:15 alpha.5 committed and pushed (461cfbf); three Opus reviews running.
- 23:50 first Opus reviews (SQL, web, migration/docs) done; about 25 findings fixed by two agents; local CI green;
  fixes committed (9b05fc1). PR #19 (alpha.5) opened; second review of the fixes running; GitHub CI running.
- 00:40 alpha.5 merged (PR #19, main 85b07bf); release PR #20 merged (main c7b3c10, CHANGELOG under 0.3.0-alpha.5);
  alpha.5 is ready to tag and deploy on the owner's go-ahead (nothing tagged, nothing deployed).
- 00:40 alpha.6 (export and data controls) built and rebased on main (e58459c); local CI green; end-to-end check of
  export, dictionary and delete dry run against a seeded dev instance passed; three Opus reviews running.
- 00:40 new tasks from the owner: resolve the open dependency PRs (7 Dependabot PRs on Kipple, none elsewhere) and a git
  hygiene pass over Kipple, kipple-history and kipple-website; both assigned to Opus agents, results go in the
  morning report.
