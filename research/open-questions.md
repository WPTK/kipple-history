# Open questions from the research — triage (2026-09-24)

Every open question the nine reports raised, with what happens to it. Three buckets:

- **Decided** — a design choice makes the question moot or answers it; the choice is stated.
- **Hedged, then observed** — Kipple is built to be correct under every plausible answer, and the
  real answer is read off Kipple's Reader API request log during phase 1 step 8 (first Reeder
  Classic and NetNewsWire connections). Phase 1 logs every Reader API request (method, path,
  query and form keys, user agent, status, duration) at debug level for exactly this purpose.
- **Verify at step N** — a measurement or device test scheduled in the plan; nothing to decide
  until then.
- **No action** — out of scope for Kipple (other servers' internals, other clients).

## Reader API contract

| # | Question (source) | Bucket | Disposition |
|---|---|---|---|
| 1 | Unit of `ts` in Reeder's `mark-all-as-read`; does Reeder use it at all (reeder, freshrss, miniflux, item-id) | Answered (2026-09-26)| Reeder Classic marked a whole category read with ONE `edit-tag` (`a=user/-/state/com.google/read`, 424 `i=` ids), not `mark-all-as-read`, and sent no `ts`. Evidence: `docs/HF/evidence/reeder-alpha2-2026-09-26.log`. Digit-count parsing of `ts` stays as a hedge for other clients. |
| 2 | Does Reeder Classic 5.5 still send `T=x` or fetch `/token` (reeder, netnewswire, item-id) | Answered (2026-09-26) | Reeder Classic (UA `Reeder/5060003`) fetches `/token` and sends a real `T` on `edit-tag` (keys T, a, i) and on `POST stream/items/contents` (keys T, i, output); evidence in `docs/HF/evidence/reeder-alpha2-2026-09-26.log`. The rule stays: POST accepted when the `Authorization` header is valid **or** `T` is valid; `T=x`/empty tolerated with a valid header, for other clients. NetNewsWire's real `T` is still validated. |
| 3 | Does Reeder follow `continuation` or stop at 10,000 (reeder, miniflux, item-id) | Hedged, then observed | `n` honored up to 100,000 (ids are ~20 bytes each), `continuation` always emitted when more remain. Either behavior works; the log tells which. |
| 4 | Does Unread 5.0 follow `continuation` (`n=100000`, no `c=` seen) (item-id) | Hedged | Same 100,000 cap covers it. |
| 5 | Does Reeder call `tag/list`, `unread-count`, `stream/contents`, use `r/nt/c/it/includeAllDirectStreamIds` (reeder, miniflux) | Hedged, then observed | All implemented (`unread-count` with `max`, `stream/contents` for FeedMe/Readrops-class clients, `r=o`, `nt`, `c`, `it`; `includeAllDirectStreamIds` ignored). |
| 6 | Reeder's current contents batch size; does it send `output=json` and `T` on that POST (item-id) | Hedged, then observed | `output` optional (JSON is the default), `T` optional with a valid header, any batch size up to 1,000 ids. Reeder sends `output=json` and `T` on the contents POST (same log as #2). |
| 7 | Does Reeder request label streams on `stream/items/ids` (Miniflux 500s) (miniflux) | Decided | `user/-/label/<name>` accepted on every stream endpoint. |
| 8 | `user/-/` vs `user/<id>/` prefix tolerance in Reeder (miniflux) | Decided | Emit `user/-/…` everywhere (FreshRSS form, proven with Reeder); accept both on input. |
| 9 | Which item keys Reeder 5/Classic reads today (reeder) | Decided | Emit the superset: `id, title, published, updated, crawlTimeMsec, timestampUsec, summary, content, canonical, alternate, categories, origin, author, enclosure`. |
| 10 | Does Reeder ever `%2F`-encode stream ids (reeder) | Decided | Router wildcard captures the rest of the path and unescapes; contract tests cover both spellings. |
| 11 | Reeder's `subscription/edit` shapes for add/rename/move/unsubscribe (reeder) | Decided | Implement `ac=subscribe|unsubscribe|edit`, `s=feed/<id>` or `feed/<url>`, `a=`/`r=` labels, `t=` title — the union of every shape FreshRSS and Miniflux accept. |
| 12 | Does NetNewsWire HTML-decode `title`/`origin.title` — send `&amp;` or `&` (netnewswire) | Decided | Titles are stored and emitted as plain text: entities decoded once at ingest, tags stripped, no fullwidth escaping. JSON strings carry `&` literally; nothing to decode either way. |
| 13 | NetNewsWire leaves `;` unencoded in `t=/a=/r=`; Go's `ParseForm` rejects it (netnewswire, go-libraries) | Decided | Custom form parser: split on `&` only, `QueryUnescape` each pair. Contract test with a folder named `Tech; Apple`. |
| 14 | Can NetNewsWire loop on 401 if Access intercepts only some paths (netnewswire) | Decided | The single Bypass app covers the whole `/api/greader.php` prefix, so `ClientLogin` and `reader/api/0/*` share one auth state; valid tokens never get 401. Cutover checklist proves it from outside. |
| 15 | Does NetNewsWire's `DateFormatter` (full weekday) parse a normal RFC 7231 `Date` header (netnewswire) | No action | Kipple sends Go's standard `Date`. If NNW fails to parse it, it falls back to a 3-month `ot` window, which Kipple serves fine. |
| 16 | Case sensitivity of NetNewsWire's ETag/Last-Modified lookup; behavior on unrelated 304s (netnewswire, item-id) | Decided | `ETag` = hash of the rendered body on both `subscription/list` and `tag/list`, and a conditional GET that matches answers 304. It changes exactly when the list does, so NNW's post-quickadd refetch always gets a 200 with the new feed. |
| 17 | Stream order and `ot`/`nt`/continuation on crawl time vs `published_at` (fetch-prior-art) | Decided | Crawl time (the id) orders streams and drives `ot`, `nt`, `continuation`, `crawlTimeMsec`, `timestampUsec`; `published` is carried separately for NetNewsWire's dates. Verified with both clients at step 8. |
| 18 | Do Reeder/NNW ever `edit-tag` ids past their cache horizon (tombstoned items) (fetch-prior-art) | Hedged, then observed | Tombstone ledger accepts and records the state; the log counts hits on tombstoned ids. |
| 19 | FreshRSS `it=starred&xt=read` bitmask collapses to "no filter" (item-id, freshrss) | Decided | Not mirrored: `it` and `xt` are real set filters (`it=starred&xt=read` = unread starred). |
| 20 | FreshRSS `ot`+`nt` OR-combination — bug or intent (freshrss) | Decided | Not mirrored: `ot` is `crawl >= ot OR state_changed >= ot`; `nt` is `crawl <= nt`; both together form a range. |
| 21 | FreshRSS `hidden` priority vs `mark-all-as-read` (freshrss) | No action | Kipple has no feed priorities. |
| 22 | FreshRSS bcrypt parameters (freshrss) | No action | Kipple compares against its own configured password (constant-time). |
| 23 | Miniflux `Sscanf("%016x")` on top-bit hex (item-id) | No action | Kipple ids are positive; the parser uses `ParseUint(…,16,64)` then casts, so negatives from other servers' ids would still round-trip. |
| 24 | BazQux `ClientLogin` failure status; Inoreader `n` docs discrepancy; Fiery Feeds/lire/News Explorer quirks; Miniflux issue comments, commit archaeology, Capy Reader; GReader Redate README; SimplePie `subscribe_url`; Miniflux PR #4139 (item-id, miniflux, freshrss, fetch-prior-art) | No action | Other servers' or other clients' internals; nothing for Kipple to do. `ClientLogin` failure is `401` text `Error=BadAuthentication` (the status both primary clients are proven against, with Google's body). |
| 25 | FreshRSS report could not read NetNewsWire's parsers (freshrss) | Answered | The NetNewsWire report read them: `summary`, `categories`, `origin` required; `content` ignored; `published` only. |

## Fetch layer and retention

| # | Question (source) | Bucket | Disposition |
|---|---|---|---|
| 26 | GUID-migration heuristic (≥50 % new-by-uid but matching by link) has no prior art (fetch-prior-art) | Decided, then observed | Ship with ≥50 % and ≥5 items; every trigger is written to `fetch_log` with counts so the threshold can be tuned against the real 138 feeds in the first week. |
| 27 | Purge the tombstone ledger? (fetch-prior-art) | Decided (phase 2) | Phase 1 did not purge. Now a nightly purge removes ledger rows 180 days after the uid last appeared in the feed (the horizon is `max(180 days, retention.restore_days + 7)`, so never inside the restore window), and restore stubs go after `retention.restore_days`. |
| 28 | Retry-After cap: 8 h (Feedbin) vs 24 h (Miniflux) vs 48 h (FreshRSS) (fetch-prior-art) | Decided | 24 h. A host asking for longer is re-polled once a day, which is harmless. |
| 29 | gofeed's 4 KiB feed-type detection window vs feeds with long preambles (go-libraries) | Decided, not implemented | No fallback was built: `ParseFeed` returns gofeed's detection error as a parse error (no preamble handling). Build the fallback if a real feed hits it (`fetch_log` shows the error). |
| 30 | Exact OPML attribute spelling and nesting in `newsblur-export.opml` (go-libraries) | Answered | Read from the file: feeds carry `text`, `title`, `type="rss"`, `version="RSS"`, `htmlUrl`, `xmlUrl`; folders carry `text` and `title` only; depth 2; no root feeds. |
| 31 | Do Reeder/NetNewsWire tolerate more than one folder level (go-libraries) | Decided | They don't (one label per feed in NNW's FreshRSS model). Nested OPML folders flatten to one level on import; export writes one level. |
| 32 | `srcset` rewriting: bluemonday's `RewriteSrc` covers `src` only (go-libraries) | Decided, revisited in phase 2 | Phase 1 stripped `srcset`/`sizes`. Phase 2 keeps `srcset`, `sizes` and `media` on `img` and `source`, resolves each candidate to an absolute URL and proxies it. |
| 33 | Does SSE survive cloudflared + Access on the UI path (fetch-prior-art, cloudflare) | Verify at cutover (C6) | `curl -N https://rss.example.com/api/events` from outside; polling `/api/status` is the built-in fallback. |

## Libraries and build

| # | Question (source) | Bucket | Disposition |
|---|---|---|---|
| 34 | Binary size and idle RSS with modernc vs ncruces (go-libraries) | Verify at step 1 | Measured on the scaffold build; gates are image < 50 MB and idle RSS < 100 MB. |
| 35 | Docker build RAM/time on Host-A for the pure-Go SQLite driver (go-libraries) | Verify at steps 1 and C4 | First on Host-B, then on Host-A (32 GB RAM, so expected fine). BuildKit cache mounts in the Dockerfile. |
| 36 | `modernc.org/sqlite` v1.59.0 vs v1.59.1 and the exact `libc` pin (go-libraries) | Verify at step 1 | Check the proxy at pin time; pin `libc` to the version in that tag's `go.mod`. |
| 37 | Does Go's ServeMux answer 405 with `Allow` on method mismatch (go-libraries) | Verify at step 1 | One `httptest` case. |

## Deployment (Cloudflare Access, tunnel, cookies)

| # | Question (source) | Bucket | Disposition |
|---|---|---|---|
| 38 | Path-app precedence edge cases; is `.php` accepted in an Access app path; does Bypass win (cloudflare) | Verify at B2/C6 | The cutover checklist's `curl` from outside must get Kipple's own 401, not a 302 to cloudflareaccess.com. The existing `/fever` bypass app is the precedent. |
| 39 | Is a client-supplied `Cf-Access-Jwt-Assertion` stripped on Bypass paths (cloudflare) | Decided | Never honored anywhere in phase 1 (no JWT trust); moot. |
| 40 | Is `CF_Authorization` always forwarded to the origin (cloudflare) | Decided | Not used; moot. |
| 41 | Exact TCP source address of tunnel traffic (cloudflare) | Verify at C4 | Read from Kipple's access log before setting `KIPPLE_TRUSTED_PROXY_IPS` (expected `192.0.2.192`). |
| 42 | Does the tunnel configurations `PUT` accept a partial ingress array (cloudflare) | Decided | Treated as full replacement: GET, edit one rule, PUT everything back — or the owner edits the route in the dashboard (B3). |
| 43 | Access session maximum vs Kipple's cookie (cloudflare) | Decided | Kipple cookie 90 days > Access session; the owner raises the Access session to 1 month so the OTP prompt is rare. |
| 44 | Reeder over plain `http://`; self-signed certificates (reeder) | Decided | Kipple is HTTP-only on 7080; HTTPS comes from the tunnel. LAN tests use NetNewsWire over http (its App Transport Security allows it); Reeder is tested through the tunnel. |
| 45 | Reeder macOS refresh-interval preferences (reeder) | No action | the owner's Reeder is on iOS; sync cadence is the client's business. |

## UI phases (2–3) — device tests, not decisions yet

| # | Question (source) | Bucket | Disposition |
|---|---|---|---|
| 46 | Does `theme-color` color the status bar in installed web apps on iOS 26/27; does `default` still force a white strip (pwa) | Verify in phase 3 | Device test with all 20 schemes (at least one per group) decides between `black-translucent` + self-painted strip and `theme-color`. |
| 47 | iOS 27 changes to home-screen app chrome or iPad safe areas (pwa) | Verify in phase 3 | Device test. |
| 48 | Will Safari 27.1 ship `interactive-widget` (pwa) | Decided | Keyboard avoidance uses `VisualViewport` regardless. |
| 49 | Access email OTP inside the standalone PWA's isolated cookie jar (pwa, cloudflare) | Verify in phase 3 | Confirm typing the code inside the PWA completes login and the session lasts weeks. |
| 50 | Feedly's regular card image ratio (pwa) | Decided | 3:2 default, judged visually in phase 2, not by Feedly parity. |
| 51 | Gentium Book Plus 6.101 (Google Fonts) vs Gentium Book 7.000 (SIL) (pwa) | Decided | Ship Google Fonts' Gentium Book Plus 6.101 — the name in CLAUDE.md. |
| 52 | Arvo latin-ext coverage (pwa) | Moot | Arvo comes prebuilt from `@fontsource/arvo` (no subsetting); check its latin-ext files if a glyph is missing. |
| 53 | Gesture library vs ~150 lines of Pointer Events (pwa) | Decided | Pointer Events, no library (use-gesture is dormant). Revisit only if it costs more than a day. |
| 54 | Does `overscroll-behavior: none` fully stop rubber-banding in standalone (pwa) | Verify in phase 2 | Browser-pane mobile preset first, then device; iNoBounce-style guard is the fallback. |

## Reader API and full text (phase 2)

| # | Question (source) | Bucket | Disposition |
|---|---|---|---|
| 55 | A Reader client that syncs an item before its background extraction lands gets the feed's own content. Will Reeder Classic (or NetNewsWire) ever re-download the contents of an id it already has, so it shows the extracted text later? (Opus review of the after-commit extraction; reeder-classic, netnewswire, greader-freshrss, greader-miniflux) | Decided; verify at deploy (Reeder) | **Decided (the owner): option (a), hold new full-text items back from the Reader API until extracted or 30 s after their crawl time; built (design §6.5).** No spec-compatible push exists, which is why a push was not built. Evidence: Reeder lists ids (`stream/items/ids`) and then POSTs `stream/items/contents` only for ids "it doesn't have locally", in batches of 100 (reeder-classic §4 item 6, FreshRSS #2956 log); NetNewsWire likewise fetches contents only for statuses lacking an article (netnewswire refreshAll). The Reader API has no per-item "changed" signal: `updated` and `crawlTimeMsec` are informational, and `ot`/`nt` filter ids by crawl (FreshRSS: id-or-`lastUserModified`) or published time (Miniflux), so moving them would only change which ids are listed, and both clients already have the id. Neither FreshRSS nor Miniflux offers a way to refresh contents already synced (an edited entry stays stale in Reeder there too). The window is also small: the extraction runs seconds after the commit (10 s cap per article) while a client sync has to land inside it; the UI is unaffected (`fulltext.ready` and the on-demand endpoint). **Verify at deploy:** add a full-text feed, sync Reeder within a few seconds of the fetch, and see whether the article stays as the feed's short content after the extraction finished (`SELECT` the `item_fulltext` row to confirm it exists); also try `stream/items/contents` for that id by hand to confirm Kipple serves the text. **Options if it bites:** (a) hold a new item of a full-text feed back from the Reader API listings (ids and contents) until its `item_fulltext` row exists or a grace of about 30 s since its crawl time has passed (Reeder lists all unread ids every sync, so it would fetch the item next time; costs: an item is briefly missing from the Reader API but present in the UI, so counts differ for a moment, and NetNewsWire's reconcile must not treat it as removed, since a missing unread id is marked read there); (b) give the item a new id when the text lands, which duplicates the article in the client and is rejected; (c) accept the limitation, as the reference servers do. Option (a) was chosen without waiting for the deploy test. Hazards worked through: ids stay monotonic; the 60 s cap on the window is inside the 120 s `ot` slack, so a client that advanced `ot` while the item was held still lists it next sync; `unread-count` and the default mark-all exclude held items; the UI is not held. **Still verify at deploy** with Reeder and NNW that the first sync after a fetch shows the extracted text and that no item is missed. |
