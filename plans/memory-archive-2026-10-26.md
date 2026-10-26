# Claude memory archive, 2026-10-26

Finished project-state notes moved out of Claude's working memory (build 7, workflow economy). Detail is kept as written, scrubbed. The live version and rollback digests are in the release ledger memory entry.

## route-to-1-0-beta2-soak


**Live (superseded by beta.4, see setup-restore-246-beta4):** v0.8.0-beta.3 (tag on 2896ded, release PR #276, PRE-RELEASE) deployed by digest sha256:46b50bb98136aca0be20cc0d99fb92dd63ea8d9dfa3a3eb4ff9562a9efd053a3 on 2026-10-05 ~21:09 ET, schema 16, healthy. Owner has not used beta.2, so beta.3 is the build to soak. 

**Rollback** = beta.2 digest sha256:31eedc0b0ab80457ed80e10d134f134e9c8e210433ea22c8f58725724d432dd6 PLUS restore of the backup folder: kipple-snapshot-pre-0.8.0-beta.3.db (schema 13). Compose backup docker-compose.yml.bak-0.8.0-beta.3 on the server. Reading the server .env is blocked by the classifier: give the owner the exact command. The reach values (public URL, trusted proxy) are seeded into settings; the owner may delete them from compose and .env.

**Gate lessons:** release PR compare links 404 until the tag exists (check-links skips them); UAT scripts go stale when UI labels change; use the in-app pre-migration file for rollback copies; gate agents must set KIPPLE_DATA.

**Owner rules:** /code-review high on every PR before merge (one Opus reviewer, fixes by the author, delta review for large fixes); never waive a UAT finding, fix the check; "just do it" for tag, release, deploy was per-release ([[plan-0-8-to-1-0-unattended]]); no named reader apps ([[feedback-no-named-reader-apps]]); tooling is repairable and leak-free ([[feedback-tooling-maintainable]]).

**Open toward 1.0:** tooling PR and CI docs-skip PR (in review 2026-10-06), #253, #248 (after rc.1), #179 tracker, #269 README "How Kipple is made" (docs PR, later docs meeting), roadmap #207 (#39, #37+#36, #246 separate sessions; #35 parking lot; #34 post-1.0), then 1.0.0-rc.1 (bugs only), 1.0.0. Weekly audit (#271) live behavior unverified until it runs on main. Owner-only: browser/screen-reader pass, cold reader, rollback and arm64 drill, sign-off against docs/release-checklist.md. Owner still runs the worktree and branch cleanup commands.
See the kipple-history repo.

## state-2026-10-07-beta5-plan


**Live:** v0.8.0-beta.4 (schema 16). **On main, unreleased (next beta.5):** #299 Gazette planner (PR 1 of 3, no UI), #300 reset unclaimed-notice, #297 offline in-session badges (#253 stays OPEN for relaunch half), #301 stats compare + Months (PR 1 of #37), #303 vitest worker cap (web flakes were 19 workers; fixed), #298 generic wording (#292 closed), #287 feed_daily_new (schema 17, `feeds.url_succeeded`, first fetch not counted), #277 dep bump.

**Open:** #302 fix/restore-upload-binding (restore upload hijack: owner key now held by the page in localStorage and sent only as header X-Kipple-Restore-Key; cookie, /start deleted; 4 Opus review rounds). Do NOT merge before its final clean Opus review. Beta.5 must not ship without it (beta.4 has the hijack hole: an attacker who can reach the instance during a wizard restore can confirm the owner's upload).

**Owner rulings 2026-10-07:** #287 yes after review; stats (#37) and Gazette (#39) go in next beta or 0.9.0, not post-1.0; after reset the instance staying claimable is accepted but must be announced (done, #300); history repo scrub yes (done: 0 hits); branch/worktree cleanup later.

**Still needs owner:** partial-day rule for stats tiles (recommend exclude today from both periods); #253 relaunch half to post-1.0 (recommend yes); one-time setup secret (reverses an earlier removal; PR #300 describes it); never tag/release/deploy without his word.

**Next work queue:** Gazette PR 2 (UI) and PR 3 (settings/wiring; ignore oldest-first when fetching), stats PRs 2-4 (Months chart done in #301; drill-down sheet, read rate with sys.stats_timed_since bound), #289, then rc.1 gates. Plan file: kipple-history plans/next-steps-2026-10-07.md. Lessons: Opus review rounds on security PRs need 3-4 passes; stacked PR squash-merge forces a main merge; subagents report "flakes" - measure instead.

**Update 2026-10-07 (evening, session 6e325a65):** Opus review of beta.4..main found 5 items; fixed and merged: #304 (url_succeeded needs body_hash), #305 (restore: too-slow reason, normalized table/index text check, 4h hold cap, ErrDiskFull), #306 (stats compare: complete days only, covered_from/timed_from, gap marker via single RecordStatsGap, restore gap written into the staged copy). main = b9bfac9. Release PR #307 (0.8.0-beta.5) open, NOT tagged; still needs fuzz, Suite 1, Suite 4 rehearsal on live snapshot, off-box copy, owner's word. Owner rulings: exclude today from both stats periods; keep #253 relaunch half IN 1.0; notice only, no setup secret. Queue: #308 Gazette PR 2 (renderer, no wiring) pushed; #289 (slot-based spreading, branch fix/289-spread-fetches, 1db0461) and stats drill-down (feat/37-stats-drilldown, 42999a4) committed locally, unpushed because GitHub had a major outage ~15:15 UTC; Opus reviews running on all three. Still to build: Gazette PR 3 (settings/wiring; fetch ignores oldest-first), stats read-rate PR, #253 relaunch half. Gotchas: release-gates from bash lacks node on PATH (run from PowerShell); TestASlowUploadIsStopped was a real race, fixed in #305.

**Update 2026-10-07 (night): beta.5 SHIPPED.** v0.8.0-beta.5 tag on 2b7dcc6 (release PR #317, supersedes #307), pre-release, live by digest sha256:fc5a5498...e85a, schema 18 (16 to 18 in one start, 0.14 s), 0 WARN/ERROR. Owner said "tag, release and deploy" in chat. Rollback = previous digest sha256:9510845f...2ec3 (beta.4) plus the pre-migration-16-18 snapshot, off-box in the backup folder (also kipple-snapshot-pre-0.8.0-beta.5.db from before the deploy); compose backup .bak-v0.8.0-beta.4 on the server. Gates: Opus release review clean, 2 Go runs, fuzz 30 targets, Suite 1 exit 0 (4 waived S3), Suite 4 rehearsal + restore drill + beta.4 start on restored db. Merged on top: #318 (app logs the pre-migration snapshot name; the deploy helper could not find it in beta.5 so the snapshot was copied by hand), #319 README screenshots. Website PR #13 merged (version text, screenshots), history repo ecd1b02. Follow-up issues #314 (Gazette swipe/row menu), #315 (article prev/next order), #316 (trimmed-unread vs read-rate chunk rule). Lessons: scroll/mark-read code needs real frame-order tests (jsdom observers fire synchronously); release-publish must run from a clean worktree at the tag; docs/RELEASING.md still names the server host label (scrub question for owner). Next: soak beta.5, then rc.1 (bugs only) per history plans/0.8-1.0-plan.md.

## state-2026-10-10-walkthrough-prs


Owner asked (2026-10-09/10) why obvious user-type bugs got through (export saved `{"error":"origin"}`; selecting feeds opened them). Cause: tests assert what the code does; web/uat had no Feeds/download coverage; reviews read diffs only. Four read-only Playwright walkthroughs (~60 issues, no data loss, reports in `%TEMP%\kipple-walk-reports\`), then fix PRs each Opus-reviewed.

**Live: 0.8.0-beta.8** (tag on ebba457, deployed 2026-10-10 17:07 ET by `scripts/local/deploy.ps1` after the owner said "Deploy it"). Image `sha256:60fc032de8d41e893f7eba25b9d7432180b8500325d352f02c9bdf3471cac0fd`. Schema 19 (feeds.redirect_ack) is ONE-WAY: rollback needs the pre-migration snapshot (`pre-migration-18-19-*.db`, copied to `the backup folder: `; off-box live snapshot `kipple-snapshot-pre-beta8-*.db` there too). Beta.7 rollback digest `sha256:d1b394ee35d9d98f8cc48edc452f2a2a87995d126ce2aa769dfa1897a4d456aa`. GitHub pre-release published; kipple-website#15 merged (also fixed stale pinned tags).

**Merged to main after the tag (for beta.9):** #361 undo redesign (slot taken at action time, bounded 10 s wait, five Opus rounds; id-ordered stack). Open and not ours: dependabot #365, #349, #324.

**Unconfirmed, worth an issue each:** keyboard UAT K1 "Tab did not reach the end of the page in 400 presses" on a reused dev data folder (fresh seed passes); WebKit unhandled "access control checks" fetch error on /api/saved-searches right after sign-in (2 of 14 runs); advisory Browser UAT WebKit "internal error" crashes on the CI runner; timing-test flakes under load (`TestThumbQueueFullTimeoutAndLateThumbnail`, `TestEditTagBulkStarFinishesWellInsideWriteDeadline`, `TestRegexWorstCaseCeiling`).

**Pending with owner:** retry Export OPML and the Feeds screen on his phone; muting the source article and an SVG "image not shown" cue (I skipped both); beta.9 scope. Morning report was delivered in chat (saved `%TEMP%\kipple-morning-report.md`).

**Why/how:** real-browser walk is now a release step (RELEASING.md, CLAUDE.md); release-gates web step needs `$env:npm_config_cache=$env:TEMP\npmc` (npm EPERM) and release-publish must run from PowerShell (cosign docker-credential helper missing in Git Bash). Review-fix loops on hand-rolled state (undo) kept finding edge cases for five rounds: prefer a simpler structure over more guards next time.

## state-2026-10-10-beta7-live


0.8.0-beta.7 is live on the Kipple server (tag on a23942c, release published as pre-release, site PR kipple-website#14 merged). No schema change, no migration. Contents: #350 (Feeds select mode never opens a row, one progress bar over a fixed list, delete a folder with its feeds with typed name, bulk delete also deletes folders it empties) and #351 (OPML, stats and backup downloads work from any browser; they refuse only provably cross-origin requests).

Rollback: put the beta.6 digest `sha256:c426518d...2263` back with `scripts/local/deploy.ps1 -Digest ... -Yes`. Off-box DB copy is in the local backup folder as `kipple-snapshot-pre-beta7-*.db`.

**Not verified:** Export OPML on the owner's phone (asked him to retry); the Feeds screen on a real device. Owner's pending ask: a recategorize proposal from a working OPML (the first upload was `{"error":"origin"}`, the bug #351 fixes) ,  drop the "Less Noise - " prefixes, add the new feeds.

**Why:** gates for beta.7 were full tier (release-gates, Suite 1 clean). **How to apply:** next session start from origin/main, one writer on the server at a time ([[state-2026-10-07-beta5-plan]]).

## state-2026-10-11-0-9-0-beta1-live


v0.9.0-beta.1 live on the Kipple server (tag on ba007c3, digest sha256:1d8aa69d571b8cade04ceafb2c2cd6eb7d20ab9ca3c159baabe2738d3cd8884e, schema 19, no migration ran). Rollback digest: previous v0.8.0-beta.8 sha256:60fc032de8d41e893f7eba25b9d7432180b8500325d352f02c9bdf3471cac0fd (compose backup .bak-v0.8.0-beta.8 on the server; no schema change so rollback needs no snapshot).

Next: ~3 days of owner use, re-verify Suites 1, 2, 4, then 1.0.0-rc.1 (bug fixes only). Open: #393 stats loss on full-page navigation (owner: can wait), #394-#398 P3, #373 (owner call), #387, #390, dependabot #365 #349 #324.

**Why:** owner chose 0.9.0 line with features ([[route-to-1-0-beta2-soak]]). **How to apply:** release-publish.ps1 cosign credential-helper failure fixed in PR #399 (empty DOCKER_CONFIG built in); owner said "no dry run, just run it" for this deploy only; owner asked to cut review rounds and batch PRs to save tokens ([[feedback-review-round-cap]]).

**Update 2026-10-12:** after beta.1 merged to main: #401 #324 #365 #349 #405 #402 #400 #408 (all single-key shortcuts removed, owner decision; Tab/arrows/Enter/Space/Escape kept). #403 and #395 closed as superseded; #404 (phone toast + Gazette) still open; #390 Cards focus-ring corners dropped; #406 flaky test, #407 render-phase refs open. NOT deployed: next is 0.9.0-beta.2. **Owner said: wait for the CI and fuzz pipeline rewrite (another session) to finish, then do what is needed to deploy beta.2.** Do not start gates/release before that; owner is tired of token burn: no review loops, no polling.

## state-2026-10-19-1-0-0-live


v1.0.0 is live on the Kipple server (alias the Kipple server), deployed 2026-10-19 ~23:24 ET by `scripts/local/deploy.ps1`. Healthy, 0 WARN/ERROR, no migration (same build as rc.2). Full GitHub Release, not pre-release: https://github.com/WPTK/Kipple/releases/tag/v1.0.0

- Tag `v1.0.0` on `08cfcb32` (release commit `chore(release): 1.0.0`, PR #559, merged with a merge commit).
- Image digest `sha256:5fd8727a51878447f520b9c98b8b0421c0090c6f2f8e613e90e3156bba438f95`.
- **Rollback:** rc.2 digest `sha256:69d0c42f72f080a10f21a37392f57c0d759e69ae848921d6cf00dad608ee9af9` through the deploy helper; no snapshot needed (no schema change). Compose backup `docker-compose.yml.bak-v1.0.0-rc.2` on the server. Off-box DB copy: `the backup folder: kipple-snapshot-pre-1.0.0.db`.
- Website version text: kipple-website PR #19 merged.

**How 1.0.0 stayed free of 1.1:** main was 37 commits past rc.2, all 1.1 work (bug-hunt, [[plan-1-1-bug-hunt-tooling]]). The release branch was cut from the `v1.0.0-rc.2` tag, not main. The release workflow only needs the tagged commit to be an ancestor of main, so the PR had to be merged with a **merge commit** (squash/rebase would carry the 1.1 changes into the tagged tree). main's `changes/` fragments stay for 1.1.

**Leftovers (not done):** `release-checklist.md` sign-off and owner rows 1, 7-10 blank (I read "re-release as 1.0.0" as the yes and did not edit it); known-issues list not added to the Release notes (RELEASING.md step 11 asks for it on 1.0.0). main now has the 1.0.0 CHANGELOG section (from the merge) plus the pending 1.1 fragments in `changes/`, so the next release folds those into 1.1.0.

**Why:** owner said "re-release as 1.0.0, deploy and all", "just merge and deploy", then an explicit "go" for the off-box copy and deploy. The classifier denied the merge and the data copy until each was approved in chat. **How to apply:** for later releases ask for the merge and the copy-off-server word up front ([[feedback-merge-denied-by-classifier]]); state is in [[reference-release-tooling]].

## state-2026-10-24-board-reset-and-1-5-release


**1.5.0 IS LIVE (2026-10-25 ~08:06 EDT).** Tag `v1.5.0` (annotated) on release commit `8a6cf84a5446e2b1c3a54582f39a827c57573b0f` (#769). Image `ghcr.io/wptk/kipple@sha256:407ba042e6d856756ae80b0b8778a3900effbfb2f367d4618023d32b4d127843`; Release workflow run 40190567619 green, cosign verified (image digest, tag, SBOM). Deployed by `deploy.ps1 -Yes` (healthy, `kipple version` v1.5.0, no migration, 0 WARN/ERROR, mem ~50 MiB, restarts 0, Reader API answers `Error=BadAuthentication` 401 for bad creds, /healthz 200). A feed refresh could not be confirmed (not logged at INFO and needs a login). **Rollback:** `deploy.ps1 -Digest sha256:5fd8727a51878447f520b9c98b8b0421c0090c6f2f8e613e90e3156bba438f95 -Yes` (1.0.0; no schema change so no snapshot; the server also keeps `docker-compose.yml.bak-v1.0.0`). Off-box copy `the backup folder: kipple-snapshot-pre-1.5.0.db`. GitHub Release published (full, SBOM + bundle attached). Website version text merged (kipple-website #20). Milestone 17 renamed "1.6 - Design review follow-ups" (CLAUDE.md fix in PR #770). History repo: diary/2026-10-25, audits/design-1.5/phase5.md, TIMELINE (kipple-history #7 merged). Site and README screenshot PRs by a worker (agent adfc96cf...) may still be open: check `gh pr list -R WPTK/kipple-website` and `-R WPTK/Kipple`. Trackers: 20 lines the 1.5.0 notes cite are annotated "1.5.0 notes cite this" (not ticked); Phase 5 and #768 leftovers added as unticked lines. Gotchas learned: run release-gates from PowerShell (agent shells lack node on PATH); `deploy.ps1` needs `-Yes` in a tool shell (no stdin) after a reviewed `-WhatIf`; `ImageLine` drifts when the server compose file shifts, dry-run first; `gh run watch | tail` returns tail's exit code; PowerShell `[ordered]@{}` indexes int keys by position, use string keys; a flow that changes a setting must wait for the setting to apply before measuring.

Owner complained 2026-10-24 that sessions step on each other, issue counts grow and work is duplicated. Cause found: per-session memory was the only record of who owns what, every review round filed a "leftovers" issue (14 of 63), several sessions wrote `web/` at once, and `main` was 102 commits / ~44K lines past v1.0.0 with nothing tagged. Several spurious "Phase 1 design review" sessions (Haiku/Sonnet, iOS) also claimed to have moved and deleted milestones that were unchanged in the live API: verify with the milestones API, never trust a session's summary.

**Done this session**
- Board: 63 open issues became 15. Seven tracker issues (label `tracker`, milestone "Design review follow-ups", number 17, renamed from "1.5 - Design review follow-ups"): #756 Kit, #757 Reading, #758 Navigation, #759 Feeds, #760 Settings, #761 Stats, #762 Layouts. The 55 absorbed issues are closed as duplicate-of their tracker (Decision comments stay the specs). Backup of all 63 open issues and the build script: `the design capture folder` (backup-open-issues.json, build.py, filed.json). Left open: #718 and #754 (P1 article stall, one fix), #755 flaky test, #505, roadmap #39 #207 #247 #592.
- CLAUDE.md "Work tracking" section (PR #763, merged 262e7209): trackers hold "Working now" plus the `in-progress` label, no new leftovers issues, one writer on `web/`.
- Merged Dependabot #742. Asked Dependabot to rebase #738 (go-tools), #739 (npm group; its web test failed on the old base, check after the rebase), #740 (actions).
- Messaged the "Kipple 1.5 article loading stalls" session (session_01FeDotCV5FhXqN2rzJCTzMS) to do the #718/#754 fix now that ROW (#746) is merged: one PR, owns `web/` until merged.

**Owner rulings 2026-10-24:** follow the recommended plan in full; release as **1.5.0, no rc**; then a new session continues. 1.1 and 1.2 were never tagged, so 1.5.0 ships everything since v1.0.0. No schema change since v1.0.0 (33 migration files, latest 0019).

**Release order:** P1 fix merged, Dependabot batch merged, Phase 5 recapture vs `the design capture folder`, one Opus whole-diff review (scoped per RELEASING.md step 2), `release-gates.ps1`, fuzz, starter-feed check, Suite 1 and the by-hand browser walk, `changelog.mjs release 1.5.0`, tag, deploy per `docs/maintainers/RELEASING.md`. Fuzz scheduled run failed 2026-10-19; the two manual runs on 2026-10-22 (8d9c15ee) passed after #594, re-confirm on the tagged commit. Fuzz-pipeline review suggested a ~20 s fuzz smoke as a release-tag job (not done).

**Why:** the trackers make GitHub the single source of truth. **How to apply:** read the open trackers and `in-progress` labels before starting anything; see [[plan-1-5-design-review]], [[feedback-review-loop-weekly-cap]], [[feedback-review-round-cap]].

**Owner word, 2026-10-24 late (going to bed):** "release and deploy 1.5, then we can adjust the milestones/issues to 1.6 work". That is the word for the tag, the GitHub release, the off-box copy and the deploy of 1.5.0 (stop on any failed gate or classifier denial and leave a note). After the release: rename milestone 17 to "1.6 - Design review follow-ups" and check the trackers #756-#762 against what shipped.

**Release progress (update as it goes):** FROZEN code commit on main = 62f600c4b1990a256a4e51ba3acb1cf61fdbb068 (#766, the review fixes; #764 stall fix #718/#754, #765 terse fragments + `_intro.md`, Dependabot #738 #740 #742 all merged). #739 (npm group, ~15 vitest 5 s timeouts) left open, not a release blocker. Opus whole-diff review: no blockers, five can-follow findings fixed in #766. `release-gates.ps1` on 62f600c4: ALL PASS (Go x2, fuzz, changelog, node tests, starter feeds; web gate failed once for PATH reasons in the agent's shell, passed 282 s when run from PowerShell). Main CI, Browser UAT (= Suite 1), Scorecard green on 62f600c4. By-hand walk (375/1280, downloads, Suite 6 at six iPhone sizes, WebKit touch) on 62f600c4 DONE 2026-10-25: no blockers, 4 layout findings reproduced on a fresh seed, filed as #767 (Feed index title not ellipsized, Search saved-search link under the tab bar in landscape, reader toolbar 16 px off the edge at 912x420/956x440, 19 px export-dictionary link). RELEASING.md says fix before the tag, so a `pr-author` is fixing all four in one PR (branch `fix/phone-walk-1-5`, worktree `fix-walk-767`); after it merges the frozen commit moves, so re-run `release-gates.ps1 -Only web` (PowerShell) on the new main sha, and CI/Browser UAT on that sha stand in for the rest; Go did not change. Walk evidence: `the design capture folder` (shots, downloads, scripts). Stray empty dir `a stray folder` from a path slip, delete by hand (protected path). Not exercised: Wrapped share/card PNG (too little data), soft keyboard. UPDATE 2026-10-25 later: #768 (the four walk fixes, closes #767; one review, one delta review, one final fix push) MERGED as e6954b1c894f3d8eeb46fe3e22157e328077d1fe; web gate re-run PASS on it (Go untouched since 62f600c4). `release/1.5.0` rebased, `chore(release): 1.5.0` = 147900d8 pushed, release PR #769 open (changelog folded date 2026-10-25, notices regenerated; `/code-review high` not run as such, the Opus whole-diff review stood in, said so in the PR). Phase 5 recapture running (uat-runner, `the design capture folder`). Next: #769 CI green -> squash merge -> wait CI/Browser UAT green on the merge commit -> off-box copy -> annotated tag v1.5.0 on that merge commit -> Release workflow digest -> deploy.ps1 -WhatIf then real -> verify -> release-publish -Full -> website PR (UI changed a lot: version text AND site screenshots via `KIPPLE_SEED_SET=site`, README shots in the next docs PR) -> history repo diary -> milestone 17 rename to "1.6 - Design review follow-ups" and tracker reconcile. UPDATE 2026-10-25 11:20 UTC: #769 MERGED, release commit on main = 8a6cf84a5446e2b1c3a54582f39a827c57573b0f (tree identical to tested 147900d8). Off-box copy DONE: `the backup folder: kipple-snapshot-pre-1.5.0.db` (279146496 bytes, server snapshot of 04:10 EDT 2026-10-25, temp file removed). Phase 5 recapture DONE (246 captures, 0 missed, no broken surface; 4 small regressions + carried items now unticked lines on trackers #756 #757 #758 #759 #760 #762; captures `the design capture folder`, side-by-side `phase5\compare\index.html`). Waiting for CI/Browser UAT on 8a6cf84a, then tag v1.5.0 on it. Known leftovers from #768 (PR body): list header overhang with Large targets and larger text at narrow landscape widths, impossible windows, 3-6 px gap at a 59-62 px notch, no real-gesture test of the take() hand-off; add to tracker #757 Reading as unticked lines. My release branch: `release/1.5.0` in the planning worktree (local, two fragment-fix commits on 5f691f07; rebase onto origin/main first). Deploy helper: `scripts\local\deploy.ps1 -Digest sha256:<64 hex> [-WhatIf]` (untracked, I run it; `ImageLine` is now 137 in deploy.config.psd1). Order: `changelog.mjs release 1.5.0` (dry run first), `gen-notices.mjs`, release PR (`chore(release): 1.5.0`), CI, merge, off-box copy to `the backup folder: `, annotated tag v1.5.0 on the merged commit, release.yml digest, deploy, verify, `release-publish.ps1 -Full`, website version PR, then 1.6 milestone rename and tracker reconcile. 1.0.0 rollback digest sha256:5fd8727a51878447f520b9c98b8b0421c0090c6f2f8e613e90e3156bba438f95 (no schema change, no snapshot needed).

## state-2026-10-26-1-5-1-live


**1.5.1 IS LIVE.** Tag `v1.5.1` (annotated) on `6bbb29239ded95451fa925d22c3b5bfe1a16b4d3` (PR #786, merged with a merge commit as dd70b9ea so the tagged commit is the exact CI-tested PR head and an ancestor of main). Image `ghcr.io/wptk/kipple@sha256:53d7cb18f36a70f890978430da008e182d21a439299aedc817d460a451c5a7d4`; Release workflow run 40264485343 green, cosign verified (image digest, tag, SBOM) by `release-publish.ps1 -Tag v1.5.1 -Full`; GitHub Release published. Deployed with `scripts/local/deploy.ps1 -Digest ... -Yes` (the owner's word in chat: "We can ship right now. Get it deployed." and "We can do 1.5.1"): healthy, `kipple version` v1.5.1, no migration, 0 WARN/ERROR, restarts 0, Reader API answers `Error=BadAuthentication` 401, /healthz 200. A feed refresh was not confirmed (needs a login). Website version text PR kipple-website#23 merged.

**Rollback:** `deploy.ps1 -Digest sha256:407ba042e6d856756ae80b0b8778a3900effbfb2f367d4618023d32b4d127843 -Yes` (1.5.0; no schema change). The server keeps `docker-compose.yml.bak-v1.5.0`.

**What shipped:** the web follow-ups only (Reading #757/#652/#650, Stats #761/#779/#691, Feeds and Feed health #759), 23 fragments, npm group bump #739. No Go, schema or workflow change since 1.5.0. Version was 1.5.1 (not 1.6.0) at the owner's suggestion: 1.6.0 is kept for when the 1.6 milestone's remaining trackers #756, #758, #760, #762 (46 open lines) are done.

**Gates run, and skipped on purpose (owner: "cut down everything where you can"):** Opus release-gate review (reviewer-deep) of 8a6cf84a..60cd687c: no code blockers; fixes to notices, release-note wording and a README security sentence went into the release PR. CI plus Browser UAT green on 60cd687c; release PR required checks green on the tagged commit. Skipped: Go test runs and fuzz (no Go change since the gated 1.5.0), starter-feed check, `release-gates.ps1` web step (CI proved it), the by-hand screen walk, and the off-box database copy (no schema or server change, so a rollback needs no database restore).

**Gotchas:** `release-gates.ps1 -Only` must be called with `&` from PowerShell, not `pwsh -File`, or the comma list arrives as one string. A background `gh pr checks --watch` dies at its 30 min timeout while Browser UAT still runs; stop waiting on the non-required Browser UAT. The Retry-now robustness and other review leftovers are one unticked line on tracker #759. See [[state-2026-10-25-1-6-feeds]], [[state-2026-10-24-board-reset-and-1-5-release]].

## setup-restore-246-beta4


Owner decided 2026-10-06: restore is only in the setup wizard (fresh instance); in-place restore stays `kipple restore`, and Settings > Reset Kipple (#283) is its GUI twin (reset = restore of a fresh database carrying server.*/security.* settings). Rule from owner: anything the CLI does must also be possible in the GUI; no "schema version" in user-facing text (About only).

**State (2026-10-06 evening):** v0.8.0-beta.4 tagged on 3996d2b7f78dc0137e319a5e8a4baf5e2773b693 (after a flaky-test fix, #296, on top of release commit 561c172), release workflow green, image digest sha256:9510845f3a2114e25d508a32e57213b84e98e22839e7bb09f0acc1c8cfac2ec3, deployed by the local deploy helper (healthy, v0.8.0-beta.4, no migration, 0 WARN/ERROR), GitHub pre-release created via release-publish.ps1, website version PR merged, history repo updated, milestone closed. Rollback: beta.3 digest sha256:46b50bb98136aca0be20cc0d99fb92dd63ea8d9dfa3a3eb4ff9562a9efd053a3 (no schema change, so no DB restore); off-box copy the backup folder: snapshot-pre-0.8.0-beta.4.db. Owner still to do: try restore on a real fresh install, browser and phone pass.

**Follow-ups:** #289 scheduler stagger (roadmap). Store refusal messages and the export API payload still carry schema numbers (operators need them for rollback). A pending wizard marker older than 7 days is discarded.

**Lessons:** reviews of the restore code found real bugs in three rounds (reserved-name trigger passing the schema check; zip directory entry-cap bypass; deleting a "no account" database that held feeds). Reset first shipped erasing host settings (421 on the user's own domain): server settings must survive. Waiver match strings can fail when the UAT report cuts a snippet. The CI watch (`gh pr checks --watch`) can exit before the main run registers: check mergeStateStatus CLEAN.

**Why:** [[route-to-1-0-beta2-soak]] says rc.1 is bugs only, so beta.4 was the last prerelease that can take a feature.

## state-2026-10-09-opml-download-fix


PR #351 relaxes the origin guard on GET downloads (OPML, stats export, backups) so new-tab, long-press and download-manager requests work (cause: `Sec-Fetch-Site: none` or no metadata got 403 `{"error":"origin"}`). Design §7 has the download rule.

**Why:** owner 2026-10-09: OPML export must work on every platform and browser. Another Claude session is working in parallel; owner said to deploy once BOTH sessions are done and ready.

**How to apply:** merge #351 when CI is green on the exact head; do not deploy until the other session reports done (check open PRs and ask the owner if unclear). Deploy steps are in docs/maintainers/RELEASING.md; one writer on the Kipple server at a time. After deploy ask the owner to retry OPML export on the phone.

## state-2026-10-24-phase-c


Phase C complete. Merged on main: #602 #605 #634 #604 #635 #722 (Digest) #732 (New page) #745 (Feed index) #752 (Coffee break, merge a827cbbb), CI fix #711. Leftover issues #710 #737 #748 #753 (Coffee break polish), #755 (flaky greader test TestVerifierSemaphoreWaitIsBounded). Phase C ships as 1.2, no tag/release/deploy. kipple-history updated (diary/2026-10-24.md). Next: owner asks for the Phase D prompt.

**Why:** the owner split Coffee break out on 2026-10-24; it went through one deep review, one fix push, one delta review.

**How to apply:** follow [[feedback-review-loop-weekly-cap]]. Gotchas: web/uat/flows.json and eslint.config.js conflict on nearly every PR and a CONFLICTING PR gets no CI, so merge origin/main before the final push; adding a layout breaks the hard-coded count in web/uat/controls.mjs (K8); wait for CI with a background until-loop on `gh pr checks`, not watcher agents. See [[feedback-layout-naming]].

## state-2026-10-21-phase-a-done


Phase A done: #269 README governance section, #409/#410 per-target fuzz corpus keys (scripts/fuzz-cache.ps1, 12 slots in fuzz.yml, 10 MiB cap, prune keeps newest key), plus #596 (Go 1.27.3 for GO-2026-6809) and #598 (only main writes the Docker layer cache; weekly cache-cleanup.yml). Cache went 10.7 GB to 5.3 GB. See [[plan-2026-10-21-post-1-0-phases]].

**Why:** the Actions cache quota (10 GB) was full from PR-ref buildkit layers and per-commit CodeQL overlays.

**How to apply:** next is phase B (#315, #314). A manual Fuzz run (20 s per target) was started after merge to prove the restore/save/prune steps; a second run proves restore. If the shard count or target count grows past 12 per shard, raise the slots in fuzz.yml and `-Slots`. Gotchas: gitleaks scans every pushed branch (fingerprint in .gitleaksignore, avoid key-looking fixtures); `gh cache list --json 'a,b'` must be one quoted arg in PowerShell; new scripts must pass PSScriptAnalyzer (no Write-Host; ci-local.ps1 and fuzz.ps1 are exempt legacy).

## state-2026-10-25-1-6-reading


**Session 2, 2026-10-25.** Dependabot #739 merged (rebased onto #776, green). Claimed #757 (Working now + in-progress).

- **PR #777** (fix/757-reading-batch): #649 feed line dir=auto (Unread span dir=ltr so auto skips it), table running-text cells `data-kp="text"` min-width 10em, watchScrollRegions observes the body (not each region), width-only picture = cap (`data-kp-w`), figure grid `fit-content(100%)` + caption `contain: inline-size; min-width: 12em` only when width known, list header control group `flex-wrap max-w-full` (#768; design B "raise list floor" rejected), layout-walk W2 real CDP touch swipe for Search take(). Review: 1 fix + 5 nits fixed in 0e7240f0, delta review clean (2 low risks noted in PR). MERGED (a6600bb6).
- **PR #781** (fix/652-aa-sheet, worktree worktree aa-652): touch Aa panel = bottom sheet max 45dvh, no backdrop (reuses data-menu-sheet pin); tooltip + Settings section "Look" -> "Reading appearance"; "Match my device" -> "Follow system"; "Smaller" -> "Small"; list header hides Aa when `beside`. columnNeeds keeps 6 header buttons (no-article case still has Aa). MERGED (2d321e02) after a tap-above catcher layer (clear full-screen div closes on click, like SheetContent's backdrop) and a focus.mjs F3 fix.

**Gotchas:** article images are `loading="lazy"`: a UAT measuring far-down pictures must set `loading="eager"` first. UAT cleanup removes feeds whose address contains `uat-feed-` or title starts "UAT feed ": a feed with a non-UAT title must be served at a `/uat-feed-*` path. Search short layout (`data-short`) is off on the empty page at 667x375 (header 169 of 330 px); it engages with results. In Bash on the dev machine `npx` cannot find node: run npm/npx from PowerShell. Python writes CRLF on Windows: use node for scripted edits.

**State at stop:** #757 has no unticked lines and is cleared (Working now: nobody, in-progress removed). Diary merged in kipple-history #9. Nothing deployed; 1.6 not tagged. Next: other 1.6 trackers (#756, #758-#762), one writer on web/.

**More gotchas:** a new filter mutes only unread articles (filterretro.go), so a UAT flow that mutes must pick an unread article; flows share one instance in CI, so a flow that opens or changes data can break a later one (focus F3 broke when touch-menus began opening articles). Prettier is not the formatter for web/uat or AppearanceControls.tsx: it reflows whole files.

## state-2026-10-25-1-6-stats


**Session 3, 2026-10-25.** #761 claimed then cleared (Working now: nobody, in-progress removed).

- **PR #782 MERGED** (5bd6bf40): `activityBars(daily, weekStart)` in statsFormat.ts drops the empty lead of a long range and folds into calendar weeks (reader's week_start) past 120 days; title "Weekly activity"/"Daily activity" follows. UAT step T9 + fixture modes `month`/`year`. Review: 1 pass (6 findings, 5 fixed, 1 skipped), delta clean. Merged with Browser UAT red: WebKit row-name.mjs N2 "named undefined" (ariaSnapshot regex), failed twice on this PR, once on #781, main green 5/5; filed as #783 (owner said merge).
- **Still open on #761:** #691 (real 1.5x run of the Share sheet; T6 covers the header at 1.5x) and the Stats leftovers (width caps: Stats page has no max-w, ~1000px at 1280, proposed max-w-3xl; wording from #730 has no spec). Both need an owner ruling.
- Gotchas: a fresh worktree has no node_modules, `npm ci` in web/ first. Background `npm run seed` is killed at its timeout, restart per UAT run. `gh run watch` exit 0 can be read before a job fails: check `gh pr checks` directly. Long PowerShell here-strings with backticks failed to parse: write scripted edits as a node file.
- Diary: history-writer agent launched for 2026-10-25 (PR in kipple-history).

## state-2026-10-25-1-6-stats-leftovers


Session "Kipple 1.6 follow-ups" 2026-10-25/26. Owner ruled: all decisions are mine, resolve everything, no questions.

- **PR #784** (branch fix/761-stats-leftovers) covers #691 and the Stats leftovers line on tracker #761: Stats column cap
  (max-w-3xl, header and body), errors via `failed()`, one `Empty` wording (`NOTHING_IN_RANGE` in statsFormat), Share
  footer stacks via `useNarrowText(420)` (a CSS min-[420px] breakpoint ignored text size; Download image ran off the
  left edge at 1.5x on 430 px), UAT step T10 in stats-screen.mjs. #761 holds the claim until merged.
- **#783** (WebKit row-name `named undefined`): not reproduced in 9 local WebKit runs on Windows. row-name.mjs now prints
  the raw snapshot and element state on a miss. Leave #783 open; the next CI failure shows the cause. Do not add a retry.
- **#759 Feeds** is held by another live session (branch fix/759-feeds-batch); left alone.
- **#760 Settings** not started.

**Gotchas (new):**
- A page load (`page.goto`) drops `--kp-scale`; set it after each `open()` or the "1.5x" run is really 1x (screenshots show it).
- `npx prettier --write` reformats whole Stats files (+1100 lines); never run it on them, indent by hand.
- Bash heredocs collapse `\\`; use the Write tool for scripts with regexes. `sed -i 'Na\\'` does not add a blank line, use `s/$/\n/`.
- Seed: `node scripts/seed.mjs` via Start-Process hidden with KIPPLE_DEV_DATA/PORT env rebuilds web/dist when stale; a
  run_in_background seed is killed at its timeout (default 30 min, pass 7200000).
- Session started on Fable by mistake; owner switched it to Sonnet. Main thread stays Sonnet, no Opus/Fable.

**How to apply:** after #784 merges, tick the #691 and Stats-leftovers lines on #761, clear Working now and `in-progress`.

## phase5-planning-decisions


Phase 5 planning meeting held 2026-09-27 (six topics, one at a time with a recommendation each, no code/branch/
agents until closed ,  same format as the phase 4 pre-meeting). Full record in `docs/ui-decisions.md` ("Phase 5
planning meeting") and `WPTK/kipple-history` DECISIONS.md/MEETINGS.md ("Phase 5 planning decisions" / meeting 28).

**Outline:** (A) full code audit + changelog review, (B) Cloudflare Access JWT validation + passwordless login
on a branch, **in parallel** with (A) ,  accepted risk of rework if the audit flags the auth path, (C) auto-night
theme, (D) documentation run + first-time Docker setup walkthrough + backup/restore-settings guide, (E) final
go/no-go meeting.

**Scope boundary:** only work directly related to Kipple and its Docker image. In: auto-night theme. Out (stay
parked per [[parking-lot]], unchanged timing): 1.5.0/2.0.0 setup-app/single-image roadmap, design system, static
demo site, user-chosen Google Fonts.

**Stale phase-3 owner checklist:** the owner is turning off the Kipple server debug logging (`KIPPLE_LOG_LEVEL`,
`KIPPLE_LOG_GREADER_FORMS`) himself. The the Kipple server→Proton Drive backup job for Kipple's own data is explicitly **not**
being built in phase 5 (separate from an unrelated backup job; local `docker cp` snapshot stays the only
backup path). GitHub vuln-reporting toggle and `claude-md-proposed-edits.md` approval remain outstanding and
unaddressed ,  still his to close, not phase 5 work.

**Why:** the owner explicitly said he wants to be involved as little as possible in phase 5.
**How to apply:** batch phase 5 work into branches/PRs; interrupt him only for what CLAUDE.md already reserves
(deploys, Cloudflare changes, the final go/no-go) ,  not for routine build decisions in between. Use subagents
freely for the audit and doc work; keep one writer at a time on the Kipple repo per [[gh-cli-notes]]-style
process norms. See the kipple-history repo and the kipple-history repo for prior-phase context.

**Update 2026-09-27, later ,  UAT and SQA plans added.** Declined installing the third-party Claude Code skill
`mecabots/webapp-uat` (npm scope didn't match its GitHub owner `tsilverberg`; its i18n checks don't apply to
Kipple) in favor of an in-repo Playwright + axe-core script. Wrote `docs/uat-plan.md` (studied from general UAT
methodology, adapted to solo-maintainer scale: roles collapse, defect tracking goes to `kipple-history/audits/`,
sign-off is the existing go/no-go meeting; scripted/agent-driven/owner-only test suites, migration rehearsal,
restore drill, Reader API regression replay, Docker walkthrough as literal UAT) and `docs/sqa-plan.md` (mapped
to IEEE 730 sections, documents existing CI/review/release practice rather than inventing new process; flags 4
candidate additions ,  risk register, coverage visibility, docs index, public-repo issue-triage statement ,  not
yet built, pending the owner). Phase 5 outline gained (F) UAT execution and (G) SQA gaps as items feeding (E).
**Update 2026-09-27, later still ,  alpha/beta/rc/1.0 criteria decided.** Recorded in `docs/RELEASING.md`.
Alpha→beta.1 only once phase 5 fully closes (feature-complete verified, not declared). Beta→rc.1 needs every
UAT suite run once with sign-off plus a 1-week soak of real daily use with zero new P0/P1s. RC→1.0.0 needs a
second few-day soak on the final rc with zero regressions, GH private vuln reporting on, docs run + Docker
walkthrough proven, then the go/no-go meeting's approval. A soak-period regression resets that soak's clock.
