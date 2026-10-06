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
- Times above are approximate (the log was written from memory of the order of events; the real clock at the
  alpha.5 release merge was about 00:15 ET). Actual events, in order, from about 00:20:
- 00:26 INCIDENT: a dependency-testing agent ran the web test suite inside a Docker Desktop container on Host-B; the
  engine health probe failed under load and the `DockerCleanStart` task restarted Docker Desktop. All 21 containers
  and the tunnel were back by 00:26:52; public services were down about 20 to 50 s. Verified healthy at 00:28. A
  memory note now forbids heavy jobs in Docker on Host-B.
- 00:30 hygiene pass done (audits/git-hygiene-2026-09-27.md); dependency assessment done (5 Actions bumps safe, Node 26
  image and TypeScript 7 not yet); Actions PRs being merged one at a time (rebase, green CI, merge). Alpha.6 review
  fixes in progress (server and web agents).
- 01:00-01:25 alpha.6: second review of the fixes found 8 web + 3 server items (dialog state persisting past close was
  the standout: closing after arming a delete confirmation, or typing DELETE ALL then cancelling, could leave a
  one-click delete armed on reopen); all fixed, dialogs now mount fresh on every open. GitHub CI's -race run then
  caught a real gap: 5 new tests timed out (a test helper did 25k+ single-row inserts inside one 10s write
  transaction, too slow under -race); fixed by chunking into several transactions (test-only, no production change).
  Five Dependabot Actions PRs merged one at a time (rebase, green CI, merge): checkout, setup-node, setup-go,
  setup-buildx, build-push. Node 26 image and TypeScript 7 left open for the owner (see the dependency assessment).
- 01:25 alpha.7 (Wrapped) built: yearly summary derived from the existing summary endpoint (no new endpoint), opt-in
  share sheet (aggregates only by default, two toggles for sources/longest-read), stats.wrapped_enabled setting.
  Local CI green on the stack. Not yet reviewed or checked visually.
- 01:30-02:00 alpha.6 fully shipped: PR #21 (feature) and PR #22 (release, CHANGELOG under 0.3.0-alpha.6) both merged,
  main at 5bcba69. Alpha.7 (Wrapped) rebased clean, local CI green, checked visually at phone width incl. the share
  dialog (privacy toggles default off, no overflow). Three Opus reviews found ~22 items, none a privacy leak (every
  reviewer independently confirmed default share output has no feed names/titles); standout bug: switching years
  while a request is in flight could label the previous year's numbers under the new year, with Share still enabled.
  Three fix agents dispatched on disjoint files (model/year-switch, share mechanics, docs); docs and share-mechanics
  done (974/974 tests); model/year-switch fix still running.
- 02:00-02:20 alpha.7 fixes: model/year-switch, share mechanics and docs all done in parallel (disjoint files); local
  CI green; PR #23 opened, GitHub CI green including -race, merged (main f865cbc). All three phase-4 alphas (sender,
  screen, export/data controls, Wrapped) are now on main. Release PR #24 (Dependabot config tidy: ignore TS>=7, ignore
  Node major for the image, group Actions majors) opened; PR #7 (TypeScript 7) closed with explanation; PR #1 (Node 26)
  stays open until 2026-10-28 LTS. Release PR #25 (0.3.0-alpha.7) opened, catching the same CHANGELOG auto-merge fold
  seen with alpha.6 before it was pushed.
- Nothing tagged, nothing deployed. Host-A verified untouched at alpha.4, healthy.

## Final status, 02:35 ET

All four PRs for tonight's dependency/hygiene follow-ups merged: #24 (Dependabot config), #25 (alpha.7 release).
Phase 4 complete on main (00510e3): alpha.4 sender, alpha.5 screen, alpha.6 export/delete, alpha.7 Wrapped - all
merged, none tagged, none deployed (Host-A verified untouched at alpha.4, healthy). Zero open PRs. Local branches
cleaned (worktree-locked fix-ops/fix2-auth left for the owner). Full local CI (13 steps) green on merged main,
confirmed twice after one flaky rerun of the already-known review3search.test.tsx timing issue (spawned as a
follow-up task, not blocking). Ready for morning review and a deploy decision.

## Morning meeting, 2026-09-27 (~08:30-09:30 ET)

- Approved: private vulnerability reporting on Kipple (enabled, 204); HTTPS on kipple-website deferred (needs
  Cloudflare CNAME for kipple.cc first, owner's task); scratch-directory deletion (7 of 8 removed, ~700MB; kipple-review
  blocked by a harness path guard, owner to remove by hand); the combined alpha.5-7 deploy; kipple-history may be
  scrubbed of personal data (not yet done, queued as its own careful pass); website's dead link to the private history
  repo left as is (repo will eventually go public).
- Found and resolved: the two locked agent worktrees (fix-ops, fix2-auth) were held by a stuck claude.exe process
  (PID 41456) idle ~19 hours with no new commits since 2026-09-26 15:56 ET; killed on the owner's go-ahead, worktrees
  and merged branches cleaned up.
- Merge permission: the classifier's block turned out to be `autoMode` policy, not a plain Bash rule; gave the owner
  the exact settings.local.json snippet. Then hit a second, harder classifier block (Self-Modification) when asked to
  edit that file directly, even on the owner's explicit instruction - a harness-level boundary I did not route around.
  Also proposed a soft-deny classifier rule (or a PreToolUse hook) against local Docker test runs on Host-B, given
  the overnight incident.
- **Deployed v0.3.0-alpha.7 to Host-A** (all of phase 4: sender, screen, export/delete, Wrapped), combining alpha.5,
  6 and 7 into one push per the recommendation: tag v0.3.0-alpha.7 on main (00510e3), off-box copy of the live database
  first (P:\ServerBackups\kipple\pre-0.3.0-alpha.7-20260927-085606, schema 8, integrity ok, 6,718 items), image built
  on Host-A from the tag, migration 0009 rehearsed on a scratch copy (clean), fuzz clean (26/26 targets), deployed
  `up -d kipple` only: healthy, version 0.3.0-alpha.7, 41.6 MiB, zero warnings. GitHub Release published.
- Still open: kipple-history personal-data scrub (owner authorized, not started); the iPhone hasFocus() check now that
  the sender is live in a screen the owner can actually use; kipple-website HTTPS once DNS is set; kipple-review
  directory deletion by hand; the classifier/hook suggestions above, pending the owner's decision.
