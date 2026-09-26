# lemon24/reader as prior art (2026-09-24)

Source state: `lemon24/reader` `master`, tree sha `b9dec1b9495ce09710102d4e47deb4aec23a81f0`, fetched
2026-09-24. Two raw reports (`lemon24-reader-storage.md`, `lemon24-reader-update.md`) were checked
against the source for this comparison. **VERIFIED** means read in the file or doc cited. **INFERRED**
means my reading, SQLite documentation knowledge, or a consequence for Kipple that reader does not
state. Two claims in the raw reports were corrected after re-reading the source. They are flagged
inline with **CORRECTION**.

---

## 1. What reader is and is not

- **A Python library, not a server.** From `docs/why.rst`: "*reader* is a library", "*reader* has
  minimal dependencies". It uses `feedparser` for parsing and `requests` for HTTP, and keeps
  everything in one SQLite file (plus an optional `.search` sidecar, §5). The repo also ships an
  internal Flask web app and a CLI under `src/reader/_app/` (underscore-private, includes a
  `legacy/` UI). These are the author's personal tools, not a product surface. VERIFIED (tree listing).
- **Single-process, thread-per-connection.** `LocalConnectionFactory` in
  `_storage/_sqlite_utils.py` opens one connection per thread through `threading.local`. Updates
  default to `workers=1`, which means fully sequential. Only network retrieval ever runs in parallel.
  VERIFIED.
- **It has no sync API.** No Google Reader API and no Fever API. A tree grep for `greader`/`fever`
  and a doc grep for "Google Reader"/"Fever" found nothing. VERIFIED. It never had to keep item
  ids stable for remote clients, to encode int64 ids, to answer `ot`/`nt`/continuation queries, or
  to keep a trimmed id acceptable to `edit-tag`.
- **So reader informs Kipple's internals only.** That covers storage, the update decision rules,
  HTTP cache hints, dedup, search and readtime. Wire compatibility with Reeder Classic and
  NetNewsWire is a separate requirement, and reader has no prior art for it. That contract lives in
  `docs/research/greader-*.md`, `reeder-classic.md`, `netnewswire.md` and `item-id-and-quirks.md`.
  Where a reader design choice conflicts with the sync contract (raw GUID primary keys, post-hoc
  deletion of duplicates), the sync contract wins. See §4 and §9.
- **Maturity signal.** The schema is at `VERSION = 44`. The changelog runs through the 3.2x series.
  Almost every heuristic cites the upstream issue whose real-world breakage motivated it, which is
  why it is useful to mine.

---

## 2. Storage and schema decisions worth adopting

Source: `src/reader/_storage/_schema.py`, `_sqlite_utils.py`, `_base.py`, `_changes.py`,
`CHANGES.rst`. VERIFIED unless marked.

### 2.1 PRAGMA and connection discipline

| reader does | reasoning (quoted/cited) | Kipple |
|---|---|---|
| `PRAGMA foreign_keys = ON` on **every** connection | the setting is not persisted across connections | ADOPT. With modernc, put it in the DSN (`_pragma=foreign_keys(1)`) so every pooled connection gets it (INFERRED re: modernc DSN form, check against `go-libraries.md`). |
| `journal_mode = WAL` once, at DB creation | CHANGES.rst: *"Use SQLite's write-ahead logging to increase concurrency. At the moment there is no way to disable WAL."* (#169) | Already planned. |
| `PRAGMA application_id` (`read` / `reaD` for the search DB), `IdError` on mismatch | refuses to open a file that isn't reader's | ADOPT. Stamp a Kipple id and refuse foreign files. It costs 5 lines. |
| `PRAGMA user_version` stepped through every intermediate version | standard | Already planned. |
| Migrations run with `foreign_keys` off, **outside** a transaction, then `PRAGMA foreign_key_check`, then `VACUUM` | SQLite needs FKs off for table-rebuild ALTERs. VACUUM can't run in a transaction. | ADOPT `foreign_key_check` after each migration. CONSIDER VACUUM after a migration (the DB is small). |
| `PRAGMA optimize` at close, and periodically inline on a schedule of 2, 4, 8, 16, 64, 256, 1024, then every 2048 calls, with a transient `busy_timeout` of 0.1 s and "database is locked" swallowed | cites a fossil-scm forum post. Opportunistic, never blocks. | ADOPT the idea. In Go, run `PRAGMA optimize` after each fetch cycle, or hourly, on the writer. Current SQLite docs recommend `optimize=0x10002` once on open for long-lived connections (INFERRED from SQLite docs, not reader). |
| `MINIMUM_SQLITE_VERSION = (3, 18)`. `REQUIRED_SQLITE_FUNCTIONS = ['json']`, probed with tiny queries, and all missing ones named at once | fail fast with a useful error | ADOPT as a startup self-check plus a unit test. Probe `json_valid('1')` and `CREATE VIRTUAL TABLE temp.x USING fts5(a)`. modernc pins SQLite, but a libc/driver swap to the ncruces fallback could silently drop FTS5. |
| **No `synchronous` pragma** | nothing stated | **CORRECTION to the raw report**, which said reader "relies on WAL's default (NORMAL)". SQLite's default is `synchronous=FULL` unless compiled with `SQLITE_DEFAULT_WAL_SYNCHRONOUS` (INFERRED from SQLite docs). Kipple should set `synchronous=NORMAL` explicitly under WAL. That is safe against app crashes, and a power loss may drop only the last commits, which the next poll refetches. |
| `busy_timeout` only transient | reader has one connection per thread and in-process locking | Not transferable. Kipple has separate writer and reader pools, so it needs a real `busy_timeout` (e.g. 5000 ms) on every connection, plus `_txlock=immediate` on the writer as already planned. |

### 2.2 Schema patterns

- **`caching_info` as one JSON column.** Migration 40→41 collapsed `http_etag` and
  `http_last_modified` into one JSON `caching_info`. Kipple already plans this. Keep it.
- **Separate "last asked" from "last changed".** `feeds.last_retrieved` is written on every attempt.
  `feeds.last_updated` is written only when content actually changed. `update_after` holds the
  schedule. `last_exception` is set only on parse or retrieve error and cleared by the next clean
  run (`_update/__init__.py`). ADOPT the two-timestamp split on `feeds` (`last_checked_at`,
  `last_new_item_at`) for the health view. "Checked 5 min ago, nothing new for 94 days" is the most
  useful dead-feed signal the owner will get.
- **`recent_sort`, a precomputed sort key** (#279) indexed as
  `recent_sort DESC, coalesce(published, updated, first_updated) DESC, feed DESC, last_updated DESC,
  - feed_order DESC, id DESC`. The comments say "id at the end makes the order deterministic" and
  "values must be non-null (#203)". On a feed's **first** update, new entries get
  `recent_sort = published or updated or now`, so an imported backlog sorts by real dates. On every
  later update they get `recent_sort = global_now`, the batch time, so one poll's arrivals sort as a
  group and a backdated post can't hide below the fold. VERIFIED (`_update/__init__.py`, Report B §1).
  This maps directly onto Kipple. Crawl-time ids serve Reeder's `timestampUsec`, and a UI "newest
  first" order needs the same two-mode rule. See delta 9 in §9.
- **Tri-state `important` (NULL/0/1) and per-flag `*_modified`.** This exists so rules (the
  `mark_as_read` plugin passes `modified=None`) are distinguishable from human actions. REJECT for
  Kipple. Reader API starred is binary, `ot` needs one `state_changed_at`, and stats provenance
  already lives in the event table.
- **Composite PK `(id, feed)` with `id` = the raw GUID string.** REJECT. Kipple needs int64 ids for
  the Reader API. The per-feed `uid` with a unique index `(feed_id, uid)` is the equivalent.
- **`ON DELETE CASCADE` from `entries` to `entry_tags`**, and from `feeds` to everything. For Kipple,
  retention deletes items, and CLAUDE.md says "stats events are never trimmed". So `stats_events`
  must **not** cascade from `items`. Store `feed_id` plus a title/url snapshot on the event, with no
  FK to `items.id` or an FK with `ON DELETE SET NULL`. INFERRED consequence, not a reader statement.
- **Content hashing** (`_hash_utils.py`): a version-prefixed MD5 over canonical JSON of the
  dataclass fields, with **empty fields dropped** so that adding a new optional field doesn't change
  existing hashes. `updated` is excluded from both feed and entry hashes (#231: RSS
  `lastBuildDate`, synthesized by feedparser, churns without real change). ADOPT the approach for a
  per-item `content_hash` (sha256 is fine), and see §3.
- **Per-row reads before writes, not `IN (...)`.** The comment is "the maximum number of SQL
  variables can be as low as 999". Not relevant. modernc's SQLite 3.53 allows 32766 (INFERRED from
  SQLite docs).

---

## 3. Update pipeline, scheduling and HTTP decisions worth adopting

Source: `src/reader/_update/__init__.py`, `base.py`, `hooks.py`, `_parser/*`, `core.py`,
`CHANGES.rst`. VERIFIED unless marked.

### 3.1 Pipeline shape

The pipeline docstring gives the shape as `get_feeds_for_update | process_feed_for_update | decider |
retrieve (parallel) | parse | get_entries_for_update | process_entry_pairs | make_intents |
update_feed`. The **`Decider` is pure**: no I/O, it takes (old, new) and returns intents. ADOPT this
split for Kipple's `internal/fetch`. A pure `decide(feedRow, httpResult, parsedItems, existingRows,
now) → intents` function makes the planned fake-clock and status-table tests plain table tests.

### 3.2 Item new/updated decision (`Decider.should_update_entry`)

1. Feed marked `stale` ⇒ update.
2. No existing row ⇒ new.
3. `new.updated != old.updated` ⇒ update. The comment says "Unlike feed.updated, we always trust
   entry.updated (so far)".
4. Otherwise, if the content hash changed ⇒ update, but only up to **`HASH_CHANGED_LIMIT = 24`**
   consecutive hash-only updates (#225, "entries whose content changes excessively, e.g. includes
   the current time"). The counter resets on an `updated`-driven update.
5. Otherwise skip.

At feed level, the feed's own `updated` is **distrusted**. A change only in `feed.updated` never
triggers a feed write.

ADOPT rules 3–5 for Kipple's existing-uid path. The Kipple plan currently says nothing about updating
an already-stored item. Recommended rule: update title/content/etc. in place, **never** change
`read`/`starred`/`id`/crawl time, and cap hash-only churn at 24.

### 3.3 Body short-circuit versus parsed-hash comparison

Reader has no raw-body hash. It always parses, then compares per-object hashes, and only skips the
DB write. Kipple plans a body SHA-256 short-circuit. Keep it. It is cheap and saves the parse for
servers that ignore validators. But it only catches byte-identical bodies, and many RSS generators
rewrite `lastBuildDate` or a timestamp comment on every request (#231). The per-item
`content_hash`, with dates excluded, is what actually prevents rewriting 250 unchanged rows. Do both.

### 3.4 Scheduling

- `next_update_after(now, interval, jitter)` snaps to a **fixed grid** anchored at Monday 1970-01-05,
  with jitter only forward inside the next bucket. The default is `interval=60, jitter=0`. REJECT
  grid snapping. It deliberately bunches every feed with the same interval onto the same wall-clock
  boundary. Kipple's plan (per-feed `next_fetch_at`, initial spread across the first interval,
  60 s tick, semaphore 8) is gentler on the box and on shared hosts.
- **Reader has no backoff and no failure counter.** `update_after` is recomputed from scratch after
  success or failure. One clean update clears `last_exception`. Kipple keeps exponential backoff
  (Miniflux/FreshRSS prior art in `fetch-prior-art.md`). Reader's "one success clears the error
  flag" matches Kipple's "reset on any 2xx/304".
- **HTTP cache hints push the schedule out, never in.** VERIFIED code from Report B:
  - Retry-After is honored **only on 429/503**. Both delta-seconds and HTTP-date forms are accepted.
    Since 3.21 the date form is interpreted relative to the response `Date` header, which tolerates
    clock skew (#307, #376).
  - `Cache-Control: max-age` (unless `no-cache`) or, only if there is no Cache-Control, `Expires`,
    on any status. `max()` of all candidates is used.
  - It is used only if later than the interval-derived time, re-snapped to the grid, and **capped at
    31 days** (`MAX_UPDATE_AFTER`, 3.21, #384 "to limit excessive update_after derived from HTTP
    headers").
  - Kipple's plan honors only Retry-After, per host. ADOPT the HTTP-date-relative-to-`Date` parsing.
    CONSIDER honoring `max-age`/`Expires` as a per-feed floor with a much tighter cap than 31 days
    (proposal: 4 h), ignored by manual refresh and shown in the health view. A 30-minute poll against
    a feed that says `max-age=3600` is wasted work, but a CDN that says `max-age=604800` must not
    silence a feed for a week.
- **Manual refresh** is `update_feeds(scheduled=False)`. With no backoff state, "update now" and the
  schedule are decoupled by construction, because `update_after` is recomputed after every run
  whatever triggered it. Kipple's plan already says manual refresh bypasses validators and backoff
  but respects a live per-host Retry-After. Add one thing: a manual refresh that succeeds should
  reset the backoff counter exactly like a scheduled success (INFERRED, consistent with "reset on any
  2xx/304").
- **`stale` flag.** A persisted, user-set, one-shot "force full resync" that wipes `caching_info` and
  forces every entry to be re-processed, then auto-clears. CONSIDER a per-feed "Resync" action in the
  phase-2 health view. It would clear the ETag/Last-Modified/body hash, re-evaluate all items, and be
  useful after changing the feed's full-text or UA override.

### 3.5 Writes and transactions

Reader writes entries first, then the feed row, with **no transaction spanning the feed**, and
chunks entry writes. The docstring says *"It's acceptable for this to not be atomic... since they will
likely be updated on the next update (because the feed will not be marked as updated if there's an
exception, so we get a free retry)."* REJECT for Kipple. The plan's "one writer goroutine, one
transaction per feed, retention in the same transaction" is cheap with a single writer and keeps
tombstones, FTS rows and `state_changed_at` consistent for Reader API clients. Keep one borrowed
idea: **write the feed's "content changed" marker last** (`last_new_item_at`, body hash,
validators), so an aborted run naturally retries.

### 3.6 HTTP layer

| reader | Kipple plan | verdict |
|---|---|---|
| Timeout `(3.05, 60)` connect/read | dial 10 s, header 15 s, total 30 s | keep Kipple |
| UA `python-reader/{version} (+{SOURCE_URL})` | `Mozilla/5.0 (compatible; Kipple/<ver>; +https://rss.example.com)` + per-feed override | keep Kipple. Its `Mozilla/5.0 (compatible; …)` prefix is effectively what `ua_fallback` retries with (§7). |
| `Accept` built from mounted parsers' declared types | Miniflux list | keep Kipple |
| Redirects left to `requests` defaults. URL change is manual-only via `change_feed_url()` | migrate after 3 consecutive permanent chains | keep Kipple's rule, but ADOPT what `change_feed_url()` resets on migration: **clear `caching_info`** (validators belong to the old URL), reset error state and `next_fetch_at`, keep items. |
| No body size cap. Streams to a temp file (~20 % faster under parallel updates) | 10 MiB cap on the decompressed stream | keep Kipple |
| `A-IM: feed` (RFC 3229) on every request | none | REJECT. 226 responses complicate the pipeline and are rarely served. |
| No SSRF guard, no per-host concurrency | SSRF dialer, per-host 2 | keep Kipple |
| Charset left to feedparser's sniffing | decode to UTF-8 before `gofeed.Parse` | keep Kipple |

### 3.7 Parse tolerance

The feedparser path skips a bad entry with a warning and fails the feed only if **all** entries
failed (#281). The JSON Feed path has an open `# TODO: skip entries that raise ParseError with a
warning`, so one bad item fails the whole feed. ADOPT per-item tolerance in Kipple's normalization
for all three formats. Log the skipped item in `fetch_log` and do not fail the feed.

### 3.8 Hook timing

`_update/hooks.py` times every hook call and logs a warning at ≥1 s. CONSIDER the same for Kipple's
per-feed stages (fetch, parse, write). A `slog` warning when any stage exceeds 1 s finds the one
pathological feed quickly, without adding a monitor.

---

## 4. Entry dedup heuristics versus Kipple's uid / link_hash / GUID-migration rules

### 4.1 What reader does (VERIFIED, `src/reader/plugins/entry_dedupe.py`, 1122 lines)

- **Identity.** The raw parser id is the primary key: RSS guid, falling back to `<link>`, with an
  error if both are missing. Atom and JSON Feed use `id`. No hashing, no type prefix, no link_hash,
  no re-keying. Duplicate ids within one feed are first-wins (open issue #335).
- **Duplicates are merged after insert** by the opt-in `entry_dedupe` plugin in `after_feed_update`.
  It loads all of the feed's entries. The docstring gives its primary purpose as: *"the id of some or
  all the entries in a feed changes... causing each entry to appear twice... fixes this by copying
  user attributes to the new entry and deleting the old one."*
- **Candidate groupers**, exact match, in order. A group with more than
  `max_candidate_group_size = 4` members is skipped.
  1. `link_grouper`, keyed on `normalize_url(link)`. It lowercases scheme and host, rewrites
     **`http`→`https`**, and applies `path.rstrip('/')`. Query and fragment are kept.
  2. `title_grouper`, keyed on the tokenized title.
  3. `published_grouper`, keyed on `(published or updated)` to the second.
  4. `title_strip_prefix_grouper` for new entries. It strips a Trie-detected common title prefix
     (`min_df=4`, `min_length=5`) for platform migrations that prefix every title.
  - Rejected upstream, with reasons documented from #371: a title-*similarity* grouper ("tens of
    seconds per feed", too many false positives) and a published-*day* grouper (too many false
    positives).
- **Confirmation by content similarity** (`is_duplicate_entry`). A candidate pair is confirmed only
  if its content matches:
  - Take each entry's longest of summary/content. Tokenize with HTML stripped (alt/title text kept),
    NFKD, lowercase, and dates/versions kept as single tokens:
    `\d{1,4}(?:[/-]\d{1,4}){1,2}` and `\d{1,4}(?:\.\d{1,3}){1,2}(?:[\._-]?[a-z]{1,5}\d{1,2})?`.
  - If either side is empty, the answer is "not a duplicate". If lengths differ by more than
    **1.5×** (`MIN_TRIM_CONTENT_RATIO`), trim the longer to the shorter's length. Below
    **48 tokens** (`MIN_CONTENT_LENGTH`, raised from 32 after #371), don't decide.
  - An exact match is a duplicate. Otherwise use **weighted (multiset) Jaccard over n-grams**:

    | avg tokens | unit | n | threshold |
    |---|---|---|---|
    | ≤12 | char | 3 | 0.60 |
    | ≤20 | char | 3 | 0.70 |
    | ≤40 | char | 3 | 0.80 |
    | ≤80 | char | 4 | 0.70 |
    | ≤120 | char | 4 | 0.80 |
    | ≤200 | char | 4 | 0.825 |
    | ≤400 | char | 4 | 0.85 |
    | ≤800 | char | 4 | 0.875 |
    | ≤1600 | word | 3 | 0.80 |
    | ≤2400 | word | 4 | 0.80 |
    | ≤3600 | word | 4 | 0.85 |
    | ≤4800 | word | 4 | 0.90 |

    These are hand-tuned against #371 and #202 examples. MinHash/LSH was rejected ("datasketch pulls
    in numpy/scipy" and it "would likely not get rid of heuristics").
  - The `.reader.dedupe.once.{title,link,title_prefix}` feed tags skip the content check. They are
    documented as raising false-positive risk.
- **Merging.**
  - Survivor: newest `(updated or published)`, then `last_updated`, then id. This avoids the
    flip-flop in #340.
  - Read and important: **CORRECTION to the raw report.** `merge_flags` sorts by
    `(value if not None else -1, -modified.timestamp())` and takes the last element. So the "most
    set" value wins (True > False > None), and ties go to the **oldest** modified time. That matches
    the module docstring ("Use the oldest *modified*"). The raw report said "most recent".
  - Tags are copied, with collisions kept as `.reader.duplicate.N.of.<key>`. `recent_sort` becomes
    the **min** across the group. Duplicates are hard-deleted through the low-level
    `Storage.delete_entries()`.

### 4.2 Kipple's plan (from `fetch-prior-art.md` via the plan)

- The uid is `g:` sha256(guid), falling back to `l:` sha256(raw link), then `h:`
  sha256(title+content).
- A `link_hash` column exists for GUID-migration detection. When **≥50 % and ≥5** of the items that
  are new by uid match existing items by link, Kipple **re-keys** the existing rows instead of
  inserting new ones.
- Tombstones in `trimmed(feed_id, uid, item_id, read, trimmed_at)` stop trimmed items from coming
  back.

### 4.3 The deciding difference: Kipple ids are published to clients

Reader can merge after the fact because nothing outside the process has seen the duplicate's id.
Kipple cannot. Once an item id has gone out in `stream/items/ids`, Reeder and NetNewsWire keep it.
The Reader API has no "item deleted" or "item merged" signal. A post-hoc delete leaves a ghost the
client may still show unread, and `edit-tag` against it must keep answering `OK`. **Dedup must happen
before insert** (INFERRED from the sync contract research, not from reader). So Kipple's pre-insert
re-key design is the right shape, and reader's post-hoc merge is not portable. Reader's matching
evidence is portable.

### 4.4 Recommended combination

1. **Normalize the link before hashing**, for both `link_hash` and the `l:` uid, with reader's
   `normalize_url`: lowercase scheme and host, `http`→`https`, strip trailing `/` from the path, and
   keep query and fragment. The most common real GUID migration is a site moving to https, where
   GUID and link change scheme together. A hash of the **raw** link misses exactly that case, so the
   migration detector would never fire when it matters most. Kipple has no data yet, so changing the
   uid derivation now is free.
2. **Require link uniqueness on both sides before any re-key.** Borrow the spirit of reader's
   `max_candidate_group_size = 4`, but be stricter: a normalized link must map to exactly one
   existing live item and one incoming item. Feeds whose items all link to the homepage, or whose
   GUIDs are random per fetch, would otherwise collapse many items into one.
3. **Keep the bulk rule (≥50 % and ≥5) as the primary trigger.** It handles the mass-migration event
   in one decision.
4. **Add a guarded per-item rule for the small case** that the bulk rule misses: a feed with fewer
   than 5 items, or one post whose GUID was edited. Re-key when the new uid is unknown, its
   normalized link matches exactly one live item in the same feed, **and** the normalized titles are
   equal (reader's link grouper confirmed by its title grouper). CONSIDER. It is cheap and uses
   columns Kipple already has.
5. **Do not port the Jaccard/n-gram machinery in phase 1.** It exists in reader for cases (republished
   posts with new links, title-prefix migrations) where the risk of a wrong merge is a silently lost
   post. Kipple can't undo a merge that clients have seen. Revisit only if duplicates show up in real
   use. The threshold table above is ready if needed, as a confirmation step for rule 4 when titles
   differ.
6. **Re-key keeps the old item id, so no flag merging is needed.** State stays on the same row. That
   is strictly better than reader's delete-and-copy. If Kipple ever does merge two live rows, use
   reader's rule: starred = OR, read = OR, and keep the **older** id, which is also the one clients
   already hold.
7. **The `h:` fallback and #225.** Reader drops entries with neither guid nor link. Kipple's `h:`
   sha256(title+content) is more lenient, but any item whose body includes a timestamp becomes a
   new item on every fetch, which is the exact failure `HASH_CHANGED_LIMIT` guards against in reader.
   CONSIDER `h:` = sha256(normalized title + published-date) when a date exists, with content only as
   the last resort.
8. **Tombstones.** CONSIDER adding `link_hash` to `trimmed`, so a trimmed item that reappears under a
   new GUID (only possible for feeds that list more than N items) is still recognized. It is low
   cost, and it closes the one path by which the GUID-migration rule and retention interact.

---

## 5. Search (FTS5) design

VERIFIED from `src/reader/_storage/_search.py`, `_changes.py`, `_html_utils.py`, and the guide's
"Full-text search" section.

- **DDL:**
  ```sql
  CREATE VIRTUAL TABLE entries_search USING fts5(
      title, content, feed,
      _id UNINDEXED, _feed UNINDEXED, _content_path UNINDEXED, _is_feed_user_title UNINDEXED,
      tokenize = "porter unicode61 remove_diacritics 1 tokenchars '_'"
  );
  INSERT INTO entries_search(entries_search, rank) VALUES ('rank', 'bm25(4, 1, 2)');
  ```
  The weights are title ×4, content ×1, feed title ×2. The code comment says "we still need to tune
  the rank weights, these are just guesses". It is a **plain** FTS5 table (text copied in, no
  `content=`). One entry can produce several rows (summary plus each content), tracked through a JSON
  `es_rowids` side table so they can be deleted together.
- **Query:** `snippet()` on title, feed and content. `JOIN entries ON (entries.id, entries.feed) =
  (_id, _feed)`, `ORDER BY rank`, grouped with `min(rank)` per entry. `.LIMIT("-1 OFFSET 0")` is a
  deliberate trick to stop subquery flattening (it cites SQLite optoverview rule 14).
- **Indexed text:** BeautifulSoup strips `<script>/<noscript>/<style>/<title>`, keeps `<head>` text
  ("Firefox shows any free-floating text"), and injects `alt`/`title` attribute text next to its
  element so image captions are searchable.
- **Sync model:** a `changes` table fed by triggers on `entries`. The triggers fire only when
  `title/summary/content` change (`coalesce(x,'') != coalesce(y,'')`), **never on read/important/tag
  changes**. A feed title change re-sequences the feed's entries because the feed title is
  denormalized into the index. The index is updated only when the app calls `update_search()`.
- **Separate attached `db.sqlite.search`** (guide: "versionchanged 3.12". The code comment says 3.11).
  The reason: *"We don't call strip_html() in transactions, because it keeps the database locked for
  too long... Since 3.11, the search index is in a separate, attached database, so we don't care about
  locking that one that much."* A second reason from the guide: the index "can be almost as large as
  the main database", and splitting it lets the main DB be backed up alone.

**For Kipple (phase 2 UI, schema in phase 1):**

- ADOPT the tokenizer, updated to **`porter unicode61 remove_diacritics 2`**. Mode 2 fixes
  diacritic folding for some code points and has existed since SQLite 3.27 (INFERRED from SQLite
  docs). Kipple's SQLite is 3.53.
- ADOPT `bm25(title 4, content 1)` as the starting weights, with reader's caveat that they are guesses.
- ADOPT reader's stripping rules: drop script/style/noscript, and fold `alt`/`title` text into the
  indexed text. Do the stripping **in Go, before the write transaction**, with `x/net/html` (already a
  dependency), and pass the resulting plain text into the transaction. That removes reader's whole
  reason for a separate attached DB and a deferred `update_search()`. REJECT both. One file keeps
  `VACUUM INTO` backups atomic. At 138 feeds × 250 items (~35k rows), index size is irrelevant.
- The plan's step 2 says "FTS5 triggers". SQL triggers can't strip HTML unless a Go function is
  registered with the driver. So either (a) insert FTS rows explicitly from Go in the same per-feed
  transaction (recommended), or (b) keep a precomputed `text` column on `items` that triggers copy.
  Either way, borrow reader's rule that **read/star updates must not touch FTS**. If triggers are
  used, write them as `AFTER UPDATE OF title, content_text ON items`. A bare `AFTER UPDATE` would
  rewrite the index on every `edit-tag`.
- Use FTS `rowid = items.id` (one row per item, best of full text and summary) instead of reader's
  multi-row plus JSON rowid list. Retention deletes must delete the FTS row in the same transaction.
- Don't index the feed title (reader had to re-sequence whole feeds on rename to support it). A feed
  filter is a join on `feed_id`.
- Keep the `LIMIT -1 OFFSET 0` anti-flattening trick in mind if a search query joins `items` and gets
  slow (INFERRED applicability).

---

## 6. Reading time: is it trivial?

**Yes.** It is about 20 lines of Go with no new dependency. VERIFIED from
`src/reader/plugins/readtime.py` (172 lines, most of them backfill plumbing):

```python
# roughly following https://github.com/alanhamlett/readtime 2.0
_WPM = 265
_WORD_DELIMITER = re.compile(r'\W+')

def _readtime_of_html(html):
    soup = get_soup(html)
    remove_nontext_elements(soup)
    seconds = _readtime_of_strings(soup.stripped_strings)
    images = len(soup.select('img'))
    delta = 12
    for _ in range(images):
        seconds += delta
        if delta > 3:
            delta -= 1
    return seconds

def _readtime_of_strings(strings):
    ...
    num_words = sum(len(re.split(_WORD_DELIMITER, s)) for s in strings)
    return int(math.ceil(num_words / _WPM * 60))
```

- **Formula:** `ceil(words / 265 × 60)` seconds. Add +12 s for the first `<img>`, +11 for the
  second, and so on down to +3, then +3 for each further image. Plain-text content is the same
  without the image term. No content gives `{'seconds': 0}`. The result is stored as the
  `.reader.readtime` entry tag `{'seconds': N}`. The `readtime` PyPI dependency was dropped in 3.1.
- **Why it is trivial for Kipple:** the HTML-to-text pass already exists for FTS (§5). Word count is
  `len(strings.FieldsFunc(text, notLetterOrDigit))`. Image count comes from the same tokenizer walk.
  Compute it at insert, store `read_seconds INTEGER` on `items`, and no backfill is ever needed if the
  column is in `0001_init.sql`. Reader's backfill machinery (global and per-feed
  `{'backfill':'pending'|'done'}` tags, three hooks) exists only because the plugin can be enabled on
  an existing DB. Kipple skips all of it.
- **The two non-trivial edges, both UI-side:**
  1. Many feeds ship truncated summaries, so "1 min" is misleading. Recompute when full-text
     extraction runs (store the value for the displayed content), and consider hiding values under
     60 s.
  2. Python's `re.split` counts a trailing empty string as a word (a slight overcount), and `\W+`
     undercounts CJK. Exact parity doesn't matter.
- **Verdict:** include it in phase 1's schema and insert path (one column, one function, one table
  test). Display is phase 2.

---

## 7. User-Agent fallback and other plugins worth porting

### 7.1 `ua_fallback` (VERIFIED, full file fetched)

```python
def _ua_fallback(session, response, request, **kwargs):
    if not response.status_code == 403:
        return None
    ua = request.headers.get('User-Agent', session.headers.get('User-Agent'))
    ...
    ua_prefix = feedparser.USER_AGENT.partition(" ")[0]
    request.headers['User-Agent'] = f'{ua_prefix} {ua}'
    log.info("forbidden, retrying", status=response.status_code, **log_headers)  # logs Server, X-Powered-By
    return request
```

The docstring says "Servers/CDNs known to not accept the *reader* UA: Cloudflare, WP Engine" (#181).
There is an open `.. todo::` to "Maybe cache if the fallback is needed as reader metadata, and change
the UA on the first request instead of retrying." In practice it triggers on 403 only and retries
once with `feedparser/6.x python-reader/...` (INFERRED exact string from feedparser's `USER_AGENT`).

**Port, with upstream's TODO fixed.** On a 403, retry once with a browser-like UA (a full
`Mozilla/5.0 (Windows NT 10.0; Win64; x64) … Chrome/…` string). If the retry succeeds, persist
`ua_mode = 'browser'` on the feed, so later polls use it first with no wasted 403. Surface it in
the health view. Log `Server` and `X-Powered-By` from the 403, as reader does, so the owner can see which
CDN blocked it. Caveat already in the plan's Risks: a Cloudflare *challenge* keys on TLS fingerprint,
not UA, so this fixes only UA-based blocks. The manual `disable_http2` and UA overrides stay.

### 7.2 `enclosure_dedupe` (VERIFIED, 37 lines)

It dedupes an entry's enclosures by `href`, first wins, at read time only, by monkey-patching
`get_entries`. The docstring says "There should be a hook for this". ADOPT, but do it at
normalization time: gofeed can surface the same media URL as both `<enclosure>` and
`media:content` (INFERRED). Dedupe by normalized URL before storing. It is a few lines.

### 7.3 `mark_as_read` (VERIFIED, 126 lines)

Per-feed `{"title": [regex...]}` rules. For **new** entries only (explicitly a no-op for modified
ones), it sets read=true and important=false with `modified=None`, so it doesn't pose as a human
action. `.reader.mark-as-read.once` backfills only `read=False, important='notset'` entries and never
overrides a human choice. Not in any phase. It is a CONSIDER for after phase 4 ("mute titles
matching…"). If it's ever built, two lessons carry over: rules must never produce stats events, and
a rule-applied read must still bump `state_changed_at` so API clients sync it.

### 7.4 Not worth porting

- `entry_dedupe`: see §4. Take the link normalization and title confirmation, not the merge engine.
- `readtime`: see §6. Take the formula, not the backfill hooks.
- `_plugins/legacy/share.py`: social share links, which is a non-goal.
- `A-IM: feed`: see §3.6.

---

## 8. Retention: what reader does, and how Kipple differs

**Reader has no retention at all.** VERIFIED. From `docs/guide.rst`, "Deleting entries":

> As of version |version|, entries are **not** deleted automatically, and there is no high-level
> way of deleting entries; see :issue:`96` for details and updates.
>
> Deleting entries properly is non-trivial for two reasons:
> * Deleted entries should stay deleted; right now, if you delete an entry that still appears in the
>   feed, it will be added again on the next update.
> * The entry_dedupe plugin needs the old entry in order to work.

- `Reader.delete_entry()` only deletes `added_by == 'user'` entries. Feed entries go away only
  through `ON DELETE CASCADE` of the whole feed, or through the low-level `Storage.delete_entries()`,
  which is a per-row DELETE loop with "we'll deal with locking issues only if they start appearing".
- There is no tombstone table, no newest-N, no age limit, and no starred exemption (nothing needs one).

**How Kipple's design answers reader's two stated blockers:**

| reader's blocker | Kipple's answer |
|---|---|
| "Deleted entries should stay deleted" | `trimmed(feed_id, uid, item_id, read, trimmed_at)` tombstones are checked before insert. Items seen in the current fetch are never trimmed, so an item still in the feed can't be trimmed and re-added. |
| dedupe needs old entries | Kipple dedups **before insert** against live rows (≤N per feed) plus tombstones. The GUID-migration case involves items currently in the feed, which are live by construction. Recommendation 4.4.8 (link_hash on tombstones) covers the remainder. |

**Additional Kipple obligations with no reader analogue** (INFERRED from the sync contract):

- A trimmed id must still get `OK` from `edit-tag` and be absent from `stream/items/ids`. Already in
  the plan's phase 1 gate.
- Keep the `read` state in the tombstone. Reader's merge logic shows why state must survive identity
  changes, and Kipple needs it so a re-seen trimmed item never comes back unread. Already in the plan.
- Trim must delete FTS rows in the same transaction (§5), and must not cascade into `stats_events` (§2.2).
- Starred items are exempt from the cap and don't count toward N. The plan ranks only non-starred
  items, which matches the phase 1 verification step "star an old item and lower the cap".
- One design point reader's silence doesn't settle: **when a user un-stars an item that is past the
  cap**. Recommended: leave it until the next fetch of that feed, when it is trimmed normally
  ("trim after fetch only" per CLAUDE.md), rather than trimming on the un-star write.

Net: Kipple's retention is novel relative to reader. Reader offers only the negative lesson that
naive deletion resurrects entries, and Kipple's tombstones already address it.

---

## 9. Concrete deltas to apply to the Kipple design

1. **ADOPT**: Set `PRAGMA foreign_keys=ON` on every pooled connection through the DSN, because the
   setting is per-connection and a pool silently loses it (reader sets it on every connection for
   this reason).
2. **ADOPT**: Stamp `PRAGMA application_id` and refuse to open a DB with a different id, to catch a
   wrong volume mount cheaply.
3. **ADOPT**: Set `synchronous=NORMAL` explicitly under WAL and `busy_timeout=5000` on all
   connections, because reader's silence on these isn't a signal and SQLite's default is FULL.
4. **ADOPT**: Run `PRAGMA foreign_key_check` after each migration step in the ~60-line migration
   runner, as reader does, so a bad table rebuild fails loudly.
5. **ADOPT**: Run `PRAGMA optimize` after each fetch cycle (or hourly) on the writer, swallowing
   "locked", following reader's opportunistic optimize schedule.
6. **ADOPT**: Add a startup self-check that probes `json_valid()` and FTS5 creation and fails fast
   naming every missing feature, so a driver fallback to ncruces can't silently lose FTS5.
7. **ADOPT**: Keep both `last_checked_at` and `last_new_item_at` on `feeds`, mirroring reader's
   `last_retrieved`/`last_updated` split, for the health view's dead-feed signal.
8. **ADOPT**: Give `items` a versioned `content_hash` that excludes all date fields and skips empty
   fields, so feeds that churn `lastBuildDate` or `updated` don't rewrite unchanged rows (#231).
9. **CONSIDER**: Add an indexed `sort_at` column set to the clamped published date on a feed's first
   fetch and to crawl time afterward (reader's `recent_sort`), and on first fetch assign crawl-time
   ids in ascending published order so Reeder's `timestampUsec` order matches real dates for an
   imported backlog.
10. **ADOPT**: For an existing uid, update the item in place when its `updated` changes or its
    content hash changes, never touching id/read/starred/crawl time, and cap hash-only updates at 24
    in a row (reader's `HASH_CHANGED_LIMIT`, #225).
11. **ADOPT**: Model the fetch decision as a pure function (feed row, HTTP result, parsed items,
    existing rows, now → intents), as reader's `Decider` does, so the planned status-table and
    fake-clock tests need no I/O.
12. **ADOPT**: Keep the body SHA-256 short-circuit, but rely on per-item content hashes for real
    no-op detection, because reader's experience shows body bytes churn without content change.
13. **ADOPT**: Parse `Retry-After` in both delta-seconds and HTTP-date form, interpreting the date
    relative to the response `Date` header to tolerate clock skew (reader 3.21).
14. **CONSIDER**: Honor `Cache-Control: max-age` (unless `no-cache`) or `Expires` as a per-feed
    next-fetch floor that only pushes out, capped at 4 h (reader caps at 31 days) and ignored by
    manual refresh.
15. **REJECT**: Grid-snapped scheduling, because it bunches all feeds on the same wall-clock
    boundary and Kipple's spread `next_fetch_at` is gentler.
16. **REJECT**: Dropping exponential backoff to match reader, because reader has no failure handling
    beyond an error flag and Kipple's backoff/410 rules come from better-suited prior art.
17. **REJECT**: Reader's non-atomic entries-then-feed writes, because Kipple's single writer makes
    one transaction per feed cheap and the Reader API needs tombstones/FTS/state consistent. Do keep
    the ordering lesson and write the feed's validators and body hash last.
18. **ADOPT**: When auto-migrating a feed URL, clear the stored ETag/Last-Modified/body hash and
    reset error state and `next_fetch_at` while keeping items, which is exactly what reader's
    `change_feed_url()` resets.
19. **ADOPT**: Skip a single malformed item with a `fetch_log` note instead of failing the feed, in
    all three formats (reader does this for RSS/Atom and has an open TODO for JSON Feed).
20. **CONSIDER**: Log a `slog` warning when any per-feed stage (fetch, parse, write) takes ≥1 s,
    copying reader's timed hooks, as a zero-infrastructure slow-feed detector.
21. **CONSIDER**: Add a per-feed "Resync" action (clear validators and body hash, re-evaluate every
    item once), modeled on reader's one-shot `stale` flag.
22. **REJECT**: `A-IM: feed` delta requests, because 226 handling adds complexity for almost no
    servers.
23. **ADOPT**: Hash both `link_hash` and the `l:` uid over reader's `normalize_url` form (lowercase
    scheme and host, http→https, strip trailing slash, keep query and fragment), because the common
    https-migration case changes the raw link and would defeat the GUID-migration detector.
24. **ADOPT**: Re-key only when a normalized link matches exactly one live item and exactly one
    incoming item, so feeds whose items all share one link can never collapse.
25. **CONSIDER**: Add a per-item re-key rule (unknown uid + unique normalized-link match + equal
    normalized title) for GUID edits below the bulk rule's ≥5 threshold.
26. **REJECT**: Porting reader's post-hoc delete-and-merge dedup and its Jaccard engine for phase 1,
    because Kipple's ids are already on clients once served and the Reader API can't retract them.
    Keep the threshold table documented for later.
27. **CONSIDER**: Derive the `h:` uid from normalized title plus published date when a date exists,
    so bodies with embedded timestamps don't mint a new item every poll (#225 class).
28. **CONSIDER**: Store `link_hash` in `trimmed` so a trimmed item that reappears under a new GUID is
    still blocked.
29. **ADOPT**: Keep `stats_events` free of `ON DELETE CASCADE` from `items`, with a feed id and
    title snapshot, because retention deletes items and stats events are never trimmed.
30. **ADOPT**: Use FTS5 with `tokenize="porter unicode61 remove_diacritics 2"` and `rank` =
    `bm25(4, 1)` (title, content), one row per item keyed by `items.id`.
31. **ADOPT**: Strip HTML for the index in Go before the write transaction (drop script/style/
    noscript, fold in alt/title text, as reader's `strip_html` does), and write FTS rows explicitly
    in the same per-feed transaction rather than through triggers that can't strip HTML.
32. **ADOPT**: Ensure `edit-tag` read/star updates never touch FTS (reader's triggers fire only on
    title/content changes), and delete FTS rows in the retention transaction.
33. **REJECT**: A separate attached search DB and deferred `update_search()`, because reader needed
    them only to keep Python HTML stripping out of the lock, and one file keeps `VACUUM INTO`
    backups simple.
34. **ADOPT**: Compute `read_seconds` at insert with reader's formula (265 WPM, `ceil`, image bonus
    12 s decreasing to a 3 s floor), store it in `0001_init.sql`, and recompute on full-text
    extraction. It's trivial because the FTS text pass already exists.
35. **ADOPT**: On a 403, retry once with a browser UA, and on success persist `ua_mode='browser'` on
    the feed (fixing reader's `ua_fallback` TODO) and log the 403's `Server`/`X-Powered-By`.
36. **ADOPT**: Dedupe enclosures by normalized URL during normalization rather than at read time (the
    point of reader's `enclosure_dedupe`, done where reader's own docstring says a hook should be).
37. **REJECT**: A tri-state starred and per-flag `*_modified` columns, because the Reader API starred
    flag is binary and one `state_changed_at` serves `ot`, with provenance in stats events.
38. **CONSIDER (post-phase 4)**: Title-regex auto-mark-read rules on new items only, never producing
    stats events and always bumping `state_changed_at` (reader's `mark_as_read`).
39. **ADOPT**: Leave an un-starred item that is past the cap in place until that feed's next fetch
    trims it, consistent with "trim after fetch only".

---

## 10. Sources

Code (raw, `master` at tree `b9dec1b9495ce09710102d4e47deb4aec23a81f0`, fetched 2026-09-24,
base `https://raw.githubusercontent.com/lemon24/reader/master/`):

- `src/reader/_storage/_schema.py`: DDL, migrations, `VERSION = 44`, `MINIMUM_SQLITE_VERSION`
- `src/reader/_storage/_sqlite_utils.py`: pragmas, `LocalConnectionFactory`, optimize schedule,
  `ddl_transaction`, `HeavyMigration`
- `src/reader/_storage/_base.py`, `_entries.py`, `_feeds.py`, `_tags.py`, `_sql_utils.py`
- `src/reader/_storage/_changes.py`: change-log table and triggers
- `src/reader/_storage/_search.py`: FTS5 DDL, bm25 weights, snippet query, attached DB rationale
- `src/reader/_storage/_html_utils.py`: `strip_html`, alt/title folding
- `src/reader/_update/__init__.py`, `_update/base.py`, `_update/hooks.py`: pipeline, `Decider`,
  `next_update_after`, `HASH_CHANGED_LIMIT`, `MAX_UPDATE_AFTER`, hook timing
- `src/reader/_parser/__init__.py`, `_parser/feedparser.py` (plus `jsonfeed.py` per Report B):
  HTTP retriever, UA, timeouts, `HTTPInfo.get_update_after`, per-entry tolerance
- `src/reader/_hash_utils.py`: versioned content hashing
- `src/reader/core.py`: `update_feeds(scheduled=...)`, `delete_entry`, `change_feed_url`
- `src/reader/plugins/entry_dedupe.py`: groupers, `normalize_url`, `MIN_CONTENT_LENGTH = 48`,
  `MIN_TRIM_CONTENT_RATIO = 1.5`, n-gram threshold table, `merge_flags` (lines 775–786)
- `src/reader/plugins/readtime.py`: `_WPM = 265`, image bonus, backfill hooks
- `src/reader/plugins/ua_fallback.py`: 403 retry, TODO on caching
- `src/reader/plugins/enclosure_dedupe.py`, `src/reader/plugins/mark_as_read.py`
- `CHANGES.rst`: WAL (#169), 3.21 scheduling and header changes, readtime dependency drop (3.1),
  important tri-state (3.5)

Docs:

- https://reader.readthedocs.io/en/latest/guide.html ("Deleting entries", "Full-text search",
  "Updating feeds", scheduling config)
- https://reader.readthedocs.io/en/latest/dev.html
- https://reader.readthedocs.io/en/latest/internal.html ("search is tightly-bound to a storage
  implementation", marked Unstable)
- https://reader.readthedocs.io/en/latest/why.html ("reader is a library", "minimal dependencies")
- https://reader.readthedocs.io/en/latest/changelog.html
- https://reader.readthedocs.io/en/latest/plugins.html

Upstream issues cited by the code (`https://github.com/lemon24/reader/issues/<n>`): #96 (entry
deletion), #169 (WAL), #181 (UA fallback), #202 / #371 (dedupe heuristics and thresholds), #225
(hash-change limit), #231 (`updated` excluded from hash), #261 (parse not threaded), #275 (readtime),
#279 (`recent_sort`), #281 (per-entry parse tolerance), #307 (Retry-After), #335 (duplicate ids),
#340 (survivor flip-flop), #376 / #384 (Cache-Control/Expires and the 31-day cap).

Kipple inputs: `C:\Users\user\.claude\plans\cached-imagining-tome.md` (sections "Research findings
that shape the design" and "Product decisions made in this plan"); the raw reports
`research-raw/lemon24-reader-storage.md` and `research-raw/lemon24-reader-update.md`.

Corrections made against the raw reports while writing this:

1. `merge_flags` breaks ties by the **oldest** modified time, not the most recent (source lines
   775–786).
2. Reader does not "rely on WAL's default NORMAL". SQLite's default `synchronous` is FULL, and reader
   never sets it (SQLite docs, INFERRED).
3. The search split is "versionchanged 3.12" in the guide but "Since 3.11" in the code comment. This
   doesn't matter for Kipple.
