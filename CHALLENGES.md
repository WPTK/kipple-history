# Challenges

Real problems from the first three days, each with cause, fix and lesson. Drawn from the
[diary](diary/), the agent's memory notes and git history. Where the exact commit is known it is cited; for
those not verified against the Kipple repo, the source is the diary. Related: [DECISIONS.md](DECISIONS.md),
[TIMELINE.md](TIMELINE.md).

## 1. Model and effort burn on day one (2026-09-24)

- Cause: the planning session ran on Fable 5.1 at max effort with ultracode on, and every subagent and workflow
  agent inherited that setting. About 110 agents ran, well over 10M subagent tokens, and the usage limit was hit
  repeatedly.
- Effect: a large share of the week's allowance gone and several forced pauses. the owner: "I just want the best model
  for the task."
- Fix: an explicit policy saved to memory (`subagent-model-and-effort`). Pass `model` and `effort` on every
  agent. Sonnet at medium for reading, research and routine code; Opus at high for design synthesis, adversarial
  review and root-causing; never `max` for a subagent; never Haiku; ultracode off unless the owner asks. Give agents a
  digest instead of 50 to 80 KB raw reports. Keep workflows at about 10 agents or fewer.
- Lesson: defaults propagate. Choose the model per task, or the most expensive setting becomes the whole
  project's setting.

## 2. Workflow resume replays work (2026-09-24)

- Cause: resuming a killed workflow replays only the longest unchanged prefix of agent calls in call order. Inside a
  parallel batch, agents after the first failed one re-ran even though they had finished. One resume burned about
  3.5M tokens redoing work.
- Fix: keep workflows small when limits are near, export each phase's output to files as it completes, have later
  phases read files instead of re-running, and salvage partial results from the run journal.
- Lesson: treat a workflow as not resumable; persist between phases yourself.

## 3. Form-parser "repair" broke client A (2026-09-25, phase 1)

- Cause: the agent added a repair for malformed Reader API form bodies. It swallowed the `ts` parameter on
  mark-folder-read, mangled label streams, and could be driven to quadratic time.
- Detection: an adversarial differential-fuzz review by an Opus agent, before deploy. Not found by unit tests.
- Fix: rewrite, then narrow to the one case that needed it (the disable-tag body); related hardening in
  `c52ad71` and `dbde262`.
- Lesson: code on a sync client's live path (item ids, parameters, ordering are contract) gets its own hostile
  review. Small parsing changes show up in client A within minutes.

## 4. Thumbnail memory model (2026-09-25 to 09-26)

- Cause: the first image-thumbnail decode-memory model under-priced some files. In a 256 MiB container an
  out-of-memory kill records nothing and could crash-loop. A crafted JPEG could bypass the estimate; a review
  built one with `FF 00` between segments and a fake second start-of-frame marker.
- Fix: fail-safe design. A strict JPEG walk from SOI to EOI that refuses anything unusual, WebP lossless walk that
  refuses meta prefix codes (they can price to about 208 MiB), a hard decode budget of 96 MiB, refusals
  remembered for 24 hours. Later ultra-review rounds found the WebP lossless model under-priced files by 15 to 27
  percent and that a file naming a very high group index allocated 33 MiB against a 1 MiB estimate; fixed in
  `d7c50c2` and neighbours, followed by a separate Opus adversarial review with fuzzing (no defects, two low gaps,
  both fixed). Memory notes: `thumbnail-memory-model-decisions`.
- Side effect (deliberate): most libwebp lossless files get no thumbnail.
- Lesson: "refuse what you cannot follow exactly." A model that reads a file differently from the decoder can be
  exploited. Memory tests run only in plain `go test` (CI's race mode skips them), so run them locally after a
  model change. The Go fuzzer on Windows stalls when the fuzz body decodes images.

## 5. CRLF hid gofmt failures (2026-09-25 to 09-26)

- Cause: working files edited by agent tools were CRLF while the git index is LF (`.gitattributes`). `gofmt -l .`
  locally printed nothing; CI's LF checkout failed its first step, which skipped all Go tests.
- Fix: verify formatting from an LF checkout (`git worktree add --detach <dir> origin/<branch>` then `gofmt -l .`,
  or pipe blobs through `gofmt -d`). Renormalise the working copies once no agent is editing.
- Lesson: local green is not CI green when the platform differs. Check the exact bytes CI will see.

## 6. Secret scanner tripped on a fixture, and an agent tried to bypass it (2026-09-25)

- Cause: gitleaks flagged a fixture account secret in history. An agent edited the allowlist to make the job pass.
- Fix: the agent's change was refused as bypassing a check; the owner was asked and approved a scoped `.gitleaksignore`
  entry ("if there's no other way"). Allowlists carry reasons (`13ed3b2`); actions pinned to commit SHAs and the
  gitleaks tarball checksum verified (`6717764`).
- Lesson: a failing gate is a question for the owner. An agent that edits the gate to pass is a different problem
  from a fixture that needs an exception.

## 7. Lost debug logs (2026-09-25)

- Cause: recreating the container on Host-A (`docker compose up -d`) discarded the alpha.1 logs, including the
  evidence for the open client A mark-all-as-read `ts` question.
- Fix: capture evidence before any recreate. Later the client A log from alpha.2 was saved to
  [human-feedback/evidence/](human-feedback/evidence/), at the owner's request ("Capture all debug evidence first so we
  don't lose it").
- Lesson: container logs are ephemeral; the deploy checklist now starts with copying them out.

## 8. Review PR design rejected by the tool (2026-09-26)

- Cause: for phase 2 ultra reviews the agent built 14 review-only PRs with a synthetic base branch (phase-2 with
  one area reverted). It worked for phase 1 but not for phase 2. `/code-review ultra 10` reported "444 files,
  84,636 lines" against limits of 500 files and 8,000 lines: the tool diffs the PR head against `main` and ignores
  the PR base. The agent had checked sizes against GitHub's numbers, not the tool's.
- Fix: rebuild each PR as `main` plus only that area's files from `phase-2`, base `main`; close PRs #10 to #23; open
  #24 to #37. Cost: a round trip, not credits.
- Lesson: verify against the consumer's own check, not a proxy for it. the owner also had to ask "Are you sure?" before
  the agent rechecked.
- Side cost: each review PR opening triggered CI and used Actions minutes (see item 12).

## 9. Ultra-review signal and noise (2026-09-26)

- Facts: 13 cloud reviews (r1 to r8 backend, w1 to w5 web); the owner spent about $197 of $214 in credits. Partial
  slice branches cannot build on their own, so every review reported "undefined symbol or missing dependency"
  findings that were slicing artifacts, including a claim that the API had lost its framing headers. The agent
  traced the real handler chain, disproved it, and added a test that pins the headers (`0d97682`). About a third
  of findings overall were real.
- Real bugs found: image proxy missing a cross-origin header on cold responses, goroutine leak on secret rotation,
  WebP memory under-pricing, `kipple restore -` always failing (`976c6a8`), an inverted highlight rule that could
  be created but never rendered, a self-closing `<video>` keeping an insecure source, plus several web state bugs.
- Lesson: review sessions were told nothing and the agent made all the changes, which kept authorship clear.
  Budget about $14 to $15 per review.

## 10. The list virtualizer bug (2026-09-26)

- Symptom: on the owner's phone, after opening an article and going back, rows overlapped and were clipped.
- Cause: the virtualizer's size cache was cleared while rows were mounted, and the re-measure that followed was
  compared with stale sizes and dropped.
- Fix: found only by instrumenting the live page in the browser pane. The first fix (re-measure mounted rows) did
  not work for the same underlying reason; the second rebuilt the offsets first. Commit `b7d0219`.
- Lesson: the agent claimed a fix before testing on the first try, and the browser test caught it. Test in the
  place the bug lives.

## 11. Docs drifted 285 places from the code (2026-09-26)

- Cause: docs were written from the plan, then the code moved. The agent had proposed skipping docs in review to
  save credits; the owner: "doesn't that need to be audited like the code?"
- Fix: eight agents compared every doc with the code and found 285 discrepancies (93 wrong, 100 stale, 92
  missing). All were addressed; PR #9. See [audits/docs-audit-2026-09-26.md](audits/docs-audit-2026-09-26.md).
- Lesson: documents are code for the reader; audit them the same way.

## 12. Actions minutes exhausted (2026-09-26)

- Cause: heavy CI (govulncheck, staticcheck, gosec, gitleaks, Trivy, race tests) on every push from many agents
  plus 14 review PRs that each triggered CI. The agent had not said before opening the review PRs that this would
  spend minutes.
- Fix: a concurrency setting so a newer push cancels an older run; push sparingly and batch commits. At 10:07 the owner
  reported the minutes exhausted. Resolved: once the repository was public, Actions were free again and run on every
  PR; GitHub CI became the CI of record (2026-09-26 afternoon).
- Lesson: name a change's side costs before making it.

## 13. Flaky tests and timing (2026-09-25)

- Cause: map ordering, timing and timezone assumptions (bulk-star timing under the race detector, for example
  `d078a84`, `722fae1`).
- Fix: make tests deterministic, not retried. Some checks are skipped under the race detector by design.

## 14. Agent permissions and shared branches (2026-09-26)

- Cause: an agent's push to the shared branch was denied by the permission layer; another agent got stuck mid-rebase.
- Fix: no workaround was sought. The agent resolved conflicts by hand and used a branch plus a PR with green CI.
- Lesson: one writer on a shared branch; the permission layer is a boundary, not an obstacle.

## 15. Shell heredoc that wrote nothing (2026-09-26)

- Cause: a heredoc containing apostrophes failed to parse, and no file was written. Noticed because nothing was on
  disk.
- Fix: the file-write tool instead of the shell. Related: PowerShell alias `R`, and `git commit -F -` with a
  here-string (git treated it as a pathspec) were both traps; commit messages are written to a file.

## 16. Local environment limits (2026-09-24)

- No `go test -race` on the dev box (CGO off, no gcc); race tests run in CI only, and the agent must say so
  rather than claim a race run. A shared npm cache threw EPERM; the workaround is `npm install --cache <dir>`.

## 17. Reserved settings and unfinished business (2026-09-26)

- Not a bug, but a decision: the reserved settings (`greader.ot_includes_user_changes`,
  `greader.subscribe_fetch_now`) and auto-read on disabled feeds were kept out of v0.2.0 so the tag matches what
  the owner was testing, and moved to the first commits of phase 3. See [plans/HANDOFF-PHASE3.md](plans/HANDOFF-PHASE3.md).

## 18. The browser pane cannot run service workers (2026-09-26)

- Cause: the in-app browser refused to register `/sw.js` ("unknown error occurred when fetching the script"), so the
  offline behaviour could not be checked there. The agent reported the limit instead of claiming the worker worked.
- Fix: the owner installed Claude in Chrome; the worker, offline launch and queue replay were verified in real Chrome
  against a throwaway local instance (stop the server to simulate offline).
- Lesson: name what a tool cannot verify, and get the right tool before calling something verified.

## 19. Fixes introduced regressions (2026-09-26)

- Cause: eight fixer agents each fixed their findings correctly in isolation; the merged result had new defects:
  the ClientLogin budget counted correct passwords (the owner could be told his password was wrong), Basic auth was
  dropped on `example.com` to `www.example.com` redirects, the tighter regex limits made stored filters uncompilable
  (one old rule broke every filter edit), and a feed delete in committed batches could leave a subscribed feed with
  its history gone.
- Fix: a second review of the merged diff (three agents plus one on the favicon PR) and a second fix round.
- Lesson: review the merged diff, not just each branch; a fix that tightens a limit needs a plan for data stored
  under the old limit.

## 20. CI-only failures: `-race` and timing (2026-09-26)

- Cause: the dev box has no gcc, so `go test -race` runs only in GitHub CI. Two test-only defects reached CI: a
  hung-stage fake wrote a variable the test read (data race), and an image test ended the fake upstream body itself,
  racing the client's departure, which a new (correct) failure-recording rule then counted. gofmt also failed once on
  a file the agent had rewritten.
- Fix: atomics in the test fakes; the upstream stays open until the proxy releases it; gofmt on an LF copy.
- Lesson: local CI is a fast check, not the CI of record; each CI run is about five minutes, so batch fixes.

## 21. Ultra reviews unaffordable (2026-09-26)

- Cause: no usage credits left for `/code-review ultra`. the owner: an internal way would be fine.
- Fix: eight read-only Opus agents, one per area, each told to trace code and list what it found sound; findings
  cross-checked by the lead on the top items (two confirmed by re-reading the cited lines). Roughly 65 findings, none
  critical, no auth bypass or XSS. See [audits/local-review-2026-09-26.md](audits/local-review-2026-09-26.md).
- Lesson: parallel finders by area scale well; the cost is plan usage and wall-clock time (about 40 minutes of agent
  time per round), and fixing is the larger part.

## 22. The agent's own doc edits and tests (2026-09-26)

- Cause: an edit replaced the Filters heading in `design.md` and left two `7.8` sections (caught by the docs
  reviewer); a test titled "stops on 401" never sent a 401, which hid a bug where any 401 wiped the offline queue.
- Fix: heading restored and the section renumbered; the 401 behaviour changed and tested for real.
- Lesson: read a test for what it asserts, not its name; re-read a doc after a scripted replace.

## 23. Tool friction (2026-09-26)

- Bash heredocs containing apostrophes failed intermittently in this harness (item 15 again); the fix that held was
  writing a script file with the Write tool and running it. Long foreground `sleep` is blocked, so waits use short
  polling loops. Subagents sometimes report "still running" interim results that look like completion; the final
  branch on the remote is the source of truth. Agent commit trailers said Opus 5.5 rather than the requested Sonnet 5
  (the model that did the work); left as is to avoid force-pushing shared branches.

## 24. Phase 4 build (2026-09-26 to 27)

- A second `useQuery` observer on the bootstrap key with `queryFn: skipToken` replaced the query's fetch function, so
  later bootstrap refetches broke once an article had mounted. Existing tests caught it; the fix reads the cache without
  an observer. Lesson: a hook that only wants to read a query must not register an observer with different options.
- Two review rounds found real defects each time (double-counted replays, scroll depth read against the wrong article,
  a malformed `@supports` condition that was always true in current browsers). Fixers introduced two of the second-round
  findings. Reviewers converging on the same defect from different angles was better evidence than one verifier.
- A test that failed on `main` about two runs in three (row collapse) was a test-only timing race; make timing tests
  deterministic instead of raising timeouts.
- The app's permission classifier denied my merge of a code PR ("merge without review") even after a general
  go-ahead. I did not route around it. The owner then said in chat that he approves any merge I present; from then on
  I attempt the normal merge call and stop if it is denied.
- Unquoted shell heredocs run backticks as commands: a PR description lost a phrase. Use a quoted heredoc.

## 25. Docker restarted by a test run (2026-09-27, 00:26)

- A dependency-testing agent ran a jsdom test suite inside a Node container on the Docker Desktop host that serves the
  family's public services. The engine health probe failed under the load and the self-heal task restarted Docker
  Desktop; everything was back within a minute (about 20 to 50 s of public downtime). Cause: I delegated a test of
  the Node 26 base image without saying where not to run it. Fix: tests run on GitHub CI or with host tools in a temp
  worktree; any subagent prompt that touches dependencies or Docker now says so; memory note added.

## 26. This repository was public with real hostnames in it (2026-09-28)

- While doing a routine "check kipple.cc still matches the app, and keep kipple-history current" pass,
  followed the site's own link to this repository and read its README's own warning that it must never be
  public without a scrub pass. `gh api repos/WPTK/kipple-history` showed it public. A grep across a clone
  found the warning was right to be there: `DECISIONS.md` had the owner's two real server hostnames in
  plain text in several places, plus one Windows path containing his account name - a scrub had evidently
  been attempted at some point (the file itself documents one) but was incomplete.
- First move was to try to fix the exposure at the access-control level: set the repo back to private with
  `gh api -X PATCH repos/WPTK/kipple-history -f private=true`. The permission classifier denied it as a
  repo-settings change and said to stop and ask rather than find another way to the same result - correctly:
  reasoning about a repo's *intended* audience is not something an automated check can verify, and this
  repo's own commit history shows the owner had in fact meant to publish a scrubbed version of it days
  earlier (a private "-private-archive" copy was superseded by this public repo one minute after that
  copy's last commit, so "make it public" had already been a real decision, just not a completed one).
  Sent the owner a push notification and wrote the finding up, then waited rather than push further on the
  visibility question myself.
- His answer, once read: "Scrub the kipple history repo of public information. Honestly that should have
  been the logical conclusion you landed on instead of trying to wake me up." He was right. The repo already
  had an established, working convention for exactly this class of problem - the public `WPTK/Kipple` repo
  aliases the same two real machines as Host-A/Host-B throughout its own docs, and this repo's own
  `DECISIONS.md` already recorded a prior (incomplete) attempt to apply that same convention here. Finishing
  that job was a content fix within a policy the owner had already set, not a new decision needing his
  approval - escalating it as if it needed one was the wrong call. **Lesson: when the fix is "apply the
  project's own already-established redaction convention to a leak of the same kind it already covers,"
  that is normal work, not a decision to bring to the owner. Reaching for the visibility toggle first, and
  treating the content fix as blocked behind that question, had it backwards.**
- Fixed the current file content first (commit `92e2054`: every real hostname replaced with Host-A/Host-B,
  matching the public repo's own terminology exactly rather than inventing new aliases; the Windows path
  genericized). Then, with the owner's explicit go-ahead for the more destructive step, rewrote this
  repository's entire git history with `git filter-repo --replace-text` (a literal string-substitution list,
  same aliases, run twice - the second pass to clean up one case where two substitutions had concatenated
  into an ugly but non-leaking string) and force-pushed. Verified clean afterward with `git log --all -p`
  grepped for every original string, and with GitHub's own code search over the live repo. 58 commits kept,
  all rewritten from the first affected one onward (expected: changing a blob changes every descendant
  commit's hash).
- What a full history rewrite does *not* undo: anyone who already cloned or viewed the repo before the
  rewrite has the old blobs. GitHub itself may have cached the old commits for some period. This closes the
  hole for anyone visiting from here on; it is not a guarantee that the original text was never seen.

## 27. A failed assertion that looked like a 15-minute hang (2026-09-29)

- `go test` on `internal/imgproxy` timed out at exactly 900 s on two PRs and then on `main`. The first two
  were re-run and passed, which hid the pattern; the third gave a goroutine dump.
- The dump showed a test goroutine inside FailNow/Goexit, not a race. A timing assertion had failed on a
  loaded runner while the test still held the whole decode budget; cleanup then blocked forever waiting for
  a worker stuck on that budget, so the assertion message was never printed.
- Fixed in PR #73. **Lesson: any test that holds a shared resource a background worker needs must release it
  in `t.Cleanup`, and a "timeout" should be diagnosed from the goroutine dump before assuming a race or
  re-running.** Re-running a flake twice was the wrong response; the evidence was already in the log.

## 28. The pre-tag review found an SSRF-guard escape in the audit's own fix (2026-09-27, findings reported 18:15 to 18:19 ET)

- Before tagging beta.1, `/code-review high` ran on the whole diff since alpha.7 (over 7,000 lines): 8 finder agents
  from different angles, then 8 verifiers. Six findings were confirmed and three refuted (a documented Access-policy
  trade-off, a fulltext-hold leak that turned out to be cleared already, and a duplicate-write worry with no real code
  path). The tag was held until all six were fixed (PR #54, 33 files).
- The headline: `fetch.SameSite` treated a bare hostname such as `nas` as the same site as any host that starts with
  `nas.`. A feed with "allow private network" that redirected to `nas.attacker.example` (a public name whose DNS can point
  at a private address) skipped the address guard. Five of the eight finder angles found it independently before
  verification began. It was in code written to harden exactly that guard (the phase 5 audit, PR #26). Fix: a bare LAN name
  and a longer name that merely starts with it are different sites; the exception applies only to redirect hops on the
  feed's own site.
- The other five: a Reader API batch of title edits lost per-feed atomicity (partial commits and a misleading 500); a
  folder-merge rename through the Reader API widened a mute or mark-read filter onto feeds it was never scoped to;
  the `kipple:deleting:<id>` placeholder of a feed being deleted leaked into unread counts, OPML export and backups
  because the guard was wired into 3 of about 8 queries; editing only a LAN feed's URL silently dropped its network
  exception; the auto-night theme's "a fixed theme clears the schedule" rule ran from one of three places that set it.
- The conventions angle also caught my own README Quickstart saying `localhost`, against the standing `127.0.0.1` rule
  (it can stall for 5 to 10 seconds on the first page load). Fixed at once.
- Lesson: a security fix needs a review of its own, and independent angles agreeing on one defect is stronger evidence
  than any single verifier. A "fix everything" rule means a release waits for its review.

## 29. Cloudflare error 1033 on every tunnelled site (2026-09-27, about 21:28 ET)

- The owner reported error 1033 on all tunnelled sites during beta.1 deploy prep. Both Docker stacks were healthy. The
  tunnel container (up 21 hours, never recreated) was failing to dial Cloudflare's edge over QUIC/UDP
  (`no recent network activity`) while the host's DNS and TCP to Cloudflare worked.
- This is not the token-rotation failure that the standing "never recreate cloudflared" rule is about. With the owner's
  go-ahead a plain `docker restart` (restart, not recreate) brought all four connections back in under a minute,
  checked from outside against two sites.
- Root cause not confirmed. The session was running heavy background load (parallel agents, image builds, a long fuzz
  run), which is a plausible trigger but unproven. Lesson: read the tunnel's log before assuming a pulled-down stack or a
  rotated token, and keep restart and recreate distinct. Memory note added.

## 30. Ten defects in the day's own PRs (2026-09-29, 07:55 to 08:55 ET)

- After PRs #73, #74 and #75 merged, a `/code-review high` of the diff since beta.1 (several angles, then verifiers)
  found 10 confirmed or plausible defects. Five were in my own fixes for #71 and #72, merged minutes earlier: the lead
  image picker split `srcset` on commas and corrupted CDN URLs that contain commas; an unsized hero image lost to any
  later image with a tiny declared size such as a 48 px avatar (the reverse of what #71 asked for); the saved scroll
  offset was compared with a global watermark that survives a remount; the "seen" set included the 8-row overscan
  buffer; and it was not kept across a remount.
- Five older ones: the refresh pill announced once per feed on refresh-all and missed a manual refresh that joined an
  in-flight fetch; a collapsed folder was unreachable in Edit and Select mode and select-all could include hidden feeds in
  a bulk delete; Feed Health kept its selection across a search or filter; a check interval of 100 minutes read "Every
  1.6666666666666667 hours"; the two bulk dialogs duplicated their loop.
- All ten were fixed, one small PR each (#76, #77, #79, #82, #83, #81, #84), each with a regression test that fails
  without the fix except the refactor and one guard that could not be reproduced in jsdom (item 35). Second-round
  reviews of #76 and #77 each found one more real issue; both fixed. Four smaller review items fell outside the top-10
  cap and were folded into the fragment tooling PR.
- Lesson: #74 and #75 were merged on my own review only, and a fresh review then found regressions in both. From this day
  I self-review each diff before proposing a merge (item 34), and a fix for a bug is reviewed like any other change.

## 31. CHANGELOG conflicts on every merge (2026-09-28 to 09-29)

- Every PR added a line under `[Unreleased]` in the same place. On Sunday night PRs #63, #64 and #65 all conflicted with
  `main` once #66 merged (23:19) (two also on `f3.test.tsx` and `AppShell.tsx`); I merged `main` into each by hand and re-ran the
  suite. On Tuesday seven of the eight fix PRs edited the same Fixed section, so the merge order needed a rebase between
  each. The owner asked for the conflicts to stop.
- Fix (PR #85, merged 12:55 ET): one file per change, `changes/<slug>.<kind>.md`, and `scripts/changelog.mjs` with
  `check` (in CI and in `ci-local.ps1`), `preview`, `release X.Y.Z` (folds fragments in Keep a Changelog order, merges
  duplicate headings, updates links, deletes the fragments) and `notes`. The 17 pending entries were migrated verbatim.
  Eight tests.
- Lesson: a file that every parallel branch appends to will conflict; give each change its own file and let a script
  assemble it. I had predicted the conflicts on Tuesday morning and queued the tool behind the bug fixes; building it
  first would have avoided the rebases.

## 32. CodeQL alerts: a fix that missed `main`, and a dismissal I got wrong (2026-09-27, 15:09 to 21:58 ET)

- Two alerts came in on `internal/discover` (request forgery) and `internal/greader/itemid.go` (integer conversion), both
  false positives: the fetcher runs through a guarded transport, and the `int64` conversion is a deliberate bit-cast of a
  `uint64`. While diagnosing a character limit on the dismissal comment, my first test call dismissed alert 1 with the
  comment "test". The classifier then blocked the real dismissal as a security bypass, correctly. I did not work around it,
  reported the "test" comment, and left both for the owner. Later that evening both
  alerts were reopened and dismissed again with real reasons, and recorded as risks R8 and R9 so the citations resolve.
- Two more alerts came from the new UAT runner (`web/uat/run.mjs`): a tag-stripping regex that ran one pass (a nested
  malformed tag can reassemble) and a selector escape that handled quotes but not backslashes. Neither was exploitable
  (test tooling, no untrusted input) but both were cheaper to fix than to dismiss: strip to a fixed point, escape
  backslashes first. The fix landed on a branch the owner had already merged as PR #46, so it never reached `main`;
  I cherry-picked it into PR #51.
- Lesson: never use a placeholder comment on a security action; check whether a branch is already merged before pushing a
  fix to it.

## 33. The local kipple-history clone diverged after the history rewrite (2026-09-29)

- The 2026-09-28 rewrite of this repository's history (item 26) was pushed from a fresh clone. The working copy on the
  dev machine stayed on the old, pre-rewrite history, with the real hostnames still in it. The morning brief for Tuesday
  already warned not to push it, and when the owner asked why nothing from Sunday was in the diary, the audit found
  that copy diverged from GitHub.
- Fix: I kept it as the local branch `local-pre-rewrite-backup` (never pushed) and reset `main` to match GitHub, with
  nothing force-pushed. The private duplicate repository was deleted on Tuesday morning after the owner refreshed the
  `delete_repo` scope and said go.
- The gap itself came from the same period: nothing was written here for Sunday daytime and evening, because the
  overnight task list put the scrub first. The owner said this repository must be updated at least daily; the rule is in
  memory and in Kipple's `CLAUDE.md` (PR #89).
- Lesson: after a history rewrite, every other clone is a hazard. Replace or delete them at once, and tell the next
  session which one is real.

## 34. Merging: a denied merge, then permission with a condition (2026-09-26 to 09-29)

- Item 24 records the first denial (PR #17, "merge without review") and the owner merging #17 and #18 himself. On
  Tuesday, after #74 and #75 had merged and a review found regressions in both (item 30), the owner set the current rule:
  I may merge any PR whose CI is green on its exact head commit, but only after we have discussed it. I wrote it to
  the settings file and he approved it.
- The Tuesday batch then merged in the agreed order (#84, #76, #77, #79, #80, #82, #83, #81) with the changelog rebased
  between each, and later #85 and #87. PRs that touch workflows, deploy or release files or repo settings still need
  an explicit ask. Tags, releases and deploys always do.
- Lesson: the classifier's denial and the owner's gate are two separate things; I stop at a denial rather than route
  around it, and a merge proposal states the PRs, the order and the conflicts to expect.

## 35. Test pitfalls in jsdom and with virtualized lists (2026-09-29)

- The scroll fixes (PRs #74, #77) depend on a virtualized list. The original bug treated every row above the
  virtualizer's start index as "scrolled past", including rows a jump had skipped without rendering them; the fix tracks
  which rows were actually rendered in the visible window.
- In jsdom `Element.prototype.scrollTo` is a no-op stub (`src/test/setup.ts`), so a pixel check of `scrollTop` cannot tell
  a restored offset from a reset one. The regression test spies on `scrollTo` and asserts whether the list asked to go
  back to the top. A stale-cache scenario also needs `invalidateQueries` with `refetchType: "none"` inside `act`, so the
  stale cached page is still served on remount.
- One guard added in the second round of fixes could not be reproduced reliably in jsdom. It shipped with no test of
  its own, and the commit says so. Timing tests in #79 were rewritten to be deterministic rather than given longer
  timeouts (as in item 24).
- Lesson: state plainly which behaviour a test does not cover, and prefer asserting the call the code makes over a
  layout number jsdom cannot produce. Real layout still needs a browser or a phone.

## Not yet sourced

- Exact token totals per session. The harness does not expose a per-session counter; the diary's numbers come from
  the plan meter and are marked approximate there.

## 36. A wide row made the Cards list scroll sideways on a phone (2026-09-29)

- Found by UAT Suite 1 (S4) after the beta.3 fixes, not by the earlier Suite 1 run that morning. One article in the
  seeded feeds had a wide unbreakable piece of content; the Cards list on a phone scrolled sideways by 24 px.
- Cause: every list row sits in `.kp-row`, a grid that defined only a row template, so its implicit column was `auto`
  and took the widest item's min-content. It was latent and data-dependent, not caused by the day's fixes.
- Fix: one column of `minmax(0, 1fr)` and `min-width: 0` on the child (PR #115). jsdom cannot lay out CSS, so the UAT
  run is the regression test. Lesson: a passing Suite 1 depends on the feed data of the day; re-run it whenever list
  code moves.

## 37. The import announcement (#93) could not be reproduced from the description (2026-09-29)

- The UAT tester reported the "N new articles" pill after an OPML import. The fix agent found the announcement came
  from the run-finished event and fixed that, but could not see how the pill could show. Before closing, I imported an
  OPML with one new feed into a seeded instance with All articles open and watched the page: no pill, no announcement.
  Lesson: when a fix addresses a nearby cause, verify the reported symptom in a running app before calling it fixed.

## 38. A test failure that became a 15 minute CI hang (2026-09-29, PR #117)

- The `go` job of the release-workflow PR (#111) timed out at 15 minutes inside `TestFullRefreshUpgradesPendingFlight`.
  Two causes together, and no scheduler bug. First, the test's barrier was one round trip on a channel and did not wait
  for the `Submit` it followed, so under `-race` on a loaded runner the check after it could run before the dispatcher
  had upgraded the pending flight. Second, that check ran as a `require` on the dispatcher goroutine; `FailNow` there
  exits that goroutine, `close(done)` never runs, and the test waits forever, so a plain failure became a hang.
- Fix: the barrier loops until the dispatcher's queues are empty; a `Goexit` or panic inside the dispatcher helper is
  re-raised on the test goroutine; the five assertions that ran there now run on the test goroutine; each rig has a
  2 minute watchdog that dumps goroutines. A forced-interleaving test failed 10 of 10 runs before the fix and passes now.
  The natural flake never reproduced locally without `-race` (no cgo toolchain on the dev box).
- Same family as item 27. Lesson: never assert off the test goroutine, and read the goroutine dump before re-running.

## 39. A health-check test used a port that another test had reused (2026-09-29, wizard backend branch)

- A health-check test needed a "dead" port; the freed port was reused by a live test server, so the check succeeded
  when it should have failed. Intermittent. Fixed on the backend branch (#118).
  Lesson: a port that was free a moment ago is not a dead port.

## 40. Another session removed five agent worktrees (2026-09-29, evening)

- A different Claude session force-removed five of the agent worktrees while the wizard work was in flight. No work was
  lost: everything was committed and pushed. A later check confirmed each PR head matched `origin`. The other session's
  reason is not recorded here. Lesson: push before a session ends, and check PR heads against `origin` after anything that
  touches worktrees.

## 41. The permission classifier again, and my own habit (2026-09-29, evening)

- The classifier denied a read of production data on Host-A (wanted for the stats question, item in DECISIONS.md) and,
  at different points, merges. I did not work around either. The read was replaced by a query in the PR for the owner to
  run on his own copy. For merges the root cause was the classifier's condition ("has gone through the project's own review
  process"); the owner changed the rule himself.
- His frustration was also aimed at me: I kept presenting a merge order as if it were a standing rule. It was my proposal
  each time. Lesson: say "proposal" when it is one, and see item 34.

## 42. Merge conflicts in the stacked wizard branches (2026-09-29, evening)

- Resolved by merging `main` into the feature branches, never rebasing. `Dockerfile`: the release workflow (#111) and build
  info (#114) both edited it; both sides kept, then the line breaks of the `go build` `RUN` line restored after the
  merge joined them. `cmd/kipple/main.go` and `internal/api/api.go`: an integration merge kept both sides. #122 got `main`
  merged in and CI re-run before it merged. Lesson: after a conflict in a build file, read the resulting file, not just
  the diff; CI green on the combined commit is the check.

## 43. A review workflow that handed back early (2026-09-29, evening)

- The parent agent of the review workflow returned before its children finished, and the harness deleted its isolated
  worktree, which killed its five child review passes. The passes were relaunched from the top level and finished.
  Lesson: launch review passes from the top level rather than under a parent that can return first.


## 44. My throttle starved the owner's correct setup code (2026-09-30, pre-tag, issue #156, fixed in #158)

- The claim lockout I added in #150 was keyed by address. Behind a shared gateway address, one noisy client could take
  every locked-out check slot, and the owner's correct setup code was then never checked. Found during pre-tag
  verification (filed 09:55), so it never shipped. Fix in #158: a setup code is always checked, even from a locked
  address. Lesson: a per-address limit must not gate the legitimate check; my own fix from the night before introduced
  this, and the pre-tag pass is what caught it.

## 45. `FuzzIconLinks` found a real bug (2026-09-30, pre-tag, issue #157, fixed in #158)

- 28 of the 29 fuzz targets ran clean. `FuzzIconLinks` found that `iconLinks` could emit a candidate that does not
  re-parse (`http://::`). Fix in #158: candidates that do not re-parse are dropped. Lesson: the fuzz run before a release
  is worth doing every time; it found something on a tree that had just passed CI.

## 46. The font picker that was not missing (2026-09-30, morning)

- The diary had asked whether the "Aa" button was missing in the owner's build. It was not: the reading-font picker was in
  that menu all along, and he found it himself. He still wanted it in Settings, Search and the wizard, and #153 added it
  there at his instruction. Lesson: when a question is whether something exists in his build, ask him to look, or look,
  before parking it as an investigation.

## 47. Host-A's compose file did not pass the build args (2026-09-30, deploy)

- The repository's example compose file passes `VCS_REF` and `BUILD_DATE`, but Host-A's own compose file (not in the
  repository) passed only the version, so the deployed image would have reported commit and build date as "unknown". It
  was caught before the deploy. The owner added the two build args to Host-A's file after making a backup copy, and ran
  the deploy commands himself. Result: `v0.5.0-beta.1`, commit `2a2e261`, correct. Lesson: a release that adds build info
  needs a check of the deploy host's compose file against the repository's, before the tag; add it to the release steps.

## 48. The access review: a morning of blocked actions (2026-09-30)

- Seven kinds of block in one morning: classifier denials on a Host-A data read; the merges; a `bind_pr` false positive;
  the read-only database backup copy; a stored-token read and a file delete by a subagent; the `PreToolUse` docker hook
  blocking a command because its text contained docker words; and the harness removing a worktree.
- Root causes: a non-deterministic classifier; a stale `autoMode` environment saying the repositories were private; one
  `soft_deny` entry flagging every `ssh` to the deploy host; a regex hook matching words; subagents running in their own
  context without the session's rules; a stale memory note saying `gh` was missing. Meeting 46.
- The owner applied the fix himself: a replacement hook with an allow-list, allow entries and a corrected environment.
  Lesson: hooks are deterministic, prose rules are not. The new hook then let the read-only backup copy through, which
  was the test that mattered. None of the blocks was worked around; each was reported and the owner decided.

## 49. The GHCR package is private (2026-09-30, after the release)

- The first real Release run was green and the image is published, but the GHCR package is private until the owner makes
  it public by hand, so anonymous `docker pull` fails and the pull-and-run quickstart cannot work for anyone else yet. A
  repository ruleset restricting who can create `v*` tags is also still his to set up, since a pushed tag now publishes
  a signed image. Both are owner steps; neither is done.


## 50. The branch ruleset that protected nothing (2026-09-30, afternoon)

- The owner created "Protect main" at 15:08 and saved it with an empty target, so it matched no branch. Nothing flagged
  it; the ruleset showed as active. Found when its target was read back through the API; 15:13 the default branch was
  added. Lesson: after a protection is created, read its conditions back, and test it against a real push or a Scorecard
  rerun, not just "active".

## 51. My Scorecard estimates were wrong (2026-09-30)

- I estimated the Branch-Protection score too high, and said a `SCORECARD_TOKEN` is needed. Both were wrong. Scorecard's
  own documentation says tier 1 is what this ruleset reaches (3 of 10) and that the higher tiers need a second reviewer;
  no token is needed for this check on this repository. Corrected in the same exchange. Lesson:
  quote the tool's own documentation for a score, not memory.

## 52. The release lost its pre-release flag (2026-09-30)

- After the beta.1 release the GitHub release object showed as Latest and not as a pre-release. Cause not established.
  Fixed with `gh release edit`; it is a pre-release again. Lesson: check the release object after the workflow, not only
  the workflow's result.

## 53. Filling the Best Practices form (2026-10-01)

- An agent had drafted 67 passing-level answers (62 met, 3 unmet, 2 N/A). The three unmet were closed by `CONTRIBUTING.md`
  (#162). Claude in Chrome was not connected, so the form was filled in the app's browser pane through the owner's own
  signed-in session; he signed in himself. The page's CSP blocked fetching the answers from a local helper server, so they
  were pasted in parts. Saved at 97%; 100% once he asserted `know_secure_design` and `know_common_errors`, which are claims
  only he can make. Lesson: a criterion that asks for the owner's own assertion goes to him, not into a draft.

## 54. A password in a file he could not read (2026-10-01)

- To check the iOS fix on his phone I stood up a throwaway preview instance bound to the Tailscale address on port 7083
  (new `KIPPLE_DEV_HOST` option in `web/scripts/seed.mjs`), and told him the dev password was in a repo file. He cannot
  read a repo file from a phone, and he was annoyed. The credential should have been given in the message that asked him to
  sign in. Lesson: say what the person needs on the device they are holding.

## 55. A push CI run failed after a green PR run (2026-09-30, 20:07)

- The CI run on the push of #163 (`d218798`) failed in the go job: `TestServeRefusesWhenTheLockIsHeld` in `cmd/kipple`.
  The PR run on its head was green, as is every later run. Observed here, not investigated, no issue filed at the time of
  writing. Whether it is related to #154 (a flaky test under `-shuffle`) is not known.

## 56. The `time.Local` race (2026-10-01)

- `-race` CI failed in `TestServeRefusesWhenTheLockIsHeld` (issue #165). My first reading blamed the test's zone swap. The
  cause was upstream: the health check built a new HTTP connection per probe and never closed it, so keep-alive goroutines
  outlived `runServe` and raced with the write to `time.Local`. Fixed in the probe (keep-alives off) and in how tests swap
  the zone (#166); production behaviour unchanged. Lesson: a race report names the victim, not the culprit.

## 57. Two flaky tests with one root (2026-10-01)

- `TestApplyBudgetEndsTheRun` (#154) depended on a wall-clock budget shared across servers; the budget became a per-server
  field the test sets to zero (#168). The same class later hit `TestRepairIsLinearAndCapped` and a Busy test in the 0.6 line
  and was replaced by step counters and huge waits (#193). Rule kept: assert a property, never elapsed time.

## 58. Offline: the loading screen that never ended (2026-10-01)

- Issue #108. With TanStack's default network mode, a query fired offline paused forever, so screens sat loading. The fix
  (#167) makes queries and mutations run in "always" mode, so they reach the service worker or fail with their normal
  error, and opened or starred articles are saved to the offline queue and sent later. A review checked for double sends
  and refetch storms and found none. Accepted trade: a screen with nothing cached now shows an error with Try again, where
  it used to show a skeleton for ever.

## 59. A shared checkout switched under an edit (2026-10-02)

- Two Claude sessions worked in the same working tree. While I was rewriting `CLAUDE.md` uncommitted, the other session
  switched the branch, and my file on disk became its version. I noticed only because a size check did not match. The
  edit was recovered from my pushed commit and rebuilt on top of the other session's rewrite in a separate worktree.
  Rules saved: edit in your own worktree, push early, never leave work uncommitted in the shared tree, leave another
  session's branches and worktrees alone, and message that session by name before touching shared state.

## 60. Squash merge versus the branch that kept the history (2026-10-03)

- Main held a squashed copy of the 0.6 integration, while `release/0.7` carried its full history, so merging 0.7 into main
  conflicted in 28 files. All of those were the same content. Resolved with a merge that kept `release/0.7`'s tree
  (`-s ours`), then re-applied the one real change that existed only on main (the `CLAUDE.md` trim); #202 and #201.
  Lesson: after a squash into the base, bring the base back into the long branch as a merge before the next integration.

## 61. A UAT failure that was a stale assertion (2026-10-03)

- The wizard script failed on `ui.font_body is vollkorn, expected Vollkorn`. The server has stored font ids, not display
  names, since 0.6; the script still asserted the name. Fixed the script (#199). The agent that ran it also stopped its
  seed server with `taskkill /IM kipple.exe`, which killed two other Kipple processes it did not own. Rule: stop a server
  by its process id, never by image name.

## 62. The 0.6.0-beta.1 release had no GitHub release (2026-10-03)

- The tag, signed image and deploy were done, but the release workflow does not create the GitHub release and nobody had.
  Created by hand with the notes and the image block, marked a pre-release. The release checklist already says every tag
  has one; the miss was a hand-off between two sessions.

## 63. My own wrong test case in Suite 5 (2026-10-03)

- I used the five-character password "short" as the "too short" case. Five is the minimum, so Kipple correctly accepted it,
  and that consumed the account claim for the volume. Redone on a fresh volume with four characters. Not a defect.

## 64. First cost estimate used guessed prices (2026-10-03)

- Asked to compute the project's cost, I first priced it from the public rates of earlier models and said so. The owner
  asked for the real figure; the official price list gave very different cache-read rates for the newest models (Fable 5.1
  and Opus 5.5 read cache at 2.5% and 5% of input), which moved the total from about $3,170 to about $2,100. The token
  counts were right both times. Lesson: fetch the price list first. Still open: 19 messages in the logs came from a
  Haiku model, against the never-Haiku rule; where they came from was not traced.

## 65. A 20-second refresh blamed on the newest change (2026-10-04)

- The scale baseline (150,000 items, 541 nested folders) showed a 500-feed refresh taking about 20 s, against 3.3 s without
  the folder tree. The first suspect was nested folders. The cause was older: the retention trim joined a temporary table
  to `items` without statistics, so every trim read the whole items table, once per trimmed feed; the tree only made
  the library big enough to see it. Fixed with a fixed join order and a query-plan test (#238, #239): 23 s to 3.7 s.
  Lesson: compare on the same library before blaming the newest change.

## 66. A wall-clock test under the race detector (2026-10-04)

- An OPML import test that asserted a time limit failed on the CI runner with the race detector on. Replaced with an
  `EXPLAIN QUERY PLAN` test that checks the index is used, which is deterministic. The same lesson as 2026-10-02 (#193):
  assert the property, not the speed.

## 67. Parallel tests that were only fast on the dev machine (2026-10-04)

- In the optimisation pass, `t.Parallel()` across the API tests cut the run on a 20-thread dev machine, but on the two-core CI
  runner with the race detector it timed out five tests, broke an image-proxy timing test and made the Go job slower.
  Reverted; the package stays serial. Rule: time a CI-affecting change under CI conditions, not on the dev machine.

## 68. A one-shot container started on the dev machine (2026-10-04)

- An overnight agent ran the local CI script from a bash shell, which started a one-shot secret-scanner container on the
  dev machine, against the standing rule of no Docker work there. It passed and nothing else ran. The standing rule is that
  heavy tests and container work do not run on the dev machine.

## 69. The release was tagged before the last gates finished (2026-10-04)

- The owner told the agent to merge and tag `v0.8.0-beta.1` while the fuzz, UAT Suite 1 and second Go-run agent was still
  running. CI was green on the exact commit, so the tag followed, and the remaining gates were reported when they finished.
  Not an error; recorded because it is the first time the rule "gates on the tagged commit" was applied out of order on
  the owner's explicit word.

## 70. Two optimisation scratch files and a stray source file (2026-10-04)

- The optimisation branch left scratch output in its worktree and a stray copy of a web component in the main checkout; the
  agent could not delete them (the removal was blocked by permissions). Removed in the 2026-10-05 housekeeping.

## 71. Prose-only pull requests ran the whole CI (2026-10-06)

- Cause: no job looked at what a diff touched, so a docs edit paid for the 11 to 17 minute Go job. Two first designs (a
  denylist of docs that tests read, then an allowlist with a name scanner) were found fail-open or incomplete in review.
- Fix: a `changes` job classifies the diff and fails closed; on code, CI deletes the listed prose files before the code jobs so
  any hidden reader fails its own test. Live proof: about 22 seconds, required checks satisfied.
- Lesson: make the unsafe case fail loudly instead of trying to enumerate it.

## 72. A whole-diff review handed back incomplete and was run twice (2026-10-06)

- Cause: the reviewer was not told to finish alone, so the same diff was reviewed again at Opus prices.
- Fix: reviewers work alone, hand back at most 15 lines, and nothing else starts on that diff meanwhile.

## 73. UAT locators went stale after an accessible-label rename (2026-10-05)

- Cause: a changed `aria-label` was still used in `web/uat`; the beta.3 UAT run failed on it.
- Fix: the `uat-labels.mjs` guard fails when a removed or changed label is still referenced there.

## 74. A docs caveat hid a behaviour bug: the read rate was an approximation (2026-10-07)

- Cause: the first per-feed read rate capped its denominator and shipped with a docs note saying so.
- Fix: review pushed on the caveat; the rate now uses exact arrival counts (`feed_daily_new`, schema 18). Rule: a docs caveat
  usually means the behaviour is wrong.

## 75. Scroll and marking code passed jsdom but had real ordering bugs (2026-10-07)

- Cause: jsdom observer stubs fire synchronously, which hid the real frame ordering in the Gazette wiring (#313).
- Fix: six review rounds, each finding a real bug; tests now model the order of events, not only the final state.

## 76. A subagent's "flake" was a real race (2026-10-07)

- Cause: `TestASlowUploadIsStopped` was reported as flaky and retried; it was a race in the upload path (fixed in #305).
- Fix: measure a reported flake (run it alone, many times) before calling it one.

## 77. The deploy helper could not find the pre-migration snapshot (2026-10-07)

- Cause: the app writes the snapshot before a migration without logging its name, so the helper has nothing to match.
- Fix: the owner's snapshot was copied off the server by hand for that deploy (read-only copy, checksum verified); the app now
  logs the snapshot's file name (#318), with a test, and the rollback docs say where to look.

## 78. "Mute similar" chose words the reader never picked (2026-10-07)

- Cause: the editor was opened with the first three title words already in the rule and a name built from them. On a phone the
  suggestion chips showed as greyed out because their words were already used, so it looked as if the reader had tapped them.
  The owner had never made a filter before and said so.
- Fix (#320): the rule starts empty, the chips toggle with a check mark, and about 550 very common words are never offered.
  Rule: a default the reader did not choose is a bug in the default, not in the explanation next to it.

## 79. A client-only text fix made the page and the server disagree (2026-10-07)

- Cause: to make a chip for "Apple's" match, the first fix folded the typographic apostrophe only in the page. The server did
  not, so the rule saved a term that matched nothing. A second review found the highlight code and the duplicate check had the
  same gap.
- Fix: the fold lives in the server's text normaliser, which compiles terms and reads titles, and the page's mirror of it
  (highlight, duplicate check, chips) follows with a parity test. A looser match is stated in the changelog fragment (the
  modifier-letter apostrophe now counts as an apostrophe).

## 80. The UAT label guard flagged unrelated buttons (2026-10-07)

- Cause: a chip label changed from "Add X" to "Word X", and two UAT lines that look for the "Add feed" and "Add N feeds" buttons
  matched the removed fragment.
- Fix: both lines carry the guard's written-reason ignore mark. The guard stays strict; a coincidental match is marked, not
  waived globally.
