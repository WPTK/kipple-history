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

## 3. Form-parser "repair" broke Reeder (2026-09-25, phase 1)

- Cause: the agent added a repair for malformed Reader API form bodies. It swallowed the `ts` parameter on
  mark-folder-read, mangled label streams, and could be driven to quadratic time.
- Detection: an adversarial differential-fuzz review by an Opus agent, before deploy. Not found by unit tests.
- Fix: rewrite, then narrow to the one case that needed it (the disable-tag body); related hardening in
  `c52ad71` and `dbde262`.
- Lesson: code on a sync client's live path (item ids, parameters, ordering are contract) gets its own hostile
  review. Small parsing changes show up in Reeder within minutes.

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
  evidence for the open Reeder mark-all-as-read `ts` question.
- Fix: capture evidence before any recreate. Later the Reeder log from alpha.2 was saved to
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
  reported the minutes exhausted. Open at the time of writing.
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

## Not yet sourced

- Exact token totals per session. The harness does not expose a per-session counter; the diary's numbers come from
  the plan meter and are marked approximate there.
