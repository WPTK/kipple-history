# greader-server-b

# server B Google Reader API - implementation report (source read from `server B/v2` `main`, 2026-09-24)

Everything under "VERIFIED" was read directly from source, the in-repo README, GitHub issue/PR text, or client B source. Items marked "INFERRED" are my reasoning from that code. server B paths are under `server B repo: internal/googlereader/`: `handler.go` (36.8 KB), `item.go`, `item_test.go`, `middleware.go`, `middleware_test.go`, `parameters.go`, `prefix_suffix.go`, `request_modifier.go`, `response.go`, `stream.go`, `README.md` (added 2026-03-18, PR #4145). Docs page is `server B docs: google_reader` (underscore; `google-reader.html` 404s). Feature shipped as "experimental" in server B 2.0.35 (2022-01-21); PR #1115 merged 2022-01-03 with fguillot noting "I was able to test successfully this PR with client A".

---

## 1. Routing (VERIFIED)

`internal/http/server/routes.go`:
```go
// Google Reader API routing.
googleReaderHandler := googlereader.NewHandler(store)
appMux.HandleFunc("POST /accounts/ClientLogin", googleReaderHandler.ServeHTTP)
appMux.Handle("/reader/api/0/", googleReaderHandler)
```
`appMux` is wrapped with `http.StripPrefix(basePath, appHandler)` when `BASE_URL` has a path. There is **no config switch** to disable the Reader API (PR #3505 `DISABLE_GOOGLEREADER_API` closed unmerged; PR #3543 also closed). The Fever API is mounted alongside at `/fever/`.

`handler.go` `NewHandler` (Go 1.22+ `net/http` method patterns; gorilla/mux removed 2026-03-18):
```go
mux := http.NewServeMux()
mux.HandleFunc("POST /accounts/ClientLogin", h.clientLoginHandler)
mux.Handle("GET /reader/api/0/token", withApiKeyAuth(h.tokenHandler))
mux.Handle("POST /reader/api/0/edit-tag", withApiKeyAuth(h.editTagHandler))
mux.Handle("POST /reader/api/0/rename-tag", withApiKeyAuth(h.renameTagHandler))
mux.Handle("POST /reader/api/0/disable-tag", withApiKeyAuth(h.disableTagHandler))
mux.Handle("GET /reader/api/0/tag/list", withApiKeyAuth(h.tagListHandler))
mux.Handle("GET /reader/api/0/user-info", withApiKeyAuth(h.userInfoHandler))
mux.Handle("GET /reader/api/0/subscription/list", withApiKeyAuth(h.subscriptionListHandler))
mux.Handle("POST /reader/api/0/subscription/edit", withApiKeyAuth(h.editSubscriptionHandler))
mux.Handle("POST /reader/api/0/subscription/quickadd", withApiKeyAuth(h.quickAddHandler))
mux.Handle("GET /reader/api/0/stream/items/ids", withApiKeyAuth(h.streamItemIDsHandler))
mux.Handle("POST /reader/api/0/stream/items/contents", withApiKeyAuth(h.streamItemContentsHandler))
mux.Handle("POST /reader/api/0/mark-all-as-read", withApiKeyAuth(h.markAllAsReadHandler))
mux.Handle("GET /reader/api/0/", withApiKeyAuth(h.fallbackHandler))
mux.Handle("POST /reader/api/0/", withApiKeyAuth(h.fallbackHandler))
```
`fallbackHandler` logs `"[GoogleReader] API endpoint not implemented yet"` at debug and does `response.JSON(w, r, []string{})` → **HTTP 200, body `[]`** for *every* unknown path, and (INFERRED, high confidence from Go ServeMux semantics: the subtree pattern matches, so no 405) for every **wrong-method** request to a known path (e.g. `GET /reader/api/0/stream/items/contents` → `[]`; `POST /reader/api/0/stream/items/ids` → `[]`). Auth still applies to the fallback. Only `POST` is registered for ClientLogin.

**Not implemented** (all fall through to `[]`): `stream/contents`, `unread-count`, `subscription/import` (OPML), `subscription/export`, `preference/list`, `preference/stream/list`, `friend/list`, `stream/details`, `search/items/ids`, `item/edit`, `mark-all-as-read` on starred/read streams (see §10), `edit-tag` for `broadcast`/`like` (accepted, ignored), removal of a label via `subscription/edit r=`. Removed 2026-01-05: the CORS handler (PR #3956, "The Google Reader API is not supposed to be used by web clients").

## 2. Authentication (VERIFIED)

Credentials are per-user integration settings (`Settings > Integrations`): `googlereader_enabled`, `googlereader_username` (must be unique across users: `HasDuplicateGoogleReaderUsername` → `SELECT true FROM integrations WHERE user_id != $1 AND googlereader_username=$2 LIMIT 1`), `googlereader_password` stored as bcrypt via `crypto.HashPassword`. Enabling without both fields is rejected (`error.googlereader_missing_required_fields`, PR #4525, 2026-09-12: "An empty stored password makes the token computable from the username alone").

`POST /accounts/ClientLogin` (`clientLoginHandler`): `r.ParseForm()`; reads `Email`, `Passwd`, `output` from `r.Form` (merged query+body). Empty → `response.JSONUnauthorized` (401, `{"error_message":"access unauthorized"}`). Password check: `GoogleReaderUserCheckPassword` does `SELECT googlereader_password FROM integrations WHERE integrations.googlereader_enabled='t' AND integrations.googlereader_username=$1 AND integrations.googlereader_password <> ''` then `bcrypt.CompareHashAndPassword`. On success calls `h.store.SetLastLogin(integration.UserID)`, builds token, and:
```go
result := loginResponse{SID: token, LSID: token, Auth: token}
if output == "json" { response.JSON(w, r, result); return }
response.Text(w, r, result.String())   // "SID=%s\nLSID=%s\nAuth=%s\n"
```
`response.Text` sets `Content-Type: text/plain; charset=utf-8`, 200. client B parses this by splitting lines on `=` and taking `Auth`.

**Token** (`middleware.go`):
```go
func getAuthToken(username, password string) string {
	token := hex.EncodeToString(hmac.New(sha256.New, []byte(username+password)).Sum(nil))
	token = username + "/" + token
	return token
}
```
`password` here is the stored **bcrypt hash**, so token = `<greader_username>/<64 hex chars>` = HMAC-SHA256 of the empty message keyed by `username||bcryptHash`. Deterministic, never expires, identical for `SID`/`LSID`/`Auth` and for `/token`. It was HMAC-SHA1 (40 hex) until PR #4160 (2026-03-22) - that change invalidated every stored client token (INFERRED). Issue #3165 shows a SHA1-era token: `test/e6ba5bb2e563e46a54f9df556deaf5874c1c9209`.

**Middleware `serveValidated`** (registered as `validateApiKey`, deliberately non-inlined, PR #4310):
- `POST`: `r.ParseForm()` (failure → 401); `token = r.Form.Get("T")`; empty → 401. `T` may be in the query string or an `application/x-www-form-urlencoded` body. **The `Authorization` header is ignored for POST.**
- Otherwise (`GET`): `authorization := r.Header.Get("Authorization")`; `fields := strings.Fields(authorization)`; requires `len(fields)==2`, `fields[0]=="GoogleLogin"`, `auths := strings.Split(fields[1], "=")`, `len(auths)==2`, `auths[0]=="auth"`, `token = auths[1]`. **Query-string tokens are ignored for GET.** (INFERRED: a token containing `=` would be rejected; server B tokens are hex so this never bites.)
- Then `parts := strings.Split(token, "/")`; requires exactly 2 parts and non-empty username; `GoogleReaderUserGetIntegration(parts[0])`; `expectedToken := getAuthToken(...)`; `crypto.ConstantTimeCmp(expectedToken, token)` (PR #4159); loads user; `SetLastLogin`; sets context keys `UserIDContextKey`, `UserNameContextKey`, `UserTimezoneContextKey`, `IsAdminUserContextKey`, `IsAuthenticatedContextKey=true`, `GoogleReaderTokenKey=token`.
- Failure response (`response.go`):
```go
func sendUnauthorizedResponse(w http.ResponseWriter, r *http.Request) {
	response.NewBuilder(w, r).
		WithStatus(http.StatusUnauthorized).
		WithHeader("X-Reader-Google-Bad-Token", "true").
		WithHeader("Content-Type", "text/plain; charset=utf-8").
		WithBodyAsString("Unauthorized").
		Write()
}
```
So `/reader/api/0/*` auth failures are **plain-text 401 with `X-Reader-Google-Bad-Token: true`**, while `ClientLogin` failures are JSON 401.

`GET /reader/api/0/token` (`tokenHandler`): requires `request.IsAuthenticated(r)`; returns `request.GoogleReaderToken(r)` as plain text (no trailing newline). client B strips a trailing `\n` if present and caches the token; on 401/403 from a write it refetches `/token` once (`withWriteToken`).

Observed client A 5.4 request (issue #3314, packet capture) sends **both** mechanisms on POST:
```
POST /reader/api/0/subscription/edit
ac=edit&s=feed%2F184&a=user%2F1%2Flabel%2Fapp&T=<auth-token>
Content-Type: application/x-www-form-urlencoded
User-Agent: client A/5040002 CFNetwork/3826.500.111.1.1 Darwin/24.4.0
Authorization: GoogleLogin auth=<auth-token>
```
Note client A used the **numeric user id** form `user/1/label/app` (mirroring what server B emitted in `subscription/list`), while client B always sends `user/-/...`.

## 3. Stream identifiers (VERIFIED, `stream.go`, `prefix_suffix.go`)

```go
streamPrefix     = "user/-/state/com.google/"
userStreamPrefix = "user/%d/state/com.google/"
labelPrefix      = "user/-/label/"
userLabelPrefix  = "user/%d/label/"
feedPrefix       = "feed/"
readStreamSuffix="read"; starredStreamSuffix="starred"; readingListStreamSuffix="reading-list"
keptUnreadStreamSuffix="kept-unread"; broadcastStreamSuffix="broadcast"
broadcastFriendsStreamSuffix="broadcast-friends"; likeStreamSuffix="like"
```
```go
type StreamType int
const ( NoStream StreamType = iota; ReadStream; StarredStream; ReadingListStream; KeptUnreadStream;
        BroadcastStream; BroadcastFriendsStream; LabelStream; FeedStream; LikeStream )
type Stream struct { Type StreamType; ID string }
```
`getStream(streamID string, userID int64) (Stream, error)`: `feed/` prefix → `FeedStream` with `ID` = remainder (URL **or** numeric id, context-dependent); `user/<uid>/state/com.google/` **or** `user/-/state/com.google/` → switch on suffix (unknown suffix → error `"googlereader: unknown stream with id: %s"`); `user/<uid>/label/` or `user/-/label/` → `LabelStream{ID: label name}`; `""` → `NoStream` (no error); anything else → error `"googlereader: unknown stream type: %s"`. Only the *current* user's numeric id is accepted (`fmt.Sprintf(userStreamPrefix, userID)`); another user's id is an error. `getStreams` maps a slice, failing fast.

server B **emits** numeric-user forms everywhere (`user/1/state/com.google/starred`, `user/1/label/Tech`), never `user/-/`. Feed streams are emitted as `feed/<numeric feed id>`; but `subscription/edit ac=subscribe` expects `feed/<absolute URL>` (README: "So `feed/<...>` is not a single stable identifier format across all endpoints").

## 4. Item IDs (VERIFIED, `item.go`)

```go
const (
	ItemIDPrefix = "tag:google.com,2005:reader/item/"
	ItemIDFormat = "tag:google.com,2005:reader/item/%016x"
)
func convertEntryIDToLongFormItemID(entryID int64) string {
	// The entry ID is a 64-bit integer, so we need to format it as a 16-character hexadecimal string.
	return fmt.Sprintf(ItemIDFormat, entryID)
}
// Expected format: "tag:google.com,2005:reader/item/00000000148b9369" (hexadecimal string with prefix and padding)
// client B uses this format: "tag:google.com,2005:reader/item/2f2" (hexadecimal string with prefix and no padding)
// client A uses this format: "000000000000048c" (hexadecimal string without prefix and padding)
// Liferea uses this format: "12345" (decimal string)
// It returns the parsed ID as a int64 and an error if parsing fails.
func parseItemID(itemIDValue string) (int64, error) {
	var itemID int64
	if strings.HasPrefix(itemIDValue, ItemIDPrefix) {
		n, err := fmt.Sscanf(itemIDValue, ItemIDFormat, &itemID)
		if err != nil { return 0, fmt.Errorf("failed to parse hexadecimal item ID %s: %w", itemIDValue, err) }
		if n != 1 { return 0, fmt.Errorf("failed to parse hexadecimal item ID %s: expected 1 value, got %d", itemIDValue, n) }
		if itemID == 0 { return 0, fmt.Errorf("failed to parse hexadecimal item ID %s: item ID is zero", itemIDValue) }
		return itemID, nil
	}
	if len(itemIDValue) == 16 {
		if n, err := fmt.Sscanf(itemIDValue, "%016x", &itemID); err == nil && n == 1 { return itemID, nil }
	}
	itemID, err := strconv.ParseInt(itemIDValue, 10, 64)
	if err != nil { return 0, fmt.Errorf("failed to parse decimal item ID %s: %w", itemIDValue, err) }
	return itemID, nil
}
func parseItemIDsFromRequest(r *http.Request) ([]int64, error) {
	items := r.Form[paramItemIDs]          // "i", merged query+body
	if len(items) == 0 { return nil, errors.New("googlereader: no items requested") }
	...
}
```
Test vectors (`item_test.go`): `"12345"`→12345, `"tag:...item/00000000148b9369"`→344691561, `"tag:...item/2f2"`→754, `"000000000000046f"`→1135, `"tag:...item/272"`→626, `"0000000000000468"`→1128; `"tag:...item/000000000000000g"`, `"invalid_id"`, `""` → error. client A's bare form: `000000000000048c` → 1164.

Overflow / edge handling (INFERRED from Go semantics): `Sscanf` `%x` into `int64` goes through `strconv.ParseInt(...,16,64)`, so hex values ≥ 2^63 (e.g. two's-complement negatives `ffffffffffffffff`) are **rejected with an error**, not wrapped; Postgres bigserial IDs are positive so this never occurs. `%016x` in a scan format means "at most 16 hex digits" so a 17+-digit long-form would silently parse only the first 16 (no trailing-input check in `Sscanf`). Ambiguity: a **16-character purely-decimal** ID (≥10^15) would be interpreted as hex by the `len==16` branch - irrelevant at server B's ID scale but a real footgun for a design that mirrors it. The zero check exists only on the long form.

History that produced this: original 2022 code was `fmt.Sscanf(item, EntryIDLong, &itemID)` with fallback `strconv.ParseInt(item, 16, 64)`. Issue #1498 (lwindolf/Liferea, 2022-07): `/stream/items/ids` returns decimal, passing it back to `/items/contents` failed. PR #1517 changed fallback to base 10 (merged 2022-08-01) then was **reverted** in commit 3eb3ac0 (`ParseInt(item, 10, 64)` → `ParseInt(item, 16, 64)`); fguillot in #2960 (2024-12-30): "I don't recall exactly why the fix was reverted. I think it was breaking client A and it's widely used." → client A sends bare 16-hex, which base-10 parsing broke. Final resolution: PR #3321 (2025-05-04, long form + decimal) then PR #3325 (2025-05-05, all four forms, shipped in 2.2.9, 2025-05-26). Issue #2960 also notes "Some clients (e.g. RSSGuard) do convert short ids to long ids and succeed."

**Output forms**: `stream/items/ids` → decimal strings `{"id":"12345"}`; `stream/items/contents` → long form `tag:google.com,2005:reader/item/%016x`.

## 5. Parameter names (VERIFIED, `parameters.go`)

```go
paramItemIDs="i"; paramStreamID="s"; paramStreamExcludes="xt"; paramStreamFilters="it"
paramStreamMaxItems="n"; paramStreamOrder="r"; paramStreamStartTime="ot"; paramStreamStopTime="nt"
paramTagsRemove="r"; paramTagsAdd="a"; paramSubscribeAction="ac"; paramTitle="t"
paramQuickAdd="quickadd"; paramDestination="dest"; paramContinuation="c"; paramTimestamp="ts"
```
Note `r` is both sort order (stream endpoints) and remove-tag (edit-tag). `includeAllDirectStreamIds` is **not read anywhere**; `it` is parsed into `FilterTargets` and never used.

## 6. Stream filter parsing (VERIFIED, `request_modifier.go`)

```go
type requestModifiers struct {
	ExcludeTargets []Stream; FilterTargets []Stream; Streams []Stream
	Count int; Offset int; SortDirection string; StartTime int64; StopTime int64
	ContinuationToken string; UserID int64
}
func parseStreamFilterFromRequest(r *http.Request) (requestModifiers, error) {
	result := requestModifiers{SortDirection: "desc", UserID: request.UserID(r)}
	streamOrder := request.QueryStringParam(r, paramStreamOrder, "d")
	if streamOrder == "o" { result.SortDirection = "asc" }
	result.Streams, err = getStreams(request.QueryStringParamList(r, paramStreamID), userID)
	result.ExcludeTargets, err = getStreams(request.QueryStringParamList(r, paramStreamExcludes), userID)
	result.FilterTargets, err = getStreams(request.QueryStringParamList(r, paramStreamFilters), userID)
	result.Count = request.QueryIntParam(r, paramStreamMaxItems, 0)
	result.Offset = request.QueryIntParam(r, paramContinuation, 0)
	result.StartTime = request.QueryInt64Param(r, paramStreamStartTime, int64(0))
	result.StopTime = request.QueryInt64Param(r, paramStreamStopTime, int64(0))
	return result, nil
}
```
All of these read **`r.URL.Query()` only** (`request.QueryStringParam`, `QueryIntParam` - returns default when missing, non-numeric or negative). `r`: `o` → asc, anything else (default `d`) → desc. `ContinuationToken` is never populated (continuation is the integer `Offset`). Any unknown stream string in `s`/`xt`/`it` makes the whole request fail (500 JSON).

`checkOutputFormat(r)`: for POST does `ParseForm` and reads `r.Form.Get("output")`; for GET reads query `output`; anything but `json` → `errors.New("googlereader: only json output is supported")` → 400 (was 500 before PR #2405, Feb 2024; message then was `"output only as json supported"` as seen by FeedMe in #2129). Required by `tag/list`, `subscription/list`, `stream/items/ids`, `stream/items/contents`. **Not** required by `user-info` since PR #3957 (2026-01-05: "The `output` parameter seems to be optional and server B will always returns a JSON response").

## 7. `GET /reader/api/0/stream/items/ids` (VERIFIED)

Requires `output=json` and exactly one `s` (`len(rm.Streams) != 1` → 500 `"googlereader: only one stream type expected"`). Dispatch on `rm.Streams[0].Type`: `ReadingListStream`, `StarredStream`, `ReadStream`, `FeedStream`; anything else (including **label streams**) → 500 `"googlereader: unknown stream type %s"`.

Reading-list handler:
```go
builder := h.store.NewEntryQueryBuilder(rm.UserID).
	WithLimitAndMaximum(rm.Count, model.MaxEntryIDsLimit).   // MaxEntryIDsLimit = 10000
	WithOffset(rm.Offset).
	WithSorting(model.DefaultSortingOrder, rm.SortDirection) // "published_at"
for _, s := range rm.ExcludeTargets {
	switch s.Type {
	case ReadStream: builder = builder.WithStatuses(model.EntryStatusUnread)
	default: slog.Warn("[GoogleReader] Unknown ExcludeTargets filter type", ...)
	}
}
if rm.StartTime > 0 { builder = builder.AfterPublishedDate(time.Unix(rm.StartTime, 0)) }   // e.published_at > $n
if rm.StopTime > 0  { builder = builder.BeforePublishedDate(time.Unix(rm.StopTime, 0)) }   // e.published_at < $n
itemRefs, continuation, err := getItemRefsAndContinuation(*builder, rm)
response.JSON(w, r, streamIDResponse{itemRefs, continuation})
```
Starred handler: `WithStarred(true)` + limit/offset/sort + ot/nt; **`xt` ignored**. Read handler: `WithStatuses(model.EntryStatusRead)` + same; **`xt` ignored**. Feed handler: `feedID := strconv.ParseInt(rm.Streams[0].ID, 10, 64)` (URL form → 500), `WithFeedID(feedID)` + limit/offset/sort + ot/nt, then `if s.Type == ReadStream { builder = builder.WithoutStatus(model.EntryStatusRead) }` (added PR #2176 after RSS Guard's `s=feed/226&xt=user/-/state/com.google/read&ot=973551600` returned read items, issue #2171).

`WithLimitAndMaximum(limit, maximum)`: `if limit <= 0 || limit > maximum { limit = maximum }` - so **`n` omitted, 0, negative or >10000 → 10000**. (Regression 2.3.3 clamped to 1000 → issue #4479 "count is always 1000", fixed PR #4497 2026-08-09: "ID lists are cheap, and clients can still follow the continuation offset for the remainder".) `ot`/`nt` are **seconds**, strict `>`/`<` on `published_at`.

Continuation:
```go
func getItemRefsAndContinuation(builder storage.EntryQueryBuilder, rm requestModifiers) ([]itemRef, int, error) {
	rawEntryIDs, err := builder.GetEntryIDs()
	itemRefs := make([]itemRef, 0, len(rawEntryIDs))
	for _, entryID := range rawEntryIDs {
		itemRefs = append(itemRefs, itemRef{ID: strconv.FormatInt(entryID, 10)})
	}
	totalEntries, err := builder.CountEntries()      // second SQL: SELECT count(*) with same WHERE
	continuation := 0
	if len(itemRefs)+rm.Offset < totalEntries { continuation = len(itemRefs) + rm.Offset }
	return itemRefs, continuation, nil
}
```
Response structs:
```go
type itemRef struct {
	ID              string `json:"id"`
	DirectStreamIDs string `json:"directStreamIds,omitempty"`   // never set
	TimestampUsec   string `json:"timestampUsec,omitempty"`     // never set
}
type streamIDResponse struct {
	ItemRefs     []itemRef `json:"itemRefs"`
	Continuation int       `json:"continuation,omitempty,string"`  // emitted as "1000"; omitted when 0
}
```
So `c` is a **plain SQL OFFSET encoded as a JSON string**, not an opaque token (PR #1601, Oct 2022). INFERRED: with desc sort and new entries arriving between pages, offset pagination can duplicate/skip IDs; sorting is by `published_at` alone (no id tiebreaker), so ties are unstable across pages. `itemRefs` is `[]` (not null) when empty. No `directStreamIds`/`timestampUsec` ever.

## 8. `POST /reader/api/0/stream/items/contents` (VERIFIED)

POST only. `checkOutputFormat` (merged form `output=json`); `ParseForm`; `parseStreamFilterFromRequest` (only `r` sort direction from the **query string** has any effect; `s`/`xt` are parsed and ignored - but an invalid `s` value still errors); `parseItemIDsFromRequest` (`i` from merged `r.Form`, any of the 4 formats; none → 400 `"googlereader: no items requested"`).
```go
entries, err := h.store.NewEntryQueryBuilder(userID).
	WithEnclosures().
	WithEntryIDs(itemIDs...).                    // e.id = $1  or  e.id = ANY($1) (pq.Int64Array)
	WithSorting(model.DefaultSortingOrder, requestModifiers.SortDirection).
	GetEntries()
result := streamContentItemsResponse{
	Direction: "ltr",
	ID:        "user/-/state/com.google/reading-list",
	Title:     "Reading List",
	Updated:   time.Now().Unix(),
	Self:      []contentHREF{{HREF: config.Opts.BaseURL() + "/reader/api/0/stream/items/contents"}},
	Author:    userName,
	Items:     make([]contentItem, len(entries)),
}
```
Per entry: `categories` = `user/<uid>/state/com.google/reading-list`, then `user/<uid>/label/<Category.Title>` (if non-empty), then `user/<uid>/state/com.google/read` **only if** `entry.Status == "read"` (fix PR #2184 after #2183: previously only starred read entries got it), then `user/<uid>/state/com.google/starred` if starred. Never `kept-unread`. Content is rewritten by `mediaproxy.RewriteDocumentWithAbsoluteProxyURL(entry.Content)`; enclosures via `ProxifyEnclosureURL`.
```go
result.Items[i] = contentItem{
	ID:            convertEntryIDToLongFormItemID(entry.ID),
	Title:         entry.Title,
	Author:        entry.Author,
	TimestampUsec: strconv.FormatInt(entry.Date.UnixMicro(), 10),
	CrawlTimeMsec: strconv.FormatInt(entry.CreatedAt.UnixMilli(), 10),
	Published:     entry.Date.Unix(),
	Updated:       entry.ChangedAt.Unix(),
	Categories:    categories,
	Canonical:     []contentHREF{{HREF: entry.URL}},
	Alternate:     []contentHREFType{{HREF: entry.URL, Type: "text/html"}},
	Content:       contentItemContent{Direction: "ltr", Content: entry.Content},
	Summary:       contentItemContent{Direction: "ltr", Content: entry.Content},
	Origin:        contentItemOrigin{StreamID: feedPrefix + strconv.FormatInt(entry.FeedID, 10), Title: entry.Feed.Title, HTMLUrl: entry.Feed.SiteURL},
	Enclosure:     enclosures,   // []contentItemEnclosure{URL, Type}, no length
}
```
Structs (`response.go`):
```go
type streamContentItemsResponse struct {
	Direction string `json:"direction"`; ID string `json:"id"`; Title string `json:"title"`
	Self []contentHREF `json:"self"`; Updated int64 `json:"updated"`
	Items []contentItem `json:"items"`; Author string `json:"author"`
}
type contentItem struct {
	ID string `json:"id"`; Categories []string `json:"categories"`; Title string `json:"title"`
	CrawlTimeMsec string `json:"crawlTimeMsec"`; TimestampUsec string `json:"timestampUsec"`
	Published int64 `json:"published"`; Updated int64 `json:"updated"`; Author string `json:"author"`
	Alternate []contentHREFType `json:"alternate"`; Summary contentItemContent `json:"summary"`
	Content contentItemContent `json:"content"`; Origin contentItemOrigin `json:"origin"`
	Enclosure []contentItemEnclosure `json:"enclosure"`; Canonical []contentHREF `json:"canonical"`
}
type contentHREFType struct { HREF string `json:"href"`; Type string `json:"type"` }
type contentHREF struct { HREF string `json:"href"` }
type contentItemEnclosure struct { URL string `json:"url"`; Type string `json:"type"` }
type contentItemContent struct { Direction string `json:"direction"`; Content string `json:"content"` }
type contentItemOrigin struct { StreamID string `json:"streamId"`; Title string `json:"title"`; HTMLUrl string `json:"htmlUrl"` }
```
`crawlTimeMsec`/`timestampUsec` are **strings**, `published`/`updated` ints. History: `crawlTimeMsec` was emitted in microseconds until PR #2670 (2024-05-28, issue #2669, Read You broke; server A/FeedHQ do ms) - fix used `entry.Date.UnixMilli()`; current code uses `entry.CreatedAt.UnixMilli()` (crawl time = insertion time). Enclosures were missing until PR #3172 (2025-02-23, #3165). Unknown IDs are silently dropped; **zero matching entries → 200 with `"items": []`** in current code (there is no emptiness check; 2022-Feb 2024 it was a 500 `"no items returned from the database"`, PR #2405 made it a 400 with the IDs listed; some later refactor removed the check entirely - I could not pinpoint that commit). Top-level `id`/`title` are hard-coded to the reading list regardless of `s`.

## 9. `POST /reader/api/0/edit-tag` (VERIFIED)

```go
addTags, err := getStreams(r.PostForm[paramTagsAdd], userID)      // "a" - BODY ONLY
removeTags, err := getStreams(r.PostForm[paramTagsRemove], userID) // "r" - BODY ONLY
if len(addTags)==0 && len(removeTags)==0 → 500 "googlreader: add or/and remove tags should be supplied"
tags, err := checkAndSimplifyTags(addTags, removeTags)  // 500 on conflict
itemIDs, err := parseItemIDsFromRequest(r)               // "i" merged, 400 on failure
entries := NewEntryQueryBuilder(userID).WithEntryIDs(itemIDs...).GetEntries()
```
`checkAndSimplifyTags` → `map[StreamType]bool`: add `read`→`tags[ReadStream]=true`; add `kept-unread`→`tags[ReadStream]=false`; remove `read`→`false`; remove `kept-unread`→`true`; add/remove `starred`→`true`/`false`; `read` and `kept-unread` in the same request → `errSimultaneously` ("googlereader: kept-unread and read should not be supplied simultaneously"); starred in both a and r → error; `BroadcastStream, LikeStream` → `slog.Debug("Broadcast & Like tags are not implemented!")` and ignored; any other type (label, reading-list, feed…) → `"googlereader: unsupported tag type: %s"` 500.
Then loops entries, only changing state when it differs (`read && entry.Status == Unread`, `!read && entry.Status == Read`, `starred && !entry.Starred`, `!starred && entry.Starred` - the `!read`/`!starred` guards were added PR #4277, 2026-05-02 "fix incorrect read/starred toggling"), batching into `SetEntriesStatus(userID, ids, "read"|"unread")` and `SetEntriesStarredState(userID, ids, bool)`. Newly-starred entries are kept (`// filter the original array`) and pushed to third-party integrations via `go integration.SendEntry(e, settings)`. Returns plain `OK`. Historic bug: unstar via client A didn't work because `SetEntriesBookmarkedState(..., true)` was passed for unstarred IDs (issue #1360, PR #1376, Feb 2022). Issue #2172 (RSS Guard, "edit-tag silently fails" with `a=user/-/state/com.google/read` and long-form IDs) is closed; I could not read its comments (GitHub REST rate-limited) - likely the base16/base10 mismatch of that era (INFERRED).

## 10. Other write endpoints (VERIFIED)

`POST subscription/quickadd`: `quickadd` from merged form, `urllib.IsAbsoluteURL` else 400; `mfs.NewSubscriptionFinder(requestBuilder).FindSubscriptions(feedURL, rssBridgeURL, rssBridgeToken)` (feed discovery from HTML; PR #4390 2026-06-05 fixed it to use the configured `HTTP_CLIENT_USER_AGENT`); zero found → `{"numResults":0}`; else `subscribe(Stream{FeedStream, subscriptions[0].URL}, Stream{NoStream,""}, "", …)` → category = `store.FirstCategory(userID)` (none → 400 `errCategoryNotFound`, PR #4516); duplicate feed → `validator.ValidateFeedCreation` error → **500 `{"error_message": …}`** (not the Google `{"numResults":0,"error":"Already subscribed…"}` shape client B's `ReaderAPIQuickAddResult` also decodes - INFERRED mismatch). Success:
```go
type quickAddResponse struct {
	NumResults int64  `json:"numResults"`
	Query      string `json:"query,omitempty"`
	StreamID   string `json:"streamId,omitempty"`   // "feed/<id>"
	StreamName string `json:"streamName,omitempty"`
}
```
`POST subscription/edit`: `s` (repeated, merged form) → `getStreams`, empty/invalid → 400 `"googlereader: no valid stream IDs provided"`; `a` → `getStream` (400 on invalid); `t`, `ac`. `subscribe`: `subscribe(streamIds[0], newLabel, title, …)` where `streamIds[0].ID` must be the **feed URL**; `a` label → `getOrCreateCategory` (`""`→first category; existing title→that; else **create**); `t` applied after creation via `FeedModificationRequest{Title}`. `unsubscribe`: every `s` → `strconv.ParseInt(stream.ID, 10, 64)` → `store.RemoveFeed`. `edit`: if `t != ""` → `rename(streamIds[0], title)` (empty title `errEmptyFeedTitle`, unknown feed `errFeedNotFound` → 400); if `r.Form.Has("a")` → `newLabel.Type` must be `LabelStream` (400 `"destination must be a label"`) → `move()` → `getOrCreateCategory`. Rename + move in one request supported since PR #2239 (issue #2191, request `ac=edit&s=feed/199&t=newname&a=user%2F2%2Flabel%2F05_fun`). **`r=` (remove label) is never read** - client B's `deleteTagging`/`moveSubscription` send `r=user/-/label/X`; with only `r` server B does nothing and returns `OK`. Unknown `ac` → 400. Panic on missing feed/category fixed PR #3315 (issue #3314, client A.4 move).
`POST rename-tag`: `s` and `dest` must both be labels (400 `"googlereader: only labels supported"`), `dest` non-empty, source category missing → **404** JSON; duplicate title → 400 via `ValidateCategoryModification`.
`POST disable-tag`: repeated `s`, all labels (400 `"googlereader: only labels are supported"`); `RemoveAndReplaceCategoriesByName(userID, titles)` moves feeds to the first remaining category; deleting the last one fails (500).
`POST mark-all-as-read` (added PR #3320, 2025-05-04, shipped 2.2.9): `s` via `getStream`; `ts`:
```go
if timestampParsedValue > 0 {
	// It's unclear if the timestamp is in seconds or microseconds, so we try both using a naive approach.
	if len(timestampParamValue) >= 16 { before = time.UnixMicro(timestampParsedValue) } else { before = time.Unix(timestampParsedValue, 0) }
}
if before.IsZero() { before = time.Now() }
switch stream.Type {
case FeedStream:        MarkFeedAsRead(userID, feedID, before)         // feed id must be numeric, else 400
case LabelStream:       CategoryByTitle → nil → 404; MarkCategoryAsRead(userID, category.ID, before)
case ReadingListStream: MarkAllAsReadBeforeDate(userID, before)
}   // any other stream type: silent no-op, still "OK"
```

## 11. Read-only list endpoints (VERIFIED)

`GET user-info` → `{"userId":"1","userName":"demo","userProfileId":"1","userEmail":"demo"}` (all strings; `userEmail` is the server B username, not an email):
```go
type userInfoResponse struct {
	UserID string `json:"userId"`; UserName string `json:"userName"`
	UserProfileID string `json:"userProfileId"`; UserEmail string `json:"userEmail"`
}
```
`GET tag/list?output=json`:
```go
type tagsResponse struct { Tags []subscriptionCategoryResponse `json:"tags"` }
type subscriptionCategoryResponse struct {
	ID string `json:"id"`; Label string `json:"label,omitempty"`; Type string `json:"type,omitempty"`
}
```
Emits `{"id":"user/<uid>/state/com.google/starred"}` first (no label/type), then one `{"id":"user/<uid>/label/<Title>","label":"<Title>","type":"folder"}` per category. No `sortid`, no `reading-list`/`read`.
`GET subscription/list?output=json`:
```go
type subscriptionResponse struct {
	ID string `json:"id"`; Title string `json:"title"`
	Categories []subscriptionCategoryResponse `json:"categories"`
	URL string `json:"url"`; HTMLURL string `json:"htmlUrl"`; IconURL string `json:"iconUrl"`
}
type subscriptionsResponse struct { Subscriptions []subscriptionResponse `json:"subscriptions"` }
```
`id` = `feed/<numeric id>`; exactly **one** category always (server B is single-category-per-feed); `iconUrl` = `BASE_URL + "/feed-icon/" + ExternalIconID` or `""` (PR #3195). No `sortid`, no `firstitemmsec`. No ETag/Last-Modified - client B sends conditional-GET headers for this and `tag/list` but never gets a 304.

## 12. Every client-specific quirk/comment in the code (VERIFIED)
1. `item.go` header comment naming **client B** (`tag:…/2f2`, unpadded hex with prefix), **client A** (`000000000000048c`, bare padded hex), **Liferea** (`12345`, decimal) - and the canonical padded long form.
2. `handler.go` mark-all-as-read: "It's unclear if the timestamp is in seconds or microseconds, so we try both using a naive approach." (`len(ts) >= 16` → µs).
3. `checkAndSimplifyTags`: `slog.Debug("Broadcast & Like tags are not implemented!")`.
4. `fallbackHandler`: `"[GoogleReader] API endpoint not implemented yet"` → `[]` 200.
5. `NewHandler`: "The returned handler expects the base path to be stripped from the request URL."
6. `editTagHandler`: `// filter the original array` (keeps only newly-starred entries for integrations).
7. `middleware_test.go`: "The store is nil: the middleware must reject the token before querying it."
8. Commit-level: "feat(googlereader): avoid SQL query to fetch username in streamItemContentsHandler" (username comes from context); "remove output param check for user-info handler … more consistent with other open source RSS readers"; "generated tokens should not be logged even in debug mode"; PR #1402 "client B makes this API call [`s=feed/<id>` on items/ids] when adding new feeds".

## 13. Documented compatibility (VERIFIED)
`server B.app/docs/google_reader.html` (source `server B/website` `content/docs/google_reader.md`): "server B implements the Google Reader API. To activate the Google Reader API, go to the **Settings > Integrations** section and choose a username and password." Compatible Apps: **Capy Reader (Android), client B (iOS/macOS), client A >= 5 (iOS/macOS), RSS Guard**. Notes: "server B implements only a subset of the Google Reader API. Open a new issue if you think that something is missing." fguillot in #2129 (2023-10-15): "the actual Google Reader API implementation supports only client A and maybe few other clients like client B and RSS Guard."

## 14. How clients react to gaps (VERIFIED unless noted)
- **FeedMe / Fluent Reader** (#2129, open): call `GET /reader/api/0/stream/contents?output=json&n=100&xt=user/-/state/com.google/read&ot=0&s=user/-/state/com.google/reading-list` → get `[]` 200 → "can't fetch contents"; FeedMe also hit `user-info` without `output=json` (500 then; fixed 2026-01). Still unresolved ("Any update on this?" 2025-12).
- **Liferea** (#1498/#2960): passed decimal IDs from `items/ids` straight to `items/contents`; broken 2022-2025, fixed by PR #3325.
- **RSS Guard** (#1548/#2171/#2172, rssguard#780 "Status-Fixed"): initially couldn't fetch content; RSS Guard converts short ids to long form itself; `xt=read` on feed streams fixed server-side (PR #2176).
- **client A** (#1350): shows at most 10,000 items per source - consistent with server B's 10,000 cap on `items/ids`; (#1360) unstar broken until PR #1376; (#3314) folder move panic until PR #3315; sends bare 16-hex item IDs; sends `Authorization` header *and* `T` on POST; uses `user/<uid>/label/...` forms as emitted by the server.
- **Read You** (#2669): mis-handled µs `crawlTimeMsec`.
- **client B** (#4530, Sep 2026): read status not syncing - "It was a bug in client B an its solved with 7.1.4"; (#4042, open) NNW shows server B's truncated-content pseudo-titles because server B fills `title` server-side; (#3165) NNW doesn't render enclosures at all.

## 15. client B's actual wire behaviour against a Reader API server (VERIFIED from `Modules/Account/Sources/Account/ReaderAPI/*.swift`, `main`)
- server B users pick the **server A** account type (`Account.swift`: `case .server-a: ReaderAPIAccountDelegate(dataFolder:, variant: .server-a)`; there is no server B/generic type wired). `.server-a` adds `AccountBehaviors.disallowFeedInRootFolder` (plus `.disallowFeedInMultipleFolders` for all) - so every subscription must carry a category, which server B guarantees.
- Auth: `URLRequest+ReaderAPI.swift` sets `Authorization: GoogleLogin auth=<secret>` on every request (GET and POST); writes additionally include `T=<token>` in the body, token from `GET /reader/api/0/token` (cached; refetched once on 401/403).
- `ClientLogin`: POST form `Email`/`Passwd`; parses `Auth=` line; 404 → `urlNotFound`.
- Endpoints used: `token`, `disable-tag`, `rename-tag`, `tag/list?output=json`, `subscription/list?output=json`, `subscription/edit`, `subscription/quickadd`, `subscription/import` (OPML, POST `text/xml` body, treats any 200 as success - against server B this **silently no-ops** because the fallback returns 200 `[]`, INFERRED), `stream/items/contents`, `stream/items/ids`, `edit-tag`. Never `unread-count`, `stream/contents`, `mark-all-as-read`, `user-info`.
- `items/ids` query: always `n=1000&output=json`; allForAccount: `ot=<lastArticleFetchStartTime or now−3 months>&s=user/-/state/com.google/reading-list`; allForFeed: `ot=<now−3 months>&s=feed/<id>`; unread: `s=user/-/state/com.google/reading-list&xt=user/-/state/com.google/read`; starred: `s=user/-/state/com.google/starred`. Follows `continuation` by replacing `c`, recursing until the response has no `continuation`; an empty `itemRefs` page with a continuation keeps going. Decodes `{itemRefs:[{id}], continuation?: String}`.
- `items/contents`: POST body `T=…&output=json&i=tag:google.com,2005:reader/item/<%.16llx>&i=…` in chunks of **150**; IDs are its internal decimal strings re-encoded as 16-digit two's-complement hex. Decodes `{id, updated, items:[{id,title,author,summary{content},alternate[{href}],categories,published,crawlTimeMsec(String),timestampUsec(String),origin{streamId,title}}]}`; uses `summary.content` as HTML, `alternate.first.href` as external URL, `origin.streamId` to map to the feed, `published` as Double. Article uniqueID = last path segment of `id` parsed `UInt64(radix:16)` → `Int64(bitPattern:)` → decimal string; an ID that isn't an Int is dropped as "unsendable".
- `edit-tag`: POST `T=…&i=<long>&i=…&a=user/-/state/com.google/read` (or `r=`, or `…/starred`) in chunks of **1000**.
- `subscription/edit`: `T=…&s=<feed/id>&ac=edit[&r=user/-/label/<from>][&a=user/-/label/<to>][&t=<title>]`; `ac=unsubscribe`; quickadd `T=…&quickadd=<url>` then re-lists subscriptions and matches `subscription.id == result.streamId`; expects `numResults`, optional `error`, `streamId`.
- `rename-tag`: `T=…&s=user/-/label/<old>&dest=user/-/label/<new>`; `disable-tag`: `T=…&s=<folder externalID>`. Folder name = substring after `/label/` in tag ids.
- Sync algorithm: fetch all IDs since last fetch → **mark all of them read locally** → download unread IDs and starred IDs to correct state. So correctness depends entirely on `items/ids` with `xt=read` and `s=starred` being complete (hence the 10,000 cap/continuation matters).
- server A-specific: NNW un-escapes fullwidth `＆＜＞` in titles/authors/feed names.

## 16. Go idioms worth mirroring
- One `http.NewServeMux` with `"METHOD /path"` patterns plus `"GET /reader/api/0/"` and `"POST /reader/api/0/"` subtree catch-alls returning `[]`; mount from the root mux as `HandleFunc("POST /accounts/ClientLogin", h.ServeHTTP)` + `Handle("/reader/api/0/", h)` behind `http.StripPrefix(basePath, …)`.
- Auth as a middleware `func(next http.Handler) http.Handler` that branches on method (POST → `r.Form.Get("T")`, GET → header), stores identity in `context.WithValue`, compares tokens with `hmac.Equal`-style constant time.
- Typed enum `StreamType int` + `Stream{Type, ID}` + `getStream` built from `strings.HasPrefix`/`TrimPrefix` against `fmt.Sprintf(userStreamPrefix, userID)` and the `-` form; `getStreams` fail-fast over a slice.
- Parameter-name constants file; `requestModifiers` struct with `String()` for debug logging; `parseStreamFilterFromRequest` reading only `r.URL.Query()`.
- `parseItemID` cascade: prefix check → `fmt.Sscanf(v, ItemIDFormat, &id)` → `len==16 && Sscanf("%016x")` → `strconv.ParseInt(v, 10, 64)`; `fmt.Sprintf("tag:google.com,2005:reader/item/%016x", id)` for output; table-driven tests with the four client forms.
- Response structs with `json:"continuation,omitempty,string"` to emit a numeric offset as a JSON string and drop it when 0; `omitempty` on `directStreamIds`/`timestampUsec`.
- Sentinel errors (`errFeedNotFound`, `errCategoryNotFound`, `errEmptyFeedTitle`, `errSimultaneously`) mapped with `errors.Is` to 400 vs 500; single JSON error shape `{"error_message": "..."}` via `generateJSONError`; a response `Builder` (`WithStatus/WithHeader/WithBodyAsString/Write`) for the odd plain-text 401.
- Query builder with `WithLimitAndMaximum(limit, max)` clamping, `WithOffset`, `AfterPublishedDate/BeforePublishedDate`, `GetEntryIDs()` + `CountEntries()` for continuation.
- `slog` structured logging with `client_ip`, `user_agent`, `handler`, `user_id` on every handler; never log the token.

## 17. Version timeline (VERIFIED from release pages / commit log)
2.0.35 (2022-01-21) "Add Google Reader API implementation (experimental)" · 2022-02 unstar fix (#1376) · 2022-04 `feed/<id>` streams on items/ids (#1402) · 2022-08 base-10 fix (#1517) then reverted · 2022-10 date filtering on all id streams (#1588) + offset continuation (#1601) · 2023-11 `xt` on feed streams (#2176), read category (#2184) · 2023-12 rename+move (#2239) · 2024-02 400 instead of 500 (#2405) · 2024-05 `crawlTimeMsec` ms (#2670) · 2025-02 enclosures (#3172) · 2025-03 `iconUrl` (#3195) · **2.2.9 (2025-05-26)**: panic fixes, 400s, `mark-all-as-read`, all four item-ID forms · 2026-01 user-info `output` optional, CORS removed, tokens not logged · 2026-03 constant-time compare, HMAC-SHA256, README, gorilla/mux removed · 2026-05 toggle guard (#4277), quickadd UA (#4390) · 2026-08 ids limit 10000 (#4497), no-category panic (#4516) · 2026-09 reject empty-password tokens (#4525).

## Claims
- [high LB] server B mounts exactly these Reader routes: POST /accounts/ClientLogin; GET token, tag/list, user-info, subscription/list, stream/items/ids; POST edit-tag, rename-tag, disable-tag, subscription/edit, subscription/quickadd, stream/items/contents, mark-all-as-read; plus GET and POST subtree fallbacks under /reader/api/0/ that return HTTP 200 with body []. (server B repo: internal/googlereader/handler.go)
- [high LB] Any unimplemented or wrong-method path under /reader/api/0/ (e.g. stream/contents, unread-count, subscription/import, GET stream/items/contents) returns 200 `[]` after successful auth, not 404/405; FeedMe and Fluent Reader fail on stream/contents because of this. (server B issue #2129)
- [high LB] For POST requests the token is read only from form field T (query or x-www-form-urlencoded body, merged via r.Form); for GET only from `Authorization: GoogleLogin auth=<token>` parsed with strings.Fields then strings.Split("="). Auth failure on /reader/api/0/* is 401 text/plain `Unauthorized` with header `X-Reader-Google-Bad-Token: true`; ClientLogin failure is 401 JSON {"error_message":"access unauthorized"}. (server B repo: internal/googlereader/middleware.go)
- [high LB] Token format is `<greader_username>/<hex>` where hex = HMAC-SHA256 (empty message) keyed by username+bcryptHash; it is deterministic, never expires, and is returned identically as SID, LSID, Auth and by GET /reader/api/0/token (plain text). It was HMAC-SHA1 before 2026-03-22. (server B repo: internal/googlereader/middleware.go)
- [high LB] ClientLogin reads form fields Email, Passwd, output; returns text `SID=..\nLSID=..\nAuth=..\n` by default or JSON {SID,LSID,Auth} when output=json; the Google Reader username must be unique across users and the password is bcrypt-hashed. (server B repo: internal/googlereader/handler.go)
- [high LB] parseItemID accepts four forms: `tag:google.com,2005:reader/item/%016x` (padded), `tag:google.com,2005:reader/item/2f2` (unpadded hex, client B), bare 16-char hex `000000000000048c` (client A), and decimal `12345` (Liferea); output uses fmt.Sprintf("tag:google.com,2005:reader/item/%016x", id) in stream/items/contents and plain decimal strings in stream/items/ids. (server B repo: internal/googlereader/item.go)
- [high LB] A 2022 change to parse the short form as base 10 (PR #1517) was reverted because it broke client A, which sends bare 16-digit hex; the four-format parser landed in PR #3325 (2025-05-05, server B 2.2.9). (server B issue #2960)
- [medium] Hex item IDs >= 2^63 are rejected by fmt.Sscanf %x into int64 (no two's-complement wrapping); a 17+-digit long-form hex silently parses only its first 16 digits; a purely-decimal 16-character string is treated as hex by the len==16 branch. (server B repo: internal/googlereader/item.go)
- [high LB] stream/items/ids requires output=json and exactly one `s`; supports only reading-list, starred, read and feed/<numeric id> streams; label streams return 500 `unknown stream type LabelStream`. (server B repo: internal/googlereader/handler.go)
- [high LB] n omitted/0/negative/>10000 is clamped to 10000 (model.MaxEntryIDsLimit) via WithLimitAndMaximum; the 2.3.3 regression that clamped to 1000 was fixed in PR #4497 (2026-08-09). (server B PR #4497)
- [high LB] Continuation `c` is a plain integer SQL offset, emitted as JSON string via `json:"continuation,omitempty,string"` and omitted when 0; computed as len(itemRefs)+offset when that is < CountEntries(). (server B repo: internal/googlereader/handler.go)
- [high LB] `r=o` gives ascending, anything else descending; sort column is published_at only. `ot`/`nt` are Unix seconds applied as strict published_at > / < . `xt=user/-/state/com.google/read` is honored only on reading-list (WithStatuses unread) and feed streams (WithoutStatus read); ignored on starred/read streams. `it` is parsed but ignored. includeAllDirectStreamIds is never read and directStreamIds/timestampUsec are never emitted in itemRefs. (server B repo: internal/googlereader/request_modifier.go)
- [high LB] All stream filter parameters (s, xt, it, n, c, r, ot, nt) are read from r.URL.Query() only; for the POST-only stream/items/contents, only the query-string `r` affects sorting, while output and i come from merged form values. (server B repo: internal/googlereader/request_modifier.go)
- [high LB] stream/items/contents is POST-only, requires output=json, returns direction=ltr, id hard-coded to user/-/state/com.google/reading-list, title "Reading List", self[0].href = BASE_URL+/reader/api/0/stream/items/contents, updated=now, author=username, and items with id (long form), categories (user/<uid>/state/com.google/reading-list, user/<uid>/label/<Title>, read if read, starred if starred), title, author, timestampUsec (string, entry.Date µs), crawlTimeMsec (string, entry.CreatedAt ms), published, updated (ChangedAt), alternate[{href,type:text/html}], canonical[{href}], summary and content both containing the same HTML, origin{streamId:feed/<id>,title,htmlUrl}, enclosure[{url,type}]. (server B repo: internal/googlereader/response.go)
- [high LB] Categories emitted by server B always use the numeric user id (user/1/...), never user/-/...; client A mirrors that back (user/1/label/app) while client B always sends user/-/... - getStream accepts both. (server B issue #3314)
- [medium] When none of the requested item IDs exist, current stream/items/contents returns 200 with "items": [] (no emptiness check); historically it was a 500 until Feb 2024 then a 400 (PR #2405). (server B repo: internal/googlereader/handler.go)
- [high LB] crawlTimeMsec was emitted in microseconds until PR #2670 (2024-05-28) which broke Read You; server A/FeedHQ emit milliseconds. (server B issue #2669)
- [high LB] edit-tag reads `a` and `r` from r.PostForm (body only) but `i` from merged r.Form; supports read/kept-unread/starred add-remove semantics, errors on read+kept-unread or starred-in-both, ignores broadcast/like, errors on any other tag type; only changes state when it differs from current; returns text OK. (server B repo: internal/googlereader/handler.go)
- [high LB] subscription/edit ac=subscribe expects s=feed/<absolute URL> while ac=edit and ac=unsubscribe expect s=feed/<numeric id>; `a` label is created if missing; `r` (remove label) is never read so a pure remove-from-folder is a silent OK no-op; rename+move in one request works since PR #2239. (server B repo: internal/googlereader/README.md)
- [high LB] quickadd requires an absolute URL, runs feed discovery, subscribes to the first discovered feed in the user's first category, returns {numResults:1,query,streamId:"feed/<id>",streamName} or {numResults:0}; a duplicate feed produces a 500 JSON error_message rather than a numResults:0 + error object. (server B repo: internal/googlereader/handler.go)
- [high LB] mark-all-as-read (added 2025-05-04) takes s and ts; ts with >=16 digits is treated as microseconds else seconds, absent means now; supports feed/<id>, label and reading-list streams; other stream types are silent OK no-ops; missing label returns 404. (server B repo: internal/googlereader/handler.go)
- [high LB] tag/list returns only the starred pseudo-tag {id} and folders {id,label,type:"folder"}; subscription/list returns id feed/<n>, title, exactly one categories entry, url, htmlUrl, iconUrl; neither includes sortid; user-info returns userId/userName/userProfileId/userEmail as strings with userEmail = username and no output param required since 2026-01. (server B repo: internal/googlereader/handler.go)
- [high] server B's docs list Capy Reader (Android), client B (iOS/macOS), client A >= 5 (iOS/macOS) and RSS Guard as compatible and state only a subset of the API is implemented. (server B docs: google_reader)
- [high LB] client B (server A account type, variant .server-a with disallowFeedInRootFolder) calls items/ids with n=1000&output=json, ot=<since>, s=reading-list / feed/<id> / starred, xt=read for unread; follows `c` continuation until absent; fetches contents by POST with T, output=json and i=tag:google.com,2005:reader/item/%.16llx in chunks of 150; sends edit-tag in chunks of 1000; sends Authorization: GoogleLogin on all requests plus T on writes; never calls unread-count, stream/contents, mark-all-as-read or user-info; parses item ids via UInt64(radix:16) → Int64(bitPattern:) → decimal. (https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] client B's sync marks every ID returned by the since-fetch as read locally, then re-downloads unread and starred ID lists to correct state, so a server's items/ids?xt=read and s=starred completeness (with continuation) is what determines read/star correctness. (https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [medium] client B OPML import posts to /reader/api/0/subscription/import and treats any HTTP 200 as success, so against server B's `[]` fallback it silently imports nothing. (https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [medium] client A caps a single source at 10,000 items, consistent with server B's 10,000 items/ids cap (issue #1350, closed as client A behavior). (server B issue #1350)
- [high] Google Reader API shipped in server B 2.0.35 (2022-01-21) as experimental after PR #1115, which fguillot merged after testing with client A; client B and RSS Guard were also reported working in that PR. (server B PR #1115)
- [high] There is no configuration option to disable the Google Reader API; PRs #3505 and #3543 proposing DISABLE_GOOGLEREADER_API / auto-disable were closed unmerged; CORS support was removed 2026-01-05. (server B PR #3505)

## Open questions
- client A's exact request set is not public (closed source). Verified only from server B comments/issues: bare 16-hex item IDs, Authorization header plus T on POST, numeric-user label ids, 10,000-item cap. Unknown: whether client A ever requests label streams on stream/items/ids (server B would 500), whether it calls unread-count or mark-all-as-read, what `ts` unit it sends, and how it handles `continuation`.
- Comments on server B issues #2172 (RSS Guard edit-tag silently failing), #1548, #1498 and rssguard#780 could not be read (GitHub REST rate limit exhausted; HTML pages did not render comments). Likely base16/base10 item-ID mismatch of the 2022-2023 era, unconfirmed.
- Which commit removed the 400/500 'no items returned' check from stream/items/contents (current main returns 200 with items: []) was not pinpointed.
- Capy Reader (listed as compatible) was not examined; its request patterns against server B are unknown.
- Whether client A tolerates `user/-/` vs `user/<id>/` prefixes in emitted categories/tag ids is unverified; server B emits numeric ids and client A works, so mirroring numeric ids is the safe choice.

## Sources
- server B repo: internal/googlereader/handler.go
- server B repo: internal/googlereader/item.go
- server B repo: internal/googlereader/item_test.go
- server B repo: internal/googlereader/middleware.go
- server B repo: internal/googlereader/middleware_test.go
- server B repo: internal/googlereader/parameters.go
- server B repo: internal/googlereader/prefix_suffix.go
- server B repo: internal/googlereader/request_modifier.go
- server B repo: internal/googlereader/response.go
- server B repo: internal/googlereader/stream.go
- server B repo: internal/googlereader/README.md
- server B repo: internal/http/server/routes.go
- server B repo: internal/http/request/params.go
- server B repo: internal/http/response/json.go
- server B repo: internal/http/response/text.go
- server B repo: internal/http/response/builder.go
- server B repo: internal/storage/entry_query_builder.go
- server B repo: internal/storage/integration.go
- server B repo: internal/model/entry.go
- server B repo: internal/ui/integration_update.go
- server B repo: internal/ui/form/integration.go
- server B docs: google_reader
- (link removed)
- (link removed)
- (link removed)
- server B PR #1115
- server B issue #1109
- server B issue #1350
- server B issue #1360
- server B PR #1376
- server B PR #1402
- server B issue #1498
- server B PR #1517
- (link removed)
- (link removed)
- server B issue #1548
- https://github.com/martinrotter/rssguard/issues/780
- server B PR #1588
- server B PR #1601
- server B issue #2129
- server B issue #2171
- server B issue #2172
- server B PR #2176
- server B issue #2183
- server B PR #2184
- server B issue #2191
- server B PR #2239
- server B PR #2405
- server B issue #2669
- server B PR #2670
- server B issue #2960
- server B issue #3165
- server B PR #3172
- server B PR #3195
- server B issue #3314
- server B PR #3315
- server B PR #3320
- server B PR #3321
- server B PR #3325
- server B PR #3505
- server B PR #3543
- server B PR #3956
- server B PR #3957
- server B issue #4042
- server B PR #4145
- server B PR #4159
- server B PR #4160
- server B PR #4277
- server B PR #4390
- server B issue #4479
- server B PR #4497
- server B PR #4516
- server B PR #4525
- server B issue #4530
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIEntry.swift
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPISubscription.swift
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPITag.swift
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIUnreadEntry.swift
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIVariant.swift
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/ReaderAPI/URLRequest+ReaderAPI.swift
- https://github.com/Ranchero-Software/client B/blob/main/Modules/Account/Sources/Account/Account.swift
