# Next steps after 2026-10-06 (beta.4 live)

State: v0.8.0-beta.4 deployed by digest, no migration (schema 16). `main` is 3996d2b. Open PRs: #287 (stats table,
schema 17, CI green, mergeable) and #277 (dev-dependency bump, CI green). Open 1.0.0 issues: #253, #248, #292, #179.

## Do now, in order (no owner input needed)

1. **Soak check.** `docker stats` on the Kipple server a few minutes and a few hours after the deploy; memory should
   settle well under 100 MB. Log WARN/ERROR count. Report one line.
2. **Review of `main` since beta.3.** `/code-review high` (Opus reviewer) over `v0.8.0-beta.3..main`. The reset PR
   (#290) merged before its high review finished. Confirm specifically: after a reset, is the instance claimable by
   anyone who can reach it? Fix every finding (one author, delta review if large).
3. **#277** merge when CI green on the exact head (one PR at a time).
4. **#253** offline bootstrap unread counts ignore queued changes. Apply the pending queue to the bootstrap counts
   the way `overlayPending` does for lists (`web/src/lib/offline.ts`). Add a Vitest case. Own branch, high review.
5. **#292** replace named reader apps and servers with generic wording (1.0.0 milestone). Docs-only; batch with any
   other wording fixes into one PR. Run `go test ./cmd/kipple` before pushing.
6. **#287** only after the owner's ruling (see decisions). Needs `/code-review high` first.
7. Update this repo and memory after each merge.

## After the soak, toward 1.0

- 1.0.0-rc.1 (bugs only): run `scripts/release-gates`, UAT on the exact commit, fuzz once. Owner-only items:
  restore on a real fresh install, phone and browser pass over wizard restore / Reset / waiting page,
  screen-reader pass, cold reader, rollback and arm64 drill, sign-off against `docs/release-checklist.md`.
- #248 docs-only audit after rc.1. #179 tracker close-out.

## Post-1.0 (do not start before 1.0 unless the owner says)

- #37 stats screen: PR1 comparison and Months range, PR2 Months chart, PR3 drill-down sheet, PR4 read rate.
  (Record table #287 is PR 4 of the sequence and already open.)
- #39 Gazette layout: PR1 planner and tests (no UI), then UI, then settings; checklist is in `gazette-layout.md`.
- #289 spread feed fetches after restore. #286 UI audit. #269 maintenance/governance doc. #247, #35, #34.

## Housekeeping

- Local branches and worktrees from finished PRs (feat-246, feat-283, fix-b4, fix-flake, fix-uat, sidebar-font,
  rel083, rel084, gate-final*, ops) and `wip/stale-checkout-edits`: owner removes them.
- Untracked `docs/plan.md`, `docs/HANDOFF-PHASE3.md`, `index.html` in the shared checkout are old drafts naming
  reader apps and a host; do not commit. Move or delete.
- History repo: README still tells contributors to use host labels; older `research/` files hold ~2000 scrub hits.

## Update 2026-10-07 (late)

Merged to main since beta.4 (unreleased): Gazette planner (#299), reset notice (#300), offline in-session badges
(#297, #253 stays open for the relaunch half), stats comparison and Months (#301), vitest worker cap (#303),
generic wording (#298), feed_daily_new schema 17 (#287). Open: #302 restore-upload binding (security; beta.5
must not ship without it). Owner rulings: stats and Gazette go in the next beta or 0.9.0; history scrub done.
Open owner decisions: partial-day rule for stats tiles, #253 relaunch half, one-time setup secret.
