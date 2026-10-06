# Backend additions, round 2 (2026-09-25)

Research only: no code changes. This turns the owner's round-1 answers (`docs/ui-decisions.md` on branch
`design/ui-round-1`) and the audit (`docs/research/design-audit-2026-09-25.md`, same branch) into backend specs.
Checked against `phase-2` at 90450e9 (migrations 0001-0003, `internal/`, `cmd/kipple`).

**Conventions for everything below.**

- Every new `/api/*` route uses `s.authed` (session cookie, plus the same-origin rules for non-GET requests). Ids are
  strings in JSON. Times are unix seconds.
- New schema goes in **0004** (filters, mute marker, devices, auto-read, categories) and **0005** (FTS porter). Both are
  additive or rebuild-only. The runner already takes `VACUUM INTO pre-migration-3-5-*.db` before applying them (§2.5).
  Rollback means restoring that snapshot, which the owner accepted (audit Q7).
- The image cache index is a **separate** SQLite file (`/data/imgcache/index.db`), not a migration of `kipple.db`.
- Effort: **S** is about half a day, **M** is 1-2 days, **L** is 3 days or more, for one Sonnet step with tests.

---

## 1. Filters: one rules engine, and features in the same family

### 1.1 Purpose

The owner said yes to keyword mute filters (audit Q8). One small engine covers mute, mark read on arrival, auto-star,
highlight, and "only show matching", scoped globally, to a folder, or to a feed. Reader clients must agree with the web
UI without knowing that filters exist.

### 1.2 Model

| Field | Values | Notes |
|---|---|---|
| `scope` | `global` \| `folder` \| `feed` | The folder is resolved at match time through the feed's *current* folder |
| `kind` | `text` \| `regex` | `text` matches literal terms. A multi-word term is a phrase: the words in order, with any whitespace between them |
| `terms` | 1-50 strings | Any one of them matches. `text`: each 1-100 runes. `regex`: 1-5 patterns, each ≤ 256 bytes |
| `fields` | a subset of `title`, `author`, `content`, `url`, `category` | Default `["title"]`. `content` is `content_text` (the first 32 KB for `text`, the first 8 KB for `regex`) |
| `case_sensitive` | bool, default false | |
| `whole_word` | bool, default true (`text` only) | The runes on each side of the match must not be letters or digits (Unicode classes) |
| `fold_diacritics` | bool, default true (`text` only) | NFKD, then Mn marks dropped (`golang.org/x/text`, already a dependency) |
| `invert` | bool | Acts on items that do **not** match. This gives "only show articles about X" for a feed |
| `action` | `mute` \| `mark_read` \| `star` \| `highlight` | See §1.3 |
| `enabled`, `name`, `position` | | `position` only sets the display order. Evaluation order does not matter (§1.3) |

**Rejected actions.** "Move to folder" (folders belong to feeds in both the Reader model and the schema) and
"add a label" (there is no tag model and none is wanted).

### 1.3 Actions and precedence

Every enabled rule in scope is evaluated, and the results combine as a set:

| Result | Effect at ingest |
|---|---|
| `star` matched | `starred=1, starred_at=now`. **Star beats mute**: the item is not muted, although it may still be marked read |
| `mute` matched (and no star) | `read=1, read_at=now, muted_by=<filter id>` (the lowest matching id). The item is hidden from every web list except the Muted view |
| `mark_read` matched | `read=1, read_at=now`. The item stays visible in "All" |
| `highlight` | No stored state. It is served to the client (§1.7), which highlights matches in titles and articles. **`text` kind only**, because JS regex is not RE2 and the two sides must agree |

- None of these is a stat (§8: bulk and rule-driven read changes are never reads).
- `initial_read_before` and the rekey leftovers still apply. A rule can only add `read=1`, never clear it.

### 1.4 How muted items appear

**Decision: mark muted items read at ingest, and flag them with `items.muted_by`.**

- **Reader API.** No change. Muted items are ordinary read items, so they drop out of client A's and NNW's unread lists
  and `unread-count` with no special-casing. They stay in `reading-list` as read items. Hiding them there too would make
  items vanish from a list after a retroactive apply, which gains nothing.
- **Web lists.** `view=all` and feed or folder views add `AND i.muted_by IS NULL`. The unread view needs nothing,
  because `read=0` already excludes muted items. Search excludes muted items unless `view=muted`.
- **Muted view.** `GET /api/items?view=muted` returns items with `muted_by IS NOT NULL`, served by the partial index
  `idx_items_muted`. Cards gain `muted_by` (a filter id string or null).
- **Restore.** A plain mark-unread (`POST /api/items/mark-read {ids, read:false}`, or Reader `r=read`) clears
  `muted_by` in the same `UPDATE`. A manual star (`SetStarred(true)`) also clears it. No new endpoint is needed.
- **Invariant.** `muted_by IS NOT NULL` implies `read = 1`. It is enforced in `SetRead` and `SetStarred`, not by a
  CHECK: a missed path must never turn Reader `edit-tag` into a 500. A store test scans for violations after every
  state test.
- **Counts.** Unread counts do not change. Bootstrap `counts.muted` (the total) uses the partial index.

### 1.5 When rules are applied

| Moment | Rule |
|---|---|
| **Ingest** | In `applyItems`, for each *fresh* item before its `INSERT`. It runs in Go on the parsed `fetch.Item`, whose fields are already in memory. Existing items whose content changes are **not** re-evaluated, so state never flips on an edit |
| **Retroactive** | Only as an explicit "Apply to existing articles" action after a preview. By default it covers unread, non-starred items; `include_read` extends it to read ones |
| **Preview (dry run)** | `POST /api/filters/preview` evaluates a saved or unsaved rule on the reader pool. Rows are paged by keyset (`id DESC`, 1000 per query, no long read transaction). It has a 5 s budget and returns `{matches, scanned, truncated, sample:[Card ≤ 20]}` |

- **Compiled-rule cache.** `store.DB` holds the compiled set and a generation counter, which every filter write bumps.
  `CommitFetch` recompiles only when the generation has changed. Only the server process writes filters.
- **Hits.** Each commit runs `UPDATE filters SET hits = hits + ?, last_hit_at = ?` per matched filter, and adds the
  fetch_log note `filters: muted k, read k, starred k` (`keep = 0`).
- **Full text.** `CommitInfo` returns `MutedIDs`, and `queueFulltext` skips them. The SSE `fetch.done` payload leaves
  them out of `new_item_ids` and adds `muted_items`.

### 1.6 Interplay

- **Retention.** Muted items are trimmed **first**. The trim selection becomes
  `ORDER BY (muted_by IS NULL) DESC, sort_at DESC, id DESC`, so N counts real items before noise. The per-feed set is
  at most a few thousand rows, so the temp sort is trivial. The ledger and stubs are unchanged. A restore brings items
  back with `muted_by = NULL` (restoring is an explicit "I want this").
- **FTS.** Unchanged. The matcher is Go-side, so the ingest, preview and apply paths share one implementation, and
  porter stemming (§7) cannot make them disagree.
- **Mark-all.** It is unaffected, because muted items are already read.
- **Deleting a filter.** `DELETE /api/filters/{id}?unmute=keep|read|unread`, default `read`. `read` clears `muted_by`,
  so the items reappear as read in "All". `unread` also sets them unread (bulk, no stats). `keep` leaves them as orphans,
  shown as "muted by a deleted filter". Folder and feed deletes cascade the filter, and its items keep `muted_by`
  (orphans).

### 1.7 API

| Method and path | Request | Response |
|---|---|---|
| `GET /api/filters` | - | `{filters:[Filter]}` |
| `POST /api/filters` | `Filter` without `id`, plus optional `apply_existing:{include_read:bool}` | `201 {filter, applied:{changed:n}}` |
| `PATCH /api/filters/{id}` | any `Filter` field | `filter`. Never retroactive by itself |
| `DELETE /api/filters/{id}` | `?unmute=keep\|read\|unread` | `{changed:n}` |
| `POST /api/filters/preview` | `{filter:<unsaved>}` or `{id}`, plus `include_read` | `{matches, scanned, truncated, sample}` |
| `POST /api/filters/{id}/apply` | `{include_read:false}` | `{changed:n}`. Batched 500 ids per `WithWrite` behind the commit gate. Publishes `items.state` or `resync`, then `counts` |
| `GET /api/items?view=muted` | as for other views | Cards with `muted_by` |

`Filter` is `{id, name, enabled, scope, folder_id, feed_id, kind, terms, fields, case_sensitive, whole_word,
fold_diacritics, invert, action, position, hits, last_hit_at, created_at, updated_at}`. Bootstrap adds
`highlights:[{id, scope, folder_id, feed_id, terms, fields, case_sensitive, whole_word, fold_diacritics}]` for the
client.

### 1.8 Schema sketch (0004)

```sql
CREATE TABLE filters (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 1 CHECK (enabled IN (0,1)),
  scope TEXT NOT NULL CHECK (scope IN ('global','folder','feed')),
  folder_id INTEGER REFERENCES folders(id) ON DELETE CASCADE,
  feed_id   INTEGER REFERENCES feeds(id)   ON DELETE CASCADE,
  kind TEXT NOT NULL CHECK (kind IN ('text','regex')),
  terms  TEXT NOT NULL CHECK (json_valid(terms) AND json_type(terms) = 'array'),
  fields TEXT NOT NULL DEFAULT '["title"]' CHECK (json_valid(fields)),
  case_sensitive  INTEGER NOT NULL DEFAULT 0 CHECK (case_sensitive IN (0,1)),
  whole_word      INTEGER NOT NULL DEFAULT 1 CHECK (whole_word IN (0,1)),
  fold_diacritics INTEGER NOT NULL DEFAULT 1 CHECK (fold_diacritics IN (0,1)),
  invert          INTEGER NOT NULL DEFAULT 0 CHECK (invert IN (0,1)),
  action TEXT NOT NULL CHECK (action IN ('mute','mark_read','star','highlight')),
  position INTEGER NOT NULL DEFAULT 0,
  hits INTEGER NOT NULL DEFAULT 0, last_hit_at INTEGER,
  created_at INTEGER NOT NULL DEFAULT (unixepoch()), updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  CHECK ((scope='global' AND folder_id IS NULL AND feed_id IS NULL)
      OR (scope='folder' AND folder_id IS NOT NULL AND feed_id IS NULL)
      OR (scope='feed'   AND feed_id IS NOT NULL AND folder_id IS NULL)),
  CHECK (action != 'highlight' OR kind = 'text')
) STRICT;
ALTER TABLE items ADD COLUMN muted_by INTEGER;             -- filter id; no FK (orphans are allowed)
CREATE INDEX idx_items_muted ON items(sort_at, id) WHERE muted_by IS NOT NULL;
ALTER TABLE item_content    ADD COLUMN categories_json TEXT CHECK (categories_json IS NULL OR json_valid(categories_json));
ALTER TABLE trimmed_content ADD COLUMN categories_json TEXT;
```

**Migration notes.**

- `ADD COLUMN` with a NULL default is O(1) with no row rewrite. The partial index starts empty.
- `categories_json` is filled for new items only: gofeed `Categories`, at most 20 entries of 100 runes each. The
  `category` field therefore does not match items stored before the deploy, and the preview says so.
- `muted_by` lands after `origin_title`. That is harmless: items rows are narrow and never overflow.

### 1.9 Limits and regex safety

- At most 200 filters and 25 regex filters. All enabled `text` terms together are capped at 2000.
- **Regex.** Go `regexp` is RE2 (linear time, no backreferences). Each pattern is compiled with `(?i)` unless
  `case_sensitive`. It is rejected when:
  - its `syntax.Prog` has more than 5000 instructions;
  - it matches the empty string (for example `a*`, which would match everything);
  - it contains `\C`.
  Errors return `400 {"error":"bad_filter","field":"terms[2]","message":…}`.
- **Performance.** Each item's haystack is normalized once per field. Single-word `text` terms are looked up in a word
  set built from that field. A phrase checks its first word in the set, then verifies by substring. Cost is
  O(text + terms), not O(text × terms). Regexes run on the capped prefixes above.
  - Budget: under 5 ms per item at 25 regexes, and under 2 s for a 250-item first fetch. The benchmark test sets both
    ceilings.
  - A retroactive apply over about 35k items streams roughly 35k × 32 KB. That is seconds on the reader pool, with writes
    batched.

### 1.10 Edge cases

- **Invert with several rules.** Each rule inverts on its own. Two inverted `mute` rules on one feed mute anything that
  fails either one. The UI warns when a scope has more than one inverted rule.
- **Folder scope after a feed moves.** New items follow the new folder. Past items keep their state.
- **Archive feed.** Items there never reach ingest, and scope `global` skips it for retroactive applies.
- **Rekey leftovers.** They are inserted read, and filters still run (a star can apply).
- **Reader `a=starred` on a muted item.** It clears `muted_by` (through `SetStarred`).
- **An item matching `mark_read` and `highlight`.** It is read and highlighted.

### 1.11 Tests

- **Engine (table tests).** Word boundaries in Latin, CJK and with punctuation; phrase whitespace; diacritic folding;
  case; invert; precedence (star > mute > mark_read); the empty-match regex rejected; the program-size cap; fuzzing that
  never panics.
- **Store.**
  - An ingest with mute sets `read=1, muted_by`, and Reader `unread-count` and `stream/items/ids xt=read` exclude the
    item.
  - `r=read` and web mark-unread clear `muted_by`; a star clears it.
  - The trim order puts muted items first.
  - The invariant scan passes.
  - Muted items skip the full-text queue.
  - The fetch_log note is written.
- **API.** CRUD validation; the preview budget and truncation; apply batching and the SSE events; the three `unmute`
  modes; `view=muted` pagination.
- **Plans.** `idx_items_muted` is used for `view=muted`, and `view=all` keeps `idx_items_sort` (both fresh and
  `ANALYZE`d, in the existing plan suite).

**Effort L** (split in §11). **Risks:** a rule that is too broad silently eats articles. Mitigations are the
preview-first UI, hit counts, the Muted view, and the rule that a restore is one tap.

### 1.12 The family: brainstorm, ranked

"Value" is for a daily Feedly-style reader. "Fit" checks against the non-goals (no AI, notifications or social).

| # | Feature | Value | Effort | Mechanism | Fit | Recommendation |
|---|---|---|---|---|---|---|
| F1 | **Keyword mute / mark read / auto-star** | High | L | §1.2-1.9 | OK | **Phase 2** |
| F2 | **Per-feed "only show matching"** | High | 0 | `invert` on a mute rule | OK | **Phase 2** (free with F1) |
| F3 | **Keyword highlights** | Med | S | `highlight` action, client-side | OK | **Phase 2** |
| F4 | **Saved searches / smart views** | High | S | Setting `library.saved_searches`: ≤ 50 entries of `{id, name, q, view, feed_id\|folder_id, order}`, listed in the sidebar. Counts on demand only | OK | **Phase 2** |
| F5 | **Auto-mark-read after N days unread** | High (keeps unread under client A's 10,000-id limit) | M | §1.13 | OK | **Phase 2** |
| F6 | **Reading-time filter** ("quick reads under 5 min") | Med | S | `min_minutes`/`max_minutes` on `/api/items` → `word_count BETWEEN` (230 wpm) | OK | **Phase 2** |
| F7 | Per-feed or per-folder layout, view and order | Med | S | `ui.layouts` values become `{layout, view, order}` (audit U2). Stored per device (§4) | OK | **Phase 2** (the frontend drives it) |
| F8 | Cross-feed duplicate collapsing (same article via an aggregator and its source) | Med | M | At ingest, an exact normalized-URL match against items of other feeds in the last 14 days marks the later copy read with `dup_of`. Needs `idx_items_url`. Deterministic only; no fuzzy or ML similarity | OK | **Later** (phase 3+) |
| F9 | Snooze / read later with resurfacing | Med | M | `snoozed_until`: the item is marked read now and flipped unread by the maintenance job. client A sees it come back in its unread list (no notification) | OK | **Later**. "Starred = read later" covers the need now (audit) |
| F10 | Daily digest view ("since yesterday", grouped by feed, top 3 each) | Med | S (backend) | `since=` on `/api/items` plus client grouping | OK | **Later** (phase 3 UI) |
| F11 | Source priority / pinned feeds | Low-Med | S | `feeds.priority` ordering the sidebar, plus a "Priority" smart view (F4 with a feed set) | OK | **Later** |
| F12 | Quiet hours per feed (hold delivery) | Low | M | Would delay visibility by clock time | **Scope creep**: it is delivery scheduling, the notifications family | **Reject** |
| - | "Trending", "popular with others", AI summaries or clustering | - | - | - | **Non-goals** (social, AI) | **Reject** |

### 1.13 Auto-mark-read after N days (F5)

- **Setting.** `library.auto_read_days` (0 = off, the default; else 1-365). Per feed, `feeds.auto_read_days` (NULL
  inherits, 0 = off for this feed) is added in 0004. Folders get "apply to all feeds in folder" (audit: no inheritance
  level).
- **Semantics.** "Unread for longer than N days *in Kipple*": crawl time, `id`. Each item crosses the threshold
  **once**, so a later manual mark-unread sticks.
  - Hourly, maintenance keeps `sys.auto_read_last_run`. For each enabled feed it marks read the unread, non-starred,
    non-held items whose crawl time is in `(last_run − N·86400, now − N·86400]`.
  - It is batched 1000 per transaction behind the gate, with no stats. It publishes `counts` (and `resync` above
    `MaxStateIDs`).
- **Setting change.** A change runs a one-time catch-up over `id < now − N·86400`, confirmed in the UI with the count
  from a dry-run endpoint `GET /api/auto-read/preview?days=`.
- **Tests.**
  - Window arithmetic across a DST change (it uses unix time, so no DST risk; a test pins that).
  - A manual mark-unread survives the next run.
  - Starred and `retain_until` items are exempt.
  - The catch-up count equals the preview.

---

## 2. Image cache (proxied and cached, bounded) and thumbnails

This replaces §7.4's "No disk cache in phase 2" (the owner: lead images are proxied and cached, and the cache must not grow
out of hand).

### 2.1 Mode default

`imgproxy.mode` defaults to **`all`**, so every image goes through Kipple. That covers privacy, hotlink avoidance,
same-origin images for the service worker, and a strict CSP `img-src 'self'` (§5). `http_only` stays as an option. The
setting becomes visible as "Load all images through Kipple (more private)".

### 2.2 Layout

- **Files.** `/data/imgcache/v1/<k[0:2]>/<k>`, where `k` = the first 32 hex of `sha256("img-v1|" + variant + "|" + flags
  + "|" + url)`. That is URL-addressed with the content hash stored beside it.
  - **Why not content-addressed filenames:** they need refcounting across URLs, and duplicate bytes across URLs are rare
    for feed images. `sha256(body)` is stored and serves as the ETag, which gives the integrity benefit without the
    bookkeeping.
- **Temp files.** `/data/imgcache/tmp/<random>`, renamed into place.
- **Index.** `/data/imgcache/index.db` is its own SQLite file: WAL, `synchronous=NORMAL`, and one writer connection that
  the cache package owns. It is **not** `kipple.db`, because per-hit LRU updates must never touch the single
  writer/commit gate that fetch commits and edit-tags depend on. It is outside `VACUUM INTO`, snapshots, export and
  migrations. A corrupt or old-schema index is renamed away and rebuilt empty, which is safe for a cache.

```sql
CREATE TABLE entries (
  key TEXT PRIMARY KEY, url TEXT NOT NULL, flags INTEGER NOT NULL, variant TEXT NOT NULL DEFAULT 'orig',
  status TEXT NOT NULL CHECK (status IN ('ok','neg')),
  content_type TEXT, size INTEGER NOT NULL DEFAULT 0, sha256 TEXT, etag TEXT, last_modified TEXT,
  fetched_at INTEGER NOT NULL, fresh_until INTEGER NOT NULL, last_access_at INTEGER NOT NULL,
  neg_status INTEGER, neg_count INTEGER NOT NULL DEFAULT 0
) STRICT, WITHOUT ROWID;
CREATE INDEX idx_lru ON entries(last_access_at) WHERE status = 'ok';
CREATE INDEX idx_neg ON entries(fresh_until) WHERE status = 'neg';
CREATE TABLE hosts (host TEXT PRIMARY KEY, referer TEXT NOT NULL CHECK (referer IN ('none','self')),
                    ua TEXT NOT NULL CHECK (ua IN ('kipple','browser')), updated_at INTEGER NOT NULL) STRICT, WITHOUT ROWID;
CREATE TABLE meta (key TEXT PRIMARY KEY, value TEXT NOT NULL) STRICT, WITHOUT ROWID;   -- schema_version
```

### 2.3 Behavior

| Aspect | Rule |
|---|---|
| **Size cap** | Setting `imgcache.max_mb`: options 0 (off), 256, 512, **1024 (default)**, 2048, 5120 and 10240. Over the cap, evict to 90 % of it |
| **Eviction** | **LRU** on `last_access_at`. Feed images are viewed once or twice while recent, so frequency adds nothing |
| **Access time** | Buffered in memory and flushed every 60 s in one transaction (`UPDATE … WHERE key IN json_each`), so a hit never waits on a write |
| **Idle expiry** | Entries not accessed for 60 days are deleted by the eviction sweep (every 10 min, and after inserts that cross the cap). The cache then tracks what the owner still reads |
| **Freshness (TTL)** | `fresh_until = fetched_at + clamp(upstream max-age, 1 d, 30 d)`, 7 d when absent. After that the next request revalidates with `If-None-Match`/`If-Modified-Since` (3 s budget). On 304 the dates are updated. On any error or timeout the **stale copy is served** |
| **Per-object cap** | Objects over **8 MiB** stream through uncached (the proxy's 15 MiB limit still applies) |
| **Negative cache** | 404 and 410: 7 d. 403, 415 and the type refusal: 24 h. Too large: 24 h. 5xx, timeout and DNS: 10 min × 2^`neg_count`, capped at 24 h. Served as 502/404 with `Cache-Control: no-store`, without contacting upstream. At most 20k neg rows; the oldest are pruned |
| **Hotlink workarounds** | Default: no `Referer` and the Kipple UA, with a browser-like `Accept: image/avif,image/webp,image/*;q=0.8`. On a 403 with neither `cf-mitigated` nor `Retry-After`: retry once with `Referer: <image origin>/`, then once with the browser UA (`fetch.user_agent` or the built-in browser string). The winning combination is saved in `hosts`. It never sends the article URL or `rss.example.com` |
| **Concurrency** | Single flight per key: followers wait for the leader's file, and a failed leader gives followers 502 with no stampede. The existing 8-slot upstream semaphore is kept |
| **Write path** | `io.MultiWriter(client, tmpfile)` streams to the client while it writes. At EOF, if the object is ≤ 8 MiB and the type checks pass, rename it into place and insert the row. On abort, overflow or an upstream error, delete the temp file. No fsync (it is a cache) |
| **Serving a hit** | `http.ServeContent` from the file (Range, conditional requests). `ETag: "<sha256[:16]>"`, `Cache-Control: private, max-age=2592000, immutable`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'`, `Cross-Origin-Resource-Policy: same-origin` |
| **Disk guard** | Before a write, `unix.Statfs` on `/data` (behind a build tag; a no-op off Linux). If free space is under max(2 GiB, 5 %), skip caching, WARN at most hourly, and set the eviction target to 50 % of the cap |
| **Startup** | Empty `tmp/`. Open the index (on failure, rename and recreate). Load `SUM(size)` into memory. A background walk removes files without rows and rows without files. On a hit whose file is missing, delete the row and refetch |
| **Cap change** | A PATCH of `imgcache.max_mb` calls `cache.SetCap`: a lower cap evicts asynchronously; 0 disables writes and purges everything in the background (the proxy streams as today) |
| **Clear** | Deletes every row and file in the background. Neg rows and `hosts` are cleared too |

**Volume and disk.** The Host-A named volume has no quota of its own, so the cap plus the disk guard are the bound.
Backups exclude `/data/imgcache` automatically: the export (§6) and the Host-B pull copy only the snapshot. Note in the
RUNBOOK: any host-level volume backup should exclude `imgcache/`.

**Thumbnails decision: yes, for card lead images only.**

- **URL.** `flags` bit 2 (`FlagThumb = 4`) is signed like the other flags, so the variant is bound to the URL.
- **Pipeline.** Fetch or reuse the `orig` entry, then `image.DecodeConfig`. When width > 800 **and** size > 150 KB:
  1. decode (stdlib `image/jpeg`, `image/png` and `image/gif` first frame; `golang.org/x/image/webp`, pure Go, a new
     x/ dependency);
  2. resize to 800 px wide with `x/image/draw.ApproxBiLinear`;
  3. encode JPEG at q=78, or PNG at `BestSpeed` when the source has alpha.
- **Fall back to the original** for AVIF (no pure-Go decoder), animated GIF, images over 24 MP (memory: roughly 36 MB
  decoded against GOMEMLIMIT 64 MiB), and decode errors.
- **Limits.** One transcode at a time with a 3 s budget; on a miss, serve the original.
- **Card.** `image` points at the thumbnail. The detail view and inline images keep the original.

### 2.4 API and settings

| Method and path | Response |
|---|---|
| `GET /api/imgcache` | `{enabled, max_bytes, used_bytes, entries, neg_entries, thumbnails, hits, misses, since (process start), oldest_access_at, disk_free_bytes}` |
| `POST /api/imgcache/clear` | `202 {entries}` |

Settings (group `images`, surface `settings`): `imgproxy.mode`, `imgcache.max_mb`, `imgcache.thumbnails` (bool, default
true).

### 2.5 Tests and risks

- **Tests.**
  - LRU order and the evict-to-90 % rule; a lower cap; cap 0 behaves as the proxy does today.
  - Idle expiry; neg-cache TTLs and backoff; revalidation 304 and serve-stale on error.
  - Single flight: 20 concurrent requests make 1 upstream call.
  - An object over 8 MiB is not cached.
  - Crash recovery: a leftover temp file, a missing file, a corrupt `index.db`.
  - The disk guard, through an injected statfs.
  - The key covers flags and variant; the hotlink retry sequence and the saved host hint.
  - Thumbnails: size, alpha to PNG, AVIF and GIF fall back; response headers.
  - A heap ceiling under a 24 MP decode, measured with `testing.AllocsPerRun`/`runtime.ReadMemStats`.
- **Effort.** L for the cache, M for thumbnails.
- **Risks.**
  - Memory spikes from decoding, handled by the pixel cap and one worker.
  - A second SQLite file doubles the driver's page cache: set `cache_size(-2000)` there, which adds 2 MB to the §2.1
    budget.

---

## 3. Ordering and mark above/below

### 3.1 `order=oldest`

- `GET /api/items?order=date|oldest|rank`. `date` stays the default (newest first).
- `oldest`: `ORDER BY i.sort_at ASC, i.id ASC`, keyset `(i.sort_at, i.id) > (?, ?)`. The same indexes are scanned
  forward, so plans do not change.
- **Cursor.** The text gains an order tag (`a<sort>.<id>` for ascending). The existing untagged form means `date`, so
  outstanding cursors stay valid. A cursor used with another order returns 400, as the rank mismatch does today.
- **Search** supports `date` and `oldest` (and `rank`).

### 3.2 Mark above/below, resolved

The bound is the **list's own `(sort_at, id)` order**, not crawl time. `max_id` stays, as a separate snapshot guard
("existed when this list was loaded"), so a newly arrived item with a high `sort_at` is never swept up.

```json
POST /api/items/mark-read
{ "scope": {"feed_id":"12" | "folder_id":"3" | "all":true, "view":"unread|all|starred|muted", "q":"optional search"},
  "bound": {"order":"date|oldest", "side":"above|below", "anchor":{"sort_at":1758700000, "id":"1758700000123456"},
            "inclusive": false},
  "max_id": "1758700999000000", "read": true, "reason": "bulk" }
```

| `order` | `side` | Predicate |
|---|---|---|
| `date` (newest first) | `above` | `(sort_at, id) > (:sa, :id)` |
| `date` | `below` | `(sort_at, id) < (:sa, :id)` |
| `oldest` | `above` | `(sort_at, id) < (:sa, :id)` |
| `oldest` | `below` | `(sort_at, id) > (:sa, :id)` |

- `inclusive:true` turns `<`/`>` into `<=`/`>=`, which includes the anchor. The default excludes it.
- The anchor comes from the card the client holds, so no lookup is needed and a trimmed anchor still works.
- **`scope.q`** adds `AND id IN (SELECT rowid FROM items_fts WHERE items_fts MATCH :m)`, built by the same query
  builder (§7). This makes "mark all search results read" possible.
- **Validation.** `bound` requires `scope`. `read:false` stays by ids only (the existing rule). `order` must match the
  list, and the client sends what it shows.
- **Ledger.** Bounded scopes **never** touch `trimmed_items`: the ledger has no `sort_at` once the stub is gone. The
  unbounded scope keeps today's ledger update. Ledger read flags only matter for star restores, so this loses nothing.
- **Reader API and retention.** No change. A trim between loading the list and marking is harmless (missing ids).
- **SSE.** `items.state`, or `resync` above `MaxStateIDs`, then `counts`.

**Tests.**

- Pagination property: no duplicate or skipped card across pages with equal `sort_at` ties, in both orders.
- The four order × side combinations, inclusive and exclusive.
- `max_id` excludes a later arrival whose `sort_at` falls inside the range.
- `q` scope; starred and folder scope; a cursor/order mismatch returns 400.
- Plans for the ascending keyset (fresh and `ANALYZE`d).

**Effort M. Risk:** a wrong comparison marks too much. The table test covers all combinations, and the UI's undo toast
reverts through `{ids, read:false}` using the returned `changed` list, which is capped at 10,000 ids (above the cap:
`resync`, no undo).

---

## 4. Per-device appearance

**Recommendation: server-side profiles keyed by an HttpOnly device cookie, with localStorage used only as a paint
cache.**

| Option | Survives ITP 7-day eviction (Safari tabs) | "Copy from my phone" | In backups | Verdict |
|---|---|---|---|---|
| localStorage per device + server default profile | **No**: script-writable storage is wiped after 7 days without a visit in Safari (installed Home Screen apps are exempt) | Needs server storage anyway | No | Rejected |
| **Server profile per device id (server-set HttpOnly cookie)** | **Yes**: first-party, server-set cookies are not in the 7-day script-storage cap. Same host and IP via Cloudflare, so the 16.4+ IP-mismatch cap does not apply | Yes | Yes | **Chosen** |

- **Cookie.** `kipple_device`: 128-bit random base64url, HttpOnly, `Secure` when https, `SameSite=Lax`, `Max-Age` 400
  days, re-issued at most monthly. It is issued by login and by bootstrap when missing. It grants nothing: it only
  selects a profile. An iOS Home Screen app has its own cookie jar, so it is its own device, which is what we want.
- **Paint cache.** The client mirrors the effective appearance to `localStorage["kipple.appearance"]`. An external
  `/theme-init.js` (CSP forbids inline scripts, §5) applies it before first paint. The server stays the source of truth.

```sql
-- 0004
CREATE TABLE devices (
  id TEXT PRIMARY KEY CHECK (length(id) BETWEEN 16 AND 32),
  name TEXT NOT NULL DEFAULT '' CHECK (length(name) <= 64),
  settings TEXT NOT NULL DEFAULT '{}' CHECK (json_valid(settings)),   -- overrides only
  user_agent TEXT NOT NULL DEFAULT '', client TEXT NOT NULL DEFAULT 'web',
  created_at INTEGER NOT NULL, last_seen_at INTEGER NOT NULL          -- bumped at most daily
) STRICT, WITHOUT ROWID;
```

- **Scope per key.** Every `settingDef` gains `scope: "device" | "account"`.
  - Device: `ui.theme`, `ui.theme_day`, `ui.theme_night`, `ui.font_body`, `ui.font_ui`, `ui.font_size`,
    `ui.reading_density`, `ui.list_density`, `ui.layout`, `ui.layouts`, `ui.mark_read_on_scroll`, `ui.swipe_*`, and
    `ui.a11y.*` (the six-control Accessibility section).
  - Account: everything else (retention, refresh, tz, images, filters, saved searches).
- **Resolution.** Effective value = device override ?? account default (today's `ui.*` settings rows, now "defaults for
  new devices") ?? built-in default.
- **Settings API changes.**
  - `GET /api/settings`: each device-scoped entry adds `scope:"device"`, `overridden: bool`, and `default` (the account
    default). `surface` (`reader_menu` \| `settings` \| `hidden`) is unchanged. The reader menu edits device values.
  - `PATCH /api/settings`: a device key writes the current device's override (`null` clears it). `?target=defaults`
    writes the account default. An account key ignores `target`.
  - Bootstrap: `settings` is the effective merge for this device, plus `device:{id, name}`.
- **Endpoints.**
  - `GET /api/devices` → `[{id, name, current, user_agent, client, last_seen_at, overrides}]`.
  - `PATCH /api/devices/{id}` `{name}`.
  - `POST /api/devices/current/copy-from` `{device_id | "defaults"}`: replaces this device's overrides.
  - `POST /api/devices/current/make-default`: copies its effective device values to the account defaults ("use on new
    devices"); `?all=1` also clears every other device's overrides ("use on all devices").
  - `DELETE /api/devices/{id}`.
- **Limits.** At most 50 devices (the least recently seen is evicted). Nightly purge of devices unseen for 400 days.
  Override blob ≤ 8 KB.
- **Tests.**
  - Resolution order; `null` clears; `target=defaults`.
  - Copy-from and make-default (with `all=1`).
  - A missing cookie issues one; an unknown id is treated as missing (new profile).
  - The eviction cap; the validation of device keys reuses `settingDef.check`.
- **Effort M. Risk:** low. The cookie is not a credential; a lost cookie means defaults plus "copy from device".

---

## 5. Security and privacy for the SPA and article content

### 5.1 Headers

Headers come from one middleware, `internal/httpx/headers.go` (`Secure(h, opts)`). It wraps the root handler in
`cmd/kipple/main.go`, around `greader.Front`, so every response gets it. It replaces `noFraming` in
`internal/web/handler.go:66` and `internal/api/api.go:203`. The `/img/` responses keep their own
`default-src 'none'`.

| Header | Value | Where |
|---|---|---|
| `Content-Security-Policy` | `default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:[ https: when imgproxy.mode=http_only]; font-src 'self'; connect-src 'self'; media-src 'self' https:; frame-src https://www.youtube-nocookie.com https://player.vimeo.com; manifest-src 'self'; worker-src 'self'; form-action 'self'; base-uri 'none'; frame-ancestors 'none'; object-src 'none'; upgrade-insecure-requests` | HTML (SPA and `/_status`). JSON responses get `default-src 'none'; frame-ancestors 'none'` |
| `Referrer-Policy` | `no-referrer` | all |
| `X-Content-Type-Options` | `nosniff` | all |
| `X-Frame-Options` | `DENY` | all (older browsers) |
| `Permissions-Policy` | `camera=(), microphone=(), geolocation=(), payment=(), usb=(), bluetooth=(), serial=(), hid=(), browsing-topics=(), interest-cohort=(), autoplay=(), fullscreen=(self "https://www.youtube-nocookie.com" "https://player.vimeo.com"), picture-in-picture=(self "https://www.youtube-nocookie.com")` | HTML |
| `Cross-Origin-Opener-Policy` | `same-origin` | HTML |
| `Cross-Origin-Resource-Policy` | `same-origin` | `/api/*`, `/img/*` |
| `Strict-Transport-Security` | `max-age=31536000` (no `includeSubDomains`, no `preload`) | only when the effective scheme is https (trusted proxy). Also enable HSTS at the Cloudflare edge (the owner's setting). LAN http access to Host-A:7080 is unaffected, because HSTS binds the hostname |

**Notes.**

- `style-src 'unsafe-inline'` stays: Radix and shadcn and `react-remove-scroll` inject `<style>` and style attributes.
  `script-src` is the control that matters.
- The mode-dependent `img-src` is computed from a cached setting (an atomic value refreshed on PATCH).
- `/_status` (`internal/web/status.html:66`) has an inline `<script>`. Move it to an embedded `/_status.js`; otherwise
  the CSP breaks it.
- The Vite dev server runs without the middleware (only `kipple serve` applies it). Production builds must not inline
  scripts: keep Vite defaults, and put the theme bootstrap in `/theme-init.js`.

### 5.2 Serve-time HTML transform

Replace `sanitize.RewriteImages` with one tokenizer pass, `sanitize.ServeHTML(html, opts)`. It covers the detail and
full-text responses. Stored HTML and Reader API output stay unchanged, as today.

| Element | Transform |
|---|---|
| `a[href^=http]` | `target="_blank" rel="noopener noreferrer"`. With `links.strip_tracking` (a new account setting, default **on**), remove `utm_*`, `fbclid`, `gclid`, `dclid`, `yclid`, `mc_cid`, `mc_eid`, `igshid`, `_hsenc`, `_hsmi`, `mkt_tok`, `oly_anon_id`, `oly_enc_id`, `vero_id`, `ref_src`. The card `url` gets the same stripping at serve time. Stored `items.url` and uids are never touched (frozen rules) |
| `[id]`, `[name]`, `a[href="#x"]` | Prefix to `kp-<id>` and `#kp-x`. This stops DOM clobbering and fixes footnotes. The client intercepts `a[href^="#kp-"]` clicks and scrolls inside the article container, not through the router |
| YouTube `iframe` | Becomes a click-to-load placeholder: `<figure class="kp-embed" data-provider="youtube" data-id="ID"><img src="<signed /img/ of i.ytimg.com/vi/ID/hqdefault.jpg>"><a href="https://www.youtube.com/watch?v=ID">Watch on YouTube</a></figure>`. On tap, the client inserts `https://www.youtube-nocookie.com/embed/ID?autoplay=1` with `sandbox="allow-scripts allow-same-origin allow-presentation allow-popups"`, `allow="autoplay; fullscreen; picture-in-picture"`, and **`referrerpolicy="strict-origin-when-cross-origin"`**. YouTube refuses embeds without a Referer (player error 153), and this sends only the origin, only on the tap |
| `video`, `audio` | `preload="none"`, `autoplay` removed. An `http://` source becomes a link (mixed content). `poster` is proxied |
| Enclosures | The UI renders a native `<audio controls preload="none">` plus an "Open in podcast app" link. Media loads directly from the host (`media-src https:`) only on play |

**Ingest pre-pass (new items only).** A non-YouTube `iframe` becomes `<p><a href="src">Embedded content from
host</a></p>` before bluemonday runs. Today it is dropped silently. Vimeo `player.vimeo.com/video/ID` is kept like
YouTube and served click-to-load with `?dnt=1`. This improves client A and NNW output too.

**Tests.**

- Golden HTML for each row.
- Stripping keeps other parameters and their order.
- No `id` survives unprefixed.
- A CSP header test per route class.
- `/_status` works under the CSP (a browser check on the release list).
- `ServeHTML` is idempotent on already-transformed HTML.

**Effort M. Risk:** a CSP mistake blanks the UI. Add a release-checklist item: load the SPA, open an article with an
image, an embed and a footnote, and check that the console shows no CSP violations.

---

## 6. Backup export, restore, password recovery

| Item | Spec |
|---|---|
| **Create** | `POST /api/backup` (same-origin + `X-Kipple-Client`). Single flight, mutually exclusive with the nightly snapshot (a shared mutex in `store`). It checks free space ≥ 2.2 × the DB size, then `VACUUM INTO /data/backup/export-<ts>.db` on the snapshot pool. That holds only a read snapshot, so no writer or gate is blocked. Then it builds `/data/backup/kipple-backup-<YYYYMMDD-HHMM>.zip` (Deflate) and deletes the `.db` |
| **Contents** | `kipple.db` (consistent snapshot); `feeds.opml`; `settings.json` (account settings, device profiles, filters, readable copies; the DB is authoritative); `manifest.json` `{kipple_version, schema_version, created_at, db_sha256, db_bytes, feeds, items, starred}`; `RESTORE.txt`. Excluded: imgcache, pre-migration copies, the nightly snapshot |
| **Why zip** | The iOS Files app and Windows Explorer open it natively. The stdlib `archive/zip` streams it |
| **Response** | `{token, filename, bytes, expires_at}`. `token` is 128-bit random, valid 15 min, reusable within that window (iOS may re-request) |
| **Download** | `GET /api/backup/{token}` with a session plus `Sec-Fetch-Site` ∈ {`same-origin`, `none`}, or a matching `Origin`. No `X-Kipple-Client` is needed, so a plain link and `<a download>` work in iOS standalone. `http.ServeContent` gives `Content-Length`, Range and resume, plus `Content-Disposition: attachment`. The file is deleted when the token expires; at most 2 kept |
| **Size** | Roughly 30-40 % of the DB: stubs dominate at about 270 MB after 90 days, so the zip is about 100 MB. The UI shows the size |
| **Sensitivity** | The file holds password hashes, `account.secret` and feeds' `http_auth`. The UI says "Contains your password hashes and feed logins: keep it private". No redaction option: a restore needs the secret |
| **Same fix for other downloads (audit U11)** | `GET /api/opml` and `GET /api/stats/export.csv` accept the same `Sec-Fetch-Site`/`Origin` rule without `X-Kipple-Client`. A cross-origin page cannot read a response anyway, and these GETs have no side effects |

**`kipple restore <file.zip|file.db> [--yes]`** (a new CLI subcommand):

1. **Refuse while the server runs.** `serve` holds an exclusive `flock` on `/data/kipple.lock` (build-tagged; on
   Windows dev, a PID file).
2. **Validate a temp copy** (`/data/restore-tmp.db`): the zip's `db_sha256`, `PRAGMA integrity_check`, `application_id`,
   and `user_version` ≤ this binary's latest. The FTS `integrity-check` runs too.
3. **Move the current `kipple.db`, `-wal` and `-shm`** to `/data/backup/pre-restore-<ts>/`.
4. **Rename the temp copy** to `kipple.db`.
5. **Next start.** `serve` migrates if the restored copy is older.

**Host-A runbook.**

```sh
docker compose -f /home/user/stack/docker-compose.yml stop kipple
docker cp kipple-backup-X.zip kipple:/data/
docker compose -f /home/user/stack/docker-compose.yml run --rm kipple restore /data/kipple-backup-X.zip --yes
docker compose -f /home/user/stack/docker-compose.yml start kipple
```

`docker cp` works on a stopped container and on distroless.

**`kipple password [--generate]`** mirrors `api-password`:

- It reads the new password from stdin (or generates 24 characters and prints them once) and writes the argon2id hash
  through `NoMigrate`.
- It **deletes all sessions**. The in-memory lockout clears on the next restart, or run it when the IP window has
  passed.
- It works while `serve` runs (busy_timeout). Afterwards, remove `KIPPLE_PASSWORD`/`KIPPLE_API_PASSWORD` from the Host-A
  `.env` (audit D4).

**Off-box copy for testing (now, before 0004 ships).**

- **Simplest safe path:** the Export button from a browser on Host-B, saved to `P:\HostBBackups\kipple\`.
- **Before the export exists:** `ssh host-a "docker cp kipple:/data/backup/kipple-snapshot.db /tmp/k.db" && scp
  host-a:/tmp/k.db P:\HostBBackups\kipple\ && ssh host-a rm /tmp/k.db`. It copies the snapshot only, never the live
  db/wal.
- **Nightly:** later, the same `docker cp` in `proton-backup.ps1` (audit D1). the owner's call when; it is ops on Host-B.

**Tests.**

- The export is consistent under concurrent writes (a writer loop during `VACUUM INTO`, then `integrity_check`).
- Token expiry and reuse; the download origin rules.
- The free-space refusal.
- Zip contents and the manifest hash.
- `restore` refuses under a held lock, a bad hash or a newer schema; the round trip export → restore → serve is
  equivalent.
- `password` revokes sessions.

**Effort M** (export) + **M** (restore and password). **Risk:** restore replaces the DB, so the lock, validation and
kept pre-restore copy make it reversible.

---

## 7. Search: FTS5 stemming

- **Migration 0005 `0005_fts_porter.sql`:**

  ```sql
  DROP TABLE items_fts;
  CREATE VIRTUAL TABLE items_fts USING fts5(title, author, content_text,
    content='item_search', content_rowid='id', tokenize='porter unicode61 remove_diacritics 2');
  INSERT INTO items_fts(items_fts, rank) VALUES('rank', 'bm25(4.0, 2.0, 1.0)');   -- persistent: title 4x, author 2x
  INSERT INTO items_fts(items_fts) VALUES('rebuild');
  ```

  The five triggers reference `items_fts` by name and resolve at run time, so they survive the drop and recreate inside
  the migration transaction and need no rewrite. The persistent `rank` config means the existing `items_fts.rank` and
  the rank cursors keep working unchanged.

- **Cost on the live DB.** `rebuild` re-tokenizes every `content_text`: about 35k items × about 6 KB is roughly 200 MB
  of text, estimated 20-60 s on Host-A at startup. The migration holds `BEGIN IMMEDIATE`, so there is no serving
  meanwhile and Cloudflare returns 502. The WAL grows by about the index size (tens of MB) and is truncated at the next
  checkpoint (`journal_size_limit` 64 MB). The pre-migration snapshot is taken first. **Test it first on a copy of the
  real snapshot** (§6 off-box copy) and record the time in the RUNBOOK. Index size stays about the same.

- **Query builder** (`BuildFTSQuery` v2; still no raw FTS syntax passes through):

  | Input | Output |
  |---|---|
  | `word` | `"word"` (stemmed by porter on both sides) |
  | the last token, ≥ 3 runes, no trailing space (search-as-you-type) | `"tok"*` |
  | `"exact phrase"` (user quotes) | `"exact phrase"` |
  | `title:foo`, `author:"jane doe"` | `title : "foo"`, `author : "jane doe"` (only these two columns; other `x:` stays literal) |
  | `-word` | `NOT "word"`, only when at least one positive term exists; otherwise dropped |
  | zero results | Retry once with every bare token as a prefix `"tok"*`. The response sets `fallback:"prefix"` so the UI can say "showing partial matches" |

  The limits stay (16 tokens, 64 runes each, 512 bytes). Porter plus prefix works on stems (`comput*` matches computer
  and computing); a few odd stems are accepted.

- **Snippets and rank.** `snippet()` reads the original text, so highlighted words are the source words. Rank changes
  (the title weight), so rank cursors issued before the deploy may reorder: acceptable (a new search).

- **Still out of scope.** Extracted full text and stubs are not indexed (§2.4 known limit).

- **Tests.**
  - `running` matches `ran`/`runs`; diacritics fold.
  - Phrase and column filters; NOT only with a positive term; the prefix fallback flag.
  - Fuzzing `BuildFTSQuery` never yields an FTS syntax error on a live index.
  - The migration test on a populated DB (rows equal, `integrity-check` clean, the triggers still sync on
    insert/update/delete/trim/restore).
  - Timing logged.

- **Effort M. Risk:** startup downtime during the rebuild, covered by a planned deploy window and the snapshot.

---

## 8. Offline and PWA data spec (the backend needs for phase 3)

the owner's scope: read and interact with what is already downloaded, show an "offline" message at launch, queue actions and
sync when back online.

| Topic | Spec |
|---|---|
| **Service worker may cache** | Precache: the app shell (`index.html`, hashed `/assets/*`, fonts). Navigation falls back to the cached shell. Runtime: `/api/bootstrap` (network-first with a 5 s timeout, then cache); the last 20 list pages (network-first); `/api/items/{id}` detail JSON (cache on view); `/img/*` (cache-first: the URLs are signed and immutable). **Never** cached: `/api/events`, `/api/auth/*`, every non-GET |
| **Quotas and eviction** | One cache `kipple-offline-v<api>` plus an IndexedDB LRU index. Default budget 200 MB, shown with `navigator.storage.estimate()`. Call `navigator.storage.persist()` at install (Safari 17+ supports it; granted heuristically). LRU evicts details and images beyond the budget; the shell is never evicted |
| **"Downloaded for offline"** | An explicit action per feed, folder or view: "Download newest 50 unread". Backend: `GET /api/items?…&include=content` returns cards plus serve-transformed `content_html` (and full text when effective). Limit 50 per page, 2 MB per item (longer is cut, with a "continue on site" link). The client then fetches the images, which is where the imgcache pays off |
| **Queued writes** | IndexedDB outbox `{op_id (uuid), kind: read\|unread\|star\|unstar, ids, at (client unix s), attempts}`. Replayed on `online`, on app focus, and after the SSE reconnects. No Background Sync on iOS. Ops older than 14 days are dropped with a toast. Filters, settings and feed edits are **not** queued; they are disabled offline |
| **Idempotency and conflicts** | Endpoints set state rather than toggle it, so a replay is naturally idempotent (the `WHERE read = 0` guards). Conflict rules:<br>• `read`, `unread`: last delivered wins.<br>• `star`: always applies.<br>• `unstar`: applies only if `starred_at ≤ at` (new optional `at` on `PUT /api/items/{id}/star`), so a stale offline unstar never removes a star made later on client A.<br>No idempotency-key table is needed, because only these four ops queue |
| **Delta sync** | The SSE hub seeds `seq` from boot microseconds (`events/hub.go:59`), so a `Last-Event-ID` from before a restart or outside the 500-event ring gets `resync`. No persistent changes feed is added. On `resync`, the client refetches bootstrap, the visible lists, and `GET /api/items?ids=` (≤ 100 per call) for its cached items to refresh their flags |
| **Offline at launch** | If `navigator.onLine` is false or bootstrap fails with a network error or timeout: render from the cached bootstrap with the banner "Offline: showing downloaded articles. Changes will sync when you're back." A 401 when online shows the login and keeps the outbox |
| **API version handshake** | Bootstrap returns `api_version` (an integer, bumped only on a breaking change), `min_client_api` and `version`. The client sends `X-Kipple-API: <n>`. When n < `min_client_api`, the server answers `409 {"error":"client_outdated"}`, and the client drops its caches (keeping the outbox), reloads and replays. The four outbox shapes plus `GET /api/items?ids=` are **frozen**: they never break without a version bump |
| **SW update** | `/sw.js` is served `no-cache` from the root with `Service-Worker-Allowed` not needed. A new SW waits, the toast says "Update available: reload", and `skipWaiting` runs on tap |
| **Root static files** | `/sw.js`, `/manifest.webmanifest`, `/favicon.ico`, `/apple-touch-icon.png` and `/theme-init.js` are served from `web/dist` before the SPA fallback (`web/handler.go:56` currently returns `index.html` for them) |
| **iOS limits** | No Background Sync or Periodic Sync, so replays happen on open and focus. The SW can be killed at any time. The Home Screen app has storage separate from Safari tabs and is exempt from the 7-day ITP wipe; a Safari tab is not (so "download for offline" is labelled best-effort in a tab). Storage is roughly 1 GB-plus per origin before eviction pressure (WebKit 17+ allows more; treat 200 MB as a safe default) |

**Tests (backend).**

- `include=content` limits and truncation.
- `star` with `at` skips a stale unstar.
- 409 on an old `X-Kipple-API`.
- Root static routes are served with the correct types and cache headers.
- `resync` after a hub restart (the existing hub test, extended).

**Effort M** (phase 3). **Risk:** a stale offline `read` overwrites a later client A mark-unread. This is rare and
accepted: read state has no per-change timestamp, and adding one would mean a write on every state change.

---

## 9. Reconciling the audit's contradictions

Resolutions for a later `design.md` update step. "Code" means a change in the implementation plan (§11).

| # | Topic | Resolution | Code? |
|---|---|---|---|
| C4 | Health status vocabulary | One Go function, `store.FeedStatus(row, hostUntil, now)`, used by bootstrap and health. Values in precedence order: `archive`, `dead` (was `gone`), `disabled` (was `user`, and also `enabled=0` without a reason), `failing` (≥ 14 consecutive failures), `erroring` (1-13), `throttled` (host deadline in the future), `redirecting` (**permanent redirect pending only**; a temporary redirect is a notice with status `ok`, which removes the noise from 10 feeds), `silent` (healthy, no new items for 90 d), `ok`. The UI is not built yet, so renaming is free | Yes |
| C5 | `/api/health/feeds` fields | Add `snapshot:{last_at,last_error}`, `clock:{ahead_s}`, and per feed `host_throttled_until`. Rename `migrated` to `redirect_pending`. Add `db:{db_bytes, wal_bytes, backup_bytes, imgcache_bytes}` (audit D7) | Yes |
| C6 | Time zone source | One source: the **`tz` setting**, for the nightly job and stats. `maint.go:124,197` loads it per run (a change takes effect at the next due-check). The env `TZ` only sets `time.Local` for log timestamps. The help text becomes "Used for daily statistics and the nightly maintenance job". The UI shows times in the **device** zone (`Intl.DateTimeFormat`) | Yes |
| C7 | Retention help text | "Only the newest N articles per feed are kept, read or unread. Starred articles are always kept." Add: "Muted articles are removed first" | Yes |
| C1 | §13 | Rewrite as a status table. 1: built. 2 (startup FTS/json self-check): **build**, S. 3: built as `last_new_items_at`. 4: **drop** `image_count` and 265 wpm; keep 230. 5: **superseded by §7** (porter + `bm25(4,2,1)`). 6: superseded by `ua_fallback` (0002). 7 (Retry-After HTTP-date relative to `Date`): **build**, S. 8: **drop** for redirects; keep for manual URL edits (already `feedadmin.go:202`). 9 (skip a malformed item): **build**, S. 10 (dedupe enclosures by URL): **build**, S. 11 (normalized-link uids): **drop** (it would re-key live items). 12 (slow-stage WARN): **drop** (log noise, no monitoring) | Partly |
| C2 | §11 inline full-text row | Replace it with: "The in-memory full-text queue (500) is lost on restart (the items fall back to on-demand extraction)" and "The Reader full-text hold can delay an item by ≤ 30 s" | Docs |
| C3 | §2.2 DDL | §2.2 becomes exactly `0001_init.sql`. Add §2.2a with a delta list for 0002-0005 | Docs |
| C8 | §4.3 AssignUIDs wording | "Keys every occurrence and never drops" | Docs |
| C9 | Research docs vs design | Add the banner "Superseded by design.md where they differ" and fix open-questions #16, #20, #26, #27, #32, #33 | Docs |
| C10 | `GET /api/stats/export.csv` | Tag it phase 4 | Docs |
| C11 | Memory notes | Mark ingest extraction as shipped (1982896, 7af643c, 13fb02c) | Memory |
| C12 | RTL `direction` | Defer. The UI sets `dir="auto"` on the article container. Add a §11 row for the hard-coded Reader `ltr` | Docs |
| §7.4 | "No disk cache in phase 2" | Replaced by §2 of this file. The default `imgproxy.mode` becomes `all` | Yes |
| §2.6 | "Host-A's host backup copies the snapshot" | Replace it with: the export (§6) plus a Host-B pull (`docker cp`) | Docs |
| §5 | Retention ranking | Add "muted items first", `ORDER BY (muted_by IS NULL) DESC, sort_at DESC, id DESC` | Yes |
| §7.1 | mark-read | Add `bound`, `scope.q` and `view=muted` (§3); `order=oldest`; `min/max_minutes`; `include=content` (phase 3) | Yes |
| U11 | Downloads need `X-Kipple-Client` | The `Sec-Fetch-Site`/`Origin` rule alone for GET downloads (§6) | Yes |
| U12 | Archive cards | Add `origin_title` to Card and Detail (`COALESCE(origin_title, feed title)` as `source`) | Yes |
| Themes | Code values `white/off-white/sepia/soft-green/brown/dark/oled/system` vs the owner's named schemes | Theme ids come from the UI spec (Paper, Linen, Parchment, <Fern rename>, Cocoa, Graphite, Midnight, Signal, Newsprint, …). **No SQL migration**: `settingDef.check` accepts the old ids as aliases and maps them on read (white→paper, off-white→linen, sepia→parchment, soft-green→<fern rename>, brown→cocoa, dark→graphite, oled→midnight). Add `ui.theme_day` and `ui.theme_night` (defaults paper/midnight). `system` stays the value, labelled "Match my device". CLAUDE.md's theme and font lists are updated, and Atkinson Hyperlegible Next is added | Yes |
| Density | Three presets vs "more" | `ui.reading_density` and a new `ui.list_density` take the round-2 preset list. The existing three values stay valid | Yes |
| Read later | Unspecified | "Starred = read later" (Reader clients only know starred); stated in §7 | Docs |
| Non-goals | Highlights and notes | Add "no highlights or annotations" to CLAUDE.md non-goals. Keyword *highlights* (§1) are a display rule, not annotations | Docs |

---

## 10. Migration summary

| File | Contents | Live-data impact |
|---|---|---|
| `0004_filters_devices.sql` | `filters`; `items.muted_by` + `idx_items_muted`; `item_content`/`trimmed_content.categories_json`; `feeds.auto_read_days`; `devices` | Additive, O(1) column adds, empty indexes. Seconds |
| `0005_fts_porter.sql` | Drop and recreate `items_fts` with porter, persistent `bm25` rank, `rebuild` | 20-60 s rebuild at startup (measure on a snapshot copy first) |
| (none) | `/data/imgcache/index.db` | New, separate, disposable |

- Both files ship in one deploy if possible, which means one `pre-migration-3-5-*` snapshot.
- The downgrade guard then blocks the older image.
- Rollback: stop, restore the snapshot, delete `-wal`/`-shm`, start the old tag. the owner accepted this; write it in the
  RUNBOOK.
- The trim SQL (`retention.go`) and restore SQL (`itemstate.go`) must copy `categories_json` once 0004 lands. The
  existing stub round-trip test covers it.

---

## 11. Implementation plan (dependency-ordered, Sonnet-sized)

"Live risk" is the risk to the owner's data on Host-A at deploy.

| # | Step | Scope | Tests | Live risk |
|---|---|---|---|---|
| 1 | **Audit fixes, no schema** | `store.FeedStatus` (C4); health fields and `redirect_pending` (C5); `tz` for maintenance (C6); help texts (C7); `origin_title` (U12); the download origin rule (U11); §13 items 2, 7, 9, 10 | Status table test; maint schedule under a changed `tz`; download 403/200 matrix; the self-check fails on a fake driver | None |
| 2 | **Security headers** | `internal/httpx/headers.go`, wired in `main`; remove both `noFraming` copies; `/_status.js` split out; CSP computed from `imgproxy.mode` | Header test per route class; `/_status` loads | None (UI breakage only; checklist item) |
| 3 | **Serve-time HTML transform + ingest iframe pre-pass** | `sanitize.ServeHTML` (links, tracking, ids and footnotes, embeds click-to-load, media); `links.strip_tracking` setting; non-YouTube iframes become links at ingest | Golden HTML, idempotence, Reader output unchanged for old items | New items only (the iframe pre-pass) |
| 4 | **Ordering and mark above/below** | `order=oldest` + tagged cursor; `bound`, `scope.q`; `min_minutes`/`max_minutes` (F6) | Property pagination, the 8-way bound table, `max_id` guard, plans | Low: bulk-mark bugs are covered by tests and undo |
| 5 | **Backup export + download token** | `POST /api/backup`, `GET /api/backup/{token}`, zip, shared snapshot mutex | Concurrency consistency, free-space refusal, token rules | Read-only on the DB; disk space |
| 6 | **CLI: `password`, `restore`, serve lock** | `cmd/kipple`; `/data/kipple.lock` | Lock refusal, restore round trip, sessions revoked | Restore replaces the DB (guarded, with a pre-restore copy) |
| 7 | **Ship 1-6** | `/code-review high`, deploy, then **take an off-box export** | Release checklist plus the CSP console check | - |
| 8 | **Migration 0004 (schema only)** | The SQL of §1.8, §1.13 and §4, plus store copies of `categories_json` in trim and restore | The migration test on a fresh DB and on a **copy of the real Host-A export**; `foreign_key_check`; plan suite | **Live migration**: pre-migration snapshot; rehearse on the copy |
| 9 | **`internal/filter` engine (pure)** | Compile, validate, evaluate; RE2 limits; word-set matcher | Table tests, fuzzing, benchmark ceilings | None |
| 10 | **Filters at ingest + mute semantics** | Hook in `applyItems`; `SetRead`/`SetStarred` clear `muted_by`; trim order; full-text skip; fetch_log note; `fetch.done` fields; categories parse | Reader `unread-count`/`xt=read` agree, invariant scan, trim order | Changes ingest: rules start empty, so there is no effect until the owner adds one |
| 11 | **Filters API** | CRUD, preview, apply, delete with `unmute`, `view=muted`, bootstrap `highlights` and `counts.muted` | API tests, batching and SSE, preview budget | A retroactive apply is explicit and previewed |
| 12 | **Device profiles** | Cookie, `devices` store, `settingDef.scope`, settings merge, the five endpoints, theme aliases, `theme_day`/`theme_night` | Resolution order, copy and default, eviction | Low: the old `ui.*` rows become the defaults |
| 13 | **Image cache: storage** | `internal/imgcache` (index.db, files, LRU, idle expiry, neg cache, disk guard, startup repair) | Everything in §2.5 except the proxy and thumbnail items | None (a new directory) |
| 14 | **Image cache: proxy integration + API** | Tee on write, single flight, revalidation, hotlink retries, `hosts`, cap-change hook, `/api/imgcache` + clear, mode default `all` | Single flight, 304/stale, hotlink sequence, stats | Bandwidth and disk on Host-A (capped) |
| 15 | **Thumbnails** | `FlagThumb`, `x/image` (webp, draw), one transcoder, card rewrite | Sizes, fallbacks, memory ceiling | Memory (pixel cap) |
| 16 | **Migration 0005 + query builder v2** | Porter, `bm25`, rebuild; phrases, columns, NOT, as-you-type prefix, zero-result fallback | Stemming, fuzzing, migration on a populated DB, timing | **Startup rebuild downtime**: planned window, snapshot, rehearse on a copy |
| 17 | **Auto-read after N days (F5) + saved searches (F4)** | Maintenance job with window semantics, preview and catch-up; `library.saved_searches` setting | Window and DST, manual unread sticks, catch-up = preview | Marks read in bulk: off by default, confirm dialog |
| 18 | **Ship 8-17** | `/code-review high`; deploy 0004 and 0005 together after rehearsal | Release checklist plus the client A/NNW sanity pass on muted and search | Covered above |
| 19 | **Phase 3 backend** | Root static files, `include=content`, `X-Kipple-API` handshake + 409, star `at`, `sw.js` headers | §8 tests | None |

Steps 9, 13 and 15 can run in parallel with anything; they are pure packages or a new directory. Steps 10-11 need 8
and 9. Step 14 needs 13, step 15 needs 14, and step 16 needs 4 (the `scope.q` builder). Keep one writer on Host-A at a
time for 7 and 18.

---

## 12. Decisions still needed from the owner

1. **Which family features go into phase 2.** The recommendation is F1-F7 now (mute, mark read, auto-star, only-show-
   matching, highlights, saved searches, auto-read after N days, reading-time filter, per-feed view and order), with
   F8-F11 later and F12 rejected. Auto-read (F5) is the one real addition to the product rather than a UI nicety.
2. **Image cache size and scope.** Is a **1 GiB** default cap right for Host-A's free disk (what is free on its root
   volume)? And is "all images through Kipple" OK as the default, meaning inline images too, not just lead images?
   That default is what allows the strict CSP.
3. **Fern's new name.** It is needed for the theme alias map (from the round-2 color work).

Everything else above is decided, following the "be decisive" instruction and the owner's round-1 answers. the owner can
overrule any row: for example muted items trimmed first, zip over tar.gz, YouTube receiving the origin on tap, or
tracking-parameter stripping on by default.
