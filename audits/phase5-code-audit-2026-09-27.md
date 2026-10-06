# Phase 5 code audit, 2026-09-27 (release step 8: full code audit and changelog review)

Audited `main` at `d2ea1c8` (v0.3.0-alpha.7 plus the phase 5 planning doc). Eight read-only Opus reviewers, one per
area, each told to skip what the 2026-09-26 reviews (`local-review-2026-09-26.md`, `local-review-round2-2026-09-26.md`)
had closed and to give extra attention to everything since `640fe2c` (alpha.2): the favicon finder, `ot` state
changes, the review-fix rounds and all of phase 4 (stats sender, summary, export and delete, Wrapped). The lead session
re-read every finding before fixing it. Fixes are on Kipple branch `phase5-code-audit`, PR
https://github.com/WPTK/Kipple/pull/26 (open, for the owner to merge), with a test for each fix except where noted.

Areas: fetch/sched/extract/favicon/opml/cmd wiring; store ingest and state; stats pipeline, devices, settings, backup;
Reader API, auth, config, cmd; web JSON API and filters; image proxy, image cache, sanitizer; web data layer and
service worker; web screens.

No critical or high findings. No auth bypass, no XSS path, no signature weakness. The one theme with several findings
was the per-host scoping of a feed's network exceptions ("allow private network", "allow insecure TLS"): the 2026-09-26
fix covered full-text extraction and favicons per redirect hop but images only at signing, only for the private flag
and only by exact host, and the feed fetch itself not at all.

## Baseline

Before any change: `scripts/ci-local.ps1 -Skip security` green (gofmt, vet, go test shuffled, npm ci, lint, Vitest,
build, contrast, npm audit); govulncheck, staticcheck and gosec (high/high) clean. govulncheck lists GO-2026-5932
(`golang.org/x/crypto/openpgp`, unmaintained, no fix) as required but not called. gitleaks was not run locally: the
local script runs it in a Docker container, and heavy Docker work on the dev machine is off the table; GitHub CI runs
it on the PR.

## Findings and fixes

### Security (network-exception scoping)

1. **Image proxy: private-network grant covered every redirect hop** (medium, reproduced with a scratch test).
   `imgproxy/upstream.go` built one client with the granted transport; `CheckRedirect` only stripped Referer. A
   feed-host image that 302s to `http://192.168.1[.]1/...` was fetched. Fixed: a per-hop `hopScoped` RoundTripper sends
   hops off the image's host (`fetch.FeedHostVariant`) through the guarded transport. Test `redirectscope_test.go`.
2. **Images: "allow insecure TLS" never scoped** (low). Third-party images in an insecure-TLS feed were fetched with
   verification off. Fixed in `api/image.go` (`scopePrivateNet` now clears both flags); design §7.4 flags text updated.
   Test `imagescope_test.go`; `image_test.go` expectation corrected (it pinned the old behaviour).
3. **Images: exact host match** (low, functional). `img.nas.lan` / `www.nas.lan` lost the grant; now
   `FeedHostVariant`, the rule extraction and favicons use.
4. **Feed fetch: exceptions applied to every redirect hop** (low; gap in the earlier fix). A LAN feed redirecting to
   loopback or another LAN host was dialled. Fixed with `siteScoped` in `fetch/client.go` (same site per
   `fetch.SameSite` or `FeedHostVariant`, the hosts a redirect migration keeps settings for). Test `hopscope_test.go`.
5. **URL edit kept the exceptions on a cross-site move** (medium). The held-redirect note and design said the edit
   clears them; `PatchFeed` only cleared `http_auth`, and even validated the new URL with the kept private grant.
   Fixed in `store/feedadmin.go`; design PATCH row updated. Test `patchfeedsite_test.go`.

### Server correctness

6. **Session lookup error answered 401** (low; login/session code). A transient read error signed the web app out.
   `sessionOK` now returns an error and `authed` answers through `serverError` (503 maintenance or 500). Sign-in's
   `CreateSession` error also goes through `serverError`. Test `sessionerr_test.go`. Small change in `api/api.go` and
   `api/login.go`; the parallel Access-JWT branch had not touched either file when this was written.
7. **Feeds being deleted stayed listed** (low). `kipple:deleting:<id>` rows appeared in the web bootstrap, Reader API
   `subscription/list` and unread-count during a purge. Excluded (`notDeletingSQL`); asserted in
   `feeddelete_test.go`.
8. **Folder merge by rename dropped folder filters** (low). `RenameLabel` onto an existing name cascaded the old
   folder's filters away; they now move to the target. Test `renamemerge_test.go`.
9. **Batch `subscription/edit` with one title renamed every feed** (low, latent: NNW and client A edit one feed at a
   time). One title now applies only to a single-feed edit. Test in `subs_test.go`.
10. **Scheduler run table** (low). A second import/retention run replaced the first in `s.runs[kind]`: the first
    vanished from status, lost progress events, and `Busy()` could go false mid-run. Runs are keyed by id. Test
    `TestOverlappingRunsOfOneKindAreAllTracked`.
11. **Held host starved the due query** (low). `DueFeeds` took the 500 oldest-due rows and skipped held hosts in Go; 500+
    feeds on one 429'd host blocked all others. `DueFeedsExcept` filters held hosts and blocked ids in SQL. Tests
    `duefeeds_test.go`, `TestHeldHostBacklogDoesNotStarveOtherFeeds` (times out without the fix).
12. **Recovered panic backed off healthy feeds** (low). Trim/skip panics and post-commit panics set `commitFailed`.
    Worker now tracks fetch/commit/committed phases. Tests in `panic_test.go`.
13. **Stats summary 500 during a delete** (low). The longest-read title lookup failed with `ErrNoRows` if a stats
    delete removed that row mid-summary; now tolerated (title left blank). Not unit-tested: the window is between two
    queries in one call and needs an injection hook that does not exist; the change is a one-line error filter.
14. **Image cache dropped a fresh entry** (low). `OpenFile` dropped the row after a failed open outside the lock; a
    commit could land in between. Now re-opens under the lock first. Not unit-tested for the same reason (a race
    between an unlocked open and a locked commit); covered by the existing cache suite for regressions.

### Web

15. **Stats off then on stopped the sender for the session** (medium). `doFlush` used the sign-out wipe for "off",
    which set `wiped` until the next sign-in. Now `clearStatsQueue()`. Test in `statsSender.test.tsx`.
16. **Beacons lost while the access-proxy sign-in was expired** (low). Now queued. Test in `statsSender.test.tsx`.
17. **Two fallback poll loops** (low). `useServerEvents` could run two `/api/status` loops. Generation token per loop.
    Not unit-tested (needs a stalled poll across two transport flips); the change is local and the events suites pass.
18. **Maintenance 503 not retried** (low). `internal/api/maintenance.go` said the web client retries; it did not, and
    an online star or mark-read during a rebuild reverted with a generic error. `api()` now retries 503 maintenance
    after Retry-After for up to 60 s and has a specific message. Test in `client.test.tsx`.
19. **Filter delete loop stopped on `changed: 0, done: false`** (low). Now repeats up to three idle rounds. Test in
    `filters.test.tsx`.
20. **Escape closing a menu also went back** (medium, reproduced in a real browser: Radix closes in a capture
    listener and React removes the content before the window listener runs). `keys.ts` returns on
    `e.defaultPrevented`. Tests in `keys.test.ts`.
21. **j/k after the selected row left the Unread list jumped to the top/bottom** (medium). Selection now moves to the
    next row when the selected row leaves. Test in `fixes.test.tsx`.
22. **Wrapped stuck on the skeleton on error** (low-medium). Error branch checked first. Tests in `wrapped.test.tsx`.
23. **Mark this fetch read left lists stale** (low). Invalidates lists. Test in `f3.test.tsx`.
24. **`/` on Search cleared the query** (low). Focuses the box. Test in `f5search.test.tsx`.

### Documentation and settings

25. Stats data dictionary said `enabled: false` means the rest is empty; a summary export with recording off is fully
    computed. Reworded.
26. `stats.api_single_read_is_open` is stored and validated but read by nothing (known reserved, see
    `claude-md-proposed-edits.md` item 9); its description now says "Reserved: stored but not used yet".
27. `ot`/`nt` in milliseconds are clamped to year 2100 and match nothing. Design §3 says seconds and both target
    clients send seconds, so the semantics stay; the clamp is now logged as a warning so a misbehaving client shows up.

## Changelog review

Compared `CHANGELOG.md` against `git log 640fe2c..d2ea1c8` (157 commits). Fixed:

- `v0.3.0-alpha.5` and `v0.3.0-alpha.6` were never deployed or tagged (alpha.7 was the first deploy after alpha.4),
  so the compare links for alpha.5, alpha.6 and alpha.7 pointed at missing tags. They now compare the release commits
  (`5b0db7d`, `271fd23`). No tags were created (tags are made at deploy time on the deployed commit only).
- The alpha.5 and alpha.6 headings say they shipped in alpha.7; the alpha.7 heading says an upgrade from alpha.4 runs
  migration 0009.
- Missing alpha.4 entry: `POST /api/stats/events` drops a malformed event instead of rejecting the batch (`5a94842`).
- Missing alpha.3 entry: a replayed offline star cannot restore a trimmed item whose restore window had closed; the
  restored read time is the real time (`9ba2df1`).
- A stray blank line split the alpha.3 "Changed" list.

Everything else since alpha.2 is covered: remaining commits are CI action bumps (Dependabot), the Dependabot config,
tests, docs, or review fixes to features that were still unreleased when fixed. The audit's own fixes are under
`[Unreleased]`.

## Deliberately left, with reasons

- **`deleteFeed` can outlive the HTTP write timeout** (informational from the API reviewer): a single feed of about
  600k items takes longer than 60 s to purge; the client sees a dropped connection and the SSE `feed.changed` event
  repairs the UI. The delete itself is resumable and correct. Left as is; changing it means a job API for deletes,
  which is out of proportion for a single-user reader.
- **iOS standalone `document.hasFocus()`**: whether it is true while reading in the installed PWA cannot be decided
  from code. If it is false there, no reading time is counted on iOS. Needs a check on a real device by the owner
  (already listed in the phase 4 notes).
- **gitleaks** not run locally (Docker); GitHub CI runs it.

## Checked and found sound (selected)

Sanitizer (ingest, serve and DOMPurify layers), embed placeholders, HMAC signatures and cache keys, SSRF dial-time
guard incl. rebinding, thumbnail memory model, cache accounting; ClientLogin pacing, token HMAC, cookie flags, CSRF
same-origin rule on every write and download; Reader API id forms, continuation, `ot` legs with `UNION`, mark-all `ts`;
retention invariants (starred, held, ledger, counters), feed delete resumption, filter generation/cache protocol,
migrations 0001-0009; stats dedup, read-time caps, summary DST/week/streak arithmetic, CSV formula guard, delete scope
(nothing else writes `stats_events`); offline queue re-read/supersede, service worker cache rules and sign-out wipe;
keyboard typing guard, destructive-action confirmations, Wrapped share defaults (names and titles off).

## Status update (added 2026-09-29, after the fact)

The header above is as written on 2026-09-27. PR #26 was merged the same day at 12:20 ET, and the fixes first shipped in
`v0.3.0-beta.1` (deployed 2026-09-27 evening; alpha.7 predates the merge). The three regression tests the audit
left tracked as issues #27 (stats summary versus delete), #28 (image cache drop race) and #29 (duplicate status
poll loop) were written in PR #53 and closed 21:03 ET, together with the four UAT accessibility findings. Issue #30
(iOS `document.hasFocus()`) was closed 2026-09-27 evening on the owner's phone test, and issue #31 (feed delete with
600k+ items can outlast the request timeout, "deliberately left" above) was closed 2026-09-29 07:24 ET as not
planned. The audit's scoping work was itself completed by the pre-tag review, see
[pre-tag-review-2026-09-27.md](pre-tag-review-2026-09-27.md).

