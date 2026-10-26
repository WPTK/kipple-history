# design.md history: revision notes, risks, red-team dispositions, deltas

Moved out of `docs/design.md` in the code repo on 2026-10-26 (Build 10, Meeting 10 items 6 and 20). `design.md` keeps what
is true now; this file keeps how the design got there. Written 2026-09-24 as "revision 2: after red-team review".

## Revision notes (the former intro)

The design started from **fetch-first**, which two of the three judges picked. It added the grafts the judges named and
fixed every defect they found. Revision 2 applied the red-team review; section 12 below gives the disposition of every
issue. Where the judges disagreed, the resolution is stated in section 1 of `design.md`. Three points also corrected the
brief and all three input designs (the `ot` semantics, the `application_id` constant, and client batching of status
changes); those three are kept in `design.md`.

What was validated, and on what:

- *Revision 1:* the DDL and the query plans in section 2.3 ran on SQLite 3.50.4 with FTS5, using 140 feeds and 35,000
  items for the planner checks and 150,000 items for the `ot` timing. That was the wide `items` table.
- *Revision 2:* the revised DDL ran on an in-memory SQLite 3.50.4 database. The checks were: FTS5 external content over a
  view (`MATCH`, `snippet()`, `integrity-check`); the split FTS triggers (a markup-only rewrite of 200 items left
  `items_fts_data` unchanged at 21 rows); the retention trim with restore stubs (300 items, 5 starred, N=50 gave 245
  trimmed, 55 kept, 245 ledger rows, 245 stubs and a trimmed-unread counter of 245); restoring a starred ledger id (the
  item and its FTS row came back, the stub was removed); archive-on-unsubscribe (starred items survived; ledger rows and
  stubs cascaded away); deleting the default folder is refused and so is a second archive feed; both `ot` legs with an
  absent `c` bound to MaxInt64, with plans checked before and after `ANALYZE`; `PRAGMA foreign_key_check` returned
  nothing.
- *Production differs.* The pinned `modernc.org/sqlite` v1.59.x ships SQLite 3.53.4 compiled with STAT4.
- *Not re-measured:* the 150k-row `ot` timings. The split table can only make them faster.

# Section 11 (was design.md section 11)

## Known risks and mitigations

| Risk | Mitigation |
|---|---|
| **Some Reader API clients are closed source.** The `mark-all-as-read` `ts` unit, continuation behaviour, `T=x` use, its Content-Type, its field-type strictness and its scroll-mark batching are inferred, not observed | Tolerant parsing (`ts` by digit count, any non-multipart POST body parsed as a form), `n` up to 100000, `T` `""`/`x` accepted, no JSON nulls anywhere. The day-1 capture was meant to turn real traffic into contract tests (§10; not yet done) |
| **Some clients do not follow continuation** (`n=10000`). If more than 10,000 items are unread, the oldest never reach such a client and its counts differ from the web UI | Warned in the bootstrap `warnings` and the health view. The UI OPML import offers "mark items older than N days read" on first fetch as an explicit choice. The default N=250 × 138 feeds can reach 34,500, so the migration import should use that option |
| **`ot` excludes user state changes** (a deliberate departure from the brief's wording) | Observed clients pull full unread and starred lists without `ot`; the reference server Kipple follows behaves this way. `greader.ot_includes_user_changes` (default off) restores it: items whose read or starred state changed since `ot`, unread and unstar included, join leg 2 through `items.state_changed_at` (migration 0007) |
| **The `ot` slack of 120 s on both legs** returns up to 2 minutes of already-known ids | Harmless: clients de-duplicate by id |
| **Some clients' `Date` parsers use a full-weekday pattern** and may fall back to a 3-month `ot` every refresh | A few pages of 1000 ids at worst. Watch the access log for `ot` of about now − 90 d |
| **Newest-N retention with such clients:** a trimmed unread item vanishes and a client may mark it read locally | Default N=250, `trimmed_unread_count` in the health view, per-feed overrides. A mark-unread within 90 days restores and holds the item |
| **Stars and mark-unread on items older than `restore_days`** (stub purged) are still ignored, and the client undoes them | 90 days matches the article window some clients keep. The window is a setting (≤ 180) if the owner stars very old items from app caches |
| **Restore stubs cost disk** (about 270 MB at 90 days for busy feeds) | `retention.restore_days` can be lowered; the nightly snapshot size shows the cost |
| **The archive feed is hidden everywhere**, so a Reader API client sees archived starred items under a stream id it has no subscription for | The server still serves them in the starred and reading-list streams with their original feed name; a client that only shows starred items of its own subscriptions (a client may) will not show them. The web Starred view always does. "Purge unstarred" and deleting the archive (`DELETE /api/feeds/{id}?delete_starred=1`) remain API-only |
| **API `open` inference is not built.** No API read ever becomes an `open` (a Reader API client read counts only as read state) | The `inferred` column exists, but nothing writes `inferred=1` |
| **API subscribe without a synchronous fetch** (the default, decision 33) shows the feed named by its URL and no items until the next sync | Opt-in with `greader.subscribe_fetch_now` (phase 3): a bounded synchronous first fetch, 8 s per request |
| **GUID churn** produces a wall of unread | The fetch_log note (kept), a health-view flag, and one-click "mark this fetch read". No automatic judgement |
| **A dedup-mode change** needs a rekey; unmatched items are inserted read | An explicit user action; `rekey_pending` persists across restarts and the re-key runs on the feed's next fetch |
| **The ledger purge** (after max(180 days, `restore_days` + 7) since last seen) re-opens the tombstone for uids the publisher drops and later re-adds | Rare; shows as one unread item |
| **The `modernc.org/sqlite` and `libc` pin is fragile** | Pin both exactly. The plan-regression suite (fresh and `ANALYZE`d) and FTS integrity tests run on every bump. `ncruces/go-sqlite3` is the fallback |
| **FTS over a view** relies on FTS5 reading external content through a join | Validated on 3.50.4 (MATCH, snippet, integrity-check); re-validated on the pinned driver in the migration test. `'rebuild'` repairs from the view |
| **Write-lock latency** during a manual run or a huge first fetch | The commit gate plus 250-item chunking, and narrow rows for state writes. The fairness test asserts p99 ≤ 250 ms |
| **A writer-pool deadlock or leaked Rows** would silently stop ingestion (there is no monitoring, by design) | `WithWrite` is the only door, with a 10 s deadline and holder logging; store writes take `Querier`; the pool-free test helper is planned but not written (§10) |
| **The allocator can be seeded ahead of the clock** (bad RTC, manual error). Every id minted until real time catches up is "in the future": a client's `ot` matches those items on every refresh, and a client's `mark-all-as-read ts=<now>` never covers them, so they come back unread | Startup ERROR plus a health banner above 1 h ahead; NTP on the server. Kipple does not rewrite ids |
| **Unpadded bare-hex ids made only of digits** would be parsed as decimal | No target client sends them. A test documents the limitation |
| **SSE through cloudflared and Access** is unverified on this named tunnel | Pings every 15 s, `no-transform`, the `/api/status` polling fallback, and `curl -N` on the release checklist |
| **Access path precedence** for the `/api/greader.php` Bypass app has community reports of inconsistency | The external `curl` checks are mandatory. The root Reader routes never get a bypass |
| **Password exposure on the public ClientLogin** | A separate, generated API password, argon2id (m=19 MiB) behind a global semaphore of 1, a success memo, a per-client failure budget enforced before hashing by pacing, not refusal (one hash in flight per client, over budget a wait doubling from 2 s to 60 s, bounded waiting, IPv6 per /64, never 429), and redaction in logs. A distributed attacker gets at most ~20 guesses per second against a 24-character random password |
| **The stateless Reader token** can only be revoked by changing the API password | Accepted for a single user. The settings UI says so |
| **Cloudflare-challenged feeds** fail on TLS fingerprint | `error_class='cloudflare'` with actionable text; `disable_http2` and a UA override |
| **Per-host limits key on the exact hostname** | About 15 rounds of 1-2 s in a manual run at 138 feeds |
| **The uid, content_hash, text_hash and `url_key` rules** are embedded in stored data | Frozen before the first real import, with versioned prefixes. Any change needs a re-keying migration |
| **Extracted full text is not searchable**, and restores lose extracted full text | Accepted for phase 2. Re-extraction is on demand |
| **The in-memory full-text queue** (500 items) is lost on a restart, and the Reader full-text hold can delay a new item by up to 30 s | Extraction runs after the commit in the `ftrun` pool, so it never holds a fetch worker (§4.3). Items queued at a restart are extracted on demand when opened. The hold is capped at 60 s inside the `ot` slack, and open question 55 keeps a Reader API client check on the release checklist |
| **The Reader `summary.direction` is hard-coded `ltr`**, so right-to-left feeds render wrong in Reader API clients | Deferred in both the Reader API and the web UI (neither sets a text direction today). Deriving `rtl` from the feed or item `xml:lang` is a later fix |
| **Image cache growth and disk use** | Bounded by `imgproxy.cache_mb` (default 1 GiB, LRU to 90%, 60 day idle expiry) plus a free-space floor of max(2 GiB, 5%) below which nothing is written; the size shows in the health view and Settings; excluded from every backup. The index is a second SQLite file with its own 2 MB page cache (about 2 MB more than the §2.1 figure) |
| **Hotlink retries look like a browser** | Only after a 401/403/429 with no `Retry-After` or Cloudflare challenge, at most two extra requests per image, remembered per host; never sends Kipple's address or a cookie, and goes through the same SSRF-guarded transport |
| **Memory: SQLite heap is outside GOMEMLIMIT** | GOMEMLIMIT 64 MiB + 34 MB of caches + runtime < 100 MB, streaming contents, capped `i=`, keyset exports, a streaming image proxy, and a `mem_limit: 256m` backstop. RSS under load is on the release checklist |
| **The iOS Home Screen app** has its own cookie jar and WebKit bug 272325 | A persistent (Max-Age) cookie and a cheap re-login. A long Access session duration (about 1 month) |
| **The nightly snapshot is Kipple's only backup artifact**, and nothing watches it | `sys.last_snapshot_at` and `last_snapshot_error` shown in the health view (red after 48 h), plus a release-checklist item |
| **Image budget** (under 50 MB) is unmeasured with modernc plus 11 font families | Size check on the release checklist; fonts subset per the phase-3 plan |

# Section 12

## 12. Red-team dispositions

| # | Issue | Disposition | Reason |
|---|---|---|---|
| 1 | [major] Star or mark-unread on a trimmed item is silently undone by the next sync | **FIX** | 90-day `trimmed_content` restore stubs; `a=starred`/`r=read` restore the row with the same id (mark-unread held 7 d), so the next starred or unread list keeps the change (decision 17, §5). Validated; contract test added |
| 2 | [major] Null or missing fields where the reference servers always send strings | **FIX** | `iconUrl` always present (`""` when off); `htmlUrl`/`origin.htmlUrl`/`href`/`author` are `NOT NULL DEFAULT ''` in the schema; a golden-test rule allows no JSON null except `LSID` (decision 32) |
| 3 | [minor] Some clients' disable-tag sends the folder id raw, so `&`/`+` names are never deleted | **FIX** | The form parser keeps raw text; label lookup tries decoded, raw and PathUnescape forms; disable-tag glues unencoded name tails in the parser (§6.2). A client test with `News & Politics+` |
| 4 | [minor] ServeMux 301s `//` paths, dropping POST bodies | **FIX** | A front handler cleans slashes and prefixes and dispatches Reader paths with its own switch; no ServeMux sees them (decision 26, §6.1). Tests plus a release-checklist curl |
| 5 | [minor] Unrecognized Content-Type silently discards edits | **FIX** | `mime.ParseMediaType` with parameters ignored; every non-multipart POST body is parsed as a form; WARN on zero ids from a non-empty body (§6.1-6.2) |
| 6 | [minor] Item HTML never absolutized (client-compat) | **FIX** | Merged with #25: ingest-time resolution of every URL attribute, readability output included, relative leftovers dropped (decision 31) |
| 7 | [minor] quickadd on an existing URL returns 0 results; the `url_original` match is missing | **FIX** | Idempotent quickadd/`ac=subscribe` through `FindFeedByURL` (scheme-less `url_key`/`url_original_key`) returning `numResults:1` with the existing streamId (§6.9) |
| 8 | [minor] ot leg 2 empty when `c` is absent (`min(x, NULL)`) | **FIX** | Absent `c` binds to MaxInt64 descending and 0 ascending, never NULL; validated; the property test covers no-`c` (§3, §6.5) |
| 9 | [minor] Some clients never follow continuation, so unread beyond 10,000 is missing | **FIX** (residual **DEFER**) | Warning when unread > 10,000; an explicit UI import option marks old first-fetch items read. The client limit itself cannot be fixed server-side (§11) |
| 10 | [minor] Login lockout never checks the password and slides forever | **FIX** | The password is always verified; success clears the IP's count; only failures are delayed, in a fixed window (§6.3). Test: 20 bad then 1 good from the same IP succeeds |
| 11 | [minor] An allocator seeded ahead of the clock breaks ot and mark-all | **FIX** (residual **DEFER**) | Startup ERROR plus a health banner above 1 h ahead; the §11 row now names the ot/mark-all impact. Rewriting ids is not attempted |
| 12 | [major] Read/star state in the wide items row rewrites overflow pages | **FIX** | `items` split into a narrow row plus `item_content`; FTS over a join view; triggers moved and validated (decision 30). The WAL-bound test is designed but **not yet written** (§10). The alternative (column reorder plus `idx_items_read`) is rejected |
| 13 | [major] The one-connection writer deadlocks on nested acquisition or leaked Rows; maintenance can't run under `query_only` | **FIX** | `WithWrite` is the only door with a 10 s deadline and holder logging; store writes take a tx; `Recorder.Record(tx, …)`; a snapshot pool for `VACUUM INTO`; FTS integrity-check on the snapshot; weekly optimize dropped for automerge (decision 2, §2.1, §2.6) |
| 14 | [major] Reply channels and shutdown order can wedge the dispatcher or hang workers | **FIX** | Buffered reply channels, non-blocking dispatcher sends, handlers select on reply, timer and `shutdownCh`, a dispatcher draining until workers exit, commits under `WithoutCancel` with 10 s, a revised 7-step order, client-seen moved out of the dispatcher (§4.1, §4.10) |
| 15 | [major] VACUUM INTO refuses existing targets; foreign_keys may stay off | **FIX** | `MkdirAll` plus `Remove` before every VACUUM INTO; timestamped pre-migration names (newest 3 kept); foreign_keys restored in a defer and verified; last-snapshot time in the health view (§2.5, §2.6) |
| 16 | [minor] ot leg-2 NULL `c`, and no visibility slack on leg 2 | **FIX** | Same binding fix as #8; leg 2 uses `content_changed_at >= ot − 120`; the legs stay disjoint (validated) |
| 17 | [minor] FTS `AFTER UPDATE OF` fires on markup-only changes | **FIX** | `WHEN old IS NOT new` guards on every update trigger, SET lists built from changed columns, and `text_hash` gating; validated (`items_fts_data` 21 → 21) |
| 18 | [minor] GOMEMLIMIT doesn't bound SQLite; contents built unbounded | **FIX** | GOMEMLIMIT 64 MiB + 34 MB of caches budget, a streaming contents encoder, `i=` capped at 1000, `mem_limit: 256m`, an RSS-under-load checklist item (decision 35) |
| 19 | [minor] Long-lived read cursors in exports pin checkpoints | **FIX** (built in phase 4) | The stats export pages by keyset, 5000 rows per short query, fully read before writing; the OPML export is built before writing (§8) |
| 20 | [minor] Reader pool keeps only 2 idle connections | **FIX** | `SetMaxIdleConns(4)`, `SetConnMaxIdleTime(0)` (§2.1) |
| 21 | [minor] Stats ingest caps are check-then-insert across pools | **FIX** | Validation and inserts in one `WithWrite` transaction, counting earlier events in the same batch (§8). The concurrent-batch test is **not yet written** (§10) |
| 22 | [minor] Plans verified without ANALYZE on 3.50.4; production is 3.53.4/STAT4 | **FIX** | The plan suite (partly written, §10) runs on the pinned driver, fresh and after `ANALYZE`; `analysis_limit=400`; `optimize=0x10002` at open. `INDEXED BY` is kept: the leg always constrains the leading column, so it cannot become unsatisfiable (§2.3) |
| 23 | [minor] Mark-all cutoff and allocator seed include uncommitted or deleted ids | **FIX** | A missing `ts` → committed `max(id)` on a reader snapshot; `sys.id_high_water` persisted in CommitFetch; the stats scan dropped from the seed (§3) |
| 24 | [blocker] API open inference is on by default, so a client's scroll marks count as reads | **FIX** | The inference is **not built**, so a client's scroll-style read never counts as an `open`; the default is effectively permanent until inference is built. The views are built with `include_inferred` default 0 (streaks and never-opened exclude inferred rows); the contract test with scroll-style marks asserts 0 `open` rows (decision 21, §8) |
| 25 | [major] Relative image/link URLs never made absolute (product-rules) | **FIX** | Same as #6, plus golden tests through both the Reader API and the web API; `/img/` collision removed |
| 26 | [major] A manual run can stay open forever; refresh joins import/retention runs | **FIX** | In-flight feeds are attached to the run; `total = outstanding` at creation; the run ends when `outstanding` hits 0; only manual runs are joined; runs are per kind (§4.9). Scheduler test added. A watchdog is unnecessary because completion is structural |
| 27 | [major] Starring an item trimmed while a client still shows it is lost | **FIX** | Same restore mechanism as #1, also applied to the web star and mark-unread endpoints. The proposed crawl-age grace window is **REJECTED**: it breaks "newest N" on busy feeds and doesn't cover a client's 90-day article window |
| 28 | [major] OPML re-import and quickadd duplicate feeds after the http→https migration | **FIX** | One `FindFeedByURL` (normalized, scheme-less, `url` or `url_original` key) used by every subscribe path; `url_key` is UNIQUE; a re-import test expects 0 new feeds |
| 29 | [major] The OPML round trip loses titles, order and per-feed settings | **FIX** (partial **REJECT**) | The OPML title goes to `custom_title` (cleared if it equals the doc title after the first fetch); positions from document order; `kipple:` override attributes; `http_auth` never exported; case merges and dropped memberships reported. Keeping multi-folder membership is rejected: decision 9, some clients disallow it (§7.6) |
| 30 | [major] Unsubscribing hard-deletes starred items | **FIX** | Starred items are re-parented to a single archive feed (listed in subscription/list while non-empty until 2026-09-29; now never listed, #100); the web dialog shows the count with an opt-in delete (decision 24, §6.9). Validated |
| 31 | [major] Unbounded argon2id on the public ClientLogin | **FIX** (partial **REJECT**) | m=19 MiB/t=2/p=1, a global semaphore of 1 with a 5 s wait, a success memo, a generated 24-character API password. The global failure lockout is rejected for ClientLogin: it would let an attacker lock the owner out, and the semaphore already bounds global rate and memory. The web login keeps its per-IP lockout (10 failures per 15 minutes) and a 90-day cookie (the owner's decision) |
| 32 | [minor] The backoff cap makes long-interval feeds poll more often when failing | **FIX** | `delay_s = min(interval_s·2^(n−1), max(86400, interval_s))`; 10080-minute rows in the backoff test (§4.6) |
| 33 | [minor] The health view's history and trim signals erode quickly | **FIX** | fetch_log kept 14 days with a 50-row floor, the last 10 errors kept, `keep=1` for redirect/churn/rekey notes; `last_error*` kept after success; an immutable `trimmed_unread_count` excluding the items the trimming transaction inserted (§5), with a reset; no ledger update for starred-scope mark-all (§4.8, §5) |
| 34 | [minor] Lowering per-feed retention does nothing until new items arrive | **FIX** | Trim runs on every successful fetch (ok/unchanged/not_modified), and a retention PATCH or default change enqueues `trim_only` jobs (decision 18) |
| 35 | [minor] The API "never fetch" exceptions need the owner's sign-off | **FIX** (opt-in only; the default keeps the rule) | The default now has no outbound HTTP on any Reader API path: the feed is inserted as due and the scheduler fetches it within 30 s. An opt-in synchronous path (`greader.subscribe_fetch_now`, default off, 8 s per request) was built in phase 3 (decision 33) |
| 36 | [minor] Image proxy buffering, AVIF sniffing, private-net feeds | **FIX** | Content-Length pre-check then streaming with `MaxBytesReader` and an abort on overflow; AVIF by `ftyp` brand with an allow-listed upstream-type fallback; signed `flags` carry `allow_private_net`/`allow_insecure_tls`; a fetch semaphore of 8 (§7.4) |
| 37 | [minor] SameSite=Lax doesn't protect against same-site origins | **FIX** | `Sec-Fetch-Site: same-origin` (or a matching `Origin`) plus a required `X-Kipple-Client` on every state-changing cookie request; the beacon is exempt from the header only (§7) |

# Section 13

## 13. Deltas from lemon24/reader (status)

A research note on lemon24/reader (not kept in this repository) compared this design with a mature SQLite feed-reader library. Most of its ADOPT items were already here (per-connection pragmas in the DSN, `application_id`, `foreign_key_check` after migrations, `PRAGMA optimize`, a date-free `content_hash`, validators and body hash, per-feed resync, keeping stats rows without a cascade from `items`). This section was first written as "applied after the red team"; it is now a status table, one line per delta, so it never contradicts the body.

| # | Delta | Status |
|---|---|---|
| 1 | `synchronous=NORMAL` and `busy_timeout=5000` in every DSN | **Built** (`buildDSN`). WAL with `NORMAL` loses at most the last commits on power loss, which the next poll refetches |
| 2 | Startup self-check for JSON1 and FTS5 | **Built** (§2.1, `internal/store/selfcheck.go`) |
| 3 | Last-new-item time on the feed | **Built** as `feeds.last_new_items_at` (§2.2), written when a fetch inserts an item. Drives the `silent` status (§4.6) |
| 4 | Reading time with `image_count` and 265 wpm | **Dropped.** Reading time is `ceil(word_count / 230)`, null under 100 words, computed at serve time (§7.1). No `image_count` column |
| 5 | `porter` tokenizer with `bm25(items_fts, 4.0, 1.0)` | **Superseded and built** by the round-2 backend additions (a research note not kept in this repository): porter over unicode61 (diacritics folded) with a persistent `bm25(4,2,1)` rank, migration 0005 |
| 6 | 403 browser-UA fallback persisted as `feeds.ua_mode` | **Superseded** by `feeds.ua_fallback` (migration 0002) and the `fetch.user_agent_mode` setting (§4.4) |
| 7 | `Retry-After` HTTP-date relative to the response `Date` | **Built** (§4.4, `fetch.ParseRetryAfter`) |
| 8 | URL migration resets fetch state | **Dropped for redirects**: a redirect migration keeps validators and the items (§4.7). **Kept for manual URL edits**, which already clear them (`feedadmin.go`) |
| 9 | A malformed item is skipped, not fatal | **Built** (§4.3): an empty entry (no title, link, guid, text, enclosure or image) or one whose conversion fails is dropped and counted in the `skipped_malformed_items: n/total` fetch_log note. A document that does not parse at all is still a failed fetch, because the XML parser cannot resume after a syntax error. An entry whose only content is an enclosure or image (a podcast or photo feed) is kept: its title is the media file name (else the feed title) and its first media URL stands in as the guid, so each gets its own uid. |
| 10 | Enclosures deduplicated by URL at ingest | **Built** (`fetch.ParseFeed`), by resolved URL |
| 11 | Normalized links for dedup (`l:` uid and `link_hash`) | **Dropped.** The uid rules are frozen (§4.8, §11): they hash the raw link, and re-normalizing would change the uid of every live item, so the next fetch would re-insert a wall of duplicates. The common http to https migration is handled by the redirect policy (§4.7) instead |
| 12 | Slow-stage WARN (a stage of 1 s or more) | **Dropped.** It is log noise, and monitoring is a non-goal; `fetch_log` already records durations |

Rejected from reader, with reasons in the report: grid-snapped scheduling, dropping exponential
backoff, non-atomic entries-then-feed writes, `A-IM: feed` deltas, post-hoc delete-and-merge dedup
(ids already served to Reader clients cannot be retracted), a separate search database, and a
tri-state starred flag.
