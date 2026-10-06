# Design audit before the phase 2 UI and deploy (2026-09-25)

A read-only audit of `docs/design.md` (all of §1-§13), `docs/plan.md`, `docs/research/open-questions.md`,
`docs/PHASE2-KICKOFF.md` and the memory notes, checked against the code on `phase-2` at 90450e9.
It covers `internal/`, `cmd/` and migrations 0001-0003.

**Severity key.** **UI** means the owner should decide before frontend step 6+. **Deploy** means fix or decide
before the first phase 2 Host-A deploy. **Nice** can wait.

---

## 1. Contradictions: design vs design, design vs code

| # | Sev | Where | Conflict | Recommended resolution |
|---|---|---|---|---|
| C1 | Deploy | §13 vs §2.2, §4.4, §4.7, §4.8, §7.1 | §13 was "applied after the red team", but most of it contradicts the body or was never built. Details: (3) `last_new_item_at` vs the `last_new_items_at` column. (4) `image_count` plus 265 wpm vs the §7.1 and code value of `ceil(words/230)` (`store/uiitems.go:24`); `image_count` is in no DDL. (5) `porter` plus `bm25(4,1)` vs `tokenize='unicode61 remove_diacritics 2'` (`0001_init.sql:197`) with plain `rank`. (6) `feeds.ua_mode='browser'` vs the built `ua_fallback` (0002). (8) A redirect migration clears validators vs §4.7 "Validators are kept", and the code keeps them (`fetchcommit.go:528`). (11) Normalized-link uids vs §4.8 "raw link", the frozen uid rules in §11 and `dedup.go:113`. (2, 7, 9, 10, 12) The self-check, Date-relative Retry-After, skip-malformed-item, enclosure dedup and slow-stage WARN are not in the code | Rewrite §13 as a status table with one line per item: built, superseded by §x, or dropped. **Drop 11**: it would change the uids of live items and re-insert a wall of duplicates. Drop 8 for redirects and keep it only for manual URL edits, which the code already does (`feedadmin.go:202`). Keep 230 wpm. Porter is the owner's call (Q9) |
| C2 | Deploy | §11 risk row "Inline full-text extraction can hold a worker up to 60 s" vs decision 19 and §4.3 | Stale. Extraction now runs after the commit in the `ftrun` pool | Replace the row with the real residual risks: a 500-item in-memory queue lost on restart, and the Reader hold window |
| C3 | Deploy | §2.2 DDL vs migrations | The DDL shows 0003's `item_fulltext.error_class` inline but omits 0002's `feeds.ua_fallback`. The block is neither v1 nor v3 | Make §2.2 exactly `0001_init.sql` and add a "§2.2a Migrations 0002, 0003" delta list. Every later migration adds a line there |
| C4 | UI | §4.6 health statuses vs §7.1 bootstrap `status` vs the code | The design uses `archive/dead/disabled/failing(≥14)/erroring(1-13)/throttled/redirecting/silent/ok`. The code (`api/feeds.go:40`, `store/uibootstrap.go:151`) emits `archive/gone/user/disabled/failing(>0)/ok`. The 10 temporary-redirect feeds and any single blip show as "failing" | Implement the §4.6 taxonomy in one shared Go function used by both bootstrap and health. The UI keys its badges on it |
| C5 | UI | §7.1 `GET /api/health/feeds` vs the code | `snapshot`, `clock` and `host_throttled_until` are specified but not returned (`api/feeds.go:91`, which returns only feeds, clients and unread_total). Also, `migrated:true` is set while a 301 is still *pending* (count < 3), after which the migration clears it | Add the three fields. Rename the flag to `redirect_pending`. The actual migration is a kept fetch_log note |
| C6 | Deploy | §2.6 "04:10 in `settings.tz`" vs `maint.go:124` (`time.Local` = env `TZ`) | Two time-zone sources exist. Stats use the `tz` setting (`store/stats.go:43`). Maintenance uses the process TZ. The settings help text says tz is "for showing times" | One source: maintenance reads the `tz` setting. The UI shows times in the **device** zone, and `tz` is labelled "for daily statistics and the nightly job" |
| C7 | UI | `settingsmeta.go:203` help text | "Older **read** articles beyond this many are removed". Retention counts unread items too (§5: N counts non-starred items, read or not) | Change it to "Only the newest N articles per feed are kept; starred articles are always kept". the owner should see that unread items can be trimmed |
| C8 | Nice | §4.3 bullet "AssignUIDs keeps the first occurrence and drops later ones" vs §4.8 and `dedup.go:33` | In auto mode, AssignUIDs keys every occurrence and never drops | Fix the §4.3 wording |
| C9 | Nice | open-questions #16, #20, #26, #27, #32, #33 vs design | #16 "No ETag" vs decision 8. #20 `ot` includes state changes vs decision 6. #26 auto re-key vs decision 14. #27 "no purge" vs the 180-day purge. #32 "strip srcset" vs srcset kept and rewritten. #33 `/api/v1/events` vs `/api/events`. The plan's research summary likewise says 60 s tick, ±20 % jitter, `GOMEMLIMIT=96MiB`, 30 s total timeout and `no-store` | Add a one-line banner to both docs, "superseded by design.md where they differ", and fix the dispositions of those six rows |
| C10 | Nice | §7.1 `GET /api/stats/export.csv` | It is listed without a phase tag and is not mounted; only `needsOriginCheck` names it (`api.go:242`) | Tag it "phase 4" in §7.1 |
| C11 | Nice | Memory notes vs the code | `phase2-inline-extraction-must-ship` and parking-lot item 3 say ingest extraction is "not yet in code". It shipped in 1982896, 7af643c and 13fb02c | Update both notes |
| C12 | Nice | §6.6 `summary.direction:"ltr"` is hard-coded (`h_streams.go:254`) | RTL feeds render wrong in client A and NNW | Derive `rtl` from the feed or item `xml:lang`/`dir`, or leave it and add a §11 row |

## 2. Blockers before the UI (API shape and product decisions)

| # | Gap | Evidence | Recommended default |
|---|---|---|---|
| U1 | **Settings scope.** Every `ui.*` key is one server-side row, so the phone and the desktop share one theme, font size and density | `store/uibootstrap.go:30`; §2.2 | Keep the server values as defaults. Add a per-device override in localStorage for theme, font size, density and layout, with a "use on all devices" action. This is Q1 |
| U2 | **Sort order.** There is no oldest-first option and no per-feed default view (unread or all). `ui.layouts` stores only the layout | `api/items.go:74` accepts only `date` and `rank` | Add `order=oldest` (keyset ascending on `(sort_at,id)`). Extend `ui.layouts` values to `{layout, view, order}` per feed or folder. This is Q2 |
| U3 | **Mark above/below, and mark all in search.** The scope bound `max_id` is crawl-time id, but the list is ordered by `sort_at`. "Mark everything older than this card" cannot be expressed, and search results have no scope. The id list works only for loaded cards (≤ 10,000) | `api/items.go:357`, §7.1 mark-read | Add a scope bound `before:{sort_at,id}` / `after:{…}` in list order, plus `scope.q` for search. Keep `max_id` as the snapshot guard against newly arrived items |
| U4 | **Unread-view semantics.** Nothing says whether a card marked read disappears at once, stays until reload (Feedly), or stays until the view is left. Scroll restoration after returning from an article is not specified either | §7, plan phase 2 | Read cards stay in the loaded list until a refresh or view change. The list state is kept in TanStack Query, and scroll is restored by item id |
| U5 | **Keyboard and gesture spec.** The plan names only `j/k/s/o/r/m`, and §4.9 binds `r` to refresh-all. There is no map for next/prev feed, back, open original, mark-all (with confirm), search `/`, help `?`, or the swipe directions | plan phase 2; memory `phase2-ui-review-meeting` | Settle it in the UI/UX meeting and write it as a §7.7 table before building. This is Q4 |
| U6 | **Empty, error, loading and offline states; first run.** None are specified: the first run with 0 feeds, an import in progress (run progress), a failing feed, a 401 in the PWA (re-login), SSE down (polling), a fulltext error with retry, a trimmed stub (`trimmed:true`) | §7 has no UX-state section | Add a short §7.8 state list. First run shows "Import OPML" (with the `mark_read_older_than_days` option) or "Add feed" |
| U7 | **Article link handling.** Links are not given `target=_blank`/`rel=noopener noreferrer`. Footnote `#frag` links are kept (`policy.go:58`) and will fight the SPA router. The design covers only the "Open original" link | `sanitize/policy.go`; §7.5 | Add `target`/`rel` at serve time. The client intercepts `#frag` clicks and scrolls inside the article container. Article `id` attributes get prefixes to avoid DOM clobbering |
| U8 | **CSP for the SPA and article HTML.** The SPA, API and SSE send only `frame-ancestors 'none'`. Sanitized article HTML goes into the same origin that holds the session. There is no `script-src`, and no `Referrer-Policy`, so every image and link leaks `rss.example.com` URLs as the Referer | `web/handler.go:68`, `api/api.go:205` | Add a strict CSP now, because it constrains the Vite build (no inline script): `default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' https: data:; media-src https:; frame-src https://www.youtube-nocookie.com https://www.youtube.com; connect-src 'self'; object-src 'none'; base-uri 'none'; form-action 'self'`, plus `Referrer-Policy: no-referrer`. Render articles in the page DOM, not an iframe |
| U9 | **Embeds and media.** Only YouTube iframes survive the sanitizer, so Vimeo, X/Bluesky and podcast players are lost silently. `video/audio src` and iframes load straight from the device, which reveals the owner's IP to third parties, and `http://` media is blocked as mixed content. Enclosures reach the detail JSON, but no UI player is specified | `policy.go:32-39`, §7.4 "Which images" | Default: YouTube as click-to-load (nocookie) and other embeds become a link. Enclosures get a native `<audio>` player with "open in podcast app" and no playback state. This is Q5 |
| U10 | **Image privacy default.** `imgproxy.mode=http_only`, so https tracking pixels and images load directly, and the setting is hidden | `settingsmeta.go:233` | Keep `http_only` (cheaper, lets the service worker cache), but show the setting as "Load all images through Kipple (more private)". This is Q5 |
| U11 | **Downloads need `X-Kipple-Client`.** `GET /api/opml` (and the future CSV) needs the header, so a plain `<a download>` gets 403. That forces fetch→blob, which is clumsy in iOS standalone | `api.go:238-258` | Accept a download token (`?dl=<HMAC(secret, path, 60s)>`) from a same-origin POST, or accept `Sec-Fetch-Site: same-origin` alone on these two GETs |
| U12 | **Archive items in cards.** Cards carry no `origin_title`, so unsubscribed starred items all read "Unsubscribed (starred)" | `store/uiitems.go` (no origin_title) | Add `origin_title` to Card and Detail and show it as the source |

## 3. Before the phase 2 deploy (operational)

| # | Gap | Evidence | Recommended decision |
|---|---|---|---|
| D1 | **No off-box backup of Kipple's data.** `kipple-snapshot.db` and the pre-migration copies live in the same `host-a_kipple_data` volume. Plan C7 (`GET /api/backup` into Proton) is not built. §2.6 assumes a "Host-A host backup" that is not documented anywhere | §2.6 step 3; plan C7; no route in `api.go:158-195` | Before deploying 0002 and 0003, a nightly pull from Host-B: ssh host-a, `docker cp kipple:/data/backup/kipple-snapshot.db`, into `proton-backup.ps1`. `docker cp` needs no shell in the container, so it works on distroless. No new HTTP auth surface. This is Q6 |
| D2 | **The rollback path is a data loss.** The downgrade guard (`migrate.go:108`) stops the phase 1 image from opening a v3 database, so rollback means restoring `pre-migration-1-3-*.db` and losing reads and stars since the deploy. 0002 and 0003 are additive `ALTER ADD COLUMN`s | §2.5 step 3, §2.5 step 7 | Accept it and put it in RUNBOOK: stop, restore the snapshot, delete `-wal`/`-shm`, start the old tag. Or relax the guard for migrations marked `-- kipple:additive`. This is Q7 |
| D3 | **Restore procedure** for a corrupt DB or a snapshot restore is written nowhere | §2.6 | A RUNBOOK section: stop kipple, copy the snapshot to `kipple.db`, remove `-wal`/`-shm`, start, run the FTS integrity-check |
| D4 | **No web password recovery.** The web login is locked for 15 min after 10 failures. `KIPPLE_PASSWORD` is only the initial value, and the CLI has only `serve/import/api-password/version` | `cmd/kipple/main.go:69-80` | Add a `kipple password` subcommand (like `api-password`), then remove `KIPPLE_PASSWORD`/`KIPPLE_API_PASSWORD` from Host-A `.env` after bootstrap |
| D5 | **Dependabot vs the libc pin.** The `gomod` minor and patch group will propose `modernc.org/libc` bumps apart from `modernc.org/sqlite`, and §3/§11 require them pinned exactly together | `.github/dependabot.yml` | Add `ignore: modernc.org/libc` and bump it only alongside sqlite by hand. Also pin actions and base images by digest (supply chain) |
| D6 | **Release gate for the new surface.** The §10 release checklist predates phase 2 and has no checks for `/img`, `fulltext.ready` over the tunnel, the Reader full-text hold with client A (open question 55), or a CSP breakage check | §10 release checklist | Add those four lines |
| D7 | **Disk growth is invisible.** Stubs (~270 MB at 90 days), 3 pre-migration copies plus 1 snapshot (~5× the DB), no `auto_vacuum`, and stats are never trimmed. The health view shows no sizes | §5 Size, §2.5 step 4 | Show DB, WAL and backup-dir sizes in the health view. No VACUUM job (the steady state reuses free pages) |
| D8 | **Open design decisions** are still unanswered: decision 33 (`greader.subscribe_fetch_now`), the day-1 capture for `stats.api_single_read_is_open`, and the client A `ts` unit (open question 1) | plan "Open decisions"; open-questions #1 | Record the answers (or "still default") in plan.md before the deploy. This is Q9 |

## 4. Product-feature coverage (daily RSS reader)

| Feature | Covered? | Sev | Recommendation |
|---|---|---|---|
| Keyword mute/filters (hide or auto-read by title/author) | No | UI (decide) | Q8. If yes, apply at ingest as `read=1` so Reader clients agree, per feed and global, with a fetch_log note |
| Saved searches / smart views | No | Nice | Store as `ui.saved_searches` (a query plus a scope). No schema change |
| Read later | Starred is the only state | Nice | Starred = read later (Reader clients only know starred). State it in §7 |
| Highlights, notes | No | Nice | Non-goal. Say so in CLAUDE.md non-goals |
| Folder-level settings (retention, interval, fulltext) | Per feed only | Nice | An "apply to all feeds in folder" UI action, no inheritance level |
| Feed and folder reordering | `position` in PATCH; no bulk reorder endpoint | UI | Default alphabetical display (ignore OPML order), or add `POST /api/folders/{id}/order {feed_ids}`. Decide with U5 |
| OPML export of state; data export | OPML covers subscriptions only; stats CSV (phase 4); **no starred export** | Nice | `GET /api/export/starred.json` (and an HTML bookmark file) later |
| Sharing | `share` stat kind; Web Share in phase 3 | OK | - |
| Duplicate handling UX | Per-feed dedup mode plus rekey confirm; no cross-feed duplicates | Nice | Accept, and add a §11 row. A related latent risk: a guid that *becomes* duplicated in a later document changes its uid from `g:h(guid)` to `g:h(guid|link)` (`dedup.go:73`), so the old item is re-inserted as new |
| Feed discovery | `POST /api/feeds` with `choose` candidates | OK | The UI shows candidates with type and title |
| Import flow | `POST /api/opml` report fields | UI | A report screen: existing, merged, dropped, `ignored_attrs`, and the run progress |
| Podcasts, enclosures, video | Data present, no UI spec | UI | See U9 |
| Image galleries, lightbox | No | Nice | Tap an image to open it full-size in a new tab. No gallery |
| Print | No | Nice | A print stylesheet for the article view only |
| RTL, non-Latin fonts | `dir` survives bluemonday; the bundled fonts are Latin | Nice | `dir="auto"` on the article container. System fallback for CJK and Arabic. See C12 |
| Time and date formatting | Unspecified | UI | Relative time in lists ("3h"), absolute time in the article, device zone, `Intl.DateTimeFormat` |
| Very long articles | The UI detail has no size cap (the Reader API has 500 KB) | Nice | `content-visibility:auto`. Cap the detail at 2 MB with a "continue on site" link |
| Search UX | FTS on title, author and feed text; not extracted full text; no stemming | UI | A search box scoped to the current feed or folder, with snippets and a "read/all" toggle. See U3 for mark-all on results and Q9 for porter |
| Pagination, infinite scroll | Keyset cursor, `limit` ≤ 100 | OK | TanStack Virtual plus cursor; see U4 |
| PWA badge count | Not specified | Nice | None. iOS badging needs notification permission, and notifications are a non-goal |
| Offline reading | SW "API network-only" (plan phase 3) | Phase 3 (decide) | No offline reading in the web app; client A is the offline client. Show a cached "offline" shell. This is Q10 |
| Logs, diagnostics UI | Health view plus fetch_log; no server log view | Nice | Enough. Add the version, uptime, DB size (D7) and last snapshot to the health view |
| Session management | Password change revokes other sessions (`account.go:87`); no list or revoke UI | Nice | "Sign out other devices" button (reuse the same delete) |

## 5. Security gaps

| # | Sev | Gap | Recommendation |
|---|---|---|---|
| S1 | UI | Only a `frame-ancestors` CSP and no Referrer-Policy (see U8) | A strict CSP and `no-referrer` |
| S2 | Nice | No HSTS | Cloudflare edge setting (the owner), not in Kipple |
| S3 | Nice | `account.secret` (token HMAC, image signatures) has no rotation | A `kipple rotate-secret` CLI (it revokes the Reader token and image URLs; sessions survive) |
| S4 | Nice | Supply chain: actions and base images are pinned by tag; there is no `npm audit` in CI | Digest pins, plus `npm audit --omit=dev --audit-level=high` in the web job |
| S5 | OK | SSRF: fetch, discover, extract and imgproxy all build clients on the guarded transports (`fetch/client.go`, `discover.go:58`, `extract.go:126`, `imgproxy.go:196`) | No action. Media and iframes bypass the proxy, as U9 covers |
| S6 | OK | CSRF: `Sec-Fetch-Site`/Origin plus `X-Kipple-Client` (`api.go:246`); clickjacking headers on every route | No action (U11 is the only usability cost) |

## 6. UX and accessibility vs the plan

- **A11y is absent from the design and plan exit criteria (UI).** Add these to the phase 2 exit: keyboard focus moves to the article on open and back to the card on close; visible focus rings; `aria-live` for run progress and toasts; swipe actions duplicated as buttons or a menu; hit targets ≥ 44 px; WCAG AA contrast checked for all 8 themes (sepia, soft green and brown are the risk).
- **Motion (UI).** Honor `prefers-reduced-motion` for swipe, card and transition animations.
- **Text size.** `ui.font_size` is 12-32 px. Also scale with iOS text size (`-apple-system-body` or rem), or state that the in-app setting replaces it.
- **Theme names.** The code uses `system` where CLAUDE.md says "follow-system", and adds `oled` (the owner's decision). Align the CLAUDE.md list.
- **PWA (phase 3).** The SPA handler serves `index.html` for `/manifest.webmanifest`, `/sw.js`, `/favicon.ico` and `/apple-touch-icon.png` (`web/handler.go:56`). Root static files must be served before phase 3, as the kickoff already notes.

---

## Top 10 questions for the owner

1. **Per-device appearance.** Should theme, font size and spacing be one setting for all devices, or server defaults with a per-device override (phone vs desktop)? *Recommend: per-device override.*
2. **List behavior.** Do read cards stay visible until refresh (Feedly), or vanish at once? Do you want an oldest-first option and a remembered unread/all view per feed? *Recommend: stay until refresh; yes to both.*
3. **Mark above/below and mark all search results.** Needed? *Recommend: yes, in list order (U3).*
4. **Keyboard and gesture map.** This is for the UI/UX sit-down: the full keymap (is `r` refresh or read?) and swipe left/right/long-press actions.
5. **Article privacy and embeds.** Load all images through Kipple, or only http ones? YouTube inline or click-to-load? Other embeds as links? A podcast `<audio>` player? *Recommend: http-only default with a visible toggle, click-to-load YouTube, embeds as links, a simple audio player.*
6. **Off-box backup.** OK to pull `kipple-snapshot.db` nightly from Host-A into the Host-B Proton tarball (via ssh plus `docker cp`) before the phase 2 deploy? *Recommend: yes, before the deploy.*
7. **Rollback cost.** Is "rollback = restore the pre-migration snapshot and lose changes since the deploy" acceptable, or should additive migrations let the older image run? *Recommend: accept it and document it.*
8. **Mute and keyword filters.** In scope for phase 2, later, or never? If in scope, should muted items be marked read at ingest, so client A and NNW hide them too? *Recommend: later, marking read at ingest.*
9. **Pending defaults.** Should apps add feeds with a synchronous fetch (decision 33)? Does the day-1 log justify API read inference? Did the log show client A's `ts` unit? Should search get porter stemming (a one-time FTS rebuild)? *Recommend: keep async, inference off, porter yes.*
10. **Offline and PWA scope.** Is it fine that the web app has no offline reading and no badge, with client A as the offline client? *Recommend: yes.*

Also unasked but recommended as defaults unless the owner objects: rewrite §13 as a status table and drop the normalized-link uid (C1); one time-zone source (C6); fix the retention help text (C7); a strict CSP plus `no-referrer` (U8); a `kipple password` CLI (D4); a Dependabot libc ignore (D5).
