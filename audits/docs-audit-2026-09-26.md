# Kipple docs-versus-code audit, 2026-09-26

Audited tree: `origin/phase-2` at `f72fc84` ("docs: human feedback folder, client A evidence, basic README"), read in a scratch worktree. Nothing in the code was changed. `go build ./...` passes. All evidence paths are relative to the repo root; line numbers refer to that commit.

**Severity.** WRONG: misleads an implementer or operator. STALE: outdated or superseded but harmless. MISSING: shipped behavior that is not documented.

**How to use this file.** Findings are grouped by document, most severe first within each group. Each one has a checkbox, the doc location, what the doc says, what the code does (with file:line evidence), and the exact fix. Several findings are the same root cause seen from different sections (the three inert settings, the ledger purge horizon, phase-4 stats). The "Internal contradictions" list below cross-references them so a fixer can do them together. Where a fix changes a CLAUDE.md "do not relitigate" decision (themes, fonts, retention), the fix only aligns the text with what shipped; the owner should confirm the wording.

## Summary

### Counts by document

| Document | WRONG | STALE | MISSING | Total |
|---|---:|---:|---:|---:|
| docs/design.md §1-§3 (decisions, schema, ids) | 6 | 11 | 13 | 30 |
| docs/design.md §4-§5 (scheduler, retention) | 14 | 16 | 4 | 34 |
| docs/design.md §6 (Reader API) | 11 | 8 | 10 | 29 |
| docs/design.md §7.0-§7.3 (UI API, filters, devices, auto-read, events) | 5 | 5 | 19 | 29 |
| docs/design.md §7.4-§8 (images, full text, OPML, headers, stats) | 8 | 8 | 6 | 22 |
| docs/design.md §9-§13 (layout, tests, risks, red team, deltas, CLI) | 16 | 5 | 3 | 24 |
| **docs/design.md subtotal** | **60** | **53** | **55** | **168** |
| docs/deploy.md | 1 | 1 | 5 | 7 |
| docs/ui-decisions.md | 1 | 5 | 1 | 7 |
| CHANGELOG.md | 3 | 14 | 8 | 25 |
| web/README.md | 7 | 6 | 9 | 22 |
| web/ACCESSIBILITY.md | 6 | 1 | 1 | 8 |
| web/src/theme/README.md | 2 | 0 | 4 | 6 |
| README.md | 0 | 1 | 0 | 1 |
| docs/plan.md (incl. compose C3) | 0 | 9 | 2 | 11 |
| docs/research/open-questions.md | 4 | 4 | 0 | 8 |
| CLAUDE.md | 6 | 3 | 3 | 12 |
| .env.example / docker-compose.example.yml | 3 | 2 | 2 | 7 |
| SECURITY.md | 0 | 1 | 1 | 2 |
| .github/pull_request_template.md | 0 | 0 | 1 | 1 |
| **Total** | **93** | **100** | **92** | **285** |

### Counts by severity

- WRONG: 93
- STALE: 100
- MISSING: 92

About 10 of these are the same root cause reported from different sections (listed below), so the number of distinct edits is roughly 270.

## Internal contradictions (fix these together)

- **Three settings documented as working that no code reads:** `greader.ot_includes_user_changes`, `greader.subscribe_fetch_now` and `stats.api_single_read_is_open`. All three are stored, validated and hidden (internal/api/settingsmeta.go:339, 341, 343; internal/store/uibootstrap.go:34, 45, 46). They are described as working in design.md decisions 6, 21 and 33 (lines 59, 117, 181-183), §4.9 (1127), §6.7 (1494), §6.9 (1547), §8 (1929, 1946-1951), §10 (2231, 2249, 2260), §11 (2324, 2331, 2332) and §12 #24/#35 (2388, 2399). Decide once: either implement them, or mark them "reserved, not implemented" everywhere (and consider removing them from settingsmeta).
- **Ledger purge horizon.** Decision 17 (line 101) says `max(180, restore_days + 7)`, which matches the code (internal/store/maint.go:94). §2.6 (703), §5 (1169, 1267), §11 (2335) and open-questions #27 say 180 days or no purge.
- **Phase-4 stats.** Line 1657 says the CSV export is "phase 4, not mounted yet". §8 (1983), §9 (2004, 2034) and §12 #19/#24 describe it as built, and §8 describes web `read_time`/`scroll`/`open_original`/`share` events that no client sends.
- **Same-origin guard location.** Line 1599 says `internal/httpx/csrf.go`. §9 line 2043 lists csrf.go under httpx. The code has it in internal/api/api.go:268-322.
- **Full text after a stale commit.** §4.3 line 858 contradicts line 873.
- **fetch_log notes.** Line 531 (inside the 0001 block) contradicts line 869.
- **Archive-feed unsubscribe.** §6.9 (1555) says it is a real delete. §7.1 (1635) says it is a 409 `archive_has_starred`. The code does 409 on the web and keeps the feed silently on the Reader API.
- **edit-tag stats.** §6.7 (1494) contradicts §8 (1951). Neither matches the code, which records stars only.
- **Mark-all cutoff.** §3 (780) and §6.8 (1510) both say `max(items.id)`. The code also takes `max(trimmed_items.id)`.
- **web/README.md** contradicts itself twice. Cards is described with no reader pane (40-41) and with one (116-118). The `ui.*` keys are global (100-102) and device-profile keys (163-175).
- **CHANGELOG.md** has superseded entries that were never amended: line 31 vs 161 (device eviction), 26 vs 247 (muted trim), 153 vs 158 (prefix rule), 233 vs 346 (WebP meta codes), 122-126 vs 271 (Reader hold).
- **docs/plan.md** line 124 (tick 60 s) contradicts line 175 (30 s). Plan C5 (`import /import/...`) contradicts deploy.md:83 (nonroot cannot read `/import`). Plan C3 contradicts docker-compose.example.yml on the restart policy.

## Code issues noticed during the audit (not doc fixes; listed for triage)

- [ ] **Bug (verified).** web/src/index.css:244-248 sets `font-size: 0` on `.article-body h1, h2, h3, h4` (the comment was copied from the embed Play button). Lines 249-251 then reset only h1-h3, so every `<h4>` in an article renders invisible. Fix: drop `font-size: 0` from that rule.
- [ ] **Likely bug.** internal/httpx/headers.go:33-36 sends `autoplay=()`, which blocks the `allow="autoplay"` and `?autoplay=1` of the tap-to-load YouTube/Vimeo iframe (web/src/lib/articleDom.ts:9, 14-15). Picture-in-picture is also never granted to Vimeo. Not verified in a browser.
- [ ] **Gap.** Nothing fetches favicons or writes `feed_icons`, so Reader `iconUrl`, the `/icon/` route and the icon settings never have data (see the §9 finding).
- [ ] **Gap.** The web client never sends `expect_total` on the auto-read catch-up, so the server's guard is unused (see CHANGELOG line 13).
- [ ] **Decision needed.** Auto-read targets disabled (non-archive) feeds, with no `enabled` filter (internal/store/autoread.go:85-86).
- [ ] **Decision needed.** The filter-chip Remove button is 32 px (web/src/screens/filters/FilterEditor.tsx:167), below the 44 px target in ACCESSIBILITY.md.

## Top 10 to fix first

1. **The three inert settings** (see Internal contradictions). They are documented as working in about 15 places, and an agent building from design.md would assume they are live. Decide between implementing them and marking them reserved, then apply that everywhere.
2. **docs/deploy.md alpha 3 notes: add the schema 3 -> 5 migration, its snapshot name, the 0005 FTS rebuild time, the rollback to alpha 2, and the CLI refusing the old schema.** This is the next deploy.
3. **CLAUDE.md**, which every agent loads:
   - dev port 8080 → 7080, plus a data dir
   - 20 themes, not 8
   - font list: Charter is system-only, Atkinson Hyperlegible Next is bundled
   - `readability` → `extract` and the real package list
   - "trim after fetch only"
   - the hostname rule
4. **design.md §6 Reader API contract:**
   - body caps (4 MiB / 64 KiB), 413, 400 for too many pairs, 405
   - `subscription/import` needs the Authorization header, and bad OPML is a 400
   - archive-feed unsubscribe
   - edit-tag un-mute SQL
   - quickadd error shape
   - icon headers
5. **design.md §4 scheduler facts:**
   - the commit gate lives inside the store
   - a dedup-mode change does not queue a fetch and shows no confirm dialog
   - the chunk threshold counts all items, and a rekey never chunks
   - the interval pull-in SQL, and no per-feed reschedule
   - host-deadline skip rules
   - retention runs cover enabled feeds only
6. **design.md §5 and §2.6:**
   - the ledger purge horizon
   - the restore window pre-selection SQL
   - the ledger writers that are not listed (auto-read, mark-fetch-read, filtered mark-all)
   - the nightly step order, including the devices purge
7. **design.md §8 stats:**
   - the Recorder is not structurally confined
   - it has two methods
   - the web client sends no `read_time`/`scroll`/`open_original`/`share`
   - "Open original" is a menu action that records nothing
   - mark phase-4 pieces as not built in §8, §9 and §12
8. **design.md §7.3 event contract:**
   - `feed.changed` can carry `{}` from the Reader API, and has more triggers than listed
   - `saved_searches.changed` is not sent when a delete drops scopes
   - the client does not fetch `new_item_ids`
   - the run-event extras for auto-read
9. **design.md §9 and §10:** regenerate the package layout. Specifically:
   - httpx/csrf.go, readability, the favicon finder and the Access JWT do not exist
   - backup, clock, discover, extract, ftrun and lock are missing
   - SQL is not store-only
   - settings are not cached
   - Stop claiming tests that do not exist: the WAL bound, the 150k plan suite, the pool-free helper, captured-traffic goldens.
10. **CHANGELOG.md and design.md §2.2:**
    - remove the nonexistent `kipple fts-rebuild` CLI
    - add the `v0.2.0-alpha.1`/`alpha.2` release sections
    - fix the superseded entries
    - restore the "exactly `0001_init.sql`" block to the real file text, with the current settings-key list moved into prose after it

---

# Findings

## docs/design.md


### design.md preamble, §1 Decisions, §2 Schema, §3 Item ids (lines 1-783)

- [ ] **WRONG** design.md §1 decision 6 (line 59): `greader.ot_includes_user_changes` does nothing
  - Doc says: the setting (default false) "restores the OR on `read_at`/`starred_at`".
  - Code does: the key is validated, stored and returned (internal/api/settingsmeta.go:339, internal/store/uibootstrap.go:45) but nothing reads it. `streamIDsSQL` builds only the id leg and the `content_changed_at` leg (internal/store/items.go:94-131). No reader of the key in cmd/ or internal/.
  - Fix: add "Not implemented: the key is accepted and stored but has no effect; `ot` never includes user changes." (or implement it). Same wording in the §11 risk row (line 2324).

- [ ] **WRONG** design.md §1 decision 33 (lines 181-183): `greader.subscribe_fetch_now=true` path does not exist
  - Doc says: the revision-1 synchronous discovery plus priority fetch "stays behind the setting".
  - Code does: key stored only (settingsmeta.go:341, uibootstrap.go:46); no code reads it.
  - Fix: "The revision-1 behaviour is not built. `greader.subscribe_fetch_now` is accepted and stored but ignored." Also fix lines 1127 and 1547 (see §4.9 and §6.9 findings).

- [ ] **WRONG** design.md §1 decision 21 (line 117): `stats.api_single_read_is_open` does nothing
  - Doc says: API inference can be turned on with this setting.
  - Code does: key stored only (settingsmeta.go:343, uibootstrap.go:34). The only stats write in greader is `RecordStars` (internal/greader/h_edit.go:98). Nothing produces `open` rows with `inferred=1`.
  - Fix: "The toggle is stored but inference is not implemented; no API-derived `open` rows are ever written." Also fix lines 1929 and 1946 (§8).

- [ ] **WRONG** design.md §2.2 (lines 242, 255-260): the block claims to be exactly `0001_init.sql` but is not
  - Doc says: "This block is exactly `0001_init.sql` ... do not edit this block".
  - Code does: the settings comment in internal/store/migrations/0001_init.sql:11-13 lists `imgproxy.mode, tz, ui.* ...` and `sys.last_snapshot_at, sys.last_snapshot_error.` The doc block adds keys the file never had: `fetch.fulltext_all, library.favorites, library.auto_read_days, library.saved_searches (§7.1d)`, `imgproxy.cache_mb`, `sys.auto_read_last_run`, and a 3-line "Defaults worth knowing" paragraph. The rest is byte-identical.
  - Fix: restore doc lines 255-260 to the file's text (`-- imgproxy.mode, tz, ui.* (theme, font_body, font_ui, font_size, line_height, content_width,` / `-- layouts, mark_read_on_scroll, ...). System keys (never PATCHable): sys.id_high_water (JSON` / `-- integer, allocator high-water mark), sys.last_snapshot_at, sys.last_snapshot_error.`). Move the additions to prose after the block, complete: also `fetch.user_agent_mode` (0002) and system keys `sys.last_nightly_date`, `sys.last_nightly_at`, `sys.auto_read_last_run`, `sys.auto_read_feed_marks` (internal/store/maint.go:272-293, internal/maint/maint.go:354). Update line 242 to say three comments are stale (the settings key list is also incomplete).

- [ ] **WRONG** design.md §2.6 (line 703): ledger purge horizon
  - Doc says: `DELETE FROM trimmed_items WHERE last_seen_at < now - 180 d`.
  - Code does: horizon = `max(LedgerDays=180, restore_days + LedgerMarginDays=7)` days (up to 187), batched with `LIMIT` (internal/store/maint.go:24-31, 88-101; settings.go:14). Decision 17 (line 101) states this correctly, so §2.6 contradicts it. Same stale "180 days" at §5 lines 1169 and 1267 and §11 line 2335.
  - Fix: `DELETE FROM trimmed_items WHERE last_seen_at < now - max(180, restore_days + 7) d` (batched). Fix lines 1169, 1267, 2335 to "`max(180, restore_days + 7)` days after last seen".

- [ ] **WRONG** design.md §2.2a (line 591): "`devices` and `feeds.auto_read_days` are still unused"
  - Code does: both are used. `feeds.auto_read_days` is read by the auto-read job (internal/store/autoread.go:85). `devices` has full CRUD, eviction above 50 and a nightly purge (internal/store/devices.go:74-282; internal/maint/maint.go:275).
  - Fix: "`devices` backs per-device appearance profiles (§7.1c) and is purged nightly after 400 days unseen; `feeds.auto_read_days` feeds the nightly auto-read step (§2.6, §7.1d)."

- [ ] **STALE** design.md §2.6 (lines 700-706): nightly step list and order
  - Doc says: step 1 stubs, ledger, sessions, then `PRAGMA optimize`; 1b imgcache sweep; then snapshot. The auto-read bullet sits between "The steps:" and step 1.
  - Code does: purge_stubs -> purge_ledger -> purge_sessions -> purge_devices -> auto_read -> imgcache_sweep -> optimize -> snapshot (internal/maint/maint.go:269-300). `PRAGMA optimize` runs after auto-read and the sweep; the devices purge (`DELETE FROM devices WHERE last_seen_at < now - 400 d`, internal/store/devices.go:279-282) is undocumented.
  - Fix: renumber: 1 purges (stubs, ledger, sessions, devices), 2 auto_read, 3 imgcache sweep, 4 `PRAGMA optimize` (through `WithWrite`), 5 snapshot. Move the auto-read bullet into the list.

- [ ] **STALE** design.md §2.2a (line 592): the 0005 row falls outside the table
  - Doc: a blank line separates the 0004 row from the `0005_fts_porter.sql` row, so Markdown ends the table and 0005 renders as a stray pipe paragraph.
  - Fix: delete the blank line 592.

- [ ] **STALE** design.md §2.5 (line 684 vs 692): snapshot filename suffix inconsistent
  - Doc says: `pre-migration-<from>-<to>-<unixtime>.db` (684), `<ns>` (692).
  - Code does: `time.Now().UnixNano()` (internal/store/migrate.go:147).
  - Fix: line 684: `pre-migration-<from>-<to>-<unix-ns>.db`.

- [ ] **STALE** design.md §2.3 (line 619) and decision 16 (line 94): trim-set selection
  - Doc says: `ORDER BY sort_at DESC, id DESC OFFSET N` over `idx_items_feed_sort`.
  - Code does: window `row_number() OVER (PARTITION BY muted_by IS NOT NULL ORDER BY sort_at DESC, id DESC)` over the feed's unstarred, unretained items; muted and real items kept against separate allowances (`mutedAllowance`, at least n/5 muted). (internal/store/retention.go:33-52, 110)
  - Fix: describe the window query and the muted allowance in §2.3 and decision 16 (and §5).

- [ ] **STALE** design.md §2.3 (lines 624, 627): dedup and tombstone lookups are one query
  - Code does: `WITH u(uid) AS MATERIALIZED (SELECT value FROM json_each(?)) SELECT ... FROM items WHERE feed_id=? AND uid IN u UNION ALL SELECT ... FROM trimmed_items WHERE feed_id=? AND uid IN u` (internal/store/fetchcommit.go:307-312).
  - Fix: say the two lookups are the two arms of one MATERIALIZED-CTE UNION ALL query.

- [ ] **STALE** design.md §2.3 (line 629) and §2.6 (line 702): stub purge SQL
  - Code does: `DELETE FROM trimmed_content WHERE id IN (SELECT c.id FROM trimmed_items t JOIN trimmed_content c ON c.id=t.id WHERE t.trimmed_at < ? LIMIT ?)`, cutoff `now - restore_days*86400` (internal/store/maint.go:73-76).
  - Fix: update the query text and add the batch `LIMIT` in both places.

- [ ] **STALE** design.md §3 (line 780): mark-all default cutoff
  - Doc says: absent/0/non-digit `ts` -> `SELECT max(id) FROM items`.
  - Code does: `max(COALESCE((SELECT max(id) FROM items),0), COALESCE((SELECT max(id) FROM trimmed_items),0))` on the reader (internal/store/itemstate.go:275-279); an overflowing `ts` also falls back (internal/greader/h_edit.go:150-157).
  - Fix: "... -> the larger of `max(items.id)` and `max(trimmed_items.id)` on a reader snapshot (`MaxCommittedID`)"; add "or overflowing" to the fallback list.

- [ ] **STALE** design.md §1 decision 2 (line 37) and §2.1 (lines 225-229): `WithWrite` signature and holder
  - Doc says: `store.WithWrite(ctx, func(tx *sql.Tx) error)`; "records its caller's stack"; "Each acquisition has a 10 s context deadline".
  - Code does: `WithWrite(ctx, fn func(ctx context.Context, tx *sql.Tx) error)`; records one frame (`runtime.Caller(1)`); the 10 s deadline covers begin, fn and commit. (internal/store/tx.go:31-64)
  - Fix: use the `fn(ctx, tx)` signature; "caller's file:line and function"; "each write transaction (acquisition, fn and commit)".

- [ ] **STALE** design.md §2.6 (line 698): hourly checkpoint also takes the commit gate
  - Code does: `CheckpointPassive` calls `AcquireGate` then takes the writer with a 10 s timeout (internal/store/maint.go:127-148).
  - Fix: add "behind the commit gate, bounded by the 10 s write timeout".

- [ ] **STALE** design.md §3 (line 738): high-water upsert text
  - Code does: the upsert also sets `updated_at = unixepoch()` (internal/store/fetchcommit.go:606-608).
  - Fix: `... DO UPDATE SET value = excluded.value, updated_at = unixepoch() WHERE ...`.

- [ ] **STALE** design.md §2.4 (line 646): trigger count
  - Doc says: "All three update triggers are value-guarded".
  - Code does: two UPDATE triggers (`items_fts_au`, `item_content_fts_au`), both guarded; the third guarded trigger is the delete trigger `item_content_fts_bd` (`WHEN EXISTS`); five FTS triggers in all (0001_init.sql:199-225).
  - Fix: "Both update triggers are value-guarded (and `item_content_fts_bd` fires only while the item exists)."

- [ ] **MISSING** design.md §2.3 (lines 610-640): index table lacks migration 0004 indexes
  - Code has `idx_items_muted ON items(sort_at, id) WHERE muted_by IS NOT NULL`, `idx_filters_folder`, `idx_filters_feed`, `idx_devices_seen` (migrations/0004_filters_devices.sql).
  - Fix: add rows: `idx_items_muted` (muted view keyset); `idx_filters_folder`/`idx_filters_feed` (cascade lookup on folder/feed delete); `idx_devices_seen` (LRU eviction and 400-day purge, internal/store/devices.go:172, 281).

- [ ] **MISSING** design.md §2.5 (line 690): migration tests omit 0005
  - Code has internal/store/migrate0005_test.go (fresh schema, populated schema 4, rollback on failure, `TestOlderBinaryRefusesSchema5`, `TestSearchPlan`).
  - Fix: "`migrate0004_test.go` and `migrate0005_test.go` ...; a binary with only four migrations refuses a schema-5 file."

- [ ] **MISSING** design.md §2.5 (lines 678-680): foreign-file check runs before any pool opens
  - Code does: `checkForeign` opens a pragma-free `mode=ro` connection and checks `application_id` and object count before the writer DSN (WAL switch) touches the file; `migrate` re-checks (internal/store/db.go:142-166, 207).
  - Fix: add to step 2: "checked first on a throwaway read-only connection, so a foreign file is never switched to WAL".

- [ ] **MISSING** design.md §1 decision 35 (line 196) and §2.1 (line 223): page-cache budget omits the image-cache index
  - Code does: `imgcache/index.db` has its own writer and 4 readers at `cache_size(-2000)` each, up to ~10 MB more (internal/imgcache/index.go:53, 87, 126).
  - Fix: add "+ up to 5x2 MB for imgcache/index.db when the cache is enabled"; update the 34 MB totals or state the exclusion.

- [ ] **MISSING** design.md §1 decision 19 (line 106): `fetch.fulltext_all` limits
  - Code does: with `fetch.fulltext_all` on, per-fetch cap is 50 (not 20) and queue 2000 (not 500); concurrency stays 4 global, 2 per host (internal/sched/fulltext.go:19-28; sched.go:50-58).
  - Fix: add "a 500-item queue; with `fetch.fulltext_all` on, 50 per fetch and a 2000 queue".

- [ ] **MISSING** design.md §3 (line 741): undated items in the oldest-first order
  - Code does: items with no published date sort last, stamped with crawl time, in reverse document order among themselves (internal/store/fetchcommit.go:134-158).
  - Fix: append "items without a date sort last".

- [ ] **MISSING** design.md §3 (lines 738, 741) and §2.1: `CommitFetch` is chunked
  - Code does: more than 500 new items (no rekey) commit in chunks of 250; each chunk takes the gate and its own 10 s `WithWrite`; `sys.id_high_water` saved per chunk (internal/store/fetchcommit.go:71-113, 208-212).
  - Fix: after "Only inside `CommitFetch`" add "(one transaction per chunk of 250 when a fetch has more than 500 items; see §4.8)"; line 738: "Each `CommitFetch` chunk that allocated ids ends with ...".

- [ ] **MISSING** design.md §2.4 (line 663): oldest-first search order
  - Code does: `q.Oldest` gives `(sort_at, id)` ascending with an `a`-tagged cursor; saved searches accept `order` `date|oldest|rank` (internal/store/search.go:117-123; savedsearch.go:34).
  - Fix: `-- or ORDER BY i.sort_at DESC, i.id DESC when order=date (ASC when order=oldest)`.

- [ ] **MISSING** design.md §2.4 (line 673): FTS rebuild bounded by the 10 s write deadline
  - Code does: `RebuildFTS` runs one `'rebuild'` inside `WithWrite`, capped at 10 s (internal/store/search.go:215-222; internal/api/maintenance.go:8). §2.2a expects ~10 s per 100,000 items, so a large library can time out.
  - Fix: add "It runs in one `WithWrite` (10 s deadline), so on a very large library it can time out and roll back; the offline path is a restore or migration."

- [ ] **MISSING** design.md §2.2a (line 591): 0004 row omits columns and defaults
  - Code has: `devices` also `name` (max 64), `user_agent`, `client` (default `'web'`), `created_at`, `last_seen_at`; `filters` defaults `fields` `'["title"]'`, `whole_word` 1, `fold_diacritics` 1, plus `invert`, `position`, `hits`, `last_hit_at` (migrations/0004_filters_devices.sql).
  - Fix: list these or reference the SQL file as the authority.

- [ ] **MISSING** design.md §2.2a (line 589): 0002 purpose omits its setting
  - Code does: 0002 backs `fetch.user_agent_mode = browser_on_failure` (0002_ua_fallback.sql:1-3; settings.go:59).
  - Fix: add "(used when `fetch.user_agent_mode` is `browser_on_failure`)".

- [ ] **MISSING** design.md §2.1 (line 221): other users of the snapshot pool
  - Code does: also opened for the pre-migration `VACUUM INTO` (migrate.go:142) and the backup export.
  - Fix: "It is opened for the nightly snapshot, the pre-migration snapshot and the backup export, and closed after each."

- [ ] **MISSING** design.md §2.6 (line 712): snapshot error bookkeeping
  - Code does: success deletes `sys.last_snapshot_error`; a cancelled run records nothing and removes the tmp file with its -wal/-shm/-journal (internal/store/maint.go:164-189, 251-255).
  - Fix: add "on success `sys.last_snapshot_error` is cleared; a cancelled run records nothing".

Verified as matching (not listed): DSN and pragmas, pool sizes, cache sizes, self-check probes, migration steps 1-3 and 5-6, 3 pre-migration snapshots kept, 0003 and 0005 SQL, rank config, search limits (12, 3, 64, 512, API cap 1000, 500 ms budget, 422 `search_too_broad`), cursor formats, id allocator and seeding, inbound id parsing, `ts` digit rules, `c`/`ot`/`nt` bounds, 120 s slack, settings defaults (30 min, 250, restore 90, icon_urls true), argon2 parameters, 5 s semaphore, 10/15 min lockout, 24-char API password, fulltext 20/10 s/4/2, 3-observation redirect rule, `retain_until` 7 d, backup export limits (4 GiB, 2.2x + 16 MB, 10 min, 5 min token).


### design.md §4 Fetch scheduler and §5 Retention (lines 784-1285)

- [ ] **WRONG** design.md §4.8 (line 1110) and §11 (line 2334): a dedup-mode change does not queue a fetch, and there is no confirm dialog
  - Doc says: a dedup-mode change sets `rekey_pending = 1` and queues a priority fetch; the UI confirm dialog says "items that cannot be matched will be marked read".
  - Code does: `PatchFeed` only sets `rekey_pending = 1`; `patchFeed` submits a fetch only when `NeedsFetch` (URL change or enable), so the rekey waits for the next scheduled or manual fetch, which is forced `Full` while rekey is pending. No confirm dialog; the editor only shows "Duplicate detection is being re-applied to this feed." (evidence: internal/store/feedadmin.go:147-151; internal/api/feedadmin.go:445-458; internal/sched/dispatcher.go:104-106, 431-433; web/src/screens/feeds/FeedEditor.tsx:309-318)
  - Fix: "A dedup-mode change sets `rekey_pending = 1` and nothing else. The re-key runs on the feed's next fetch (scheduled, refresh-all or per-feed), which is forced `Full` while `rekey_pending` is set. The editor shows 'Duplicate detection is being re-applied to this feed.' while pending. There is no confirm dialog." Same at line 2334.

- [ ] **WRONG** design.md §4.9 (line 1127): `greader.subscribe_fetch_now` does nothing
  - Doc says: with it true, Reader subscribe does discovery plus a priority fetch, waiting 8 s.
  - Code does: never read; Reader quickadd, subscribe and import always just `wake()` (internal/greader/h_subs.go:255-257, 371-372; internal/api/settingsmeta.go:341; internal/store/uibootstrap.go:46).
  - Fix: state it is not implemented (or remove the setting from settingsmeta). Same finding as §1 decision 33 and §6.9.

- [ ] **WRONG** design.md §4.6 (lines 974-981): global interval pull-in SQL; no per-feed equivalent
  - Doc says: `UPDATE feeds SET next_fetch_at = min(next_fetch_at, COALESCE(last_fetch_at, :now) + :new_interval_s) WHERE interval_minutes IS NULL AND consecutive_failures = 0`; "the same statement, keyed on the feed id, runs when a per-feed interval changes".
  - Code does: `PullInSchedule` sets `next_fetch_at = last_fetch_at + max(:interval_s, CASE WHEN honor_ttl THEN min(coalesce(ttl_hint_s,0),86400) ELSE 0 END)` with filter `enabled = 1 AND interval_minutes IS NULL AND consecutive_failures = 0 AND last_fetch_at IS NOT NULL AND next_fetch_at > <that>`, then `Wake()`. A per-feed `interval_minutes` PATCH only writes the column (no reschedule, no wake). (evidence: internal/store/settings.go:227-255; internal/api/settings.go:94-101; internal/store/feedadmin.go:145-179; internal/api/feedadmin.go:445-458)
  - Fix: replace the SQL with the code's; say it runs only on a `refresh.interval_minutes` change followed by `Wake`, never postpones, leaves never-fetched feeds alone, respects the TTL hint when `fetch.honor_publisher_ttl` is on. Replace the per-feed sentence with "A per-feed interval change takes effect from the feed's next fetch (no reschedule)."

- [ ] **WRONG** design.md §4.3 (line 858, contradicts line 873): full text after a stale commit
  - Doc says (858): `if committed and not stale: ftQueue.push(...)`; line 873 says full text is still queued for chunks that did commit.
  - Code does: `queueFulltext` runs whenever `cerr == nil`, stale or not, with `ci.NewIDs` minus `ci.MutedIDs`; a stale single-chunk commit has empty `NewIDs`; a chunked commit cut short queues earlier chunks' items. (evidence: internal/sched/worker.go:91-100; internal/store/fetchcommit.go:103-111)
  - Fix: line 858: `if commit succeeded: queueFulltext(cand, NewIDs - MutedIDs)   // NewIDs is only what really committed (empty for a stale fetch)`.

- [ ] **WRONG** design.md §5 (lines 1169, 1267; contradicts line 101): ledger purge horizon
  - Doc says: ledger rows purged "180 days after the uid was last seen".
  - Code does: `horizon := max(LedgerDays(180), set.RestoreDays+LedgerMarginDays(7))` (internal/store/maint.go:25-31, 88-101).
  - Fix: "`max(180, restore_days + 7)` days after the uid was last seen"; keep the note that `restore_days` is capped at 180 (`MaxRestoreDays`, internal/store/settings.go:14). (Duplicate of the §2.6 finding; fix together.)

- [ ] **WRONG** design.md §5 Restore (lines 1229-1257): restore window missing from the SQL
  - Doc says: restore takes every ledger row with a stub; "Ledger ids without a stub (older than restore_days) cannot be restored".
  - Code does: `restoreTrimmed` first selects ids with `t.trimmed_at >= now - restore_days*86400` that also have a stub (a stub the nightly purge has not yet removed still cannot be restored), then inserts with `RETURNING` over those ids. Mark-unread on an out-of-window id falls through to the plain ledger `read = 0` flip. (evidence: internal/store/itemstate.go:101-110, 157-217)
  - Fix: add the pre-selection `SELECT t.id FROM trimmed_items t JOIN trimmed_content c ON c.id = t.id WHERE t.id IN (:ids) AND t.trimmed_at >= :now - :restore_days*86400`; reword 1257: "Ledger ids trimmed more than `restore_days` ago (with or without a stub still on disk) cannot be restored..."

- [ ] **WRONG** design.md §4.8 (line 1039): what the `guid_duplicates` note counts
  - Doc says: added when "more than 5% of the guids in a document are empty or duplicated".
  - Code does: counts only repeated non-empty guids against items with a non-empty guid; empty guids never count. (evidence: internal/fetch/dedup.go:46-56, 105-109)
  - Fix: "If more than 5% of the items that carry a non-empty guid repeat an earlier guid in the same document, the fetch adds `guid_duplicates: k/n` (k repeats, n items with a guid). Empty guids are not counted."

- [ ] **WRONG** design.md §4.9 (line 1129): retention runs cover only enabled feeds
  - Doc says: "Apply retention now" runs over every feed; a `retention.default` change over the inheriting feeds.
  - Code does: both use `EnabledFeeds` (`WHERE enabled = 1`); a per-feed retention PATCH trims a disabled feed (priority trim allowed on disabled). (evidence: internal/sched/dispatcher.go:326-338, 415; internal/store/feeds.go:143-145)
  - Fix: "...a `retention` run of `trim_only` jobs over the enabled feeds that inherit the default. 'Apply retention now' does the same over every enabled feed. A per-feed retention PATCH trims that feed even when it is disabled."

- [ ] **WRONG** design.md §4.1 (line 795): "at most one active run per kind" holds only for manual
  - Code does: only a manual run is joined; a second import or retention run creates a new run and overwrites `s.runs[kind]`; the older still completes and publishes `run.done` but drops out of `Status()` (`GET /api/status`). (evidence: internal/sched/dispatcher.go:249-252, 307-312, 368)
  - Fix: "`runs` holds the latest run per kind. A second refresh-all joins the active manual run. A new import or retention run starts alongside an older one of the same kind (both finish and publish `run.done`, but only the newest shows in `/api/status`)."

- [ ] **WRONG** design.md §4.8 (lines 1079-1086, 1096): which feed columns the success commit writes
  - Doc says: `title`, `site_url`, `description`, custom_title clearing on every success; `unchanged`/`not_modified` run "the feed bookkeeping".
  - Code does: title, site_url, description, custom_title clearing and `rekey_pending = 0` only for outcome `ok`; `title`/`site_url` keep old values when the document's is empty (`CASE WHEN ? != '' THEN ? ELSE col END`); `etag`/`last_modified` written as `NULLIF(value,'')` only when `SetValidators`; `body_hash` only when non-empty. (evidence: internal/store/fetchcommit.go:242-267)
  - Fix: split into an `ok`-only part (`title = CASE WHEN :doc_title != '' THEN :doc_title ELSE title END, site_url = CASE WHEN :site != '' THEN :site ELSE site_url END, description = :desc, custom_title = ..., rekey_pending = 0`) and an every-success part (validators via `NULLIF`, `body_hash` when non-empty, the rest).

- [ ] **WRONG** design.md §4.3 (line 873): chunking threshold; no chunking during a rekey
  - Doc says: "Fetches of more than 500 new items ... are committed in chunks of 250."
  - Code does: counts all parsed items in the document, not new ones; never chunks when `RekeyPending`. (evidence: internal/store/fetchcommit.go:15-18, 86-96, 353)
  - Fix: "A fetch whose document has more than 500 items is committed in chunks of 250 (never while `rekey_pending` is set: the re-key runs in a single transaction)."

- [ ] **WRONG** design.md §4.1 and §4.3 (lines 810, 853-857, 874): where the commit gate lives
  - Doc says: `commitGate chan struct{}` (cap 1) shared by workers; the worker takes it around the commit.
  - Code does: the gate is `store.DB.gate`, taken inside the store: per chunk in `commitChunk` via `AcquireGate`, and in `gated`/`batch` for `CommitFetchError`, `CommitSkip`, `TrimOnly`, nightly purges, auto-read, filter retro-apply and `CheckpointPassive`. Workers never touch it. `SetFeedUAFallback` and `SaveFulltextIfURL` use plain `WithWrite` without the gate. (evidence: internal/store/db.go:37-46, 296-304; internal/store/fetchcommit.go:116-132, 616, 646; internal/store/maint.go:41-60, 127-132; internal/store/retention.go:116-118)
  - Fix: "`store.DB` owns a one-slot commit gate. Every fetch-path write (each commit chunk, the error and skip rows, `trim_only`) and every maintenance batch takes it inside the store." Drop the gate lines from the worker pseudo-code or annotate "(inside store)". Also adjust decision 2 (line 40) wording "Fetch workers take a chan".

- [ ] **WRONG** design.md §4.5 (line 944): which jobs a host deadline turns into a skip
  - Doc says: only "Host deadline active during a manual run" yields a `skipped` row.
  - Code does: import runs and plain per-feed priority refreshes also become `skip` jobs; a queued job that becomes held while pending is dropped silently if it is a plain scheduled fetch with nobody waiting, else a skip. A `full=1` refresh and the subscribe fetch (`forcesFetch`) ignore the deadline. (evidence: internal/sched/dispatcher.go:139-171, 434-439, 490-492)
  - Fix: "Host deadline active: a scheduled job is left due (or dropped from `pending`). A manual, import or plain per-feed refresh writes fetch_log `skipped` (note `skipped: host retry-after until <RFC3339 UTC>`), and the schedule is untouched. A `full=1` refresh and the subscribe fetch ignore the deadline."

- [ ] **WRONG** design.md §4.2 (line 814): what triggers a tick
  - Doc says: "A `wake` signal or a priority job also triggers a tick."
  - Code does: only the ticker and `wake` run `tick()`; a priority job is handled by `handlePriority` (fresh snapshot, head of `pending`) without a tick. (evidence: internal/sched/dispatcher.go:23-33, 377-444)
  - Fix: "A `wake` signal also triggers a tick. Priority jobs bypass the tick: they are snapshotted and put at the head of `pending`."

- [ ] **STALE** design.md §4.1 (lines 790-808): dispatcher state and channel lists
  - Code does: state is `flights` (queued and running; `started` marks running), plus `notBefore` (commit-failure backoff), `commitFails`, `running`, `stopping`, `lastRunID`; `pending` is not strictly FIFO (priority prepended). Extra channels `shutdownCh` (closed by `Stop`), `stopped`, `syncCh`. `manualCh` cap 8, `priorityCh` 32, `wake` 1. (evidence: internal/sched/sched.go:109-121, 164-210, 269-288)
  - Fix: update the block to these names and fields; add the missing channels with capacities.

- [ ] **STALE** design.md §4.2 (lines 817-821, 827-829): tick query and skip rules
  - Code does: also selects `enabled` and `ua_fallback`; also skips feeds in `notBefore` (last commit failed, in-memory backoff); fetch settings loaded each tick. (evidence: internal/store/feeds.go:87-90, 138-140; internal/sched/dispatcher.go:72-94)
  - Fix: add the two columns and the rule "A feed whose last commit failed is skipped until its in-memory `notBefore` (§4.6)."

- [ ] **STALE** design.md §4.5 (line 922) and §4.3 (line 873): the stale-URL check also covers errors
  - Doc says: "Every attempt appends a fetch_log row."
  - Code does: `CommitFetchError` updates `WHERE id = ? AND url = ?`; if the URL was edited mid-fetch it writes nothing (no failure count, no log row); a stale `CommitFetch` also writes no log row. (evidence: internal/store/fetchcommit.go:185-192, 618-631)
  - Fix: add "except when the feed's URL was edited while the fetch ran: then neither the success nor the error path writes bookkeeping or a log row."

- [ ] **STALE** design.md §4.5 (line 926): when validators are dropped
  - Doc says: when `Expires: 0`.
  - Code does: whenever `Expires` is present but not a valid HTTP date ("0", "-1", garbage); a parseable past date does not drop them. (evidence: internal/fetch/fetch.go:269-275)
  - Fix: "both dropped when `Expires` is present but not a valid HTTP date (such as `0`)".

- [ ] **STALE** design.md §4.5 (lines 931, 936): empty body and Cloudflare conditions
  - Code does: whitespace-only body counts as empty; Cloudflare detected by a `Content-Type` containing `html`, not the body. (evidence: internal/fetch/fetch.go:242-244, 260-262)
  - Fix: "empty or whitespace-only body" and "...and an HTML `Content-Type`".

- [ ] **STALE** design.md §4.4 (lines 879, 881): SSRF ranges and proxy
  - Code does: also blocks `0.0.0[.]0/8`, `192.0.0[.]0/24`, `198.18.0[.]0/15`, `240.0.0[.]0/4`, `64:ff9b:1::/48`, Teredo `2001::/32`, `100::/64`; the transport sets no `Proxy`. (evidence: internal/fetch/ssrf.go:16-50; internal/fetch/client.go:89-98)
  - Fix: list the extra ranges; add "No `Proxy` (environment proxies would bypass the dial guard)."

- [ ] **STALE** design.md §4.4 (lines 891-896): charset decoding
  - Doc says: decode with `charset.NewReaderLabel`.
  - Code does: `charset.Lookup` plus `transform.Bytes`; UTF-16/32 labels without a BOM ignored; a single-byte label on a body that is valid multi-byte UTF-8 is decoded as UTF-8. (evidence: internal/fetch/charset.go:37-41, 91-113, 120-139)
  - Fix: describe these rules and the `Lookup`/`transform` decode.

- [ ] **STALE** design.md §4.6 (line 968): which Cache-Control directive wins
  - Code does: `s-maxage` wins over `max-age`; an unparseable `Expires` contributes nothing. (evidence: internal/fetch/backoff.go:97-107)
  - Fix: "`Cache-Control s-maxage` (else `max-age`) - `Age`".

- [ ] **STALE** design.md §4.8 (lines 1036, 1038): uid fallbacks
  - Code does: no link gives `g:h(guid|n)`; same guid and same link gives `g:h(guid|link|k)` with k bumped until free; `link_title` with no link falls back to the `h:` rule; separators `0x1f`. (evidence: internal/fetch/dedup.go:62-91)
  - Fix: correct both rules.

- [ ] **STALE** design.md §4.8 (lines 1062-1064, 1070): rekey matching and INSERT columns
  - Code does: the URL must also be unique among the new items (`newByURL == 1`); rekey only for outcome `ok` in a single-chunk commit; INSERT also writes `muted_was_read`. (evidence: internal/store/fetchcommit.go:352-358, 370-373, 519-561)
  - Fix: add "and no other new item in the document has that URL"; add `muted_was_read` to the column list.

- [ ] **STALE** design.md §4.9 (line 1125): which feeds refuse a refresh
  - Doc says: "A `gone` feed must be re-enabled first."
  - Code does: any disabled feed gets `409 disabled`. (evidence: internal/sched/dispatcher.go:415-417; internal/api/feedadmin.go:567-568)
  - Fix: "A disabled feed (including `gone`) answers 409 `disabled` and must be re-enabled first."

- [ ] **STALE** design.md §4.10 (lines 1149-1153): shutdown steps
  - Code does: `srv.Shutdown` over 10 s is followed by `srv.Close()`; the `Stopped()` wait is bounded at 15 s (logs "scheduler did not drain in time"); the TRUNCATE checkpoint runs inside `db.Close()` on the writer after the reader pool closes, 5 s timeout; `uiAPI.Close` and `imgcache.Close` run as defers before `db.Close`; the snapshot tmp is removed immediately on a failed/cancelled VACUUM and again at the next run's start. (evidence: cmd/kipple/main.go:155-159, 196, 233-254; internal/store/db.go:311-335; internal/store/maint.go:179-189)
  - Fix: update steps 3-7 accordingly.

- [ ] **STALE** design.md §4.10 (lines 1136-1138): SSE details
  - Code does: ring capped at 500 events and 1 MiB payload; replay sends `resync` when the ring does not cover `Last-Event-ID`, when 64+ events would be replayed, or the id is ahead of the hub; event ids seeded from the clock in µs (monotonic across restarts); cursor also accepted as `?last_event_id=` (header wins); stream opens with `retry: 3000`; every heartbeat re-checks the session and closes on revoke; each write has a 10 s deadline. (evidence: internal/events/hub.go:13-22, 52-60, 103-134; internal/api/sse.go:14-80; internal/api/api.go:44)
  - Fix: add these points (and keep §7.3 consistent).

- [ ] **STALE** design.md §5 (lines 1209-1211): `trimmed_unread_since` missing from the SQL
  - Code does: also sets `trimmed_unread_since = COALESCE(trimmed_unread_since, :now)`, guarded by `AND EXISTS (... i.read = 0 AND i.id < :first_new_id)`; the trim returns early when `trim_set` is empty. (evidence: internal/store/retention.go:59-65, 86-91)
  - Fix: replace the statement with the code's version.

- [ ] **STALE** design.md §5 (line 1227): what the future-date clamp touches
  - Code does: only `sort_at` is clamped (`min(published, crawl+86400)`); `published_at` keeps the bogus date. (evidence: internal/store/fetchcommit.go:387-392)
  - Fix: "A bogus future date is clamped to crawl + 24 h in `sort_at` (the ranking key). `published_at` keeps the feed's value."

- [ ] **STALE** design.md schema comment (line 531, contradicts §4.3 line 869): fetch_log note vocabulary
  - Doc says: line 531 lists `fulltext: <ok>/<tried>`; line 869 says there is no such per-run note any more.
  - Code does: writes `fulltext_picked: n`, `fulltext_deferred: m`, `fulltext: skipped (...)`, `filters: muted k, marked_read k, starred k`, `skipped_malformed_items: k/n`, `redirect_target_owned_by_feed <id>`, `redirect_migrated: a -> b`. (evidence: internal/sched/fulltext.go:255, 265, 318-321; internal/store/fetchcommit.go:231-235, 579, 595; internal/fetch/parse.go:146)
  - Fix: update the note list. Note: line 531 is inside the "exactly 0001_init.sql" block, so put the current list in prose after the block rather than editing the block.

- [ ] **MISSING** design.md §5 Ledger writes elsewhere (lines 1259-1267): three writers not listed
  - Code does: nightly auto-read (`RunAutoRead`) marks matching ledger rows read in gated batches; "Mark this fetch read" (guid churn) flips ledger rows in that fetch's id range; web mark-all skips the ledger for starred and muted views and any filtered or search scope. (evidence: internal/store/autoread.go:260-262, 303-325; internal/store/feedadmin.go:323; internal/store/uiitems.go:550-558)
  - Fix: add bullets for auto-read and mark-fetch-read; change the mark-all bullet to "skipped for the starred and muted scopes and for any filtered or search scope (web); the Reader API skips it only for starred."

- [ ] **MISSING** design.md §4.3 (lines 864-871): full-text details that shipped
  - Code does: `pickFulltext` rereads the current mode (`FeedFulltextNow`); skips with note `fulltext: skipped (re-key pending)` when a rekey is pending and `fulltext: skipped (could not check existing items)` when the lookup fails; skips URL-less candidates; `queueFulltext` rechecks the mode; each queued item is added to the Reader pending set (`MarkFulltextPending`) before the push and cleared on push failure or job end (`ClearFulltextPending`), which drives the Reader hold (§6.5); the queue dedupes by item id; `fulltext.ready` events carry `"source":"ingest"`, coalesced over 300 ms, max 500 ids per event. A stale commit or mode switched off drops candidates silently (contrary to "never silent"). (evidence: internal/sched/fulltext.go:160, 197-229, 239-324, 331-384; internal/sched/worker.go:99)
  - Fix: add these points; note that a stale commit and a mode switched off since the pick are not logged.

- [ ] **MISSING** design.md §4.8 / §4.4: parse-time behavior
  - Code does: malformed entries dropped with note `skipped_malformed_items: k/n`; an enclosure-only entry gets its first media URL as guid and a title from the file name; note `initial_read: k` (keep 0) when the initial-read window marks items read; `feedburner:origLink` wins for `url`. (evidence: internal/fetch/parse.go:121-147, 156-224, 288-297; internal/store/fetchcommit.go:228-230)
  - Fix: add these to §4.8 (or cross-reference §13 item 9).

- [ ] **MISSING** design.md §4.9 (lines 1126, 1129): subscribe and PATCH details
  - Code does: web subscribe fetch is `Full: true`, ignores host Retry-After, discovery has a 10 s timeout; a URL change or re-enable via PATCH submits a `Full` priority fetch (falls back to `Wake`); PATCH of `user_agent` or URL resets `ua_fallback`; changing the feed's host clears `http_auth` unless set in the same request. (evidence: internal/api/feedadmin.go:209-217, 257-264, 451-458; internal/store/feedadmin.go:167-171, 201-211)
  - Fix: add these points.


### design.md §6 Google Reader API (lines 1286-1589)

- [ ] **WRONG** design.md §6.9 (line 1555): unsubscribing the archive feed is not always a real delete
  - Doc says: "1. If the feed is the archive feed, `DELETE` it (a real delete)."
  - Code does: the archive feed is handled last, after the other feeds in the same request have moved their starred items into it. It is deleted only if it holds no starred items. Otherwise `removeFeed` returns `ErrArchiveHasStarred`, the feed is kept and logged at INFO, and the reply is still `OK`. The Reader API cannot force the delete. (evidence: internal/store/subs.go:324-364, 374-388; internal/greader/h_subs.go:337-346). Also contradicts §7 line 1635, where the web UI answers 409 `archive_has_starred` for the same case.
  - Fix: replace step 1 with "The archive feed, if listed, is processed last (after the other `s` feeds have moved their starred items into it). It is deleted only when it holds no starred items; otherwise it is kept, an INFO line is logged, and the reply is still `OK` (the Reader API has no `delete_starred`)."

- [ ] **WRONG** design.md §6.9 (line 1547) and decision 33 (lines 181-183): `greader.subscribe_fetch_now` does nothing
  - Doc says: with the setting true, step 3 runs guarded discovery and a priority first fetch, waiting up to 8 s.
  - Code does: nothing in greader or store reads the setting; `store.Subscribe` never does outbound HTTP (evidence: internal/store/subs.go:145-205; internal/greader/h_subs.go:237-251; `subscribe_fetch_now` appears only at internal/api/settingsmeta.go:341 and internal/store/uibootstrap.go:46).
  - Fix: step 5: "`greader.subscribe_fetch_now` is stored and exposed (hidden) but not implemented: every Reader subscribe path behaves as the default." (or implement it). Mirror in decision 33.

- [ ] **WRONG** design.md §6.2 (line 1311): body caps, and the 413 and 400 answers
  - Doc says: every other POST body is read with a 4 MiB cap.
  - Code does: 4 MiB (`maxBody`) only when the `Authorization` header already authenticated the request; ClientLogin and any POST authenticating by T-in-body are capped at 64 KiB (`maxLoginBody`). Over the cap answers `413`, never parsed truncated. More than 20000 pairs (`maxPairs`) in body or query answers `400`. `subscription/import` raw OPML body: same 4 MiB cap and 413. (evidence: internal/greader/form.go:14-23, 216-249; internal/greader/api.go:248-250, 273-280, 302-312; internal/greader/hardening_test.go:22-95)
  - Fix: "The body is read with a 4 MiB cap when the Authorization header authenticated the request, and a 64 KiB cap for ClientLogin and for any POST that must authenticate with T. A body over its cap answers `413`; the truncated text is never parsed. More than 20000 pairs in the body or the query answers `400`." Add 400/405/413 to the §6.1 status policy.

- [ ] **WRONG** design.md §6.9 (line 1572): `subscription/import` does not accept T, and bad OPML is a 400
  - Doc says: "Parse the raw OPML body (no T needed; NNW requires exactly 200)" and "Reply `200 OK`."
  - Code does: the route is `raw`, so a valid `Authorization` header is mandatory; a T-only POST is 401 (internal/greader/api.go:268-271; subs_test.go:316-317). Unparseable OPML answers `400 text/plain "Bad OPML"` with a WARN (h_subs.go:360-364; subs_test.go:323-324). `wake` is sent only when `FeedsAdded > 0` (h_subs.go:371-373).
  - Fix: "1. Requires the Authorization header (T is not read; the body is not a form). ... Unparseable OPML answers `400 "Bad OPML"` and logs a WARN. 4. Send `wake` when any feed was added."

- [ ] **WRONG** design.md §6.7 (lines 1487-1488): edit-tag un-mutes muted items
  - Doc says: `r=read`/`a=kept-unread` runs `... WHERE ... AND read=1`; `a=starred` runs `... WHERE ... AND starred=0`.
  - Code does: unread: `UPDATE items SET read=0, read_at=NULL, muted_by=NULL, muted_was_read=NULL WHERE id IN (...) AND (read=1 OR muted_by IS NOT NULL)`. Star: `UPDATE items SET starred=1, starred_at=:now, muted_by=NULL, muted_was_read=NULL WHERE id IN (...) AND (starred=0 OR muted_by IS NOT NULL)`; a starred item stays read. (evidence: internal/store/itemstate.go:92-94, 133-135; internal/greader/filters_test.go:75-86)
  - Fix: update both SQL cells to these statements and add: "The Reader API has no concept of filters: a muted item is an ordinary read item. `r=read` and `a=starred` are the un-mute (star beats mute)."

- [ ] **WRONG** design.md §6.7 (line 1494): stats from edit-tag
  - Doc says: "Stats rules (§8) run inside the same transaction through `Recorder.Record(tx, ...)`."
  - Code does: only `a=starred`/`r=starred` write stats, through `Stats.RecordStars(tx, kind, family, res.Changed)`, one row per changed id (restores included). Read/unread edits write no stats; `stats.api_single_read_is_open` is never read by greader. (evidence: internal/greader/h_edit.go:92-101; internal/stats/stats.go:52-57, 147). Contradicts §8 line 1951 (inferred single reads behind that setting).
  - Fix: "Star and unstar changes record one stats row per changed id through `Recorder.RecordStars(tx, ...)` in the same transaction. Read changes record nothing (single-read inference, §8, is not implemented; `stats.api_single_read_is_open` has no effect)." Fix §8 to match (see §8 findings).

- [ ] **WRONG** design.md §6.1 (line 1302): what the request log records
  - Doc says: the log records method, path, query, ...; `KIPPLE_LOG_GREADER_FORMS=1` adds form keys and value counts. The zero-ids WARN covers `edit-tag`, `mark-all-as-read` and `stream/items/contents`.
  - Code does: DEBUG level only. Always logs method, path, UA, family, Content-Type, status, duration and the query and form KEYS (no query values, never the Authorization header). `KIPPLE_LOG_GREADER_FORMS` adds values: per key a count plus the first 3 values truncated to 200 bytes, with `passwd`, `t`, `auth`, `sid`, `lsid`, `authorization` replaced by `[redacted]`. `warnNoIDs` is called only by `edit-tag` and `stream/items/contents`. (evidence: internal/greader/log.go:41-72, 84-114, 118-124; h_edit.go:66; h_streams.go:97)
  - Fix: "The request log (DEBUG level) records method, path, UA, client family, Content-Type, status, duration and the query and form keys. With `KIPPLE_LOG_GREADER_FORMS=1` it also records each key's value count and first 3 values (truncated to 200 bytes), with `Passwd`, `T`, `auth`, `SID`, `LSID` and `Authorization` redacted. `edit-tag` and `stream/items/contents` log a WARN with UA and Content-Type when they parsed zero ids from a non-empty body."

- [ ] **WRONG** design.md §6.2 (line 1324): the repair does not always glue empty parts
  - Doc says: following `&`-parts are glued "in their original positions (empty parts included)".
  - Code does: if the label value as sent contains a valid `%XX` escape (it was form-encoded), an empty part ends the run (`s=user%2F-%2Flabel%2FMy+Folder&&T=tok` keeps `My Folder`, T survives). Raw names (`R&`, `A&&B`) still glue empty parts. A key containing `+` is also never a parameter key. (evidence: internal/greader/form.go:93-98, 151; formrepair_test.go:9-31)
  - Fix: add "except that when the label value contains a valid `%XX` escape (it was form-encoded), an empty part is a stray `&` and ends the run". Change "no space" to "no space or `+`".

- [ ] **WRONG** design.md §6.1 (line 1300) and §6.9 (line 1584): icon endpoint headers and 404s
  - Doc says: every response carries `Cache-Control: private, no-cache`; the icon endpoint "serves `feed_icons` bytes and nothing else".
  - Code does: icons are sent with `Cache-Control: public, max-age=86400`, `X-Content-Type-Options: nosniff`, `Content-Security-Policy: default-src 'none'; sandbox`. Only raster types are served (jpeg, png, gif, webp, avif, x-icon, vnd.microsoft.icon); SVG/HTML/other, wrong hash, malformed path, or `icon_urls` off answer 404. (evidence: internal/greader/h_subs.go:93-136; hardening_test.go:97-118)
  - Fix: §6.1: "Every response except `/icon/...` carries ...". §6.9: "Serves the stored bytes only for raster image types (else 404), with `Cache-Control: public, max-age=86400`, `nosniff` and a sandbox CSP; 404 when the setting is off or the id/hash does not match."

- [ ] **WRONG** design.md §6.9 (line 1545): subscribe never allows a private-address literal
  - Doc says: validate the URL "(http/https, a host, not an SSRF-literal IP unless allowed)".
  - Code does: Reader subscribe calls `ValidateFeedURL(raw, false)`; a literal blocked IP is always refused ("address not allowed"). (evidence: internal/store/subs.go:151, 213-223)
  - Fix: "...not a literal blocked IP (always refused on the Reader API; per-feed `allow_private_net` is set only from the web UI)".

- [ ] **WRONG** design.md §6.9 (line 1549): invalid quickadd reply also carries `query`
  - Doc says: `200 {"numResults":0,"error":"<msg>"}`.
  - Code does: `200 {"numResults":0,"query":<q>,"error":<reason>}`; reason is "not an absolute http(s) URL" or "address not allowed". (evidence: internal/greader/h_subs.go:242-244; internal/store/subs.go:216, 220)
  - Fix: `200 {"numResults":0,"query":url,"error":"<msg>"}`.

- [ ] **STALE** design.md §6.1 (line 1296): dispatch mechanism
  - Doc says: a `switch` on method plus cleaned path, `strings.HasPrefix` for `/reader/api/0/stream/contents/`.
  - Code does: a route table `map[string]route` with flags `post`, `raw`, `repair`, `prefix`; `lookup` tries exact then prefix routes; probes, icon and ClientLogin are switched before the table. (evidence: internal/greader/api.go:107-114, 237-297, 314-324; h_streams.go:18)
  - Fix: describe the route table and its flags.

- [ ] **STALE** design.md §6.3 (lines 1331-1333): success memo
  - Doc says: memo is `HMAC(secret, "login|"+Passwd)`, "cleared whenever either password changes".
  - Code does: kept per kind (`api`/`web`) as `HMAC(secret, "login|"+kind+"|"+phc+"|"+pw)`; the stored hash is in the MAC so a password change invalidates it without clearing; `SetSecret` drops all memos. Empty `Passwd` fails at once without hashing. (evidence: internal/auth/auth.go:114-118, 124-132, 145-178)
  - Fix: "If `hmac.Equal(HMAC(secret, "login|"+kind+"|"+hash+"|"+Passwd), memo[kind])`... The hash is part of the MAC, so a changed password never matches an old memo; a changed secret drops every memo." Also update decision 10 (line 71), which says the memo "is cleared whenever the password changes".

- [ ] **STALE** design.md §6.3 (lines 1341, 1343): token cache and comparison
  - Doc says: token "cached in an `atomic.Pointer` and recomputed when the API password changes"; compared with `hmac.Equal`.
  - Code does: account snapshot (token included) cached with a 5 s TTL (`acctTTL`); `InvalidateAccount` (wired to `OnAPIPasswordChange` in main) drops it at once; a CLI password change takes effect within 5 s. Comparison is `subtle.ConstantTimeCompare`. (evidence: internal/greader/api.go:351-397, 399-401, 562-569; cmd/kipple/main.go:194)
  - Fix: "...cached in an account snapshot (`atomic.Pointer`, 5 s TTL) and dropped at once by `InvalidateAccount` when the API password changes in the UI (within 5 s for the CLI). Compared in constant time."

- [ ] **STALE** design.md §6.3 (line 1350): client family and request context
  - Doc says: family goes into the request context for stats.
  - Code does: it is a field on the per-request `call`, passed explicitly to `RecordStars` and used as the SSE `source`. (evidence: internal/greader/api.go:124, 234; h_edit.go:98, 120)
  - Fix: "The family is kept with the request and passed to the stats recorder and as the SSE `source`."

- [ ] **STALE** design.md §6.6 (lines 1435-1445): contents SQL
  - Doc says: selects `i.fulltext_mode` and `f.fulltext AS feed_fulltext`; no hold predicate.
  - Code does: one computed column `FulltextModeSQL("i.fulltext_mode","f.fulltext", fetch.fulltext_all)` (`COALESCE(i.fulltext_mode, 1)` when the switch is on, else `COALESCE(i.fulltext_mode, f.fulltext, 0)`), and appends `AND NOT <HeldSQL>` when the hold is active. (evidence: internal/store/items.go:191-220; internal/store/fulltextmode.go:43-48)
  - Fix: replace the two columns with the effective-mode expression and add `[AND NOT <HeldSQL(i.)>]` to the WHERE.

- [ ] **STALE** design.md §6.5 (line 1421): "snapshotted the mode" example
  - Doc says: an item the pool never accepted includes "a fetch that snapshotted the mode before the setting changed".
  - Code does: `pickFulltext` and `queueFulltext` re-read the current mode (`FeedFulltextNow`), so that case no longer occurs; muted items are never queued, so never held. (evidence: internal/sched/fulltext.go:243-251, 281-295, 337-341)
  - Fix: replace the example with "(..., or full-text turned on for the feed after its fetch was picked)"; add "muted items are never queued, so never held".

- [ ] **STALE** design.md §6.2 (line 1324) and §12 review table (line 2367): disable-tag lookup order
  - Doc says: disable-tag "tries the merged raw name, its decoded forms..."; line 2367 says it "falls back to the raw body from `s=` to `&T=` or the end".
  - Code does: tries the decoded merged name (lenient unescape), then the raw merged name, then the raw name through `PathUnescape`; only when the raw name ends in `&` does it try the trimmed name. No raw-body fallback; the repair is in the parser. (evidence: internal/greader/h_subs.go:159-182, 437-450; form.go:91-106)
  - Fix: §6.2: "tries the merged name decoded, then raw, then raw through PathUnescape, and...". Line 2367: "...disable-tag glues unencoded name tails in the parser (§6.2)".

- [ ] **STALE** design.md §6.8 (line 1510) and §3 (line 780): absent-`ts` cutoff
  - Doc says: absent `ts` = committed `max(id)` (§3: `SELECT max(id) FROM items`).
  - Code does: `max(max(items.id), max(trimmed_items.id))` on the reader pool; `ts` = 0, non-digit or overflowing also falls back. (evidence: internal/store/itemstate.go:275-280; internal/greader/h_edit.go:150-157, 184-190)
  - Fix: "...the committed max id over `items` and `trimmed_items` (reader pool); also used when `ts` is 0 or unparseable". Mirror in §3 line 780.

- [ ] **MISSING** design.md §6.1 (lines 1293-1301): 404, 405, 400 and 413
  - Code does: a non-Reader path under `/api/greader.php` answers 404 (no Reader Cache-Control) and never reaches the web mux; GET to a POST-only route answers `405` with `Allow: POST`; too many pairs 400; oversize body 413. (evidence: internal/greader/api.go:204-228, 291-295, 302-312; hardening_test.go:121-129; front_test.go:87-92)
  - Fix: add to §6.1: "Other paths under the prefix: `404`, never the web mux. A write route (`edit-tag`, `mark-all-as-read`, `subscription/quickadd|edit|import`, `rename-tag`, `disable-tag`) answers `405` with `Allow: POST` to other methods." Add 400/413.

- [ ] **MISSING** design.md §6.3 (lines 1329-1345): ClientLogin headers, busy verifier, API disabled
  - Code does: ClientLogin's 401 carries `Google-Bad-Token: true` and `X-Reader-Google-Bad-Token: true`; a busy verifier (5 s wait expired or ctx cancelled) answers 401 but records no failure and adds no delay; with no API password every non-probe route answers 401 `Unauthorized!`; GET authenticates only by header; cookies (`kipple_session`, `kipple_device`) are never credentials. (evidence: internal/greader/api.go:268-271, 405-418, 443-473; devicecookie_test.go:12-20)
  - Fix: add these five points to §6.3.

- [ ] **MISSING** design.md §6.7 (lines 1482-1495): id cap and SSE details
  - Code does: only the first 10000 `i=` values (`maxEditIDs`) are processed, the rest ignored, still 200; no parsed id or no recognized op answers OK without a transaction; `items.state` carries `restored` ids; more changed ids than `events.MaxStateIDs` publish `resync` instead. (evidence: internal/greader/h_edit.go:56-71, 110-131, 136)
  - Fix: add those points.

- [ ] **MISSING** design.md §6.8 (lines 1497-1518): `resync`, `kept-unread`, empty `s`, `it`/`xt`
  - Code does: publishes SSE `resync` when any item changed; `s=.../kept-unread` is a no-op; empty `s` = reading-list; `it`/`xt` ignored. (evidence: internal/greader/h_edit.go:174-205; stream.go:16-18)
  - Fix: add "`s` empty = reading-list; `kept-unread` is a no-op; publishes `resync` when rows changed; `it`/`xt` ignored."

- [ ] **MISSING** design.md §6.9 (line 1582): unread-count response shape
  - Doc says: `{"max":<total>,"unreadcounts":[{"id":"feed/12",...},...]}`.
  - Code does: `unreadcounts` holds one `user/-/state/com.google/reading-list` entry (total, newest), then one `user/-/label/<folder>` entry per folder with unread items, then per-feed entries; SQL orders by folder position/name, feed position, feed id, and ANDs `NOT HeldSQL`. (evidence: internal/greader/h_subs.go:474-511; internal/store/subs.go:490-515)
  - Fix: document the three entry kinds and their order, with an example.

- [ ] **MISSING** design.md §6.9 (lines 1551-1564): subscription/edit details
  - Code does: `ac=subscribe` skips invalid-URL `s` values (still OK); `ac=edit` with several `s` and as many `t` applies `t[i]` to feed `i`, else `t[0]` to all; `r=` is only checked for being a label (any label moves the feed to folder 1), never looked up; unknown `ac` is OK. (evidence: internal/greader/h_subs.go:263-349)
  - Fix: add these points; in §6.2 line 1318 drop `r=` from the label-lookup list or note it is not resolved.

- [ ] **MISSING** design.md §6.9 (line 1536): `iconUrl` also needs `KIPPLE_PUBLIC_URL`
  - Code does: non-empty only when `greader.icon_urls` is on, `KIPPLE_PUBLIC_URL` is set and the feed has an icon; trailing `/` trimmed. (evidence: internal/greader/h_subs.go:62-72)
  - Fix: "...when the setting is on, `KIPPLE_PUBLIC_URL` is set, and an icon exists, otherwise `""`."

- [ ] **MISSING** design.md §6.2 (lines 1309-1312): multipart scope and empty parts
  - Code does: any POST with `multipart/form-data` and a boundary is read as multipart (not only ClientLogin), file parts skipped, 1 MiB per field; without a boundary falls back to urlencoded; empty `&&` parts dropped. (evidence: internal/greader/form.go:84-88, 237-242, 251-270)
  - Fix: "`multipart/form-data` with a boundary (Readrops ClientLogin, any endpoint) goes through the multipart reader; file parts skipped, 1 MiB per field", and in step 2 "empty parts are skipped".

- [ ] **MISSING** design.md §6.4 / §6.5 (lines 1363-1370, 1389-1399): stream and filter extras
  - Code does: `feed/<url>` in a request path gets its collapsed `http:/`/`https:/` restored before lookup; `it=.../kept-unread` means `read = 0`, `xt=.../kept-unread` means `read = 1`; with `ot`, `nt` is ANDed into both legs; `stream/items/contents` applies the 1000 cap to parsed ids, not raw `i=`. (evidence: internal/greader/stream.go:52-79, 81-104; internal/store/items.go:105-130; h_streams.go:84-96)
  - Fix: add the scheme restore to the `feed/<url>` row; add `kept-unread` to the `it`/`xt` sentence; add `[AND id < :nt_us]` to both legs of the `ot` SQL; §6.6 line 1432: "parsed ids beyond the first 1000".

- [ ] **MISSING** design.md §6.9 (line 1578): export headers
  - Code does: `Content-Type: text/x-opml; charset=utf-8` and `Content-Disposition: attachment; filename="kipple.opml"`. (evidence: internal/greader/h_subs.go:384-395)
  - Fix: append these two headers.


### design.md §7 intro, §7.1, §7.1a-d, §7.2, §7.3 (lines 1590-1781)

Verified as matching (not listed): every doc route is registered (apart from phase-4 stats); filter limits, Filter JSON and apply/delete batching; device cap 50 / evict after 30 days / purge after 400 days / 8 KB / cookie attributes / `client.*` key list and ranges; the `ui.*` device-scope list; auto-read windows, marks, 25 ms pause, 500-id batches, confirm/expect_total; saved-search limits (100 / 60 / 300 / 999 / 200 ms / 2 s / Cc+U+2028/9); SSE heartbeat (15 s, no id) and watchdog (45 s).

- [ ] **WRONG** design.md §7.3 (line 1780): the client does not fetch `new_item_ids`
  - Doc says: "For `new_item_ids` inside the current view it calls `GET /api/items?ids=...`."
  - Code does: no web code requests `/api/items?ids=`. `fetch.done` only adds counts and ids to `pendingByFeed` / `pendingIds`, driving an "n new" pill; ListPane uses the ids only to discount items already loaded. Lists are refetched only on `resync`. (evidence: web/src/api/events.ts:95-104, 275-279; web/src/screens/ListPane.tsx:158, 655-660)
  - Fix: "For `fetch.done` it keeps a per-feed pending count and the `new_item_ids` (capped) and shows an 'n new' pill for the current scope, not counting ids already loaded. Lists are not refetched by events except on `resync`. `GET /api/items?ids=` stays available for SSE catch-up but the web client does not call it."

- [ ] **WRONG** design.md §7.3 (line 1773): `feed.changed` payload and triggers
  - Doc says: `{feed_id}`, "on migration, disable, rename, move, archive or delete".
  - Code does: Reader `rename-tag` and `disable-tag` publish `feed.changed` with an empty `{}` (internal/greader/h_subs.go:421, 460). It also fires on web subscribe (internal/api/feedadmin.go:256), any notifying PATCH (feedadmin.go:460), archive purge (feedadmin.go:512), each feed moved by a folder delete (feedadmin.go:750-752), each feed whose position changed in `POST /api/reorder` (feedadmin.go:865-867), Reader subscribe/edit (h_subs.go:259, 353, 375), scheduler migration or gone (internal/sched/dispatcher.go:281-283).
  - Fix: "`{feed_id?}`: a feed was created, edited (any PATCH that changes it, including position or folder), reordered, moved by a folder delete, migrated, disabled, archived/purged or deleted. `feed_id` (string) is absent (`{}`) when the Reader API renamed or deleted a label, where several feeds may have changed."

- [ ] **WRONG** design.md §7.1d (line 1746; also §7.3 line 1770 and line 1748): not every saved-search change publishes `saved_searches.changed`
  - Doc says: "Every change publishes `saved_searches.changed` `{}`".
  - Code does: deleting a feed or folder drops the `scope` of saved searches naming it in the same transaction and publishes no `saved_searches.changed`; only `feed.changed` / `folder.changed` go out, and the web client refetches saved searches on those. (evidence: internal/store/favorites.go:117-122; internal/store/savedsearch.go:262-296; internal/api/feedadmin.go:492-499, 750-753; web/src/api/events.ts:261-270)
  - Fix: add "A feed or folder deletion that drops scopes publishes only its `feed.changed` / `folder.changed`; clients refetch saved searches on those events too." (or make the code publish it).

- [ ] **WRONG** design.md §7 (line 1599): the same-origin rule also covers the login
  - Doc says: applies to "every cookie-authenticated request whose method is not GET/HEAD".
  - Code does: `POST /api/auth/login` (no cookie) runs the full `sameOrigin` check (rules 1-3, including `X-Kipple-Client`) first and answers 403 `origin`. (evidence: internal/api/login.go:17-20; internal/api/api.go:315-331)
  - Fix: "...every cookie-authenticated request whose method is not GET/HEAD, **and `POST /api/auth/login`** (all three rules, so the login form must send `X-Kipple-Client`), plus the GET downloads..."

- [ ] **WRONG** design.md §7.1c (line 1696): make-default on an unsaved device does not 404
  - Doc says: an unsaved device's "writes answer 404".
  - Code does: `PATCH /api/device`, `PUT /api/device/name` and `copy-from` return 404; `POST /api/device/make-default` returns 200 and rewrites `ui.device_defaults` with its current value; `DELETE /api/devices/{id}` of another device works. (evidence: internal/api/devices.go:410-412, 594-628, 632-653)
  - Fix: "writes to the device itself (`PATCH /api/device`, `PUT /api/device/name`, `copy-from`) answer 404; `make-default` is a no-op 200."

- [ ] **STALE** design.md §7.1 (line 1642): `/api/status` `runs` also carries the auto-read run
  - Code does: also appends the active auto-read catch-up run (internal/api/feeds.go:31-41), as §7.1d line 1731 already says.
  - Fix: "...plus, while active, the filter apply run and the auto-read catch-up run (as in bootstrap)".

- [ ] **STALE** design.md §7.3 (lines 1766-1767): run event rows list only the filter-apply extras
  - Code does: auto-read `run.progress` also carries `changed`; its `run.done` carries `kind:"auto_read", changed, scanned, ledger, new_items:0, errors, error:"auto_read_failed"`; filter apply's error value is `"apply_failed"`; the scheduler publishes `run.done` with no `run.start` when a run has zero feeds. (evidence: internal/api/autoread.go:248-249, 264-268; internal/api/filters.go:556-560; internal/sched/dispatcher.go:363-366)
  - Fix: `run.progress`: "(a filter apply or auto-read run adds `changed`)". `run.done`: "(a filter apply adds `kind, filter_id, changed, scanned`; an auto-read run adds `kind, changed, scanned, ledger`; both add `error` (`apply_failed` / `auto_read_failed`) when they failed). A run with nothing to do sends `run.done` without a `run.start`."

- [ ] **STALE** design.md §7.1 (line 1658): stats summary route not mounted
  - Code does: not registered; the `/api/` catch-all answers 404 `not_found` (internal/api/api.go:195-263).
  - Fix: "`GET /api/stats/summary` (phase 4, not mounted yet)".

- [ ] **STALE** design.md §7.1a (line 1691): garbled favorites sentence
  - Doc says: "...so a legacy spelling never outlives its folder, and no repeated `(t, id)` pair; anything else answers 400..."
  - Code does: on write a repeat or malformed entry is 400 (internal/api/settingsmeta.go:399-426); on read and on delete stored lists are normalised silently (internal/store/favorites.go:40-54, 93-113).
  - Fix: "The PATCH rejects any other shape, and a repeated `(t, id)`, with 400 `invalid_settings` naming the key. Stored lists are normalised when read (`MergedSettings`) and when a deleted folder or feed is dropped from them: ids are canonicalised, and malformed or repeated entries are dropped silently."

- [ ] **STALE** design.md §7.1 (line 1635): typo, and `delete_starred` values
  - Doc says: "...pass `?delete_starred=1` to really delete The confirm dialog..."
  - Fix: add the missing period; note that any other `delete_starred` value is `400 bad_request` (internal/api/feedadmin.go:477-482).

- [ ] **MISSING** design.md §7.1 (line 1634): PATCH /api/feeds accepts `url`
  - Code does: `url` is accepted; other keys are `400 unknown_field`; archive feed is `409 archive_feed`. (evidence: internal/api/feedadmin.go:41-61, 287-288)
  - Fix: add `url` to the key list, plus "unknown keys are `400 {"error":"unknown_field"}`; the archive feed is `409 archive_feed`".

- [ ] **MISSING** design.md §7.1 (line 1626): mark-read scope rules
  - Code does: a `scope` request requires `read:true` (`read:false` with a scope is 400; mark-unread is by id only); `max_id` optional (falls back to `MaxCommittedID`); exactly one of `feed_id`, `folder_id`, `all`; `view` optional; `scope.q` at most 1000 bytes. (evidence: internal/api/items.go:364-366, 377-443)
  - Fix: add "Scope marks are `read:true` only. `max_id` is optional (default: the current MaxCommittedID, which a client should not rely on). Exactly one of `feed_id`, `folder_id`, `all`. `q` <= 1000 bytes."

- [ ] **MISSING** design.md §7.1 (line 1624): `via:"key"` is accepted
  - Code does: accepts `""`, `tap`, `key`, `nav`; body may be empty; else 400; unknown id 404. (evidence: internal/api/items.go:221-237)
  - Fix: `{via?: "tap"|"key"|"nav"}`.

- [ ] **MISSING** design.md §7.1 (line 1622): GET /api/items defaults and limits
  - Code does: no `view` defaults to `unread`, or `all` when `q` is set; `q` over 1000 bytes 400; `order=rank` with blank `q` 400; `feed` and `folder` together 400; negative `limit` 400; `ids=` capped at `maxIDsQuery`. (evidence: internal/api/items.go:86-133)
  - Fix: add these rules to the request column.

- [ ] **MISSING** design.md §7.1 (line 1618; also line 1595): login status codes
  - Code does: lockout `429 {"error":"locked"}` with `Retry-After`; busy verifier `503 {"error":"busy"}` with `Retry-After: 5`; bad user/password `401 {"error":"auth"}`; malformed body `400 bad_request`; success sets `Cache-Control: private, no-store`. (evidence: internal/api/login.go:24-77)
  - Fix: add "`429 locked` (+`Retry-After`), `503 busy` (+`Retry-After: 5`), `401 auth`, `400 bad_request`".

- [ ] **MISSING** design.md §7.1 (line 1648): account endpoints
  - Code does: `POST /api/account/password` signs out every other session, keeps the caller's; both routes verify `current` under the per-IP login lockout (a failure counts). Errors `403 bad_password`, `400 bad_new_password` (length `auth.MinPasswordLen`..`auth.MaxPasswordLen`), `429 locked`, `503 busy`, `400 bad_request` unless exactly one of `new`/`generate`. Generated API password is 24 chars. (evidence: internal/api/account.go:17, 24-63, 67-91, 104-106)
  - Fix: add these to the row.

- [ ] **MISSING** design.md §7.1 (line 1631): POST /api/feeds details
  - Code does: the `ok` response also carries `fetch:{pending?|outcome, new_items, error_class?, error?}`. Errors: `400 invalid_url`, `400 folder_not_found`, `400 bad_request` (title over 200 chars or control chars), `422 no_feed`, `422 discovery_failed` (10 s discovery budget), `400 unknown_field`. (evidence: internal/api/feedadmin.go:21-26, 146-152, 160-270)
  - Fix: add the `fetch` field and the error list.

- [ ] **MISSING** design.md §7.1 (lines 1636, 1641, 1655): refresh and run errors
  - Code does: per-feed refresh: `400` for `full` other than 0/1, `404`, `409 archive_feed`, `409 disabled`, `503 shutting_down`. `POST /api/refresh` and `POST /api/retention/apply`: `503 shutting_down`. `error_class`/`error` null when empty. (evidence: internal/api/feedadmin.go:526-576; internal/api/feeds.go:142-153; internal/api/settings.go:126-136)
  - Fix: add these codes.

- [ ] **MISSING** design.md §7.1 (line 1640): folder routes
  - Code does: POST answers `201` with the folder; `name` trimmed, 1-100 chars, no control chars; `position` 0-1,000,000; errors `409 folder_exists` (create and rename), `409 default_folder` (delete default), `400 unknown_field`, `404`; DELETE publishes `feed.changed` for each moved feed, then `folder.changed {folder_id}`. (evidence: internal/api/feedadmin.go:652-755)
  - Fix: "`201` folder (POST), `200` folder (PATCH), `204` (DELETE)", plus limits and errors.

- [ ] **MISSING** design.md §7.1 (line 1646): settings PATCH errors and side effects
  - Code does: 400 body `{error:"invalid_settings", message, keys:[...], issues:[{key, message}]}`; `sys.*` keys give "read-only setting", unknown keys "unknown setting"; empty body `400 bad_request`; `null` resets a key; lowering `refresh.interval_minutes` runs `PullInSchedule` and wakes the scheduler; changing `imgproxy.mode` refreshes the CSP; changing `imgproxy.cache_mb` applies the cap at once; a saved-search list naming a missing feed/folder is `400 invalid_settings` from inside the write. (evidence: internal/api/settings.go:26-108)
  - Fix: document the error shape and the side effects.

- [ ] **MISSING** design.md §7 / §7.1 (lines 1592, 1660): `/img` route, `/api/` catch-all, `/healthz`
  - Code does: `GET /img/{sig}/{flags}/{u}` requires the session cookie though not under `/api/`; any unregistered `/api/*` answers `401 auth`, or `404 {"error":"not_found"}` with a session, never the SPA; `/api/greader.php*` reaching a UI route is a plain 404; `GET /healthz` (`ok`, text) exists and is unauthenticated. (evidence: internal/api/api.go:197, 206, 261-263, 277-280)
  - Fix: add these to the §7 intro and `/healthz` to the table.

- [ ] **MISSING** design.md §7.1b (line 1676): error field vocabulary and preview scope
  - Code does: fields also include `terms` (no terms, over 50 terms, over 5 regex patterns), `id` (bad or duplicate id; preview `id` not an id), `filter` (preview with neither `filter` nor `id`), `name` (over 200 bytes); a feed scope naming the archive feed is `feed_id: no such feed`; preview evaluates saved **enabled** rules plus itself (disabled rules do not count toward its 200 cap); create and patch count all rules. (evidence: internal/filter/compile.go:57, 104-112, 236, 247; internal/api/filters.go:346-363; internal/store/filters.go:225-232; internal/store/filterretro.go:156-172)
  - Fix: extend the field list; "...apply to a create and a patch (every stored rule counts toward 200) and to a preview (evaluated against the enabled rules only)."

- [ ] **MISSING** design.md §7.1c (line 1696): registration edge cases
  - Code does: the 30 s reuse also applies to a malformed or unregistered cookie, not only a cookieless request; past 5 registrations a day, if the session's last device no longer exists, the client gets the unsaved default device; UA truncated to 300 chars. (evidence: internal/api/devices.go:329-381; internal/store/devices.go:115, 151)
  - Fix: "a request without a valid registered cookie"; add "(or the unsaved default device if that device is gone)".

- [ ] **MISSING** design.md §7.1c (lines 1700, 1708-1709): device endpoint details
  - Code does: `PUT /api/device/name` rejects control chars and missing `name` (400); in `GET /api/devices` `overrides` is an integer count, not an object; `ui.device_defaults` accepts only known `client.*` keys, drops nulls, capped at 8 KB; empty `PATCH /api/device` body 400; unknown stored profile keys ignored on read. (evidence: internal/api/devices.go:205-229, 293-297, 440-443, 508-516, 547)
  - Fix: add these details.

- [ ] **MISSING** design.md §7.1c (line 1714): localStorage holds more than a paint cache
  - Code does: also holds unsent profile changes (`kipple.deviceSync.dirty.v1`, replayed after reload), a one-time migration flag (`kipple.deviceSync.v1`), and legacy caches uploaded once. (evidence: web/src/lib/deviceSync.ts:41-43, 205-248, 440-493)
  - Fix: "...as a paint cache, plus a queue of unsent changes and a one-time migration flag (legacy localStorage prefs are uploaded once)."

- [ ] **MISSING** design.md §7.1d (lines 1720, 1728): auto-read request errors and targets
  - Code does: unknown body key `400 unknown_field`; bad values `400 bad_request`; archive feed id `404`; `expect_total` 0 to 2^31; disabled (non-archive) feeds are targets too (no `enabled` filter). (evidence: internal/api/autoread.go:79-117, 153-167; internal/store/autoread.go:85-86)
  - Fix: add these rules; state that disabled feeds are included (or add an `enabled = 1` filter if intended).

- [ ] **MISSING** design.md §7.1d (lines 1735, 1741-1742): saved-search validation details
  - Code does: `name` trimmed; scope errors use fields `scope.feed_id`, `scope.folder_id`, `scope.view`, `scope`; reorder errors use `ids`; the settings-PATCH path reports `saved_searches` and `id`; unknown keys in POST or reorder are `400 bad_request`, in PATCH `400 unknown_field`; a PATCH scope with unknown keys is `bad_saved_search` on `scope`. (evidence: internal/store/savedsearch.go:99-160; internal/api/savedsearches.go:148-156, 192-204, 291-298)
  - Fix: add the field names and unknown-key behaviour.

- [ ] **MISSING** design.md §7.3 (line 1765): `fetch.done` fields
  - Code does: `next_fetch_at` omitted when none; `error_class` and `error` are `""` when no error. (evidence: internal/sched/dispatcher.go:271-279)
  - Fix: `next_fetch_at?` (omitted when unscheduled).

- [ ] **MISSING** design.md §7.3 (lines 1758-1760, 1778): stream preamble and client reconnect policy
  - Code does: stream opens with `retry: 3000` and a `: connected` comment; each tick sends `: ping` then the `heartbeat` event. The client closes the source on every error, reconnects itself with backoff (1 s doubling to 30 s, +/-25% jitter, reset after 10 s up), arms the 45 s watchdog only after the first heartbeat, after a gap reconciles runs and counts from `/api/status` and refetches bootstrap, and reconciles on `visibilitychange` while runs are active. (evidence: internal/api/sse.go:49, 73; web/src/api/events.ts:349-470)
  - Fix: add a short paragraph with this policy.


### design.md §7.4-§7.8 and §8 (lines 1782-1986)

Verified as matching (not listed): caps, TTLs, budgets, CSP string, key and signature formats, thumbnail and decode-cost constants, except where below.

- [ ] **WRONG** design.md §8 (lines 1929, 1946-1951): API single-read inference is not implemented
  - Doc says: with `stats.api_single_read_is_open` on, a single-id `edit-tag a=read` whose `RETURNING` shows 0 to 1 writes an `open` with `inferred=1`.
  - Code does: nothing reads the setting (default only at internal/store/uibootstrap.go:34; hidden PATCH-able setting at internal/api/settingsmeta.go:343). greader `editTag` only calls `RecordStars` for starred changes (internal/greader/h_edit.go:84-101).
  - Fix: in the `open` row replace the API part with "API: none yet. The single-id inference of rule 3 is designed but not implemented; the setting exists but is inert." Mark rule 3 "(not implemented)". Same caveat at line 117 (decision 21).

- [ ] **WRONG** design.md §8 (lines 1930-1934, 1958-1962): the web client sends no `read_time`, `scroll`, `open_original` or `share` events
  - Doc says: "Web only" via `/api/stats/events`; rule 5 describes a live active-reading timer (visibility, focus, route checks, 15 s flush, `sendBeacon`).
  - Code does: the server ingest exists (internal/api/items.go:606-645; internal/stats/stats.go:81-142) but nothing under web/src posts to `/api/stats/events` or uses `sendBeacon`, `hasFocus`, a reading timer or scroll percentage (verified by grep). web/src/lib/share.ts:21-22 says no client sends the share event yet. The web only calls `POST /api/items/{id}/open` (web/src/api/queries.ts:209).
  - Fix: add under the Kinds table: "Server-side ingest and validation are implemented. The web client does not send `read_time`, `scroll`, `open_original` or `share` yet (phase 4); rule 5 is the contract for that work."

- [ ] **WRONG** design.md §7.5 (line 1842): "Open original" is not a plain link and records nothing
  - Doc says: plain link (`target=_blank`, `rel=noopener noreferrer`) that also records `open_original` via `POST /api/stats/events`.
  - Code does: a dropdown menu item whose `onSelect` calls `openExternal` (web/src/screens/ArticlePane.tsx:414-417; web/src/lib/links.ts:32-35): same tab (`location.assign`) by default on Apple touch devices, else `window.open(url, "_blank", "noopener,noreferrer")`; the device setting "Open links in" overrides. No stats event.
  - Fix: "'Open original' is a menu action that opens the article URL through `openExternal`: the same tab on iPhone/iPad (the default there), a new tab with `noopener,noreferrer` elsewhere, overridable by the device setting 'Open links in'. It records no stats event yet (`open_original` is phase 4)."

- [ ] **WRONG** design.md §8 (line 1939): `stats.Recorder` has two methods
  - Doc says: "an interface whose only method is `Record(tx *sql.Tx, ev Event) error`".
  - Code does: also `RecordStars(tx *sql.Tx, kind, client string, ids []int64) error` (internal/stats/stats.go:52-57), used by greader `edit-tag` (internal/greader/h_edit.go:98).
  - Fix: "an interface with two methods: `Record(tx, ev)` and `RecordStars(tx, kind, client, ids)` (one star/unstar row per changed id, used by greader `edit-tag`)."

- [ ] **WRONG** design.md §8 (line 1938): rule 1 signatures stale; not every read-state path goes through them
  - Doc says: `store.SetRead(tx, ids, read)`, `store.MarkScope(tx, scope, maxID)`, `store.MarkAllRead(tx, scope, ts)`; "every read-state path goes through them".
  - Code does: `SetRead(ctx, tx, ids, read, now)` (internal/store/itemstate.go:70), `MarkScopeRead(ctx, tx, scope, filter, maxID, now)` (internal/store/uiitems.go:529), `MarkAllRead(ctx, tx, scope, maxID, now)` (itemstate.go:234), plus `UnreadLedger` (itemstate.go:285). Other paths write `read` directly: auto-read (internal/store/autoread.go:271, 309), retroactive mute filters (internal/store/filterretro.go:402), fetch commit initial-read and mute rules (internal/store/fetchcommit.go:395-405). None reaches a Recorder, so the stats guarantee holds.
  - Fix: list the real signatures; "Every read-state write, including auto-read (`store/autoread.go`), retroactive mutes (`store/filterretro.go`) and the fetch commit's initial-read/mute marking, takes no Recorder and writes no stats."

- [ ] **WRONG** design.md §8 (lines 1936-1945): the "structural" enforcement is not structural in `internal/api` or `internal/greader`
  - Doc says: Recorder injected only into four handlers; `api.markRead` and greader `mark-all-as-read` "never receive it".
  - Code does: Recorder is a field of the whole `api.Server` (`s.rec`, internal/api/api.go:118, 181) and `opt.Stats` on the greader API (internal/greader/api.go:35), reachable from every handler. Only scheduler, maint and store truly never get it. The guarantee is convention plus tests (`TestMarkReadNeverTouchesRecorder`, internal/api/items_test.go:885).
  - Fix: "The Recorder is held by `api.Server` (`s.rec`) and by the greader API (`opt.Stats`). Only the web open, web star and stats ingest handlers and greader `edit-tag` call it. The scheduler, maint and store never receive it. The mark-read paths not calling it is enforced by the §10 tests, not by the types." Also adjust §11/§12 rows that call this "structural" if any.

- [ ] **WRONG** design.md §7.4 (line 1815): setting `imgcache.max_mb` does not exist
  - Code does: the setting is `imgproxy.cache_mb` (internal/api/settingsmeta.go:307; internal/store/uibootstrap.go:36; cmd/kipple/main.go:147).
  - Fix: replace `imgcache.max_mb` with `imgproxy.cache_mb`.

- [ ] **WRONG** design.md §7.7 (line 1886) vs §7.8 (line 1905): Permissions-Policy contradicts embed autoplay
  - Doc says: §7.7 grants `fullscreen` and picture-in-picture "only for the embed hosts"; §7.8 inserts the tap-to-load iframe with `allow="autoplay; fullscreen; picture-in-picture"` and `?autoplay=1`.
  - Code does: `autoplay=()`, `fullscreen=(self youtube-nocookie vimeo)`, `picture-in-picture=(self youtube-nocookie)` (internal/httpx/headers.go:33-36). PiP is never delegated to Vimeo; both lists include `self`; `autoplay=()` disables autoplay for the page and nested frames, so the iframe's `allow="autoplay"` (web/src/lib/articleDom.ts:9, 14-15) cannot grant it. Likely a second tap is needed (not verified in a browser).
  - Fix: document the exact header (`autoplay=()`; `fullscreen=(self "https://www.youtube-nocookie.com" "https://player.vimeo.com")`; `picture-in-picture=(self "https://www.youtube-nocookie.com")`); then either say in §7.8 that autoplay is blocked by the page policy, or flag the header for a code fix (grant `autoplay` to the two embed hosts).

- [ ] **STALE** design.md §8 (line 1983, contradicts line 1657): CSV export described as live but not mounted
  - Code does: no route registered (internal/api/api.go:196-240); only the same-origin download list mentions the path (api.go:310).
  - Fix: start the paragraph with "**CSV export (phase 4, not mounted yet).**"

- [ ] **STALE** design.md §7.4 (line 1800): every `/img/` response gets CORP, not only hits
  - Code does: `serveHit` sets it (internal/imgproxy/cached.go:209) and `httpx.Secure` sets it on every `/img/` and `/api/` response (internal/httpx/headers.go:87-89).
  - Fix: "Every `/img/` response also carries `Cross-Origin-Resource-Policy: same-origin` (set by `httpx.Secure`, §7.7)."

- [ ] **STALE** design.md §7.4 (line 1807): failure classes broader than listed
  - Code does: every non-200 status except 5xx, 429, 408 is permanent 24 h (incl. 400, 401, 451) (internal/imgproxy/upstream.go:317-322); 408, empty body and mid-body read error are transient (upstream.go:318; internal/imgproxy/imgproxy.go:380-386); every transport error is transient, incl. too many redirects and an SSRF-blocked address (upstream.go:324; cached.go:128).
  - Fix: "24 h: any non-200 status other than 5xx, 429 and 408, an unsupported type, too large. 10 min doubling to 24 h: 5xx, 429, 408, any transport error (timeouts, DNS, connection, too many redirects, a blocked address), an empty or unreadable body."

- [ ] **STALE** design.md §7.4 (lines 1820, 1822): 150 KB is really 150 KiB
  - Code does: `thumbMinSource = 150 << 10` = 153,600 bytes (internal/imgproxy/thumb.go:26).
  - Fix: "at least 150 KiB (153,600 bytes)"; same on line 1822.

- [ ] **STALE** design.md §7.6 (line 1863): export escaping understated
  - Code does: `xml.EscapeText` (internal/opml/export.go:119) also escapes `'`, `>`, tab, LF, CR.
  - Fix: "`xml.EscapeText` escapes `& < > \" '` and tab, LF and CR as character references; `;` and `,` are left as is."

- [ ] **STALE** design.md §8 (line 1923): timezone setting key
  - Doc says: `settings.tz`.
  - Code does: key `tz`, default `America/New_York`, UTC fallback for an unresolvable name (internal/store/stats.go:43-48; internal/api/settingsmeta.go:320).
  - Fix: "computed in the `tz` setting (default `America/New_York`; an unknown zone falls back to UTC)".

- [ ] **STALE** design.md §7.4 (line 1811): `GET /api/imgcache` is not origin-checked
  - Code does: both routes `authed`; same-origin covers non-GET only, so `POST /api/imgcache/clear` is checked and the GET is not (internal/api/api.go:208-209, 285, 305-312).
  - Fix: "API (session; the POST is also same-origin checked)".

- [ ] **STALE** design.md §7.5 (line 1836): the hold also requires the pending set
  - Code does: the hold applies only while the item is in the in-process pending set of items the pool queued or is running (internal/store/items.go:37-42; internal/store/fulltextmode.go:106-137); items the pool never accepted are served at once; the window is configurable up to 60 s (internal/greader/api.go:60-77).
  - Fix: append "...and only while the item is in the pool's in-memory pending set (§6.5); an item the pool did not accept is shown at once with the feed content."

- [ ] **MISSING** design.md §7.4 (line 1806): freshness rule for `no-store`/`no-cache`
  - Code does: `no-store` or `no-cache` gives 1 day freshness; max-age over 30 d capped (internal/imgcache/cache.go:995-1014).
  - Fix: add "`no-store`/`no-cache` count as 1 d (still cached, revalidated daily); max-age is capped at 30 d."

- [ ] **MISSING** design.md §7.4 (lines 1786-1794): URL length cap, redirect limit, 503
  - Code does: the rewriter leaves URLs over 4096 bytes unproxied (internal/imgproxy/imgproxy.go:96-98; in `all` mode such an image is then blocked by CSP); the proxy answers 400 to an encoded URL over that length, non-canonical flags such as `04`, or a URL with userinfo (imgproxy.go:237-258); upstream follows at most 5 redirects (imgproxy.go:57; upstream.go:175-181); `/img/` answers 503 while there is no account secret (internal/api/image.go:75-79).
  - Fix: add these four facts under URL and Fetch.

- [ ] **MISSING** design.md §7.4 (line 1793): open response not in the rewrite list
  - Code does: `POST /api/items/{id}/open` also returns a proxied detail (internal/api/items.go:265); card images are rewritten in `api.proxyCards` via `imgproxy.Rewriter`, not in `internal/sanitize` (internal/api/image.go:112-137).
  - Fix: list "the open response" beside `GET /api/items/{id}`; say card `image` and `url` are rewritten in `api.proxyCards`.

- [ ] **MISSING** design.md §7.6 (lines 1846-1855): import report fields and CLI entry point
  - Code does: result also carries `folders_created`, `feeds_added`, `skipped`, `invalid_attrs`, plus `run_id` from `POST /api/opml` (internal/opml/import.go:42-53; internal/api/opml.go:69-72); `kipple:enabled=0` imports as `disabled_reason='user'` (import.go:160-163); `mark_read_older_than_days` must be 1-365 or 400 `bad_days` (internal/api/opml.go:25-31); `kipple import [-mark-read-older-than-days N] <file|->` CLI shares the parser (cmd/kipple/import.go); export writes `kipple:*` attributes only when non-default (internal/opml/export.go:76-101).
  - Fix: add to Import steps 3, 6, 7 and the export attribute bullet; heading "(UI, `subscription/import` and `kipple import` share the parser)".

- [ ] **MISSING** design.md §7.8 (line 1902): client removes `target` on same-tab devices
  - Code does: the client's DOMPurify pass removes `target` when the device opens links in the same tab (default on iPhone/iPad), else sets `target=_blank`; `rel` always kept (web/src/lib/safeHtml.ts:15-25).
  - Fix: add to the `a[href]` row: "The client drops `target` on devices set to open links in the same tab (default on Apple touch devices)."

- [ ] **MISSING** design.md §8 (lines 1952-1957): ingest limits and checks
  - Code does: body capped at 64 KiB, batch at 200 events (extra dropped) (internal/api/items.go:27-28, 607-617); only `read_time`, `scroll`, `open_original`, `share` accepted; values truncated to integers; every kind requires the item in `items` or `trimmed_items` (internal/stats/stats.go:87-93; internal/store/stats.go:54-75); `client` must be one of web, pwa, client-a, client-b, unread, api (stats.go:29, 83).
  - Fix: add these as bullets under rule 4.


### design.md §9-§13 and the CLI (lines 1987-2427, plus CLI mentions at 692, 716-718, 1648, 1784)

- [ ] **WRONG** design.md §11 (line 2324), §10 (line 2249): `greader.ot_includes_user_changes` does nothing
  - Doc says: the setting "restores it without a schema change"; the `ot` test says an item read after `ot` is not returned "(unless the setting is on)".
  - Code does: only declared and validated (internal/api/settingsmeta.go:339; internal/store/uibootstrap.go:45); nothing in internal/greader or internal/store reads it.
  - Fix: §11: "Both target clients pull full unread and starred lists without `ot`; server A behaves this way. The `greader.ot_includes_user_changes` key is reserved (validated, hidden) but **not implemented**." §10 line 2249: delete "(unless the setting is on)". (Same root as the §1 decision 6 finding.)

- [ ] **WRONG** design.md §11 (line 2332), §12 #35 (line 2399): `greader.subscribe_fetch_now` does nothing
  - Doc says: "`greader.subscribe_fetch_now` restores the synchronous path".
  - Code does: declared hidden, never read; no synchronous path (internal/api/settingsmeta.go:341; internal/store/uibootstrap.go:46).
  - Fix: §11: "Pending the owner's decision. The `greader.subscribe_fetch_now` key is reserved but not implemented: there is no synchronous path yet." §12 #35: "...The synchronous path is not built; the reserved key is a no-op pending the owner (decision 33)."

- [ ] **WRONG** design.md §11 (line 2331), §10 (lines 2231, 2260), §12 #24 (line 2388): API `open` inference not implemented
  - Doc says: with `stats.api_single_read_is_open` on, a single-id `edit-tag a=read` stores 1 inferred `open`; the client A contract step 9 and the structural-rule test check this.
  - Code does: edit-tag records stats only for star/unstar; nothing reads the setting; nothing writes `inferred=1` (internal/greader/h_edit.go:92-98; internal/api/settingsmeta.go:343; internal/store/uibootstrap.go:34).
  - Fix: §11: "Not implemented: the reserved key `stats.api_single_read_is_open` is a no-op, so no API read ever becomes an `open`." §10: remove the "with the setting on -> 1 inferred `open`" clauses or mark "(when inference is built)". §12 #24: the default is effectively permanent until inference is built.

- [ ] **WRONG** design.md §11 (line 2351): the web UI does not set `dir="auto"`
  - Code does: no `dir` attribute or CSS `direction` anywhere in web/src or web/index.html.
  - Fix: "Deferred in both the Reader API and the web UI (neither sets a direction today)." (or implement it).

- [ ] **WRONG** design.md §9 (line 2011): no favicon finder; discovery is its own package
  - Doc says: `internal/fetch` contains `discover.go (autodiscovery, favicon finder; UI path only by default)`.
  - Code does: autodiscovery is `internal/discover` (discover.go:1-5). No code fetches favicons and nothing writes `feed_icons` (only readers: internal/store/subs.go:32, 70, 528; internal/store/uibootstrap.go:189). internal/fetch holds client, ssrf, fetch, charset, parse, dedup, errors, backoff, redirect.
  - Fix: drop `discover.go (...)` from the fetch line; add `parse.go (gofeed parse, malformed-item skip, enclosure dedup)`; add `internal/discover  feed autodiscovery for the UI add-feed path, through the guarded transport`. Note favicon fetching is not built: `feed_icons` is never populated (so Reader `iconUrl` and the `/icon/` route never have data).

- [ ] **WRONG** design.md §9 (line 2005): SQL is not confined to `internal/store`
  - Doc says: "Only this package contains SQL."
  - Code does: SQL also in internal/opml/import.go:78-168, internal/opml/export.go:29, internal/backup/check.go:55-124, internal/backup/backup.go:363, internal/backup/sessions.go:13, internal/api/autoread.go:158, and internal/imgcache/index.go (separate SQLite index).
  - Fix: "Kipple-database SQL lives in this package, except `internal/opml` (import/export, run inside a store transaction), `internal/backup` (checks on a copied file) and one count in `internal/api/autoread.go`. `internal/imgcache` has its own separate SQLite index." (or move that SQL into store).

- [ ] **WRONG** design.md §9 (line 2035): there is no Access JWT verifier
  - Code does: no JWT or Cloudflare Access code in internal/ or cmd/. internal/auth/auth.go has the Verifier, argon2id, Lockout (10 per 15 min, :349), GeneratePassword (:275), trusted-proxy handling.
  - Fix: delete "optional Access JWT verifier"; add "web login Lockout (10 failures / 15 min), GeneratePassword, WarnUntrustedProxyHeaders".

- [ ] **WRONG** design.md §9 (line 2043; contradicts line 1599): `internal/httpx` holds only headers.go
  - Doc says: httpx has request log with redaction, recover, security headers and csrf.go; line 1599 names `internal/httpx/csrf.go` as the same-origin guard.
  - Code does: internal/httpx/headers.go only (`Secure`, `PageCSP`, :44, :77); no recover middleware; the same-origin guard is `authed`/`needsOriginCheck`/`isDownload`/`sameOrigin` in internal/api/api.go:268-322; the redacting request log exists only for the Reader API (internal/greader/log.go).
  - Fix: §9: `internal/httpx  headers.go: Secure (security headers, CSP via PageCSP)`; move "same-origin guard" to the internal/api line and "request log with redaction" to the greader line. Line 1599: `internal/api/api.go (sameOrigin)`.

- [ ] **WRONG** design.md §9 (lines 1990-1992): main.go summary inaccurate
  - Code does: `sqlite.OFDLocking(true)` runs inside `store.Open` under a `sync.Once` (internal/store/db.go:193-198); main dispatches subcommands (cmd/kipple/main.go:66-89); runServe applies TZ (:108), takes the data-dir lock (:120), calls `ensureAccount` (:139), opens the optional `imgcache` (:145-160), creates one shared `auth.Verifier` (:165) and the `ftrun` runner (:169), starts `maint` (:177-178), wraps in `httpx.Secure` + `auth.WarnUntrustedProxyHeaders` (:207-209).
  - Fix: "cmd/kipple/main.go  subcommands (serve default, import, api-password, password, restore, version); serve: config -> TZ -> lock.Acquire(kipple.lock) -> store.Open (migrations; OFD locking) -> ensureAccount -> imgcache.Open (optional) -> verifier, fetch client, ftrun, sched, maint -> greader.Front ahead of the root mux, wrapped by httpx.Secure -> serve; shutdown sequence (§4.10); import _ "time/tzdata"; mime registrations".

- [ ] **WRONG** design.md §9 (lines 1987-2043, 2046): package list and dependencies out of date
  - Code does: no `internal/readability`; the extractor is `internal/extract` (extract.go:1-4) using `codeberg.org/readeck/go-readability/v2 v2.1.2` (go.mod); `golang.org/x/sync` is not a dependency; go.mod also has `golang.org/x/image`, `golang.org/x/sys`, `golang.org/x/term`. Missing packages: `internal/backup`, `internal/clock`, `internal/discover`, `internal/extract`, `internal/ftrun`, `internal/lock` (also `internal/filter`, `internal/imgcache`, `internal/feedurl` should be checked against the list).
  - Fix: rename the readability line to `internal/extract  go-readability v2 (codeberg.org/readeck) pipeline (guarded fetch, charset, absolutize, sanitize)`; add one-line entries for backup, clock, discover, ftrun, lock; dependencies: replace go-readabilityV2 with `codeberg.org/readeck/go-readability/v2`, drop `golang.org/x/sync`, add `golang.org/x/image` (thumbnails), `golang.org/x/sys`, `golang.org/x/term` (password prompt).

- [ ] **WRONG** design.md §9 (lines 2052-2058): long-lived goroutine list incomplete
  - Code does: also the full-text pool, `FulltextGlobal` (default 4) goroutines (internal/sched/fulltext.go:145-165; sched.go:299); imgcache background loop (internal/imgcache/cache.go:270) plus a goroutine per cap change (:615); lazily started thumbnail worker pool (internal/imgproxy/thumb.go:391); backup export job (internal/backup/job.go:82); filter-apply and auto-read runs (internal/api/filters.go:510; internal/api/autoread.go:230); the ListenAndServe goroutine (cmd/kipple/main.go:222). main blocks in `superviseServe` on `serveErr` or `ctx.Done()` (:267-287).
  - Fix: add "Full-text extraction pool (4, via ftrun)", "imgcache sweep loop (1)", "thumbnail pool (lazy)", "short-lived job goroutines: backup export, filter apply, auto-read run"; item 5: "main, in superviseServe, selecting on the listener error and ctx.Done()".

- [ ] **WRONG** design.md §9 (lines 2002-2003, 2064): settings are not cached in an `atomic.Pointer`
  - Doc says: store/settings.go keeps a "cached snapshot in an atomic.Pointer, refreshed on PATCH"; sync inventory lists "the cached Reader-token and settings `atomic.Pointer`s".
  - Code does: settings read on each call ("The result must not be cached", internal/store/settings.go:70). Existing atomic.Pointers: greader `acct` (5 s TTL, internal/greader/api.go:94, 351), api `imgMode` (internal/api/api.go:129), store WithWrite `holder` (internal/store/db.go:60). Inventory omits the imgproxy per-host limiter (internal/imgproxy/upstream.go:285), the full-text queue mutex/cond, the ftrun call map, the imgcache mutex, the web-login Lockout map.
  - Fix: settings.go "(typed reads with defaults; not cached)"; inventory: "the greader account-snapshot, imgMode and WithWrite-holder atomic.Pointers" plus the missing primitives.

- [ ] **WRONG** design.md §12 #12 (line 2376), §10 (line 2104): no WAL-bound test
  - Doc says: "WAL-bound test added" (1000-id edit-tag on 20 KB articles writing < 1 MB of WAL).
  - Code does: no test sets `wal_autocheckpoint=0` or measures `-wal` size (grep of all *_test.go).
  - Fix: add the test, or "...validated at design time; the WAL-bound test in §10 is **not yet written**".

- [ ] **WRONG** design.md §10 (line 2103), relied on by §11 (line 2336) and §12 #22 (line 2386): query-plan suite much smaller than described
  - Doc says: 150k-item seeded DB; every hot query checked fresh and after ANALYZE (contents, mark-all, keyset views, trim-set, dedup lookup, due selection, FindFeedByURL, stats session lookups).
  - Code does: plan tests seed 300 items (internal/store/items_test.go:16-64, TestStreamIDsQueryPlans: ids legs, unread, starred) and 900 items (internal/store/order_test.go:57, TestOrderQueryPlans), plus TestSearchPlan; fresh and after ANALYZE. No plan tests for contents, mark-all, trim-set, dedup, due, FindFeedByURL, stats.
  - Fix: list what exists and mark the rest "TODO" (or extend the suite).

- [ ] **WRONG** design.md §10 (line 2095), §11 (line 2339): pool-free assertion helper does not exist
  - Code does: no `OpenConnections`/`InUse` check in any *_test.go; only `TestWithWriteTimeoutLogsHolder` (internal/store/store_test.go:368).
  - Fix: remove it from §11's mitigations and mark the §10 bullet "not yet written" (or add the helper).

- [ ] **WRONG** design.md §12 #19 (line 2383) and #24 (line 2388), §9 (lines 2004, 2034); contradicts line 1657: phase-4 stats shown as built
  - Doc says: #19 FIX "The CSV export pages by keyset..."; §9 lists store/stats.go "aggregates + keyset CSV pages" and `internal/api/stats.go`; #24 "views default to `inferred=0`...".
  - Code does: no `/api/stats/export.csv` or `/api/stats/summary` route (internal/api/api.go:195-262); `isDownload` only names the path (api.go:310); store/stats.go has insert and lookup helpers only (:43-133); no api/stats.go; `POST /api/stats/events` is in internal/api/items.go:606.
  - Fix: §12 #19/#24 "FIX (designed; phase 4, not built)"; §9 store/stats.go "(insert + validation in tx; aggregates and CSV pages are phase 4)"; remove `stats.go` from the api list and note stats events are in items.go.

- [ ] **STALE** design.md §13 #5 (line 2415): migration 0005 has shipped
  - Doc says: porter with `bm25(4,2,1)` is "in pending migration 0005. Until then the table uses `unicode61 remove_diacritics 2` and plain `rank`".
  - Code does: internal/store/migrations/0005_fts_porter.sql recreates `items_fts` with `tokenize='porter unicode61 remove_diacritics 2'` and persistent rank `bm25(4.0, 2.0, 1.0)`; tested by internal/store/migrate0005_test.go.
  - Fix: "**Superseded and built** by backend-additions-round2 §7: porter over unicode61 (diacritics folded) with a persistent `bm25(4,2,1)` rank, migration 0005."

- [ ] **STALE** design.md §9 (lines 1998-2005, 2012-2014, 2026, 2029-2034, 2039-2042): file lists name missing files and omit many
  - Code does: **store:** no `folders.go` or `icons.go`; restore is in itemstate.go, purges in maint.go; `KnownUIDs` in fulltext.go:162; missing autoread, devices, export, favorites, feedadmin, feedstatus, filterretro, filters, fulltextmode, health, itemstate, savedsearch, search, searchquery, selfcheck, subs, uibootstrap, uiitems. **greader:** actual files api.go (New, Front at :215, auth, client-seen map at :103-171), form.go, h_edit.go, h_streams.go, h_subs.go, itemid.go, log.go, routes.go, stream.go; none of front/auth/filter/h_ids/h_contents/h_markall/h_tags/h_misc/response/ua/seen.go exist. **api:** actual account, api, autoread, backup, bootstrap, devices, feedadmin, feeds, filters, fulltext, image, imgcache, items, login, maintenance, opml, savedsearches, settings, settingsmeta, sse; none of router/folders/refresh/health/stats/events/archive.go exist. **sanitize:** entry at 2012-2014 garbled; actual absolutize, policy (RequireParseableURLs :30), iframes, leadimage, rewrite, serve (ServeHTML, StripTracking), text, url. **sched:** also sched.go, fulltext.go. **imgproxy:** also thumb*.go, relay.go, upstream.go. **stats:** Recorder also `RecordStars` (internal/stats/stats.go:147). **web:** also `/_status` (internal/web/handler.go:69). **events:** ring bounded at 1 MiB too (internal/events/hub.go:18).
  - Fix: regenerate these lines from `ls internal/<pkg>` with the roles above.

- [ ] **STALE** design.md §10 (line 2077, 2199), §9 (line 2071): test command and golden files
  - Doc says: "All tests use `go test -race -timeout 5m ./...`. ... Golden files use an `-update` flag."; contract tests "compare the responses with golden files".
  - Code does: CI runs `go test -race -shuffle=on -timeout 15m ./...` (.github/workflows/ci.yml); local Windows runs cannot use `-race` (race_on/race_off build-tagged files stretch timing ceilings, internal/store/race_on_test.go); only internal/fetch uses golden files with `-update` (parse_test.go:14); greader contract tests assert inline (internal/greader/contract_test.go:185-481).
  - Fix: "CI runs `go test -race -shuffle=on -timeout 15m ./...` (race-only timing stretched via race_on/race_off files). Golden files with `-update` are used by the fetch parser tests. Reader contract tests assert inline."

- [ ] **STALE** design.md §10 (lines 2080-2114): store-plan tests that do not exist or only partly exist
  - Code does: **Migrations:** a fresh DB gets `LatestVersion()` (5), not `user_version=1` (internal/store/store_test.go:35-45); no test of `foreign_keys`=1 after a failed foreign-keys-off migration (mechanism at internal/store/migrate.go:177-196, unused); failed-then-retry covered by migrate0004_test.go:150. **Constraints:** no store tests for "second archive feed refused" or "`url_key` UNIQUE"; username, default-folder, retention-75 tested only at CLI/API level (cmd/kipple/account_test.go; internal/api/feedops_test.go:395-462; internal/api/settings_test.go:75). **Allocator:** no 8x10k concurrency test, no unsubscribe-cascade high-water test, no 2 h-ahead ERROR/health assertion; backward step and seeding covered by TestIDAllocMonotonicAcrossRestart (internal/store/fetchcommit_test.go:489). **FTS:** no markup-only `items_fts_data` test, no integrity-check after trim/restore. **Maintenance:** no "missing `/data/backup` is created" test (maint_test.go:123 pre-creates it); "Cancel interrupts VACUUM INTO" only with a pre-cancelled context (:133-139).
  - Fix: change "user_version=1" to "user_version = latest (5)"; mark each missing item "TODO" (or write the tests).

- [ ] **STALE** design.md §10 (lines 2134-2143, 2160-2166, 2252, 2263-2274): other promised tests missing or partial
  - Code does: **absolutize:** inline, not golden (internal/sanitize/absolutize_test.go); no `xml:base` test and no code for xml:base; the end-to-end `/wp-content/x.jpg` fixture through `stream/items/contents` and `GET /api/items/{id}` does not exist. **Shutdown:** TestShutdownDuringLargeRun (internal/sched/sched_test.go:616) covers < 15 s, fetch_log commits, waiting handlers returning; not "SSE subscribers return before Shutdown" (partly internal/api/api_test.go:592) or "`wal_checkpoint` runs"; waiters get `ErrStopped` -> 503 "shutting_down" (internal/api/feeds.go:147). **Phase-1 gate:** no captured-traffic golden sequences under internal/greader (only docs/HF/evidence/client-a-alpha2-2026-09-26.log). **Stats:** no Recorder-error rollback test, no concurrent-batch cap test, no stats DST test, no views/CSV tests (not built).
  - Fix: mark each "TODO" (views/CSV "phase 4"); state the Phase-1 gate status.

- [ ] **MISSING** design.md §2.6 (lines 716-718), §9: CLI subcommands `import`, `api-password`, `version`
  - Code does: `serve` is the default (cmd/kipple/main.go:67-88); `kipple import [-mark-read-older-than-days N] <file.opml | ->` (N 0 or 1-365; NoMigrate/NoCheckpoint; JSON on stdout, summary on stderr; cmd/kipple/import.go:23-81); `kipple api-password` (no args; generates, prints once, signs clients out; cmd/kipple/account.go:98-127); `kipple version`; `restore` also accepts `-yes` (restore.go:39). `restore` and `password` (5-256 bytes, 5 s account cache) match.
  - Fix: add after line 718: "**`kipple import [-mark-read-older-than-days N] <file.opml|->`** (N 0 or 1-365; NoMigrate/NoCheckpoint; JSON report on stdout; new feeds fetched by the running server's next tick). **`kipple api-password`** (no args; prints a fresh generated Reader API password once). **`kipple version`**. No argument runs `serve`." List the subcommands in the §9 main.go line.

- [ ] **MISSING** design.md §9 (line 2050): `ReadTimeout` and per-write deadlines
  - Code does: also `ReadTimeout: 30 * time.Second` (cmd/kipple/main.go:211); the backup download replaces the write deadline per write (internal/api/backup.go:164), like SSE (internal/api/sse.go:43).
  - Fix: add "`ReadTimeout` 30 s" and "SSE and the backup download extend it per write with `http.ResponseController.SetWriteDeadline`".

- [ ] **MISSING** design.md §10 (lines 2075-2300): shipped test suites the plan never mentions
  - Code does: suites for the filter engine (internal/filter/*_test.go incl. fuzz corpora and benchmarks; store/api/sched/greader filters_test.go), backup export and restore (internal/backup/*_test.go; cmd/kipple/restore_test.go, restore_wal_test.go, restore_owner_unix_test.go), `password`/`api-password` CLI (cmd/kipple/password_test.go, account_test.go), data lock (internal/lock/lock_test.go), devices, saved searches, auto-read, search v2, full-text (ftrun, extract, sched/fulltext_test.go, greader/hold_test.go), discover, imgproxy thumbnails (thumb*_test.go), and the web Vitest suite.
  - Fix: add short §10 subsections: "Filters", "Backup/restore/CLI", "Full-text", "Thumbnails", "Web (Vitest)", naming each suite and key invariants.


## docs/deploy.md

Context: tags `v0.2.0-alpha.1` and `v0.2.0-alpha.2` ship schema 3 (migrations 0001-0003); docs/HF/evidence/README.md says alpha.2 runs on Host-A. The phase-2 tip adds 0004 and 0005, so the next deploy (alpha 3) migrates 3 -> 5.

- [ ] **WRONG** docs/deploy.md "Phase 2 alpha 3 deploy notes" (line 151): the schema migration and its rollback are not mentioned
  - Doc says: the alpha 3 notes cover images, search and devices only; the only migration text is the phase 1 -> 2 section ("(0002, 0003)", `pre-migration-1-3-<ns>.db`).
  - Code does: the alpha 3 binary has 5 migrations. First start takes `pre-migration-3-5-<ns>.db`, then applies 0004 (additive) and 0005 (drops and rebuilds `items_fts` with porter, re-tokenizing every item: time proportional to the corpus). An alpha.2 binary refuses schema 5. `password`, `api-password` and `import` open with NoMigrate and refuse a schema-3 database under the alpha 3 binary until `serve` has migrated it. (evidence: internal/store/migrate.go:88, 107-125, 147; internal/store/migrations/0005_fts_porter.sql:1-19; `git ls-tree v0.2.0-alpha.2 internal/store/migrations/`)
  - Fix: add a first bullet: "**Schema 3 -> 5.** The first start writes `/data/backup/pre-migration-3-5-<ns>.db`, then applies 0004 (additive) and 0005 (rebuilds the search index; startup takes longer on a large database, so watch `docker logs kipple` for `store: applied migration`). Take an Export backup from alpha 2 first. Rollback to alpha 2: stop kipple, `docker compose run --rm -T --no-deps kipple restore /data/backup/pre-migration-3-5-<ns>.db --yes` with the alpha 3 image, `git checkout v0.2.0-alpha.2`, rebuild, `up -d kipple`. Anything read or starred since then is lost. Until the new server has started once, `kipple password`, `api-password` and `import` refuse the old schema."

- [ ] **STALE** docs/deploy.md "Phase 2 deploy: extra steps" / "Roll back to phase 1" (lines 112-149): historical; numbers no longer match
  - Code does: "(0002, 0003)" and `pre-migration-1-3-<ns>.db` held only for alpha.1/alpha.2; a phase-1 DB started with the current build produces `pre-migration-1-5-*` (internal/store/migrate.go:122, 147).
  - Fix: retitle "Phase 1 -> phase 2 (done 2026-09-25, v0.2.0-alpha.1)"; add "applies to a schema-1 database; with a build after alpha.2 the file is `pre-migration-1-<latest>-*`".

- [ ] **MISSING** docs/deploy.md "Where things live" (lines 14-23): image cache and restore temp files
  - Code does: image cache at `/data/imgcache/` (default cap 1024 MiB, never in backups); restore leaves `/data/restore-tmp.db*` and `/data/restore-upload.tmp` while running (cmd/kipple/main.go:145-149; internal/store/uibootstrap.go:13-16; cmd/kipple/restore.go:125-140).
  - Fix: add rows "`/data/imgcache/` | Image cache (`imgproxy.cache_mb`, default 1024 MiB; LRU; not in backups or snapshots) | capped" and "`/data/restore-tmp.db`, `/data/restore-upload.tmp` | Only during a `kipple restore` | transient".

- [ ] **MISSING** docs/deploy.md (whole file): `kipple import` and `kipple version`
  - Code does: `kipple import [-mark-read-older-than-days N] <file.opml | ->` is safe while `serve` runs, prints JSON on stdout, flag must precede the file; `kipple version` prints the build version (cmd/kipple/import.go:23-33; cmd/kipple/main.go:81-85).
  - Fix: add "Import OPML": `ssh host-a 'docker exec -i kipple /kipple import -' < feeds.opml` (stdin, because nonroot cannot read a bind-mounted `/import`); add "`docker exec kipple /kipple version` shows the running build".

- [ ] **MISSING** docs/deploy.md "Restore a backup" step 2 (line 88): exit status of a verify-only run
  - Code does: without `--yes`, restore prints the report, then exits 1 with `kipple: nothing was changed: run the same command again with --yes to restore` (cmd/kipple/restore.go:59, 195-197; cmd/kipple/main.go:60-62).
  - Fix: append: "It ends with 'nothing was changed ...' and exit status 1; that is expected."

- [ ] **MISSING** docs/deploy.md: no health check guidance
  - Code does: `GET /healthz` unauthenticated returns `ok`; Dockerfile and compose example have no HEALTHCHECK (distroless has no curl) (internal/api/api.go:197, 266-270; Dockerfile:34-40).
  - Fix: add "Health: `curl -s http://127.0.0.1:7080/healthz` on Host-A -> `ok`. The image has no HEALTHCHECK."

- [ ] **MISSING** docs/deploy.md "Reset the web password" (line 58): in-app routes
  - Code does: `POST /api/account/password` and `POST /api/account/api-password` (Settings) (internal/api/api.go:228-229).
  - Fix: add "When you can still sign in, change either password in Settings > Account; the CLI is the recovery path."

Verified correct (not listed): the lock and "kipple is running" refusal; `restore - --yes` argument order; the `-2` suffix for two pre-restore dirs in one second; keeping the newest 3 pre-restore and pre-migration files; 04:10 snapshot on the `tz` setting; export 409/507, 2.2x space, 4 GiB cap, 5-minute single-use link, job polling, filename format; password length 5-256 and account-secret rotation; lockout 10/15 min in memory; root-ownership fix; `/_status`; alpha 3 claims (imgproxy.mode default `all`, 1 GiB cache, 422 `search_too_broad` at 500 ms, 5 new devices per session per day, 50-device cap with 30-day eviction).



## docs/ui-decisions.md

- [ ] **WRONG** docs/ui-decisions.md "Round 2 / Gestures and keys" (line 119): read rows leave the Unread list
  - Doc says: "`m` in Unread view: row dims in place."
  - Code does: a row marked read on purpose (key, menu, toolbar) dims, then leaves the Unread list after 1.5 s while the undo toast stays; the open article leaves when you move off it; a swiped row leaves at once. (evidence: web/src/screens/ListPane.tsx:65-66, 418-425, 427-466; web/src/lib/itemActions.ts:11-19, 78)
  - Fix: add "(shipped differently: the row leaves after 1.5 s with the undo toast up; the open article leaves when you move off it; undo or mark unread cancels it)".

- [ ] **STALE** docs/ui-decisions.md "Round 2 / Backend features" (lines 123-124): F1-F7 only partly shipped
  - Doc says: "Filters family F1 to F7 in phase 2 (mute, mark read, auto-star, only-show-matching, highlights, saved searches, auto-read after N days, reading-time filter, per-feed view/order)".
  - Code does: shipped: filter actions Mute, Mark as read, Star, Highlight (web/src/api/filters.ts:68-73), saved searches, auto-read. Not shipped: only-show-matching (no action); reading-time filter has server params `min_minutes`/`max_minutes` (internal/api/items.go:115-118, 661) but no UI; per-feed view/order (order is per device, web/src/lib/devicePrefs.ts:66; FeedEditor has no order control).
  - Fix: annotate "(shipped in phase 2: mute, mark read, star, highlight, saved searches, auto-read; not shipped: only-show-matching, reading-time filter UI (API only), per-feed view/order)".

- [ ] **STALE** docs/ui-decisions.md "design.md audit answers" item 10 (lines 71-72): offline/PWA not shipped
  - Doc says: read offline, "offline" message at launch, queue actions and sync later.
  - Code does: no service worker, manifest, offline launch message or action queue; only "Can't refresh while offline" (web/index.html:1-16; web/src/screens/ListPane.tsx:604-606).
  - Fix: annotate "(not shipped yet: phase 3 PWA)".

- [ ] **STALE** docs/ui-decisions.md "Layout" (line 54) and "Round 2 / Layouts" (lines 106-107): layouts shipped under other labels
  - Code does: all five shipped; Magazine labelled "Editorial", Headlines "Email - Compact"; ids unchanged (web/src/lib/devicePrefs.ts:9-17).
  - Fix: annotate "(shipped; Magazine is labelled Editorial and Headlines Email - Compact, ids unchanged)".

- [ ] **STALE** docs/ui-decisions.md header (lines 5-6) and round-1 TODOs (lines 14-15, 24-26, 29-30, 32-33, 43-44, 47-48, 54-55, 64, 66, 69): every TODO is resolved
  - Code does: all resolved and shipped: density steps (web/src/lib/prefs.ts:9-17), Directory (schemes.json), 20 schemes, Paper/Midnight default (web/src/theme/schemes.ts:36-37), star via swipe/button/`s`/menu, KEYMAP (web/src/lib/keys.ts:175-196), Inbox layout, `bound` API (web/src/api/bulk.ts:40-51), click-to-load embeds (web/src/index.css:395-443), referrer meta (web/index.html:10), filters.
  - Fix: add "(resolved; see Round 2 and what shipped)" beside each TODO; change line 5-6 to "Round-1 TODOs were resolved in round 2."

- [ ] **STALE** docs/ui-decisions.md "Next chunks" (lines 79-85): list is historical
  - Code does: all four steps done.
  - Fix: mark "(done)" or remove.

- [ ] **MISSING** docs/ui-decisions.md "Round 2 / Colors" (lines 100-101): the Aa menu picker differs
  - Code does: the short list / "More themes" / collapsed accessibility group is the Settings picker (web/src/theme/ThemePicker.tsx:93-155); the Aa menu picker is a flat grouped select of every theme (web/src/screens/AppearanceControls.tsx:77-114).
  - Fix: annotate "(Settings picker; the Aa menu has a compact grouped select)".


## CHANGELOG.md

- [ ] **WRONG** CHANGELOG.md Unreleased/Added (lines 82-83): `kipple fts-rebuild` CLI command does not exist
  - Doc says: "FTS5 item search with safe query building, rank keyset cursors and snippets; `kipple fts-rebuild`."
  - Code does: the CLI accepts only serve, api-password, password, restore, import, version (cmd/kipple/main.go:72-88; `git log -S fts-rebuild -- cmd` is empty). The rebuild is `POST /api/maintenance/fts-rebuild` (internal/api/api.go:216; internal/api/maintenance.go:5-7).
  - Fix: replace "`kipple fts-rebuild`" with "`POST /api/maintenance/fts-rebuild` (manual index rebuild)". Also grep other docs for `kipple fts-rebuild`.

- [ ] **WRONG** CHANGELOG.md Unreleased/Added (line 13): the web client does not send `expect_total`
  - Doc says: "(the frontend will send the total its preview showed, so running feed by feed cannot slip a moved library past the confirm rule)".
  - Code does: the server supports `expect_total` (internal/api/autoread.go:111-118, 191-195) but the web request type has only `feed_id` and `days`, `runAutoRead` adds only `confirm`, and nothing in web/src mentions `expect_total` or `total_changed` (web/src/api/autoRead.ts:14-27; web/src/screens/AutoReadCatchUp.tsx:104).
  - Fix: "(API only for now: the web client does not send it yet)" or wire the frontend.

- [ ] **WRONG** CHANGELOG.md Unreleased/Added (lines 67-70): security headers not all "on every response"
  - Doc says: "Security headers on every response ... plus `Referrer-Policy: no-referrer`, `Permissions-Policy`, `Cross-Origin-Opener-Policy`, `Cross-Origin-Resource-Policy`, `nosniff`, and HSTS..."
  - Code does: only Referrer-Policy, nosniff, `X-Frame-Options: DENY` (not listed) and HSTS (https only) go on every response; Permissions-Policy and COOP only on HTML; CORP only on `/api/` and `/img/`; assets get `frame-ancestors 'none'` as CSP. (evidence: internal/httpx/headers.go:80-89, 138-162)
  - Fix: "...`Referrer-Policy: no-referrer`, `X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY` and HSTS (https only) on every response; `Permissions-Policy` and `Cross-Origin-Opener-Policy` on pages; `Cross-Origin-Resource-Policy: same-origin` on `/api/` and `/img/`; `upgrade-insecure-requests` only when the effective scheme is https."

- [ ] **STALE** CHANGELOG.md Unreleased/Added (line 31, contradicts line 161): device eviction rule superseded
  - Doc says: "At most 50 devices (the least recently seen is evicted)".
  - Code does: the cap evicts only devices unseen for 30 days, never the session's own; when it cannot make room the client gets an unsaved default device (internal/store/devices.go:20-22, 162-167).
  - Fix: "At most 50 devices (only devices unseen for 30 days are evicted, see Changed)".

- [ ] **STALE** CHANGELOG.md Unreleased/Added (line 26, superseded by line 247): trim order for muted items
  - Doc says: muted items "trimmed before real items (`ORDER BY (muted_by IS NULL) DESC, sort_at DESC, id DESC`)".
  - Code does: muted and real ranked separately; muted keep the newest `min(muted, max(N/5, N-real))`, real items keep the rest (internal/store/retention.go:33-52, 110-111).
  - Fix: "counted against the retention cap but kept under their own allowance (the newest `max(N/5, N - real)` muted items; real items keep the rest)".

- [ ] **STALE** CHANGELOG.md Unreleased/Added (line 153, superseded by line 158): prefix rule
  - Doc says: "The last word (at least 3 characters, 2 for CJK) is a prefix while the text does not end in a space (search-as-you-type)."
  - Code does: the last word is a prefix only with `typing=1`, or an explicit `word*`; at most 3 prefixes and 12 terms (internal/store/searchquery.go:28-50, 170; internal/api/items.go:91).
  - Fix: "With `typing=1` (search-as-you-type), the last word (at least 3 runes, 2 for CJK) is a prefix while the text does not end in a space."

- [ ] **STALE** CHANGELOG.md Unreleased/Fixed (line 233, superseded by line 346): WebP refusal rule
  - Doc says: "a file with meta prefix codes ... is not thumbnailed".
  - Code does: meta prefix codes are priced with an upper bound (at most 2,600 groups) and refused only when over the decode ceiling (internal/imgproxy/thumbwebp.go:9-28, 334).
  - Fix: add "(later relaxed: meta prefix codes are priced with an upper bound and refused only over the ceiling, see below)" or drop the clause.

- [ ] **STALE** CHANGELOG.md Unreleased/Added (line 15): search order no longer kept per browser
  - Doc says: "sort by relevance, newest or oldest (kept per browser)".
  - Code does: synced through device profile key `client.search_order`, with a one-time migration of the old localStorage key (web/src/lib/devicePrefs.ts:50-68, 181-186; internal/api/devices.go:160).
  - Fix: "(synced per device through `client.search_order`)".

- [ ] **STALE** CHANGELOG.md Unreleased/Added (line 52): layout names outdated
  - Doc says: "five list layouts (Magazine, Cards, Compact, Inbox, Headlines)".
  - Code does: labels are Editorial, Cards, Compact, Inbox, Email - Compact (web/src/layouts/magazine.tsx:92; headlines.tsx:51).
  - Fix: "five list layouts (Editorial, Cards, Compact, Inbox, Email - Compact; ids `magazine` and `headlines` unchanged)".

- [ ] **STALE** CHANGELOG.md Unreleased/Added (lines 115-117): `ui.reading_density` values and `oled` theme superseded
  - Doc says: `ui.reading_density` (`compact`, `comfortable`, `relaxed`); "`oled` theme (true black...)".
  - Code does: density also takes `dense`, `snug`, `standard`, `airy`; `oled` is only an alias read as `midnight` (internal/api/settingsmeta.go:162, 256, 266-267; internal/store/uibootstrap.go:67-71).
  - Fix: add "(later extended, see `ui.theme` above)" to line 115; line 117: "`oled` theme (true black; now an alias of `midnight`)".

- [ ] **STALE** CHANGELOG.md Unreleased/Added (lines 122-126, superseded by line 271): Reader hold rule
  - Doc says: "a new item of a full-text feed is left out ... until its extraction has finished ... or 30 s have passed".
  - Code does: only items whose effective full-text mode is on (incl. `fetch.fulltext_all`) and that are pending in the extraction pool are held; deferred items are served at once (internal/store/fulltextmode.go:139-142; internal/greader/api.go:60-77).
  - Fix: "a new item still pending in the full-text extraction pool (effective mode on) is left out ... until its extraction finishes or 30 s have passed...".

- [ ] **STALE** CHANGELOG.md Unreleased/Added (line 128): self-check list misses porter
  - Doc says: probes "FTS5 (unicode61, `snippet`, `bm25`)".
  - Code does: probes `porter unicode61 remove_diacritics 2`, snippet, bm25, rank (internal/store/selfcheck.go:25-28).
  - Fix: "FTS5 (porter over unicode61 with diacritic folding, `snippet`, `bm25`, `rank`)".

- [ ] **STALE** CHANGELOG.md Unreleased/Fixed (lines 326-327): "inline" extraction no longer exists
  - Doc says: "Inline full-text extraction is capped at 4 articles at once across all workers (`Options.FulltextGlobal`)".
  - Code does: extraction runs in the background pool; `FulltextGlobal` is the pool size (internal/sched/sched.go:53; internal/sched/fulltext.go:145-150).
  - Fix: "Full-text extraction is capped at 4 articles at once (`Options.FulltextGlobal`, the extraction pool size)...".

- [ ] **STALE** CHANGELOG.md Unreleased (line 9): phase summary understates Unreleased
  - Doc says: "Phase 2 (reading UI backend) so far."
  - Code does: Unreleased also holds the whole web UI.
  - Fix: "Phase 2 (reading UI: backend and web app) so far."

- [ ] **STALE** CHANGELOG.md Unreleased/Added line 47 and Changed line 166: duplicate per-host image fetch limit
  - Code does: one limit (internal/imgproxy/imgproxy.go:55-56).
  - Fix: delete the per-host sentence from line 166.

- [ ] **STALE** CHANGELOG.md Unreleased/Fixed lines 257 and 259: overlapping archive-feed entries
  - Code does: one feature (internal/store/subs.go:316-368; internal/api/feedadmin.go:481-487).
  - Fix: merge into one entry: the API 409 `archive_has_starred` plus the batch `UnsubscribeSkipped` behavior (and note the Reader API keeps the archive silently, see design §6.9 finding).

- [ ] **STALE** CHANGELOG.md Unreleased/Fixed (lines 290-293): new endpoint filed under Fixed
  - Doc says: "`POST /api/backup` is now an asynchronous job ... `GET /api/backup/jobs/{id}`".
  - Code does: a behavior change plus a new route (internal/api/api.go:231).
  - Fix: move to Changed, or put `GET /api/backup/jobs/{id}` under Added.

- [ ] **MISSING** CHANGELOG.md release sections: two pre-release tags have no sections
  - Doc says: only `[Unreleased]` and `[0.1.0]`, compare link `v0.1.0...HEAD`.
  - Code does: annotated tags `v0.2.0-alpha.1` (4d14ca8, "web UI, review fixes, backup export, migrations 0002-0003", deployed to Host-A 2026-09-25) and `v0.2.0-alpha.2` (b74170d, "real-device testing fixes, second review round") exist (`git tag -n3`).
  - Fix: add `## [0.2.0-alpha.2] - 2026-09-25` and `## [0.2.0-alpha.1] - 2026-09-25` sections (or a note in Unreleased naming what shipped in each) with compare links; `[Unreleased]` -> `compare/v0.2.0-alpha.2...HEAD`. Note migrations 0004 and 0005 are post-alpha.1.

- [ ] **MISSING** CHANGELOG.md Unreleased/Added: mark-read-on-scroll, warnings banner, first-run screen
  - Code does: commit c9a785e adds mark-read-on-scroll (setting `ui.mark_read_on_scroll`), a warnings banner fed by bootstrap `warnings` (`clock`, `snapshot`, `unread_cap`), a first-run empty state and sidebar links (web/src/screens/FirstRun.tsx:4; web/src/screens/ListPane.tsx; internal/api/bootstrap.go:77-90).
  - Fix: add "Web UI: mark read on scroll (setting), a warnings banner for the bootstrap `warnings` (clock skew, failing or stale snapshot, over 10,000 unread), and a first-run screen with Add feed and Import OPML."

- [ ] **MISSING** CHANGELOG.md Unreleased/Added (lines 99-100): two feed-admin endpoints not named
  - Code does: routes also include `POST /api/feeds/{id}/trimmed-unread/reset` and `POST /api/archive/purge-unstarred` (internal/api/api.go:242-243).
  - Fix: "delete, `POST /api/archive/purge-unstarred`, refresh, mark-fetch-read, `POST /api/feeds/{id}/trimmed-unread/reset`, fetch log and folder endpoints".

- [ ] **MISSING** CHANGELOG.md Unreleased/Changed (line 198): CI entry covers only Go
  - Code does: the web job also runs `npm run lint`, `npm test`, `npm run build`, `npm run contrast`, `npm audit --omit=dev --audit-level=high` (commit 9cc41c8; .github/workflows/ci.yml:91-96).
  - Fix: add "The web job runs lint, tests, the build, a theme contrast check and `npm audit` (high, production dependencies)."

- [ ] **MISSING** CHANGELOG.md Unreleased/Added (line 18 area): confirmations before destructive settings changes
  - Code does: lowering or zeroing `imgproxy.cache_mb` and lowering `retention.default` ask for confirmation; server-setting segmented controls apply only on an explicit choice (commit 9ee21fc).
  - Fix: add "Settings ask before a lower image cache size (which purges) or a lower retention (which trims); segmented settings apply on Enter, Space or click, not on arrow focus."

- [ ] **MISSING** CHANGELOG.md Unreleased/Changed: code-splitting perf change
  - Code does: Settings, Feeds, Health and the feed dialogs are lazy chunks; main chunk 672 kB -> 483 kB (gzip 209 -> 154 kB) (commit 4c870b2).
  - Fix: add "Web UI: Settings, Feeds, Health and the feed dialogs load on demand (main bundle 483 kB, 154 kB gzip, was 672/209)."

- [ ] **MISSING** CHANGELOG.md Unreleased/Added (line 32): two theme aliases not listed
  - Code does: `fern` -> `directory` and `cocoa` -> `cocoa-kraft` also validate (internal/store/uibootstrap.go:67-71).
  - Fix: append "(and the retired `fern` and `cocoa` names, read as `directory` and `cocoa-kraft`)".

- [ ] **MISSING** CHANGELOG.md Unreleased/Added (line 103): README not listed
  - Code does: README.md and docs/HF added (commit f72fc84).
  - Fix: add "a basic `README.md`".


## web/README.md

- [ ] **WRONG** web/README.md "Lists: layouts..." (lines 40-41, contradicts lines 116-118): Cards has a reader pane on wide screens
  - Doc says: Cards is "no reader pane, an article opens full width".
  - Code does: on a wide screen an article opened from a grid shows in the reader pane with the list beside it as one column; only a grid with nothing open fills the width (web/src/screens/ReaderRoute.tsx:217-221, 257-278).
  - Fix: "(a grid of 1 to 3 columns from the list's own width: under 600 px 1, under 900 px 2, else 3; on a wide screen an open article shows in the reader pane with the list beside it as one column)".

- [ ] **WRONG** web/README.md "Gestures (touch)" (line 53): swipe-back is not an edge swipe
  - Doc says: "Swipe from the left edge to go back from an article".
  - Code does: a rightward swipe starting at least 24 px from the left edge (iOS owns the edge); only in the full-screen (narrow) article; blocked on controls, media, horizontal scrollers, pinch zoom and text selection (web/src/gestures/tracking.ts:5, 25, 208; web/src/gestures/useSwipeBack.ts:20-33, 41-45; web/src/screens/ArticlePane.tsx:169-171).
  - Fix: "Swipe right on an article (starting away from the left edge, which iOS keeps for its own back gesture) to go back to the list you came from; phone layout only."

- [ ] **WRONG** web/README.md "Undo" (line 63): not every star is undoable
  - Doc says: "Every read, unread, star and bulk mark pushes an undo entry."
  - Code does: only a star made by a full left swipe pushes an undo entry; the row star button, `s`, row menu Star and article toolbar star do not (web/src/lib/itemActions.ts:105-120; web/src/screens/ListPane.tsx:509, 546-551, 689-690; web/src/screens/ArticlePane.tsx:120-125).
  - Fix: "Every read, unread and bulk mark pushes an undo entry; a star pushes one only when made by a full swipe (the star button, `s` and the menus toggle it directly)."

- [ ] **WRONG** web/README.md "Reading appearance" (lines 100-102, contradicts lines 163-175): `ui.*` keys are device-profile keys
  - Doc says: "the server's `ui.*` reader-menu keys are global, so today they only supply labels."
  - Code does: `ui.theme`, `ui.theme_day`, `ui.theme_night`, `ui.font_body`, `ui.list_density`, `ui.reading_density`, `ui.mark_read_on_scroll` sync through `PATCH /api/device` (web/src/lib/deviceSync.ts:69-103).
  - Fix: replace with "they sync to the server's device profile (see Device profile sync); the server metadata also supplies their labels."

- [ ] **WRONG** web/README.md "Device profile sync" (lines 174-175): Highlight keywords does sync
  - Doc says: "'Highlight keywords' and the local favorites fallback have no profile key and stay on the device."
  - Code does: syncs as `client.highlight_keywords`; only the favorites fallback is local (web/src/lib/deviceSync.ts:101, 157, 159-160).
  - Fix: "Only the local favorites fallback has no profile key and stays on the device."

- [ ] **WRONG** web/README.md "Local development" (lines 283-285): `placeholderApp` does not exist
  - Doc says: "Until `placeholderApp` in `internal/web/handler.go` is flipped, `/` redirects to `/_status`; open a deep link such as `/l/unread`."
  - Code does: no `placeholderApp`, no redirect; `GET /` serves the built `index.html`, or the status page when `web/dist` has no build; `/_status` and `/_status.js` always served (internal/web/handler.go:67-97).
  - Fix: "To try the production bundle through Go: `npm run build`, then `go run ./cmd/kipple serve` and open `/`. Without a build, `/` serves the status page, which is always at `/_status`."

- [ ] **WRONG** web/README.md "Reading appearance" (lines 93-95): Settings > Appearance does not include the font
  - Doc says: the Aa button "and Settings > Appearance" offer theme, font, text size and Density.
  - Code does: Settings > Appearance has theme, text size and Density only plus "Change the font from the Aa button"; the Aa menu also has "Highlight keywords" (web/src/screens/SettingsScreen.tsx:252-257; web/src/screens/AppearanceControls.tsx:248-252).
  - Fix: "the 'Aa' button (theme, font, text size, Density, Highlight keywords) and Settings > Appearance (theme, text size, Density; the font is only in the Aa menu)".

- [ ] **STALE** web/README.md "Layout" (line 27) and "Lists: layouts" (lines 39-43): old layout names
  - Code does: labels Editorial and "Email - Compact"; ids `magazine` and `headlines` (web/src/lib/devicePrefs.ts:7-17; web/src/layouts/magazine.tsx:92; web/src/layouts/headlines.tsx:51).
  - Fix: "Editorial (id `magazine`)" and "Email - Compact (id `headlines`)" in both places, matching line 104.

- [ ] **STALE** web/README.md "Keys" (lines 57-61): keymap gaps
  - Code does: `g g` also jumps to top (web/src/lib/keys.ts:91-92, 183); `Esc` stays active with single keys off (keys.ts:112-114); `v` is not bound in the full-screen article (web/src/screens/ArticlePane.tsx:149-151); `z` reaches an undo stack of 60 s, 2 min for bulk marks (web/src/lib/undo.ts:10-13).
  - Fix: "`Shift+G` bottom, `g g` or `Home` top"; "`?` and `Esc` always work"; "`z` undo (last 60 s, 2 min for bulk marks)"; "`v` in lists only".

- [ ] **STALE** web/README.md "Lists: layouts, gestures..." (line 28): pull to refresh is not pointer-based
  - Code does: pull to refresh uses touch events; row swipe and back swipe use pointer events (web/src/gestures/usePullToRefresh.ts:15-20, 70-73).
  - Fix: "(pointer events for row swipe and swipe back, touch events for pull to refresh; no gesture library)".

- [ ] **STALE** web/README.md "Stack notes" (lines 20-21): `internal/web` serves more
  - Doc says: "`internal/web` only serves `/assets/*` and `index.html`."
  - Code does: also `/_status` and `/_status.js`; every other GET gets `index.html` (internal/web/handler.go:68-84).
  - Fix: "`internal/web` serves `/assets/*`, `/_status(.js)`, and `index.html` for every other path, so anything in `public/`..."

- [ ] **STALE** web/README.md "Tests" (lines 289-292): suite list out of date; dev-proxy note misplaced
  - Code does: ~50 suites (f3, f5library, f5search, filters, devices, muted, highlights, deviceSync, undo, dnd, speech, theme, ...); `KIPPLE_DEV_BACKEND` is a dev-proxy setting (web/vite.config.ts:59-71).
  - Fix: move the `KIPPLE_DEV_BACKEND` sentence to the `npm run dev` row or Local development; "`npm test` runs every `src/**/*.test.ts(x)` suite (Vitest, jsdom, Testing Library, axe)".

- [ ] **STALE** web/README.md "Live updates" (lines 71-75 and 156-159): section appears twice
  - Fix: merge into one paragraph under Lists; add "Muted" to the views where the new-articles pill never appears (web/src/api/events.ts:138).

- [ ] **MISSING** web/README.md "Scripts" (lines 243-250): three npm scripts undocumented
  - Code does: `preview` (vite preview), `typecheck` (tsc --noEmit), `test:watch` (vitest) (web/package.json:9, 11, 13).
  - Fix: add three rows.

- [ ] **MISSING** web/README.md "Device settings" (lines 104-111): two controls not listed
  - Code does: "Lists and reading" also has "Thumbnails in Inbox" (Auto/Off) and "Show swipe tips again" (resets `peekSeen`); Single-key shortcuts is under its own "Keyboard" section (web/src/screens/SettingsScreen.tsx:295-309, 315-329).
  - Fix: add them; note Single-key shortcuts is under Settings > Keyboard.

- [ ] **MISSING** web/README.md "Gestures (touch)" (lines 51-55): several gesture rules undocumented
  - Code does: swipes are touch-only (web/src/gestures/SwipeRow.tsx:137-138); off on multi-column Cards grids (web/src/screens/ListPane.tsx:755-758); in Muted a right swipe means Restore (ListPane.tsx:418-421); a partial left swipe rests open on Star and More, a full left swipe stars (web/src/gestures/tracking.ts:175-184; ListPane.tsx:689); long press 500 ms (tracking.ts:42); first-run peek only on touch in a single-column list (ListPane.tsx:636-640); row menu has "Mute similar..." and muted rows show Star, Restore, Edit rule (web/src/layouts/parts.tsx:91-140); pull to refresh off in search (ListPane.tsx:623); in-app Reduce motion also turns animation off (web/src/lib/prefs.ts:184-193).
  - Fix: add a sentence covering each point.

- [ ] **MISSING** web/README.md "Undo" (line 66): toast durations
  - Code does: info toasts 8 s, toasts with an action 15 s, errors until dismissed (web/src/shell/toasts.tsx:52-58).
  - Fix: "Info and help toasts stay 8 s, a toast with an action 15 s, an error until dismissed".

- [ ] **MISSING** web/README.md "Bulk read API" (lines 77-78): shapes incomplete
  - Code does: `scope` can carry `fallback` (web/src/api/bulk.ts:14-16, 23-26); `bound.order` is `"date"|"oldest"` (bulk.ts:32); response can carry `ledger_ids` (web/src/api/types.ts:265-270); undo sends `{ids, ledger_ids?, read:false, reason:"bulk"}` (web/src/lib/itemActions.ts:44-48).
  - Fix: add these.

- [ ] **MISSING** web/README.md "Stack notes" (lines 8-9) and "Layout" (line 30): Radix and `src/ui` lists incomplete
  - Code does: DropdownMenu and Popover also used (web/src/layouts/parts.tsx:1; web/src/screens/AppearanceControls.tsx:2); `src/ui` also has FavStar.tsx, ResizeHandle.tsx, UnreadCount.tsx.
  - Fix: "(Collapsible, Dialog, DropdownMenu, Popover)"; add "FavStar, ResizeHandle (window splitter), UnreadCount".

- [ ] **MISSING** web/README.md "Settings" (lines 83-87): setting confirmations
  - Code does: some changes confirm first via `settingWarning` / `lib/settingGuards.ts` (web/src/screens/SettingField.tsx:28, 64-70); enum renderer offers a preset row with "Custom" (SettingField.tsx:20, 123).
  - Fix: add "changes that `lib/settingGuards.ts` flags ask for confirmation first."

- [ ] **MISSING** web/README.md "List header" (lines 118-119): Settings gear is wide-screen only
  - Code does: web/src/screens/ReaderRoute.tsx:109-113.
  - Fix: "and on a wide screen Settings has a gear beside them."

- [ ] **MISSING** web/README.md "Local development" (lines 265-266): seed script details
  - Code does: reads `KIPPLE_DEV_PORT` (default 7080), data in `<dir>\data` (web/scripts/seed.mjs:19-28).
  - Fix: add "`KIPPLE_DEV_PORT` changes the port."

## web/ACCESSIBILITY.md

- [ ] **WRONG** web/ACCESSIBILITY.md "Text and spacing" (line 36): 46rem cap only at Medium width
  - Doc says: "the article measure is capped at 46rem."
  - Code does: 46rem is only the Medium "Article width"; Narrow 34rem, Wide 62rem, Full 100% (web/src/lib/devicePrefs.ts:28-32; web/src/screens/ArticlePane.tsx:31-34, 240; web/src/index.css:236).
  - Fix: "the article column follows Article width (Narrow 34rem, Medium the density's measure capped at 46rem, Wide 62rem, Full)."

- [ ] **WRONG** web/ACCESSIBILITY.md "Pointer and keyboard" (line 44): not every target is 44 px
  - Code does: row controls (star, More) 32 px with a fine pointer, 44 px on coarse (web/src/index.css:354-358; web/src/layouts/parts.tsx:36, 72); filter chip Remove buttons 32 px (`size-8`, web/src/screens/filters/FilterEditor.tsx:167); headline rows 28-36 px with a mouse (index.css:373-386).
  - Fix: "44 px minimum targets on touch (row controls and dense rows are 32 px with a mouse, above WCAG 2.5.8's 24 px); 'Larger buttons' raises controls to 56 px." (or make the chip button 44 px).

- [ ] **WRONG** web/ACCESSIBILITY.md "Read aloud" (line 60): the Listen bar shows only one caveat
  - Doc says: the Listen bar shows the screen-lock caveat, the better-voices path, pause best effort, no word highlighting.
  - Code does: only "On iPhone, reading stops if the screen locks or you leave the app" (web/src/screens/ListenBar.tsx:93-95); Voices path in Settings > Accessibility (web/src/screens/SettingsScreen.tsx:165); pause/word-highlighting caveats appear nowhere in web/src.
  - Fix: "The Listen bar says reading stops if the screen locks or the app closes; Settings > Accessibility names the iOS Voices path." Drop the other two claims or implement them.

- [ ] **WRONG** web/ACCESSIBILITY.md "Pointer and keyboard" (line 47): many actions confirm, not just feed delete
  - Doc says: undo toasts replace confirm dialogs "except deleting a feed".
  - Code does: also confirm: filter delete (web/src/screens/filters/FiltersSection.tsx ~76), device Copy/Forget/make-default/reset, bulk feed delete, saved-search delete, image cache Clear, auto-read catch-up above `confirm_above` (web/src/screens/AutoReadCatchUp.tsx:34), setting warnings (web/src/screens/SettingField.tsx:64-70).
  - Fix: "Undo toast (15 s) for read, unread, swipe-star and bulk marks; destructive or irreversible actions (deleting feeds, filters or saved searches, device copy, forget or reset, clearing the image cache, a large auto-read catch-up) confirm instead."

- [ ] **WRONG** web/ACCESSIBILITY.md "Structure and focus" (line 11): more than one live region
  - Doc says: "one polite region for announcements".
  - Code does: a polite region and an assertive `role="alert"` region for errors (web/src/shell/toasts.tsx:113-129); the undo toast has its own persistent polite region (web/src/shell/UndoToast.tsx:14).
  - Fix: "persistent live regions (polite for announcements and the undo toast, assertive for errors), never one per item".

- [ ] **WRONG** web/ACCESSIBILITY.md "Structure and focus" (line 9): focus to article title only on the phone layout
  - Code does: only in the full-screen (narrow) article; in the wide reader pane focus stays on the list row (web/src/screens/ArticlePane.tsx:153, 158-162).
  - Fix: "to the article title when an article opens full screen (in the wide reader pane focus stays on its list row)".

- [ ] **STALE** web/ACCESSIBILITY.md "Cognitive" (line 54): the two items are the same thing
  - Code does: "Titles only in lists" sets the device layout to `headlines` (Email - Compact) (web/src/screens/SettingsScreen.tsx:221-230).
  - Fix: "'Titles only in lists' (Accessibility; it switches to the Email - Compact layout)".

- [ ] **MISSING** web/ACCESSIBILITY.md "Structure and focus" (line 8): axe list incomplete
  - Code does: axe also runs on search (f5search.test.tsx:116, screens.test.tsx:284), filters (filters/filters.test.tsx:117), devices (devices.test.tsx:92), muted (muted.test.tsx:150), saved searches (f5library.test.tsx:176), the `?` overlay (f2a.test.tsx:600), article embeds (f2a.test.tsx:837).
  - Fix: append "search, filters, devices, muted, saved searches, the shortcut overlay and article embeds".

## web/src/theme/README.md

- [ ] **WRONG** web/src/theme/README.md "How it works" (lines 11-12): the theme does reach the server
  - Doc says: "The choice lives in `localStorage` (`kipple.theme.v1`), never on the server".
  - Code does: syncs to the device profile as `ui.theme` (`system` or a scheme id), `ui.theme_day`, `ui.theme_night`; localStorage is only the instant-paint cache (web/src/lib/deviceSync.ts:21-24, 73-75, 108-117).
  - Fix: "The choice is part of the server's device profile (`ui.theme`, `ui.theme_day`, `ui.theme_night`, see lib/deviceSync.ts); `localStorage` (`kipple.theme.v1`, `{mode, fixed, day, night}`) is the instant-paint cache the boot script reads."

- [ ] **WRONG** web/src/theme/README.md "Verify" (lines 40-43): theme.test.ts does not repeat the full CVD check
  - Doc says: "`theme.test.ts` asserts the same in the test run."
  - Code does: theme.test.ts covers WCAG on bg and surface, toasts, highlights, Signal's deuteranopia pair and Carbon/Fountain, not the per-deficiency CVD threshold for Tracing, Carbon, Inkwell, Teletype (web/src/theme/theme.test.ts:50-119 vs web/scripts/contrast.mjs:69-75).
  - Fix: "`theme.test.ts` asserts the WCAG, toast, highlight, Signal and Carbon/Fountain checks; the full color-blind check is `npm run contrast` only." (or add the CVD loop to the test).

- [ ] **MISSING** web/src/theme/README.md "Verify" (lines 40-43) and WCAG table note (line 72): contrast script checks more
  - Code does: `npm run contrast` also requires 4.5:1 for text, text2, link, danger on surface; text on selection; text on the toast tint (18% accent into surface) with accent and danger borders at 3:1; text on the highlight tint (20% star into bg) with star underline at 3:1; Carbon/Fountain bg delta E >= 25 and accent delta E >= 40 (web/scripts/contrast.mjs:24-57, 87-88).
  - Fix: list these in "Verify".

- [ ] **MISSING** web/src/theme/README.md intro (lines 5-7): derived tokens not mentioned
  - Code does: index.css derives `--kp-toast-bg` and `--kp-hl-bg`, maps `--font-reading`, sets device tokens (`--kp-scale`, `--kp-reading-font`, `--kp-app-font`, `--kp-col`, density vars); `meta` token has no Tailwind utility (web/src/index.css:36-86; web/src/lib/prefs.ts:166-176).
  - Fix: add "Derived: `--kp-toast-bg`, `--kp-hl-bg` (index.css); `meta` is only used for `<meta name=theme-color>`."

- [ ] **MISSING** web/src/theme/README.md "How it works / Picker" (lines 22-24): picker details
  - Code does: offered schemes narrowed to ids the server lists in `ui.theme_day` options (web/src/theme/serverThemes.ts:10-20); the Aa menu has a compact grouped select with "Match my device" first (web/src/screens/AppearanceControls.tsx:77-114); the fold is labelled "Accessibility themes" (web/src/theme/ThemePicker.tsx:146).
  - Fix: add a sentence on each.

- [ ] **MISSING** web/src/theme/README.md "No flash" (lines 16-19): dev mode differs
  - Code does: in dev the boot script is inlined (web/vite.config.ts:35-39).
  - Fix: append "(inlined by the dev server)".


## README.md

- [ ] **STALE** README.md "Status" (lines 7-9): phase 2 alpha.2 is already deployed
  - Doc says: "Phase 1 ... is deployed. Phase 2 ... is built on the `phase-2` branch and being reviewed."
  - Code does: `v0.2.0-alpha.1` and `v0.2.0-alpha.2` are tagged and alpha.2 runs on Host-A (docs/HF/evidence/README.md:7-8); alpha 3 work is on phase-2; neither alpha is merged into main.
  - Fix: "Phase 1 (v0.1.0) and phase 2 alpha 2 (v0.2.0-alpha.2, reading UI) are deployed; alpha 3 (search, filters, image cache, backups) is on `phase-2`. Phase 3 (installable app, offline use) is next."

Other README claims (build and test commands, docs map, pointer to web/README) verified.

## docs/plan.md

- [ ] **MISSING** docs/plan.md (top, line 1): no phase status anywhere
  - Fix: add "Status (as of 2026-09-26)": phase 1 done (v0.1.0, 2026-09-25); phase 2 alpha.2 deployed, alpha 3 in review on `phase-2`; phases 3-4 not started.

- [ ] **MISSING** docs/plan.md "Phase 2" (lines 328-333): scope omits most of what shipped
  - Code does: phase 2 also shipped keyword filters (mute, mark_read, star, highlight), a Muted view, device profiles, stemmed FTS search with saved searches, auto-read after N days, image proxy with on-disk cache and thumbnails, export and restore, 20 themes and bundled fonts (internal/filter, internal/imgcache, internal/backup, migrations 0004-0005, internal/api/api.go:206-260).
  - Fix: append "Shipped beyond the original scope: ..." with that list and a pointer to CHANGELOG [Unreleased].

- [ ] **STALE** docs/plan.md "Phase 2" (line 328): component library
  - Doc says: "shadcn (Base UI default; `-b radix` optional)".
  - Code does: `radix-ui` ^1.6.7, no Base UI (web/package.json:35).
  - Fix: "shadcn on Radix (`radix-ui`)".

- [ ] **STALE** docs/plan.md "Phase 3" (lines 334-337): theme and font work listed as future
  - Doc says: "Seven themes, font settings..., subsetted self-hosted woff2 for the eleven bundled fonts (Charter from Butterick's release...)".
  - Code does: 20 schemes and font settings shipped in phase 2; fonts via @fontsource, no custom subsetting; Charter not vendored (web/src/theme/schemes.json; web/package.json:18-28; web/src/lib/fonts.ts:1-3).
  - Fix: remove themes and fonts from phase 3 (done in phase 2 via @fontsource; Charter system-only). Phase 3 = manifest, safe areas, service worker, Web Share.

- [ ] **STALE** docs/plan.md "Environment facts" (line 36): Kipple has no HTTPS port
  - Doc says: "Kipple: 7080 (http) and 7443 (https)".
  - Code does: one plain-HTTP listener on KIPPLE_ADDR; no ListenAndServeTLS (cmd/kipple/main.go:205-229).
  - Fix: "Kipple: 7080 (http only; TLS is terminated by the tunnel)".

- [ ] **STALE** docs/plan.md "Fetch layer" (line 124; contradicts line 175): scheduler tick
  - Doc says: "scheduler tick 60 s".
  - Code does: 30 s (internal/config/config.go:39; internal/sched/sched.go:221).
  - Fix: "scheduler tick 30 s".

- [ ] **STALE** docs/plan.md "Go libraries" (lines 137, 147): readability library and GOMEMLIMIT drifted
  - Doc says: `markusmobius/go-readabilityV2` v0.6.0; "`GOMEMLIMIT=96MiB`".
  - Code does: `codeberg.org/readeck/go-readability/v2 v2.1.2` (go.mod:6); compose example `GOMEMLIMIT=64MiB` (docker-compose.example.yml:23; plan line 204; design.md:195).
  - Fix: update the Readability row; 96MiB -> 64MiB.

- [ ] **STALE** docs/plan.md "Phase 1 step 7" (line 251): route names wrong
  - Doc says: "`/api/login`, `/status`, `/feeds`, `/refresh`, `/events`, `/opml/*`, `/healthz`".
  - Code does: `/api/auth/login`, `/api/status`, `/api/health/feeds`, `/api/refresh`, `/api/events`, `GET`/`POST /api/opml`, `/healthz`, status page `/_status` (internal/api/api.go:197-234; internal/web/handler.go:69).
  - Fix: substitute those paths.

- [ ] **STALE** docs/plan.md "C5" (lines 278-279; contradicts deploy.md:83): import command
  - Doc says: `docker compose run --rm kipple import /import/newsblur-export.opml`.
  - Code does: `import` opens the path as nonroot, which cannot read `/import`; stdin works (cmd/kipple/import.go:36-44).
  - Fix: "`docker compose run --rm -T --no-deps kipple import - < /home/user/newsblur-export.opml` (nonroot cannot read `/import`)".

- [ ] **STALE** docs/plan.md "C8" (lines 301-302): migration details alpha.1-specific
  - Doc says: "migrates (0002, 0003) after writing `pre-migration-1-3-<ns>.db`".
  - Fix: mark C8 "done at v0.2.0-alpha.1 (schema 1->3)" and point to deploy.md for alpha 3 (3->5).

- [ ] **STALE** docs/plan.md C3 vs docker-compose.example.yml (line 13): restart policy and `/import` mount disagree
  - Doc says: plan C3 `restart: unless-stopped` plus `/home/user:/import:ro`; the example has `restart: always` and no mount.
  - Fix: make C3 match what runs on Host-A; note in the example that there is no `/import` mount because nonroot cannot read it (use `import -`).

Verified: env var list at lines 211-215 matches config.go (13 vars); lockout 10/15 min; 24-char API password; `n` up to 100,000; API read inference off by default.

## docs/research/open-questions.md

- [ ] **WRONG** open-questions.md #16 (line 33): list endpoints do send ETags
  - Doc says: "No `ETag`/`Last-Modified` on `subscription/list` or `tag/list`, so NNW never sees a 304 there."
  - Code does: both send `ETag` = sha256(body)[:16] and answer a conditional GET with 304 (internal/greader/api.go:526-533; internal/greader/h_subs.go:54, 75, 89).
  - Fix: "Decided: ETag = hash of the rendered body on both endpoints (304 on a match), so it changes exactly when the list does; NNW's post-quickadd refetch always gets a 200 with the new feed."

- [ ] **WRONG** open-questions.md #29 (line 51): gofeed fallback never built
  - Doc says: "Fallback to the RSS/Atom/JSON sub-parsers on `ErrFeedTypeNotDetected` is implemented up front."
  - Code does: `ParseFeed` calls `gofeed.Parser.Parse` and returns its error; no fallback, no preamble handling (internal/fetch/parse.go:80-91; no `ErrFeedTypeNotDetected` in internal/).
  - Fix: "Not implemented: gofeed's detection error is returned as a parse error. Build the fallback if a real feed hits it (fetch_log shows the error)." (or implement it).

- [ ] **WRONG** open-questions.md #33 (line 55): endpoint paths do not exist
  - Doc says: "`curl -N https://rss.example.com/api/v1/events` ... polling `/api/v1/status`".
  - Code does: no `/api/v1`; routes are `/api/events` and `/api/status` (internal/api/api.go:201, 204).
  - Fix: replace the paths.

- [ ] **WRONG** open-questions.md #44 (line 76): HTTPS listener does not exist
  - Doc says: "Kipple serves HTTPS on 7443 with the Tailscale Let's Encrypt cert".
  - Code does: HTTP only (cmd/kipple/main.go:205-229).
  - Fix: "Decided: Kipple is HTTP-only on 7080; HTTPS comes from the tunnel. LAN tests use client B over http (ATS allows it); client A is tested through the tunnel."

- [ ] **STALE** open-questions.md #2 and #6 (lines 19, 23): the alpha.2 log answers them
  - Evidence: `client A/5060003` calls `GET /reader/api/0/token` and sends `T` on `edit-tag` (keys T,a,i) and on `POST stream/items/contents` (keys T,i,output) (docs/HF/evidence/client-a-alpha2-2026-09-26.log:23; docs/HF/evidence/README.md:25-28).
  - Fix: #2 -> "Answered (2026-09-26): client A (UA client A/5060003) fetches `/token` and sends a real `T` on POSTs; the header-or-T rule stays for other clients." #6 -> note "client A sends `output=json` and `T` on the contents POST (same log)".

- [ ] **STALE** open-questions.md #27 (line 49): the ledger is now purged
  - Doc says: "No purge in phase 1... Revisit with real numbers after a month."
  - Code does: nightly purge of ledger rows unseen for max(180 days, restore_days + 7), stubs after restore_days (internal/store/maint.go:27-31, 64-102).
  - Fix: "Decided (phase 2): ledger rows purge 180 days after the uid last appeared in the feed (never inside the restore window); stubs after `retention.restore_days`."

- [ ] **STALE** open-questions.md #32 (line 54): srcset no longer stripped
  - Code does: `srcset`, `sizes`, `media` allowed on `img` and `source`, candidates absolutized and proxied (internal/sanitize/policy.go:34; absolutize.go:73-117; rewrite.go:10, 48).
  - Fix: "Revisited in phase 2: srcset kept, each candidate resolved and proxied."

- [ ] **STALE** open-questions.md #46 and #52 (lines 83, 89): theme count and font source
  - Doc says: "all seven themes"; "Check the upstream TTF while subsetting" (Arvo).
  - Code does: 20 schemes; fonts prebuilt from @fontsource, no subsetting (web/src/theme/schemes.json; web/package.json:25).
  - Fix: #46 "all 20 schemes (at least one per group)"; #52 "Moot: Arvo comes from @fontsource/arvo; check its latin-ext files."

Verified: #1, #3 (n cap 100,000; stream.go:108), #6 cap 1,000 ids (stream.go:109), #28 Retry-After cap 24 h (fetch/backoff.go:21), #55 hold 30 s with 60 s max (greader/api.go:61-64), #14 bypass prefix.

## CLAUDE.md (decisions and non-goals vs what shipped)

- [ ] **WRONG** CLAUDE.md "Commands" (line 39): wrong dev port, no data directory
  - Doc says: "`go run ./cmd/kipple` (API on 127.0.0.1:8080)".
  - Code does: default listen `:7080` on all interfaces, default data dir `/data` (on Host-B `\data` on the current drive); the Vite proxy targets `http://127.0.0.1:7080` (internal/config/config.go:36-37; web/vite.config.ts:60; web/README.md:245, 272-276).
  - Fix: "Dev: `cd web && npm run seed` (Kipple on 127.0.0.1:7080 with sample feeds in %TEMP%\kipple-dev), or set `KIPPLE_ADDR=127.0.0.1:7080` and `KIPPLE_DATA=%TEMP%\kipple-dev` and run `go run ./cmd/kipple serve`; then `cd web && npm run dev` (Vite on 127.0.0.1:5173 proxies to 7080)."

- [ ] **WRONG** CLAUDE.md "Decisions / Themes" (line 24): 8 themes listed, 20 shipped
  - Doc says: "white, off-white, sepia, soft green, brown, dark, OLED dark (true black), follow-system."
  - Code does: 20 color schemes: 9 light (Paper, Linen, Newsprint, Parchment, Directory, Cocoa Kraft, Airmail, Stationery, Tissue), 4 dark (Graphite, Midnight, Cocoa Mid, Fountain), 7 accessibility (Foolscap, Tracing, Signal, Carbon, Lamplight, Inkwell, Teletype); follow system with separate day/night picks. Old ids are read-time aliases: white->paper, off-white->linen, sepia->parchment, soft-green->directory, brown->cocoa-kraft, dark->graphite, oled->midnight (web/src/theme/schemes.json; web/src/theme/README.md:3, 13; internal/store/uibootstrap.go:49-51, 64-71).
  - Fix: "**Themes:** 20 color schemes (web/src/theme/schemes.json is the source of truth) plus follow-system with separate day/night picks (default Paper/Midnight). The original seven names are aliases: white=Paper, off-white=Linen, sepia=Parchment, soft green=Directory, brown=Cocoa Kraft, dark=Graphite, OLED=Midnight." This is a "do not relitigate" decision that shipped differently; the owner should confirm the new wording.

- [ ] **WRONG** CLAUDE.md "Decisions / Fonts" (lines 20-23): bundled list off by two
  - Doc says: Charter bundled; 11 bundled faces.
  - Code does: faces bundled through @fontsource; Charter is **not** bundled (system-only); Atkinson Hyperlegible Next **is** bundled; default body is `ui-serif` (New York on Apple), then Literata (web/src/lib/fonts.ts:1-3, 21-40; web/package.json:18-28; web/src/index.css:56-57).
  - Fix: "Bundled via @fontsource (self-hosted, no CDN): Literata, Vollkorn, Gentium Book Plus, Source Serif 4, Arvo, Inter, Manrope, Source Sans 3, JetBrains Mono, Source Code Pro, Atkinson Hyperlegible Next. System when present: New York, Charter, SF Pro, SF Mono, Georgia, Menlo." (decision change, the owner to confirm).

- [ ] **WRONG** CLAUDE.md "Layout" (line 31): names a package that does not exist
  - Doc says: "`internal/` Go packages (fetch, store, greader, readability, stats)".
  - Code does: no `readability`; extraction is `internal/extract` (go.mod:6). Packages: api, auth, backup, clock, config, discover, events, extract, feedurl, fetch, filter, ftrun, greader, httpx, imgcache, imgproxy, lock, maint, opml, sanitize, sched, stats, store, web.
  - Fix: "(fetch, sched, store, greader, api, extract, imgproxy, imgcache, filter, backup, stats, ...)".

- [ ] **WRONG** CLAUDE.md "Decisions / Retention" (line 17): "Trim after fetch only" no longer holds
  - Code does: retention also runs when the global or a per-feed retention setting changes and on "Apply retention now" (`POST /api/retention/apply`); ledger purged after max(180 d, restore_days + 7); stubs after `retention.restore_days` (internal/api/settings.go:103, 125-137; internal/store/maint.go:27-31, 64-102).
  - Fix: "Trim after each fetch and when retention changes (settings change or Apply retention now). Trimmed ids and read state are kept for API consistency, purged once the item has been gone from its feed for 180 days (longer if restore_days needs it)." (decision change, the owner to confirm).

- [ ] **WRONG** CLAUDE.md "Layout" (line 35): committed docs break the "no hostnames" rule
  - Doc says: "No secrets or hostnames committed."
  - Code does: docs/plan.md (19 hits), docs/research/cloudflare-access-deploy.md (24), docs/design.md and others commit `rss.example.com`, `192.0.2.x` and the Tailscale name `host-a.tailnet.example`; code and config clean apart from test fixtures (grep `tailnet-name|192\.168\.|rss\.wptk\.org`). CLAUDE.md itself names `rss.example.com`.
  - Fix: scope the rule ("No secrets committed; no hostnames or IPs in code, config or examples; docs may name the deployment") or scrub the docs. the owner's call.

- [ ] **STALE** CLAUDE.md "Releases and CI" (lines 68-69): TODO already done
  - Doc says: "TODO when the phase 2 frontend deps land: add `npm audit --omit=dev`, ESLint and Vitest to the web job."
  - Code does: the web job runs `npm ci`, lint, test, build, contrast, `npm audit --omit=dev --audit-level=high` (.github/workflows/ci.yml:77-96).
  - Fix: "The web job runs lint, Vitest, build, the contrast check and `npm audit --omit=dev --audit-level=high`."

- [ ] **STALE** CLAUDE.md "Process" (line 55): themes and fonts listed under phase 3
  - Code does: themes, fonts and device profiles shipped on phase-2; no manifest or service worker yet.
  - Fix: "2 reading UI (incl. themes and fonts); 3 PWA (manifest, service worker, install, offline)".

- [ ] **STALE** CLAUDE.md "Layout" (line 33): final stage hedged
  - Doc says: "scratch/distroless".
  - Code does: `gcr.io/distroless/static-debian12:nonroot` (Dockerfile:34).
  - Fix: "... -> distroless static nonroot (uid 65532)".

- [ ] **MISSING** CLAUDE.md "Non-goals" (line 27): device profiles vs "no multi-user"
  - Code does: per-device appearance profiles on the single account (device cookie; cap 50; 5 new per session per day; theme, fonts, density, layouts per device) (internal/store/devices.go:17-22; internal/api/settingsmeta.go:369-373; internal/api/devices.go:39). Not multi-user, so no contradiction, but undocumented.
  - Fix: append "Per-device appearance profiles (one account, many browsers) are not multi-user."

- [ ] **MISSING** CLAUDE.md "Decisions / Refresh" (lines 13-15): subscribing from a sync app wakes the scheduler
  - Doc says: "API clients never trigger fetches."
  - Code does: a Reader API subscribe (quickadd, subscription/edit, import) that adds a feed wakes the scheduler, so the new (already due) feed is fetched on an immediate tick; `greader.subscribe_fetch_now` exists but nothing reads it (internal/greader/h_subs.go:255-258, 371-373; internal/sched/sched.go:304-310; internal/store/uibootstrap.go:44-46).
  - Fix: "API clients never trigger fetches of existing feeds; a feed added from a client is fetched on the next scheduler tick, which the add brings forward."

- [ ] **MISSING** CLAUDE.md "Deploy" (lines 49-50): exact bypass path
  - Code does: Reader API under `/api/greader.php` (bypassed); also answers root `/accounts/ClientLogin` and `/reader/api/0/*` (LAN "Reader" account type), which stay behind Access; feed icons under `/api/greader.php/icon/` (internal/greader/api.go:26, 180-202; internal/greader/h_subs.go:71).
  - Fix: "the Access bypass covers exactly `rss.example.com/api/greader.php` (Reader API and its `/icon/` URLs); root `/accounts/ClientLogin` and `/reader/api/0/*` answer too but stay behind Access."

Verified: Reader API only, no Fever code (no "fever" in internal/); 30-minute default (`refresh.interval_minutes`, 5-1440) with per-feed `interval_minutes`; retention options 50/100/250/500/1000/0, default 250, per-feed `retention`; stats events never deleted; stats recorder only on web opens and Reader stars; no Notification or Push API use (unread badge in-app only), so "no notifications" holds; no monitoring features; WAL SQLite; web embedded; one port 7080; the Deploy command.

## .env.example, docker-compose.example.yml, Dockerfile vs internal/config/config.go

Env-var table (code: internal/config/config.go; other `os.Getenv` calls are test-only):

| Var | Default in config.go | In .env.example? | Doc default | Match? | Validation in code |
|---|---|---|---|---|---|
| KIPPLE_ADDR | `:7080` | yes | `:7080` | yes | none |
| KIPPLE_DATA | `/data` | yes | `/data` | yes | none |
| KIPPLE_USERNAME | "" | yes (`owner`) | "required" | comment wrong (below) | 1-64 of `A-Za-z0-9._-` at account creation (cmd/kipple/account.go:61) |
| KIPPLE_PASSWORD | "" | yes | - | only read at first creation, undocumented | 5-256 for `kipple password` (internal/auth/auth.go:490) |
| KIPPLE_API_PASSWORD | "" | yes | unset | also applied later when no API password exists, undocumented | - |
| KIPPLE_PUBLIC_URL | "" | yes | empty | yes | none |
| KIPPLE_TRUSTED_PROXY_IPS | none | yes | empty | yes | each entry must parse as an IP or startup fails |
| TZ | `America/New_York` | yes | same | yes (description overclaims) | unknown zone stops `serve` |
| KIPPLE_SCHED_TICK | `30s` | yes | `30s` | yes | Go duration > 0 |
| KIPPLE_FETCH_WORKERS | 8 | yes | 8 | yes | int > 0 |
| KIPPLE_FETCH_PER_HOST | 2 | yes | 2 | yes | int > 0 |
| KIPPLE_LOG_LEVEL | info | yes | info | yes | debug/info/warn(ing)/error, else fails |
| KIPPLE_LOG_GREADER_FORMS | false | yes | unset/false | yes | strconv.ParseBool; e.g. `yes` fails startup |
| GOMEMLIMIT (Go runtime) | - | no | 64MiB in compose | n/a | - |
| KIPPLE_DEV_BACKEND / KIPPLE_DEV_DATA / KIPPLE_DEV_PORT | web dev scripts only (web/vite.config.ts:60; web/scripts/seed.mjs:19-20) | no | in web/README.md | n/a | - |
| KIPPLE_REAL_OPML / KIPPLE_REHEARSAL_DB | test-only (opml_test.go:137; migrate0004_test.go:256) | no | - | n/a | - |

- [ ] **WRONG** .env.example "Auth" (line 20): username comment misstates the effect
  - Doc says: "Single-user web login. Required before Kipple will serve the UI."
  - Code does: the UI is always served. Without KIPPLE_USERNAME and KIPPLE_PASSWORD no account is created: web login and the Reader API stay disabled and a WARN is logged. Both are read only when the account is first created (cmd/kipple/account.go:16-20, 39-42, 61).
  - Fix: "Web login, used only to create the single account on the first start (1-64 characters of A-Z a-z 0-9 . _ -). Without both, web login and the Reader API stay disabled. Changing them later has no effect: use `kipple password` to reset the password, and remove KIPPLE_PASSWORD from .env afterwards."

- [ ] **WRONG** .env.example "API password" (lines 24-26): when it is applied
  - Doc says: "Optional initial Google Reader API password. If unset, run `kipple api-password`..."
  - Code does: also applied on a later start if the account exists but has no API password yet; never overwrites (cmd/kipple/account.go:26-37).
  - Fix: append "Applied at start only while the account has no Reader API password; never replaces an existing one."

- [ ] **WRONG** .env.example "Time" (lines 49-52): TZ credited with the `tz` setting's work
  - Doc says: TZ sets time.Local "so log timestamps and local-time grouping follow it".
  - Code does: TZ sets only `time.Local` (log timestamps); daily stats and the 04:10 nightly job use the `tz` database setting (default America/New_York) (cmd/kipple/main.go:93-100; internal/store/stats.go:44; internal/store/maint.go:265; internal/api/settingsmeta.go:320).
  - Fix: "IANA zone for the process (log timestamps). Daily stats and the nightly 04:10 maintenance use the separate `tz` setting in Settings, not this variable."

- [ ] **STALE** .env.example (lines 9-11): placeholder note predates the embedded web build
  - Doc says: "Until the web app is built into the image, "/" serves the placeholder page."
  - Code does: the Dockerfile always builds and embeds the web app; the status page is served at `/` only for a Go build without `web/dist` (Dockerfile:4-21; internal/web/handler.go:88-97).
  - Fix: "The image embeds the web app at `/`. A Go build without `npm run build` serves the status page there instead. The status page (login, feed health, refresh, live events) is always at `/_status`."

- [ ] **STALE** docker-compose.example.yml (line 13) vs docs/plan.md C3: see the plan.md C3 finding (restart policy and `/import` mount). Fix in one place and mirror.

- [ ] **MISSING** .env.example: GOMEMLIMIT not documented
  - Code does: compose example sets `GOMEMLIMIT=64MiB` with `mem_limit: 256m` (docker-compose.example.yml:21-23); CLAUDE.md says ".env.example documents every variable".
  - Fix: add a commented "Go runtime" block: `# GOMEMLIMIT=64MiB  # set in compose; soft Go heap limit (SQLite's heap is outside it)`.

- [ ] **MISSING** .env.example "Networking" (line 30): KIPPLE_PUBLIC_URL gates feed icons
  - Code does: with KIPPLE_PUBLIC_URL empty no `iconUrl` is sent even when `greader.icon_urls` is on; icon URLs are `<PUBLIC_URL>/api/greader.php/icon/<id>-<hash>` (internal/greader/h_subs.go:62-72). (Note: `feed_icons` is never populated today, see §9 finding.)
  - Fix: append "If empty, sync apps get no feed icons."

Dockerfile verified: node:22-alpine -> golang:1.27-alpine (go.mod `go 1.27`) -> `gcr.io/distroless/static-debian12:nonroot` (uid 65532), `/data` pre-created and owned, `EXPOSE 7080`, `ENTRYPOINT ["/kipple"]`, `CMD ["serve"]`, no HEALTHCHECK.

## SECURITY.md and .github/pull_request_template.md

- [ ] **STALE** SECURITY.md "Supported versions" (line 13): the deployed build is not on main
  - Doc says: "Only the latest tagged release (or the current `main`) receives fixes."
  - Code does: deployed tags `v0.2.0-alpha.*` are on `phase-2`, not in `main` (`git merge-base --is-ancestor v0.2.0-alpha.2 origin/main` -> false).
  - Fix: "Only the latest tag deployed to Host-A (currently a `phase-2` prerelease) or the active development branch receives fixes."

- [ ] **MISSING** SECURITY.md "Automated checks" (line 17): npm audit gate not listed
  - Code does: CI also runs `npm audit --omit=dev --audit-level=high`; gosec gates only on high/high (.github/workflows/ci.yml:60-65, 96).
  - Fix: "...gosec (gates on high severity and high confidence), gitleaks, `npm audit --omit=dev` (high) and a Trivy image scan...".

- [ ] **MISSING** .github/pull_request_template.md "Checklist" (line 8): web and gofmt checks missing
  - Doc says: "`go vet ./...` and `go test ./...` pass".
  - Code does: CI also requires gofmt, `npm run lint`, `npm test`, `npm run build`, `npm run contrast` (.github/workflows/ci.yml:30-40, 91-95).
  - Fix: "- [ ] `gofmt -l .` empty, `go vet ./...`, `go test ./...`; for web changes `npm run lint && npm test && npm run build && npm run contrast` (in `web/`)".

