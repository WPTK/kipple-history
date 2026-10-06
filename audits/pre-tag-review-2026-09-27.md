# Pre-tag code review for v0.3.0-beta.1, 2026-09-27 (release checklist step 2)

Review target: `v0.3.0-alpha.7..main`, about 7,050 lines (phase 5: code audit fixes, Access JWT and optional web
password, scheduled auto-night theme, UAT tooling, docs). Run at 18:07 ET as `/code-review high`, the level the
Kipple `CLAUDE.md` requires before every deploy. Method: eight read-only finder subagents, one per angle
(correctness, removed behavior, cross-file tracing, reuse, simplification, efficiency, altitude, conventions), about 30
raw candidates, deduplicated to nine, then one verifier subagent per candidate that read the current code and
returned CONFIRMED or REFUTED. Results came back between 18:11 and 18:16 ET.

Nine candidates were verified: six confirmed, three refuted. The refuted ones were dropped with their reason (below).
The six confirmed defects were fixed before the tag, following the standing rule that every review finding is fixed.
In the same run the lead session caught its own README mistake (it told a new user to browse to `localhost`, which
the project's rule forbids because it can stall on IPv6) and corrected it to `127.0.0.1`.

Severity: the review itself only graded finding 1 ("critical"). The P0 to P3 grades for the rest were assigned when
this record was written, using the scale in `docs/uat-plan.md` (P0 blocker, P1 high, P2 medium, P3 low), from the
effect each verifier described.

## Confirmed findings

| # | Finding | Severity | Found by | Resolution |
|---|---|---|---|---|
| 1 | **SSRF guard escape.** `fetch.SameSite` treated a single-label host and any `<host>.<anything>` as one site (`nas` matched `nas.attacker.example`). A feed with the "allow private network" exception, redirected to such a name, took the granted transport on that hop, so the dial-time private-address guard did not run (and TLS was unverified if "insecure TLS" was on). The phase 5 audit had just scoped these exceptions per hop; this was the hole in the scoping. | Critical (P0). Needs a feed that already has the exception and an attacker-controlled redirect. | 5 of the 8 finder angles independently | Fixed in PR #54. A single-label name and its qualified form now match only under suffixes no public registrant can hold (`.lan`, `.local`, `.home.arpa`, `.internal`, `.localdomain`, `.home`, `.corp`). Later rounds on the same diff found the mirror hole (a single-label host such as `news` is also a public TLD, so `evil.news` matched) and closed it: single-label hosts match only themselves. Trade-off, recorded in the changelog: a LAN whose search domain is a real domain now has that redirect held; the fix is to edit the feed to the full name. |
| 2 | **Reader API batch title edit lost atomicity.** `subscription/edit` with several feeds ran one transaction per feed; a failure part-way left earlier feeds committed and answered 500. Malformed `s=` values also shifted titles onto the next feed. | Medium (P2) | Verifier read `h_subs.go` | Fixed in PR #54: one title per ref, one `EditSubscription` call, one transaction; counts that do not pair rename nothing. Tests force a mid-batch failure and check the rollback (including a created folder). |
| 3 | **A Reader API folder merge widened filter scope.** `rename-tag` onto an existing folder repointed the old folder's filters at the target, so a mute or mark-read rule scoped to one folder started acting on every feed already in the target. The web UI cannot trigger a merge (it answers 409), so only Reader API clients could. | Medium (P2) | Verifier | Fixed in PR #54: a merge turns each old-folder filter into feed filters for exactly the feeds it covered; a dry run refuses a merge whose copies would exceed filter limits (answers OK plus a log line, so client B's queue is not wedged); the archive feed is skipped. |
| 4 | **The "deleting feed" placeholder leaked.** A feed mid-delete is renamed to `kipple:deleting:<id>`; the filter that hides it was used in three places only. Folder unread counts, `Counts`, `UnreadTotal`, card lists, search, mark-all-read, Reader API streams and the OPML export (and so backups) still saw it, and the export wrote the placeholder URL. | High (P1): wrong counts and a bad URL in exports and backups | Verifier traced every use of the predicate | Fixed in PR #54: the predicate is applied to all those paths; the OPML export drops the feed; starred views keep its starred items (moved to the archive); Feed health still lists it on purpose so an interrupted delete can be finished. A central `live_feeds` view was deferred because it needs a schema migration and beta.1 says none. |
| 5 | **Editing only a LAN feed's URL silently dropped its network exception.** The server resets both exceptions on a cross-site URL change unless the request names them; the editor only sends changed fields. An IP-literal move failed with an unfixable error, a hostname move quietly lost the grant. | Medium (P2) | Verifier | Fixed in PR #54 differently from the brief. "Always send the flags" would have kept the grant on an attacker-named host after fix 1, so the editor now shows a notice and a "Keep for the new address" switch; the confirmation says when options were turned off or a saved login was removed. A follow-up commit (`f6c3674`) made single-label hosts match only themselves and named dropped logins. |
| 6 | **The auto-night theme's "a fixed theme ends the schedule" rule fired from one of three writers.** `PATCH /api/settings` and make-default could leave a fixed theme with the schedule flag on, so a later "system" pick brought back a schedule the client could not show or clear. | Low (P3) | Verifier: real, narrower than stated (`copyDeviceFrom` cannot create the state) | Fixed in PR #54: the rule moved to `store.ScheduleOffForFixedTheme`, shared by device patch, settings patch and make-default; the account write applies it inside the write transaction. |

## Candidates refuted

- **Passwordless sign-in trusts any email the Access policy admits.** Refuted as a new finding: it is a documented,
  deliberate trade-off in `.env.example`, design section 7.0 and `docs/deploy.md` (keep the Access policy to the owner's
  own identity). An optional setting that pins the email was noted as a possible hardening idea only.
- **Full-text hold marks not cleared after a panic.** Refuted: `queueFulltext` clears every mark it does not hand to a
  job in a `defer`, and the one gap is a nil-by-default test hook; a leaked mark would hide an item for at most 30 to 60 s.
- **Maintenance retry could double-write.** Refuted: no duplicate-write path found.

## Status

All six fixed and merged: PRs #53 and #54 merged 2026-09-27 21:03 ET; `v0.3.0-beta.1` tagged 21:35 ET after the
full fuzz suite (all 26 targets) ran clean in the same pre-tag window and an off-box copy of the live database was
saved. PR #54 also carries six further `/code-review high` rounds on its own diff, each answered. Nothing from this
review is open. Context: [phase5-code-audit-2026-09-27.md](phase5-code-audit-2026-09-27.md) (the audit whose scoping
fix this review completed) and [uat-results-2026-09-27.md](uat-results-2026-09-27.md) (the UAT findings fixed in PR #53).
