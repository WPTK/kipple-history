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
  contributors". Git author stays `WPTK <...@users.noreply.github.com>`. the owner rejected an earlier suggestion that used
  his real name in a copyright line. In this private history repo the first name "the owner" is allowed and the
  surname is not.
- **Pre-public scrub (planned, not done at the time of writing):** before going public, remove or generalise
  hostnames, IP addresses and personal names from committed docs; one family of hostnames contains the surname. the owner
  asked at 10:10 whether to do a preliminary first public publish now to get secrets, hostnames, IPs and names out
  (see [MEETINGS.md](MEETINGS.md) item 19). This repo, `kipple-history`, exists so the diaries and working notes
  can stay private while the code repo goes public.
- **Third-party notices and font licences** are generated and shipped in the image (`517bd2e`).

## Parking lot (deferred on purpose, do not raise until the end)

1. Cloudflare Access JWT validation (`Cf-Access-Jwt-Assertion`, team domain and audience settings, RS256 check).
2. Passwordless or optional-password login, only after item 1 (port 7080 is published on the LAN).
3. A design system, a static demo site and a public pull-and-run image; a Kipple identity or accent colour.
4. A scheduled automatic night theme.
5. User-chosen Google Fonts (see roadmap).

Source: memory note `parking-lot` (summarised here, not copied), [MEETINGS.md](MEETINGS.md).
