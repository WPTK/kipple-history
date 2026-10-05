# Git hygiene pass, 2026-09-27

Scope: WPTK/Kipple (public), WPTK/kipple-history (private), WPTK/kipple-website (public), plus scratch
clones on the dev machine. Hands off: the Kipple working tree, `phase4-stats-export`, `release-0.3.0-alpha.5`,
`main`. Personal-data scans report counts, commit hashes and paths only.

State changed during the pass (not by this pass): PR #20 (`release-0.3.0-alpha.5`) was merged into Kipple
`main` (now `c7b3c10`) and its remote branch deleted; the `kipple-rel5` worktree entry was pruned; two new
detached worktrees appeared (`%TEMP%\kipple-node26`, `%TEMP%\kipple-ts7`, both at `c7b3c10`, presumably
someone testing Dependabot PRs #1 and #7); `phase4-stats-export` gained local commit `e58459c`
(alpha.6 candidate, not pushed; there is no remote branch of that name).

## Kipple (public)

### DONE
- `git fetch --prune`: removed 13 stale remote-tracking refs (docs-ci-on, favicon-finder, fix-flaky-abort-test,
  fix-ot, fixes-alpha2, lossless-webp, phase3-pwa, phase4-stats-screen, phase4-stats-sender,
  release-0.3.0-alpha.2/.3/.4/.5; all already deleted on GitHub by delete-on-merge).
- Deleted 12 fully merged remote branches via the API (each tip verified an ancestor of `origin/main`
  immediately before delete; none had an open PR; all returned 204): fix-auth 71ba30a, fix-fetch 9baeea4,
  fix-filters 0608f7c, fix-images e19f9ad, fix-ingest 655e207, fix-ops 8175433, fix-store 592f733,
  fix-web ed56228, fix-webapi ed17975, fix2-auth d5b5b89, fix2-store f879a33, fix2-web dbf5e14.
  Remote now holds only `main` and the 7 Dependabot branches.
- Deleted local merged branches: phase4-stats-screen (cdf356e), phase4-stats-sender (5a94842),
  release-0.3.0-alpha.4 (c4293e0).
- Full-history gitleaks 8.30.1 (the pinned CI image, repo `.gitleaks.toml` + `.gitleaksignore`, all refs incl.
  local branches): no leaks.

### FOUND, NOT CHANGED
- Local `main` is 7 behind `origin/main` (hands off; a plain `git checkout main && git pull --ff-only` later).
- Local `release-0.3.0-alpha.5` (5b0db7d) is merged via PR #20 and its remote is gone: delete locally once the
  release work is finished (`git branch -d release-0.3.0-alpha.5`).
- Local `fix-ops` and `fix2-auth` are merged and remote-gone, but each is checked out in a **locked** agent
  worktree under `.claude/worktrees/` (agent-a23b6c9cbe657f290, agent-ab279fd4e58e7bb2a; both clean; lock
  owner PID is a live claude.exe). Proposal below.
- Tags: v0.1.0 through v0.3.0-alpha.4 (10), all annotated, all pushed, no local-only tags, remote peeled
  commits match. No `v0.3.0-alpha.5` tag yet: per policy it is made at deploy time on the deployed commit.
- No stashes. No submodules. `git fsck` clean (416 unreachable objects from deleted branches; normal).
  Pack 3.7 MiB; largest blobs are `docs/design.md` revisions (~380 KB each). No binaries of note.
  `git gc` skipped because another session is actively working in this repo; run it any time later.
- Line endings: `.gitattributes` exists (`* text=auto eol=lf`, binaries marked). Index is LF throughout.
  `web/src/App.tsx` and `web/src/shell/AppShell.tsx` are CRLF in the working tree only (editor side effect);
  they normalise on the next `git add`. No change needed.
- Ignore rules: `web/tsconfig.tsbuildinfo` is ignored by `web/.gitignore` (`*.tsbuildinfo`). `docs/HANDOFF-PHASE4.md`
  and `docs/parking-lot.md` are ignored only through `.git/info/exclude` (per clone), while
  `docs/HANDOFF-PHASE3.md` and `docs/plan.md` are in `.gitignore`. Suggested PR change, `.gitignore`, under
  "Internal session notes": add `docs/HANDOFF-PHASE4.md` and `docs/parking-lot.md` (or `docs/HANDOFF-*.md`), so a
  fresh clone cannot commit them by accident.
- Identity: 489 commits author/committer `WPTK <GitHub no-reply address>`; 3 with committer
  GitHub; 13 PR merge commits made in the web UI carry the GitHub profile display name (initials only) as author;
  7 Dependabot. No personal email anywhere.
- Messages: every non-merge commit is Conventional Commits. Trailers: Sonnet 5 (434), Opus 5.5 1M (32),
  Opus 5.5 (1), Fable 5.1 (2); inconsistent model strings are cosmetic.
- Personal-data scan (full history, commit messages, tag messages, PR titles/bodies, comments, releases):
  0 hits for the owner's name, surname, login, personal email, home/deploy hostnames, LAN subnet, street/town,
  Windows user paths. The only pattern hits are third-party author emails in `THIRD_PARTY_NOTICES.md` and
  generic RFC 1918 addresses in 5 test files (fetch/imgproxy/opml/api SSRF tests). Clean.
- Open PRs: 7 Dependabot (#1 node 22->26-alpine, #2 build-push-action 7.4.0, #3 setup-go 7.0.0,
  #4 setup-buildx 4.4.1, #5 checkout 7.0.1, #6 setup-node 7.0.0: CI green; #7 typescript 7.0.2: CI failing).
  Recommendation: merge #2-#6 after a rebase on current main; hold #1 (node 26 is not LTS until late October;
  stay on an even LTS for the build stage, or add a Dependabot `ignore` for node majors); close #7 or keep it
  open as a tracker until the TypeScript 7 break is fixed. Someone appears to be testing #1/#7 already.
- Dependabot config covers gomod, npm (/web), github-actions, docker; weekly, minor/patch grouped. Sound.

### GitHub settings (read-only)
- Default `main`; merge, squash and rebase all allowed; delete-branch-on-merge ON; auto-merge off.
- Vulnerability alerts ON, Dependabot security updates ON, secret scanning ON, push protection ON,
  non-provider patterns and validity checks off. 0 open Dependabot/secret-scanning alerts; no code scanning.
- **Private vulnerability reporting is OFF**, but `SECURITY.md` tells reporters to use it. Mismatch (already on
  the owner's list).
- Actions: enabled, all actions allowed, SHA pinning not required, default GITHUB_TOKEN read-only, cannot
  approve PRs. No secrets, environments, webhooks or deploy keys.
- Branch protection / rulesets: none configured; available (public repo on the free plan).
- Description and topics set; homepage empty (could be the website URL). README, LICENSE (BlueOak-1.0.0),
  SECURITY.md, PR template present. Issues on, wiki/projects off. No security advisories.

## kipple-history (private)

### DONE
- Commit `147c700` `chore: add .gitignore for local Claude settings and OS files`, pushed to `main`
  (repo is updated by direct pushes; no PRs ever).
- `git gc` (loose objects packed, 789 KiB); `git fsck` clean.

### FOUND, NOT CHANGED
- No `.gitattributes`. `MILESTONES.md` and `plans/HANDOFF-PHASE3.md` are stored with CRLF in the index; the
  other 62 files are LF. Adding `* text=auto eol=lf` + `git add --renormalize .` rewrites exactly those two
  files (line endings only; tested in a scratch clone). Needs approval (renormalisation).
- Identity: all 28 commits authored and committed as the initials-only display name with the noreply
  address (the local `user.name` in this clone), unlike Kipple/website which use `WPTK`. Harmless but
  inconsistent; set `git config user.name WPTK` in this clone if uniformity is wanted.
- Messages: 20 of 28 use repo-specific prefixes (`diary:`, `history:`, `plans:`, `audits:`), not Conventional
  Commits types. Fine for a journal repo; optionally adopt `docs(diary):` etc. going forward.
  8 of 28 commits lack a Co-Authored-By trailer.
- gitleaks (default rules): 1 finding, false positive: `generic-api-key` in `research/greader-miniflux.md:63`,
  commit `dca7d518`, a sample token quoted from a public upstream issue for a test user. Nothing to rotate.
- Personal data (expected, repo is private): owner's first name in 44 files; home-server hostname in 24 files;
  deploy-host hostname in 36 files; LAN addresses in 12 files; Windows user-profile paths in 5 files (4 of them
  containing the Windows login name); 1 file names another home service. No surname, no personal email, no
  street or town. **Must be scrubbed (or history rewritten) before this repo is ever made public.**
- **The public website links to this private repository** (`index.html` footer "History" link and
  `design-system/DESIGN-SYSTEM.md`); visitors get a 404. Either remove the link or plan a scrubbed public copy.
- Settings: private; branch protection and rulesets unavailable (need Pro or public). Dependabot alerts,
  secret scanning off (not available/needed for a docs repo). delete-branch-on-merge off (no branches used).
  No README gaps (README present); no LICENSE (fine for private).

## kipple-website (public, GitHub Pages)

### DONE
- Commit `140791e` `chore: add .gitattributes (LF for text, binary fonts and images)`, pushed to `main`
  (repo is updated by direct pushes; no PRs ever). The index was already LF, so `--renormalize` changed nothing.
- `git gc`; the only `fsck` complaint (missing empty tree `4b825dc` referenced from a rebase reflog entry) is gone.

### FOUND, NOT CHANGED
- **Pages HTTPS is not enforced** (`https_enforced: false`, custom domain, legacy build from `main` `/`).
  Recommend turning on "Enforce HTTPS" in Settings > Pages (settings change: owner).
- No workflows, no package files, no analytics, trackers, tokens or third-party requests; fonts self-hosted.
  gitleaks full history: clean. Personal-data scan: 0 hits in content, history and messages.
- Two GitHub-web commits (`5da23b0` Initial commit, `e489ed6` Create CNAME) carry the initials-only display
  name as author and are not Conventional Commits; the "copy:" prefix (6 commits) is a local convention.
  The rest are `WPTK`, Conventional, with trailers. No action.
- Local clone has `core.autocrlf=true` set at repo level (origin of the CRLF working files); now overridden
  by `.gitattributes`. Optional: `git config --unset core.autocrlf` in `C:\kipple-website`.
- Fonts are OFL-1.1: the OFL asks that the license text travel with redistributed font files. Add the OFL
  text(s) under `fonts/` (e.g. `fonts/OFL.txt` with the three families' copyright lines).
- Content staleness: the status line still says `v0.3.0-alpha.1 is the first public build`.
- `.claude/launch.json` is tracked (a local preview server on 127.0.0.1:7099; harmless).
- Settings: merge/squash/rebase all allowed; delete-branch-on-merge off; wiki and projects on (unused;
  consider turning off); issues on; description is informal; topics empty; homepage empty (set to the site URL).
  Secret scanning and push protection ON; Dependabot security updates off (nothing to update). No branch
  protection configured (available). LICENSE (Unlicense), README, CNAME present; no SECURITY.md (not needed).

## Scratch directories on the dev machine

| Dir | What it is | State | Unique content? | Proposal |
|---|---|---|---|---|
| `C:\kipple-pub` | Working clone of `C:\kipple-scrub`, main `bb62035` (1 commit ahead of its origin) | clean, 233 MB (222 MB node_modules) | `bb62035` is a superseded draft of the first public commit (differs from published `7497c4c` in 16 files, different parent chain) | delete |
| `C:\kipple-pub2` | Same, main `f6cd385` | clean, 233 MB | superseded draft, 15 files differ | delete |
| `C:\kipple-pub3` | Repo with no remote, main at `7497c4c` | clean, 233 MB | none (7497c4c is on GitHub main) | delete |
| `C:\kipple-pub-bare` | Bare repo, main `7497c4c` | 3.5 MB | none | delete |
| `C:\kipple-scrub` | Bare repo, main `bdc770e`, 361 commits: the scrubbed history | 3.8 MB | none (`bdc770e` is an ancestor of public `main`) | delete |
| `C:\kipple-verify` | Clone of GitHub Kipple at `7497c4c` | clean, 7.7 MB | none | delete |
| `C:\kipple-review` | Not a repo: 13 empty directories (r1..r8, w1..w5 review slots) | empty | none | delete |
| `C:\kipple-wt` | Not a repo: empty directory | empty | none | delete |

All personal-data pattern counts in the scratch repos match the scrubbed public history (no hostnames or
names), so deletion is housekeeping (~705 MB), not a privacy fix. The original unscrubbed history lives in the
private GitHub repo `WPTK/kipple-archive` (outside this pass's scope; not audited).

## NEEDS THE OWNER
1. Enable private vulnerability reporting on Kipple (SECURITY.md already points to it).
2. Enforce HTTPS on the website's Pages settings.
3. Website footer and design doc link to the private kipple-history repo: remove the link or publish a
   scrubbed copy.
4. Delete the 8 scratch directories above (none holds anything not on GitHub or superseded).
5. Remove the two locked agent worktrees once their session is done:
   `git worktree unlock <path>; git worktree remove <path>` for both `.claude/worktrees/agent-*`, then
   `git branch -d fix-ops fix2-auth`. Also `git branch -d release-0.3.0-alpha.5` and fast-forward local `main`.
   The `%TEMP%\kipple-node26` / `kipple-ts7` worktrees belong to whoever made them.
6. kipple-history: approve `.gitattributes` + renormalisation of the 2 CRLF files.
7. Dependabot triage: merge #2-#6, hold #1 (node 26), fix or close #7 (TypeScript 7 fails CI).
8. Optional settings: pick one merge method per repo (Kipple uses merge commits for PRs today), branch
   protection or a ruleset on Kipple `main` (require CI, block force-push/deletion), website homepage/topics,
   website wiki/projects off, Kipple homepage field.
9. Kipple `.gitignore`: add `docs/HANDOFF-PHASE4.md` and `docs/parking-lot.md` in the next PR.
10. No history rewrites are needed: no secrets or personal data found in either public repo.

## RISKS
- Whoever tests Dependabot PRs in `%TEMP%\kipple-node26` / `kipple-ts7` shares the object store with
  `C:\kipple`; avoid `git gc --prune=now` there until those worktrees are removed.
- kipple-history is the only place holding hostnames, LAN addresses and the owner's first name; flipping it to
  public without a scrub would leak them.
- Deleting `C:\kipple-scrub` removes the local bridge between the archive and the public history; the public
  history itself contains all of it, so nothing is lost.

## Status update (added 2026-09-29, after the fact)

The follow-up pass on 2026-09-28 ([git-hygiene-2026-09-28.md](git-hygiene-2026-09-28.md)) found no Dependabot pull
requests open, all tags present, the stale worktrees and merged branches removed, and repository settings unchanged.
Item 1 (private vulnerability reporting) is recorded as turned on in `docs/RELEASING.md` as of 2026-09-27. The
website's link to the history repository (item 3) is how the history repository's exposure was found; see
[overnight-2026-09-28.md](overnight-2026-09-28.md). The status of items 2, 4, 6, 8 and 9 is not recorded in the
sources used for this update.
