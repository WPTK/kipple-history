# Git hygiene pass, 2026-09-28 (overnight)

The second pass of this kind; the first is [git-hygiene-2026-09-27.md](git-hygiene-2026-09-27.md). It was one item on
the owner's fixed overnight list (see [overnight-2026-09-28.md](overnight-2026-09-28.md)), run against the current
state of `WPTK/Kipple` rather than the phase 2 era checklist. Source: the agent's memory note for the pass and the
session transcript.

Rule used for every deletion: the branch was first proved merged. Either its tip had an empty diff against
`origin/main` (squash-merged) or `git log origin/main..<branch>` was empty.

## Done (unattended)

- Removed 10 stale agent worktrees under `.claude/worktrees/` left by finished phase 5 subagent sessions, and deleted
  their local branches and the `worktree-agent-*` bookkeeping branches. The 2026-09-27 pass had left two locked
  agent worktrees for the owner; whether these were among the ten is not recorded.
- Deleted local and remote `phase5-uat-suite1` (PR #46, long merged, remote branch had lingered), and local
  `phase5-uat-suite2-fixes` and `phase5-uat-codeql-fix` (PRs #45 and #51), and local
  `feed-health-bulk-and-manage-feed` (PR #66, merged the same night).
- `git worktree prune`, `git gc --prune=now`. No stashes.

## Checked, nothing to change

- Local and remote branches match: `main` plus the open pull request branches; no orphans on either side.
- Tags `v0.1.0` through `v0.3.0-beta.1` all present and annotated (spot check of four with `git cat-file -t`). No
  gaps.
- No Dependabot pull requests open (the 2026-09-27 pass had listed seven; how they were closed is not recorded here).
- The recurring `THIRD_PARTY_NOTICES.md` line-ending diff was investigated: `.gitattributes` already has
  `* text=auto eol=lf`, and `git add --renormalize` produced an empty diff, so the committed content is fine. It is
  a Windows checkout artifact on the dev machine. Nothing to fix in the repository.
- Repository settings observed, not changed: squash, merge-commit and rebase merges all still allowed (the question
  the first pass left open for the owner is still open); delete-branch-on-merge on (which is why most branches clean
  up themselves); auto-merge off; branch protection unavailable on the free plan; Actions allowed for all actions with
  SHA pinning not required (a possible hardening item for a public repository, not urgent).

## Found during the pass

- Merging #66 first put #63, #64 and #65 into conflict on `CHANGELOG.md` (two also on `f3.test.tsx` and
  `AppShell.tsx`). Main was merged into each branch, the conflicts resolved by hand, the full suites and typecheck
  run, and all three returned to mergeable. This is the cost that led to the changelog fragment tooling on 2026-09-29
  (PR #85).
- Not a hygiene finding but discovered on the same night: the history repository itself carried real hostnames and a
  local path, see the overnight record.

## Status

Complete. Nothing from the branch, tag or pull request side was left for the owner. The only open item is the
merge-method choice, unchanged from 2026-09-27.
