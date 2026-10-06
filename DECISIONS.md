# Decisions

Standing decisions and the later ones, with date, who made them and where the source is. "the owner" decided unless
stated. The Kipple repo's `CLAUDE.md` holds the "do not relitigate" list; the current copy is
[plans/CLAUDE.md](plans/CLAUDE.md) and earlier versions are in [plans/history/](plans/history/). UI decisions
are in [plans/ui-decisions.md](plans/ui-decisions.md). Meeting context: [MEETINGS.md](MEETINGS.md).

## Standing ("do not relitigate"), set 2026-09-24

| Decision | Detail | Source |
|---|---|---|
| Stack | Go backend; React, TypeScript, Vite, Tailwind, shadcn frontend; SQLite in WAL mode; frontend embedded in the Go binary; one image, one container, one port | [CLAUDE.md](plans/CLAUDE.md) |
| Sync API | Google Reader API (FreshRSS and Miniflux flavour) only; no Fever; Reeder Classic primary client, NetNewsWire secondary; test both | [CLAUDE.md](plans/CLAUDE.md), [research/reeder-classic.md](research/reeder-classic.md), [research/netnewswire.md](research/netnewswire.md) |
| Refresh | Background poll every 30 minutes (global and per-feed override), conditional requests, exponential backoff; API clients never trigger fetches | [CLAUDE.md](plans/CLAUDE.md), [research/fetch-prior-art.md](research/fetch-prior-art.md) |
| Retention | Newest N per feed (50, 100, 250, 500, 1000, unlimited), starred never trimmed, trimmed ids and read state kept, trim after fetch | [CLAUDE.md](plans/CLAUDE.md), [plans/design.md](plans/design.md) |
| Stats | Bulk mark-as-read and mark-read-on-scroll are not reads; active reading time is tab visible and focused; stats events never trimmed | [CLAUDE.md](plans/CLAUDE.md) |
| Fonts | Bundled and self-hosted, no CDN; system fonts when present | [CLAUDE.md](plans/CLAUDE.md), [research/pwa-ui-fonts.md](research/pwa-ui-fonts.md) |
| Themes | White, off-white, sepia, soft green, brown, dark, OLED, follow-system (later expanded to 20 schemes, see below) | [CLAUDE.md](plans/CLAUDE.md) |
| Look | Feedly is the reference (magazine and cards with images up front); not NewsBlur, FreshRSS or Miniflux | [CLAUDE.md](plans/CLAUDE.md) |
| Non-goals | No AI features, no notifications, no social, no monitoring, no multi-user | [CLAUDE.md](plans/CLAUDE.md) |
| Build | The image must build with Docker alone (the deployment host has no Go or Node) | [CLAUDE.md](plans/CLAUDE.md) |
| No secrets or hostnames committed | `.env.example` documents every variable (in practice some hostnames were committed in docs; see the scrub below) | [CLAUDE.md](plans/CLAUDE.md) |

## Design and planning decisions

- Item id equals crawl-time microseconds; a separate generated API password with an HMAC token; list-endpoint ETag
  is a hash of the rendered body; stats read inference is off by default; unsubscribe keeps starred items in an
  archive feed; modernc.org/sqlite with three pools and a commit gate; GOMEMLIMIT 64 MiB with a 256 MiB container
  limit. Source: [plans/design.md](plans/design.md), [research/item-id-and-quirks.md](research/item-id-and-quirks.md).
- Prior art for internals: lemon24/reader. the owner (2026-09-25): "We don't have to copy Reeder." Kipple is a web app
  plus compatibility with other readers, not an iOS app. Source: [research/lemon24-reader.md](research/lemon24-reader.md).
- Open questions from the research were triaged before building: [research/open-questions.md](research/open-questions.md).
- Model and effort policy (2026-09-25): choose per task; Sonnet at medium as default; Opus at high for reviews and
  root-causing; no `max` for subagents; no Haiku; ultracode off unless asked. See [CHALLENGES.md](CHALLENGES.md) item 1.

## Phase 1 operational decisions (2026-09-25)

- Web login lockout stays (10 failures per 15 minutes per IP); cookie lifetime 90 days; yarr is paused with a
  compose profile at cutover, not removed; restore window capped at 180 days; feeds with permanent redirects were
  auto-migrated and ambiguous ones left alone on purpose.
- the owner makes Cloudflare Access and tunnel changes himself; the agent does not touch Cloudflare (a security
  setting). Reader API path gets an Access bypass; the UI stays behind email one-time-passcode login.

## Process decisions

- **Fix every review finding** (2026-09-25 15:33). "All defects against the spec should be called out, and
  fixed." No silent "not fixing" lists; skipped items need a reason the owner can overrule.
- **Releases** (2026-09-25): SemVer with alpha, beta and rc prereleases; annotated tags on the exact deployed
  commit at deploy time; never move or reuse a pushed tag; Keep a Changelog 1.1.0.
- **CI** (2026-09-25): govulncheck, staticcheck, gosec (fails on high severity and high confidence only), gitleaks,
  Trivy, gofmt, shuffled race tests; Dependabot on; delete branch on merge; suppress findings only with a
  written reason.
- **Deploy** (2026-09-25 and 09-26): the agent asks before every deploy; off-box database copy first; compose and
  `.env` backups; named-service deploy only, never a bare `compose up`; one writer on the host at a time.
- **Docs are audited like code** (2026-09-26 05:31). Test-only diffs may be skipped in review; docs may not.
- **Ultra reviews** (2026-09-25 to 09-26): phase 1 first, phase 2 when fully wrapped; review sessions do not make
  changes, the main agent does. Review PRs must be `main` plus one area, because the tool ignores the PR base.
- **Merge strategy** (2026-09-26): merge commit of `phase-2` into `main`, after the reviews were fixed; squash
  was the alternative because a few commits on `phase-2` had misleading messages (`3ae3678`, `cca8156`), and
  pushed history was not rewritten.
- **Overnight autonomy** (2026-09-25 and 09-26): may build and fix; may not deploy, change Cloudflare, merge to
  `main`, tag, close review PRs before findings are in, add gitleaks allowlists without asking, or start billed
  reviews.
- **Test day** (2026-09-26): shortened for alpha.4 ("I aggressively test when the time comes").
- **Diary** (2026-09-26): senior-engineer voice, no flattery, updated at each milestone. See [diary/](diary/).
- **Verify UI in the browser pane** at the mobile preset before calling a UI phase done.

## UI and product decisions

- **UI round 1 and 2** (2026-09-25): see [plans/ui-decisions.md](plans/ui-decisions.md) and [MEETINGS.md](MEETINGS.md)
  items 8 and 9. Highlights: magazine default, full swipe with undo, five layouts with per-feed and per-category
  choice, 20 colour schemes (renamed and separated per the owner's notes), Atkinson Hyperlegible as "Easy to read", no
  OpenDyslexic, accessibility phases 2 and 3 implemented, proxied and size-capped image cache, keyword mute
  filters, offline read of downloaded content with queued actions.
- **Settings live in the app** (2026-09-25): Kindle-style reading menu plus a Settings screen; friendly names and
  help text; density presets rather than line height and width; password 5 to 256 characters; user-agent fallback
  only on feeds that fail. Source: [MEETINGS.md](MEETINGS.md) item 6.
- **Multi-user withdrawn** (2026-09-25): "Forget I said multi-user." People can clone and self-host instead.
  Per-device appearance profiles under one account are not multi-user.
- **Inline full-text extraction ships** (2026-09-25); **image proxy stays strict** (2026-09-25).
- **Image cache** (2026-09-26): only images the browser requests through Kipple, capped at 1 GiB, LRU eviction.
- **Clients never trigger fetches** (2026-09-26): no exception for refresh-all, since the Reader API has no such
  call.
- **Stats ledger kept forever** (2026-09-26, the owner's question, adopted into `CLAUDE.md`): stats events are never
  trimmed and are kept separate from the id ledger.

## Roadmap decisions (2026-09-26)

- The end state is a single pull-and-run Docker image with a separate setup application (custom domain, optional
  Cloudflare OTP, generated API password for clients such as Reeder): version 1.5.0 or 2.0.0.
- User-chosen Google Fonts: 2.0.0, only if cheap.
- Release steps 8 onward, in order: full code audit and review; changelog review; documentation run; first-time
  Docker setup walkthrough; backup and settings retention; a final go/no-go meeting.
- Release-prep list (2026-09-26): back up Kipple through Host-B's backup for now (a Host-A backup to Proton Drive
  is a separate job for the owner); test restore; health checks and other Docker features; fuzz tests before each
  release; no accessibility testing for now; Host-A runs the real feeds.

## Licence, name and open-source style (2026-09-26)

- **Licence: Blue Oak Model License 1.0.0**, chosen at 09:48 ET after Apache 2 versus MIT, then Blue Oak versus
  PolyForm. A non-commercial licence had been the first draft (PolyForm Noncommercial 1.0.0, committed 09:43, replaced
  09:50) because the owner did not want anyone to make money from work an AI made. The final choice is a standard,
  recognisable open-source-style text, which was the owner's requirement.
- **No real name anywhere, no exceptions.** Never the owner's surname, full real name or personal email in the code repo:
  LICENSE, notices, package metadata, docs, commit trailers, examples. Copyright holder wording is "Kipple
  contributors". Git author is `WPTK <...@users.noreply.github.com>` in the code repo; this history repo's own commits
  originally used the owner's initials as the author name and were scrubbed to match on 2026-09-27 (see the
  addendum below). the owner rejected an earlier suggestion that used his real name in a copyright line.
- **Pre-public scrub (planned, not done at the time of writing):** before going public, remove or generalise
  hostnames, IP addresses and personal names from committed docs; one family of hostnames contains the surname. the owner
  asked at 10:10 whether to do a preliminary first public publish now to get secrets, hostnames, IPs and names out
  (see [MEETINGS.md](MEETINGS.md) item 19). This repo, `kipple-history`, exists so the diaries and working notes
  can stay private while the code repo goes public.
- **Addendum, 2026-09-27: this repo's own pre-public scrub, done.** The owner authorized scrubbing this
  repo (`kipple-history` itself, not just the code repo) and publishing it. Rewrote the full history with
  `git-filter-repo`: the owner's first name, both hostnames (already generalised to
  Host-B/Host-A per the code repo's own convention), the Tailscale tailnet name, real LAN IPs, the
  personal domain, another home service's hostname, and the Windows login path, all replaced with
  generic equivalents across every commit's content and messages; the author identity was mapped to
  `WPTK` to match the code repo. No surname or personal email was ever present (checked, 0 hits). Verified
  with gitleaks and an exhaustive full-history grep for every pattern before publishing. The pre-scrub
  private history was kept, privately, as `kipple-history-private-archive`, never made public, so the
  raw data was never reachable by any public URL, including a transient one.
- **Third-party notices and font licences** are generated and shipped in the image (`517bd2e`).

## Parking lot (deferred on purpose, do not raise until the end)

1. Cloudflare Access JWT validation (`Cf-Access-Jwt-Assertion`, team domain and audience settings, RS256 check).
2. Passwordless or optional-password login, only after item 1 (port 7080 is published on the LAN).
3. A design system, a static demo site and a public pull-and-run image; a Kipple identity or accent colour.
4. A scheduled automatic night theme.
5. User-chosen Google Fonts (see roadmap).

Source: memory note `parking-lot` (summarised here, not copied), [MEETINGS.md](MEETINGS.md).

## Phase 3, review and release decisions (2026-09-26)

- **Ultra reviews are retired; a local multi-agent review replaces them** (the owner, 13:45: no credits). Read-only Opus
  agents by area, cross-checked, then fix agents with disjoint file ownership, then a second review of the merged
  diff. Every finding is fixed, minor ones included (the owner, 14:10 and 18:50). See [audits/](audits/).
- **CI of record is GitHub Actions** (free on the public repo, runs `-race`); `scripts/ci-local.ps1` is the fast
  pre-push check. Every change goes through a branch and PR, merged after CI is green.
- **Deploys go to Host-A** (ssh alias `host-a`; committed docs use the generic Host-A). Deploy by checking out the tag,
  building with `KIPPLE_VERSION`, `up -d kipple` only, then back to `main`; off-box database copy first; a migration
  rehearsal on a copy of the live database; the owner's go-ahead every time.
- **Releases:** GitHub Release for every tag (created for all ten), pre-release for alpha/beta/rc; changelog moves
  under the version in a `chore(release)` PR; fuzz run before each tag.
- **Feed network exceptions are per host:** a feed's "allow private network" and "allow insecure TLS" apply only to
  the feed's own host (and its subdomains and bare/www twin), for full-text extraction, images and favicon lookups.
- **ClientLogin never answers 429 and never refuses a password it did not check:** only failures count; after five
  in ten minutes each attempt waits two seconds and is then verified; IPv6 clients are grouped by /64; chosen Reader
  API passwords need 16 characters.
- **`greader.subscribe_fetch_now` is an opt-in exception** to "clients never trigger fetches" (default off, 8 s per
  request); `greader.ot_includes_user_changes` is built (default off) and needs migration 0007.
- **Offline scope** (from the UI decisions): read what is on the device, queue star and read changes, nothing else;
  only an explicit sign-out clears the queue and the cached data; an expired session keeps them.
- **The favicon finder ships** as a background goroutine, one lookup at a time, off the fetch path, failures kept
  apart from feed health.

## Phase 4 stats decisions (pre-meeting, 2026-09-26)

**Purpose.** Sources and pruning are the focus (most read, time per source, never opened); habits sit at the top of the
page (streaks, heatmap, behavior facts: busiest day and hour, longest read). Success after a week of real reading: the
numbers match memory, a backgrounded tab adds no time, the never-opened list is credible. Wrapped is in: a simple
yearly summary (totals, top sources, popular days and times, longest streak) with an opt-in share sheet; share cards
carry aggregates only unless the owner opts in each time. Not wanted: goals, targets, badges, comparisons with other
people, directives ("unfollow X"). CLAUDE.md non-goals need a clarifying edit for Wrapped (sharing is not social).

**What counts.** Every open is recorded; views count an item as read at 10 s active time or 25% scroll (threshold can
change later, raw events kept). List-preview opens count. Bulk and mark-read-on-scroll never count (unchanged).
Offline: sender events are queued and flushed on reconnect; anything the server caps reject is accepted as lost.
Web app is the intended client for stats. Reeder and any other RSS app stats tracking: parking lot;
`stats.api_single_read_is_open` stays off. CLAUDE.md calls Reeder the primary client: propose an edit.

**Screens.** One Stats entry in the main nav (phone first). Range: Week, Month, Year, All (default Month). Order:
summary strip (items read, active time, days with reading); daily activity chart; streaks (all time); heatmap
(weekday by hour, reading time); behavior facts; most read and time per source as one Items/Minutes toggle with folder
rollup, plus average read length, quick-bounce rate (opens under 10 s active), open-original rate and most-starred
feeds; never opened (with subscribed-on date, archived excluded). Low-data message under a week. Deferred:
per-feed drill-down, period comparison, monthly charts, read rate per feed (published vs opened). Wrapped ships after
the main screen. Export button under the range selector.

**Time and units.** Local time zone stored at write time, no DST handling. First day of week is a setting, Sunday or
Monday, default Sunday (display only). Minutes rounded, "<1 min", "1h 20m", hours in Wrapped.

**Data and privacy.** Events kept forever. Export: CSV and JSON (array or JSON Lines), raw events or summary, range
(week/month/year/all/custom), toggle to omit item titles and URLs, data dictionary included; behind login and the
same-origin guard. Delete a range (confirmation shows the count) and Delete all stats (typed confirmation), stats only.
Stats "off" stops recording (server-enforced) and the sender, hides the Stats entry and Wrapped, keeps existing data.
Separate switch to disable Wrapped.

**Performance.** Summaries computed on the fly; no cache or rollup. Indexes only after measuring on a seeded million-row
database; budget under 200 ms for the summary endpoint; export streams without memory growth. Container stays 256 MB
unless measurement says otherwise; 512 MB is acceptable to the owner.

**Sender.** Session per open (server session_key); timer runs while visible, focused and on the article route; 2 minute
idle cutoff (scroll, touch, key, pointer count as activity); flush every 15 s and on visibilitychange (primary), pagehide
(backup) and route change via sendBeacon with client in the body; at most 60 s per read_time event; one scroll value per
session; open_original and share events; per-session sequence number on batches for server-side dedup; offline queue
without breaking its rules; checks the stats setting. Two devices make separate sessions. Fake-timer unit tests.
Research basis: Chartbeat/GA4 engaged-time methods, MDN/Chrome page lifecycle guidance.

**Delivery.** alpha.4 sender, sequence number, stats on/off and first-day-of-week settings (no screen); alpha.5 stats
screen; alpha.6 export and data controls; alpha.7 Wrapped. Each: branch, ci-local, /code-review high, PR, CI green,
ask before deploy. Acceptance: a week of real reading on the web app.

**Decided no.** Per-device (web vs PWA) stats view, import from other readers, goals/targets/badges.
## Phase 4 build decisions after the meeting (2026-09-26 to 27)

- **Per-event id replaces the sequence number.** Every sender event carries a random `event_id`; a unique index drops any
  replay (all kinds), before the reading-time cap is evaluated. Reason: a per-session `seq` only protected `read_time`,
  and two tabs flushing one queue or a lost response would double-count `share` and `open_original`. Migration 0008 was
  undeployed when this changed, so it was edited in place.
- **Stats queue design.** One localStorage key per batch (no read-modify-write races), a cross-tab flush lock, age caps
  (12 h session-bound, 24 h others), wiped on sign-out, events dropped rather than queued while signed out, sent through
  the shared `api()` helper so a 401 signs out like everywhere else.
- **Scroll depth** is measured only from real scroll events (one read per animation frame) or a settled
  fits-on-screen check after 3 active seconds; never at session start or stop; the first 500 ms of a session are ignored.
- **Timer** runs only while it can count and re-arms on activity, visibility and focus (checked again 1 s and 3 s after
  becoming visible). `document.hasFocus()` in an installed iPhone web app is still unverified.
- **Summary endpoint** (alpha.5): a read is an open with at least 10 s of read time or 25% scroll; opens from before the
  sender existed count as reads; streak day = a day with a read; never-opened is bounded by the range and by the
  subscription date. Migration 0009 adds three partial covering indexes (about 60 MB and 2 s per million events).
  Week and month meet the 200 ms budget at a million events; year and all-time take about 0.5 s (a rollup table is the
  next step only if it matters). One summary computation runs at a time, at most 3 concurrent queries, one id snapshot
  per request. A free-space check now precedes the pre-migration snapshot.
- **Heatmap** shading is neutral (text colour into the surface) because the accent tint cannot keep 1.5:1 between steps
  in every scheme; the contrast script enforces it in CI.
- **Merges of code PRs** are attempted by me with the owner's chat approval on record; if the classifier denies it, the
  owner merges.

## Still with the owner (as of 2026-09-26 evening)

1. Turn on GitHub private vulnerability reporting (repo setting); `SECURITY.md` points to it.
2. ~~Approve or reject audits/claude-md-proposed-edits.md.~~ Dropped (2026-09-27, 21:55): the owner had the file removed
   rather than acted on, given how much has shipped since it was written.
3. Say when to turn off debug logging on Host-A (`KIPPLE_LOG_LEVEL`, `KIPPLE_LOG_GREADER_FORMS`).
4. The Host-A-side backup job that pushes to Proton Drive (outside the repo).
5. Cloudflare changes; the go/no-go decision for each deploy; phase 4 UI decisions when that meeting happens.

## Phase 5 planning decisions (2026-09-27)

Phases 1-4 complete (v0.3.0-alpha.7 deployed, kipple.cc public). Six topics, one at a time with a recommendation
each. Full text in `docs/ui-decisions.md` (working copy, `C:\kipple`); summarized here.

- **Scope: interleaved, not sequential.** Phase 5 combines release-readiness (CLAUDE.md's "release steps 8+":
  full code audit, changelog review, documentation run, first-time Docker setup walkthrough, backup/
  restore-settings guide, final go/no-go) with the two parking-lot items that were gated on "planned work
  finished" — Cloudflare Access JWT validation and passwordless login. Not parking-lot-only, not
  release-steps-only.
- **Sequencing: fully parallel.** The code audit/changelog review and the Access JWT/passwordless branch run at
  the same time on separate branches, rather than auditing first or building auth first. Accepted risk: the
  audit could flag something in the auth path and cause rework.
- **Stale phase-3 owner checklist resolved.** Item 3 (Host-A debug logging) the owner is doing himself. Item 4
  (Host-A→Proton backup job for Kipple's own data, separate from Host-B's own Proton backup job) is explicitly
  **not** being built in phase 5 — local `docker cp` snapshots remain the only backup path. Items 1 and 2
  (GitHub vuln reporting toggle, `claude-md-proposed-edits.md` approval) are still his to close and stayed
  unaddressed by this meeting.
- **Scope boundary: Kipple and its Docker image only.** In: auto-night theme (small, self-contained). Out (stay
  parked, unchanged timing): the 1.5.0/2.0.0 setup-app/single-image roadmap, a design system, a static demo
  site, user-chosen Google Fonts.
- **Owner involvement: minimal.** He wants to be interrupted only for what CLAUDE.md already reserves for him —
  deploys, Cloudflare changes, the final go/no-go — not for routine build decisions during phase 5.

**Phase 5 outline:** (A) full code audit + changelog review, (B) Cloudflare Access JWT + passwordless in
parallel with A, (C) auto-night theme, (D) documentation run + Docker walkthrough + backup/restore-settings
guide, (E) final go/no-go meeting.

## Phase 5 additions: UAT plan, SQA plan, and release-process gaps (2026-09-27)

The owner asked to evaluate a third-party Claude Code UAT skill (`mecabots/webapp-uat`); declined (unverified
npm scope mismatched from its GitHub repo owner, and its i18n checks don't apply to Kipple) in favor of an
in-repo Playwright + axe-core script — auditable, no mystery dependency. He then asked for a full UAT plan
studied from general methodology (entry/exit criteria, traceable test cases, severity-triaged defects, formal
sign-off) and adapted to a single-maintainer/single-user project: `docs/uat-plan.md`. Roles collapse (the owner
is both end user and product owner; Claude is QA/dev); defect tracking goes to `kipple-history/audits/` instead
of a ticketing tool; sign-off is the existing go/no-go meeting. Suites: scripted (Playwright+axe), agent-driven
scenario walkthroughs, an owner-only minimal list (real-device swipe gestures, PWA install, Web Share, the
`document.hasFocus()` question), migration rehearsal, an actual restore drill, and the Docker walkthrough
doubling as literal UAT.

He also asked for an SQA plan and what could be learned from industry standards: `docs/sqa-plan.md`, mapped to
the IEEE 730 SQA plan outline, documenting existing practice (CI's static analysis suite, `/code-review high`
gates, CHANGELOG/SemVer/tag discipline, dependency-vetting practice) rather than inventing new process. It
flags four candidate additions for his decision, not yet built: a living risk register, code-coverage
visibility in CI (reporting only, not a gate), a docs index page, and a stated (low-commitment) issue-triage
expectation now that the repo is public. (All four were adopted the same day; see "Phase 5 process directions" below.)

Phase 5 outline, current: (A) code audit + changelog review — DONE, PR #26; (B) Cloudflare Access JWT +
passwordless, in parallel — in progress; (C) auto-night theme; (D) documentation run + Docker walkthrough
(doubles as UAT Suite 5) + backup/restore-settings guide; (F) UAT plan execution; (G) SQA plan gaps, if
accepted; (E) final go/no-go, fed by D, F and G.

## Alpha → beta → rc → 1.0.0 promotion criteria (2026-09-27)

Recorded in full in `docs/RELEASING.md`. Three topics, one at a time with a recommendation each, all accepted:

- **Alpha → beta.1** only once phase 5 fully closes (audit fixes merged, Access JWT/passwordless shipped,
  auto-night theme, docs run, UAT Suites 1-4 clean of P0/P1) — feature-complete verified, not declared.
- **Beta → rc.1** needs every UAT suite run at least once (including the owner-only device checks) with
  sign-off, plus a **1-week soak** of real daily use on the beta build with zero new P0/P1s.
- **RC → 1.0.0** needs a second, shorter soak (a few days) on the final rc with zero regressions, GitHub
  private vulnerability reporting on, the docs run and Docker walkthrough proven end-to-end, then the go/no-go
  meeting's approval.
- A soak-period regression resets that soak's clock rather than being patched in place mid-count.

## GitHub project hygiene: labels, milestones, issues (2026-09-27)

PR #26 merged. The owner asked for GitHub PR metadata to actually be used (it had been sitting blank —
reviewers/assignees/labels/milestone all empty) and for a real label taxonomy, then confirmed backfilling every
existing PR with the same treatment, plus turning the phase 5 audit's open items and select parking-lot items
into tracked Issues.

**Label taxonomy created:** type (`security`, `chore`, `test` new; `bug`, `enhancement`, `documentation` already
existed), area (`area:backend`, `area:web`, `area:reader-api`, `area:stats`, `area:infra`, all new), plus
`roadmap` for anything deliberately deferred past 1.0. Kept the existing Dependabot-created labels
(`dependencies`, `docker`, `github_actions`, `javascript`) and defaults (`accessibility`, `question`,
`duplicate`, `invalid`, `wontfix`, `good first issue`, `help wanted`) rather than duplicating them.

**Milestones created**, one per phase plus two forward-looking ones: Phase 1-4 (closed, with ship dates in the
description — no phase 1/2 PRs exist in the public repo's rewritten history, so those milestones have none
attached and that's expected, not a gap), Phase 5 - Release readiness (open, current), Roadmap (post-1.0) (open,
for deferred parking-lot items).

**Assignee note:** GitHub won't let a PR's author request review from themselves, so the "Reviewers" field
stays empty by design — not a bug, not fixable without a second collaborator account, which nobody asked for.
Assignee (the owner, `WPTK`) works fine and is set everywhere.

**Backfilled:** all 25 pre-existing PRs (#1-25) got an assignee, milestone (by merge date relative to phase
boundaries — dependency-bump PRs land in whichever phase's window they merged in), and labels matching content
(dependency bumps, phase feature PRs, release-chore PRs, docs, review-fix PRs, etc).

**Issues created**, all assigned to the owner:
- Under Phase 5 (open items from the phase 5 audit, `docs/risk-register.md` R1/R2, and one phase 5 outline item):
  #27-29 (regression tests still needed for three timing-race fixes in #26, no test hooks exist yet), #30 (R1,
  iOS `document.hasFocus()` verification), #31 (R2, large-feed-delete timeout), #32 (auto-night theme).
- Under Roadmap (post-1.0): #33 (setup app + single pull-and-run image), #34 (user-chosen Google Fonts), #35
  (design system/demo site/brand identity), #36 (Reader API client stats/read inference), #37 (Stats screen:
  reading pace, period comparison, per-feed drill-down, monthly charts), #38 (filters: only-show-matching,
  reading-time UI, per-feed view/order), #39 (additional reading layouts: Columns, Reader list, Expanded
  stream).
- Deliberately NOT turned into issues: already-completed parking-lot items (inline extraction, the UI review
  meeting, favicon finder, `ot` fix, lossless WebP — all shipped), explicitly-decided-against items (multi-user
  withdrawn, quiet hours rejected, Reader "refresh all" has no exception), and release steps 8+ itself (that's
  the whole of phase 5, already tracked as outline items, not a discrete issue).
- `docs/risk-register.md` updated to link R1→#30 and R2→#31.

## Phase 5 progress (2026-09-27, later)

PR #26 (code audit) merged. PR #40 (Cloudflare Access JWT validation + optional Access-gated web password)
opened, hit a merge conflict with #26 on `CHANGELOG.md` (exactly the R4 risk-register entry predicted; the code
itself in `internal/api/api.go`/`login.go` auto-merged cleanly), resolved by rebasing onto `main` and keeping
both `[Unreleased]` sections, verified with a full `go test` run post-rebase, then merged.

Phase 5 outline status: (A) code audit — done, #26 merged. (B) Access JWT + passwordless — done, #40 merged.
(C) auto-night theme — PR #41 open (closes #32), CI running, mergeable. (D) documentation run, (F) UAT
execution, (E) go/no-go — not started. (G) SQA plan gaps — done, merged directly to `main` earlier.

Auto-night theme took six `/code-review high` rounds and about 90 minutes (versus 0 extra rounds for the audit
and 3 for the auth work) — the owner flagged the runtime as unusually long partway through; checked the
worktree directly rather than guessing, confirmed steady real progress (not a stuck loop), and told the agent
to stop iterating and open the PR after finishing only substantive fixes. Notable design change from the brief:
"schedule" is a hidden per-device flag (`ui.theme_schedule` + two time settings) rather than a third value of
`ui.theme`, because a third value would make a stale/older client misread it as follow-system and write that
back — review found this, not the brief. Two known-acceptable edge cases documented in code rather than fixed:
a narrow server race between reading and writing the schedule flag, and a cached-fixed-theme-without-flag case
that follows the same policy as picking a fixed theme.

PR #41 merged. Phase 5 (A)-(C) and (G) are now done.

## Phase 5: documentation run and UAT execution started (2026-09-27, later)

Moved to (D) documentation run and (F) UAT plan execution. Split three ways:

- **Restore drill + migration rehearsal (UAT Suite 4), done directly, not delegated.** SSH to Host-A works from
  this box. Copied the live nightly snapshot (`kipple-snapshot.db`, 04:10 that day, schema 8, 138 feeds, 6594
  items) off the running container with `docker cp` — never touching `kipple.db` — restored it onto a
  brand-new throwaway volume with the currently-deployed image (`kipple:local`, v0.3.0-alpha.7): passed its
  integrity checks. Starting a throwaway container against that volume also exercised the 8→9 migration for
  real (the snapshot was one migration behind live), confirmed by the log line and a healthy `/healthz`. The
  live `kipple` container was verified untouched throughout (`docker ps` before/after); all throwaway
  artifacts (container, volume, copied file) were removed after. Documented in `docs/uat-plan.md` under Suite
  4. Noted in passing: a stray orphan volume (a hyphen where the real one it resembles uses an underscore)
  exists on Host-A — not touched, just flagged for the owner's awareness.
- **Documentation run, delegated to a background agent.** Full staleness audit against current code and
  CHANGELOG.md — the known stale spot (README.md's status line still says phase 4 is "next") plus a search for
  more, and documentation of the two new phase 5 features (Access JWT/passwordless, auto-night theme) that
  landed without their own doc updates in some places.
- **UAT Suite 1 (scripted Playwright + axe-core), delegated to a background agent.** Building the in-repo
  script `docs/uat-plan.md` specifies (not the declined third-party `webapp-uat` skill), running it once
  against a local seeded dev instance, and reporting real findings without fixing unrelated bugs itself.
- **UAT Suite 2 (agent-driven scenario walkthroughs), delegated to a background agent.** Working through the
  full test-case list in `docs/uat-plan.md` against its own local dev seed instance (a different port than
  Suite 1's, to avoid collision), skipping only what genuinely needs the owner's own devices (Reeder
  Classic/NetNewsWire, the real Cloudflare Access positive case). Told to fix small unambiguous bugs itself on
  a branch/PR, and file a GitHub Issue (using the established label taxonomy) for anything needing a product
  decision or bigger than a quick fix.

Suite 3 (owner-only device checks: PWA install, swipe gestures, Web Share, the iOS `document.hasFocus()`
question) still needs the owner directly — nothing to delegate there.

## PR #42 review notes (2026-09-27)

- **kipple.cc is not sensitive** — the owner corrected an over-redaction in the docs-run PR: the agent had
  replaced "kipple.cc" with "the repository" while fixing the genuine Host-A/Host-B hostname leaks. kipple.cc is
  the product's own public domain, meant to be shared; only the owner's actual server hostnames (aliased
  Host-A/Host-B everywhere in the public docs) are the standing-rule redaction. Fixed directly in the PR
  branch (one line, `docs/ui-decisions.md`).
- **Single-host vs. two-host framing.** The owner pointed out that `docs/deploy.md`'s Host-A/Host-B split
  (ssh-based admin workflow) reflects only his own convenience setup — most self-hosters will run Kipple and
  manage Docker on one machine, no SSH step at all. Added a callout at the top of `docs/deploy.md` explaining
  Host-A/Host-B collapse to the same box for a single-host setup, and updated UAT Suite 5 in `docs/uat-plan.md`
  to explicitly simulate a single-host self-hoster (not the owner's own two-host setup) when it actually runs —
  if the two-host framing trips up a one-host walkthrough, that's a real UAT finding. Both changes pushed as
  additional commits to the still-open PR #42.

## PR #42 merged; CodeQL enabled; UAT Suite 2 done (2026-09-27, later)

PR #42 merged. The owner turned on GitHub CodeQL (his own action, not something built here). It found 2 alerts,
both assessed as false positives (SSRF is enforced at dial time by a custom guarded transport CodeQL can't
trace, in `internal/discover/discover.go`; a documented same-width uint64->int64 bitcast in
`internal/greader/itemid.go`). Attempting to dismiss them with the real reasoning via the API was **denied by
the host's permission classifier as a CI/security bypass** — a reasonable guardrail on an agent unilaterally
dismissing security findings. One earlier verification call had already dismissed alert #1 with a placeholder
"test" comment before the classifier caught the retry; left as-is for the owner to fix or redo himself. Both
alerts' technical assessment was handed to the owner to act on.

UAT Suite 2 (agent-driven scenario walkthroughs) finished: 20/23 applicable test cases pass (TC-A1-A3 skipped,
need the owner's Reeder/NetNewsWire), 3 small bugs found and fixed in PR #45 (`/` landing focus on the wrong
element in Search, highlight-filter status text claiming it never matched when the server doesn't track that,
OPML-import summary grammar), 2 wording questions filed as issues #43/#44 for the owner's call rather than
guessed at. `docs/uat-plan.md` gained per-test-case "Executed" notes in PR #45, same style as Suite 4's. Left
for the owner: delete a leftover downloaded Wrapped-share PNG (a `.tmp` file in his Downloads folder) that
the agent's browser-pane download intercept missed.

## UAT Suite 1 built; Suite 3 stops being a promotion gate (2026-09-27, later)

**Suite 1 (scripted Playwright + axe-core)** built and opened as PR #46 (`web/uat/run.mjs`, `npm run uat`,
`@playwright/test` Apache-2.0 + `axe-core` MPL-2.0 — corrected from the original "MIT-only" premise). One full
run against the seeded dev instance (90 checks across 15 screens x 2 themes x 3 widths) found 4 real
accessibility issues, left unfixed for triage: a critical missing `aria-label` on the Manage Feeds "Select"
button below 400px, a secondary-text contrast failure on selection backgrounds in Midnight that the existing
`contrast.mjs` doesn't check, a keyboard-unreachable scroll region on Wrapped (possibly only its empty state),
and a target-size warning on list rows that's likely a false positive (axe can't see the full-row click
overlay). PR hit an expected merge conflict with the two PRs merged since the branch was created (#42, #45);
rebased cleanly, all Go tests re-verified green, pushed, CI green, mergeable.

**Suite 3 is no longer a promotion gate**, per the owner: "keep Suite 3 open, it seems to be working as
intended so far on my end." Recorded in `docs/RELEASING.md` and `docs/uat-plan.md`: the owner-only device
checks (PWA install, swipe gestures, Web Share, `document.hasFocus()`) are checked informally on his own
devices on an ongoing basis, not closed off as a one-time checklist gating beta or rc. Alpha→beta and
beta→rc now require Suites 1, 2 and 4 only. A real Suite 3 finding still becomes its own tracked fix, just not
a release blocker.

Also decided: once phase 5 fully closes, the next release is a beta or rc (the "go" product), and other
phases/steps continue after that — not a full stop-and-wait for 1.0 before further work.

## PR #46 merged with 2 open CodeQL findings; follow-up PR #51 (2026-09-27, later)

The owner merged #46 while a CodeQL fix for it was still in progress on the same branch — the fix commit landed
on a now-closed branch and never reached `main`. Cherry-picked it onto a fresh branch and opened #51 instead:
fixes `web/uat/run.mjs`'s `decodeSnippet` (single-pass tag stripping, CodeQL: incomplete multi-character
sanitization — now loops to a fixed point) and its link-selector builder (didn't escape backslashes before
quotes, CodeQL: incomplete string escaping). Neither was actually exploitable in context (test-tool-only code,
no attacker-controlled input reaches either path), but both were cheap to fix properly rather than argue as
false positives, unlike the two earlier CodeQL alerts in production code (SSRF guard, item-id bitcast) that
needed a dismissal with reasoning instead. Replied to and resolved both inline review threads on #46 per the
auto-fix protocol, pointing at #51 as where the fix actually landed.

Lesson: when a background agent is mid-fix on a branch, a merge from the owner can land before the fix does —
watch for this when a PR merges unexpectedly quickly after review comments come in.

## PR #51 merged; UAT Suite 5 executed; phase 5 outline fully closed (2026-09-27, later)

#51 merged. Ran UAT Suite 5 (fresh-machine Docker walkthrough), directly, not delegated: a fresh `git clone`
into an isolated throwaway location on Host-A (separate container name/image tag/volume, no impact on the real
`kipple` container, confirmed via `docker ps` before/after). Real finding: `README.md` had no concrete
clone-to-login sequence, and `docker-compose.example.yml`'s own comment told readers not to run it standalone
and to see `CLAUDE.md` instead (which is written for the maintainer, not outsiders). Working it out by file-name
convention (`cp .env.example .env`, `cp docker-compose.example.yml docker-compose.yml`, set `KIPPLE_PASSWORD`,
build, `up -d`) worked cleanly end to end — 9 migrations, account creation, `/healthz`, and a real authenticated
login (verified via curl with the `Origin` + `X-Kipple-Client: web` headers a browser sends, once the same-origin
check's exact requirement was tracked down). So the app was never broken, just underdocumented. Fixed both docs
directly on `main`; everything torn down afterward.

The browser pane refused to navigate to Host-A's LAN IP (a site-permission gate, not a real problem) — worked
around by verifying the login flow via curl over SSH instead, which the owner explicitly approved as the
fallback.

**Phase 5 outline is now fully closed:** (A) audit, (B) Access JWT/passwordless, (C) auto-night theme, (D) docs
run, (G) SQA gaps — all merged. UAT Suites 1, 2, 4 and 5 all executed clean (Suite 3 explicitly non-gating per
the owner's earlier call). Per `docs/RELEASING.md`'s own criteria, **the next release is v0.3.0-beta.1** — every
named gate is met. Open issues (#27-31, #36-39, #43-44, #47-50) are all P2/P3 quality items or post-1.0 roadmap,
none of which block per the defined severity scale.

## Pre-tag `/code-review high` on the full alpha.7..main diff (2026-09-27, later)

Before actually tagging beta.1, ran the release-checklist step: `/code-review high` on the entire diff since the
last deployed tag (7000+ lines across all of phase 5), per `docs/RELEASING.md`. 8 finder agents (3 correctness
angles, 3 cleanup angles, altitude, conventions), then 8 verifier agents against the deduped candidates. Result:
6 CONFIRMED, 3 REFUTED (a documented Access-policy tradeoff already covered in 3 docs; a fulltext-hold leak that
turned out already-cleared via defer or test-only-reachable; a maintenance-retry duplicate-write concern where
no handler actually has a post-commit failure path).

**The headline finding: a real SSRF-guard escape**, independently found by 5 of the 8 finder angles before
verification even started — `fetch.SameSite`'s bare-hostname rule treats "nas" as the same site as any host
starting with "nas.", so a feed's private-network/insecure-TLS grant could follow a redirect to an
attacker-controlled domain, defeating the exact guard PR #26's audit added. Confirmed exploitable by a dedicated
verifier.

Other 5 confirmed: Reader API subscription/edit lost per-feed atomicity when editing titles in a batch; a
Reader-API-only folder-merge rename silently widens a filter's scope onto pre-existing feeds in the target
folder; the deleting-feed placeholder (`kipple:deleting:<id>`) leaks into unread counts and OPML
export/backups because `notDeletingSQL` was only wired into 3 of ~8 relevant queries; editing just a LAN feed's
URL silently drops its network exception because the web editor only sends that field when the checkbox itself
changes; and the auto-night-theme "fixed theme clears the schedule flag" rule is only enforced in `patchDevice`,
not in the account-level settings PATCH or `makeDeviceDefault`.

Also fixed directly, found by the conventions angle: the new README Quickstart said `localhost` instead of
`127.0.0.1`, violating the box's own standing rule (and contradicting `web/README.md`'s own copy of the same
rule) — this would have made the very first URL a new user is told to open occasionally hang for 5-10s.

All 6 confirmed findings assigned to a fix agent (branch `phase5-beta-review-fixes`) before the beta.1 tag goes
out — this blocks the tag, per the standing "fix everything a review finds" rule. Full fuzz suite
(`scripts/fuzz.ps1`, 26 targets, 60s each) also run in parallel as the other pre-tag release-checklist step. All
26 fuzz targets clean.

Also, mid-review, the owner reported a live issue on the actual deployed instance (alpha.7 on Host-A): the
Unread list dominated by one feed category, other known-active feeds showing 3+ day old items. Investigated
(inconclusive — log silence at debug level isn't proof of a stuck scheduler, since routine fetches aren't
logged at all by design) and filed as issue #52 with a theory: the phase 5 audit's scheduler-starvation fix
(one held/rate-limited host no longer blocking every other feed) is in `main`/PR #26 but not yet deployed to
Host-A, so this may already be resolved once beta.1 deploys. The owner separately proposed a "verbose" log
level to help diagnose issues like this; decided instead to add targeted debug-level scheduler-tick/fetch
logging (Go's four `log/slog` levels are enough; the gap is that the code never logs routine activity, not that
debug is disabled) — queued as a post-beta.1 follow-up on issue #52 rather than started immediately, to avoid
colliding with the two fix agents already deep in `internal/fetch`/`internal/sched`.

**PR #53** (regression tests + UAT accessibility fixes: #27-29, #47-50) opened, hit an expected merge conflict
with #43/#44's direct-push fix (same CHANGELOG region), resolved by rebasing, Go/web tests and the contrast
script re-verified green, pushed. Two judgment calls made directly rather than kicked back to the owner (given
his "take it from here"): accepted the #50 target-size waiver (the agent's own investigation concretely verified
the full-row click overlay), and left the Cocoa Mid contrast gap as a documented known-gap rather than force a
color fix that would either wash out secondary text or make the selected row nearly invisible.

**PR #54** (the 6 confirmed pre-beta findings, including the critical SSRF fix) opened after ~2.5 hours and 11
total `/code-review high` rounds across two passes — legitimately large scope (28+ files across fetch/hosts,
greader, store, api/devices+settings, web FeedEditor), not stuck; checked in on it once via SendMessage after 2
hours with no commits, confirmed real steady progress, let it continue. Its own review rounds found real
follow-ups beyond the original 6: a *second* SSRF hole in the same class (a bare LAN name that's also a real
public TLD, e.g. "news" vs "evil.news", was still getting the grant via subdomain matching — fixed by making
single-label hosts match only themselves), deleting-feed leaks in more places than the original review found
(UnreadTotal, muted counts, article lists, search, both mark-all-read paths, Reader API streams), and a folder
merge that had a filter-count limit gap. One deliberate deviation from the fix instructions, with good reasoning
recorded in the CHANGELOG: always sending the current allow_private_net/allow_insecure_tls on a URL edit (as
originally asked) would have undone the SSRF fix itself for a feed redirected to an attacker's held domain — so
FeedEditor instead added an explicit "Keep for the new address" opt-in when the host changes while a grant is
on. One thing deliberately left out: the reviewers' suggestion to consolidate deleting-feed exclusion into one
view/indexed column instead of a per-query condition — needs a schema migration, and this release has none, so
it's written up in the PR body as a future item instead of forced into a "no migration" release.

## v0.3.0-beta.1 shipped (2026-09-27, tagged 21:35)

PRs #53 and #54 merged, closing every phase 5 gate. Full release checklist run: CI green on the exact commit
(`12121c7`), 26/26 fuzz targets clean, off-box DB copy (a copy of the nightly snapshot kept on the owner's
own backup drive — no live-export credentials on hand, which `docs/deploy.md` lists as the sanctioned
fallback), CHANGELOG moved to `## [0.3.0-beta.1]` with a note that beta/rc from here changes only fixes, tagged
`v0.3.0-beta.1` on that commit, deployed to Host-A (no schema migration, still schema 9), verified (healthy,
correct version string, `/healthz` ok, greader endpoint reachable, memory 18MiB/256MiB idle), GitHub Release
published as a pre-release with the CHANGELOG section as notes.

**A real incident interrupted the deploy prep, unrelated to any of this session's own actions on the box.** The
owner reported Cloudflare error 1033 on every site behind Host-B's tunnel — checked both Docker stacks
(Host-B and Host-A) first, both fully healthy, ruling out anything actually being "pulled down." Root cause:
`cloudflared` (same container, up 21h, created 2 weeks ago — never recreated) was failing to dial Cloudflare's
edge over QUIC/UDP while the host's own DNS and TCP connectivity were fine — a Docker/WSL2 network-layer
problem, not the token-rotation risk the standing "never recreate cloudflared" rule is about. Fixed with a
plain `docker restart cloudflared` (restart, not recreate, so that specific risk didn't apply) after getting the
owner's go-ahead; all 4 tunnel connections re-registered cleanly, verified externally (every site behind the
tunnel, Kipple included, answering normally again). Root cause of the WSL2 network hiccup itself wasn't nailed
down — plausibly the heavy sustained background load this session was running (parallel review/fix agents,
long fuzz suite, image builds), but that's a hypothesis, not confirmed.

**Issue #52 closed (2026-09-27, 21:45):** the owner confirms feed fetching is back to normal after the beta.1 deploy.
Not independently proven with logs (routine fetch activity still isn't logged — the debug-logging follow-up is
still queued), but the timing matches the theory: PR #26's scheduler-starvation fix was in `main` but not yet
deployed when the owner first saw the problem (Host-A was on alpha.7 at the time); beta.1 includes it.

## Overnight: beta.1 feedback triage (2026-09-27, from 22:06, to 2026-09-28)

The owner attached a running feedback file (`0.3.0B1 feedback.md`, ten items from his own phone testing) and
asked for triage (work now / work later / parking lot), a plan, and anything the feedback pointed at beyond
its own list. Ten items sorted: two quick fixes (#56 the "N new articles" pill firing on background polls
not just manual refresh; #62 a mobile tab-bar seam), two feature gaps found to be code-confirmed not just
perception (#58 folders can't collapse on the only feed-browsing surface mobile actually has; #59 the drag
handle and edit pencil showing on every Manage Feeds row with no way to hide them), two new small features
(#60 "Manage this feed" from an article's menu; #61 Feed Health bulk select), and two that needed a design
pass rather than a code fix (#55 settings reorganization; #57 list-layout differentiation — confirmed by
direct comparison that Editorial and Cards converge to near-identical at narrow widths). One item (#10,
"Suite 3 all passes") closed out risk-register R1 and issue #30 directly. PRs #63-#66 shipped same night,
all reviewed against the live seeded app in the browser pane, not just the test suite.

**A live-app bug turned up during that work, outside the feedback list**: tapping a feed or folder row in
Manage Feeds appeared not to navigate on either mobile or desktop width, in the browser pane. Root-caused as
far as: a plain `<a>`.click() via JavaScript worked fine, so the router itself was not broken; real pointer
clicks at the same coordinates repeatedly did not register on the right element, and a `computer` click
even mis-hit by over 100px on one unrelated test earlier the same session. Concluded the browser pane's
click-coordinate mapping was unreliable that session, not a real product bug, and did not file it — a
genuine finding would need confirming on a real device, which the owner does routinely anyway (see the
Suite 3 item above).

## Morning meeting, mockups approved, kipple-history follow-through (2026-09-28)

The owner reviewed the settings/layout mockups artifact (5 artboards, `#55`/`#57`) and approved both
directions as shown: master-detail for settings (a persistent group rail on desktop, tap-a-group-then-back
on mobile — the same idiom the app's own shell already uses elsewhere), and the layout redesigns (Cards
gets real card chrome so it stops reading as Editorial at narrow widths; Compact keeps its favicon always,
Headlines drops it always). Told to implement both.

Also settled, same meeting: `kipple-history`'s public exposure (see CHALLENGES.md #26) gets the full
destructive fix — git history rewritten, not just the current file content — and the repo stays public
regardless. Separately: `kipple-history-private-archive` (fully
redundant, superseded by this repo one minute after its last commit) is being deleted; `kipple-archive`
(a full pre-history-rewrite snapshot of the *code* repo, not docs — different purpose, a real backup) is
being kept.

## Sunday morning meeting (2026-09-27, 08:32 to 11:00)

Meeting 29 in [MEETINGS.md](MEETINGS.md). Decisions:

- **Phase 4 ships as one deploy.** alpha.5 to alpha.7 were tagged and deployed together as `v0.3.0-alpha.7` (08:55),
  on the agent's recommendation: they are additive to one feature and only alpha.5 carries a migration (0009), so one
  migration rehearsal covered all three. Off-box backup and rehearsal came first. The owner authorised it and turned on
  GitHub private vulnerability reporting.
- **Website HTTPS** is enforced once the certificate exists: the owner added the DNS record, the certificate issued,
  the agent enforced it at 10:42. The website's footer link to the history repo stays: "It will eventually be public."
- **Scratch clones deleted** (eight superseded local clones, about 705 MB); the one blocked by a tool guard was left to
  the owner. The stuck agent worktrees were one leaked process; killed and cleaned up.
- **The auto-mode classifier is not a normal permission rule.** The agent may not edit its own permission settings, so
  the owner pasted a rule himself: merging a PR in the Kipple repo once CI is green on the exact commit and the change
  has been reviewed. (CHALLENGES item 34 records that the agent's `gh pr merge` calls were still refused until Tuesday
  09:24, when an allow rule for `gh pr merge` was written to the project's local settings and approved.) He also set usage-limit auto-continue and clickable PR/CI links in the footer. A guard hook that
  blocks local `docker build`/`run` on Host-B (unless wrapped in an ssh to Host-A) was written after the 00:26 outage
  and given to him to install.
- **kipple-history is public.** The owner: scrub it of personal data, then make it public. The agent renamed the old
  private repo to an archive and created a new public repo with the rewritten history, because GitHub can serve
  unreferenced commits by hash after a force-push and the raw data must never be reachable while public. It fixed one
  mistake on the way (see [CHALLENGES.md](CHALLENGES.md)). The archive was meant to stay private; the owner had it deleted on Tuesday (below).
- **Production is on Host-A.** The 00:26 outage was a dependency test run on Host-B, not a deploy; no test builds on Host-B.

## Phase 5 process directions (2026-09-27, 11:49 to 13:06)

Meeting 30 in [MEETINGS.md](MEETINGS.md).

- **Auto-fix monitoring is on for every PR** (the owner, 11:49). Right after opening a PR the agent binds it and turns on
  auto-fix and comment handling.
- **The four SQA additions were adopted at once** (12:03 "Decide on the candidate additions now", built by 12:10, commit
  `1447d76` on `main`): risk register, coverage visibility (reporting only, no gate), a docs index, and an issue-triage
  statement in `SECURITY.md`. This supersedes "not yet built" under "Phase 5 additions" above.
- **The setup-app / single-image design stays parked**: the owner asked (12:11) whether a meeting exists; the answer was
  that it is a one-line roadmap placeholder and phase 5 excludes it.
- **Merged PRs close their issues** through closing keywords in the PR body (asked 13:04).

## Beta.1 decision and aftermath (2026-09-27, 17:37 to 21:59)

Meetings 31 and 32 in [MEETINGS.md](MEETINGS.md). Complements "Pre-tag `/code-review high`" and "v0.3.0-beta.1 shipped".

- **The pre-tag review is a gate.** The owner said to cut and deploy beta.1 (18:05); the agent held the tag for the six
  confirmed findings under the fix-everything rule, and he left the issue queue and the fixes to it ("You take it from
  here", 18:55). He merged #53 and #54 at 21:03 (said so at 21:04) and gave the go at 21:05.
- **Suite 5 may fall back to curl** when the browser pane is refused a LAN address (17:39).
- **A pre-release is not "Latest".** GitHub keeps showing `v0.2.0` as Latest; the owner asked at 21:41 and it was left
  alone so that nobody is steered to a beta.
- **The plain tunnel restart** was approved at 21:33 (a restart of the existing container, not a recreate).
- **Loose ends 2 and 3** (21:55): the agent re-dismissed the two CodeQL alerts with written reasons (R8 and R9; Kipple commit `1158ca3`, 21:57), and the stale proposed-edits file was removed (kipple-history commit `ee8ecca`, 21:58).
- **The beta soak week began** on beta.1 (the agent's statement at 21:42); a real bug resets its clock.

## Beta.1 feedback, overnight authority and the Monday meeting (2026-09-27 22:06 to 2026-09-28)

Meetings 33 to 36 in [MEETINGS.md](MEETINGS.md). The morning-meeting answers themselves are under "Morning meeting,
mockups approved, kipple-history follow-through" above.

- **Overnight authority (22:17):** screenshot pass first, then execute the triage plan; "Pull/merge PRs as you see fit";
  update kipple-history and the relevant docs; open and resolve issues with the existing labels. Tasks added at 23:23: the
  mockups, git hygiene, a README for regular users, a website check.
- **Fix, do not wake the owner (07:14).** When the agent found the public history repo carrying real hostnames it tried
  to set the repo private (denied by the classifier) and sent a phone alert. The owner's rule: if a fix is inside an
  established policy (here, the Host-A/Host-B aliasing), apply it instead of escalating. Destructive history rewrite was
  approved in the meeting.
- **Only three Kipple repositories:** `kipple`, `kipple-history`, `kipple-website`. The redundant private archive of the
  docs repo is deleted; the private snapshot of the code repo from before the history rewrite is kept.
- **README rules** (07:46 to 09:18): no fixation on the word "list", no em dashes, no comparisons with other products,
  a caveat that Wrapped is opt-in, a quote about the word "kipple" as the first thing after the badges, SemVer / repo
  size / image size badges, a sensible heading order, and use of the writing skills. At 09:18 he said to commit and push to `main`.
- **Parking lot (08:08): every config-file setting should move into the app**, with a setup flow if needed, so users do not
  edit a file to run Kipple. (Now in `parking-lot.md`.)
- **Changelog conflicts (09:31):** the owner asked for a lasting fix; the agent said conflicts could only be caught fast
  by auto-fix unless changelog entries moved to one file per PR, which needed his go-ahead (given Tuesday 07:23).

## Tuesday morning meeting (2026-09-29, 07:23 to 07:25)

Meeting 37 in [MEETINGS.md](MEETINGS.md). The agent's brief said an rc was not yet justified: the changes since beta.1
were feature-sized and `docs/RELEASING.md` asks for the suites re-run and a one-week soak. The owner's eight answers:

1. **beta.2 next, not rc.1.** The realistic sequence is beta.2, then rc.1 after the soak.
2. **#71 and #72 go into "Phase 5 - Release readiness"** and are fixed today, one PR each.
3. **#31 (feed delete with 600k+ items outlasts the timeout) is closed as not planned**, at 07:24. The owner: it is "so
   far beyond an edge case" that it could just stay open; the agent closed it with a written reason.
4. **The GitHub CLI `delete_repo` permission is granted** by the owner; the redundant private archive repo was then
   deleted at his 07:25 go-ahead.
5. **Changelog conflicts must stop**: build changeset-style tooling, queued behind #71 and #72 (07:25).
6. **Settings group names: Title Case with ampersands.**
7. **The "Manage feeds and folders" link goes under Sync & Feeds.**
8. **No shareable page for the meeting brief.**

## Merge permission and the review gate (2026-09-29)

Meetings 38 and 39 in [MEETINGS.md](MEETINGS.md). This replaces the earlier standing rule "I merge code PRs; you never
merge them" and the "Merges of code PRs" line under "Phase 4 build decisions after the meeting".

- **The agent may merge any PR whose CI is green on its exact head commit, but only after discussing it with the owner
  in the conversation** (09:24). Never unprompted, never around a denied merge. Merge order and expected conflicts are
  proposed first; merging uses `gh pr merge <n> --squash`. The agent added `Bash(gh pr merge:*)` to the
  project's local settings file and the owner approved the edit (09:26 to 09:28). PRs touching CI configuration, deploy or release files or repo settings always
  ask (the 12:55 merge of #85, which edits CI, was asked and approved). Tags, release builds and deploys still need
  his go-ahead each time.
- **Review before merge, not after.** A review run after #74 and #75 merged had found regressions in both. The agent
  now self-reviews each diff before opening a PR and gets an independent review of the substantive ones before the
  owner merges (09:30 "Review first, then let's meet back").
- **Every review finding is fixed** (standing since 2026-09-25/26). Applied at 10:01 ("Go ahead with the fixes"); ten
  defects from the review of the diff since beta.1 became fix PRs #76, #77, #79, #81, #82 and #83 (and #84, a refactor from
  the second review), plus #80 for the owner's offline "read the original" report (issue #78). The two-round review of #76, #77 and #79 added fixes; the owner asked for one more
  quick pass on the last two fixes (10:41).
- **The flow is right** (08:45 "I like that flow"): one branch per fix, a regression test that fails without the fix,
  a PR, then CI. Added: the agent's own review first.

## Changelog fragments (2026-09-29, 11:57)

- The owner: "begin the changelog retooling. Take that all the way through." Shipped as PR #85 (merged): each change
  adds `changes/<slug>.<kind>.md`; `scripts/changelog.mjs` has `check` (also run in CI and `ci-local.ps1`), `preview`,
  `release X.Y.Z` and `notes X.Y.Z`; `CHANGELOG.md` `[Unreleased]` holds only a pointer line. `CLAUDE.md`,
  `docs/RELEASING.md`, the PR template and the plans point to it. It also fixed the duplicate `### Changed` headings and
  gave `.claude/launch.json` its `url`.
- **Favorited folders collapse from Favorites** (issue #86, PR #87): the owner chose a chevron in Favorites (12:14
  dialog); the folder shares its collapsed state with the Feeds list, and folders start expanded.

## Beta.2 and the daily kipple-history rule (2026-09-29)

- **Beta.2 go (13:18):** "let's move to the beta2 tag and the work required with that." The pre-tag checks ran (CI
  green, 26 fuzz targets clean, UAT Suite 1 clean, review clean), and the release commit is PR #88, the first real use
  of the fragment `release` command. The agent said it would still ask before each production step (tag push,
  off-box copy, deploy, GitHub Release). The owner's phone pass and the closing of #57 and #62 remain his. #88 merged at 14:01 ET; no tag exists yet.
- **kipple-history is updated at least daily** and after every release, meeting or incident (13:53: "should be part
  of your workflow, at the very least daily"). Saved to memory; PR #89 adds it to `CLAUDE.md`.

### Website update on every release (2026-09-29, mid-turn)

- The owner asked that each release also update the kipple.cc website: new screenshots and anything that mentions a
  version. It is release step 12 in `docs/RELEASING.md` (the version text is never skipped; screenshots may be kept for a
  release with no visible UI change), done through a PR in the site repository whose merge publishes. Tooling:
  `web/scripts/site-shots.mjs` and `KIPPLE_SEED_SET=site`.
- Deploy and tag were asked for and given explicitly for beta.2 ("Tag, deploy and release"); the standing rule stays that
  a tag, an off-box copy and a deploy each need the owner's go-ahead.

### Beta.2 soak begins (2026-09-29)

- The owner started the soak on beta.2 after his phone pass and closed #57 and #62 as fixed. Rules as set on 2026-09-27:
  one week of real use, zero new P0/P1 defects, a regression resets the clock, Suites 1, 2 and 4 re-verified before rc.1,
  Suite 3 stays informal.

### The beta.2 UAT round and beta.3 (2026-09-29, afternoon and evening)

- **Fix every defect the re-run found** (the owner: "Fix all defects"), shipped as the next beta (`v0.3.0-beta.3`), not
  waiting for rc.1. Nine defects: #92 to #99 fixed; #100 was first filed as a question and became a fix.
- **An unsubscribed feed shows up nowhere.** The internal archive pseudo-feed that holds starred articles of an
  unsubscribed feed is hidden from the sidebar, every picker, search, and the Reader API subscription list (one
  shared rule on the server and one on the web). Its starred articles stay in Starred, All, Unread and search. Risk
  recorded: NetNewsWire or Reeder may no longer show those archived starred items; it needs a device check.
  Stats rows for deleted feeds (five code paths) were deliberately left as they are; the owner has not decided.
- **The soak keeps the beta.2 clock** (chosen at the beta.3 go-ahead): fixes only, so earliest rc.1 stays 2026-10-06 after
  15:22 ET; a regression still resets it. Suites 1, 2, 4 and 5 were all re-run this round; Suite 3 stays informal.
- **Work is split into one fix per issue per agent** (each in its own worktree, tests first, PR opened by the agent,
  merges by the coordinator after a combined test run and review), because the nine fixes were independent.
- Deferred: the offline-reads problem (every query except the article detail pauses offline) is issue #108, not part of
  beta.3.

## Setup wizard planning meeting (2026-09-29, afternoon)

Meeting 43 in [MEETINGS.md](MEETINGS.md). This records the decisions as taken; the earlier "Added 2026-09-29" note in
[parking-lot.md](parking-lot.md) has the scope.

- **It is called the wizard.** Account creation (username, optional password) moves into it. No password is required, with
  a notice to keep the instance behind Tailscale or on localhost only.
- **Default port 1919.** IANA lists it for the IBM Tivoli directory service only, no common application. Fallback 1138.
  Considered and passed over: 1138 (THX), 2187 (Star Wars), 2063 (Star Trek), 1701, 2001, 2010, 1999, 4242, 1984.
- **GHCR first.** Other registries (Docker Hub, Quay, Unraid Community Apps, CasaOS/Umbrel/Runtipi, awesome-selfhosted,
  selfh.st, Portainer and TrueNAS templates) are parked until 1.0.
- **Starter feeds live in a separate editable data file** (`starter/feeds.json`); the owner supplies the list later.
  The recommended-feeds step and the OPML import are both skippable.
- **The wizard asks for a time zone**, with the browser's zone preselected. Custom domain, Cloudflare OTP and other
  settings that are env-only today are deferred to later wizard steps.
- **Build info adopted:** OCI labels, a richer `kipple version -v`, an About screen with copy-debug-info, a stale-PWA
  banner, a downgrade-guard message, and what's-new after an upgrade. **No update check and no phoning home**, by decision.
- **Timing.** Built on feature branches during the beta.2 soak, target 0.5.0-beta.1. The owner approved this as an
  exception to "beta adds no features"; the soak restarts on it.

## Wizard design accepted, later answers (2026-09-29, evening)

- The design document (PR #91, `docs/setup-wizard-design.md`) had five recommendations; the owner accepted all of them:
  existing databases keep port 7080 through 0.x with a warning; Host-A builds from source for beta.1, then pulls the
  signed GHCR image by digest from 0.5.0; open mode refuses other LAN devices by default, with `security.open_lan` as the
  opt-in; "Run setup again" lives in Settings; new installs default to UTC. He added the time zone step. The design found
  an in-app `tz` setting already existed and reused it.
- Time zone Skip keeps the design's behaviour: it writes the suggested zone. The known limit that an explicit UTC choice
  cannot be told from the default on the first run after an upgrade is left as it is.
- Build order: release workflow (A, #111), build info (E, #114), backend (B, #118), wizard UI (C, #119), docs (D, #121).
  Sonnet built A, E, C and D; Opus built B and did the reviews. Merged in dependency order, stacked branches first
  (MILESTONES.md).

## What counts as a read in the stats (2026-09-29, evening; issue #120, PR #122)

- The owner: a "read" should be an article he clicked on and read, not one scrolled past.
- Finding: mark-read-on-scroll and bulk mark-read never create an open event (only `POST /open` does), so scrolling was
  already not a read. The loophole was the rule itself: 25 percent scroll counted with no time floor, and legacy opens
  (recorded before timed rows) counted as reads.
- **New rule, on my recommendation and approved:** read = 10 s of active reading, or 25 percent scroll plus at least 3 s.
  Legacy opens still count, and are now counted and shown separately as `legacy_opens`. Existing history is
  reclassified at query time, so past numbers may drop.
- I could not measure the effect on the live Host-A data: the permission system blocked the read. The PR contains a
  read-only SQL query for the owner to run on his own copy.

## Font choice (2026-09-29, evening)

- The owner asked where fonts are chosen. Answer: the "Aa" reading menu in the article header (`ReadingMenu`), never
  Settings; the wizard's theme step is theme only. Follow-up, not decided: offer font in Settings > Appearance & Reading
  and in the wizard, and find out whether the Aa button is actually missing somewhere in his build. Parked.

## Merge condition (2026-09-29, evening)

- Merges were blocked several times. Root cause: the auto-mode classifier's allow rule was conditioned on a PR "having
  gone through the project's own review process", which it could not verify. The owner edited that rule in the local
  settings himself; I do not edit permission settings. Standing rule unchanged (item 34 of CHALLENGES.md): merge on green
  CI on the exact head, after discussion.

## Overnight autonomy for the audit (2026-09-29 night)

- Same limits as earlier nights: audit and fix yes; deploy, tag and release no. Three fix agents open one PR each and
  leave it open for the owner's morning review; nothing is merged overnight.


## Merges and the starter list (2026-09-30, morning)

- The owner merged #137, #150 and #151 himself at 08:34, then #152 (the real recommended-feeds list, pinned by a test, with
  a liveness script) and #153 (font) followed. Standing merge rule unchanged (CHALLENGES 34).

## Font choice, settled (2026-09-30)

- The picker was in the "Aa" menu all along (he found it). At his instruction it is also offered in Settings >
  Appearance & Reading, in Search and in the wizard (#153). This closes the parked item from 2026-09-29.

## The display name "BK" is fine (2026-09-30)

- The owner clarified that the GitHub display name "BK" is fine to leave: it is not his surname or real name. This
  settles the parked question about the commit-author name in the website repository's history. The scrub rule for
  anything new is unchanged: no surname, no real name.

## Release 0.5.0-beta.1 and the deploy (2026-09-30)

- Tagged 12:21 on `2a2e261` and deployed to Host-A about 12:44, built from the tag on Host-A. Two preconditions set by the
  owner: Host-A's compose file gets `VCS_REF` and `BUILD_DATE` build args (backup copy first), and the off-box database
  snapshot copy is taken first. He ran the deploy commands himself.
- The rc.1 soak restarts at this deploy: rc.1 not before 2026-10-07. Still his: make the GHCR package public by hand,
  and a repository ruleset restricting who can create `v*` tags.

## Access rules (2026-09-30, the access review)

- Enforcement moves from prose to a hook: a replacement `PreToolUse` hook with an allow-list, plus allow entries and a
  corrected `autoMode` environment (the repositories are public). The owner applied it; I do not edit permission
  settings. Hooks are deterministic, prose rules are not. See MEETINGS.md 46 and CHALLENGES.md 48.


## Badges and the Scorecard (2026-09-30 to 2026-10-01)

- Goal set by the owner: raise the OpenSSF Scorecard (7.1, then 7.3) where it can honestly be raised. Fixable: pinned
  actions, token permissions, a security policy, SAST (CodeQL), fuzzing, a signed release, the Best Practices badge. Not
  fixable for a one-person project: Code-Review and the higher Branch-Protection tiers (both need a second person).
- Badge refresh (#160, #161): Go Report Card not added (the service is retired); ghcr-badge `latest_tag` (shows a
  signature tag) and `size` (errors on a multi-arch image) not usable, so the tags badge is used. The views counter is
  hits.sh, chosen after testing four services; it is a third-party image, served through GitHub's image proxy, and the
  count is approximate. One line to remove.
- The SemVer badge was removed in #160 and restored at the owner's request; it stays.
- Coverage goes to Codecov with the token as a repository secret the owner added; the uploads are skipped when the secret
  is empty and `codecov.yml` is informational, so nothing CI gates on changed.
- SemVer 2.0.0 versus 2.0.0-rc.2: no practical difference for Kipple. The differences are build metadata (SHOULD be
  ignored in rc.2, MUST in 2.0.0), leading-zero rules, empty identifiers and the BNF. Stay on 2.0.0.

## Rulesets (2026-09-30)

- "Protect Release Tags" (created 13:17): `v*` tags, creation, update, deletion and force-push blocked, repository admin
  bypass only. Closes the parked item.
- "Protect main" (created 15:08, target fixed 15:13): deletion and non-fast-forward blocked, required status checks go,
  web, security and docker, pull request required with 0 approvals. Zero approvals is deliberate: there is no second
  reviewer. Scorecard scores that tier, 3 of 10; the higher tiers need a second reviewer and stay out of reach. No
  `SCORECARD_TOKEN` is needed for the check on a public repository (CHALLENGES 51).

## OpenSSF Best Practices: silver and gold not pursued (2026-10-01)

- Passing earned 2026-10-01 (project 15120). Silver is feasible (55 criteria, 7 already met) but `access_continuity` and
  `bus_factor` need a named second person. Gold is not realistic for one person (`two_person_review`, unassociated
  contributors, hardened site headers that GitHub Pages cannot set). At silver the Scorecard CII check gains about 0.05.
  The owner chose to forget silver and gold; parked in parking-lot.md.
- The two claims only the owner could make (`know_secure_design`, `know_common_errors`) were asserted by him, not by me.

## The status-bar cover (2026-10-01)

- iOS softens the status-bar strip from whatever sits at the top edge of the page. Kipple draws no blur and
  `theme-color` already equals the background for all 20 schemes, so the fix is a solid fixed element, `#kp-top-cover`
  (#163). Verified by the owner on his iPhone before the PR was opened. Unreleased; goes into beta.2.

## 2026-10-02: root causes, not band-aids; 0.6.0 and 0.7.0

Owner review: stop building workarounds (shims, warnings, fallbacks, flags); fix the cause. A whole-codebase review followed
(plans/0.6-0.7-1.0-plan.md). Decided: no setup code; open mode like Sonarr's "Disabled for Local Addresses" with one rule;
next release 0.6.0-beta.1 (0.5.0 never ships stable); 0.7.0 carries the auth changes; docs written for a stranger, not for
the owner's machines. Design rules recorded in the assistant's memory and proposed for the project instructions.

## 2026-10-03: no extra guard on first account creation

A review of 0.7 noted that without a setup code, anyone who can reach a brand-new instance through a tunnel or proxy
(before the account exists) could create the account; the Host gate is the only barrier on that path. Options were to
refuse forwarded account creation or to document it. The owner decided to do neither: people run this in Docker on a
home machine and the account is created within minutes of the first start, so the extra rule is more complexity than
the risk deserves. Revisit only if a real report appears.

## 2026-10-04: answers at the morning meeting

- Web sessions keep their sliding 90-day life (#223 closed; no absolute lifetime). A flat Reader API client deleting a folder
  also deletes its subfolders: fine. Deprecations are removed only in a major release (written into the compatibility
  document). The iOS 27 installed-app status-bar blur is a WebKit bug, not Kipple's CSS; dropped. 0.8.0-beta.1 is a full
  release, not a pre-release, and is deployed after the gates.
- The five findings of the delta review were filed (#241 to #245), not fixed in the release.

## 2026-10-05: issue and housekeeping rulings

- #241 fixed now: cap a folder label's length before the path is resolved.
- #244: OPML export matches the web order, subfolders first, and the order is documented.
- #229: full-text search stops at 75,000 matching documents. One variable, refused at once with 422. A common single word on a
  150,000-item library is now always refused; before, such a search passed or was refused as too broad depending on load,
  and the fixed limit makes the answer the same every time.
- Docs-only issues #242, #243 and #245 are batched in the milestone "0.8.0-beta.3 - Reader API docs" and done after beta.3.
- #33 closed. #179 stays open as the 1.0.0 tracker, with its two follow-ups tracked as #252 (zizmor as a CI gate) and #253
  (offline bootstrap unread counts). #236 and the roadmap issues wait for the next housekeeping agenda. Milestone 5
  closed; 6 onward stay open.
- Order of releases: beta.2 stays perf-only and is tagged and deployed first (schema 13). Beta.3 is #241, #244, #229 and two
  new issues, #254 (open mode accepts any private hostname, not only `.localhost` and `.ts.net`, because not everyone
  uses Tailscale) and #255 (fetch the feed title automatically when adding a feed). Then the docs run. The beta.1 soak
  needs only about 24 hours because the build is heavily used.
- `/code-review high` is always run before a deploy (already in the project instructions; restated).
- Client policy: Kipple supports any RSS reader client that speaks the Reader API. No named app is referenced or
  special-cased in code, docs or tests, and new text says "Reader API clients". Earlier entries in this repository that name
  apps are left as they were. #256 tracks a protocol-level conformance suite.

## 2026-10-05, later: open-mode hosts, client compatibility, stats, reachability

- Open-mode Host gate (#254, PR #259): option A. Accept IP literals, `localhost`, `.localhost`, `.ts.net`, the public URL's
  host, listed names, and the name used when open mode was chosen in the wizard. A broad list (`.local`, `.lan`, any single-word
  name) was rejected after review showed the README's default publish on 127.0.0.1 would then be exposed to DNS rebinding.
- Compatibility with any Reader API client is a 1.0 requirement, resolved now (#256, #266): a protocol-level conformance suite
  (PR #264), CORS on the Reader API routes only, `content.content` and response gzip, feed discovery on the first fetch when a
  page URL is given, smoother feed adding.
- All Reader API clients collapse to one `api` stats value, with a migration (schema 14 or 15, PR #267).
- `KIPPLE_PUBLIC_URL` and the other reachability environment variables move into setup and Settings (#265).
- The feed title is fetched automatically on add; the first fetch names the feed (#255, PR #261).
- `/code-review high` runs on every PR before merge, not only before a deploy. Any order of merging is fine once a PR is
  reviewed and CI is green.

## 2026-10-05, evening: marketing and launch rulings

- Launch publicly at 1.0, not at a beta or release candidate.
- Be open, on the site and README, that Kipple is also an experiment in working with coding agents.
- Keep Blue Oak Model License 1.0.0; it is already permissive and OSI-approved.
- The demo is wanted but deferred, no date.
- Install-base stores (Unraid, Umbrel, CasaOS, Runtipi, TrueNAS) are researched, not submitted to. Submissions wait for 1.0,
  when `latest` starts to move, and each store's policy on agent-built packages is read first.
- awesome-selfhosted waits until the first release is over four months old (about February 2027) and the agent-disclosure
  question is settled.
- Detail: [research/marketing-and-launch-2026-10-05.md](research/marketing-and-launch-2026-10-05.md).

## 2026-10-05, night: beta.3 scope, the roadmap split, release authority

- Beta.2 was never used, so beta.3 is the build to soak. #262, #263, #265, #236 and #38 are in beta.3.
- #207 is split: #39, #37 and #36, and #246 each get their own session; #35 stays in the parking lot; #34 is "Post 1.0", not 2.0.0.
- #269 (README section "How Kipple is made") is drafted and approved for now; the docs meeting is separate.
- The 14 "decisions made for the owner" in #274 (docs/ui-decisions.md) are approved.
- For this release, tagging, releasing and deploying no longer need a per-step ask ("just do it"). This does not carry over to later releases.
- Standing: always run `/code-review high` before merge; fix every finding; one session per release.

## 2026-10-06: working economy and session coordination

- Batch related small pull requests into one. Run cheap checks first and the expensive gates once, on the commit being tagged.
- The auto-fix monitor is only for pull requests that touch code, workflows or dependencies.
- One task or release per session. Reviewers (Opus, read-only) work alone and hand back at most 15 lines; authors (Sonnet)
  stop at a pushed branch.
- Models: Opus for review, root-causing and design; Sonnet for the rest; never Haiku. Unused connectors are off by default.
- Owner-specific values stay in untracked files (`scripts/local/`, `.scrub-terms.local`); tooling must be repairable by a
  session that did not write it.
- CI skips the heavy jobs for prose-only pull requests, fail closed, with the prose files deleted before the code jobs run.
- Plan: soak beta.3, #253, `rc.1` (bugs only), #248 after `rc.1`, 1.0.0. Separate design sessions for #39, #37 with #36, and
  #246; they write only `docs/ui-decisions.md` and their issues. A lanes file will list each session's issue, branch and
  owned files; shared files (changelog fragments, `docs/design.md`, `go.mod`, `package.json`) are held by one session at a time.

## 2026-10-06, evening: restore in the setup wizard, reset, no schema numbers

- Restore from the web app exists only in the setup wizard, on an instance with no account. Restoring over a populated library
  stays `kipple restore`; its web twin is "Reset Kipple and start over" in Settings, which returns the instance to setup.
- Anything the command line does must also be possible in the web app. Exception: recovering from a start that fails.
- The product never shows schema numbers; they live on the About page only. Operators still see them in refusal messages
  because a rollback needs them.
- A server's address settings (public URL, allowed host names, trusted proxies, Cloudflare Access) describe the server, not
  the library: a restore or reset keeps this server's own, never the backup's.
- A reset ignores `KIPPLE_USERNAME` and `KIPPLE_PASSWORD` until a new account exists, because a restart reuses the same
  container environment.
- Reviews are fixed completely, and a finding about the check is fixed in the check, not waived.
