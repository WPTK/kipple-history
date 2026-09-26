# netnewswire

# NetNewsWire Google Reader API client — findings from source (main @ 2026-09-21, ≈ shipped 7.1.4)

## 0. Where the code lives / version context

- Path (current): `Modules/Account/Sources/Account/ReaderAPI/` — `ReaderAPICaller.swift` (677 lines), `ReaderAPIAccountDelegate.swift`, `ReaderAPIEntry.swift`, `ReaderAPISubscription.swift`, `ReaderAPITag.swift`, `ReaderAPITagging.swift` (dead Feedbin-shaped structs, unused), `ReaderAPIUnreadEntry.swift` (itemRefs wrapper), `ReaderAPIVariant.swift`, `URLRequest+ReaderAPI.swift`. Tests: `Modules/Account/Tests/AccountTests/ReaderAPI/ReaderAPIEntryTests.swift`. Transport: `Modules/RSWeb/Sources/RSWeb/WebServices/URLSession+Webservice.swift`, `URLSession+WebserviceJSON.swift`. Credentials: `Modules/Secrets/Sources/Secrets/Credentials.swift`. UI: `Mac/Preferences/Accounts/AccountsReaderAPIWindowController.swift`, `iOS/Account/CredentialsAccountView.swift`.
- Heavy Reader-API churn landed 2026-07-07 → 2026-09-01 (token refresh, 429 pause, pending-status protection, ID-encoding fixes, unsigned hex parse, conditional GET, folder creation). Latest stable Mac release is **7.1.4 (2026-09-20)**; iOS 7.1.4 (7213) TestFlight 2026-09-19. All commits below dated ≤ 2026-09-01 are in 7.1.4; the 09-16 "Throw sync database errors" commit is very likely in it too (b2 was 09-17).

## 1. Account variants and configuration

`ReaderAPIVariant` (verified):
```swift
public enum ReaderAPIVariant: Sendable { case generic, freshRSS, inoreader, bazQux, theOldReader
  public var host: String { .inoreader: "https://www.inoreader.com", .bazQux: "https://bazqux.com", .theOldReader: "https://theoldreader.com", default: "" } }
```
`AccountType` (Account.swift) has **no generic and no Miniflux case**: `freshRSS = 20, inoreader = 21, bazQux = 22, theOldReader = 23`. `Account.init` maps each to `ReaderAPIAccountDelegate(dataFolder:, variant:)`. `.generic` is unreachable from the shipped UI; **Miniflux (and Kipple) users must pick "FreshRSS"**, so Kipple gets exactly the `.freshRSS` code path. Native-Miniflux PRs #5335 (closed) / #5405 (open) are unmerged.

Base URL (`apiBaseURL`): for `.generic`/`.freshRSS` it is `accountSettings.endpointURL` — **exactly what the user typed** (whitespace-trimmed, stored in UserDefaults). NNW then does `baseURL.appendingPathComponent("/accounts/ClientLogin")` / `("/reader/api/0/...")`. It does **not** add `/api/greader.php` itself. Placeholders: Mac `"https://fresh.rss.net/api/greader.php"`, iOS `"API URL: https://fresh.rss.net/api/greader.php"`. For Inoreader/BazQux/TOR the URL field is hidden and `variant.host` is used. `needsAPIURL` is true only for `.freshRSS`. Duplicate-account check (`AccountManager.duplicateServiceAccount`) is type+username but allows same username on a different `endpointURL` (fix for #4377).

FreshRSS-specific behaviors (`ReaderAPIAccountDelegate.behaviors`): always `.disallowFeedInMultipleFolders`; for `.freshRSS` additionally `.disallowFeedInRootFolder` (because every FreshRSS feed must have a category — issue #4923). Inoreader-only: headers `AppId`/`AppKey`, `tag/list?types=1`, folders = tags with `type == "folder"`, quota headers `X-Reader-Zone1-Usage`/`X-Reader-Zone1-Limit`/`X-Reader-Limits-Reset-After` (skip status downloads at ≥90% of limit). The Old Reader-only: item IDs passed through raw (no hex↔dec), `disable-tag` never called (folder removal is local only).

## 2. Transport, headers, session

`URLSession.makeWebserviceSession()` (one session per caller): `requestCachePolicy = .reloadIgnoringLocalCacheData`, `timeoutIntervalForRequest = 60`, `timeoutIntervalForResource = 120`, `waitsForConnectivity = true`, `httpShouldSetCookies = false`, `httpCookieAcceptPolicy = .never`, `httpCookieStorage = nil`, `urlCache = nil`, **`httpMaximumConnectionsPerHost = 1`** (all calls serialized), `httpAdditionalHeaders = ["User-Agent": <Info.plist UserAgent>]`.

User-Agent (both Mac and iOS Info.plist `UserAgent` key): **`NetNewsWire (RSS Reader; https://netnewswire.com/)`** (confirmed also in FreshRSS admin logs in #5274 and Proxyman capture in #3717).

`URLRequest(url:readerAPICredentials:conditionalGet:)`:
- `credentials.type == .readerBasic` → `Content-Type: application/x-www-form-urlencoded`, `httpMethod = "POST"`, body = `URLComponents{queryItems:[Email=<username>, Passwd=<secret>]}.enhancedPercentEncodedQuery` (allowed set = `urlQueryAllowed` minus `!*'();:@&=+$,/?%#[]`, then `%20`→`+`). Fix for #1903 (`&`/`=` in password).
- `credentials.type == .readerAPIKey` → header **`Authorization: GoogleLogin auth=<Auth>`**, method left as GET unless caller sets POST.
- Conditional GET adds `If-Modified-Since` (unless value contains "2038") and `If-None-Match`.

ATS: both Info.plists set `NSAllowsArbitraryLoads = true`, so plain `http://` endpoints are allowed by policy.

Status validation (`validatedHTTPResponse`): **200…399 → success** (so a 304 with empty body passes and JSON callers return `nil`), **429 → `WebserviceError.tooManyRequests(retryAfter: <Retry-After seconds>)`**, anything else → `WebserviceError.httpError(status:, responseBody: first 500 chars of whitespace-collapsed body)`. Redirects are followed by URLSession. JSON decoding: `JSONDecoder` with `.iso8601` dates (unused here) and default keys; empty body → `nil`; malformed/missing required key → `DecodingError` → surfaced as "The service returned an invalid response."

## 3. Authentication flow

**ClientLogin** (`validateCredentials(endpoint:)`): `POST <base>/accounts/ClientLogin`, form body `Email=…&Passwd=…` (no `service=`, `accountType=`, `source=`, `output=`). Response parsed as UTF-8 text, split on `"\n"`, each line split on **every** `"="`; a line is accepted only if it yields exactly 2 parts; needs key `Auth`. ⇒ **the Auth value must not contain `=`** (a base64-padded token would be silently skipped → `CredentialsError.missingAccessToken`). `SID`/`LSID` ignored. HTTP 404 → `AccountError.urlNotFound` ("The API URL wasn't found."); other errors shown raw ("HTTP 401: unauthorized"). On success both credentials are stored in Keychain: `readerBasic` (username/password) and `readerAPIKey` (username/Auth).

**T token** (`requestAuthorizationToken`): `GET <base>/reader/api/0/token` with `Authorization: GoogleLogin auth=…`; body is the token as plain text; exactly one trailing `"\n"` stripped. Cached in memory (`accessToken`) for the process lifetime — **never proactively refreshed**. `withWriteToken` (added 2026-07-07, shipped 7.1.2): runs the operation; on `httpError` **401 or 403** it clears the cache, fetches a new token, retries **once**. Before 7.1.2 a stale T caused perpetual 401s on edit-tag (FreshRSS admin report #5274; FreshRSS log `Invalid POST token: <40 hex>ZZZZZZZZZZZZZZZZZ` in #3731 after an API-password change).

**401/403 re-login**: in `refreshAll`'s catch, `AccountError.wrapped(error).isCredentialsError` (status 401 or 403) → load stored `readerBasic` creds → `validateCredentials` (ClientLogin) → store new `readerAPIKey` → `try await refreshAll()` again. There is no recursion guard in code; if ClientLogin succeeds but API calls keep 401ing (e.g., a proxy stripping `Authorization`), this loops (inferred).

## 4. Endpoint-by-endpoint wire format (exact)

`ReaderAPIEndpoints`: `/accounts/ClientLogin`, `/reader/api/0/token`, `/reader/api/0/disable-tag`, `/reader/api/0/rename-tag`, `/reader/api/0/tag/list`, `/reader/api/0/subscription/list`, `/reader/api/0/subscription/edit`, `/reader/api/0/subscription/quickadd`, `/reader/api/0/subscription/import`, `/reader/api/0/stream/items/contents`, `/reader/api/0/stream/items/ids`, `/reader/api/0/edit-tag`. **Never called:** `user-info`, `unread-count`, `stream/contents`, `mark-all-as-read`, `stream/items/count`, `preference/*`, `friend/list`. Mark-all-read is done client-side via edit-tag batches.

Constants: `read = "user/-/state/com.google/read"`, `starred = "user/-/state/com.google/starred"`, `readingList = "user/-/state/com.google/reading-list"`.

### tag/list
`GET <base>/reader/api/0/tag/list?output=json` (+`&types=1` Inoreader), GoogleLogin header, conditional GET (key `"tags"`). Decoded as `{"tags":[{"id":String (required), "type":String?}]}` (`ReaderAPITagContainer.tags` required). Folder tags = `tagID.contains("/label/")`; `folderName` = substring after `/label/`; `folder.externalID` = full tag id (e.g. `user/-/label/Comics`). The etag is stored only after the model is updated and only on 200 (`storeConditionalGetIfNeeded`).

### subscription/list
`GET <base>/reader/api/0/subscription/list?output=json`, conditional GET (key `"subscriptions"`). Decoded `{"subscriptions":[{"id":String req, "title":String?, "categories":[{"id":String req,"label":String req}] **required array (may be empty)**, "url":String?, "htmlUrl":String?, "iconUrl":String?}]}`. `feed.feedID = feed.externalID = subscription.id` (e.g. `"feed/130"`); feed URL = `url` else `id` stripped of `feed/`. Each refresh: feeds not in list are removed; existing feeds get `name` (if non-empty, after fullwidth decode) and `homePageURL` updated — **feed `url` changes are not applied** (#4712), `iconUrl` unused. Folder membership = `categories[].id` matched against folder externalIDs; a feed whose category has no local folder stays at top level (fix 2026-09-01).

### stream/items/ids
`GET <base>/reader/api/0/stream/items/ids?` with query items appended in this order: `n=1000`, `output=json`, then by type:
- `.allForAccount`: `ot=<Int unix seconds>`, `s=user/-/state/com.google/reading-list`. `ot` = `accountSettings.lastArticleFetchStartTime` (the HTTP `Date` header of the **first page of the previous complete run**, set only when the continuation loop ends) else `now − 3 months`.
- `.allForFeed` (after subscribing): `ot=<now − 3 months>`, `s=feed/<id>`.
- `.unread`: `s=user/-/state/com.google/reading-list`, `xt=user/-/state/com.google/read` (**no `ot`** — full unread set).
- `.starred`: `s=user/-/state/com.google/starred` (**no `ot`**).
- Pagination: `c=<continuation>` (previous `c` removed, new appended). No `r`, `nt`, `it`, `includeAllDirectStreamIds`, `T`, `client`.
Response decoded as `{"itemRefs":[{"id":String?}]?, "continuation":String?}` — **`itemRefs[].id` must be a JSON string** (a number fails decoding), and the ids are used **verbatim** as NNW's `articleID` (no conversion). Loop: while `continuation` present, request next page; a page with zero refs but a continuation keeps looping (an always-present continuation = infinite loop). `Date` header parsed with `DateFormatter "EEEE, dd LLL yyyy HH:mm:ss zzz"`, `en_US_POSIX`; if unparseable, `lastArticleFetchStartTime` stays nil → 3-month window every refresh. Real-world log (#5171): `reader/api/0/stream/items/ids?n=1000&output=json&s=user/-/state/com.google/reading-list&xt=user/-/state/com.google/read` and `…&s=user/-/state/com.google/starred`, every 120 s while the app is active even with refresh = "Manually only".

### stream/items/contents
`POST <base>/reader/api/0/stream/items/contents`, `Content-Type: application/x-www-form-urlencoded`, body **`T=<token>&output=json&i=tag:google.com,2005:reader/item/<16-hex>&i=…`**, **150 ids per request** (`chunked(into: 150)` in `refreshMissingArticles`), wrapped in `withWriteToken`. Decoded `ReaderAPIEntryWrapper { id: String (required), updated: Int (**required, JSON integer**), items: [ReaderAPIEntry] (required, key "items") }`. `ReaderAPIEntry`: `id` String req; `title` String?; `author` String?; `published` Double? (unix seconds, JSON number); `crawlTimeMsec` String?; `timestampUsec` String?; **`summary` object required** (`{content: String?}`); `alternate` `[{href: String?}]?`; **`categories` `[String]` required**; **`origin` object required** (`{streamId: String?, title: String?}`). Ignored entirely: `content`, `canonical`, `updated` (per item), `enclosure`, `likingUsers`, etc. Mapping to `ParsedItem`: `syncServiceID = uniqueID = entry.uniqueID(variant:)`; `feedURL = origin.streamId` (**must equal `subscription.id`**; entries without `streamId` are dropped); `url = nil`; `externalURL = alternate?.first?.url`; `title` (fullwidth-decoded); `contentHTML = summary = summary.content`; `datePublished = Date(timeIntervalSince1970: published)`; `dateModified = nil`; `authors` = one `ParsedAuthor(name: author)`; no tags/attachments/images. `categories` are **not** used for read/starred (statuses come from the ids lists); articles are inserted with `defaultRead: true` then reconciled.

### edit-tag
`POST <base>/reader/api/0/edit-tag`, form body **`T=<token>&i=tag:google.com,2005:reader/item/<16-hex>&i=…&a=user/-/state/com.google/read`** (or `r=`; state `read`/`starred`), **up to 1000 ids per request**, four passes per send (unread: `r=…read`; read: `a=…read`; starred: `a=…starred`; unstarred: `r=…starred`). No `async`, `ac`, or `s`. Success = any 2xx/3xx; body ignored. On failure the batch is re-queued (`resetSelectedForProcessing`) and retried on every later sync forever — see #3717 (TOR returning 404 `<errors type="array"><error>Not found</error></errors>` for a batch with one stale id wedged the account until it was deleted). Article IDs that aren't `Int`-parsable (non-TOR) are "unsendable", deleted from the queue with Error Log entry "Dropped %d article status changes that can't be encoded for this service."

### subscription/edit
Body `T=<token>&s=<subscriptionID>&ac=edit` + optional `&r=user/-/label/<enc>` (remove), `&a=user/-/label/<enc>` (add), `&t=<enc title>`. Rename feed → `t=` only; add to folder → `a=` only; move → `r=`+`a=`; remove from one of several folders → `r=`. Unsubscribe: `T=<token>&s=<id>&ac=unsubscribe`. **`changeSubscription` catches and only logs errors** — rename/move failures are silent. Encoding for `t`/`a`/`r`/`quickadd`/rename-tag names: `CharacterSet.urlHostAllowed` minus `+` and `&` (so space→`%20`, `+`→`%2B`, but `=`, `;`, `,`, `$` stay raw).

### subscription/quickadd
Body `T=<token>&quickadd=<enc feed URL>`. Decoded `{numResults: Int (required), error: String?, streamId: String?}`; `numResults == 0` → not found. NNW then **re-fetches subscription/list (with its stored etag!)** and matches `subscriptions.first { $0.feedID == subResult.streamId }`; nil list (304) or no match → `createErrorNotFound`. ⇒ the server's subscription/list ETag/Last-Modified must change when subscriptions change, or be omitted. Subscribe sequence: FeedFinder on the URL (JSON Feed candidates filtered out) → quickadd → subscription/list → (folder) `subscription/edit ac=edit&a=` → (custom name) `subscription/edit ac=edit&t=` → `stream/items/ids?s=feed/N&ot=…` → mark all read locally → unread ids + starred ids → contents. This is the "duplicate subscribe" seen in #3512 (then `ac=subscribe`, now `ac=edit`).

### rename-tag / disable-tag / import
`rename-tag`: `T=<token>&s=user/-/label/<enc old>&dest=user/-/label/<enc new>`. `disable-tag`: `T=<token>&s=<folder.externalID>` (raw tag id, not re-encoded). No create-tag endpoint exists: `createFolder` keeps the folder local with `externalID == nil` until a feed is tagged into it; `syncFolders` never deletes such folders (fix for #3834, 7.1.3). `subscription/import`: `POST` raw OPML bytes, `Content-Type: text/xml`, GoogleLogin header, **no `T`**, requires `statusCode == 200` exactly.

## 5. Item-ID handling (load-bearing)

`ReaderAPIEntry.uniqueID(variant:)`: take last `/`-component of `id`; TOR → return it raw; else `UInt64(idPart, radix: 16)` → `String(Int64(bitPattern:))` (decimal, two's-complement signed). Non-hex → returns whole `id` string (which then never matches the ids-list id → article orphaned). `itemIDParameter`: TOR → raw; else `Int(articleID)` → `String(format: "%.16llx", idValue)` → `i=tag:google.com,2005:reader/item/<16 hex>`. Tests: `00058b10ce338909` ↔ `"1560279178774793"`, `ffffffffffffcdef` ↔ `"-12817"`, `0000000000000000` ↔ `"0"`. History: contents request was unpadded/wrong for negative IDs until 2026-08-02; hex parse was signed (overflowed on high-bit IDs → status dropped as unsendable) until 2026-09-01 ("Fixed bug where some FreshRSS, BazQux, Inoreader, and The Old Reader articles could never be marked read or starred on the server", 7.1.4).

**Consequence for a server:** `stream/items/ids` must return **decimal int64 strings** (e.g. `"1560279178774793"`), and `stream/items/contents` must return the **same numbers as `tag:google.com,2005:reader/item/` + zero-padded 16-hex** (two's complement for negatives). Hex or long-form ids in `itemRefs` would make every id "unsendable" and every article orphaned. FreshRSS does exactly this (`'id' => '' . $entryId, //64-bit decimal`; `'tag:google.com,2005:reader/item/' . dec2hex(id)`), as does Miniflux (`strconv.FormatInt(entryID, 10)`; `fmt.Sprintf(ItemIDFormat, entryID)` = `%016x`). Both servers accept `i=` as long-form hex or bare decimal (FreshRSS: `if (!ctype_digit($e_id) || $e_id[0] === '0') hex2dec(basename($e_id))`; Miniflux `parseItemID` accepts prefixed hex, bare 16-hex, or decimal).

Timestamps: only `published` is used (seconds, Double). `crawlTimeMsec`/`timestampUsec` are decoded as optional **strings** but unused (if present as numbers, decoding fails).

## 6. Sync algorithm (delegate)

`refreshAll` (skipped while rate-limited):
1. `refreshAccount`: tag/list → subscription/list → `BatchUpdate { syncFolders; syncFeeds; syncFeedFolderRelationship }` → store etags (200 only).
2. `try? sendArticleStatus()` — queued local changes (SyncDatabase `Sync.sqlite3`), failure does not stop the refresh.
3. `retrieveItemIDs(.allForAccount)` (reading-list since `ot`) → **`markAsReadAsync(all returned ids)`** (creates status rows read=true for unknown ids).
4. `refreshArticleStatus`: unread ids (full) → `markAsUnread(server − local − pending)`, `markAsRead(local − server − pending)`; starred ids (full) → same for starred. Pending unsent local changes are excluded both directions (fix 2026-08-02). Note: a server-unread id NNW has never seen gets a status row now → is fetched in step 5. Items evicted on the server vanish from the unread list → marked read locally (#5302, Brent: by design).
5. `refreshMissingArticles`: `select articleID from statuses s where (starred=1 or dateArrived>?) and not exists (select 1 from articles …)` with cutoff `now − 90 days` → contents in chunks of 150 → `updateAsync(defaultRead: true)`.

`syncArticleStatus` (app foreground / feed selection; the #5171 2-minute pattern): send, then (non-Inoreader) full unread + starred downloads. `markArticles`: local update → `SyncStatus(articleID,key,flag)` rows; if pending > 100 → background send. Send batches of 1000 per key/flag; success deletes rows, failure resets them. #5428 (7.1.4): `selectForProcessing` built one UPDATE with an OR per row → SQLite `Expression tree is too large (maximum depth 1000)` once >999 rows queued → statuses never sent again; fixed by grouping by key with `IN (...)`.

Rate limiting: `SyncRateLimiter` — 429 pauses **all** sync for `Retry-After` seconds or **1 hour default**; 403 is not treated as rate-limit for Reader API. Inoreader quota headers as above.

## 7. Other data-model details
- Folder externalID for a new folder = `"user/-/label/\(name)"` (unencoded).
- FreshRSS escapes `& < >` in titles/author/feed names as fullwidth `＆ ＜ ＞` (compat mode `escapeToUnicodeAlternative`); NNW maps them back (`decodingFullwidthEscapedCharacters`, #5143, 7.1.3). Kipple should not do this.
- NNW keeps articles ~90 days for sync accounts and drops "read, unstarred, really old" incoming items; it is "not meant for long-term storage" (Brent, #5302).

## 8. Server-side facts confirmed in FreshRSS / Miniflux source (context for quirks)
- FreshRSS `ClientLogin` reply: `SID=<u>/<sha1>\nLSID=null\nAuth=<u>/<sha1>\n`; token = `str_pad(sha1(...), 57, 'Z')`, **never expires** (`//TODO: Implement real token that expires`); `checkToken` accepts `''` (FeedMe) and literal `'x'` (comment: `//Reeder`) as valid T. Requires "Allow API access" + a separate **API password** (web password fails → "Unauthorized"; #4690, #3731). Correct URL `https://host/api/greader.php` (some installs `/p/api/greader.php`); wrong path → NNW "The API URL wasn't found."
- FreshRSS compat item: `id` long-form hex, `crawlTimeMsec` (string), `timestampUsec` (string), `published` (int), `title`, `canonical[{href}]`, `alternate[{href}]`, `categories` = reading-list + `user/-/label/<Category>` + `org.freshrss` states, `origin{streamId,htmlUrl,title}`, **`summary.content`** (truncated to `API_MAX_COMPAT_CONTENT_LENGTH`); `content` only in non-compat mode. Miniflux emits both `content.content` and `summary.content` (same body), `updated: time.Now().Unix()`, `continuation` as a string.
- **`ot` semantics**: FreshRSS filters `min(date) OR min(lastSeen)`; Miniflux `AfterPublishedDate`. Open PR #5156 (Feb 2026, unmerged): an item published before desktop's `lastArticleFetchStartTime` but read on the phone before desktop ingested it is never discovered by the reading-list query (unread items are still caught by the `xt=read` list). Proposal: always use the 3-month window for `.freshRSS`. A server that applies `ot` to crawl/arrival time avoids the gap.
- Miniflux 2022 (#3512): 500 on `stream/items/ids?s=feed/N` (fixed miniflux PR 1402); "destination must be a label" when `r=`+`a=` combined; unread toggling was a Miniflux bug fixed in 2.0.39.

## 9. Issue digest (server-relevant)
- #5428 (7.1.4) >999 queued statuses wedge — client bug, fixed.
- #5274 FreshRSS admin: repeated `POST /api/greader.php/reader/api/0/edit-tag` 401 — stale cached T (pre-7.1.2). Server must answer stale T with 401/403 (not 400) for `withWriteToken` to recover.
- #5266 read status not syncing (iOS) — local device issue, closed.
- #5302 Miniflux 15-day eviction → NNW marks read — by design.
- #4707 read state reset (FreshRSS, iOS) — "Believed fixed in 7.1.2".
- #4944 iOS couldn't add FreshRSS with `home.local` / `192.168.0.2` (Mac fine) — fixed 7.1.3, root cause undocumented (ATS is arbitrary-loads on both).
- #4690/#3731 FreshRSS setup: API access + API password + `/api/greader.php`; `curl -u` basic auth 401 is expected.
- #4408 creds "disappear" every few weeks → believed fixed 7.0.2 (undocumented).
- #3834 folders unable to be created on FreshRSS — fixed 7.1.3 by lazy folder creation.
- #4923 (open, 7.2.1) Uncategorized always shown/deletable in NNW; FreshRSS mandates a category.
- #4712 (open) feed URL edits on server not reflected (NNW keys by `feed/N`).
- #3717 TOR edit-tag 404 wedged status queue forever.
- #4381 "cancelled" = Caddy HTTP/3 quic-go + iOS 18, not NNW.
- #5171 items/ids unread+starred every 2 min regardless of refresh setting.
- #1903 `&`/`=` in password broke ClientLogin body — fixed via URLQueryItem.
- #4476/#3001 Inoreader app-wide quota.
- PR #5399 (open) custom HTTP headers for self-hosted; PR #5156 (open) `ot` window.

## 10. Kipple implications (derived)
Serve at whatever prefix the user will type (NNW appends `/accounts/ClientLogin` and `/reader/api/0/*`); accept `Email`/`Passwd` POST; Auth token without `=`; `token` GET returns plain text; return 401 for bad/stale T and bad Auth; never 429 casually (1-hour pause); `itemRefs.id` decimal int64 strings, item `id` 16-hex long form; `published` integer, `updated` integer at wrapper level, `crawlTimeMsec`/`timestampUsec` strings; always emit `summary.content`, `categories`, `origin.streamId == subscription.id`; `subscription/list` always includes `categories` (may be `[]`), category `{id,label}` both strings; `quickadd` returns integer `numResults` + `streamId`; support `n=1000` + `c` continuation with `continuation` omitted on the last page; support `s=feed/N`, `s=reading-list&xt=read`, `s=starred`, `ot`; accept 1000-id edit-tag bodies (~50–70 KB) and 150-id POST contents; **return 2xx for edit-tag on unknown ids**; either omit ETag/Last-Modified on list endpoints or ensure they change on any list change; send an RFC 7231 `Date` header; put the Cloudflare Access bypass on `/accounts/ClientLogin` and `/reader/api/0/*` (an Access redirect → 200 HTML → decoding error / missingAccessToken).

## Claims
- [high] NetNewsWire's Reader API client lives in Modules/Account/Sources/Account/ReaderAPI/ (ReaderAPICaller.swift, ReaderAPIAccountDelegate.swift, ReaderAPIEntry.swift, ReaderAPISubscription.swift, ReaderAPITag.swift, ReaderAPIUnreadEntry.swift, ReaderAPIVariant.swift, URLRequest+ReaderAPI.swift) on the main branch. (https://github.com/Ranchero-Software/NetNewsWire/tree/main/Modules/Account/Sources/Account/ReaderAPI)
- [high LB] AccountType has only freshRSS(20), inoreader(21), bazQux(22), theOldReader(23) as Reader API types; there is no generic or Miniflux account type, so Kipple/Miniflux users must choose FreshRSS and get the .freshRSS variant code path. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/Account.swift)
- [high LB] For the FreshRSS variant the base URL is exactly the user-typed endpointURL; NNW appends '/accounts/ClientLogin' and '/reader/api/0/...' via appendingPathComponent and does not add '/api/greader.php' itself (placeholder text is 'https://fresh.rss.net/api/greader.php'). (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] ClientLogin is POST <base>/accounts/ClientLogin with form body 'Email=<user>&Passwd=<pass>' (URLQueryItem percent-encoded, %20 replaced by +); no service/accountType/source params are sent. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/URLRequest+ReaderAPI.swift)
- [high LB] The ClientLogin response is parsed line-by-line, each line split on every '=' and accepted only if it yields exactly two parts, requiring an 'Auth' key; therefore the Auth token value must not contain '=' characters. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] All authenticated requests carry the header 'Authorization: GoogleLogin auth=<Auth>'; User-Agent is 'NetNewsWire (RSS Reader; https://netnewswire.com/)' from Info.plist; cookies are disabled and httpMaximumConnectionsPerHost is 1. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/WebServices/URLSession+Webservice.swift)
- [high LB] The T token is fetched with GET <base>/reader/api/0/token, the plain-text body is used with one trailing newline stripped, cached in memory for the process lifetime, and re-fetched once only when a token-bearing request returns HTTP 401 or 403 (withWriteToken). (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] HTTP statuses 200-399 are treated as success (a 304 with empty body yields a nil result), 429 becomes WebserviceError.tooManyRequests(retryAfter) which pauses all syncing for Retry-After seconds or 1 hour by default, and any other status becomes httpError(status, first 500 chars of body). (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/WebServices/URLSession+Webservice.swift)
- [high LB] A 401 or 403 during refreshAll triggers re-login via ClientLogin with the stored username/password, storing a new Auth token and re-running refreshAll. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [high LB] stream/items/ids is a GET with n=1000&output=json and, per stream: reading-list with ot=<unix seconds> (allForAccount), s=feed/<id> with ot=<now-3 months> (allForFeed), reading-list with xt=user/-/state/com.google/read and no ot (unread), s=user/-/state/com.google/starred with no ot (starred); pagination via c=<continuation>; no r, nt, or T parameters. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] itemRefs[].id must be a JSON string (decoded as String?) and is used verbatim as NNW's articleID with no conversion; the loop continues while a 'continuation' key is present, even for pages with zero itemRefs. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIUnreadEntry.swift)
- [high LB] stream/items/contents is a POST with form body 'T=<token>&output=json&i=tag:google.com,2005:reader/item/<16-hex>&i=...' with 150 ids per request. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [high LB] The contents response wrapper requires 'id' (String), 'updated' (Int) and 'items'; each item requires 'id' (String), 'summary' (object), 'categories' ([String]) and 'origin' (object); missing required keys or wrong JSON types fail decoding of the whole batch. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIEntry.swift)
- [high LB] NNW reads article HTML only from summary.content and ignores the 'content' object, 'canonical', per-item 'updated', 'crawlTimeMsec' and 'timestampUsec' (the latter two are decoded as optional strings); the link is alternate[0].href; the date is 'published' as unix seconds. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [high LB] Items are mapped to feeds via origin.streamId, which must equal the subscription 'id' from subscription/list (e.g. 'feed/130'); items without origin.streamId are dropped. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [high LB] Item 'categories' are not used to derive read/starred state; read and starred come exclusively from the stream/items/ids unread and starred lists, and articles are inserted with defaultRead: true. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [high LB] Item ID conversion: the last '/' component of the item id is parsed as UInt64 hex and reinterpreted as signed Int64 decimal for NNW's articleID; the reverse encodes Int(articleID) as String(format: "%.16llx") with the 'tag:google.com,2005:reader/item/' prefix. Tests: 00058b10ce338909 <-> 1560279178774793, ffffffffffffcdef <-> -12817. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Tests/AccountTests/ReaderAPI/ReaderAPIEntryTests.swift)
- [high LB] Because itemRefs ids are used raw and edit-tag re-encodes them via Int(articleID), stream/items/ids must return decimal int64 strings and contents/edit-tag must use the equivalent zero-padded 16-hex long form; non-integer articleIDs are classed 'unsendable' and permanently dropped from the status queue. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [high LB] edit-tag is POST with form body 'T=<token>&i=<long-form id>&i=...&a=user/-/state/com.google/read' (or r=, or the starred state), sent in batches of up to 1000 ids, in four passes (unread, read, starred, unstarred); a failed batch is re-queued and retried on every subsequent sync. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] A server that returns a non-2xx for edit-tag when some ids are unknown wedges NNW's status queue indefinitely (The Old Reader returned 404 '<errors type="array"><error>Not found</error></errors>' and the only fix was removing and re-adding the account). (https://github.com/Ranchero-Software/NetNewsWire/issues/3717)
- [high LB] subscription/edit uses ac=edit with optional r=user/-/label/<enc>, a=user/-/label/<enc>, t=<enc title>, and ac=unsubscribe for deletion; errors in changeSubscription are caught and only logged, so rename/move failures are silent to the user. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] subscription/quickadd is POST 'T=<token>&quickadd=<enc url>'; the response must contain integer numResults and streamId; NNW then re-fetches subscription/list (with its stored conditional-GET headers) and requires an entry whose id equals streamId, otherwise the subscribe fails with 'The feed couldn't be found and can't be added.' (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] tag/list and subscription/list are GET ?output=json with conditional GET (If-None-Match / If-Modified-Since); the etag is stored only on a 200 response after the model is updated; a 304 yields nil and the sync step is skipped. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] subscription/list entries require 'id' (String) and 'categories' (array of {id,label} strings, may be empty); 'title', 'url', 'htmlUrl', 'iconUrl' are optional; folders are tags whose id contains '/label/', with the folder name taken after '/label/'. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPISubscription.swift)
- [high LB] NNW never calls user-info, unread-count, stream/contents, mark-all-as-read, stream/items/count or preference endpoints; the full set is ClientLogin, token, tag/list, subscription/list, subscription/edit, subscription/quickadd, subscription/import, stream/items/ids, stream/items/contents, edit-tag, rename-tag, disable-tag. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high] There is no create-folder API call: a new folder stays local (externalID nil) until a feed is tagged into it via subscription/edit a=; rename-tag sends 'T=&s=user/-/label/<old>&dest=user/-/label/<new>' and disable-tag sends 'T=&s=<tag id>'. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [high LB] refreshAll order: tag/list, subscription/list, send queued statuses (failures ignored), fetch reading-list ids since ot and mark them all read locally, fetch full unread and starred id lists and reconcile (excluding pending local changes), then fetch contents for statuses lacking articles that are starred or newer than 90 days. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [high LB] An article that disappears from the server's unread list (e.g. evicted by retention) is marked read locally on the next reconcile; the maintainer confirmed this is intended behaviour. (https://github.com/Ranchero-Software/NetNewsWire/issues/5302)
- [high] lastArticleFetchStartTime (the next ot) is taken from the HTTP Date header of the first page of the reading-list ids request, parsed with DateFormatter 'EEEE, dd LLL yyyy HH:mm:ss zzz' (en_US_POSIX), and only committed when the continuation loop completes; if nil, ot falls back to now minus 3 months. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/HTTPDateInfo.swift)
- [high] On app activity NNW runs syncArticleStatus, which sends queued statuses and then downloads the full unread and starred id lists; a FreshRSS admin observed these two requests every 120 seconds even with refresh set to 'Manually only'. (https://github.com/Ranchero-Software/NetNewsWire/issues/5171)
- [high LB] FreshRSS and Miniflux apply the ot parameter to the entry's published date (FreshRSS: min date OR min last-seen; Miniflux: AfterPublishedDate), so items published before NNW's last fetch but read elsewhere before desktop ingested them are never discovered; PR #5156 proposing a fixed 3-month window for FreshRSS remains unmerged. (https://github.com/Ranchero-Software/NetNewsWire/pull/5156)
- [high LB] FreshRSS emits itemRefs ids as 64-bit decimal strings, item ids as 'tag:google.com,2005:reader/item/'+16-hex, crawlTimeMsec and timestampUsec as strings, published as an integer, and in compat mode puts the body in summary.content (truncated) rather than content.content; its ClientLogin returns 'SID=..\nLSID=null\nAuth=..\n' and its T token is a 57-char sha1 padded with 'Z' that never expires. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/p/api/greader.php)
- [medium] FreshRSS's checkToken accepts an empty T (FeedMe) and the literal T value 'x' with a source comment attributing it to Reeder. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/p/api/greader.php)
- [high] Miniflux emits itemRefs ids as decimal strings, item ids as %016x long form, both content.content and summary.content, continuation as a string, and its parseItemID accepts prefixed hex (padded or not), bare 16-hex, or decimal. (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/item.go)
- [high] FreshRSS escapes & < > in titles, author and feed names as fullwidth characters; NNW 7.1.3+ maps ＆＜＞ back to & < > (issue #5143). (https://github.com/Ranchero-Software/NetNewsWire/issues/5143)
- [high] For FreshRSS accounts NNW applies disallowFeedInRootFolder and disallowFeedInMultipleFolders; FreshRSS requires every feed to have a category and NNW's handling of 'Uncategorized' is an open issue targeted at 7.2.1. (https://github.com/Ranchero-Software/NetNewsWire/issues/4923)
- [medium] Until 7.1.2 (commit 'Refresh ReaderAPI authentication token as needed', 2026-07-07) NNW cached the T token forever, producing repeated 401s on edit-tag observed by a FreshRSS admin (#5274) and FreshRSS 'Invalid POST token' warnings after an API-password change (#3731). (https://github.com/Ranchero-Software/NetNewsWire/issues/5274)
- [high] NNW 7.1.4 fixed a SyncStatusTable bug where queuing more than 999 statuses produced SQLite 'Expression tree is too large (maximum depth 1000)' and statuses were never sent again. (https://github.com/Ranchero-Software/NetNewsWire/issues/5428)
- [high] FreshRSS setup with NNW requires enabling 'Allow API access', creating a separate API password under Profile > API Management, and using https://host/api/greader.php as the API URL; the web password does not work and HTTP Basic auth is not used. (https://github.com/Ranchero-Software/NetNewsWire/issues/3731)
- [high] Both the iOS and Mac Info.plist set NSAppTransportSecurity NSAllowsArbitraryLoads = true, so plain http:// Reader API endpoints are permitted by App Transport Security. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/iOS/Resources/Info.plist)
- [high] subscription/import posts raw OPML with Content-Type text/xml, no T token, and requires exactly HTTP 200. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high] Values for t=, a=, r=, quickadd= and rename-tag names are percent-encoded with CharacterSet.urlHostAllowed minus '+' and '&', leaving '=', ';', ',' and '$' unencoded. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)

## Open questions
- Does NNW HTML-entity-decode the Reader API item 'title' (and origin.title) before display, or treat it as plain text? FreshRSS chose fullwidth escaping precisely because clients differ; Kipple needs to know whether to send '&amp;' or '&' in titles. Not verified in RSParser/Articles code.
- Does DateFormatter pattern 'EEEE, dd LLL yyyy HH:mm:ss zzz' (full weekday name) leniently parse a standard RFC 7231 Date header ('Thu, 24 Sep 2026 …')? If not, lastArticleFetchStartTime is never set and NNW always uses the 3-month ot window (harmless but heavier). Could not execute Swift here.
- Root cause of #4944 (iOS could not add FreshRSS with a local hostname/IP while Mac could; fixed in 7.1.3) is undocumented in the issue; ATS is arbitrary-loads on both platforms so it was not ATS.
- Go-specific: NNW leaves ';' unencoded in t=/a=/r= values; Go's url.ParseQuery (used by r.ParseForm) rejects semicolons and drops that pair. Confirm Kipple's form parsing handles feed titles / folder names containing ';' (or accept the loss).
- Inferred, not observed: refreshAll's 401/403 handler re-runs ClientLogin and refreshAll recursively without a guard; if ClientLogin succeeds but API calls keep returning 401 (e.g. a proxy stripping Authorization, or Cloudflare Access intercepting only some paths), does NNW loop indefinitely? Kipple's Cloudflare Access bypass must cover both /accounts/ClientLogin and /reader/api/0/*.
- Does HTTPURLResponse.allHeaderFields lookup of 'ETag'/'Last-Modified' in HTTPConditionalGetInfo(headers:) behave case-insensitively on all supported OS versions? Affects whether Kipple's header casing matters for NNW's conditional GET.
- Whether the unmerged native-Miniflux PRs (#5335 closed, #5405 open) will ever ship; if so Miniflux users leave the FreshRSS path, but this does not affect Kipple, which will continue to be added as a 'FreshRSS' account.
- Whether Reeder Classic actually sends T=x (FreshRSS source comment) — relevant to the Reeder researcher: Kipple may need to accept a dummy/empty T token for Reeder while still validating T for NNW.

## Sources
- https://github.com/Ranchero-Software/NetNewsWire/tree/main/Modules/Account/Sources/Account/ReaderAPI
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIEntry.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPISubscription.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPITag.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIUnreadEntry.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIVariant.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/URLRequest+ReaderAPI.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Tests/AccountTests/ReaderAPI/ReaderAPIEntryTests.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/Account.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/AccountError.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/AccountBehaviors.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/AccountSettings.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/AccountManager.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/SyncRateLimiter.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/WebServices/URLSession+Webservice.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/WebServices/URLSession+WebserviceJSON.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/HTTPConditionalGetInfo.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/HTTPDateInfo.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/URLComponents+RSWeb.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/RSWeb/Sources/RSWeb/UserAgent.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Secrets/Sources/Secrets/Credentials.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/SyncDatabase/Sources/SyncDatabase/SyncStatusTable.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/ArticlesDatabase/Sources/ArticlesDatabase/ArticlesTable.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/ArticlesDatabase/Sources/ArticlesDatabase/StatusesTable.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Mac/Preferences/Accounts/AccountsReaderAPIWindowController.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/iOS/Account/CredentialsAccountView.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Mac/Resources/Info.plist
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/iOS/Resources/Info.plist
- https://api.github.com/repos/Ranchero-Software/NetNewsWire/commits?path=Modules/Account/Sources/Account/ReaderAPI
- https://github.com/Ranchero-Software/NetNewsWire/releases/tag/mac-7.1.4
- https://github.com/Ranchero-Software/NetNewsWire/releases/tag/mac-7.1.3
- https://github.com/Ranchero-Software/NetNewsWire/releases/tag/mac-7.1.2
- https://github.com/Ranchero-Software/NetNewsWire/releases
- https://github.com/Ranchero-Software/NetNewsWire/pull/5156
- https://github.com/Ranchero-Software/NetNewsWire/pull/5156.patch
- https://github.com/Ranchero-Software/NetNewsWire/issues/5428
- https://github.com/Ranchero-Software/NetNewsWire/issues/5274
- https://github.com/Ranchero-Software/NetNewsWire/issues/5266
- https://github.com/Ranchero-Software/NetNewsWire/issues/5302
- https://github.com/Ranchero-Software/NetNewsWire/issues/5171
- https://github.com/Ranchero-Software/NetNewsWire/issues/5143
- https://github.com/Ranchero-Software/NetNewsWire/issues/4944
- https://github.com/Ranchero-Software/NetNewsWire/issues/4923
- https://github.com/Ranchero-Software/NetNewsWire/issues/4712
- https://github.com/Ranchero-Software/NetNewsWire/issues/4707
- https://github.com/Ranchero-Software/NetNewsWire/issues/4690
- https://github.com/Ranchero-Software/NetNewsWire/issues/4476
- https://github.com/Ranchero-Software/NetNewsWire/issues/4408
- https://github.com/Ranchero-Software/NetNewsWire/issues/4381
- https://github.com/Ranchero-Software/NetNewsWire/issues/3834
- https://github.com/Ranchero-Software/NetNewsWire/issues/3731
- https://github.com/Ranchero-Software/NetNewsWire/issues/3717
- https://github.com/Ranchero-Software/NetNewsWire/issues/3512
- https://github.com/Ranchero-Software/NetNewsWire/issues/3001
- https://github.com/Ranchero-Software/NetNewsWire/issues/1903
- https://github.com/Ranchero-Software/NetNewsWire/pull/5405
- https://github.com/Ranchero-Software/NetNewsWire/pull/5335
- https://github.com/Ranchero-Software/NetNewsWire/pull/5399
- https://hachyderm.io/api/v1/statuses/115870547755336623
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/p/api/greader.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/Entry.php
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/item.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/response.go
