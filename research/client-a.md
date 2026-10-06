# client-a-classic

# client A Classic (ex-client A 5) - Google Reader API behaviour, reconstructed from server-side sources

Research date 2026-09-24. client A is closed source; everything below about the client is reconstructed from (a) server implementations that were patched *for* client A (server A `p/api/greader.php`, server B `internal/googlereader`), (b) verbatim server access logs posted in server A/B issues, (c) one disassembly report (server A #2759), and (d) App Store and vendor site text and in-app screenshots. **V** = verified in source/log/doc; **I** = inferred.

---

## 1. Identity, versions, User-Agents

- client A 5 was renamed **client A Classic** in v5.4.4 (2024-09-02, Mac App Store version history). Current version **5.5.1 (2025-05-16)**, macOS 10.15+, iOS app id 1529445840, Mac app id 1529448980. the vendor help page: *"the old version of client A is not being discontinued. It will remain available as client A Classic ... and it will, of course, continue to receive updates."* **V**
- The **new client A (2024, app id 6475002485) does NOT support third-party sync services at all**: help FAQ *"Why doesn't this version support third-party sync services?"* → scroll-based tracking makes integration "non-trivial, so support isn't currently planned". So only Classic speaks Google Reader API. **V**
- Observed `User-Agent` strings (server A logs): `client A/4020.19.01 CFNetwork/1120 Darwin/19.0.0 (x86_64)` (mac, Nov 2019), `client A/4020.29.03 CFNetwork/1121.2.2 Darwin/19.2.0` (iOS, Jan 2020), `client A/4020.39.05 CFNetwork/1125.2 Darwin/19.4.0` (May 2020), `client A/5010.01.03 CFNetwork/1240.0.4 Darwin/20.6.0` (iOS client A 5.1, Dec 2021), `client A/5050001 CFNetwork/3826.400.120 Darwin/24.3.0` (client A Classic 5.5, Feb 2025). No `client=` query parameter is sent (News+ sends `client=newsplus`; client A logs never show it). **V**

## 2. Account types and login form

App Store description (verbatim): *"SUPPORTED THIRD-PARTY SERVICES Feedbin, Feedly, FeedHQ, NewsBlur, The Old Reader, Inoreader, BazQux Reader, server A, Instapaper and Pocket."* MacUpdate description adds: *"If you want to use a self-hosted service, client A should work with services which use the Fever or the Google Reader API."* **V**

Actual "Add Account..." sheet (screenshot posted by user Hukuma1 in server A #4105, client A 5.1 iOS, Jan 2022; viewed directly) **V**:
- SERVICES: Feed Wrangler (greyed/legacy), FeedHQ (feedhq.org), NewsBlur, The Old Reader, Inoreader, BazQux Reader - all Google-Reader-API dialects hard-wired to their hosts.
- SELF-HOSTED:
  - **"server A - server A.org"** → form fields **Server / User / Password**, with note: *"Please make sure that you have enabled the API in your server A instance by: • Setting an "API password" • Enabling "Allow API Access". Also, client A won't trigger a refresh of your feeds when syncing. This has to be set up on the server (see server A documentation)."*
  - **"Reader - Self-hosted, Google Reader API"** → form fields **Server / Email / Password**. (Generic GReader account; Email is just the `Email=` ClientLogin field - server A maintainer: *"You can use your server A username in the Email field"*.)
  - **"Fever - Deprecated. Not recommended."**
- **There is no server B-specific type.** server B is used through the generic "Reader" type: a blog post: *"in client A choose "Reader" in the add account screen, set the domain you've got server B hosted at and away you go."* server B docs list "client A Classic >= 5 (iOS/macOS)" as compatible. **V**

Server URL handling:
- server A type: user enters only the host; *"I selected "server A" during account setup and client A 4 automatically configured `https://example.tld/api/greader.php/` as API backend"* (server A #2960). So client A appends `/api/greader.php` itself. **V**
- Generic "Reader" type: server base URL, client A appends `/accounts/ClientLogin` and `/reader/api/0/...` (server B mounts exactly `BASE_URL/accounts/ClientLogin` and `BASE_URL/reader/api/0`, and works with client A via "Reader" type). **V** TT-RSS freshapi docs say to enter the full `.../plugins.local/freshapi/api/greader.php` as server URL with the "server A or Google Reader API" type - so a path component in the Server field is honoured. **V**
- server A defensively strips a duplicated prefix: `$pathInfo = preg_replace('%^(/api)?(/greader\.php)?%', '', $pathInfo); //Discard common errors` - Kipple should do the same (accept `/api/greader.php/reader/api/0/...` and `/reader/api/0/...`). **V**
- **HTTPS**: a blog post (client A 5 + server A): error *"An error occurred while trying to log in."*; *"I noticed that the automatically-generated API URL from client A started with http instead of https. And that tuned out to be the problem. After I changed http in the URL to https, the feed got added"*. the same blog post, updated: *"you must have HTTPS enabled ... for this to work"*. So: a bare host without scheme was turned into `http://`; login over plain http failed; typing `https://` explicitly fixed it. Whether client A itself refuses http or the server redirected is not determinable. **V (observation), I (cause)**
- Wrong path → client A error text: *"Login Failed. The requested page was not found on the server. Please verify the URL and try again."* (freshapi #7, 404 on ClientLogin). **V**
- **Self-signed certificates**: no client A-specific source found. client A uses CFNetwork/URLSession; iOS only trusts CAs in the system store or user-installed profiles with "Enable Full Trust" - **I**. **Cloudflare**: no client A+Cloudflare-Access source found; client A has no way to present an Access service token or complete an Access OTP, hence tools like `pacnpal/wicketgate` exist ("self-hosted server B or server A behind a tunnel and feed reader apps like client A") - **I**: the Reader API path must have an Access bypass policy (Kipple's planned design). server A discussion #7229 is about Cloudflare blocking *feed fetches*, not the API.

## 3. Authentication wire format

**ClientLogin**
- `POST /accounts/ClientLogin` with `application/x-www-form-urlencoded` body `Email=<user>&Passwd=<pass>` (server A #4105 access log: `"POST /api/greader.php/accounts/ClientLogin HTTP/1.1" 200 126 "-" "client A/5010.01.03 ..."`). davd.io additionally lists optional fields clients send: `accountType=HOSTED_OR_GOOGLE`, `service=reader`, `client=<name>`, `output` - *"anything but Email and Passwd can be ignored"*. **V**
- Response must be `text/plain`: server A emits `SID=<user>/<sha1>\nLSID=null\nAuth=<user>/<sha1>\n`; server B `SID=..\nLSID=..\nAuth=..\n` (same token thrice). davd.io notes `expires_in` optional. **V**
- Regression to know: client A 4.2.1 (Nov 2019, `client A/4020.19.01`) sent `GET /api/greader.php/accounts/ClientLogin` with empty query and no body (server A #2684 log: `[REQUEST_METHOD] => GET ... [_GET] => Array() [_POST] => Array()`); server A accepts Email/Passwd via GET or POST for this reason. Fixed in later client A. **V**
- Immediately after login client A calls `GET /reader/api/0/user-info?output=json` (#4105, #3531 logs). server A returns `{"userId","userName","userProfileId","userEmail"}`; server B same keys, all strings. **V**

**Per-request auth**: `Authorization: GoogleLogin auth=<token>` (scheme exactly `GoogleLogin`, field exactly lowercase `auth`; server B middleware rejects otherwise). **V**

**401 handling**: server A `unauthorized()` sends `HTTP/1.1 401 Unauthorized`, `Content-Type: text/plain`, header `Google-Bad-Token: true`, body `Unauthorized!`. server B: 401, `X-Reader-Google-Bad-Token: true`, `text/plain`, body `Unauthorized`. client A 4 UI on repeated 401: *"Request Failed, Please re-authorize this account"* (#3031). Original Google semantics (Google groups "fougrapi"): bad `T` → 400 + `X-Reader-Google-Bad-Token: true`; expired auth → 401 on `user-info`, re-login on first 401. **V**

**Edit token `T`**
- `GET /reader/api/0/token` → plain text, server A pads to exactly 57 chars: `str_pad(sha1(salt.user.apiPasswordHash), 57, 'Z') //Must have 57 characters`. client A does call it: log `"GET /api/greader.php/reader/api/0/token HTTP/1.1" 200 335 ... client A/4020.39.05` right before the `POST stream/items/contents` batch (#2956). **V**
- **client A 4 (2019) sent `T=x` on edit-tag.** server A #2513 log: `Invalid POST token: x` / `POST token should have been: 92ddc5...ZZZZ`. server A PR #2526 ("API client A compatibility") added: `$token === '' || //FeedMe` / `$token === 'x')) { //client A` → accepted as valid (still in edge today: `checkToken`). **V**
- server B authenticates **every POST solely via `T`** (`token = r.Form.Get("T")`; the Authorization header is ignored on POST; `T` may be in query or body) and requires it to equal the login token; client A 5 works with server B ⇒ client A 5 sends a real `T` on POSTs including `stream/items/contents`, `edit-tag`, `mark-all-as-read`, `subscription/edit`. **I (strong)**. Kipple should: accept `T` from query or body on POST; also accept the `Authorization` header on POST (server A does; client B relies on it); optionally tolerate `T=x`/empty as server A does.

## 4. client A's sync request sequence (reconstructed)

Pull-to-refresh / launch / background refresh → same sequence. From server A access logs (#2620 Nov 2019, #2956 May 2020, Cloudron forum, #7370 Feb 2025) plus server B PR #1115 and davd.io/ash7.io write-ups:

1. `GET /reader/api/0/subscription/list?output=json` **V** (every log)
2. `GET /reader/api/0/stream/items/ids?s=user/-/state/com.google/reading-list&xt=user/-/state/com.google/read&output=json&n=10000` **V** (verbatim from #7370, client A 5050001; identical in #2620/#2956/Cloudron) - unread IDs
3. `GET /reader/api/0/stream/items/ids?n=10000&s=user/-/state/com.google/starred` **V** (server B PR #1115 "StarredList" URL, client A 5 tested) - starred IDs
4. `GET /reader/api/0/stream/items/ids?ot=1586240105&n=10000&output=json&s=user/-/state/com.google/read` **V** (#2956, request at 2020-05-07T06:15:05Z; 1586240105 = 2020-04-07T06:15:05Z ⇒ **`ot` = now − exactly 30 days, in seconds**) - read items of the last month. ash7.io summarises client A's strategy as *"complete starred articles, complete unread articles, and read articles from the past month"*. **V**
5. `GET /reader/api/0/token` **V**
6. `POST /reader/api/0/stream/items/contents` with repeated `i=` for the IDs it doesn't have locally, **in batches of 100** (#2956: Postgres placeholders `$1..$100`, then `$1..$56`). **V** IDs are sent as **16-digit zero-padded hex WITHOUT the `tag:google.com,2005:reader/item/` prefix**: `0005978fb9baf6b1`, `0005868e4d78a058` (#2956); server B code comment: `// client A uses this format: "000000000000048c" (hexadecimal string without prefix and padding)`; davd.io: *"at least client A sometimes sends the 16-digit padded hexadecimal version without the ... prefix"*. **V**
7. Writes: `POST /reader/api/0/edit-tag` (§6), `POST /reader/api/0/mark-all-as-read` (§7), `POST /reader/api/0/subscription/edit` / `quickadd` (server A README rates client A Classic "Manage feeds ✓").

Observations about what is **not** seen in any client A log: `stream/contents/...` (davd.io: *"NewsFlash uses /stream/contents/:streamId ... while client A first fetches a list of ID ... via /stream/items/ids and then sends batch calls to /stream/items/contents"*), `tag/list`, `unread-count`, `r=`, `c=` continuation, `nt=`, `it=`, `includeAllDirectStreamIds` (Inoreader-only param), `ck=`. **V (absence in available logs) / I (that client A never calls them)**. client A always sends `output=json` on GET list endpoints (server B `checkOutputFormat` requires `output=json` on `stream/items/ids` and client A works). **V**

Per-source cap: server B #1350 - *"client A's indicator will stay at 10,000 forever"* with >10k starred; users concluded *"A single source in client A shows up to 10,000 articles (showing the latest)"*. Consistent with `n=10000` and no observed continuation follow-up. **V (observation)**

## 5. Response-shape strictness client A has actually broken on (Swift `Codable`)

| Field | Requirement | Evidence |
|---|---|---|
| `itemRefs[].id` in `stream/items/ids` | **must be a JSON string** (decimal) | server A #2620: MySQL native types made it an int → client A Console "Type Mismatch"; user patched to `{"itemRefs":[{"id":"1572638017615972"},...` and *"client A magically started working again"*; fixed by PR #2621; edge code: `'id' => '' . $entryId, //64-bit decimal` **V** |
| `continuation` in `stream/items/ids` | **must be a string** if present | server A #3247 client A log: `Swift.DecodingError.typeMismatch(Swift.String ... codingPath: [CodingKeys(stringValue: "continuation")], "Expected to decode String but found a number instead.")`; fixed PR #3250. server B: `Continuation int \`json:"continuation,omitempty,string"\`` **V** |
| item `id` | `tag:google.com,2005:reader/item/` + `%016x` of an **int64**; client A converts the decimal itemRef id → 16-hex and back, so IDs must be numeric and fit a signed 64-bit | server A `dec2hex` = `str_pad(dechex((int)$dec),16,'0',STR_PAD_LEFT)`; server B `ItemIDFormat = "tag:google.com,2005:reader/item/%016x"`; oksskolten PR: *"Article IDs returned as bare decimal strings for client B/client A Swift `Int()` compatibility"* **V** |
| `timestampUsec` | string, microseconds | server A `'timestampUsec' => '' . $this->dateAdded(true, true), //EasyRSS & client A`; server B `fmt.Sprintf("%d", entry.Date.UnixNano()/1000)` **V** |
| `crawlTimeMsec` | string, milliseconds | server B PR #2670 fixed it being emitted in µs **V** |
| `published` (and `updated`) | integer seconds | all three servers **V** |
| envelope of `stream/items/contents` | `{"id":"user/-/state/com.google/reading-list","updated":<int>,"items":[...]}` - server B adds `"direction":"ltr","title":"Reading List","self":[{"href"}],"author"`; PR #3325 changed server B from per-feed `id`/`title` to the hard-coded reading-list envelope | **V** |
| `edit-tag`, `mark-all-as-read`, `subscription/edit` | plain-text body `OK` (`text/plain`) | davd.io: *"Response content type: text/plain (client A needs that)"*; server A `exit('OK')`; server B `response.Text(w, r, "OK")` **V** |
| unknown `/reader/api/0/*` paths | server B returns `200` with `[]` (fallback handler); client A works with this | **V** |

Item keys client A 4 actually read (javerous disassembled the binary, #2759): `title, id, origin, alternate, content, summary, author, timestampUsec, html_content, html_title`. client A 4 displayed `timestampUsec` as the article date (server A then used entry id = crawl time ⇒ wrong dates ⇒ "GReader Redate" extension). **client A 5 switched to `published`**: server A README PR #4413: *"Install and enable the GReader Redate extension ... if you are using client A 4 or FeedMe. (No longer required for client A 5)"*. server A maintainer's position: `timestampUsec`/`crawlTimeMsec` are crawl time and are what `ot` filters on; `published` is informational. **V**

Minimal item shape that both server A ("compat" mode) and server B emit and client A consumes:
```json
{"id":"tag:google.com,2005:reader/item/0005978fb9baf6b1",
 "crawlTimeMsec":"1578673009998","timestampUsec":"1578673009998440","published":1578672000,
 "title":"...","canonical":[{"href":"https://..."}],"alternate":[{"href":"https://..."}],
 "summary":{"content":"<p>...</p>"},            // server A compat uses summary; server B sends both summary and content
 "categories":["user/-/state/com.google/reading-list","user/-/label/Folder","user/-/state/com.google/read","user/-/state/com.google/starred"],
 "origin":{"streamId":"feed/12","title":"Feed name","htmlUrl":"https://site/"},
 "author":"...","enclosure":[{"href":"...","type":"audio/mpeg","length":123}]}
```
server A truncates compat content at `API_MAX_COMPAT_CONTENT_LENGTH = 500000` bytes (*"Some clients (tested with News+) would fail if sending too long item content"*). **V**

`subscription/list` shape (server A): `{"subscriptions":[{"id":"feed/12","title":"...","categories":[{"id":"user/-/label/Folder","label":"Folder"}],"url":"<feed url>","htmlUrl":"<site>","iconUrl":"<abs favicon url>"}]}`; server B adds `"type":"folder"` in categories and uses `user/<id>/label/...` (client A accepts both `user/-/` and `user/<n>/` forms). **V**

`tag/list` (server A): `{"tags":[{"id":"user/-/state/com.google/starred"},{"id":"user/-/state/com.google/reading-list"},...,{"id":"user/-/label/Folder","type":"folder"}]}`; server B returns only starred + labels. Not observed in client A logs; server A README marks client A Classic "Labels -" (no tag support). **V**

`unread-count` (server A): `{"max":<int>,"unreadcounts":[{"id":"feed/12","count":3,"newestItemTimestampUsec":"1710000000123456"},{"id":"user/-/label/Folder",...},{"id":"user/-/state/com.google/reading-list","count":N,"newestItemTimestampUsec":"..."}]}`. Not implemented by server B (falls to `[]`), and client A works with server B ⇒ client A derives counts from the ID lists. **V/I**

## 6. `edit-tag` (read/unread/star/unstar)

`POST /reader/api/0/edit-tag`, form body: `T=<token>`, repeated `i=<item id>` (client A: bare 16-hex), `a=<tag>` to add and/or `r=<tag>` to remove. Tags client A uses: `user/-/state/com.google/read` (a → read, r → unread) and `user/-/state/com.google/starred` (a → star, r → unstar). Evidence: server B #1360 *"client A 5.1 on macOS, unstarring items does not work"* → PR #1376 flipped `SetEntriesBookmarkedState(userID, unstarredEntryIDs, true)` to `false` (so client A sends `r=user/-/state/com.google/starred`). server B additionally maps `kept-unread` add→unread / remove→read and ignores `broadcast`/`like`; server A lists `broadcast`, `like`, `tracking-kept-unread` as "Not supported" no-ops. No evidence client A sends `kept-unread`. server B reads `a`/`r` from `r.PostForm` (body only), `i`/`T` from merged form. server A `editTag()` ID normalisation: `if (!ctype_digit($e_id) || $e_id[0] === '0') $e_ids[$i] = hex2dec(basename($e_id));` - i.e. treat as hex unless pure decimal not starting with 0 (PR #2957 after #2956 broke client A 4). server B `parseItemID`: prefix form via `Sscanf("...%016x")`, else `len==16` → hex, else decimal. **V**

## 7. `mark-all-as-read`

`POST /reader/api/0/mark-all-as-read` form: `T`, `s=<stream>` (`user/-/state/com.google/reading-list`, `feed/<id>`, `user/-/label/<name>`; server A also starred/main/important), `ts=<timestamp>`. **Units are not standardised and what client A sends was not captured in any public log**:
- The Old Reader API doc: `# Older than timestamp in nanoseconds` / `ts=1371645508000000` (16 digits - actually microseconds). server A comment copies "Older than timestamp in nanoseconds" and implements `UPDATE _entry SET is_read=1 WHERE ... id <= ?` with `$idMax = ts` - server A entry IDs are microsecond crawl timestamps, so server A effectively expects **microseconds** and cuts on crawl time.
- Inoreader: `ts` = *"Unix Timestamp in seconds or microseconds"*.
- server B: `// It's unclear if the timestamp is in seconds or microseconds, so we try both using a naive approach.` `if len(timestampParamValue) >= 16 { before = time.UnixMicro(v) } else { before = time.Unix(v, 0) }`; omitted → now; cutoff on **published_at**; label stream → `CategoryByTitle`.
- CommaFeed (greader added 2026-08): `Instant.ofEpochSecond(ts / 1_000_000)` (assumes µs).
- lirtual/rss-sync-worker spec (built against a real client A): *"`ts` accepts the timestamp magnitudes client A may send: microseconds → convert to milliseconds; milliseconds → use directly; Unix seconds → convert to milliseconds"* and applies the cutoff to **ingestion** time, not publisher date. **V (all)**
Recommendation for Kipple: parse `ts` by digit count (≥16 µs, 13 ms, ≤10 s), cut on server ingestion time (matches server A and Google semantics), return `OK`.

## 8. Semantics of `ot`/`xt`/`s` on `stream/items/ids` across servers

- client A sends `ot` in **seconds** (10 digits). server A converts `ot` to an ID lower bound: SQL `id >= ?` with value `"{ot}000000"` **OR** `lastUserModified >= ot` (`setMinDate` OR `setMinModifiedDate`), so its "read stream since ot" also returns items *marked read* after `ot`. server B uses `AfterPublishedDate(time.Unix(ot,0))` (published date). `nt` is the symmetric upper bound (server A `setMaxDate` AND `setMaxModifiedDate`). **V**
- `s=user/-/state/com.google/read`: server A filters `is_read=1`; server B `WithStatuses(EntryStatusRead)`; davd.io claims *"most clients rely on this to return everything"* - contradicted by server A/B both filtering to read-only and client A working. Serve read-only. **V**
- `xt=user/-/state/com.google/read` on reading-list ⇒ unread only. server B only honours `xt=read`; `it` is *"parsed but currently ignored"*. **V**
- `n`: client A 10000; server B caps at `model.MaxEntryIDsLimit = 10000`; server A default 20 if absent. `r`: `o` ascending else descending (client A omits ⇒ newest first). `c`: server A = last entry id (string), server re-fetches `n+1` and drops the first; server B = numeric offset as string. **V**
- server A maintainer's recommended client strategy (#2566, News+ log): tag/list → subscription/list → `stream/contents/reading-list?xt=read&ot=<last>&n=1000&r=n` → `stream/items/ids?s=reading-list&xt=read&n=10000&r=n` → starred contents/ids. BazQux README "The Right Way to Sync": *"DON'T "sync" by downloading `reading-list` stream with `ot` option ... Use item IDs"* and *"BazQux Reader does not automatically mark items as read after 30 days. If you add `ot=CurrentTime-30days` you will miss some items."* - a direct warning about exactly the `ot=now-30d` read-stream call client A makes. **V**

## 9. Refresh cadence

- client A never asks the server to fetch feeds (login screen: *"client A won't trigger a refresh of your feeds when syncing. This has to be set up on the server"*; #4105 user: *"the Reeader App does not update the feeds itself. It only gets it from the server A DB"*). Matches Kipple's "API clients never trigger fetches". **V**
- iOS: per-account "Sync" setting with values **"On Start" / "Manually" / "Background refresh"** (client A 2.2 announcement, 9to5Mac/iMore 2014; per-account, background off by default). MacStories client A 5 review: general settings *"include the ability to disable the app's auto-refreshing feature and Background App Refresh"*. App Store: background refresh needs Background App Refresh on in iOS Settings and in client A. iOS decides the actual interval (BGAppRefreshTask heuristics); several App Store reviews report it firing rarely. Pull-to-refresh runs the full §4 sequence (#7370: *"Container log emission correlating with a pull-to-refresh action"*). macOS Classic refresh-interval preference: **not verified** (a search snippet claims Preferences > Sync > "Background refresh: When app is inactive" + "Adaptive interval" but the page could not be confirmed). **V/I as marked**

## 10. Server-maintainer quirk log (chronological)

| Date | Server | Symptom | Cause / fix |
|---|---|---|---|
| 2019-09 | server A #2513 / PR #2526 | "authentication errors ... when trying to mark articles as read" | client A 4 sent `T=x`; server A now accepts `T=x` |
| 2019-11 | server A #2620 / PR #2621 | client A authenticates but "No unread items" | `itemRefs[].id` emitted as JSON int (MySQL native types); must be string |
| 2019-11 | server A #2684 | login fails, `badRequest()` | client A 4.2.1 sent `GET /accounts/ClientLogin` with no params (client bug) |
| 2020-01 | server A #2759 / PR #2761(reverted) / GReader Redate ext | wrong article dates in client A 4 | client A 4 displays `timestampUsec` (crawl time); client A 5 uses `published` |
| 2020-05 | server A #2956 / PR #2957 | Postgres `invalid input syntax for integer: "0005978fb9baf6b1"` | client A posts bare 16-hex `i=`; detection `!ctype_digit || [0]==='0'` |
| 2020-08 | server A #3143 | `Call to undefined function gmp_strval()` on 32-bit Raspbian | hex2dec needs GMP on 32-bit PHP |
| 2020-11 | server A #3247 / PR #3250 | client A `DecodingError.typeMismatch(Swift.String ... "continuation")` | `continuation` must be a string |
| 2021-03 | server A #3531 | 401 + `Google-Bad-Token: true` after 1.18 | user config missing `enabled`/`is_admin` keys after upgrade |
| 2021-05/12 | server A #3606, #4105 | 401 / "unable to login" | nginx reverse proxy: `REQUEST_SCHEME=http`, POST arriving as GET without body, user typing email instead of username; "use your server A username in the Email field" |
| 2022-01 | server B #1350 | starred count stuck at 10,000 | client A shows max 10,000 items per source |
| 2022-02 | server B #1360 / PR #1376 | client A 5.1 unstar ignored | boolean inverted in `SetEntriesBookmarkedState` for `r=starred` |
| 2024-05 | server B PR #2670 | - | `crawlTimeMsec` was µs, fixed to ms |
| 2025-02 | server A #7370 | `listIdsWhere(): Argument #4 ($filters) must be of type ?ServerA_BooleanSearch, string given` on client A's `stream/items/ids` | stale `greader.php` in a cached image layer, not a client A bug |
| 2025-05 | server B PR #3325 | 400s on `i=` | unified item-ID parser: long padded, long unpadded (client B `.../item/2f2`), bare 16-hex (client A), decimal (Liferea); envelope hard-coded to reading-list |
| 2025-12 | server A #8370 | Capy/Smart RSS timeouts after 1.28.0 with 80k+ articles | huge `stream/contents` responses; maintainer: clients should use continuation |
| 2025-11 | server A #8261 | intermittent 401 on some `stream/items/ids` (Read You) | "two identical Authorization request headers" - proxy duplication |
| generic | server A discussion #6183, #2582, docs | 401 / Bad Request | `/api/` must not be behind HTTP Basic Auth; nginx needs `fastcgi_param PATH_INFO`, `fastcgi_split_path_info`, `proxy_set_header Authorization $http_authorization`; Apache `AllowEncodedSlashes On` for clients that `%2F`-encode stream ids (News+ does; client A logs show unencoded `/`) |

## 11. Reference implementations client A Classic is known to work with

- server A `p/api/greader.php` (edge) - most tolerant; accepts `T=x`; hex/decimal ids; `ot` on crawl-or-modified; `continuation` = last id string.
- server B `internal/googlereader` (2.2.x/2.3.x) - docs list "client A Classic >= 5"; strict `T` on POST; `output=json` required on `stream/items/ids`; `[]`+200 for unknown endpoints; no `unread-count`, no `stream/contents`; `tag/list` only starred+labels. Its `README.md` in that directory is the best concise contract to copy.
- TT-RSS `eric-pierce/freshapi` - "client A Classic: Fully Functional"; needs PATH_INFO.
- CommaFeed (greader added 2026-08-08, commit `fd8bb60`) - new, no client A issues yet; caution: its `parseItemId` only handles the prefixed form or decimal, so client A's bare 16-hex `i=` would be mis-parsed/dropped (potential bug, not yet reported).
- BazQux README: *"API implementation is tested and works with client A"*.


## Claims
- [high LB] client A Classic's Add Account sheet has a SELF-HOSTED section with three entries: 'server A' (fields Server/User/Password), 'Reader - Self-hosted, Google Reader API' (fields Server/Email/Password), and 'Fever - Deprecated. Not recommended.'; there is no server B-specific type. (server A issue #4105)
- [high LB] With the server A account type client A takes only a host and automatically appends /api/greader.php/ to form the API base URL. (server A issue #2960)
- [high LB] server B is used from client A via the generic 'Reader' account type by entering the server B base URL; server B mounts /accounts/ClientLogin and /reader/api/0 directly under its base URL.
- [high] server A strips an accidental '/api' and/or '/greader.php' prefix from PATH_INFO with preg_replace('%^(/api)?(/greader\.php)?%', '', $pathInfo) to tolerate client URL mistakes. (server A repo: p/api/greader.php)
- [medium] A client A 5 login to server A failed with 'An error occurred while trying to log in.' because the auto-generated URL used http; typing https fixed it.
- [high LB] client A sends ClientLogin as POST application/x-www-form-urlencoded with Email and Passwd, then immediately GETs /reader/api/0/user-info?output=json. (server A issue #4105)
- [high LB] ClientLogin must answer text/plain lines 'SID=<token>\nLSID=null\nAuth=<token>\n' (server A) - server B returns the same token for SID/LSID/Auth. (server A repo: p/api/greader.php)
- [high LB] Authenticated requests carry 'Authorization: GoogleLogin auth=<token>'; server B requires the scheme to be exactly 'GoogleLogin' and the field exactly lowercase 'auth'. (server B repo: internal/googlereader/middleware.go)
- [high] On auth failure server A returns 401 text/plain 'Unauthorized!' with header 'Google-Bad-Token: true'; server B returns 401 text/plain 'Unauthorized' with 'X-Reader-Google-Bad-Token: true'. (server A repo: p/api/greader.php)
- [high LB] client A 4 sent the literal edit token 'T=x' on edit-tag; server A PR #2526 added acceptance of $token === 'x' //client A, which is still present in edge checkToken(). (server A PR #2526)
- [high LB] client A calls GET /reader/api/0/token before POSTing stream/items/contents; server A returns the token as plain text padded to exactly 57 characters. (server A issue #2956)
- [medium LB] server B authenticates every POST solely by the 'T' form/query parameter (Authorization header ignored on POST), and client A 5 works with server B, so client A 5 sends a valid T on POST stream/items/contents, edit-tag, mark-all-as-read and subscription/edit. (server B repo: internal/googlereader/README.md)
- [high LB] client A's refresh sequence begins with GET /reader/api/0/subscription/list?output=json followed by GET /reader/api/0/stream/items/ids?s=user/-/state/com.google/reading-list&xt=user/-/state/com.google/read&output=json&n=10000. (server A issue #7370)
- [medium LB] client A fetches starred IDs with GET /reader/api/0/stream/items/ids?n=10000&s=user/-/state/com.google/starred. (server B PR #1115)
- [high LB] client A fetches read items of the last 30 days with GET /reader/api/0/stream/items/ids?ot=<now-30d in seconds>&n=10000&output=json&s=user/-/state/com.google/read (log: ot=1586240105 at 2020-05-07T06:15:05Z). (server A issue #2956)
- [high LB] client A does not use stream/contents; it fetches IDs via stream/items/ids and then POSTs stream/items/contents in batches. (https://www.davd.io/posts/2025-02-05-reimplementing-google-reader-api-in-2025/)
- [high LB] client A POSTs stream/items/contents with repeated i= values as bare 16-digit zero-padded hex without the tag:google.com prefix (e.g. 0005978fb9baf6b1), in batches of at most 100 IDs. (server A issue #2956)
- [high LB] server B's parseItemID documents four client formats: padded long form, client B unpadded long form 'tag:google.com,2005:reader/item/2f2', client A bare '000000000000048c', Liferea decimal '12345'. (server B PR #3325)
- [high LB] itemRefs[].id in stream/items/ids must be a JSON string; client A 4 failed with a Type Mismatch when server A emitted integers (fixed in server A PR #2621). (server A issue #2620)
- [high LB] The 'continuation' field must be a JSON string; client A logs 'Swift.DecodingError.typeMismatch(Swift.String ... continuation ... Expected to decode String but found a number instead.)' otherwise (server A PR #3250). (server A issue #3247)
- [high LB] Item ids must be int64-representable: servers emit 'tag:google.com,2005:reader/item/' + %016x of a 64-bit integer and client A round-trips the decimal itemRef id into that hex form. (server B repo: internal/googlereader/item.go)
- [high LB] timestampUsec and crawlTimeMsec must be strings (microseconds / milliseconds) and published an integer in seconds; server B PR #2670 fixed crawlTimeMsec precision. (server B PR #2670)
- [high] client A 4 displayed timestampUsec as the article date (per a disassembly of the binary) while client A 5 uses published; server A README says the GReader Redate extension is 'No longer required for client A 5'. (server A PR #4413)
- [medium] client A 4 read only these item keys: title, id, origin, alternate, content, summary, author, timestampUsec, html_content, html_title. (server A issue #2759)
- [high LB] edit-tag and mark-all-as-read must return plain-text 'OK' with text/plain content type for client A. (https://www.davd.io/posts/2025-02-05-reimplementing-google-reader-api-in-2025/)
- [high LB] client A unstars via edit-tag with r=user/-/state/com.google/starred; server B #1360 (client A 5.1) was fixed by PR #1376 correcting the boolean passed to SetEntriesBookmarkedState for removed starred tags. (server B PR #1376)
- [high LB] mark-all-as-read 'ts' units are not standardised: The Old Reader documents 16-digit values ('nanoseconds' label, actually microseconds), Inoreader accepts seconds or microseconds, server A compares ts against microsecond-based entry ids (id <= ts), server B treats >=16 digits as microseconds else seconds, CommaFeed divides by 1,000,000. (server B repo: internal/googlereader/handler.go)
- [high LB] server A applies 'ot' on stream/items/ids as (id >= ot*1e6) OR (lastUserModified >= ot), i.e. crawl time or last user modification, not published date; server B uses AfterPublishedDate. (server A repo: app/Models/EntryDAO.php)
- [medium] client A shows at most 10,000 items per source; with >10,000 starred items the count stays at 10,000 (server B #1350). (server B issue #1350)
- [high LB] server B requires output=json on stream/items/ids (checkOutputFormat) and caps n at model.MaxEntryIDsLimit = 10000; client A works with it, so client A sends output=json. (server B repo: internal/googlereader/handler.go)
- [medium LB] server B does not implement unread-count or stream/contents (unknown /reader/api/0/* paths return 200 with JSON []), and client A Classic >= 5 is listed as compatible, so client A does not depend on unread-count. (server B docs: google_reader)
- [high] client A never triggers server-side feed fetches; its server A login screen states 'client A won't trigger a refresh of your feeds when syncing. This has to be set up on the server'. (server A issue #4105)
- [medium] client A's iOS per-account Sync setting offers 'On Start', 'Manually' or 'Background refresh' (background off by default; interval controlled by iOS Background App Refresh).
- [high] The new client A (2024, app id 6475002485) does not support third-party sync services; only client A Classic speaks the Google Reader API.
- [high] client A Classic App Store description lists supported third-party services as Feedbin, Feedly, FeedHQ, NewsBlur, The Old Reader, Inoreader, BazQux Reader, server A, Instapaper and Pocket; current version 5.5.1 (2025-05-16), renamed from client A 5 in 5.4.4 (2024-09-02).
- [high] client A 4.2.1 (Nov 2019) sent GET /accounts/ClientLogin with no Email/Passwd parameters, breaking login against server A; server A accepts credentials via GET or POST as a result. (server A issue #2684)
- [high] server A README compatibility table rates client A Classic: GReader API, works offline, fast sync 3 stars, fetch read articles yes, favourites yes, labels no, podcasts no, manage feeds yes. (server A repo: README.md)
- [high] BazQux warns clients not to sync the reading-list with ot and specifically that 'ot=CurrentTime-30days' misses items because BazQux does not auto-mark items read after 30 days. (https://github.com/bazqux/bazqux-api)
- [low LB] No public source documents client A's behaviour with self-signed certificates or Cloudflare Access; client A cannot present Access service tokens, so the Reader API path needs an Access bypass. (https://github.com/pacnpal/wicketgate/tree/main)

## Open questions
- Exact magnitude (seconds / milliseconds / microseconds) of the `ts` value client A Classic sends on mark-all-as-read, and whether it uses mark-all-as-read at all versus batching edit-tag - no public log captures a client A mark-all-as-read request; parse by digit count to be safe.
- Whether client A Classic 5.5.x still sends `T=x` in any situation (client A 4 did in 2019); it must send a real T for server B to work, but tolerating `T=x`/empty like server A is harmless.
- Whether client A follows `continuation` on stream/items/ids or simply stops at n=10000 (server B #1350 suggests a hard 10,000 cap per source).
- Whether client A Classic ever calls tag/list, unread-count, stream/contents, or uses `r=`, `nt=`, `c=`, `it=`, `includeAllDirectStreamIds` - none appear in any published client A access log; server B lacks unread-count/stream/contents and still works.
- Whether client A rejects plain `http://` server URLs outright (iOS ATS) or the observed http login failure was a server redirect/proxy artefact.
- How client A Classic behaves with self-signed TLS certificates (presumably requires the CA to be trusted at the iOS/macOS system level).
- Which item keys client A 5/Classic reads today (the key list comes from a client A 4 disassembly; client A 5 is known to have switched from timestampUsec to published for dates).
- Whether client A sends stream ids URL-encoded (%2F) in any request - all captured logs show literal slashes.
- Exact macOS client A Classic refresh-interval preference values (search snippets mention 'Background refresh: When app is inactive' and 'Adaptive interval' but the source page could not be verified).
- Which subscription/edit request shapes client A uses for add/rename/move/unsubscribe (ac=subscribe with s=feed/<url>, a=user/-/label/<name>, t=<title>; ac=edit / ac=unsubscribe with s=feed/<id>) - inferred from server A/B support and server A README 'Manage feeds ✓', not from a client A log.

## Sources
- server A repo: p/api/greader.php
- server A repo: app/Models/Entry.php
- server A repo: app/Models/EntryDAO.php
- server A repo: docs/en/developers/06_GoogleReader_API.md
- server A repo: docs/en/users/06_Mobile_access.md
- server A repo: README.md
- server A issue #2513
- server A PR #2526
- server A issue #2620
- server A issue #2684
- server A issue #2759
- server A PR #2761
- server A issue #2956
- server A PR #2957
- server A issue #2960
- server A issue #3031
- server A issue #3143
- server A issue #3247
- server A PR #3250
- server A issue #3531
- server A issue #3606
- server A issue #4105
- server A PR #4413
- server A issue #2566
- server A issue #7370
- server A issue #8370
- server A issue #8261
- (link removed)
- (link removed)
- server B repo: internal/googlereader/handler.go
- server B repo: internal/googlereader/middleware.go
- server B repo: internal/googlereader/item.go
- server B repo: internal/googlereader/request_modifier.go
- server B repo: internal/googlereader/parameters.go
- server B repo: internal/googlereader/prefix_suffix.go
- server B repo: internal/googlereader/response.go
- server B repo: internal/googlereader/README.md
- server B docs: google_reader
- server B PR #1115
- server B issue #1350
- server B issue #1360
- server B PR #1376
- server B PR #2670
- server B issue #2960
- server B PR #3325
- server B issue #2129
- https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/main/java/com/commafeed/frontend/resource/googlereader/GoogleReaderREST.java
- https://github.com/eric-pierce/freshapi
- https://github.com/eric-pierce/freshapi/issues/7
- https://github.com/bazqux/bazqux-api
- https://raw.githubusercontent.com/theoldreader/api/master/README.md
- https://www.inoreader.com/developers/mark-all-as-read
- https://www.inoreader.com/developers/item-ids
- https://www.davd.io/posts/2025-02-05-reimplementing-google-reader-api-in-2025/
- https://ash7.io/blog/hello-read-you-welcome-to-google-reader-api-en-us/
- https://github.com/lirtual/rss-sync-worker/issues/6
- https://github.com/lirtual/rss-sync-worker/issues/27
- https://github.com/babarot/oksskolten/pull/67
- https://www.ipa4fun.com/history/501793/
- https://github.com/pacnpal/wicketgate/tree/main
- https://groups.google.com/g/fougrapi/c/4zHzf38SbAA
