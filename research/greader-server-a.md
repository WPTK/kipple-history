# greader-server-a

# server A Google Reader API contract (as implemented in `p/api/greader.php`, `edge`, server A_VERSION `1.30.1-dev`, read 2026-09-24)

Primary sources read in full: `p/api/greader.php` (1352 lines), `app/Models/Entry.php` (`toGReader`, `dec2hex`), `app/Models/EntryDAO.php` (`listWhere`, `listIdsWhere`, `listByIds`, `sqlListWhere`, `sqlListEntriesWhere`, `sqlBooleanSearch`, `markRead*`), `app/Models/FeedDAO.php` (`listFeedsNewestItemUsec`), `lib/lib_rss.php` (`uTimeString`, `escapeToUnicodeAlternative`), `p/api/.htaccess`, `p/scripts/api.js`, `app/Controllers/apiController.php`, `config-user.default.php`, `docs/en/users/06_Mobile_access.md`, `docs/en/developers/06_GoogleReader_API.md`, README client table, CHANGELOG, plus the mihaip Google Reader wiki mirror, FeedHQ docs, The Old Reader API README, BazQux README, and client B `Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift` (main). Everything marked **[src]** is quoted/verified from source; **[inf]** is my inference from reading the code paths; **[doc]** is from docs/issues.

---

## 1. Transport, routing, headers

- Base URL: `https://host/api/greader.php`. Everything is dispatched on `PATH_INFO` (fallback `ORIG_PATH_INFO`), `rawurldecode()`d, then `preg_replace('%^(/api)?(/greader\.php)?%', '', $pathInfo)` "to discard common errors" (so `/api/greader.php/api/greader.php/reader/...` still works). **[src]**
- `GET /api/greader.php` with no path and no query string → body `OK` (200). Any path with fewer than 3 `/`-segments → 400. **[src]**
- Every response carries `Content-Security-Policy: default-src 'none'; frame-ancestors 'none'; sandbox`, `X-Content-Type-Options: nosniff`, and CORS: `Access-Control-Allow-Headers: Authorization`, `Access-Control-Allow-Methods: GET, POST`, `Access-Control-Allow-Origin: *`, `Access-Control-Max-Age: 600`. `OPTIONS` → `204 No Content`. **[src]**
- If `api_enabled` is false in system config → `503 Service Unavailable` body `Service Unavailable!`. **[src]**
- `GET /check/compatibility` (no auth needed beyond having *some* `Authorization: GoogleLogin auth=...` header - `api.js` sends `GoogleLogin auth=test/1`): returns `text/plain` `PASS`, or `FAIL 64-bit or GMP extension! Wrong PHP configuration.` / `FAIL get HTTP Authorization header! Wrong Web server configuration.`. `api.js` tries `/check/compatibility`, then `/check%2Fcompatibility` (tests `AllowEncodedSlashes`), then `./greader.php/check/compatibility`. **[src]**
- `output`: required and must equal `json` on exactly three endpoints - `tag/list`, `subscription/list`, `unread-count` - otherwise `501 Not Implemented` (`Not Implemented!`). Ignored everywhere else (no Atom output anywhere). **[src]**
- `ck` (client timestamp) is parsed (`(int)$_GET['ck']`) and never used. `client` is only read for the `newsplus` hack (below). `includeAllDirectStreamIds`, `merge`, `likes`, `comments`, `sharers`, `mediaRss`, `trans` do not appear in the source - ignored. **[src]**
- POST bodies: server A reads `php://input` (capped at 1,048,576 bytes: `file_get_contents('php://input', false, null, 0, 1048576)`) into `$ORIGINAL_INPUT`, and repeated params are extracted by `multiplePosts($name)`: split raw body on `&`, keep entries `str_starts_with($input, $name . '=')`, `urldecode()` the remainder. So repeated params must be plain `i=...&i=...` (not `i[]=`), `application/x-www-form-urlencoded`, and `+` decodes to space. Bodies > 1 MiB are truncated silently. **[src]**
- Content-Type of responses: `application/json; charset=UTF-8` is set explicitly only in `tagList`, `subscriptionList`, `unreadCount`, `streamContents`, `streamContentsItems`; **not** in `userInfo`, `quickadd`, `streamContentsItemsIds` (those fall back to PHP's default, typically `text/html`). `ClientLogin`, `token`, and all errors are `text/plain; charset=UTF-8`. **[src]**
- JSON flags: `JSON_THROW_ON_ERROR | JSON_INVALID_UTF8_SUBSTITUTE | JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE`. **[src]**
- Logging: warnings/debug to `API_LOG` = `USERS_PATH . '/_/log_api.txt'`. **[src]**

## 2. Authentication

### API password
- Per-user "API password", separate from the login password. Set on the profile page (`apiPasswordPlain`, `pattern=".{7,}"`), hashed by `ServerA_password_Util::hash()` (bcrypt via PHP `password_hash`; verified with `password_verify` in `clientLogin`) into `userConf->apiPasswordHash`; the same plaintext also derives the Fever key `feverKey = md5($user . ':' . $apiPasswordPlain)`. Docs: "Every user must define an API password." **[src apiController.php, config-user.default.php; doc]**

### `POST /accounts/ClientLogin`
- Params `Email` (= server A username, validated by `ServerA_user_Controller::checkUsername`) and `Passwd`, read from `$_POST` first, then `$_GET`. GET is accepted but logs a deprecation warning (since #8845). **[src]**
- Success (200, `text/plain; charset=UTF-8`):
  ```
  SID=<user>/<sha1>\n
  LSID=null\n
  Auth=<user>/<sha1>\n
  ```
  where `<sha1> = sha1(systemConf->salt . $email . $userConf->apiPasswordHash)`. `LSID=null` is there for **Vienna RSS** (source comment). **[src]**
- The token is deterministic and never expires (changes only when salt or API password changes). Bad username → 400; no API password set or mismatch → 401. **[src]**
- `//TODO: Implement real token that expires` remains in `token()`. **[src]**

### `Authorization: GoogleLogin auth=<user>/<sha1>`
- Parsed by `headerVariable('Authorization', 'GoogleLogin_auth')`: reads `$_SERVER['HTTP_AUTHORIZATION']` (or `REDIRECT_HTTP_AUTHORIZATION`, or `getallheaders()['Authorization']`), runs `parse_str()` on it - PHP turns the space in `GoogleLogin auth` into `GoogleLogin_auth`. Value is split on the first `/` into user and hash; check is `hash_equals(sha1(salt . user . apiPasswordHash), part2)`. Failure → 401; malformed username → 400. **[src]**
- Required for every path except `/accounts/*`. **[src]**
- `p/api/.htaccess` exports the header for Apache: `SetEnvIfNoCase "Authorization" "(.*)" HTTP_AUTHORIZATION=$1` and `SetEnvIfNoCase "Authorization" "^GoogleLogin auth=([^/]+)" REMOTE_USER=$1 LOG_REMOTE_USER=$1` (mod_rewrite fallback). **[src]**

### `GET /reader/api/0/token` and the `T` write token
- Response: `text/plain`, body `str_pad(sha1(salt . user . apiPasswordHash), 57, 'Z') . "\n"` - i.e. the same 40-hex sha1 as in the Auth token, right-padded with 17 `Z`s to exactly 57 chars ("Must have 57 characters", mimicking Google). Example from docs: `8e6845e089457af25303abc6f53356eb60bdb5f8ZZZZZZZZZZZZZZZZZ`. **[src, doc]**
- `checkToken($conf, $token)`: **accepts `T=''` (comment: `//FeedMe`) and `T='x'` (comment: `//client A`) for any non-internal user** - `//TODO: Check security consequences`; otherwise requires `hash_equals(<57-char token>, $token)` (timing-safe since #9183); mismatch → 401 with `Google-Bad-Token: true`. **[src]**
- `T` is read only from `$_POST['T']` (trimmed) and only checked on: `edit-tag`, `rename-tag`, `disable-tag`, `mark-all-as-read`. **Not checked** on `subscription/edit`, `subscription/quickadd`, `subscription/import`, `stream/items/contents`. **[src]**

## 3. Error responses (all `text/plain; charset=UTF-8`)
| Status | Body | Extra header |
|---|---|---|
| 400 | `Bad Request!` | |
| 401 | `Unauthorized!` | `Google-Bad-Token: true` (note: Google used `X-Reader-Google-Bad-Token`) |
| 500 | `Internal Server Error!` | |
| 501 | `Not Implemented!` | |
| 503 | `Service Unavailable!` | |
| 204 | (empty) | for `OPTIONS` |
Unmatched routes fall through to 400. **[src]**

## 4. Stream ID grammar accepted

- `user/-/state/com.google/reading-list` - all items from feeds with priority > PRIORITY_HIDDEN (type `A`).
- `user/-/state/com.google/starred` (type `s`: `is_favorite=1` plus non-hidden feeds).
- `user/-/state/com.google/read`, `user/-/state/com.google/unread` - accepted as `s=` on `stream/items/ids` (since #7695, "redundant with `it`") and on `mark-all-as-read`; accepted as `xt=`/`it=` values everywhere.
- server A extensions: `user/-/state/org.server-a/main` (feeds with priority ≥ 10, type `a`), `user/-/state/org.server-a/important` (priority ≥ 20, type `i`), `user/-/state/org.server-a/hidden` (only emitted in item `categories`, never accepted as a stream).
- `user/-/label/<name>` - a **category (folder) or a label (tag)**, same namespace; lookup order is category first (`searchByName`), then tag. `user/<username>/label/<name>` is also accepted in `edit-tag` `a=` and `subscription/edit` `a=`.
- `feed/<numeric id>` (what server A emits) **or** `feed/<url>` (looked up via `searchByUrl`; unknown URL → id -1 → empty result). In `subscription/edit` the regex `%^(feed/)+%` strips one or more `feed/` prefixes.
- `broadcast`, `like`, `kept-unread`, `tracking-kept-unread`: `edit-tag` silently ignores `broadcast`, `like`, `tracking-kept-unread` (`// Not supported`); `kept-unread` is not mentioned anywhere (falls to the label branch, does nothing since it doesn't start with `user/-/label/`). `tag/list` has `broadcast` commented out. **[src]**
- `stream/contents/<stream>` path routing accepts: `feed/<id|url>`, `user/-/state/{com.google,org.server-a}/{reading-list,starred,main,important}`, `user/-/label/<name>`; anything else after `contents/` → 400; `stream/contents` with **no** stream → reading-list (comment `//EasyRSS, FeedMe`); `stream/contents?s=<stream>` (BazQux compatibility) is exploded on `/` and appended to the path. **[src]**
- Encoded slashes: `feed/<url>` and `user/-/label/<name>` are re-extracted from `$_SERVER['REQUEST_URI']` with `#/reader/api/0/stream/contents/feed/([A-Za-z0-9\'!*()%$_.~+-]+)#` and `#/reader/api/0/stream/contents/user/[^/+]/label/([A-Za-z0-9\'!*()%$_.~+-]+)#` then `urldecode()` - so the whole stream id must be percent-encoded as one path segment (`%2F` for slashes), which is why Apache needs `AllowEncodedSlashes On` (docs). Label with literal `/` fixed in #7437; label with `+` fixed in #7033 (`rawurldecode`, for FocusReader). **[src, doc]**
- Names are `htmlspecialchars()`-encoded before DB lookup and `htmlspecialchars_decode(..., ENT_QUOTES)` on output (server A stores names HTML-escaped). **[src]**

## 5. Item ID forms and conversion

- Internal entry id = `uTimeString()` = `gettimeofday()` seconds concatenated with zero-padded 6-digit microseconds → a 16-digit decimal (e.g. `1760679231329338`, the ids client B posted in #8129). It is the DB primary key and also `date_added` (`_id()` sets `date_added = id` if unset). **[src]**
- Output long form: `'tag:google.com,2005:reader/item/' . dec2hex(id)` where `dec2hex` = `str_pad(dechex((int)$dec), 16, '0', STR_PAD_LEFT)` (GMP on 32-bit PHP). Output short form (in `itemRefs[].id` and `frss:id`): the decimal string. **[src]**
- Input (`i=` on `edit-tag` and `stream/items/contents`): `if (!ctype_digit($e_id) || $e_id[0] === '0') $e_ids[$i] = hex2dec(basename($e_id));` - i.e. anything that is not pure decimal digits, **or a decimal that starts with `0`**, is treated as the long form: `basename()` strips everything up to the last `/`, and `hex2dec` = `'' . hexdec($hex)` (returns `'0'` if not `ctype_xdigit`). Consequence **[inf]**: a bare 16-hex string without the `tag:` prefix also works; a short-form id that happens to start with `0` would be misparsed as hex; and because `hexdec()` returns a float above `PHP_INT_MAX`, a long-form id with the top bit set (Google's "negative short form"/two's-complement case) would become `1.8446744073709552E+19` and match nothing - server A never generates such ids (µs timestamps ≈ 2^50), so it never handles signed/two's-complement conversion. client B's `itemIDParameter` does `String(format: "%.16llx", idValue)` and always sends the long form (except for The Old Reader). **[src NNW]**
- Google's spec: long form is unsigned 0-padded 16-hex; short form is *signed* base-10 (`fb115bd6d34a8e9f` ↔ `-355401917359550817`) - mihaip `ItemId.wiki`; FeedHQ converts with `struct.unpack("L", struct.pack("l", short_form))`. **[doc]**

## 6. Timestamp units per field
| Field | Unit | Source of value in server A |
|---|---|---|
| `ot`, `nt` (query) | seconds | compared against `id >= "{ot}000000"` (µs) and `lastModified >= ot` (s) |
| `ts` (mark-all-as-read POST) | comment says "Older than timestamp in nanoseconds" (copied from The Old Reader) but it is compared directly to the µs entry id: `WHERE ... AND id <= ?` - effectively **microseconds** (FeedHQ documents `ts` as microseconds) |
| `crawlTimeMsec` | ms, string | `substr($this->dateAdded(true, true), 0, -3)` = id with last 3 digits dropped |
| `timestampUsec` | µs, string | `'' . $this->dateAdded(true, true)` = the entry id (comment `//EasyRSS & client A`) |
| `published` | seconds, int | `$this->date(true)` = feed-supplied publication date |
| `updated` (item) | not emitted (`// 'updated' => $this->date(true)` commented out) |
| `updated` (top-level) | seconds, int | `time()` at response time |
| `newestItemTimestampUsec` | µs, string | `MAX(id)` per feed / max over category / max overall |
| `c` continuation | decimal entry id (µs) | last item id of the page |
**[src]**

## 7. Endpoint-by-endpoint

### `GET /reader/api/0/user-info`
Auth required. Response (no explicit Content-Type):
```json
{"userId":"<username>","userName":"<username>","userProfileId":"<username>","userEmail":"<mail_login>"}
```
No `isBloggerUser`, `signupTimeSec`, etc. **[src]**

### `GET /reader/api/0/tag/list?output=json`
```json
{"tags":[
 {"id":"user/-/state/com.google/starred"},
 {"id":"user/-/state/com.google/reading-list"},
 {"id":"user/-/state/org.server-a/main"},
 {"id":"user/-/state/org.server-a/important"},
 {"id":"user/-/label/<Category>","type":"folder"},
 {"id":"user/-/label/<Label>","type":"tag","unread_count":<int>}
]}
```
`type` and `unread_count` are Inoreader-isms (source comments `//Inoreader`); `sortid` is commented out. Categories (folders) come first, then labels. Since #7020 all categories are returned, even empty ones. **[src]**

### `GET /reader/api/0/subscription/list?output=json`
```json
{"subscriptions":[{
  "id":"feed/<numericFeedId>",
  "title":"<escapeToUnicodeAlternative(name, true)>",
  "categories":[{"id":"user/-/label/<Category>","label":"<Category>"}],
  "url":"<feed url>",
  "htmlUrl":"<website>",
  "iconUrl":"<absolute favicon url>",
  "frss:priority":"important"|"main"|"category"|"feed"
}]}
```
Exactly one category per feed (server A feeds live in one category; the default category is included). Feeds with `priority <= PRIORITY_HIDDEN (-10)` are omitted. `sortid`, `firstitemmsec` commented out. `frss:priority` added in #7583 (1.28.0) for Capy Reader: `PRIORITY_IMPORTANT=20→'important'`, `PRIORITY_MAIN_STREAM=10→'main'`, `PRIORITY_CATEGORY=0→'category'`, `PRIORITY_FEED=-5→'feed'`; `hidden` never returned. Title uses `escapeToUnicodeAlternative(..., extended=true)`, which replaces `& < >` with fullwidth `＆ ＜ ＞` **and** `' " ^ ? \ / , ;` with `’ ＂ ＾ ？ ＼ ／ ， ；` (the characters Google forbade in stream ids). **[src]**

### `GET /reader/api/0/unread-count?output=json`
```json
{"max":<totalUnread>,
 "unreadcounts":[
  {"id":"feed/<id>","count":<n>,"newestItemTimestampUsec":"<MAX(id) or 0>"},
  ... (each non-hidden feed, followed by its category)
  {"id":"user/-/label/<Category>","count":<n>,"newestItemTimestampUsec":"..."},
  ... then each label:
  {"id":"user/-/label/<Label>","count":<n>,"newestItemTimestampUsec":"..."},
  {"id":"user/-/state/com.google/reading-list","count":<total>,"newestItemTimestampUsec":"..."}
 ]}
```
`max` is the total unread, not a cap. Order: feeds grouped under their category, category row after its feeds, then labels, reading-list last. Hidden feeds skipped. **[src]**

### `GET /reader/api/0/stream/contents[/<stream>]` (also `?s=<stream>`)
Query params: `n` (int, default 20, **no upper cap**; `n=0` removes the SQL LIMIT [inf]), `r` (`o` → ASC by id; anything else incl. `n`, `d`, absent → DESC), `ot` (int s), `nt` (int s), `xt` (string), `it` (string, server A/FeedHQ-style include target), `c` (must be `ctype_digit`, otherwise treated as no continuation). Response is **streamed** (#8041):
```json
{
	"id": "user/-/state/com.google/reading-list",
	"updated": <time()>,
	"items": [ <item>, ... ]
	,
	"continuation": "<lastEntryId>"   // only when nbItems >= n and lastEntryId > 0
}
```
`id` is **always** `user/-/state/com.google/reading-list` regardless of the requested stream; there is no top-level `title`, `self`, `direction`, `author`, `alternate`. Items with `frss:id` stripped. **[src]**

Item shape (`ServerA_Entry::toGReader('compat', $labels)`):
```json
{
 "id":"tag:google.com,2005:reader/item/<16 hex>",
 "crawlTimeMsec":"<13 digits>",
 "timestampUsec":"<16 digits>",
 "published":<int seconds>,
 "title":"<escapeToUnicodeAlternative(title, false)>",   // & < > → fullwidth only
 "canonical":[{"href":"<link>"}],
 "alternate":[{"href":"<link>"}],                          // "type":"text/html" is unset in compat mode
 "categories":[
   "user/-/state/com.google/reading-list",
   "user/-/label/<Category>",                              // feed's category
   "user/-/state/org.server-a/main",                       // if feed priority >= 10
   "user/-/state/org.server-a/important",                  // if >= 20
   "user/-/state/org.server-a/hidden",                     // if <= -10
   "user/-/state/com.google/read",                         // if read (no "unread" tag in compat mode)
   "user/-/state/com.google/starred",                      // if favourite
   "user/-/label/<Label>", ...,                            // user labels on this entry
   "<raw feed-provided tag>", ...                          // entry->tags(), NOT prefixed with user/-/label/
 ],
 "origin":{"streamId":"feed/<id>","htmlUrl":"<website>","title":"<escapeToUnicodeAlternative(feedName, true)>"},
 "summary":{"content":"<html, mb_strcut to 500000 bytes>"},   // compat mode uses summary, not content
 "enclosure":[{"href":"...","type":"<type|medium|'image'|''>","length":<int>}],   // optional
 "author":"<authors joined, '; '-trimmed, escapeToUnicodeAlternative(..., false)>"   // optional
}
```
Notes: `API_MAX_COMPAT_CONTENT_LENGTH = 500000` ("Some clients (tested with News+) would fail if sending too long item content"); content is `$this->content($feed->attributeBoolean('display_enclosures') ?? true)`, i.e. enclosures may be rendered into the HTML too. `published` = feed date; `crawlTimeMsec`/`timestampUsec` = server ingestion time. The `EntryBeforeDisplay` extension hook runs on each item (this is how the "GReader Redate" extension rewrote `crawlTimeMsec`/`timestampUsec` to the publication date for EasyRSS/FeedMe/client A 4; client A+ shows `published` and "just fetches articles since the last 2 weeks", per the extension README via search). **[src, doc]**

### `GET /reader/api/0/stream/items/ids?s=<stream>&n=&r=&ot=&nt=&xt=&it=&c=`
`s` is required (`is_string($_GET['s'])`), single value only (`// TODO: support multiple streams`). Response (no explicit Content-Type):
```json
{"itemRefs":[{"id":"<decimal id>"}, ...], "continuation":"<lastId>"}
```
Only `id` per ref - **no `timestampUsec`, no `directStreamIds`**. `continuation` present when `count(ids) >= n`. If result is empty and `client=newsplus`, returns `{"itemRefs":[{"id":"0"}]}` (News+ bug workaround). Same filter semantics as stream/contents. **[src]**

### `POST /reader/api/0/stream/items/contents`
Only POST, and only if `isset($_POST['i'])` (so body must be form-encoded; GET → 400). `i` repeated via `multiplePosts('i')`, long or short form. `r=o` → ASC by id else DESC. Response identical in shape to stream/contents (`id`, `updated`, `items`) but **never has `continuation`**. Order is `ORDER BY id`, not request order; ids are chunked at `MAX_VARIABLE_NUMBER`. Comment `//FeedMe`. Regression #8129 (client B got empty `items` in 1.27.2-dev) was an SQL identifier bug in `listByIds` (`lastUserModified` needed backticks), fixed #8130. **[src, patch]**

### `POST /reader/api/0/edit-tag`
Body: `T=<token>`, repeated `i=<itemId>`, repeated `a=<tag>`, repeated `r=<tag>` (all via `multiplePosts`, so from the raw body). Applied to **all** listed items: for each `a`: `read` → `markRead(ids, true)`, `starred` → `markFavorite(ids, true)`, `broadcast|like|tracking-kept-unread` → no-op, `user/-/label/X` or `user/<me>/label/X` → creates the label if missing (`addTag`) and tags every item; for each `r`: `read` → `markRead(ids,false)`, `starred` → `markFavorite(ids,false)`, `user/-/label/X` → untag (label must exist, `user/<me>/label/` form not accepted on remove). Both `a` and `r` may be present in the same call; `a` processed before `r`. Response `OK` (200, PHP default content type). Multiple `a`/`r` per request since #7060. **[src]**

### `POST /reader/api/0/mark-all-as-read`
Body: `T`, `s=<stream>`, `ts=<digits>` (default `'0'`; non-digit → 400). Streams: `feed/<numeric>` (`basename()`; non-numeric → 400 - **feed URLs not accepted here**), `user/-/label/<name>` (category → `markReadCat`, else tag → `markReadTag`, else 400), `reading-list` (priority > hidden), `starred` (`onlyFavorites`), `org.server-a/main`, `org.server-a/important`, `com.google/read` (no-op in practice), `com.google/unread`. SQL is `UPDATE _entry SET is_read=1, lastUserModified=now WHERE is_read <> 1 AND id <= ?` with `?` = `ts` - if `ts=0` the server substitutes `uTimeString()` (now). **Because `id` is µs, a client sending seconds (10 digits) marks nothing, one sending ns (19 digits) marks everything** [inf]. Response `OK`. **[src]**

### `POST /reader/api/0/subscription/edit`
Params from `$_REQUEST` (so GET query works, no `T` check): `ac` ∈ `subscribe|unsubscribe|edit` (else 400), `s` (repeatable via POST body; single via GET), `t` (title, repeatable, index-aligned with `s`; **server A uses `t`, not Google's `title`**), `a` (single: target `user/-/label/<cat>` or `user/<me>/label/<cat>`; empty/default name → default category; unknown name → **category is created**), `r` (single; if `r=user/-/label/...` and no `a`, feed moves to default category). Comment: "in server A, we do not support repeated values since a feed can only be in one category". Behaviour per `s`: `subscribe` requires `feed/<url>` (numeric `feed/<id>` is skipped), adds via `addFeed(url, title, catId, ..., kind)` where kind is JSON Feed if URL matches `/(?:\b|_)json(?:\b|_)/i` (#9167), failure → 400; `unsubscribe` needs an existing feed id (by id or url) → `deleteFeed`; `edit` → `moveFeed` if `a` resolved, `renameFeed` if `t` non-empty. Response `OK`. Multiple `s`/`t` since #7017 (FocusReader). **[src]**

### `POST|GET /reader/api/0/subscription/quickadd?quickadd=<url>`
`$_REQUEST['quickadd']`; leading `feed/` stripped; no `T` check; adds to default category. Success: `{"numResults":1,"query":"<feed url>","streamId":"feed/<id>","streamName":"<name>"}`; failure (200!): `{"numResults":0,"error":"<message>"}`. (Shape copied from The Old Reader.) client B then re-fetches `subscription/list` and matches `streamId`. **[src, NNW]**

### `GET /reader/api/0/subscription/export` → OPML (`application/xml`, attachment). `POST /reader/api/0/subscription/import` with raw OPML body → `OK` then triggers a feed refresh (`actualizeFeedsAndCommit`). server A-only extras; client B uses `import` with `Content-Type: text/xml`. **[src, NNW]**

### `POST /reader/api/0/rename-tag`
`T`, `s=user/-/label/<old>`, `dest=user/-/label/<new>` (both must have that prefix). Renames a category if found, else a label. `OK` or 400. **[src]**

### `POST /reader/api/0/disable-tag`
`T`, repeated `s=user/-/label/<name>`. Category: moves its feeds to the default category (`changeCategory(cat, 0)`) and deletes it (unless it is the default category); else deletes the label. `OK` or 400 (exits on first `s`, so effectively one). **[src]**

## 8. Filter semantics (`xt`, `it`, `ot`, `nt`, `r`, `n`, `c`)

Implemented in `streamContentsFilters()` + `EntryDAO::sqlListWhere/sqlListEntriesWhere/sqlBooleanSearch`. **[src]**

- State bitmask: `STATE_READ=1, STATE_NOT_READ=2, STATE_ALL=3, STATE_FAVORITE=4, STATE_NOT_FAVORITE=8`. `it` sets the base: `read→1`, `unread→2`, `starred→4`, else `3`. `xt` then ANDs: `read → &2`, `unread → &1`, `starred → &8`. In `sqlListWhere`, `if (!$state) $state = STATE_ALL`. Consequences [inf, from code]: `xt=read` alone → unread only (3&2=2); `it=starred` alone → favourites; **`xt=user/-/state/com.google/starred` is silently a no-op** (3&8=0→ALL); `it=starred&xt=read` → 4&2=0 → **ALL items** (the classic "unread starred" combination breaks unless you use the `starred` stream + `xt=read`, which works: stream type `s` adds `is_favorite=1` in the WHERE, then state 3&2=2). `xt=feed/...` is not supported (only the three state values are matched).
- `ot`: adds **two** `ServerA_Search` objects - `setMinDate(ot)` → `e.id >= "{ot}000000"` and `setMinModifiedDate(ot)` → `e.lastModified >= ot` - into one `ServerA_BooleanSearch`, whose `ServerA_Search` members are joined by **OR** (`sqlBooleanSearch`: "Searches are combined by OR"). So since 1.29.0 (#8131, motivated by Capy Reader / issue #7304) `ot` returns items *received* after `ot` **or whose content was modified server-side (author edit) after `ot`**; user state changes (read/star) do **not** count (`lastUserModified` is a separate column). Before 1.29.0 it was `id >= ot·10^6` only.
- `nt`: one search with `setMaxDate(nt)` AND `setMaxModifiedDate(nt)` → `(e.id <= "{nt}000000" AND COALESCE(e.lastModified,0) <= nt)`.
- **Quirk [inf, high confidence from code]:** when both `ot` and `nt` are given, all three sub-searches sit in the same BooleanSearch and are OR-ed: `((id >= ot) OR (lastModified >= ot) OR (id <= nt AND lastModified <= nt))`, which for `nt >= ot` matches everything. Do not rely on `ot`+`nt` together against server A.
- `r`: `order: $order === 'o' ? 'ASC' : 'DESC'` - sort is always by entry id (ingestion time), never by `published`.
- `c` (continuation): value is the last id of the previous page. Server does `$count++`, queries `id <= c` (DESC) or `id >= c` (ASC) **inclusive**, then drops the first row (`LimitIterator offset 1` / `array_shift`) and `$count--`. `continuation` is emitted iff `nbItems >= n && lastEntryId > 0` - so a page that is exactly full always carries a continuation even if nothing follows (the next call then returns 0 items and no continuation). client B's `retrieveItemIDs` loops until `continuation` is nil and tolerates empty pages. **[src, NNW]**
- `n` default 20 for both endpoints; no max enforced (News+ uses 1000/10000, NNW uses 1000).
- Stream types: `A` reading-list = `f.priority >= 0` (PRIORITY_CATEGORY; hidden −10 and "show in its feed" −5 excluded), `a` main = `priority >= 10`, `i` important = `>= 20`, `s` starred = `priority > -10 AND is_favorite=1`, `c` category = `priority >= 0 AND f.category=?`, `t` tag = join `_entrytag`, `f` feed = `e.id_feed=?` (hidden feeds **are** readable by direct feed stream).

## 9. Deliberate deviations from Google's original (and from Google-era client expectations)
1. `Auth`/`SID` token = `user/sha1(...)`, static, never expires; `LSID=null`. **[src]**
2. `T` token static (sha1 + `Z` padding to 57 chars); `''` and `'x'` accepted; `T` not required on `subscription/*`. **[src]**
3. `Google-Bad-Token: true` header (Google: `X-Reader-Google-Bad-Token`). **[src]**
4. `subscription/edit` uses `t` for title (Google: `title`), single `a`/`r`, auto-creates categories, `feed/<numericId>` ids. **[src]**
5. `stream/contents` top-level `id` always reading-list, `updated` = now, no `continuation` opacity (it is a raw id), no `title/self/direction`. **[src]**
6. Items: `summary.content` (not `content.content`) in API mode; no `updated`; `alternate[0]` has no `type`; fullwidth-Unicode escaping of `& < >` in titles/authors and of `' " ^ ? \ / , ;` in feed titles; feed-provided tags appear as bare strings in `categories`; extra `user/-/state/org.server-a/*` categories; `enclosure[]` array. **[src]**
7. `stream/items/ids` refs have only `id`; single `s`; `client=newsplus` empty → `[{"id":"0"}]`. **[src]**
8. `stream/items/contents` is POST-only with form body. **[src]**
9. `mark-all-as-read` `ts` compared to µs ids. **[src]**
10. `ot` includes server-modified items (1.29.0+). **[src]**
11. `it` include-target supported (FeedHQ-ism); `s=user/-/state/com.google/read|unread` accepted (1.27.0+). **[src]**
12. `tag/list` includes `type`/`unread_count` (Inoreader-isms); `subscription/list` includes `frss:priority`; `subscription/export|import`; `check/compatibility`. **[src]**
13. Output only JSON; `output=json` mandatory on three endpoints (501 otherwise). **[src]**
14. API clients never trigger feed refresh (issue #3957 "Actualize when Greader/Fever API is polled" is a request; only `subscription/import` refreshes). **[src, doc]**
15. Responses are streamed for memory reasons (#8041, 1.27.0). **[src]**

## 10. Client-specific comments in the source
- `//Vienna RSS` - `LSID=null` line in ClientLogin.
- `//FeedMe` - `T=''` accepted; `stream/contents` without stream; `stream/items/contents` POST `i`.
- `//client A` - `T='x'` accepted.
- `//EasyRSS & client A` - `timestampUsec` field; `//EasyRSS` - `origin.title`; `//EasyRSS, FeedMe` - bare `stream/contents`.
- `//Inoreader` - `type: folder|tag`, `unread_count` in tag/list.
- News+ (`newsplus`) - empty itemRefs hack (noinnion/newsplus#84), 500,000-byte content cap ("tested with News+").
- BazQux - `stream/contents?s=` compatibility.
- The Old Reader - `user-info`, `quickadd`, `rename-tag`/`disable-tag` shapes, `ts` comment.
- No references to client B, Unread, Fiery Feeds or News Explorer in `greader.php`. README marks client A as GReader with "Fetch read articles ✓, Favourites ✓, Labels -, Podcasts -, Manage feeds ✓"; client B "Work in progress", GReader, Favourites ✓, Manage feeds ✓; Unread and Fiery Feeds listed as **Fever** clients. **[src, README]**
- client A-related issues: #2759/#3052/#4413 (client A 4 sorted/dated by `crawlTimeMsec`; Redate extension; not needed for client A); #4105 (client A UA `client A/5010.01.03 CFNetwork/...`, sends `POST /accounts/ClientLogin` then `GET /reader/api/0/user-info?output=json`; ClientLogin POST had no `Content-Type`/`Content-Length`); #3531 (1.18 regression: correct Auth header still got `Unauthorized!` on `user-info`, fixed 1.18.1). **[doc]**

## 11. What client B actually sends (cross-check, `ReaderAPICaller.swift`, main)
Endpoints used: `/accounts/ClientLogin`, `/reader/api/0/token`, `disable-tag`, `rename-tag`, `tag/list?output=json`, `subscription/list?output=json` (with conditional GET headers; treats 304 as "skip"), `subscription/edit` (`T=&s=&ac=unsubscribe` / `T=&s=&ac=edit[&r=user/-/label/X][&a=user/-/label/Y][&t=title]`), `subscription/quickadd` (`T=&quickadd=<url>`), `subscription/import` (raw OPML, `text/xml`), `stream/items/contents` (POST `T=<token>&output=json&i=tag:google.com,2005:reader/item/<16hex>&i=...`), `stream/items/ids` (GET `n=1000&output=json` plus: all-for-account `ot=<lastFetch or now-3 months>&s=user/-/state/com.google/reading-list`; per-feed `ot=<now-3mo>&s=<feedID>`; unread `s=reading-list&xt=user/-/state/com.google/read`; starred `s=user/-/state/com.google/starred`; pages with `c=`), `edit-tag` (POST `T=&i=...&i=...&a|r=user/-/state/com.google/read|starred`). It parses `Auth=` from ClientLogin lines, strips the trailing `\n` from `/token`, and on 401/403 refetches the token once. It never calls `stream/contents`, `unread-count`, `user-info`, or `mark-all-as-read`. **[src NNW]**

## 12. Recommended sync strategy per server A maintainer (issue #2566 comment, linked from official docs)
Seven requests, modelled on News+: (1) `tag/list`, (2) `subscription/list`, (3) `stream/contents/user/-/state/com.google/reading-list?xt=user/-/state/com.google/read&ot=<lastSync>&n=1000&r=n`, (4) `stream/items/ids?s=user/-/state/com.google/reading-list&xt=user/-/state/com.google/read&n=10000&r=n`, (5) `stream/contents/.../starred?xt=...read&ot=...&n=1000&r=n`, (6) `stream/contents/.../starred?n=1000&r=n`, (7) `stream/items/ids?s=user/-/state/com.google/starred&n=10000&r=n`. Docs also link BazQux's "The Right Way to Sync" (don't sync per-feed, don't rely on `ot` alone; use `stream/items/ids` for unread + starred, then fetch missing contents by id). **[doc]**

## 13. Gotchas to reproduce or avoid when building a server A-flavour server
- Parse `Authorization: GoogleLogin auth=<token>`; token may contain `/`. Accept `Email`/`Passwd` from POST body (and GET).
- Return `T` as a 57-char string ending in a newline; accept `T=x` (client A) and empty `T`.
- Emit both `crawlTimeMsec` and `timestampUsec` (strings) and `published` (int). Keep ids monotonic in ingestion order because `c`, `r`, `ts` and `ot` all lean on id order.
- Accept item ids in long form (`tag:google.com,2005:reader/item/` + 16 hex), bare hex, and short decimal; client B sends long form built with `%.16llx`, and its itemRefs parser expects the decimal `id` string back.
- `stream/items/contents` must accept POST form bodies with repeated `i=`; `edit-tag` must accept repeated `i`, `a`, `r` in one body.
- `output=json` required on tag/list, subscription/list, unread-count (clients always send it); `n`, `r=n|o|d`, `xt`, `it`, `ot`, `nt`, `c` on both stream endpoints; `s=` on items/ids (single stream).
- Feed ids as `feed/<number>`, category as the single `categories[]` entry with `id` + `label`; hide nothing unless you implement priorities.


## Claims
- [high LB] server A ClientLogin (POST or GET /accounts/ClientLogin with Email, Passwd) returns text/plain lines SID=<user>/<sha1>, LSID=null, Auth=<user>/<sha1> where sha1 = sha1(salt . user . apiPasswordHash); the token never expires. (server A repo: p/api/greader.php)
- [high LB] All non-/accounts requests require the header Authorization: GoogleLogin auth=<user>/<sha1>; server A parses it with parse_str so the key becomes GoogleLogin_auth, splits on the first '/', and compares with hash_equals; failure is 401 'Unauthorized!' with header Google-Bad-Token: true. (server A repo: p/api/greader.php)
- [high LB] GET /reader/api/0/token returns the 40-hex sha1 right-padded with 'Z' to exactly 57 characters plus a trailing newline; checkToken accepts T='' (FeedMe) and T='x' (client A) for any non-internal user, and T is only checked on edit-tag, rename-tag, disable-tag and mark-all-as-read. (server A repo: p/api/greader.php)
- [high LB] output=json is mandatory on tag/list, subscription/list and unread-count (otherwise 501 'Not Implemented!'); it is ignored on all other endpoints and no Atom output exists. (server A repo: p/api/greader.php)
- [high] Error bodies are text/plain: 400 'Bad Request!', 401 'Unauthorized!', 500 'Internal Server Error!', 501 'Not Implemented!', 503 'Service Unavailable!' (API disabled); OPTIONS returns 204; unmatched routes return 400. (server A repo: p/api/greader.php)
- [high LB] server A entry ids are uTimeString() = unix seconds concatenated with zero-padded 6-digit microseconds (16-digit decimal); long-form item id is 'tag:google.com,2005:reader/item/' + str_pad(dechex(id),16,'0',STR_PAD_LEFT); short form is the decimal string. (server A repo: app/Models/Entry.php)
- [high LB] On input (edit-tag i=, stream/items/contents i=), an id that is not ctype_digit or starts with '0' is treated as hex: basename() strips the 'tag:google.com,2005:reader/item/' prefix and hexdec() converts; server A performs no signed/two's-complement handling because its ids never exceed 2^63. (server A repo: p/api/greader.php)
- [high LB] Item JSON fields: crawlTimeMsec = id with last 3 digits dropped (ms string), timestampUsec = id (us string), published = feed publication date (int seconds); item 'updated' is not emitted; top-level 'updated' is time(). (server A repo: app/Models/Entry.php)
- [high LB] In API ('compat') mode the item body is in summary.content (not content.content), truncated with mb_strcut to 500000 bytes; alternate[0].type is removed; titles/authors have & < > replaced by fullwidth Unicode; feed titles additionally replace ' " ^ ? \ / , ; (server A repo: app/Models/Entry.php)
- [high LB] Item categories array contains 'user/-/state/com.google/reading-list', 'user/-/label/<Category>', optional 'user/-/state/org.server-a/main|important|hidden', 'user/-/state/com.google/read' if read, 'user/-/state/com.google/starred' if starred, 'user/-/label/<Label>' per label, and raw feed-provided tag strings without prefix. (server A repo: app/Models/Entry.php)
- [high LB] stream/contents response always has "id": "user/-/state/com.google/reading-list" regardless of the stream requested, "updated": <now>, "items": [...], and "continuation": "<last decimal id>" only when nbItems >= n and lastEntryId > 0. (server A repo: p/api/greader.php)
- [high LB] Continuation c is the last entry id of the previous page; the server increments n by one, queries id <= c (DESC) or id >= c (ASC) inclusive, then discards the first row; a non-digit c is treated as absent. (server A repo: p/api/greader.php)
- [high LB] r: only r=o gives ASC by entry id; r=n, r=d or absent give DESC; ordering is always by entry id (ingestion time), never by published date; n defaults to 20 with no upper cap. (server A repo: p/api/greader.php)
- [high LB] stream/items/ids requires a single s= parameter and returns {"itemRefs":[{"id":"<decimal>"}...],"continuation":"<id>"} with no timestampUsec or directStreamIds; if empty and client=newsplus it returns [{"id":"0"}]. (server A repo: p/api/greader.php)
- [high LB] stream/items/contents is POST-only and requires i in the form-encoded body ($_POST['i']); repeated i= values are parsed from the raw body; results are ordered by id and the response never includes continuation. (server A repo: p/api/greader.php)
- [high LB] Repeated POST parameters (i, a, r, s, t) are extracted by splitting the raw php://input on '&' and matching 'name=' prefixes with urldecode; the body is capped at 1,048,576 bytes. (server A repo: p/api/greader.php)
- [high LB] edit-tag applies every a= then every r= to all listed i= items: read -> markRead, starred -> markFavorite, broadcast/like/tracking-kept-unread -> ignored, user/-/label/X (or user/<me>/label/X on add) -> create-if-missing label and tag/untag; response body is 'OK'. (server A repo: p/api/greader.php)
- [high LB] mark-all-as-read takes POST s and ts (digits only, default '0'); ts is compared directly to the microsecond entry id (UPDATE ... WHERE is_read <> 1 AND id <= ts); ts=0 means now; feed streams must be feed/<numeric id>. (server A repo: app/Models/EntryDAO.php)
- [medium LB] A client that sends ts in seconds to server A mark-all-as-read marks nothing (id <= 10-digit value never true), while nanoseconds mark everything; FeedHQ documents ts as microseconds and The Old Reader as 'nanoseconds' with a 16-digit example. (https://raw.githubusercontent.com/theoldreader/api/master/README.md)
- [high LB] xt/it are reduced to a state bitmask (READ=1, NOT_READ=2, ALL=3, FAVORITE=4, NOT_FAVORITE=8); it sets the base, xt ANDs it; a resulting 0 is reset to ALL, so xt=starred is a no-op and it=starred&xt=read returns all items, while the starred stream plus xt=read correctly yields unread favourites. (server A repo: p/api/greader.php)
- [high LB] Since 1.29.0 (PR #8131) ot matches entries with id >= ot*10^6 OR lastModified >= ot (server-side content modification), excluding user read/star changes; nt matches id <= nt*10^6 AND COALESCE(lastModified,0) <= nt. (server A PR #8131)
- [medium] When both ot and nt are supplied, server A OR-joins the three sub-searches ((id>=ot) OR (lastModified>=ot) OR (id<=nt AND lastModified<=nt)), so for nt >= ot the filter matches everything. (server A repo: app/Models/EntryDAO.php)
- [high LB] tag/list returns {"tags":[{"id":"user/-/state/com.google/starred"},{"id":"user/-/state/com.google/reading-list"},{"id":"user/-/state/org.server-a/main"},{"id":"user/-/state/org.server-a/important"}, categories as {"id":"user/-/label/<name>","type":"folder"}, labels as {"id":"user/-/label/<name>","type":"tag","unread_count":n}]} with no sortid. (server A repo: p/api/greader.php)
- [high LB] subscription/list returns {"subscriptions":[{"id":"feed/<numericId>","title","categories":[{"id":"user/-/label/<Cat>","label":"<Cat>"}],"url","htmlUrl","iconUrl","frss:priority":"important|main|category|feed"}]} with exactly one category per feed and hidden feeds omitted. (server A repo: p/api/greader.php)
- [high LB] unread-count returns {"max":<totalUnread>,"unreadcounts":[{"id":"feed/<id>","count":n,"newestItemTimestampUsec":"<MAX(id)>"}, category rows after their feeds, label rows, and finally {"id":"user/-/state/com.google/reading-list",...}]}. (server A repo: p/api/greader.php)
- [high] user-info returns {"userId","userName","userProfileId"} all equal to the username plus "userEmail" = mail_login, without an explicit JSON Content-Type header. (server A repo: p/api/greader.php)
- [high LB] subscription/edit reads ac, s, t, a, r from $_REQUEST (GET or POST, no T token check); ac in subscribe|unsubscribe|edit; title parameter is t (not Google's title); a/r are single-valued and target categories, unknown category names are auto-created; s may be repeated in POST; response 'OK'. (server A repo: p/api/greader.php)
- [high LB] subscription/quickadd (quickadd=<url>, no T check) returns {"numResults":1,"query":<url>,"streamId":"feed/<id>","streamName":<name>} or, with HTTP 200, {"numResults":0,"error":<msg>}; JSON Feed kind is guessed when the URL matches /(?:\b|_)json(?:\b|_)/i. (server A repo: p/api/greader.php)
- [high] rename-tag takes POST T, s=user/-/label/<old>, dest=user/-/label/<new>; disable-tag takes T and s=user/-/label/<name> (category: feeds moved to default and category deleted; else label deleted); both respond 'OK' or 400. (server A repo: p/api/greader.php)
- [high LB] stream/contents path accepts feed/<id|url>, user/-/state/{com.google,org.server-a}/{reading-list,starred,main,important}, user/-/label/<name>, a bare 'stream/contents' (reading-list, for EasyRSS/FeedMe) and '?s=<stream>' (BazQux); feed URLs and labels are re-extracted from REQUEST_URI so they must be percent-encoded as one path segment (%2F), requiring AllowEncodedSlashes on Apache. (server A repo: p/api/greader.php)
- [high LB] stream/items/ids accepts s = user/-/state/com.google/reading-list|starred|read|unread, user/-/state/org.server-a/main|important, feed/<id|url>, user/-/label/<name> (category first, then label); read/unread in s were added in 1.27.0 (PR #7695) for Read You. (server A PR #7695)
- [high] GET /check/compatibility returns text/plain 'PASS' when the Authorization header reaches PHP and PHP is 64-bit or has GMP; api.js probes /check/compatibility, /check%2Fcompatibility and ./greader.php/check/compatibility. (server A repo: p/scripts/api.js)
- [high] server A API clients never trigger feed refreshes except subscription/import, which calls actualizeFeedsAndCommit. (server A repo: p/api/greader.php)
- [high LB] client B (main) uses ClientLogin, token, tag/list?output=json, subscription/list?output=json (conditional GET), subscription/edit (ac=edit with r/a=user/-/label/X and t), subscription/quickadd, subscription/import (text/xml OPML), stream/items/contents (POST T=&output=json&i=tag:google.com,2005:reader/item/<%.16llx>...), stream/items/ids (n=1000&output=json with ot+s, s+xt=read, or s=starred, paging with c), and edit-tag (T=&i=...&a|r=state); it never calls stream/contents, unread-count, user-info or mark-all-as-read. (https://raw.githubusercontent.com/Ranchero-Software/client B/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] client B parses ClientLogin by splitting lines on '=' and requires an 'Auth' key; it strips a trailing newline from /token and refetches the token once on 401/403; item refs are read from itemRefs[].id and continuation from 'continuation'. (https://raw.githubusercontent.com/Ranchero-Software/client B/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [medium] client A 4 dated/sorted articles by crawlTimeMsec/timestampUsec (server A ingestion time), prompting the third-party GReader Redate extension; client A displays the published date and the extension is not needed (README PR #4413, issue #2759). (server A PR #4413)
- [medium] client A logs in with POST /api/greader.php/accounts/ClientLogin followed by GET /api/greader.php/reader/api/0/user-info?output=json (User-Agent client A/5010.01.03 CFNetwork/...). (server A issue #4105)
- [high] The server A maintainer's recommended sync (News+ pattern) is: tag/list, subscription/list, stream/contents/reading-list?xt=read&ot=&n=1000&r=n, stream/items/ids?s=reading-list&xt=read&n=10000&r=n, stream/contents/starred?xt=read&ot=&n=1000&r=n, stream/contents/starred?n=1000&r=n, stream/items/ids?s=starred&n=10000&r=n. (server A issue #2566#issuecomment-541317776)
- [high LB] Google's original spec defines the short-form item id as a signed base-10 64-bit number and the long form as unsigned 0-padded 16-hex (e.g. fb115bd6d34a8e9f <-> -355401917359550817), ot/nt in seconds, T token valid 30 minutes with header X-Reader-Google-Bad-Token on failure. (https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ItemId.wiki)
- [medium] The GReader API code in p/api/greader.php was most recently changed by #9322 (SensitiveParameter, 2026-09-19), #9183 (hash_equals token, 2026-08-08), #9167 (JSON Feed detection on subscribe), #8697 (JSON encoding on malformed UTF-8), #8131 (lastModified ot filter, 2026-03-01), #8041 (streaming), #7583 (frss:priority), #7695 (states in s), #7437 (labels with slash). ((link removed))

## Open questions
- Whether the ot+nt OR-combination (all three ServerA_Search objects in one BooleanSearch) is intentional or a bug - inferred from code, not executed; worth a test against a live server A before Kipple mirrors or deliberately diverges from it.
- Exact hashing parameters of ServerA_password_Util::hash (bcrypt cost) - file not located under the paths tried; only password_verify usage is verified. Not needed for a compatible server since Kipple defines its own hash.
- client A's exact request set against server A (which of stream/contents vs stream/items/ids+items/contents it uses, whether it sends ot/nt/xt, whether it uses mark-all-as-read with ts and in which unit, and whether it still sends T=x) is not in server A source or docs; only issue logs (ClientLogin then user-info) and the checkToken comment were found. A packet capture or client A-specific research is needed.
- Whether client B's ReaderAPIVariant.server-a changes any behaviour beyond using the user-supplied endpoint URL (the caller only branches on it for apiBaseURL); the Account delegate/parsers (ReaderAPIEntry, ReaderAPIReferenceWrapper) were not read and may impose field requirements (e.g. expecting summary vs content, timestampUsec vs crawlTimeMsec).
- The precise content of the GReader Redate extension README (GitHub raw returned 404; repo appears to have moved to Codeberg) - only the search-engine summary was available.
- How server A's `hidden` priority interacts with mark-all-as-read on feed/<id> (markReadFeed does not filter by priority) - minor.

## Sources
- server A repo: p/api/greader.php
- server A repo: app/Models/Entry.php
- server A repo: app/Models/EntryDAO.php
- server A repo: app/Models/FeedDAO.php
- server A repo: app/Models/Feed.php
- server A repo: app/Models/BooleanSearch.php
- server A repo: app/Models/Search.php
- server A repo: app/Services/ExportService.php
- server A repo: app/Controllers/apiController.php
- server A repo: app/views/user/profile.phtml
- server A repo: lib/lib_rss.php
- server A repo: lib/Minz/User.php
- server A repo: constants.php
- server A repo: config-user.default.php
- server A repo: p/api/.htaccess
- server A repo: p/api/index.php
- server A repo: p/scripts/api.js
- server A repo: docs/en/users/06_Mobile_access.md
- server A repo: docs/en/developers/06_GoogleReader_API.md
- server A repo: README.md
- server A repo: CHANGELOG.md
- (link removed)
- server A issue #2566#issuecomment-541317776
- server A PR #8131
- server A issue #7304
- server A issue #8129
- server A PR #8130.patch
- server A PR #7695
- server A PR #7437.patch
- server A PR #7033
- server A PR #7060
- server A PR #7017
- server A PR #7583
- server A PR #4413
- server A issue #3052
- server A issue #2759
- server A issue #4105
- server A issue #3531
- server A issue #5363
- https://github.com/jocmp/capyreader/discussions/533
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ItemId.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/StreamId.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ActionToken.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiStreamItemsIds.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiStreamItemsContents.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiStreamContents.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiSubscriptionEdit.wiki
- https://feedhq.readthedocs.io/en/latest/api/reference.html
- https://feedhq.readthedocs.io/en/latest/api/terminology.html
- https://raw.githubusercontent.com/theoldreader/api/master/README.md
- https://raw.githubusercontent.com/bazqux/bazqux-api/master/README.md
- https://raw.githubusercontent.com/Ranchero-Software/client B/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift
- (link removed)
