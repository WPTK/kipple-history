# CodeQL findings, 2026-09-27 to 2026-09-29

GitHub offered to enable CodeQL scanning on Kipple during the phase 5 work; the owner turned it on on 2026-09-27
("GitHub suggested I enabled CodeQL so you will see those too"). Four alerts on `main` were raised in the first
scans, plus one review-time alert on a pull request two days later. Source: the repository's code-scanning alert
list, the dismissal comments, PR #51 and `docs/risk-register.md` (R8 and R9).

Severities are CodeQL's own security-severity labels.

| Alert | Rule and place | CodeQL severity | Outcome |
|---|---|---|---|
| #1 | `go/request-forgery`, `internal/discover/discover.go` ("URL of this request depends on a user-provided value") | Critical | **Dismissed as a false positive** (the owner had already marked it on the GitHub tab; at 21:56 ET the alert was reopened and re-dismissed to replace an empty comment with a written reason): feed discovery fetches through a caller-supplied guarded round tripper, and the private-address block is enforced at dial time by a custom `Dialer.Control` on the resolved address, which CodeQL cannot trace. Recorded as risk R8. |
| #2 | `go/incorrect-integer-conversion`, `internal/greader/itemid.go` (`ParseUint` to `int64` without an upper bound) | High | **Dismissed as a false positive** (same sequence) with the reason written on the alert: a deliberate same-width bit cast, documented in the code comment; item ids are positive by construction and a malformed inbound id simply fails to match. Recorded as risk R9 (commit `1158ca3`, 21:57 ET). |
| #3 | `js/incomplete-multi-character-sanitization`, `web/uat/run.mjs` (`decodeSnippet` stripped HTML tags in one regex pass) | High | **Fixed** in PR #51: strips to a fixed point in a loop. Fixed at 16:41 ET. |
| #4 | `js/incomplete-sanitization`, `web/uat/run.mjs` (the link selector builder escaped quotes but not backslashes) | High | **Fixed** in PR #51: backslashes are escaped first. |
| PR #85 | Regex built from a heading string in `scripts/changelog.mjs` (2026-09-29, raised on the pull request) | Not recorded | **Fixed** in the same PR (`ddd16c2`, "compare headings as strings, not a built regex"); the review thread was answered and resolved before merge. |

## Notes

- #3 and #4 were in the UAT runner added by PR #46, a dev-only tool that is not in the image. Neither was
  exploitable (the snippet output is only compared as text, the path is a script-owned route string), but the PR body
  says both were cheap to fix properly instead of dismissing. PR #46 had merged before the fix was pushed to its
  branch, so the fix went in as a separate PR (#51, merged 16:39 ET).
- The owner's instruction (21:55 ET) was to fix the two remaining queue items: the CodeQL dismissals he had already
  made on the tab ("I already marked them false positive") and the stale proposed-edits file. The agent reopened and
  re-dismissed each alert so the reasoning is on the alert, and added R8 and R9 so the comments' citations resolve.
- The decision to suppress only with a written reason is a standing rule in the Kipple `CLAUDE.md` (CI section).
- Status on 2026-09-29: no open code-scanning alerts on `main`. A CodeQL check reported "neutral" on PR #82, which
  GitHub still counted as clean.
