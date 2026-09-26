# fetch-prior-art

# Fetch-layer prior art: Miniflux, yarr, FreshRSS, Feedbin (+ Feedly docs), read from source on 2026-09-24

All Go/PHP/Ruby excerpts below were pulled with `curl` from `raw.githubusercontent.com` at the default branches (`miniflux/v2@main`, `nkanaev/yarr@master`, `FreshRSS/FreshRSS@edge`, `feedbin/feedbin@master`, `feedbin/feedkit@master`). "Verified" = read in code. "Inferred" is marked as such.

---

## 1. Miniflux (Go)

### 1.1 Scheduler and worker pool

`internal/cli/scheduler.go` — one goroutine ticks every `POLLING_FREQUENCY` and builds a batch; a second ticks every `CLEANUP_FREQUENCY_HOURS`:

```go
func feedScheduler(store *storage.Storage, pool *worker.Pool, frequency time.Duration, batchSize, errorLimit, limitPerHost int) {
	for range time.Tick(frequency) {
		jobs, err := store.NewBatchBuilder().
			WithBatchSize(batchSize).
			WithErrorLimit(errorLimit).
			WithoutDisabledFeeds().
			WithNextCheckExpired().
			WithLimitPerHost(limitPerHost).
			FetchJobs()
		...
			pool.Push(jobs)
```

`internal/storage/batch.go` — the batch query (Postgres):

```go
query := `SELECT id, user_id, feed_url FROM feeds`
// conditions: "parsing_error_count < $n" (only if limit > 0), "next_check_at < now()", "disabled IS false"
query += " ORDER BY next_check_at ASC"
if b.batchSize > 0 { query += " LIMIT " + strconv.Itoa(b.batchSize) }
```

Per-host cap is applied *in Go while scanning rows*, keyed by `urllib.Domain(job.FeedURL)`; feeds over the cap are skipped for this batch (`nbSkippedFeeds++`) and picked up on a later tick. It is a per-batch cap, not a true concurrency limiter.

`internal/worker/pool.go` / `worker.go` — `queue: make(chan model.Job)` (unbuffered); `NewPool(store, nbWorkers)` starts `WORKER_POOL_SIZE` goroutines, each loops `feedHandler.RefreshFeed(w.store, job.UserID, job.FeedID, false)`. Concurrency cap = worker count.

Defaults (`internal/config/options.go`, verified against the docs page):

| Option | Default |
|---|---|
| `POLLING_FREQUENCY` | 60 min |
| `BATCH_SIZE` | 100 |
| `WORKER_POOL_SIZE` | 16 |
| `POLLING_SCHEDULER` | `round_robin` (other: `entry_frequency`) |
| `POLLING_PARSING_ERROR_LIMIT` | 3 |
| `POLLING_LIMIT_PER_HOST` | 0 (disabled) |
| `SCHEDULER_ROUND_ROBIN_MIN_INTERVAL` / `MAX_INTERVAL` | 60 min / 1440 min |
| `SCHEDULER_ENTRY_FREQUENCY_MIN_INTERVAL` / `MAX_INTERVAL` / `FACTOR` | 5 min / 24 h / 1 |
| `HTTP_CLIENT_TIMEOUT` | 20 s |
| `HTTP_CLIENT_MAX_BODY_SIZE` | 15 MiB (`parsedInt64Value * 1024 * 1024`) |
| `HTTP_CLIENT_USER_AGENT` | "" → default UA |
| `CLEANUP_FREQUENCY_HOURS` | 24 |
| `CLEANUP_ARCHIVE_READ_DAYS` / `UNREAD_DAYS` | 60 / 180 |
| `CLEANUP_ARCHIVE_BATCH_SIZE` | 10000 |
| `FORCE_REFRESH_INTERVAL` | 30 min (UI "refresh all" throttle) |

Default UA (`internal/config/config.go:11`):
```go
var defaultHTTPClientUserAgent = "Mozilla/5.0 (compatible; Miniflux/" + version.Version + "; +https://miniflux.app)"
```
Commit "Fix default User-Agent regression" (fixes #2188/#2189) records that falling back to Go's `Go-http-client/1.1` was treated as a bug.

### 1.2 Next-check computation (`internal/model/feed.go`)

```go
func (f *Feed) ScheduleNextCheck(weeklyCount int, refreshDelay time.Duration) time.Duration {
	interval := config.Opts.SchedulerRoundRobinMinInterval()
	if config.Opts.PollingScheduler() == SchedulerEntryFrequency {
		if weeklyCount <= 0 {
			interval = config.Opts.SchedulerEntryFrequencyMaxInterval()
		} else {
			interval = (7 * 24 * time.Hour) / time.Duration(weeklyCount*config.Opts.SchedulerEntryFrequencyFactor())
			interval = min(interval, config.Opts.SchedulerEntryFrequencyMaxInterval())
			interval = max(interval, config.Opts.SchedulerEntryFrequencyMinInterval())
		}
	}
	// Use the RSS TTL field, Retry-After, Cache-Control or Expires HTTP headers if defined.
	interval = max(interval, refreshDelay)
	// Limit the max interval value for misconfigured feeds.
	switch config.Opts.PollingScheduler() {
	case SchedulerRoundRobin:     interval = min(interval, config.Opts.SchedulerRoundRobinMaxInterval())
	case SchedulerEntryFrequency: interval = min(interval, config.Opts.SchedulerEntryFrequencyMaxInterval())
	}
	f.NextCheckAt = time.Now().Add(interval)
	return interval
}
```

`WeeklyFeedEntryCount` (storage/feed.go) estimates a virtual weekly count from `max(published_at)-min(published_at)` over the last week's entries.

Error bookkeeping on the same struct:
```go
func (f *Feed) WithTranslatedErrorMessage(message string) { f.ParsingErrorCount++; f.ParsingErrorMsg = message }
func (f *Feed) ResetErrorCounter() { f.ParsingErrorCount = 0; f.ParsingErrorMsg = "" }
```

### 1.3 Request builder (`internal/reader/fetcher/request_builder.go`)

- `WithETag(etag)` sets `If-None-Match` only if non-empty; `WithLastModified` sets `If-Modified-Since` only if non-empty. Values are stored and replayed **verbatim** (a `W/"..."` weak ETag is echoed as-is — correct per RFC 9110 §13.1.2, which requires weak comparison for If-None-Match).
- `WithUserAgent(userAgent, defaultUserAgent)` — per-feed UA, else global default.
- Dialer: `Timeout: 10 * time.Second, KeepAlive: 15 * time.Second`. Transport: `ForceAttemptHTTP2: true, MaxIdleConns: 50, IdleConnTimeout: 10s`; `client := &http.Client{Timeout: r.clientTimeout}` (20 s default). Redirects: Go default (followed, max 10) unless `WithoutRedirects()` which uses `http.ErrUseLastResponse`.
- Private-network refusal done in `Dialer.Control` after DNS resolution (anti DNS-rebinding).
- Per-feed `DisableHTTP2` exists explicitly "to avoid fingerprinting" (commit message); `IgnoreTLSErrors` adds insecure cipher suites + `InsecureSkipVerify`.
- Headers set on every request:
```go
if r.disableCompression { req.Header.Set("Accept-Encoding", "identity") } else { req.Header.Set("Accept-Encoding", "br,gzip") }
if req.Header.Get("Accept") == "" { req.Header.Set("Accept", defaultAcceptHeader) }
req.Header.Set("Connection", "close")
```
with `defaultAcceptHeader = "application/xml,application/atom+xml,application/rss+xml,application/rdf+xml,application/feed+json,text/html,*/*;q=0.9"`.

Because `Accept-Encoding` is set explicitly, Go does **not** transparently decode; `response_handler.go::getReader` wraps manually (`NewBrotliReadCloser` / `NewGzipReadCloser` in `encoding_wrappers.go`) and then applies the size cap **after** decompression:
```go
return http.MaxBytesReader(nil, reader, maxBodySize)
```
Go's own doc (`net/http/transport.go`): "If the Transport requests gzip on its own and gets a gzipped response, it's transparently decoded in the Response.Body. However, if the user explicitly requested gzip it is not automatically uncompressed."

### 1.4 Response handler (`internal/reader/fetcher/response_handler.go`)

```go
func (r *ResponseHandler) LastModified() string { if r.httpResponse.Header.Get("Expires") == "0" { return "" }; return r.httpResponse.Header.Get("Last-Modified") }
func (r *ResponseHandler) ETag() string         { if r.httpResponse.Header.Get("Expires") == "0" { return "" }; return r.httpResponse.Header.Get("ETag") }
```
(`Expires: 0` = "feed does not want any cache" → validators discarded.)

```go
func (r *ResponseHandler) ParseRetryDelay() time.Duration {
	retryAfterHeaderValue := r.httpResponse.Header.Get("Retry-After")
	if retryAfterHeaderValue != "" {
		if seconds, err := strconv.Atoi(retryAfterHeaderValue); err == nil { return time.Duration(seconds) * time.Second }
		if t, err := time.Parse(time.RFC1123, retryAfterHeaderValue); err == nil { return time.Until(t).Truncate(time.Second) }
	}
	return 0
}
func (r *ResponseHandler) IsRateLimited() bool { return r.httpResponse != nil && r.httpResponse.StatusCode == http.StatusTooManyRequests }
func (r *ResponseHandler) IsModified(lastEtagValue, lastModifiedValue string) bool {
	if r.httpResponse.StatusCode == http.StatusNotModified { return false }
	if r.ETag() != "" { return r.ETag() != lastEtagValue }
	if r.LastModified() != "" { return r.LastModified() != lastModifiedValue }
	return true
}
```
`CacheControlMaxAge()` parses `max-age=`; `Expires()` parses RFC1123 and rounds up to the next minute.

`ReadBody(maxBodySize)`: `*http.MaxBytesError` → `error.http_response_too_large`; zero bytes → `error.http_empty_response_body`.

`LocalizedError()` classification order: (1) transport error: `isSSLError` (`x509.UnknownAuthorityError`, `x509.HostnameError`, `x509.InsecureAlgorithmError`) → `error.tls_error`; `isNetworkError` (`*url.Error`, `io.EOF`, `*net.OpError`) → `error.network_operation`; `os.IsTimeout` → `error.network_timeout`; else `error.http_client_error`. (2) Cloudflare challenge: `StatusCode == 403 && cf-mitigated == "challenge" && Content-Type text/html` → `error.http_cloudflare_challenge`. (3) status map: 401, 403, 429, 404, 410 (same message as 404), 500, 502, 503, 504, then any ≥400 generic. (4) non-304 with `ContentLength == 0` → empty body error.

### 1.5 Refresh flow (`internal/reader/handler/handler.go::RefreshFeed`)

Order of operations (verified):
1. Load feed; if `entry_frequency` scheduler, compute `weeklyEntryCount`.
2. `originalFeed.CheckedNow(); originalFeed.ScheduleNextCheck(weeklyEntryCount, time.Duration(0))` — **before** the HTTP request, so an error path already has `next_check_at = now + min interval`.
3. Build request; `ignoreHTTPCache := originalFeed.IgnoreHTTPCache || forceRefresh`; validators are sent only when not ignoring cache.
4. `if responseHandler.IsRateLimited() { retryDelay := responseHandler.ParseRetryDelay(); calculatedNextCheckInterval := originalFeed.ScheduleNextCheck(weeklyEntryCount, retryDelay) ... }` — then falls through to `LocalizedError()` which is non-nil for 429, so **a 429 still increments `parsing_error_count`** via `getTranslatedLocalizedError` → `WithTranslatedErrorMessage` → `store.UpdateFeedError` (writes `parsing_error_msg, parsing_error_count, checked_at, next_check_at`).
5. `if store.AnotherFeedURLExists(userID, originalFeed.ID, responseHandler.EffectiveURL()) → ErrDuplicatedFeed` (error counted).
6. `if ignoreHTTPCache || responseHandler.IsModified(etag, lastModified)`: read body, `parser.ParseFeed(responseHandler.EffectiveURL(), ...)`; then
```go
refreshDelay := max(feedTTLValue, cacheControlMaxAgeValue, expiresValue)
calculatedNextCheckInterval := originalFeed.ScheduleNextCheck(weeklyEntryCount, refreshDelay)
...
updateExistingEntries := forceRefresh || (!originalFeed.Crawler && !originalFeed.IgnoreEntryUpdates)
newEntries, storeErr := store.RefreshFeedEntries(originalFeed.UserID, originalFeed.ID, originalFeed.Entries, updateExistingEntries)
...
originalFeed.EtagHeader = responseHandler.ETag()
originalFeed.LastModifiedHeader = responseHandler.LastModified()
```
   else (304 / unchanged validators):
```go
// Last-Modified may be updated even if ETag is not. In this case, per
// RFC9111 sections 3.2 and 4.3.4, the stored response must be updated.
if responseHandler.LastModified() != "" { originalFeed.LastModifiedHeader = responseHandler.LastModified() }
```
7. `originalFeed.ResetErrorCounter()`; `store.UpdateFeed(originalFeed)`.

**Redirects / feed_url update (verified by grep of every `FeedURL =` and `EffectiveURL` in handler.go):** `CreateFeed` sets `subscription.FeedURL = responseHandler.EffectiveURL()` (line 181) — i.e. at subscription time the *final* URL after any redirect (301 or 302, Go follows both) is persisted. `RefreshFeed` uses `EffectiveURL()` only for the duplicate check (line 276) and as the parse base URL (line 295); it **never** rewrites `originalFeed.FeedURL`. So Miniflux follows redirects on every poll and does not migrate the stored URL after a 301 discovered later. Issue #1387 ("How should Miniflux deal with 302 responses for a feed?") reports exactly the creation-time behavior ("Miniflux updates the feed's URL upon receiving a 302") and was closed with 0 comments. Issue #3412 (301 reported as 403): maintainer fguillot: "This website returns different responses depending on the client. It's easy to distinguish an HTTP request made by the standard Go HTTP client from one made by a web browser, based on the TLS fingerprint. Cloudflare returns a 403 status code with a CAPTCHA in the response body before sending the 301 redirect." (headers showed `Cf-Mitigated: challenge` — the origin of the Cloudflare detection above).

**Error limit / disabling:** the batch builder excludes `parsing_error_count >= POLLING_PARSING_ERROR_LIMIT` (3). There is no automatic reset or exponential backoff; recovery paths are: (a) manual per-feed refresh (resets on success), (b) UI "Refresh all" (`internal/ui/feed_refresh.go::refreshAllFeeds` builds the batch **without** `WithErrorLimit`, throttled by `FORCE_REFRESH_INTERVAL`), (c) CLI `-reset-feed-errors` → `UPDATE feeds SET parsing_error_count=0, parsing_error_msg=''`. Feeds are not auto-`disabled`; they just stop being scheduled.

### 1.6 Entry hash / dedup

RSS (`internal/reader/rss/adapter.go`):
```go
// The RSS 2.0 spec requires <guid> to uniquely identify the item, but
// some feeds ship the same GUID for every entry. Keep the first
// occurrence stable (so existing stored entries still match) and
// disambiguate later collisions using the entry URL or, as a last
// resort, the item position.
switch {
case item.GUID.Data != "":
	n := seenGUIDs[item.GUID.Data]
	seenGUIDs[item.GUID.Data] = n + 1
	switch {
	case n == 0:          entry.Hash = crypto.SHA256(item.GUID.Data)
	case entry.URL != "": entry.Hash = crypto.SHA256(item.GUID.Data + "|" + entry.URL)
	default:              entry.Hash = crypto.SHA256(item.GUID.Data + "|" + strconv.Itoa(n))
	}
case entryURL != "":  entry.Hash = crypto.SHA256(entryURL)
default:              entry.Hash = crypto.SHA256(entry.Title + entry.Content)
}
```
Note `entryURL` here is the raw item link before absolutization/tracking-param removal (the `urlcleaner` runs later in the processor), so the hash is stable even if cleaning rules change.

Atom 1.0 (`atom_10_adapter.go`): `for _, value := range []string{atomEntry.ID, atomEntry.Links.originalLink()} { if value != "" { entry.Hash = crypto.SHA256(value); break } }`.
JSON Feed (`json/adapter.go`): `[]string{item.ID, item.URL, item.ExternalURL, item.ContentText + item.ContentHTML + item.Summary}`, first non-empty after TrimSpace.

Storage (`internal/storage/entry.go`, schema `unique (feed_id, hash)` in `internal/database/migrations.go`):
- `entryExists`: `SELECT true FROM entries WHERE feed_id=$1 AND hash=$2 LIMIT 1`.
- `createEntry` is guarded: `WHERE NOT EXISTS (SELECT 1 FROM entry_tombstones WHERE feed_id=$9 AND hash=$2)`; `ErrEntryTombstoned` is swallowed in `RefreshFeedEntries`.
- `updateEntry` comment: "we do not update the published date because some feeds do not contains any date, it default to time.Now() which could change the order of items on the history page."
- `IsNewEntry` = not in `entries` and not in `entry_tombstones`.
- `RefreshFeedEntries` uses one transaction per entry.

Ordering: processor iterates `slices.Backward(feed.Entries)` "Processing older entries first ensures that their creation timestamp is lower than newer entries." Google Reader API: `CrawlTimeMsec: strconv.FormatInt(entry.CreatedAt.UnixMilli(), 10)`; stream sorting uses `model.DefaultSortingOrder = "published_at"`.

### 1.7 Dates

`rss/adapter.go::findEntryDate`: `pubDate` unless `dc:date` present; empty or unparseable → `time.Now()`. Atom: tries `published` then `updated`; zero → `time.Now()`. JSON: same fallback. `internal/reader/date/parser.go::Parse`: integer → `time.Unix`; a `strings.NewReplacer` normalizes localized weekday/month names and odd TZ strings; RFC822/RFC850/RFC1123 parsed with `ParseInLocation` (PST/PDT → America/Los_Angeles, EST/EDT → America/New_York, else UTC); ~150 layouts; `checkTimezoneRange` converts to UTC when offset > +14h or < −12h. **No future-date clamping in the parser.** Future dates are handled as an opt-in filter rule (PR #3016, closes #2971): `internal/reader/filter/filter.go`:
```go
func isDateMatchingPattern(pattern string, entryDate time.Time) bool {
	if pattern == "future" { return entryDate.After(time.Now()) }
	// before:YYYY-MM-DD, after:YYYY-MM-DD, between:YYYY-MM-DD,YYYY-MM-DD, max-age:<Nd|duration>
```

### 1.8 Cleanup (`internal/storage/entry.go::ArchiveEntries`, run by `internal/cli/cleanup_tasks.go`)

```sql
WITH to_delete AS (
	SELECT id, feed_id, hash FROM entries
	WHERE status=$1 AND starred is false AND share_code='' AND created_at < now() - $2::interval
	ORDER BY created_at ASC FOR UPDATE SKIP LOCKED LIMIT $3
), deleted AS (
	DELETE FROM entries USING to_delete WHERE entries.id = to_delete.id RETURNING entries.feed_id, entries.hash
)
INSERT INTO entry_tombstones (feed_id, hash) SELECT feed_id, hash FROM deleted WHERE hash <> '' ON CONFLICT (feed_id, hash) DO NOTHING
```
Read entries after 60 days, unread after 180 days, 10 000 per pass, daily. Age-based on **arrival** (`created_at`), not count-based; starred and shared entries are never archived; tombstones are never purged. `FlushHistory` does the same for all read entries on demand.

---

## 2. yarr (nkanaev/yarr, Go)

### 2.1 Fetch loop (`src/worker/worker.go`)

```go
const NUM_WORKERS = 4
func (w *Worker) SetRefreshRate(minute int64) { ... w.refresh = time.NewTicker(time.Minute * time.Duration(minute)) ... case <-fire: w.RefreshFeeds() }
func (w *Worker) RefreshFeeds() {
	w.reflock.Lock(); defer w.reflock.Unlock()
	if *w.pending > 0 { log.Print("Refreshing already in progress"); return }
	feeds := w.db.ListFeeds()
	atomic.StoreInt32(w.pending, int32(len(feeds)))
	go w.refresher(feeds)
}
func (w *Worker) refresher(feeds []model.Feed) {
	// w.db.ResetFeedErrors()
	srcqueue := make(chan model.Feed, len(feeds)); dstqueue := make(chan []model.Item)
	for range NUM_WORKERS { go w.worker(srcqueue, dstqueue) }
	for _, feed := range feeds { srcqueue <- feed }
	for range feeds { items := <-dstqueue; if len(items) > 0 { w.db.CreateItems(items) }; atomic.AddInt32(w.pending, -1) }
```
`worker()` clears `LastError` ("" → NULL-ish via `UpdateFeedState`) before each fetch and sets `err.Error()` on failure. Refresh rate is a single global setting (`settings.refresh_rate`, minutes, `0` = off, default 0); `/api/feeds/refresh` (POST) triggers `RefreshFeeds()`. Every feed is fetched every cycle regardless of prior errors — no backoff, no disabling, forever.

### 2.2 HTTP client (`src/worker/client.go`, `crawler.go::listItems`)

```go
transport := &http.Transport{ Proxy: http.ProxyFromEnvironment,
	DialContext: (&net.Dialer{Timeout: 10 * time.Second}).DialContext,
	DisableKeepAlives: true, ForceAttemptHTTP2: true, TLSHandshakeTimeout: time.Second * 10 }
httpClient := &http.Client{Timeout: time.Second * 30, Transport: transport}
client = &Client{httpClient: httpClient, userAgent: "Yarr/1.0"}   // SetVersion → "Yarr/" + num  (issue #216 / PR #217)
```
No `Accept-Encoding` is set → Go handles gzip transparently. No body size cap. Redirects: Go default (follow, max 10); the stored `feed_link` is never changed by redirects.

```go
res, err := client.getConditional(f.FeedLink, lmod, etag)      // If-Modified-Since / If-None-Match only if non-empty
switch {
case res.StatusCode < 200 || res.StatusCode > 399:
	if res.StatusCode == 404 { return nil, fmt.Errorf("feed not found") }
	return nil, fmt.Errorf("status code %d", res.StatusCode)
case res.StatusCode == http.StatusNotModified:
	return nil, nil
}
feed, err := parser.ParseAndFix(res.Body, f.FeedLink, getCharset(res))
lmod = res.Header.Get("Last-Modified"); etag = res.Header.Get("Etag"); now := time.Now().UTC()
if lmod != "" || etag != "" { db.UpdateFeedState(f.Id, model.UpdateFeedStateParams{HTTPLastModified: &lmod, HTTPEtag: &etag, LastRefreshed: &now}) }
```
Note the quirk: on 304 nothing is updated (not even `last_refreshed`); on 200 without validators `last_refreshed` is not updated either.

Feed state table (`m13_consolidate_feed_states`): `feed_states(feed_id unique, last_refreshed datetime default 0, last_error string default '', http_lmod string default '', http_etag string default '')`, upsert with `coalesce(:x, x)`.

### 2.3 Dedup and storage (`src/parser/*.go`, `src/storage/sqlite/item.go`, `migration.go`)

Schema: `create unique index if not exists idx_item_guid on items(feed_id, guid);` (`guid string not null`).

GUID derivation:
- RSS: `GUID: firstNonEmpty(srcitem.GUID.GUID, srcitem.Link)`; `URL: firstNonEmpty(srcitem.OrigLink, srcitem.Link, permalink)` where `permalink = GUID if isPermaLink == "true"`; `OrigLink` is `feedburner:origLink`.
- Atom: if `htmlutil.IsAPossibleLink(srcitem.ID)` then `guidFromID = srcitem.ID + "::" + srcitem.Updated`; `GUID: firstNonEmpty(guidFromID, srcitem.ID, link)` — i.e. an Atom entry whose `<id>` is a URL is re-keyed **every time `<updated>` changes** (creates a new unread item on edit). Deliberate-looking but a known source of duplicates; do not copy.
- `ParseAndFix`: `TranslateURLs(baseURL)`, `SetMissingDatesTo(time.Now())`, `SetMissingGUIDs()` = `sha256(Title + ";;" + Date.RFC3339 + ";;" + URL)`.
- `cleanup()` trims GUID/URL/Title/Content.

Insert:
```go
slices.SortStableFunc(items, func(a, b model.Item) int { sa := a.Date.Format(time.RFC3339) + "::" + a.GUID; ...})
insert into items (guid, feed_id, title, link, date, content, media_links, date_arrived, last_arrived, status) values (...)
on conflict (feed_id, guid) do update set last_arrived = :last_arrived
```
Existing items are never content-updated; only `last_arrived` is bumped ("still present in feed").

Dates: `dateParse` tries the goread layout list with `time.Parse` and returns `defaultTime` (zero) on failure; no TZ fixes, no future clamp.

### 2.4 Retention (`DeleteOldItems`, run at startup and every 24 h via `StartFeedCleaner`)

```go
var ( itemsKeepSize = 50; itemsKeepDays = 90 )
// The rules:
//   - Never delete starred entries.
//   - Keep at least 50 latest items for each feed.
//   - Delete entries older than 90 days relative to the latest arrived item in the same feed.
delete from items where id in (
  select id from (
    select id, row_number() over (partition by feed_id order by date desc) as rn,
           last_arrived, max(last_arrived) over (partition by feed_id) as max_la
    from items where status != :starred_status)
  where rn > :keep_size and last_arrived < datetime(max_la, :keep_days_limit))
-- then: vacuum
```
No tombstones: a trimmed item that is still in the feed comes back as unread on the next fetch, but the `last_arrived` guard (relative to the feed's own newest arrival) makes that rare.

### 2.5 UI streaming

`GET /api/status` → `{"running": <pending count>, "refresh": <scheduler != nil>, "stats": FeedStats()}`; `GET /api/feeds/errors` → `{feed_id: last_error}`. Frontend (`src/frontend/js/pages/App.vue`):
```ts
async refreshStats(loopMode?: boolean) {
  const [err, data] = await to(api.status());
  if (loopMode && !this.itemSelected) this.refreshItems();
  this.loading.feeds = data.running;
  if (data.running) { setTimeout(() => this.refreshStats(true), 500); }
```
i.e. short-polling every 500 ms while a refresh is running, re-listing items each tick. No SSE/WebSocket.

---

## 3. FreshRSS (PHP, `edge`)

### 3.1 Configuration defaults

`config.default.php` (system): `'nb_parallel_refresh' => 10`; `limits`: `'cache_duration' => 800` s ("Might be overridden by HTTP response headers"), `'cache_duration_min' => 60`, `'cache_duration_max' => 86400`, `'retry_after_default' => 1500` ("when HTTP response header `Retry-After` is absent"), `'retry_after_max' => 172800`, `'timeout' => 20`.
`config-user.default.php`: `'ttl_default' => 3600`; `'archiving' => ['keep_period' => 'P3M', 'keep_max' => 200, 'keep_min' => 50, 'keep_favourites' => true, 'keep_labels' => true, 'keep_unreads' => false]`; `'mark_updated_article_unread' => false`; `mark_when` = `['gone' => false, 'max_n_unread' => false, 'same_title_in_feed' => false, ...]`.
`constants.php`: `FRESHRSS_USERAGENT = 'FreshRSS/' . FRESHRSS_VERSION . ' (' . PHP_OS . '; ' . FRESHRSS_WEBSITE . ')'`; `CLEANCACHE_HOURS = 720`. Docker: `CRON_MIN` e.g. `13,43` (recommended) drives `actualize_script.php`.

### 3.2 Which feeds are due (`FeedDAO::listFeedsOrderUpdate`)

```php
$refreshThreshold = time() + 60;
$lastAttemptExpression = '(CASE WHEN error > `lastUpdate` THEN error ELSE `lastUpdate` END)';
WHERE ttl >= {$ttlDefault} AND {$lastAttemptExpression} < ({$refreshThreshold}-(CASE WHEN ttl={$ttlDefault} THEN {$defaultCacheDuration} ELSE ttl END))
ORDER BY {$lastAttemptExpression} ASC
```
`ttl < 0` = muted (`mute()` sets `ttl = -ABS(ttl)`). `error` is a timestamp of the last failure and counts as the "last attempt", so after an error the feed waits one full TTL before retrying — no exponential growth, no strike limit.

### 3.3 Actualize loop (`feedController::actualizeFeeds`)

- `@set_time_limit(300)`; skip muted feeds unless refreshed manually; skip if `time() <= $feed->lastUpdate() + $ttl` (with a multi-user shared-cache exception); `$feed->lock()` = exclusive-create of `TMP_PATH/<hash>.freshrss.lock`, stale locks (>3600 s) removed.
- `Feed::load()`: first `if (($retryAfter = FreshRSS_http_Util::getRetryAfter($this->url, $this->proxyParam())) > 0) throw new FreshRSS_Feed_Exception('For that domain, will first retry after ' . date('c', $retryAfter) ..., code: 503);` — a **domain-wide** wait shared by all feeds on that host.
- On `FreshRSS_Feed_Exception`: `$feedDAO->updateLastError($feed->id()); $feed->_error(time()); if ($e->getCode() === 410) { Minz_Log::warning('Muting gone feed: ' ...); $feedDAO->mute($feed->id(), true); }`.
- 301: `Feed::load()` uses `$simplePie->subscribe_url(true)` ("The case of HTTP 301 Moved Permanently") and `if ($subscribe_url !== '' && $subscribe_url !== $url) { $this->_url($clean_url); }`; back in the controller `if ($feed->url() !== $url) { Minz_Log::warning('Feed ... moved permanently to ' ...); $feedProperties['url'] = $feed->url(); }` → the stored URL **is** rewritten after a permanent redirect. (Inferred, not read: SimplePie's `subscribe_url(true)` returns only the permanent-redirect target.) For WebSub self-URL changes it explicitly refuses https→http downgrade.
- Unchanged content: `if ($noCache || $simplePie->get_hash() !== $this->attributeString('SimplePieHash'))` — a body hash is kept per feed; identical body → `load()` returns null → `$entryDAO->updateLastSeenUnchanged($feed->id(), $mtime)`.
- `rand(0, 30) === 1` → `$feed->cleanOldEntries()` (retention runs on ~1/31 of successful refreshes per feed); `actualizeFeedsAndCommit` also `cleanCache(CLEANCACHE_HOURS)` with the same odds.
- Success: `$feedDAO->updateLastUpdate($feed->id(), $mtime)` = `UPDATE _feed SET lastUpdate=:last_update, error=0`.

### 3.4 HTTP layer (`SimplePieCustom`, `SimplePieFetch`, vendored SimplePie, `httpUtil.php`)

- `SimplePieCustom::__construct`: `set_useragent(FRESHRSS_USERAGENT)`; `set_cache_duration($limits['cache_duration'], $limits['cache_duration_min'], $limits['cache_duration_max'])`; `set_timeout(feed 'timeout' attribute or $limits['timeout'])`; protocols restricted to `http,https` (also for redirects).
- `SimplePieFetch`: redirects default `4` (`CURLOPT_MAXREDIRS` if set); `CURLOPT_FOLLOWLOCATION` is stripped "to favour the custom SimplePie redirects for security". `on_http_response`: `if (in_array($this->get_status_code(), [429, 503], true))` → parse headers → `FreshRSS_http_Util::setRetryAfter($this->get_final_requested_uri(), $proxy, $headers['retry-after'] ?? '')`.
- `httpUtil.php::setRetryAfter`:
```php
if (ctype_digit($retryAfter)) { $retryAfter = time() + (int)$retryAfter; }
else { $retryAfter = \SimplePie\Misc::parse_date($retryAfter) ?: (time() + max(600, $limits['retry_after_default'] ?? 0)); }
$retryAfter = min($retryAfter, time() + max(3600, $limits['retry_after_max'] ?? 0));
touch($txt, $retryAfter);   // file mtime = deadline; keyed by domain(:port) [+ sha256(url) when host is not public] [+ proxy]
```
`getRetryAfter` returns the mtime if still in the future, else deletes the file.
- Conditional GET (vendored `SimplePie.php` ~2070-2150): when `cache_expiration_time < time()` it sends `if-modified-since` and `if-none-match` from the cached response headers. On 304 it keeps the cache, replaces stored headers, and applies a "Workaround for buggy servers returning wrong cache-control headers for 304 responses": `if ($new_max_age === null || $new_max_age > $old_max_age) { /* Allow servers to return a shorter cache duration for 304 responses, but not longer */ ... }`. On 200 it hashes the body (`clean_hash`) and if equal to the stored hash returns cached (`// Content unchanged even though server did not send a 304`).
- `HTTP\Utils::negociate_cache_expiration_time($headers, $cache_duration, $min, $max)`: `no-store` → `now + min - 3`; `no-cache` → `now + min`; `must-revalidate` → duration := min; `max-age=N` (minus `Age`) → `now + min(max(N, cache_duration), max)`; `Expires` → `min(max(expires, now + cache_duration), now + max)`; else `now + cache_duration`.

### 3.5 GUID policy, change detection, dedup (`Feed.php`, `Entry.php`, `EntryDAO.php`)

Schema (`app/SQL/install.sql.sqlite.php`): `entry(id BIGINT PK, guid VARCHAR(767), ..., lastSeen BIGINT, lastModified, lastUserModified, hash BINARY(16), is_read, is_favorite, id_feed, ..., UNIQUE (id_feed, guid))`. `addEntry` truncates `guid` to 767 bytes and `safe_ascii`, `link` to 16383, `title` to 8192.

`Feed::decideEntryGuid($item, $fallback)`: per-feed attribute `unicityCriteria`:
```php
null => $entryId,                                     // $item->get_id(false, false), safe_ascii
'link' => $item->get_permalink() ?? '',
'sha1:link_published'               => sha1($item->get_permalink() . $item->get_date('U')),
'sha1:link_published_title'         => sha1(permalink . date . title),
'sha1:link_published_title_content' => sha1(permalink . date . title . content),
'sha1:title', 'sha1:title_published', 'sha1:title_published_content', 'sha1:content', 'sha1:content_published', 'sha1:published'
```
fallback chain when empty: `$entryId` → `sha1(permalink . date)` → `sha1(permalink . date . title)` → `sha1(permalink . date . title . content)`.

`Feed::loadGuids($simplePie, $invalidGuidsTolerance = 0.05)`: counts GUIDs that are empty **or duplicated within the document** as invalid; `if (!unicityCriteriaForced && $invalidGuids > round(0.05 * count($items)))` → auto-degrade `null|'link'` → `'sha1:link_published'` → `'sha1:link_published_title'`, persist the new attribute, log "Feed unicity policy degraded", and re-run. Any invalid GUID also sets `_error(time())`.

Change detection hash (`Entry::hash()`): `md5($this->link . $this->title . $this->authors(true) . $this->originalContent() . $this->tags(true) . $attributes)` with the comment "Do not include $this->date because it may be automatically generated when lacking". In `actualizeFeeds`: `$existingHashForGuids = $entryDAO->listHashForFeedGuids($feed->id(), $newGuids)`; for each parsed entry (chronological order, later duplicates of a GUID in the same document skipped): if GUID exists and `strcasecmp($existingHash, $entry->hash()) !== 0` → `_isUpdated(true); _lastModified($mtime); _isFavorite(null); _isRead($mark_updated_article_unread ? false : null); updateEntry(...)`; else new → `_id(uTimeString())` (microsecond timestamp id = arrival order) → `addEntry(..., true)` into `entrytmp`; `commitNewEntries` copies into `entry` `ORDER BY etmp.date, etmp.id` with consecutive ids (`INSERT IGNORE`). After the loop: `$entryDAO->updateLastSeen($feed->id(), array_keys($newGuids), $mtime)` (touch every GUID still present). Constraint-violation errors (SQLSTATE class 23) on insert are silently ignored as expected duplicates.

Dates: `Entry::_date($value)`: `$this->date = $value > 1 ? $value : time();` — no future clamp; default UI sort is `id DESC` (arrival), not `date`.

### 3.6 Retention (`EntryDAO::cleanOldEntries($id_feed, $options)`)

```sql
DELETE FROM `_entry` WHERE id_feed = :id_feed1
  AND is_favorite = 0                              -- if keep_favourites
  AND is_read = 1                                  -- if keep_unreads
  AND NOT EXISTS (SELECT 1 FROM `_entrytag` WHERE id_entry = id)   -- if keep_labels
  AND `lastSeen` < (SELECT `lastSeen` FROM (SELECT e2.`lastSeen` FROM `_entry` e2 WHERE e2.id_feed = :id_feed2 ORDER BY e2.`lastSeen` DESC LIMIT 1 OFFSET :keep_min) last_seen2)   -- if keep_min > 0
  -- Keep at least the articles seen at the last refresh
  AND `lastSeen` < (SELECT maxlastseen FROM (SELECT MAX(e3.`lastSeen`) AS maxlastseen FROM `_entry` e3 WHERE e3.id_feed = :id_feed3) last_seen3)
  AND (1=0
    OR `lastSeen` < :max_last_seen                 -- if keep_period (now - DateInterval)
    OR `lastSeen` <= (SELECT `lastSeen` FROM (SELECT e4.`lastSeen` FROM `_entry` e4 WHERE e4.id_feed = :id_feed4 ORDER BY e4.`lastSeen` DESC LIMIT 1 OFFSET :keep_max) last_seen4)   -- if keep_max > 0
  )
```
Semantics: candidates are non-starred, (optionally read-only), unlabelled, beyond the newest `keep_min` by `lastSeen`, and **not present in the last fetch**; delete if older than `keep_period` OR beyond `keep_max`. Ranking is by `lastSeen` (last time the item appeared in the feed), so items the publisher keeps in the feed are never deleted (this is what makes the lack of tombstones safe). Options resolve feed → category → user. `ARCHIVING_RETENTION_COUNT_LIMIT = 10000`. Related opt-ins: `markAsReadUponGone` (`is_read=1 WHERE lastSeen + 10 < :min_last_seen`), `markAsReadMaxUnread` (mark read beyond newest N unread by id), `read_when_same_title_in_feed`.

---

## 4. Feedbin (Ruby, `feedbin/feedbin` + `feedbin/feedkit`) — production-scale crawler

Crawler was merged into the main app (`feedbin/crawler` README: "Crawler functionality has been merged into the main Feedbin app.").

- `app/jobs/feed_crawler/schedule.rb`: skips if crawl queues non-empty or `last_refresh` < 15 minutes ago; `feed_ids = (...).uniq.shuffle`, `each_slice(5_000)`, enqueue `[feed.id, feed.feed_url, feed.subscriptions_count, feed.crawl_data.to_h]` only `if feed.crawl_data.ok?(feed.feed_url)` (`Time.now.to_i > retry_after`).
- `downloader.rb`: `sidekiq_options queue: :crawl, retry: false`; `url = @crawl_data.redirected_to ? @crawl_data.redirected_to : parsed_url.url`; `Feedkit::Request.download(url, last_modified: @crawl_data.last_modified, etag: @crawl_data.etag, auto_inflate:, user_agent: "Feedbin feed-id:#{@feed_id} - #{@subscribers} subscribers", block_ssrf: true)`; `content_changed = !@response.not_modified?(@crawl_data.download_fingerprint)`; retry once with `auto_inflate: false` on `Feedkit::ZlibError`; `UpdateRedirect.perform_async(@feed_id, @crawl_data.redirected_to) if @crawl_data.redirect_changed?`.
- `app/models/crawl_data.rb` (fields `downloaded_at failed_at last_error error_count etag last_modified download_fingerprint redirected_to retry_after`):
```ruby
def download_error(exception)
  @data[:error_count] = error_count + 1; @data[:failed_at] = Time.now.to_i
  @data[:last_error]  = error_data(exception); @data[:retry_after] = next_retry(exception)
end
def next_retry(exception)
  header = retry_after_header(exception).to_i
  default = @data[:failed_at] + backoff
  retry_after = [header, default].max
end
def retry_after_header(exception)   # seconds unless it contains a space (HTTP-date)
  ...; retry_after = [retry_after, 8.hours.from_now].min
def backoff
  multiplier = [error_count, 8].max
  multiplier = [multiplier, 23].min
  multiplier ** 4                    # seconds: 4096s (~68 min) for errors 1..8, 6561, 10000, ... 279841s (~3.2 d) at 23
end
def save(response)
  if response.status == 304
    @data[:etag] = response.etag if response.etag; @data[:last_modified] = response.last_modified if response.last_modified
  else
    @data[:etag] = response.etag; @data[:last_modified] = response.last_modified; @data[:download_fingerprint] = response.checksum
  end
  if retry_after = FeedCrawler::Throttle.retry_after(response.url) then @data[:retry_after] = retry_after end
end
```
`download_success` → `clear!` (errors reset) unless the last error was `Feedkit::NotFeed`. `Feed#crawl_error?` = `error_count > 23`; irrecoverable classes for "fixable" UI: `Feedkit::ConnectionError, SSLError, TimeoutError`.
- Redirect persistence (`lib/redirect_cache.rb`): `PERSIST_AFTER = 4 * 24 * 6  # 4 redirect/hr 24hrs a day for 6 days`; only when `@redirects.all?(&:permanent?)`; counter keyed by SHA1 of `[feed_id, status, from, to]` chain with 72 h expiry; then `UpdateRedirect` does `feed.update(redirected_to: to, current_feed_url: to)` — the canonical `feed_url` is kept (receiver: `feed.update(data["feed"].except("feed_url"))`), the crawler just fetches `redirected_to`.
- Per-host throttle (`lib/throttle.rb`): env `THROTTLED_HOSTS` (host=weight), `TIMEOUT = 60 * 30`, `rand(base..(base * 2))` with `base = TIMEOUT * weight`, host = last two labels of the hostname.
- Feedkit `Request`: `MAX_SIZE = 10 * 1024 * 1024` (stream to tempfile, `break if size > MAX_SIZE`); `HTTP.timeout(connect: 5, write: 5, read: 30)`; `.follow(max_hops: 4, on_redirect:)`; headers `user_agent` (default "Feedbin"), `accept_encoding "gzip, deflate"` when auto_inflate, `if_none_match`, `if_modified_since`, basic auth; success = `2xx || 304`; 401 `Unauthorized`, 404 `NotFound`, other 4xx `ClientError`, 5xx `ServerError`; TLS `VERIFY_NONE`. `Response#checksum = Digest::SHA1.file(@path).hexdigest[0, 7]`; `not_modified?(old) = status == 304 || old == checksum`; `request_url` returns the final URL only if **all** hops were permanent.
- Dedup (`feedkit/parser/entry.rb`): `public_id = SHA1(feed_url + entry_id)`; without an id: `SHA1(feed_url + url + published.iso8601 + title)` (compatibility mode); `public_id_alt` = same with the id's scheme flipped http↔https or scheme+host stripped, checked by `Receiver#alternate_exists?` to suppress http/https duplicates; `fingerprint = MD5(sorted flattened attribute values with whitespace removed)` for update detection. `EntryFilter`: `@entries = entries.first(300)`; new = not in DB (`Entry.where(public_id:)`) and not in a Redis "previously created" cache; updated only if fingerprint differs and either a random 12–24 h "check for changes" window elapsed or (`always_check_recent`) published within 24 h. `Receiver` rescues `ActiveRecord::RecordNotUnique`. `Parser` on `Feedkit::NotFeed` → `crawl_data.download_error` (parse failures back off like HTTP failures).

## 5. Feedly (public docs, secondary)

- docs.feedly.com/212: Pro+/Enterprise "the polling interval is as low as 7 minutes"; Pro "between 15 minutes and an hour"; Basic "between 30 minutes to 1 day depending on how popular the site is and how often it publishes"; push (WebSub) sources update "in near real-time".
- feedly.com/fetcher.html: UA "Feedly/1.0"; "Fetcher shouldn't retrieve feeds from most sites more than once every hour on average. Some frequently updated sites may be refreshed more often."; "If your feeds advertise a push hub, Feedly will subscribe for updates and reduce the number of polls to once a day."; "fetcher does not follow robots.txt guidelines."

## 6. Spec anchors (RFC 9110 / 6585 text, verified)

- §13.1.2: "A recipient MUST use the weak comparison function when comparing entity tags for If-None-Match (Section 8.8.3.2), since weak entity tags can be used for cache validation even if there have been changes to the representation data." Examples include `If-None-Match: W/"xyzzy"`.
- §10.2.3: `Retry-After = HTTP-date / delay-seconds`; "When sent with a 503 (Service Unavailable) response, Retry-After indicates how long the service is expected to be unavailable"; "When sent with any 3xx (Redirection) response, Retry-After indicates the minimum time that the user agent is asked to wait before issuing the redirected request." RFC 6585 §4: 429 "MAY include a Retry-After header".
- §15.4.2 (301) / §15.4.9 (308): "any future references to this resource ought to use one of the enclosed URIs ... The user agent MAY use the Location field value for automatic redirection." 308 is additionally "heuristically cacheable".
- §15.5.11 (410): "access to the target resource is no longer available at the origin server and that this condition is likely to be permanent."

---

## 7. Synthesis: concrete rules for Kipple

Kipple facts assumed: ~140 feeds, one user, SQLite WAL, 30-min global poll with per-feed override, retention newest-N-per-feed excluding starred, Reader API clients never trigger fetches.

### 7.1 Dedup key (`entries.uid`, unique per feed)

Table: `entries(id INTEGER PRIMARY KEY, feed_id, uid TEXT NOT NULL, link_hash TEXT, ..., UNIQUE(feed_id, uid))` plus index `(feed_id, link_hash)`.

Compute `uid` at parse time, per format, with a type prefix so the source is auditable:
1. RSS `<guid>` / Atom `<id>` / JSON `id` (TrimSpace, non-empty) → `uid = "g:" + sha256(guid)`. Handle in-document GUID collisions exactly like Miniflux: first occurrence keeps `g:sha256(guid)`; later collisions use `g:sha256(guid + "|" + entryURL)` else `g:sha256(guid + "|" + n)`. (Do **not** mix `<updated>` into the key as yarr does for URL-shaped Atom ids — that manufactures a new unread on every edit.)
2. Else entry link (raw, before tracking-param cleanup and before absolutization, as Miniflux hashes it — stable across cleaner rule changes) → `uid = "l:" + sha256(rawLink)`. For FeedBurner items prefer `feedburner:origLink` for the *displayed* URL (yarr and Miniflux both read it) but hash the plain `<link>` for stability.
3. Else `uid = "h:" + sha256(title + "\x1f" + normalizedContent)` (Miniflux) — deliberately **not** the published date (FreshRSS's hash comment: dates are often synthesized). If content is also empty, fall back to yarr's `title;;date;;url` triple so at least something distinguishes items.
Always store `link_hash = sha256(normalized absolute link)` alongside for GUID-migration detection.

Invalid-GUID guard (from FreshRSS `loadGuids`): if > `round(5% × items)` GUIDs in one document are empty or duplicated, persist `feeds.dedup_mode = "link"` (then `"link_published_title"`) and re-key; log once. Store the mode per feed so it does not flap.

### 7.2 Feed that changes GUIDs

None of the three readers handle a wholesale GUID rewrite; Miniflux's tombstones only stop *archived* items from returning, FreshRSS degrades the policy for future fetches, Feedbin only covers the http↔https flip via `public_id_alt`. Kipple rule: after computing uids for a fetch, if ≥ 50% of items (and ≥ 5) are new by `uid` but match an existing row in the same feed by `link_hash`, treat it as a **GUID migration**: `UPDATE entries SET uid = ? WHERE feed_id = ? AND link_hash = ?` for each match instead of inserting, keep read/starred state, and add the http↔https-flipped `uid` check (Feedbin `public_id_alt`) as a cheap second pass. Guard the unread flood regardless: cap "new unread per feed per fetch" (e.g. if > 100 new items arrive on a feed that has history, insert them as read and log) — the harm of a bad dedup is a wall of unread, not a missed post.

### 7.3 Conditional requests

- Store `etag TEXT` and `last_modified TEXT` verbatim (weak `W/` prefix included) on the feed; send `If-None-Match: <etag>` and `If-Modified-Since: <last_modified>` whenever non-empty (Miniflux, yarr, Feedbin, SimplePie all do exactly this). Never rewrite or "strengthen" the ETag; RFC 9110 §13.1.2 mandates weak comparison on the server side anyway.
- On 200: replace both validators with the response's values (empty if absent). On 304: keep the ETag, but overwrite `last_modified` if the 304 carries one (Miniflux, per RFC 9111 §3.2/§4.3.4; Feedbin does the same for both headers).
- Servers that ignore validators: also keep `body_hash TEXT` (SHA-256 of the raw body; FreshRSS `SimplePieHash`, Feedbin `download_fingerprint`); if the 200 body hash equals the stored one, skip parsing and treat as 304 ("Content unchanged even though server did not send a 304"). This also neutralizes ETags that rotate on every request.
- Manual "refresh all now" bypasses validators (Miniflux `forceRefresh` → `ignoreHTTPCache`) but should still apply the body-hash short-circuit.
- Optional Miniflux quirk: drop validators when the response says `Expires: 0`.

### 7.4 Status handling (per response)

| Result | Action | Prior art |
|---|---|---|
| 200 | body-size cap → parse → dedup → store validators + body hash; `error_count = 0`, `last_error = NULL`, `checked_at = now` | all |
| 304 | no parse; update `last_modified` if present; `error_count = 0`; `checked_at = now`; **also touch `last_seen`** of currently-stored items is impossible (no body) — FreshRSS uses `updateLastSeenUnchanged` for items seen at the previous fetch | Miniflux, FreshRSS |
| 301 / 308 | follow (Go default). Record `redirect_target`. Migrate `feed_url` only when the *whole* chain was permanent (Feedbin `all?(&:permanent?)`), the same target was seen on **N consecutive** successful fetches (Feedbin waits ~6 days of hourly polls; for Kipple 3 consecutive 30-min polls ≈ 90 min, or 48 ≈ 1 day, is enough), no other feed already owns that URL (Miniflux `AnotherFeedURLExists` → duplicate error), and it is not an https→http downgrade (FreshRSS WebSub rule). Keep the original URL in `feed_url_original` for display/OPML. | Feedbin, FreshRSS, Miniflux |
| 302 / 303 / 307 | follow, never persist | Feedbin (`permanent?` gate) |
| 404 | error + backoff; message "feed not found" | yarr, Miniflux |
| 410 | error + set `disabled = 1` with reason "gone" (FreshRSS mutes on 410; RFC 9110: "likely to be permanent") — surface in UI, user can re-enable | FreshRSS |
| 401 / 403 | error + backoff; if `cf-mitigated: challenge` + `text/html` → message "blocked by Cloudflare challenge (TLS fingerprint); try disabling HTTP/2 or a browser UA for this feed" | Miniflux |
| 429 | honor `Retry-After` (integer seconds, else HTTP-date; Miniflux `ParseRetryDelay`, FreshRSS `setRetryAfter`); `next_check = max(backoff, now + retry_after)` (Feedbin `[header, default].max`), clamp to 24 h (Miniflux max interval 1440 min; FreshRSS caps at `retry_after_max` 48 h; Feedbin 8 h); with no header use the backoff (FreshRSS default 1500 s). Write the deadline into a **per-host** table so sibling feeds on the same host wait too (FreshRSS domain-wide file; Feedbin per registered domain). Count it as an error (Miniflux does). | Miniflux, FreshRSS, Feedbin |
| 503 | same as 429 incl. `Retry-After` (FreshRSS treats 429 and 503 identically) | FreshRSS, RFC 9110 |
| other 5xx, 502, 504 | error + backoff | all |
| timeout (`os.IsTimeout` / `context.DeadlineExceeded`) | error + backoff; message "timeout" | Miniflux |
| DNS (`*net.DNSError`) / connect (`*net.OpError`) | error + backoff; message "network" | Miniflux |
| TLS (`x509.UnknownAuthorityError`, `x509.HostnameError`, `x509.InsecureAlgorithmError`, `tls.RecordHeaderError`) | error + backoff; message "tls"; offer per-feed `allow_insecure_tls` | Miniflux |
| 200 with empty body / body > cap / parse failure | error + backoff (Feedbin backs off on `NotFeed` too); keep old validators so a transient blank 200 is retried | Miniflux, Feedbin |

Error bookkeeping fields: `error_count INTEGER`, `last_error TEXT`, `last_error_at`, `checked_at`, `next_check_at`. Reset `error_count` on any 2xx/304 (Miniflux `ResetErrorCounter`, yarr clears `LastError` each cycle, Feedbin `clear!`).

### 7.5 Backoff schedule

None of the three readers the owner compared implement exponential backoff: Miniflux is "3 strikes then stop polling until manual intervention", yarr retries every cycle forever, FreshRSS retries after one TTL measured from the error time. Feedbin is the only production-grade schedule: `max(8, n)^4` seconds, capped at `23^4` (~3.2 days), `> 23` errors = dead. For Kipple:

- `interval_i = min(base × 2^(i-1), 24h)` with `base` = the feed's interval (30 min default), i = consecutive error count → 30m, 1h, 2h, 4h, 8h, 16h, 24h, 24h ... Add full jitter of ±20% (`interval × (0.8 + 0.4×rand)`) so a host outage does not resynchronize all its feeds.
- `next_check_at = max(now + interval_i, retry_after_deadline_for_host)`.
- Reset to `base` on success. Never stop polling and never auto-disable except on 410; after e.g. 14 consecutive failures (≈ 1 week at the 24 h cap) mark the feed "failing" in the UI (Feedbin uses `error_count > 23` for its "dead/fixable" UI). A manual refresh ignores backoff and Retry-After (Miniflux "refresh all" ignores the error limit) but must still respect a live per-host 429 deadline.
- Successful fetches: `next_check_at = now + max(feed.interval, min(rss_ttl, cache_control_max_age − Age, expires − now, 24h))` — Miniflux `max(feedTTL, maxAge, expires)` then `min(., 1440 min)`; FreshRSS clamps to `[60 s, 86400 s]`. Never go *below* the feed's configured interval because of a small `max-age`.

### 7.6 User-Agent

- Default: `Mozilla/5.0 (compatible; Kipple/<version>; +https://rss.example.com)` — Miniflux's shape. Go's default `Go-http-client/1.1` is documented as a blocked-UA bug (Miniflux #2188/#2189); yarr shipped a hard-coded `Yarr/1.0` for years (#216) and Feedbin puts `feed-id:<id> - <n> subscribers` in the UA for publisher visibility; Feedly's is `Feedly/1.0` and publishers are told they can block it by UA.
- Per-feed `user_agent TEXT` override (Miniflux `feeds.user_agent`, FreshRSS `curl_params[CURLOPT_USERAGENT]`) for hosts that want a browser UA (reddit is the recurring case in Miniflux #1432/#2255/#3794). Note Cloudflare managed challenges key on TLS/HTTP2 fingerprint, not UA (fguillot in #3412); Miniflux's mitigation is a per-feed `disable_http2` flag — expose the same (`TLSNextProto = map[string]func(...) http.RoundTripper{}`).
- FeedBurner: parse `feedburner:origLink` and `feedburner:origEnclosureLink` (both yarr and Miniflux) for entry/enclosure URLs; there is no special UA requirement in any of the four codebases.

### 7.7 Transport settings

- Compression: either leave `Accept-Encoding` unset and let Go decode gzip transparently (yarr), or set `br,gzip` and decode yourself (Miniflux) — mixing (setting the header and expecting auto-decode) is the bug. If decoding manually, apply `http.MaxBytesReader` **to the decompressed stream** (Miniflux `getReader`) so the cap bounds memory, not wire bytes.
- Max body: 10 MiB (Feedbin `MAX_SIZE`) to 15 MiB (Miniflux). Kipple: 10 MiB; treat `*http.MaxBytesError` as a distinct error.
- Timeouts: dial 10 s (Miniflux, yarr), TLS handshake 10 s (yarr), `ResponseHeaderTimeout` ~15 s, overall `http.Client.Timeout` 20–30 s (Miniflux 20, FreshRSS 20, yarr 30, Feedbin read 30). Redirect hops: 4–5 (Feedbin `max_hops: 4`, FreshRSS 4; Go default 10). `Connection: close` / `DisableKeepAlives: true` (Miniflux/yarr) is fine at 140 feeds and avoids stale-pool errors.
- SSRF: refuse private/loopback targets in `Dialer.Control` after resolution (Miniflux) unless a per-feed allow flag is set — Kipple is behind a Cloudflare tunnel on a LAN with other services, so this matters.
- `Accept` header: use Miniflux's `application/xml,application/atom+xml,application/rss+xml,application/rdf+xml,application/feed+json,text/html,*/*;q=0.9`.

### 7.8 Concurrency and scheduling for ~140 feeds

- Miniflux runs 16 workers for multi-user installs, yarr 4, FreshRSS 10 parallel from the UI. Kipple: a scheduler goroutine ticking every 60 s that selects `WHERE disabled = 0 AND next_check_at <= now ORDER BY next_check_at LIMIT 100` (Miniflux batch shape; the 30-min cadence lives in `next_check_at`, which makes per-feed overrides trivial), feeding a semaphore of **8** concurrent fetches with a per-host limit of **2** in flight (Miniflux `POLLING_LIMIT_PER_HOST`; OpenRSS blocked Miniflux users for parallel bursts in #3289). 140 feeds × ~1–2 s / 8 ≈ 20–35 s per cycle. Spread initial `next_check_at` across the first interval (Feedbin `.shuffle`) so the box does not fire 140 requests at minute 0.
- Single writer to SQLite: workers fetch/parse concurrently but hand parsed items to one goroutine that does the transaction (yarr's `dstqueue` → `CreateItems` pattern); one transaction per feed, not per entry (Miniflux's per-entry transactions are a Postgres habit).
- "Refresh all now": enqueue every enabled feed ignoring `next_check_at`/backoff; debounce to one run at a time (yarr `pending > 0` guard; Miniflux `FORCE_REFRESH_INTERVAL` 30 min throttle per session is too strict for a single user — use "no more than one forced run in flight").

### 7.9 Streaming new items into the UI

yarr polls `/api/status` every 500 ms while `running > 0` and re-lists items; Miniflux has no live update. Kipple: one SSE endpoint (`GET /api/events`, `text/event-stream`, `http.Flusher`, 15 s keep-alive comment) broadcasting per-feed completions `{"type":"feed","feed_id":..,"new":n,"error":".."}` and `{"type":"refresh_done"}`; the React list appends/reconciles by entry id. Fall back to polling `/api/status` (yarr shape: `running`, per-feed unread counts, errors) when `EventSource` errors twice. Reader API clients are unaffected (they poll on their own schedule). Verify SSE through cloudflared + Cloudflare Access on the UI path (buffering/idle timeouts) before relying on it.

### 7.10 Retention: newest N per feed, starred exempt, compact trimmed record

Prior art: yarr keeps ≥ 50 newest by `date` and deletes only what is older than 90 days relative to the feed's newest arrival, never starred; FreshRSS ranks by `lastSeen`, keeps `keep_min`, deletes beyond `keep_max` or `keep_period`, never favourites/labelled, and never anything present in the last fetch; Miniflux is age-based with tombstones so archived items cannot be re-ingested as unread.

Kipple algorithm (run per feed, only after a successful fetch, inside the same transaction as the insert — "Trim after fetch only"):
```sql
-- N = feed.retention ?? global.retention; skip if N is NULL (unlimited)
WITH ranked AS (
  SELECT id, uid, read, ROW_NUMBER() OVER (ORDER BY published_at DESC, id DESC) AS rn
  FROM entries WHERE feed_id = :feed AND starred = 0 AND last_seen_at < :this_fetch_started   -- FreshRSS: never trim what the feed still lists
)
INSERT OR IGNORE INTO trimmed(feed_id, uid, entry_id, read, trimmed_at)
  SELECT :feed, uid, id, read, :now FROM ranked WHERE rn > :N;
DELETE FROM entries WHERE id IN (SELECT id FROM ranked WHERE rn > :N);
```
- `last_seen_at` is bumped for every uid present in the fetched document (FreshRSS `updateLastSeen`, yarr `last_arrived`); it is what keeps "still in the feed" items from being trimmed and re-inserted.
- `trimmed(feed_id, uid, entry_id INTEGER, read INTEGER, trimmed_at INTEGER, PRIMARY KEY(feed_id, uid))` is the compact tombstone (Miniflux `entry_tombstones(feed_id, hash)` plus two small columns): insert is guarded by `NOT EXISTS (SELECT 1 FROM trimmed WHERE feed_id=? AND uid=?)` so a trimmed item that reappears (or whose GUID we re-see after a feed regression) never returns as unread; `entry_id` lets the Reader API answer `edit-tag` on an id the client still holds without erroring, and keep the id space monotonic; `read` is enough state for Reader clients (a trimmed id simply drops out of `stream/items/ids?xt=user/-/state/com.google/read`, which Reeder/NetNewsWire treat as read; starred items are never trimmed so no starred state is needed). Purge `trimmed` rows older than 180 days whose uid was not seen in the last fetch (Miniflux never purges; FreshRSS has none — 180 days matches Miniflux's unread horizon).
- Stats events are never trimmed (separate table keyed by `entry_id`, no FK cascade).

### 7.11 Dates

- Store `published_at` (feed value; fallback `created_at`) and `created_at` (arrival). Never update `published_at` on an entry update (Miniflux `updateEntry` comment). Use Miniflux's parser approach: try RFC822/1123/850 in a location (EST/EDT → America/New_York, matching the owner's box), then the layout list; clamp impossible TZ offsets to UTC.
- No reader clamps future dates in the parser; Miniflux instead exposes `EntryDate=future` as a block rule, FreshRSS sorts by arrival id by default, Feedbin uses `published` with a `date_filter` only on import. Kipple: keep the raw date, but order Reader API streams and `crawlTimeMsec` by `created_at`/`id` (that is Google Reader's actual semantics and what Miniflux emits for `CrawlTimeMsec`), and in the web UI sort by `min(published_at, created_at + 24h)` so a mis-dated post cannot pin itself to the top.


## Claims
- [high] Miniflux's scheduler selects feeds with `parsing_error_count < POLLING_PARSING_ERROR_LIMIT AND disabled IS false AND next_check_at < now() ORDER BY next_check_at ASC LIMIT BATCH_SIZE` every POLLING_FREQUENCY, and the per-host limit is applied while scanning rows (skipped feeds wait for a later batch). (https://raw.githubusercontent.com/miniflux/v2/main/internal/storage/batch.go)
- [high] Miniflux defaults: POLLING_FREQUENCY 60 min, BATCH_SIZE 100, WORKER_POOL_SIZE 16, POLLING_PARSING_ERROR_LIMIT 3, POLLING_LIMIT_PER_HOST 0, HTTP_CLIENT_TIMEOUT 20 s, HTTP_CLIENT_MAX_BODY_SIZE 15 MiB, SCHEDULER_ROUND_ROBIN_MIN/MAX 60/1440 min, ENTRY_FREQUENCY MIN/MAX 5 min/24 h, CLEANUP read 60 d / unread 180 d / batch 10000 / every 24 h, FORCE_REFRESH_INTERVAL 30 min. (https://raw.githubusercontent.com/miniflux/v2/main/internal/config/options.go)
- [high] Miniflux's default User-Agent is `Mozilla/5.0 (compatible; Miniflux/<version>; +https://miniflux.app)`; falling back to Go's default UA was fixed as a regression (issues #2188/#2189). (https://raw.githubusercontent.com/miniflux/v2/main/internal/config/config.go)
- [high LB] Miniflux sends If-None-Match / If-Modified-Since verbatim from stored etag_header/last_modified_header (only when non-empty), skips them on force refresh or ignore_http_cache, and on a 304 overwrites the stored Last-Modified if the 304 carries one (citing RFC 9111 §3.2 and §4.3.4). (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/handler/handler.go)
- [high] Miniflux's IsModified returns false on 304; otherwise compares the response ETag to the stored one if present, else Last-Modified, else treats the response as modified; ETag/Last-Modified are ignored when the response has `Expires: 0`. (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/fetcher/response_handler.go)
- [high] Miniflux parses Retry-After as integer seconds or RFC1123 date; on 429 it calls ScheduleNextCheck(weeklyCount, retryDelay) but still returns an error that increments parsing_error_count. (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/handler/handler.go)
- [high] Miniflux ScheduleNextCheck: interval = round-robin min interval (or 7d/(weeklyCount*factor) clamped for entry_frequency), then max(interval, refreshDelay) where refreshDelay = max(RSS ttl, Cache-Control max-age, Expires) or Retry-After, then min(interval, max interval 1440 min). (https://raw.githubusercontent.com/miniflux/v2/main/internal/model/feed.go)
- [high] Miniflux sets Accept-Encoding `br,gzip` explicitly and therefore decodes brotli/gzip itself, then applies http.MaxBytesReader to the decompressed stream; it sets `Connection: close`, dial timeout 10 s, keepalive 15 s, MaxIdleConns 50, IdleConnTimeout 10 s, ForceAttemptHTTP2, and a per-feed disable_http2 option 'to avoid fingerprinting'. (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/fetcher/request_builder.go)
- [high LB] Go's net/http Transport only transparently decodes gzip when it added Accept-Encoding itself: 'if the user explicitly requested gzip it is not automatically uncompressed.' (https://raw.githubusercontent.com/golang/go/master/src/net/http/transport.go)
- [high] Miniflux classifies fetch errors: x509.UnknownAuthorityError/HostnameError/InsecureAlgorithmError → TLS; *url.Error, *net.OpError, io.EOF → network; os.IsTimeout → timeout; 403 + `cf-mitigated: challenge` + text/html → Cloudflare challenge; explicit messages for 401/403/429/404/410/500/502/503/504; non-304 with ContentLength==0 → empty body error. (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/fetcher/response_handler.go)
- [high LB] Miniflux sets feed_url to the redirect-resolved effective URL only at feed creation (CreateFeed line 181); RefreshFeed uses EffectiveURL only for a duplicate-feed check and as parse base URL and never rewrites the stored feed_url after a 301. (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/handler/handler.go)
- [high] Miniflux has no exponential backoff or auto-disable: feeds with parsing_error_count >= 3 are simply excluded from scheduled batches until a manual refresh succeeds, the UI 'refresh all' (which ignores the error limit) runs, or `miniflux -reset-feed-errors` clears counters. (https://raw.githubusercontent.com/miniflux/v2/main/internal/ui/feed_refresh.go)
- [high LB] Miniflux RSS entry hash: SHA256(guid) for the first occurrence of a GUID, SHA256(guid|url) or SHA256(guid|n) for in-document GUID collisions, else SHA256(raw entry link), else SHA256(title+content); Atom: first non-empty of id, original link; JSON Feed: id, url, external_url, content_text+content_html+summary. Unique index is (feed_id, hash). (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/rss/adapter.go)
- [high LB] Miniflux ArchiveEntries deletes non-starred, non-shared entries by status older than N days by created_at (read 60 d, unread 180 d, 10000 per pass) and inserts (feed_id, hash) into entry_tombstones; createEntry refuses to insert a tombstoned hash, so archived entries cannot return as unread. Tombstones are never purged. (https://raw.githubusercontent.com/miniflux/v2/main/internal/storage/entry.go)
- [high LB] Miniflux never updates published_at on entry update ('some feeds do not contains any date, it default to time.Now()'), processes entries oldest-first so created_at is monotonic, and emits Google Reader crawlTimeMsec from entry.CreatedAt.UnixMilli() while sorting Reader streams by published_at. (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go)
- [high] Miniflux's date parser does not clamp future dates; missing/unparseable dates become time.Now(); out-of-range TZ offsets (> +14h or < -12h) are converted to UTC; future-dated entries are handled only via the opt-in filter rule `EntryDate=future` (PR #3016, issue #2971). (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/filter/filter.go)
- [high] yarr uses NUM_WORKERS = 4, a global refresh_rate in minutes (0 = off), refuses to start a refresh while one is pending, fetches every feed every cycle with no backoff or error limit, and has `// w.db.ResetFeedErrors()` commented out. (https://raw.githubusercontent.com/nkanaev/yarr/master/src/worker/worker.go)
- [high] yarr's HTTP client: UA `Yarr/<version>` (default 'Yarr/1.0'), dial timeout 10 s, TLS handshake 10 s, client timeout 30 s, DisableKeepAlives, ForceAttemptHTTP2, no explicit Accept-Encoding, no body cap; statuses outside 200-399 are errors (404 → 'feed not found'), 304 returns no items and updates nothing, validators stored only when at least one is present, and the stored feed_link is never changed on redirect. (https://raw.githubusercontent.com/nkanaev/yarr/master/src/worker/crawler.go)
- [high LB] yarr dedups on unique (feed_id, guid) with `on conflict (feed_id, guid) do update set last_arrived`; RSS GUID = guid else link; Atom GUID = `<id>::<updated>` when the id looks like a URL (so edits create new items), else id, else link; missing GUIDs become sha256(title;;date;;url); missing dates become time.Now(). (https://raw.githubusercontent.com/nkanaev/yarr/master/src/parser/atom.go)
- [high LB] yarr retention (daily): never delete starred; keep at least 50 newest items per feed by date; delete the rest only if last_arrived is older than 90 days relative to the feed's newest last_arrived; VACUUM afterwards. No tombstones. (https://raw.githubusercontent.com/nkanaev/yarr/master/src/storage/sqlite/item.go)
- [high] yarr's UI shows live progress by polling GET /api/status ({running, refresh, stats}) every 500 ms while running > 0 and re-listing items; no SSE. (https://raw.githubusercontent.com/nkanaev/yarr/master/src/frontend/js/pages/App.vue)
- [high] FreshRSS defaults: cache_duration 800 s (min 60, max 86400), retry_after_default 1500 s, retry_after_max 172800 s, timeout 20 s, nb_parallel_refresh 10, user ttl_default 3600; archiving keep_period P3M, keep_max 200, keep_min 50, keep_favourites true, keep_labels true, keep_unreads false. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/config.default.php)
- [high] FreshRSS selects due feeds with `(CASE WHEN error > lastUpdate THEN error ELSE lastUpdate END) < now+60 - ttl` (ttl<0 = muted), so an error timestamp counts as the last attempt and the feed waits one TTL before retry; no exponential backoff or strike limit; a 410 response mutes the feed. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/FeedDAO.php)
- [high] FreshRSS stores a domain-wide Retry-After deadline (file mtime keyed by host[:port]) on 429/503: integer → now+n, else HTTP-date, else now+max(600, retry_after_default), clamped to now+max(3600, retry_after_max); Feed::load() throws a 503-coded exception before making any request while the deadline is in the future. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Utils/httpUtil.php)
- [high LB] FreshRSS rewrites the stored feed URL after a permanent redirect: Feed::load() takes `$simplePie->subscribe_url(true)` ('The case of HTTP 301 Moved Permanently') and actualizeFeeds writes `$feedProperties['url'] = $feed->url()` when it changed; the WebSub path refuses an https→http downgrade. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Controllers/feedController.php)
- [high] FreshRSS's vendored SimplePie sends if-modified-since/if-none-match from cached headers, refuses to accept a longer max-age from a 304 than previously stored ('Workaround for buggy servers'), and treats a 200 whose body hash equals the stored hash as unchanged; cache expiry = negotiated from no-store/no-cache/must-revalidate/max-age(-Age)/Expires clamped to [cache_duration_min, cache_duration_max]. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/lib/simplepie/simplepie/src/HTTP/Utils.php)
- [high LB] FreshRSS dedups on UNIQUE(id_feed, guid) with a per-feed `unicityCriteria` (id → link → sha1:link_published → sha1:link_published_title → ...); if more than round(5% of items) have empty or in-document-duplicate GUIDs the policy is automatically degraded and persisted; change detection uses md5(link.title.authors.content.tags.attributes) deliberately excluding the date; updated entries keep favourite state and are re-marked unread only if mark_updated_article_unread. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/Feed.php)
- [high LB] FreshRSS cleanOldEntries deletes per feed only non-favourite (and optionally read-only, unlabelled) entries ranked by lastSeen beyond keep_min, never anything with lastSeen equal to the feed's max lastSeen (present in the last fetch), and only if older than keep_period or beyond keep_max; it runs on ~1/31 of successful refreshes. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/EntryDAO.php)
- [high] Feedbin's crawl backoff is `[max(error_count, 8), 23].min ** 4` seconds (4096 s for the first eight failures up to ~3.2 days), next retry = max(Retry-After header clamped to 8 h, failed_at + backoff), errors cleared on success, and a feed is considered in crawl error after error_count > 23. (https://raw.githubusercontent.com/feedbin/feedbin/master/app/models/crawl_data.rb)
- [high] Feedbin persists a redirect target only after PERSIST_AFTER = 4*24*6 observations of an all-permanent redirect chain to the same target, and then stores it as redirected_to/current_feed_url without changing feed_url; Feedkit Response#request_url returns the final URL only when every hop was permanent. (https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/lib/redirect_cache.rb)
- [high] Feedkit requests use MAX_SIZE 10 MiB (streamed to a tempfile), timeouts connect 5 / write 5 / read 30 s, max 4 redirect hops, UA default 'Feedbin' (Feedbin sends 'Feedbin feed-id:<id> - <n> subscribers'), Accept-Encoding 'gzip, deflate', If-None-Match/If-Modified-Since when present, success = 2xx or 304; not_modified? = status 304 or SHA1 body checksum (first 7 hex) equals the stored fingerprint. (https://raw.githubusercontent.com/feedbin/feedkit/master/lib/feedkit/request.rb)
- [high] Feedbin's entry key is public_id = SHA1(feed_url + entry_id), or SHA1(feed_url + url + published.iso8601 + title) when the entry has no id, with a public_id_alt (http↔https flipped) checked to suppress duplicates; updates are detected via an MD5 fingerprint of all attribute values and only checked in a random 12-24 h window or for entries published within 24 h; only the first 300 entries of a document are considered. (https://raw.githubusercontent.com/feedbin/feedkit/master/lib/feedkit/parser/entry.rb)
- [high] Feedbin's scheduler runs at most every 15 minutes, only when the crawl queues are empty, shuffles feed ids, and enqueues only feeds whose crawl_data.retry_after is in the past; per-host throttling is an env-configured list with random 30-60 min (× weight) delays. (https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/schedule.rb)
- [medium] Feedly polls Pro+/Enterprise feeds 'as low as 7 minutes', Pro '15 minutes and an hour', Basic '30 minutes to 1 day depending on how popular the site is and how often it publishes'; its fetcher UA is 'Feedly/1.0', it aims for no more than once an hour per site on average, drops to once a day when a push hub is advertised, and does not honor robots.txt. (https://docs.feedly.com/article/212-how-often-does-feedly-update)
- [high LB] RFC 9110 §13.1.2 requires weak comparison for If-None-Match (so echoing a stored `W/"..."` ETag verbatim is correct); §10.2.3 defines Retry-After as HTTP-date or delay-seconds and applies it to 503 and any 3xx; RFC 6585 says 429 MAY include Retry-After; §15.4.2/15.4.9 say 301/308 clients 'ought to use' the new URI and MAY auto-redirect; §15.5.11 says 410 is 'likely to be permanent'. (https://www.rfc-editor.org/rfc/rfc9110.txt)
- [high] Cloudflare managed challenges distinguish Go's standard HTTP client by TLS fingerprint and return 403 with `Cf-Mitigated: challenge` before any 301, so a User-Agent change alone does not unblock such feeds (Miniflux maintainer, issue #3412). (https://github.com/miniflux/v2/issues/3412)

## Open questions
- Whether SimplePie's `subscribe_url(true)` returns only the permanent-redirect (301/308) target and not 302 targets — inferred from FreshRSS's comment 'The case of HTTP 301 Moved Permanently', not read in SimplePie source.
- Reader API stream ordering: Miniflux sorts Google Reader streams by published_at but emits crawlTimeMsec from created_at; Kipple must decide whether stream order/`ot`/`nt` continuation follows crawl time (Google Reader semantics) or published_at, and verify Reeder Classic and NetNewsWire behave with both.
- Whether Cloudflare Access / cloudflared buffers or times out a long-lived text/event-stream on the UI path (SSE fallback to /api/status polling is planned, but needs a live test).
- Whether to ever purge the trimmed/tombstone table (Miniflux never does; proposed 180-day purge for uids not seen in the last fetch) and whether Reeder/NetNewsWire ever POST edit-tag for ids older than their local cache horizon.
- Miniflux PR #4139 'support weak ETag comparison for If-None-Match header' has no description; it is presumed to concern Miniflux's own HTTP server responses, not the feed fetcher (the fetcher already echoes ETags verbatim).
- The GUID-migration heuristic (>=50% of items new-by-uid but matching by link_hash → relink instead of insert) has no prior art in the four codebases; thresholds need validation against the owner's ~140 feeds.
- Feedbin's 8-hour Retry-After clamp vs FreshRSS's 48 h vs Miniflux's 24 h max interval — proposed 24 h cap for Kipple, but a host that legitimately asks for longer would be re-polled early once.
- GitHub API rate limiting prevented reading comments on Miniflux issues #2336/#3289 (OpenRSS/FeedBurner 'too many requests'); only issue bodies and one maintainer comment (#3412) were read.

## Sources
- https://raw.githubusercontent.com/miniflux/v2/main/internal/cli/scheduler.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/cli/cleanup_tasks.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/cli/refresh_feeds.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/cli/cli.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/storage/batch.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/storage/entry.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/storage/feed.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/worker/pool.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/worker/worker.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/fetcher/request_builder.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/fetcher/response_handler.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/fetcher/encoding_wrappers.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/handler/handler.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/processor/processor.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/rss/adapter.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/rss/feedburner.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/atom/atom_10_adapter.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/json/adapter.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/date/parser.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/parser/parser.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/filter/filter.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/model/feed.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/model/entry.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/model/job.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/config/options.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/config/config.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/database/migrations.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/ui/feed_refresh.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go
- https://miniflux.app/docs/configuration.html
- https://github.com/miniflux/v2/issues/3412
- https://github.com/miniflux/v2/issues/1387
- https://github.com/miniflux/v2/issues/2971
- https://github.com/miniflux/v2/pull/3016
- https://github.com/miniflux/v2/issues/3289
- https://github.com/miniflux/v2/pull/4139
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/worker/worker.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/worker/client.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/worker/crawler.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/parser/feed.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/parser/rss.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/parser/atom.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/parser/date.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/parser/util.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/storage/sqlite/item.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/storage/sqlite/feedstate.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/storage/sqlite/migration.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/storage/model/model.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/server/routes.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/server/scheduler.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/cmd/yarr/main.go
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/frontend/js/api.ts
- https://raw.githubusercontent.com/nkanaev/yarr/master/src/frontend/js/pages/App.vue
- https://github.com/nkanaev/yarr/issues/216
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/config.default.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/config-user.default.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/constants.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Controllers/feedController.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/Feed.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/FeedDAO.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/Entry.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/EntryDAO.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/SimplePieCustom.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/SimplePieFetch.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Utils/httpUtil.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/SQL/install.sql.sqlite.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/lib/simplepie/simplepie/src/SimplePie.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/lib/simplepie/simplepie/src/HTTP/Utils.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/lib/lib_rss.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/Docker/README.md
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/schedule.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/downloader.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/parser.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/receiver.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/persist_crawl_data.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/lib/throttle.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/lib/redirect_cache.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/feed_crawler/lib/entry_filter.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/jobs/update_redirect.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/models/crawl_data.rb
- https://raw.githubusercontent.com/feedbin/feedbin/master/app/models/feed.rb
- https://raw.githubusercontent.com/feedbin/feedkit/master/lib/feedkit/request.rb
- https://raw.githubusercontent.com/feedbin/feedkit/master/lib/feedkit/response.rb
- https://raw.githubusercontent.com/feedbin/feedkit/master/lib/feedkit/parser.rb
- https://raw.githubusercontent.com/feedbin/feedkit/master/lib/feedkit/parser/entry.rb
- https://raw.githubusercontent.com/feedbin/feedkit/master/lib/feedkit/parser/xml_entry.rb
- https://raw.githubusercontent.com/feedbin/feedkit/master/lib/feedkit/parser/json_entry.rb
- https://raw.githubusercontent.com/feedbin/crawler/master/README.md
- https://docs.feedly.com/article/212-how-often-does-feedly-update
- https://feedly.com/fetcher.html
- https://www.rfc-editor.org/rfc/rfc9110.txt
- https://www.rfc-editor.org/rfc/rfc6585.txt
- https://raw.githubusercontent.com/golang/go/master/src/net/http/transport.go
