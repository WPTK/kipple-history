# item-id-and-quirks

# Google Reader API: item IDs, timestamps, stream/edit semantics, client quirks

Scope / versions examined (all read directly, 2026-09-24):
- FreshRSS `edge`: `p/api/greader.php` (1352 lines), `app/Models/Entry.php` (`toGReader`, `dec2hex`), `app/Models/EntryDAO.php`, `lib/lib_rss.php`.
- Miniflux `main`: `internal/googlereader/{handler,item,item_test,response,stream,parameters,request_modifier,middleware,prefix_suffix}.go`, `internal/googlereader/README.md`, `internal/model/entry.go`, `internal/storage/{entry_query_builder,entry}.go`, `internal/http/response/{json,text}.go`.
- CommaFeed `master` (API added in 7.3.0, CHANGELOG): `commafeed-server/src/main/java/com/commafeed/frontend/resource/googlereader/{GoogleReaderREST,GoogleReaderModel,GoogleReaderStreamId}.java`, `security/mechanism/GoogleReaderAuthenticationMechanism.java`, test `integration/rest/GoogleReaderIT.java`.
- Tiny Tiny RSS: there is no first-party greader plugin; the one in use is `eric-pierce/freshapi` (`api/freshapi.php`, 1877 lines, v1.2, "Modeled after ... FreshRSS"). Read directly.
- NetNewsWire `main` (commits through 2026-09-04): `Modules/Account/Sources/Account/ReaderAPI/*.swift`, `Modules/Account/Tests/AccountTests/ReaderAPI/ReaderAPIEntryTests.swift`.
- Docs: `mihaip/google-reader-api` wiki (ItemId, ApiStreamItemsIds, ApiStreamContents, ApiStreamItemsContents, ApiEditTags, ApiSubscriptionEdit, ActionToken, StreamId, ApiCommonInputs, Authentication), BazQux `bazqux-api/README.md`, TheOldReader `api/README.md`, Inoreader developer pages (raw HTML), FeedHQ docs, pyrfeed wiki (archive.org), Martin Doms part 2/3 (archive.org), undoc.in ClientLogin (archive.org).
- Feedbin and Feedly: **neither emulates the Google Reader API** (Feedbin has its own REST API at api.feedbin.com; Feedly built "Normandy", its own API). Reeder Classic's service list confirms the GReader-family services are FreshRSS, BazQux, Inoreader, The Old Reader (reederapp.com/classic). Not covered further.
- Readrops (Android, open source) client code also read: `api/src/main/java/com/readrops/api/services/greader/{GReaderDataSource,GReaderService,GReaderSyncData}.kt`.

---

## 1. Item IDs

### 1.1 Canonical definition (Google, verified)
mihaip `ItemId.wiki`: "Internally, item IDs are 64-bit numbers ... *Long form*: The prefix `tag:google.com,2005:reader/item/` followed by the ID as an *unsigned* *base 16* number that is *0-padded* so that it's always 16 characters wide. *Short form*: The ID as a *signed* *base 10* number." Examples: `5d0cfa30041d4348`=`6705009029382226760`; `024025978b5e50d2`=`162170919393841362` ("Long form needs 0-padding"); `fb115bd6d34a8e9f`=`-355401917359550817` ("Short form ends up being negative"). "All API methods that take item IDs accept either form, but different outputs will contain different forms." `ApiStreamItemsIds.wiki`: itemRefs `id` is the "signed base 10 version". BazQux README repeats it: `tag:google.com,2005:reader/item/80484b00000e8003` = `-9203023375158575101`; "`/stream/items/ids` return ids in short form but `/stream/items/contents` in long form."

### 1.2 Per-server emit/parse (verified in source)

| Server | itemRefs[].id | items[].id | Parses `i=` | Top-bit / negative handling |
|---|---|---|---|---|
| FreshRSS | `'id' => '' . $entryId, //64-bit decimal` — decimal **string** | `'tag:google.com,2005:reader/item/' . self::dec2hex($this->id())`, `dec2hex` = `str_pad(dechex((int)$dec), 16, '0', STR_PAD_LEFT)` | `if (!ctype_digit($e_id) \|\| $e_id[0] === '0') { $e_ids[$i] = hex2dec(basename($e_id)); }` — i.e. all-digit strings not starting with `0` are decimal; everything else is `basename()`'d (strips the tag prefix) and parsed as hex via `hexdec()` (GMP on 32-bit). Same code in `streamContentsItems` and `editTag`. | A negative decimal (`-355...`) fails `ctype_digit`, then fails `ctype_xdigit` → `hex2dec` returns `'0'` → item silently not found (inferred from code). Irrelevant in practice: FreshRSS ids are microsecond timestamps (~1.7e15, hex `0006...`), never top-bit. Ambiguity: a bare hex string that is all digits and doesn't start with `0` is misparsed as decimal. |
| Miniflux | `strconv.FormatInt(entryID, 10)` — decimal **string** (`itemRef.ID string`) | `fmt.Sprintf("tag:google.com,2005:reader/item/%016x", entryID)` | `parseItemID`: if prefix present → `fmt.Sscanf(v, ItemIDFormat, &itemID)` (hex, any width; zero rejected); else `if len(v)==16` try `Sscanf("%016x")`; else `strconv.ParseInt(v, 10, 64)`. Code comment: "NetNewsWire uses this format: `tag:google.com,2005:reader/item/2f2` (hexadecimal string with prefix and no padding); Reeder uses this format: `000000000000048c` (hexadecimal string without prefix and padding); Liferea uses this format: `12345` (decimal string)". Test: `12345`, `.../00000000148b9369`, `.../2f2`, `000000000000046f`, `.../272` → `12345, 344691561, 754, 1135, 626`. | Negative decimal parses fine via ParseInt. Hex with top bit set (`ffff...`) overflows `Sscanf` into `int64` → error → falls to decimal parse → 400 (inferred). Never occurs: Postgres bigserial ids are positive. Ambiguity: a 16-digit decimal id (≥1e15) is parsed as hex first. |
| CommaFeed | `String.valueOf(s.getEntry().getId())` — decimal **string** | `"tag:google.com,2005:reader/item/" + String.format("%016x", id)` (test asserts regex `tag:google\.com,2005:reader/item/[0-9a-f]{16}`) | `parseItemId`: `if (raw.startsWith("tag:google.com") && idx != -1) return Long.parseUnsignedLong(raw.substring(idx+1), 16)` else `Long.valueOf(raw)`. **Bare 16-hex without prefix (Reeder's form) is NOT handled** — `Long.valueOf("000000000000048c")` throws → id skipped silently (`continue`). | Correct two's-complement round trip: `parseUnsignedLong(..,16)` reinterprets top-bit hex as negative long, `%016x` on a negative long prints two's complement, `Long.valueOf` accepts negatives. |
| TT-RSS freshapi | `SELECT ref_id::varchar as id` — decimal **string** | `'tag:google.com,2005:reader/item/' . dec2hex(strval($article['id']))` (same helper as FreshRSS) | FreshRSS heuristic **plus a User-Agent sniff**: `if (!ctype_digit($e_id) \|\| $e_id[0] === '0' \|\| (substr($_SERVER['HTTP_USER_AGENT'], 0, 11) == 'NetNewsWire'))` → hex. Exists precisely because pre-Aug-2026 NetNewsWire sent unpadded hex (`.../item/1234` is all digits and would be misread as decimal). | Same as FreshRSS. |
| BazQux (docs) | short form (signed decimal) | long form | "All API calls accept both item ids formats." | Documented negative example above. |
| Inoreader (docs) | short form, e.g. `id`s in `itemRefs` | long form `"tag:google.com,2005:reader/item/0000000693c3bc0c"` | edit-tag: "`i` - item ID. Can accept two types of values ... `1234567890` (shortened ID, preferred as it saves bandwidth)"; "`i` can be an array of IDs". | Docs mirror mihaip's text. |
| TheOldReader (docs) | — | `tag:google.com,2005:reader/item/00157a17b192950b65be3791` — **24-hex MongoDB ObjectId, not a 64-bit number** | long form only shown | NetNewsWire special-cases `.theOldReader` to pass the raw id part untouched. |

### 1.3 What clients send (verified)
- **NetNewsWire** (`ReaderAPICaller.itemIDParameter`): `String(format: "%.16llx", idValue)` → always `i=tag:google.com,2005:reader/item/<16 hex>`; doc comment: "The long form is zero-padded 16-digit hex, two's-complement for negative IDs." Same encoding for `stream/items/contents` and `edit-tag`. Commit 2026-08-02: "Fix Reader API item ID encoding in the article contents request — it was unpadded and wrong for negative IDs" — so NNW ≤ mid-2026 sent unpadded hex (`.../item/2f2`), which is what Miniflux's comment and the TT-RSS UA hack refer to. Decoding (`ReaderAPIEntry.uniqueID`): last path component → `UInt64(idPart, radix: 16)` → `String(Int64(bitPattern: idNumber))`; tests: `00058b10ce338909`→`1560279178774793`, `ffffffffffffcdef`→`-12817`, `0000000000000000`→`0`; commit 2026-09-01 "Parse Reader API hex item IDs as unsigned so high-bit IDs no longer overflow to an unsendable ID." itemRefs ids are used verbatim, and `articleIDIsSendable` = `Int(articleID) != nil` — **itemRefs.id must be a decimal string or NNW silently drops the status change**. Consequence: NNW requires items[].id in long hex form and itemRefs[].id in decimal; mixing breaks the join.
- **Reeder**: bare zero-padded 16-hex, no prefix, in `i=` (Miniflux code comment; FreshRSS #2956 Postgres log `invalid input syntax for integer: "0005978fb9baf6b1"` on `stream/items/contents`, fixed by FreshRSS PR #2957; davd.io: "at least Reeder sometimes sends" `000000000000001F`). In that 2020 log Reeder POSTed 100 ids, then 56, per `stream/items/contents`. Reeder requires `itemRefs[].id` to be a JSON **string**: FreshRSS #2620 — MySQL native statements started returning `{"itemRefs":[{"id":1572638017615972},...]}` and Reeder showed "Type Mismatch"; forcing `"id":"1572638017615972"` fixed it (PR #2621, 1.15.1). Miniflux #2960: fguillot "I think it was breaking Reeder" when ids were parsed as decimal (commit 3eb3ac0 reverted `ParseInt(item, 10, 64)` back to base 16); resolved by the multi-format parser in PR #3325.
- **Liferea**: passes decimal short ids from `items/ids` unchanged to `items/contents` (Miniflux #2960). **RSSGuard**: converts short→long before requesting (same thread).
- **Readrops**: passes whatever `stream/items/ids` returned (List<String>) straight into `edit-tag` `i=`.

---

## 2. Timestamps and pagination

### 2.1 Original definitions (verified)
- `ApiStreamItemsIds.wiki`: itemRefs `timestampUsec`: "time in microseconds since the epoch that the item appeared in the direct stream that it was in"; `directStreamIds`: array of StreamIds; `nt`/`ot`: "Timestamp (in seconds since the epoch)"; `n` "up to a maximum of 10,000"; `r`: `n` newest-first (default), `o` oldest-first, `a` magic, `c` comments; `includeAllDirectStreamIds` default false; `merge`.
- `ApiStreamContents.wiki`: `c` "Continuation token ... `CJLRnpeNpakC`"; `n` "up to a maximum of 1,000", default 20; `ot`/`nt` seconds. Martin Doms sample: `"continuation":"CLbwxoSAsZsC"`, `"crawlTimeMsec":"1255415774867"` (string), `"updated":1255415774`; pyrfeed: "continuation has no meaning, it's just a string"; `ot` "Only works for order r=o mode. If the time is older than one month ago, one month ago will be used instead."
- Original Google item (posted by Alkarex in FreshRSS #2759): `"crawlTimeMsec" : "1320065162882", "timestampUsec" : "1320065162882657", "published" : 1320045130, "updated" : 1320045130` — crawl fields are strings and equal the crawl time; `published`/`updated` are integers in seconds.
- unread-count (Martin Doms sample): `{"max":1000,"unreadcounts":[{"id":"feed/...","count":3,"newestItemTimestampUsec":"1255568508813466"}, ...]}` — `max` was 1000 in Google Reader.
- mark-all-as-read `ts`: FeedHQ "an epoch timestamp **in microseconds**"; BazQux "`ts=...` - maximum published time in μs"; TheOldReader example `ts=1371645508000000` (16 digits = µs) but labelled "# Older than timestamp in nanoseconds" — FreshRSS and TT-RSS copied that wrong comment (`//Older than timestamp in nanoseconds`) while implementing µs; Inoreader: "`ts` - Unix Timestamp in seconds or microseconds."
- Token: pyrfeed "This url will return a string containing 57 chars. It's the token."; mihaip `ActionToken.wiki`: "valid for 30 minutes. If it is missing or invalid, a 401 HTTP response code will be given and the response will have a `X-Reader-Google-Bad-Token: true` HTTP header." Google sample token in ApiCommonInputs is `//RQ5Ala9wTbGxisuYqJALKg` (24 chars) — the 57 figure comes from pyrfeed and is what FreshRSS/TT-RSS/davd.io enforce.

### 2.2 Per-server field semantics (verified in source)

| Field | FreshRSS | Miniflux | CommaFeed | TT-RSS freshapi |
|---|---|---|---|---|
| `published` (int s) | `$this->date(true)` (feed pubDate) | `entry.Date.Unix()` | `entry.getPublished()` or EPOCH if null | `$article['updated']` (TT-RSS "updated") |
| `updated` (int s) | **omitted** (`// 'updated'` commented out) | `entry.ChangedAt.Unix()` — **time of last status change**, not content update (`changed_at=now()` on mark read) | same as `published` | omitted |
| `crawlTimeMsec` (string ms) | `substr($this->dateAdded(true,true), 0, -3)` = crawl time (= entry id / 1000) | `strconv.FormatInt(entry.CreatedAt.UnixMilli(), 10)` (crawl) — fixed in PR #2670/#2673 (was µs) | `String.valueOf(entry.getInserted().toEpochMilli())` (crawl) | `$article['updated'] . '000'` |
| `timestampUsec` (string µs) | `'' . $this->dateAdded(true,true)` = **crawl time = the entry id** (`//EasyRSS & Reeder`) | `strconv.FormatInt(entry.Date.UnixMicro(), 10)` = **published time**, not crawl | `String.valueOf(published.toEpochMilli() * 1000)` = **published**, ms precision padded | `$article['updated'] . '000000'` |
| itemRefs `timestampUsec` / `directStreamIds` | not emitted (only `id`) | struct fields exist (`omitempty`) but never populated → absent | not in model → absent | absent |
| `newestItemTimestampUsec` | `MAX(id)` per feed (µs) as string; per category = max of feeds; total | endpoint not implemented | per feed only: `toUsec(newest)`=ms*1000; category/reading-list entries carry `count` only | `str_pad($counter['ts'], 16, "0", STR_PAD_RIGHT)` — seconds right-padded to 16 digits |
| `ot` / `nt` | `(int)$_GET['ot']` seconds. `ot`: `(id >= ot*1e6) OR (lastModified >= ot)` (SQL `id >= ?` with `"{$min}000000"`, `` `lastModified` >= ? ``); `nt`: `id <= nt*1e6 AND lastModified <= nt` | `request.QueryInt64Param(... "ot")` seconds → `e.published_at > $` / `e.published_at < $` (filters on **published**, not crawl) — added in 2.0.39 "Add support for date filtering in Google Reader API item ID calls" | **not supported**: `streamItemIds`/`streamContents*` only read `s,n,c,r,xt` | passed as `since_id`-ish min_date into TT-RSS API |
| `ts` (mark-all-as-read) | `ctype_digit` else 400; passed as `$idMax` into `UPDATE ... WHERE is_read <> ? AND id <= ?` — i.e. compared to the µs id; `'0'` → `uTimeString()` now. Seconds or ms → `id <= 1.7e9` → marks nothing (inferred) | `if len(ts) >= 16 { time.UnixMicro } else { time.Unix }` ("It's unclear if the timestamp is in seconds or microseconds, so we try both using a naive approach"); omitted → now; SQL `status=unread AND published_at < before` | `Instant.ofEpochSecond(ts / 1_000_000)` — µs assumed; seconds → 1970 → marks nothing | `intval($olderThanId / 1000000)` → seconds → `FEED:<id>:<ts>` catchup |
| `c` continuation | **numeric entry id** of the last item (`"continuation": "$lastEntryId"`); server re-queries `count+1` from `id <= c` (DESC) / `id >= c` (ASC) and drops the first; non-digit `c` → `'0'`; emitted iff `nbItems >= count` | **numeric SQL offset**: `result.Offset = QueryIntParam("c")`, `continuation = len(itemRefs)+Offset` iff `< totalEntries`; `json:"continuation,omitempty,string"` → `"continuation":"2"`, absent when done | last entry id (`statuses.getLast().getEntry().getId()`) for reading-list/feed/label, but **OFFSET** (`parseOffset`) for starred; emitted iff `fetchedCount >= limit` | offset (`skip`) |
| ordering | `r === 'o' ? 'ASC' : 'DESC'` on id (crawl order) | `r == "o"` → asc, else desc, on `published_at` | `"o".equals(order) ? ASC : DESC` on entry id | `date_reverse` vs `feed_dates` |
| `n` | `(int)$_GET['n']` default 20; **no cap** (`LIMIT n` only if n>0; n=0 → unlimited, inferred); Alkarex tested `n=20000` (#8370) | `WithLimitAndMaximum(rm.Count, model.MaxEntryIDsLimit)`: `if limit <= 0 \|\| limit > maximum { limit = maximum }` → **10000** cap and default | `DEFAULT_ITEM_COUNT = 20; MAX_ITEM_COUNT = 1000` for both ids and contents | passed to TT-RSS `limit`, paged internally in 200s |

Other servers' limits (docs): BazQux ids `n` default 20 max **50000**, stream/contents 1000, items/contents 1000 per POST, edit-tag 10000 items, mark-all 50000; `ot` = "minimum download time in seconds ... Internally 180 seconds are subtracted"; `c` "it's just an item id and hence never expire". TheOldReader: 10000 ids / 1000 contents. Inoreader: stream/contents `n` "default 20, max 100" (raw HTML `<code>100</code>`), item-ids "max 1000", `ot` "in seconds or in microseconds matching timestampUsec ... When r=o is used the maximum lookback period is approximately one month", `continuation` opaque (`"gmMZgKmmqI4U"`), "If the continuation string is missing, then you are at the end of the stream", "Use timestampUsec whenever possible, because we need microsecond resultion."

### 2.3 The timestampUsec disagreement (load-bearing for Reeder)
FreshRSS #2759 (javerous disassembled Reeder 4): Reeder reads only `title,id,origin,alternate,content,summary,author,timestampUsec,html_content,html_title` and "they don't use `published` entry: they are using `timestampUsec`" for the displayed date. Alkarex refused to change: "timestampUsec is used by the stream API in filters for such as `ot` ... only the first crawl dates provide a robust, monotonous series of timestamps"; PR #2761 ("Use a real timestamp") closed unmerged; PR #2773 added an extension hook instead. So: FreshRSS/Google/Inoreader → `timestampUsec` = crawl time; Miniflux/CommaFeed → `timestampUsec` = published time. Reeder sorts/dates by it either way; NetNewsWire ignores it entirely (`datePublished: entry.parseDatePublished()` from `published`, `dateModified: nil`). EasyRSS also uses `timestampUsec` (`item.setTimestamp(Long.valueOf(parser.getText()))`).

---

## 3. Semantics

### 3.1 `stream/items/ids` and filters
- Google: `s` may repeat; `xt` excludes; `merge`; `includeAllDirectStreamIds`.
- FreshRSS `streamContentsItemsIds`: accepts `s` = `user/-/state/com.google/{reading-list,starred,read,unread}`, `user/-/state/org.freshrss/{main,important}`, `feed/<id>`, `user/-/label/<name>` (category or tag). Filters via bitmask: `it` → `read`→STATE_READ(1), `unread`→STATE_NOT_READ(2), `starred`→STATE_FAVORITE(4), default STATE_ALL(3); `xt=read` → `&= STATE_NOT_READ`, `xt=unread` → `&= STATE_READ`, `xt=starred` → `&= STATE_NOT_FAVORITE`. `reading-list&xt=read` → unread ids. Inferred edge: `it=starred&xt=read` → `4 & 2 = 0` → no state filter at all (returns everything). Only one `s` ("TODO: support multiple streams"). `client=newsplus` with empty result → `itemRefs:[{"id":"0"}]` (News+ bug workaround). `includeAllDirectStreamIds` ignored.
- Miniflux: exactly one `s` or 500; supported `reading-list`, `starred`, `read`, `feed/<numeric id>`; **labels unsupported** (500 "unknown stream type"); `xt=read` on reading-list → `WithStatuses(unread)`, on feed → `WithoutStatus(read)`; `xt` ignored on starred/read streams; `it` "parsed but currently ignored"; unknown `xt` values (e.g. FreshRSS's `user/-/state/com.google/unread`) fail `getStream` → 500. README: "if `n` is omitted, or is above 10000 or non-positive, 10000 items are returned at most; clients must follow `continuation`".
- CommaFeed: `GoogleReaderStreamId.parse` — blank/`reading-list`/full reading-list → ALL; starred; `user/-/label/`; `feed/<subscriptionId>`; **anything else (including `user/-/state/com.google/read`) silently maps to ALL**. `isUnreadOnly` = any `xt` ending in `/state/com.google/read`. Starred: `findStarred` then `filter(!isRead)` post-hoc if unreadOnly.
- TT-RSS freshapi: `read`, `reading-list` (with `xt=read` → unread_only, `xt=unread` → read_only), `starred`.
- Starred stream includes read items on every server (FreshRSS type `s` with STATE_ALL; Miniflux `WithStarred(true)` only; CommaFeed `findStarred`; TT-RSS `starred`), matching Google. Clients depend on it: NNW `.starred` request has no `xt`; Readrops `stream/contents/.../starred?n=1000`; News+ step 6 "List of starred items (also read ones)".

### 3.2 `stream/contents` and `stream/items/contents`
- FreshRSS: `stream/contents/<path>` GET; also BazQux-style `stream/contents?s=...`; bare `stream/contents` (no stream) → reading-list ("EasyRSS, FeedMe"). Response top-level: `{"id":"user/-/state/com.google/reading-list","updated":<now>,"items":[...],"continuation":"<id>"}` — the top-level `id` is always reading-list even for feeds/labels; streamed (heredoc) to avoid memory. `stream/items/contents`: **POST only, `isset($_POST['i'])`** (`//FeedMe`), `i` parsed from raw body by `multiplePosts` (split on `&`, `urldecode`) — so `i`,`a`,`r` must be in an `application/x-www-form-urlencoded` body; `output` not required; compat mode: `summary.content` truncated to `API_MAX_COMPAT_CONTENT_LENGTH = 500000` ("Some clients (tested with News+) would fail if sending too long item content"), `alternate[0].type` removed in compat mode (`unset($item['alternate'][0]['type'])`), `canonical` kept, `origin.{streamId,htmlUrl,title}`, `author` only if non-empty, `categories` includes reading-list, `user/-/label/<category>`, `org.freshrss/{main,important,hidden}`, `read`, `starred`, tag labels; `enclosure[]` with `href,type,length`.
- Miniflux: **`stream/contents` not implemented** (falls to `fallbackHandler` → `[]` with 200 — the cause of FeedMe's empty result in #2129); `unread-count` and `subscription/export` also unimplemented (`[]`). `stream/items/contents`: `POST` only route; requires `output=json` (`checkOutputFormat` → 400 "only json output is supported"); requires `T` (middleware: for POST, `T` from merged form, else 401); ids via `parseItemIDsFromRequest`; response has `direction`, `id` "user/-/state/com.google/reading-list", `title` "Reading List", `self[].href`, `updated`, `author` (username), `items[]` with both `summary` and `content` (identical), `alternate[{href,type:"text/html"}]`, `canonical`, `origin{streamId,title,htmlUrl}`, `enclosure[{url,type}]` (note key `url`, not `href`), categories with **user-specific prefix `user/<id>/state/com.google/...`** (not `user/-/...`).
- CommaFeed: both `GET` (`@QueryParam i`) and `POST` (`@FormParam i`) for items/contents; `stream/contents/{streamId}` and `stream/contents?s=`; item has `summary` only (no `content`), `alternate[{href,type:"text/html"}]`, `canonical[{href}]`, `origin`, `author`, categories `user/-/...`; response `id` reflects the stream; `title`.
- TT-RSS: `alternate` without `type` (commented out), `summary.content` truncated to 500000, `author` always present (may be null), `origin.htmlUrl` derived from link's scheme+host.
- Google `ApiStreamItemsContents.wiki`: "`GET` and `POST` ... `POST` is supported in case so many item IDs are passed in that URL length limits (2K) become an issue"; BazQux: "No more than 1000 items at once. I suggest to fetch 50-100 items per call on mobile."

### 3.3 unread-count
- FreshRSS: entries for every feed (`feed/<id>`), every category (`user/-/label/<cat>`), every tag (`user/-/label/<tag>`), and `user/-/state/com.google/reading-list`; `"max" => $totalUnreads`; requires `output=json` else 501. Hidden-priority feeds excluded.
- CommaFeed: per feed (+ `newestItemTimestampUsec`), per category (count only, root category skipped), reading-list (count only); `max` = constant `MAX_UNREAD_COUNT = 10000` ("cap at which clients should display 'count+' instead of the exact unread count").
- Miniflux: not implemented (`[]`). Reeder, NetNewsWire, Unread do not call it (no such endpoint in NNW code; none in Reeder/Unread server logs); FeedMe/News+/EasyRSS do.
- TT-RSS: feeds + categories + reading-list, `max` = total.
- Google: `max` 1000 (counts capped at 1000).

### 3.4 user-info
All emit strings `userId`, `userName`, `userProfileId`, `userEmail`. FreshRSS: all three ids = username, `userEmail` = `mail_login`; no `output` required. Miniflux: `userId`/`userProfileId` = numeric id string, `userEmail` = username; no `output` check today (older builds returned 500 `"output only as json supported"` to FeedMe, #2129). CommaFeed: numeric id string + real email. TT-RSS: username, `userEmail: ''`. Google/TOR add `isBloggerUser`, `signupTimeSec`, `publicUserName`/`isPremium`. BazQux `userId` is a 20-digit string. Reeder GETs `user-info?output=json` immediately after ClientLogin and treats a 401 there as login failure (FreshRSS #4105/#3531 access logs).

### 3.5 token / T
- FreshRSS: `str_pad(sha1(salt . user . apiPasswordHash), 57, 'Z')` "Must have 57 characters", echoed with trailing `\n`; `checkToken` accepts `$token === ''` (`//FeedMe`) and `$token === 'x'` (`//Reeder`) for non-internal users; only checked on `edit-tag`, `rename-tag`, `disable-tag`, `mark-all-as-read` (not on `stream/items/contents`); `T` read from `$_POST` only.
- Miniflux: token == auth token `<username>/<hmac-sha256 hex>` (~70 chars); **every POST must carry a valid `T`** (query or body); `Authorization` header is ignored on POST; GET must use `Authorization: GoogleLogin auth=` exactly (scheme `GoogleLogin`, field lowercase `auth`).
- CommaFeed: `Digests.md5Hex(apiKey + ":" + userId)` (32 chars); `validToken` = blank OR match ("Some real-world clients (e.g. RSSGuard, unless configured as 'Reedah'/'Miniflux') never call the 'token' endpoint and always submit a blank token"); auth via `Authorization: GoogleLogin auth=` on every request (POST included), the api key being the part after the last `/`.
- TT-RSS: `substr(hash('sha256', session_id . salt), 0, 57)`; blank accepted only when `HTTP_USER_AGENT` starts with `FeedMe`; token checks on mark-all-as-read/disable-tag are commented out.
- BazQux: `Token123`, "expires in 30 minutes, with 'x-reader-google-bad-token: true' header set"; FeedHQ: 30 min, `X-Reader-Google-Bad-Token: true`.
- Bad-token/unauthorized header name: FreshRSS and TT-RSS send **`Google-Bad-Token: true`** (no `X-Reader-` prefix; visible in #3531 curl output); Miniflux sends `X-Reader-Google-Bad-Token: true` with `text/plain` body `Unauthorized`; Google/FeedHQ/BazQux use `X-Reader-Google-Bad-Token`.

### 3.6 edit-tag
- Google `ApiEditTags.wiki`: `i` repeatable ("`1386864356855952360`"), optional parallel `s`, `a` repeatable, `r` repeatable, response `OK`. Martin Doms: `async=true` also sent by Google's own client; pyrfeed history note: token param renamed `token`→`T`, `ac=edit-tags`.
- FreshRSS: `multiplePosts('a')`, `multiplePosts('r')`, `multiplePosts('i')` from raw body; handles `read`/`starred` add/remove, ignores `broadcast`/`like`/`tracking-kept-unread`; anything else starting `user/-/label/` or `user/<user>/label/` is a tag (created on the fly); `a` with no `i` still creates the tag (Readrops relies on this to create folders); returns `OK` text; no 200-limit.
- Miniflux: `a`/`r` from `r.PostForm` (body only), `i` from `r.Form`; `read`, `kept-unread` (add = mark unread, remove = mark read), `starred`; `broadcast`/`like` ignored; conflicting `read`+`kept-unread` or `starred` in both → 500; **unsupported tag types (labels) → error**; no `i` → 400 "no items requested"; `OK` text.
- CommaFeed: `@FormParam` lists; `markRead = containsTag(add, READ)`, `markUnread = containsTag(remove, READ)`, star/unstar; `ids == null` → `OK` no-op; labels ignored.
- TT-RSS: `a` and `r` are single strings (only first value), `i` repeatable.
- BazQux: "No more than 10000 items to tag at once."
- Clients: NNW posts `T=<token>&i=...&i=...&a=user/-/state/com.google/read` (single `a` OR `r` per POST), chunks of 1000 ids; Readrops `@Field("i") itemIds: List<String>` with single `a`/`r`; Unread's initial-sync log shows no edit-tag.

### 3.7 ClientLogin and auth failures
- Google: HTTP 403 + `Error=BadAuthentication` on failure ("Google returns either an HTTP 200, if login succeeded, or an HTTP 403, if login failed" — undoc.in archive of Google docs); success body lines `SID=`, `LSID=`, `Auth=`; header `Authorization: GoogleLogin auth=<Auth>`.
- FreshRSS: `Email`/`Passwd` from POST or GET (GET logged as deprecated); success `text/plain` `SID=user/sha1\nLSID=null\nAuth=user/sha1\n` (`LSID=null //Vienna RSS`); failure → **401** `Unauthorized!` + `Google-Bad-Token: true`; wrong username → 400.
- Miniflux: `POST /accounts/ClientLogin` only; `text/plain; charset=utf-8` `SID=..\nLSID=..\nAuth=..\n` (all three equal), or JSON with `output=json`; failure → 401 JSON `{"error_message":"access unauthorized"}`.
- CommaFeed: 403 `Error=BadAuthentication\n` (test asserts `SC_FORBIDDEN`); success `SID=name/apikey\nLSID=...\nAuth=...\n` text/plain.
- TT-RSS: 401; `LSID=` empty.
- BazQux: prints `Error=BadAuthentication` (status not documented); adds `X-BQ-LoginErrorReason`.
- NNW parses each line with `split(separator: "=")` and requires exactly 2 parts — an `Auth` value containing `=` would be dropped; maps HTTP 404 on ClientLogin to "URL not found"; strips one trailing `\n` from the `/token` body; retries a write once with a fresh token on 401/403.

### 3.8 Empty streams / absent continuation
FreshRSS always emits `"items": [ ]` and `itemRefs: []` (arrays, never null); continuation omitted unless `count >= n`. Miniflux `make([]T, 0)` → `[]`, `continuation` `omitempty`. CommaFeed `new ArrayList<>()` → `[]`, `continuation` null → omitted (`@JsonInclude(NON_NULL)`). NNW decodes `itemRefs: [ReaderAPIReference]?` and `continuation: String?` (a numeric continuation or numeric `id` would fail Swift decoding), `items: [ReaderAPIEntry]` non-optional (null → decode error), top-level `id: String` and `updated: Int` non-optional, per item `summary` (object), `categories` (array), `origin` (object) non-optional, `alternate`/`author`/`title`/`published: Double?`/`crawlTimeMsec: String?`/`timestampUsec: String?` optional. `ReaderAPISubscription`: `id`, `categories: [ReaderAPICategory]` required (empty array OK), each category needs both `id` and `label` (both non-optional Strings); `title`,`url`,`htmlUrl`,`iconUrl` optional. `ReaderAPITag`: `id` required, `type` optional. `ReaderAPIQuickAddResult`: `numResults` required.

### 3.9 `subscription/list` fields
FreshRSS: `id: feed/<id>`, `title`, `categories:[{id:"user/-/label/<cat>",label}]` (exactly one), `url`, `htmlUrl`, `iconUrl`, `frss:priority`; `sortid` and `firstitemmsec` deliberately commented out. Miniflux: `id`, `title`, `categories:[{id:"user/<uid>/label/<cat>",label,type:"folder"}]`, `url`, `htmlUrl`, `iconUrl`. CommaFeed: same minus `type`; `categories` may be `[]`. BazQux: "Always contain `htmlUrl` not depending on favicons setting. `firstitemmsec` is always dummy `1234567890000` (it seems that no one use it)." Inoreader: `firstitemmsec` "articles with timestampUsec lower than this cannot be marked as unread". No server issue found where a client required `sortid`/`firstitemmsec`.

---

## 4. Client quirk catalog (with sources)

**Reeder (4/5/Classic, closed source)**
- Requires `itemRefs[].id` as JSON strings — integer ids → "Type Mismatch", no articles. FreshRSS #2620 → PR #2621 (1.15.1). Also #2684.
- Sends literal `T=x` as the POST token (Reeder 4.0, 2019): FreshRSS #2513 log `Invalid POST token: x` → PR #2526 added `$token === 'x'` exception. By Reeder 4.2 (2020) logs show `GET /reader/api/0/token` before POSTs (#2956).
- Sends bare zero-padded 16-hex ids in `i=` (no `tag:` prefix): FreshRSS #2956 → PR #2957; Miniflux `item.go` comment; Miniflux #2960/PR #3325 (decimal-only parsing "was breaking Reeder"); davd.io.
- Dates/sorts by `timestampUsec`, ignores `published`: FreshRSS #2759 (disassembly), PR #2761 closed, PR #2773 hook.
- Sync pattern: `subscription/list?output=json`, `stream/items/ids?n=10000&xt=user/-/state/com.google/read&output=json&s=user/-/state/com.google/reading-list` (FreshRSS #2620 log), `stream/items/ids?...s=...starred`, then POST `stream/items/contents` in batches of ≤100 (#2956). Caps at 10,000 items per source (Miniflux #1350). UA `Reeder/4020.19.05 CFNetwork/1120 Darwin/19.0.0`, `Reeder/5010.01.03 ...`.
- Validates login with `GET user-info?output=json` right after `POST accounts/ClientLogin` (#4105, #3531); generic "GReader" account UI labels the field "Email" — FreshRSS username works (#4105).
- Adds feeds via `subscription/quickadd` then `subscription/edit` `ac=edit&a=user/-/label/...` (FreshRSS #3031 → PR #3051 quickadd changes).
- davd.io (2025 reimplementation): edit-tag response must be `text/plain` `OK` ("Reeder needs that"); token padded to 57 chars.
- FreshRSS `Google-Bad-Token` 401 on `user-info` makes Reeder re-prompt for login (#3531, caused by a missing `enabled` user config after upgrade).

**NetNewsWire (open source; verified in code + issues)**
- `stream/items/ids`: `n=1000&output=json`; all-items with `ot=<seconds>` (last fetch or 3 months back) on reading-list or `s=feed/<id>` (needed Miniflux PR #1402); unread = `s=reading-list&xt=read`; starred = `s=starred` (no xt). Follows `continuation` until absent, keeps paging even on empty pages while a continuation is present.
- After the `ot` fetch it locally marks every returned id as read then re-downloads unread ids — servers ignoring `ot` produced read/unread toggling (NNW #3512; fixed by Miniflux 2.0.39 date filtering).
- `stream/items/contents`: POST body `T=<token>&output=json&i=tag:...&i=...`, chunks of 150; requires Miniflux-style `output=json` and `T` (it sends both plus the `Authorization` header).
- `edit-tag`: chunks of 1000, one `a=` or `r=` per POST; ids must be sendable (`Int(articleID) != nil`).
- Item ID encoding fixes: unpadded hex until 2026-08-02; high-bit overflow until 2026-09-01 (see §1.3). TT-RSS freshapi still has a `NetNewsWire` UA hack for the unpadded form; freshapi changelog "2024-09-18: Resolved several issues related to labels and syncing for NetNewsWire".
- Uses `published` only for dates; `author` shown from `author` (FreshRSS #3518 was actually Fever-API NNW at the time).
- Conditional GET (`If-None-Match`/`If-Modified-Since`) on `tag/list` and `subscription/list` since Aug 2026; a 304 with empty body is treated as "nothing changed".
- `tag/list?types=1` sent only for Inoreader variant. Login: `Email`/`Passwd` POST; decoding failures surface as "The data couldn't be read because it isn't in the correct format" (NNW #2765, FreshRSS 1.17 → fixed by 1.18).
- NNW #5428: SQLite "Expression tree is too large (maximum depth 1000)" blocked all status sends once >~1000 rows queued (fixed 7.1.4); Miniflux #4530 "Reading status is not synced" was this NNW bug.

**Unread 5.0 (Sept 2026, John Brayton; FreshRSS via GReader, Miniflux via its REST API ≥2.3.2)** — FreshRSS PR #9296 server log: `GET /api/greader.php` (root ping), `POST .../accounts/ClientLogin`, `subscription/list?output=json`, `tag/list?types=1&output=json`, `stream/items/ids?output=json&includeAllDirectStreamIds=false&n=100000&s=user/-/state/com.google/reading-list&ot=<s>` (no `xt` — pulls ~30 days of read history), `...&n=100000&s=...reading-list&xt=user/-/state/com.google/read`, `...&n=100000&s=...starred`; ~74 `POST stream/items/contents` (75 KB–1.8 MB each) for ~18k items; **no `c=` continuation observed, no unread-count/edit-tag/token in the initial log**; UA `Unread%20Dev/500062 CFNetwork/3896.200.31 Darwin/27.2.0`.

**FeedMe (Android, closed)** — sends empty `T` (FreshRSS `//FeedMe` exception; TT-RSS UA-gated exception); `GET stream/contents?output=json&n=100&xt=user/-/state/com.google/read&ot=0&s=user/-/state/com.google/reading-list` and `GET user-info` without `output=json` (Miniflux #2129: 500 `"output only as json supported"` then; `stream/contents` still unimplemented → `[]`); POSTs ClientLogin with credentials in the query string (FreshRSS #2233 log); broke when a reverse proxy lowercased `Authorization` (FreshRSS #2233 → PR #2235 `getallheaders()` fallback); FreshRSS #2197/#2959 were nginx/mod_rewrite not forwarding `Authorization`.

**Readrops (Android, open source)** — `stream/contents/user/-/state/com.google/reading-list?xt=read&xt=starred&n=2500&ot=<lastModified s>`; `stream/contents/.../starred?n=1000`; `stream/items/ids?xt=read&s=reading-list&n=2500` (unread), `xt=user/-/state/com.google/unread` (read ids — FreshRSS-only value; Miniflux 500), `s=starred&n=1000`; creates folders with `edit-tag` `a=user/-/label/<name>` and no `i`; ClientLogin as multipart form; edit-tag as url-encoded. Triggered FreshRSS #5363 (starred ids 500 in 1.22.0 → PR #5366) and FreshRSS #2566 (origin of Alkarex's sync recommendations).

**News+ / EasyRSS (reference clients per FreshRSS)** — News+ 7-request sync: `tag/list`, `subscription/list`, `stream/contents/.../reading-list?xt=read&ot=<s>&n=1000&r=n`, `stream/items/ids?s=reading-list&xt=read&n=10000&r=n`, starred contents (unread, with ot), starred contents (all), `stream/items/ids?s=starred`. FreshRSS keeps `client=newsplus` empty-result hack and the 500 kB content cap for News+. EasyRSS uses `timestampUsec` as the item timestamp.

**FocusReader** — labels containing `+` failed on FreshRSS; PR #7033 switched `urldecode`→`rawurldecode` ("Compatibility with FocusReader", release requiring PHP 8.1+).

**Fiery Feeds** — FreshRSS #2043 was a PHP session-dir permission error, not API; TT-RSS freshapi "2024-09-19: Updated authentication logic to support more clients like Fiery Feeds" (no detail); listed "Fully Functional" by freshapi.

**lire, News Explorer** — no server-side incompatibility found in FreshRSS/Miniflux/CommaFeed trackers; lire listed as compatible by FreshRSS docs and freshapi.

**Liferea / RSSGuard / Vienna / Capy Reader / Smart RSS / Fluent Reader Lite** — Liferea passes decimal ids through (Miniflux #2960); RSSGuard converts to long form and may send blank `T` (CommaFeed comment); Vienna wants the `LSID=null` line (FreshRSS comment); Capy Reader & Smart RSS timed out on FreshRSS 1.28.0 `stream/contents/reading-list` with huge unpaged responses (#8370; Alkarex: "clients [should] use a continuation token to split very large responses"); Fluent Reader Lite "supports Max 1500 unread articles" (freshapi README).

---

## 5. Explicit disagreements between servers
1. `timestampUsec`: crawl time (Google, FreshRSS, Inoreader, TT-RSS≈updated) vs published (Miniflux, CommaFeed).
2. `updated`: omitted (FreshRSS, TT-RSS) vs = published (CommaFeed) vs last status change (Miniflux).
3. `ot`/`nt` target: crawl id OR lastModified (FreshRSS); published_at (Miniflux); download time minus 180 s (BazQux); unsupported (CommaFeed).
4. `continuation`: opaque (Google/Inoreader) vs last-id (FreshRSS, BazQux, CommaFeed non-starred) vs offset (Miniflux, TT-RSS, CommaFeed starred).
5. `n` caps: none (FreshRSS), 10000 (Miniflux ids), 1000 (CommaFeed), 50000/1000 (BazQux), 10000/1000 (TOR/Google), 1000/100 (Inoreader).
6. `ts`: µs by id comparison (FreshRSS), length-sniffed (Miniflux), µs assumed (CommaFeed, TT-RSS), s-or-µs (Inoreader).
7. Bad-token header: `Google-Bad-Token` (FreshRSS, TT-RSS) vs `X-Reader-Google-Bad-Token` (Google, Miniflux, FeedHQ, BazQux).
8. ClientLogin failure: 403 `Error=BadAuthentication` (Google, CommaFeed, BazQux body) vs 401 text (FreshRSS, TT-RSS) vs 401 JSON (Miniflux).
9. `T` requirement: optional/`x`/blank (FreshRSS, CommaFeed, TT-RSS-for-FeedMe) vs mandatory on every POST incl. items/contents (Miniflux).
10. `stream/items/contents` method: POST only (FreshRSS via `$_POST['i']`, Miniflux) vs GET+POST (CommaFeed, Google, BazQux).
11. Bare 16-hex `i=` (Reeder): accepted by FreshRSS/Miniflux/TT-RSS; **rejected (skipped) by CommaFeed**.
12. `output=json` required: FreshRSS (501 on list endpoints, not on user-info/items-contents), Miniflux (400 on ids/items-contents/tag-list/subscription-list), CommaFeed (never).
13. Category prefix in item `categories`: `user/-/...` (FreshRSS, CommaFeed) vs `user/<uid>/...` (Miniflux, Google).
14. `unread-count`: full (FreshRSS, TT-RSS), partial with `max` 10000 (CommaFeed), absent (Miniflux).
15. `s=user/-/state/com.google/read`: supported (FreshRSS, Miniflux, TT-RSS) vs silently treated as reading-list (CommaFeed).

## 6. Implications for Kipple (derived)
Emit items[].id as `tag:google.com,2005:reader/item/%016x` of `uint64(id)`; emit itemRefs[].id and `continuation` as JSON strings; parse `i=` as: strip prefix → if 16 hex chars parse as uint64 and cast to int64 → else `ParseInt(v,10,64)` (accept negatives); keep SQLite rowids positive and <1e15 to dodge both heuristics. Emit `published`/`updated` as integers, `crawlTimeMsec`/`timestampUsec` as strings; make `timestampUsec` the crawl time (Reeder sorts on it; FreshRSS/Google semantics) while `published` carries the feed date (NNW). Return `summary`, `categories`, `origin`, top-level `id`+`updated`, `categories[].{id,label}` always. Accept `T` blank/`x`/any, accept `Authorization` on POST, accept `ot` in seconds, `ts` by digit-length (≥16 µs, 13 ms, else s), `n` up to at least 100000 (Unread) or cap with continuation; support `xt=read`, `xt=user/-/state/com.google/unread`, `s=starred` including read items, `stream/items/contents` via GET and POST with `output` optional, `stream/contents` (FeedMe/Readrops/News+), `unread-count` with `max`; return 401 + both `Google-Bad-Token` and `X-Reader-Google-Bad-Token`; ClientLogin failure 403 `Error=BadAuthentication` text/plain.

## Claims
- [high LB] Google's long-form item id is 'tag:google.com,2005:reader/item/' + unsigned base-16 zero-padded to 16 chars; short form is the signed base-10 value; e.g. fb115bd6d34a8e9f = -355401917359550817. (https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ItemId.wiki)
- [high LB] stream/items/ids itemRefs[].id is the signed base-10 (short) form; itemRefs may also carry timestampUsec (µs the item appeared in the stream) and directStreamIds; n max 10,000; ot/nt in seconds. (https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiStreamItemsIds.wiki)
- [high LB] FreshRSS emits itemRefs id as a decimal string ('' . $entryId) and items[].id as 'tag:google.com,2005:reader/item/' . dec2hex(id) with str_pad(dechex(...),16,'0',STR_PAD_LEFT). (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/p/api/greader.php)
- [high LB] FreshRSS parses i= with: if (!ctype_digit($e_id) || $e_id[0] === '0') hex2dec(basename($e_id)); otherwise decimal — so bare all-digit hex not starting with 0 is misparsed as decimal, and negative decimals become '0'. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/p/api/greader.php)
- [high LB] Miniflux parseItemID accepts prefixed hex (any width), bare 16-char hex, and decimal; test maps '12345','tag:...00000000148b9369','tag:...2f2','000000000000046f','tag:...272' to 12345,344691561,754,1135,626; code comment attributes unpadded prefixed hex to NetNewsWire, bare padded hex to Reeder, decimal to Liferea. (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/item.go)
- [high LB] Miniflux emits itemRefs id via strconv.FormatInt(entryID,10) as a string and items[].id via fmt.Sprintf('tag:google.com,2005:reader/item/%016x', id). (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go)
- [high LB] CommaFeed parseItemId handles 'tag:google.com...' via Long.parseUnsignedLong(hex,16) and otherwise Long.valueOf(raw); bare 16-hex without prefix (Reeder's form) throws and the id is skipped; items[].id uses String.format('%016x', id); itemRefs use String.valueOf(id). (https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/main/java/com/commafeed/frontend/resource/googlereader/GoogleReaderREST.java)
- [high] TT-RSS freshapi uses FreshRSS's id heuristic plus a User-Agent sniff: ids are parsed as hex if UA starts with 'NetNewsWire'; itemRefs ids are 'SELECT ref_id::varchar as id'. (https://raw.githubusercontent.com/eric-pierce/freshapi/master/api/freshapi.php)
- [high LB] NetNewsWire sends i=tag:google.com,2005:reader/item/<%.16llx> (zero-padded, two's complement) in both stream/items/contents and edit-tag, and decodes items[].id via UInt64(hex,16) then Int64(bitPattern:) to a decimal string; itemRefs ids must be decimal because articleIDIsSendable requires Int(articleID) != nil. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] NetNewsWire tests: '00058b10ce338909' -> '1560279178774793', 'ffffffffffffcdef' -> '-12817', and decimal re-encodes to the original hex; the high-bit fix landed 2026-09-01 and the padded-encoding fix 2026-08-02. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Tests/AccountTests/ReaderAPI/ReaderAPIEntryTests.swift)
- [high LB] Reeder requires itemRefs[].id to be JSON strings; integer ids caused a 'Type Mismatch' and no articles (FreshRSS 1.15.0 with MySQL native statements), fixed by forcing strings in PR #2621. (https://github.com/FreshRSS/FreshRSS/issues/2620)
- [high LB] Reeder sends bare zero-padded 16-hex ids without the tag prefix in stream/items/contents (Postgres error 'invalid input syntax for integer: "0005978fb9baf6b1"'), in batches of up to 100 per POST; fixed by FreshRSS PR #2957. (https://github.com/FreshRSS/FreshRSS/issues/2956)
- [high LB] Reeder 4.0 sent the literal POST token T=x; FreshRSS added an exception (PR #2526) and the code still accepts $token === 'x' //Reeder and '' //FeedMe. (https://github.com/FreshRSS/FreshRSS/issues/2513)
- [high LB] Reeder displays/sorts articles by timestampUsec and ignores published (found by disassembly); FreshRSS keeps timestampUsec = crawl time = entry id and refused to change (PR #2761 closed). (https://github.com/FreshRSS/FreshRSS/issues/2759)
- [high LB] FreshRSS toGReader emits crawlTimeMsec = substr(dateAdded µs,0,-3), timestampUsec = dateAdded µs string (//EasyRSS & Reeder), published = date(true) int, no 'updated', summary.content truncated to 500000 in compat mode, alternate[].type removed in compat mode. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/Entry.php)
- [high LB] Miniflux emits TimestampUsec = entry.Date.UnixMicro() (published), CrawlTimeMsec = entry.CreatedAt.UnixMilli(), Published = Date.Unix(), Updated = ChangedAt.Unix(); item categories use the user-specific prefix user/<id>/state/com.google/.... (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go)
- [high LB] CommaFeed emits published = updated = entry.published (s), crawlTimeMsec = inserted ms, timestampUsec = published ms*1000; unread-count max is a constant 10000; DEFAULT_ITEM_COUNT 20, MAX_ITEM_COUNT 1000; ot/nt are not read at all. (https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/main/java/com/commafeed/frontend/resource/googlereader/GoogleReaderREST.java)
- [high] FreshRSS ot filters on (id >= ot*1e6 OR lastModified >= ot) and nt on (id <= nt*1e6 AND lastModified <= nt); ot/nt parsed as (int) seconds. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/EntryDAO.php)
- [medium] Miniflux ot/nt are seconds applied to e.published_at > / < ; date filtering on item ID calls was added in 2.0.39, which resolved NetNewsWire's read-state toggling. (https://github.com/miniflux/v2/releases/tag/2.0.39)
- [high LB] FreshRSS continuation is the last entry id as a numeric string; the next request re-queries count+1 from that id and discards the first; emitted only when returned count >= n. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/p/api/greader.php)
- [high LB] Miniflux continuation is a numeric SQL offset encoded as a JSON string (json:"continuation,omitempty,string"), omitted when done; n is capped/defaulted to MaxEntryIDsLimit = 10000. (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/README.md)
- [high] CommaFeed continuation is the last entry id for reading-list/feed/label streams but an integer offset for the starred stream. (https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/main/java/com/commafeed/frontend/resource/googlereader/GoogleReaderREST.java)
- [high LB] mark-all-as-read ts: FreshRSS compares it to the µs entry id (id <= ?); Miniflux treats >=16 digits as µs else seconds; CommaFeed divides by 1_000_000; TT-RSS divides by 1000000; FeedHQ/BazQux document µs; Inoreader accepts s or µs; TheOldReader's example is 16 digits labelled 'nanoseconds'. (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go)
- [high] Google unread-count returned "max":1000 and newestItemTimestampUsec as a µs string; Google stream/contents continuation was an opaque string like CLbwxoSAsZsC and crawlTimeMsec a string. (https://web.archive.org/web/20210126115837/https://blog.martindoms.com/2009/10/16/using-the-google-reader-api-part-2)
- [high] The '57 characters' token length originates from the pyrfeed wiki ('This url will return a string containing 57 chars. It's the token.'); FreshRSS pads sha1 with 'Z' to 57 and TT-RSS truncates sha256 to 57; Google's own ActionToken is 30-minute and a bad token gives 401 + X-Reader-Google-Bad-Token: true. (https://web.archive.org/web/2013id_/http://code.google.com/p/pyrfeed/wiki/GoogleReaderAPI)
- [high LB] Miniflux requires a valid T on every POST (including stream/items/contents), ignores the Authorization header on POST, requires output=json on stream/items/ids, stream/items/contents, tag/list, subscription/list, and returns [] with 200 for unimplemented endpoints such as stream/contents and unread-count. (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/README.md)
- [high LB] FreshRSS stream/items/contents is reached only via POST with isset($_POST['i']); i/a/r are parsed from the raw php://input body split on '&'; unauthorized responses are 401 text/plain 'Unauthorized!' with header 'Google-Bad-Token: true' (not X-Reader-...). (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/p/api/greader.php)
- [high] CommaFeed returns HTTP 403 with body 'Error=BadAuthentication\n' on ClientLogin failure (test asserts SC_FORBIDDEN); Google documented 403 on failure; FreshRSS and TT-RSS return 401; Miniflux returns 401 JSON {"error_message":"access unauthorized"}. (https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/test/java/com/commafeed/integration/rest/GoogleReaderIT.java)
- [high LB] NetNewsWire's Codable models require itemRefs.id and continuation to be strings, items to be an array (not null), top-level id (String) and updated (Int), and per item non-optional summary, categories, origin; subscription categories need both id and label. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIEntry.swift)
- [high LB] NetNewsWire requests stream/items/ids with n=1000&output=json, ot=<seconds> for all-items and per-feed (s=feed/<id>), xt=user/-/state/com.google/read for unread, s=starred for starred; fetches contents in chunks of 150 and sends edit-tag in chunks of 1000 with a single a= or r=. (https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift)
- [medium LB] Unread 5.0 requests stream/items/ids with n=100000&includeAllDirectStreamIds=false for reading-list with ot (no xt), reading-list with xt=read, and starred; tag/list?types=1; ~74 POST stream/items/contents for ~18k items; no continuation, edit-tag or unread-count observed in the initial sync log. (https://github.com/FreshRSS/FreshRSS/pull/9296)
- [high] FeedMe sends an empty T token, GETs stream/contents?output=json&n=100&xt=...read&ot=0&s=...reading-list and user-info without output=json; on Miniflux these returned 500 'output only as json supported' and [] respectively. (https://github.com/miniflux/v2/issues/2129)
- [high] Readrops uses stream/contents/.../reading-list?xt=read&xt=starred&n=2500&ot=<s>, stream/items/ids with xt=user/-/state/com.google/unread to obtain read ids, and creates folders via edit-tag with a=user/-/label/<name> and no i. (https://raw.githubusercontent.com/readrops/Readrops/develop/api/src/main/java/com/readrops/api/services/greader/GReaderDataSource.kt)
- [high] BazQux: ids default n=20 max 50000, stream/contents n=1000 max, items/contents 1000 per call, edit-tag 10000 items, ot is download time in seconds minus 180 s slack, c is an item id, firstitemmsec is dummy 1234567890000, ids endpoint returns short form and contents long form. (https://raw.githubusercontent.com/bazqux/bazqux-api/master/README.md)
- [medium] Inoreader documents stream/contents n max 100 and item-ids n max 1000, ot in seconds or microseconds, opaque continuation whose absence means end of stream, and prefers timestampUsec (crawl time) over crawlTimeMsec. (https://www.inoreader.com/developers/stream-contents)
- [high] FreshRSS PR #7033 fixed labels/categories containing '+' by switching urldecode to rawurldecode, for FocusReader compatibility. (https://github.com/FreshRSS/FreshRSS/pull/7033)
- [medium] Feedbin and Feedly do not implement the Google Reader API; Reeder Classic's GReader-family services are FreshRSS, BazQux, Inoreader and The Old Reader. (https://www.reederapp.com/classic/)

## Open questions
- Does current Reeder Classic still ever send T=x, or does it always fetch /token (2019 logs show T=x, 2020 logs show GET /token before POSTs; Miniflux requires a valid T and lists Reeder as compatible)? Closed source; only inferable from server logs.
- Does Reeder follow `continuation` on stream/items/ids, or is its 10,000-item ceiling purely its own cap (Miniflux #1350 says Reeder truncates to 10,000 per source)?
- Does Unread 5.0 follow `continuation` at all? Its FreshRSS log shows n=100000 with no c= requests; behaviour when a server caps n and returns a continuation is unverified.
- Reeder's exact current batch size for POST stream/items/contents (100 in 2020 logs) and whether it sends output=json and T on that POST (it works against Miniflux, which requires both).
- BazQux ClientLogin failure HTTP status (body is Error=BadAuthentication; status not documented).
- Inoreader's stream/contents n max is documented as 100 while item-ids says 1000; possible documentation error.
- FreshRSS: `it=starred&xt=read` yields a zero state bitmask and appears to return unfiltered results (inferred from code, not executed).
- Miniflux: whether fmt.Sscanf("%016x", &int64) rejects top-bit hex (ffffffffffffcdef) as inferred; irrelevant for positive ids but untested.
- Fiery Feeds, lire, News Explorer: no primary-source evidence of GReader-specific server quirks was found beyond TT-RSS freshapi's undetailed 'authentication logic' note for Fiery Feeds.
- Whether NetNewsWire's conditional GET on tag/list and subscription/list (Aug 2026) misbehaves against servers that return 304 for unrelated reasons — code treats an empty 304 as 'skip syncing'.

## Sources
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/p/api/greader.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/Entry.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/app/Models/EntryDAO.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/lib/lib_rss.php
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/docs/en/developers/06_GoogleReader_API.md
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/CHANGELOG.md
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/item.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/item_test.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/response.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/stream.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/parameters.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/request_modifier.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/middleware.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/README.md
- https://raw.githubusercontent.com/miniflux/v2/main/internal/model/entry.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/storage/entry_query_builder.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/storage/entry.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/http/response/json.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/http/response/text.go
- https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/main/java/com/commafeed/frontend/resource/googlereader/GoogleReaderREST.java
- https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/main/java/com/commafeed/frontend/resource/googlereader/GoogleReaderModel.java
- https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/main/java/com/commafeed/frontend/resource/googlereader/GoogleReaderStreamId.java
- https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/main/java/com/commafeed/security/mechanism/GoogleReaderAuthenticationMechanism.java
- https://raw.githubusercontent.com/Athou/commafeed/master/commafeed-server/src/test/java/com/commafeed/integration/rest/GoogleReaderIT.java
- https://raw.githubusercontent.com/Athou/commafeed/master/CHANGELOG.md
- https://raw.githubusercontent.com/eric-pierce/freshapi/master/api/freshapi.php
- https://raw.githubusercontent.com/eric-pierce/freshapi/master/init.php
- https://github.com/eric-pierce/freshapi
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIEntry.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIUnreadEntry.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPISubscription.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPITag.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIVariant.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/URLRequest+ReaderAPI.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIAccountDelegate.swift
- https://raw.githubusercontent.com/Ranchero-Software/NetNewsWire/main/Modules/Account/Tests/AccountTests/ReaderAPI/ReaderAPIEntryTests.swift
- https://github.com/Ranchero-Software/NetNewsWire/commits/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPIEntry.swift
- https://github.com/Ranchero-Software/NetNewsWire/commits/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift
- https://raw.githubusercontent.com/readrops/Readrops/develop/api/src/main/java/com/readrops/api/services/greader/GReaderDataSource.kt
- https://raw.githubusercontent.com/readrops/Readrops/develop/api/src/main/java/com/readrops/api/services/greader/GReaderService.kt
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ItemId.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiStreamItemsIds.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiStreamContents.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiStreamItemsContents.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiEditTags.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiSubscriptionEdit.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ActionToken.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/StreamId.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/ApiCommonInputs.wiki
- https://raw.githubusercontent.com/mihaip/google-reader-api/master/wiki/Authentication.wiki
- https://raw.githubusercontent.com/bazqux/bazqux-api/master/README.md
- https://raw.githubusercontent.com/theoldreader/api/master/README.md
- https://www.inoreader.com/developers/stream-contents
- https://www.inoreader.com/developers/item-ids
- https://www.inoreader.com/developers/article-ids
- https://www.inoreader.com/developers/edit-tag
- https://www.inoreader.com/developers/mark-all-as-read
- https://feedhq.readthedocs.io/en/latest/api/terminology.html
- https://feedhq.readthedocs.io/en/latest/api/reference.html
- https://web.archive.org/web/2013id_/http://code.google.com/p/pyrfeed/wiki/GoogleReaderAPI
- https://web.archive.org/web/20210126115837/https://blog.martindoms.com/2009/10/16/using-the-google-reader-api-part-2
- https://web.archive.org/web/20200616071132/https://blog.martindoms.com/2010/01/20/using-the-google-reader-api-part-3
- https://web.archive.org/web/20130604091042/http://undoc.in/clientLogin.html
- https://raw.githubusercontent.com/miniflux/google-reader/main/README.md
- https://miniflux.app/docs/google_reader.html
- https://github.com/FreshRSS/FreshRSS/issues/2620
- https://github.com/FreshRSS/FreshRSS/issues/2684
- https://github.com/FreshRSS/FreshRSS/issues/2513
- https://github.com/FreshRSS/FreshRSS/issues/2956
- https://github.com/FreshRSS/FreshRSS/issues/2759
- https://github.com/FreshRSS/FreshRSS/pull/2761
- https://github.com/FreshRSS/FreshRSS/issues/2566
- https://github.com/FreshRSS/FreshRSS/issues/3031
- https://github.com/FreshRSS/FreshRSS/issues/3531
- https://github.com/FreshRSS/FreshRSS/issues/3606
- https://github.com/FreshRSS/FreshRSS/issues/4105
- https://github.com/FreshRSS/FreshRSS/issues/5363
- https://github.com/FreshRSS/FreshRSS/issues/7370
- https://github.com/FreshRSS/FreshRSS/issues/8370
- https://github.com/FreshRSS/FreshRSS/issues/3518
- https://github.com/FreshRSS/FreshRSS/issues/2233
- https://github.com/FreshRSS/FreshRSS/issues/2197
- https://github.com/FreshRSS/FreshRSS/issues/2959
- https://github.com/FreshRSS/FreshRSS/issues/2043
- https://github.com/FreshRSS/FreshRSS/pull/7033
- https://github.com/FreshRSS/FreshRSS/pull/9296
- https://github.com/miniflux/v2/issues/2960
- https://github.com/miniflux/v2/pull/3325
- https://github.com/miniflux/v2/commit/3eb3ac06b66f2b0e7cef085831cd6aaeb8ddc9c8
- https://github.com/miniflux/v2/issues/2129
- https://github.com/miniflux/v2/issues/1350
- https://github.com/miniflux/v2/issues/4530
- https://github.com/miniflux/v2/issues/3165
- https://github.com/miniflux/v2/pull/2670
- https://github.com/miniflux/v2/pull/1402
- https://github.com/miniflux/v2/releases/tag/2.0.39
- https://github.com/Ranchero-Software/NetNewsWire/issues/3512
- https://github.com/Ranchero-Software/NetNewsWire/issues/2765
- https://github.com/Ranchero-Software/NetNewsWire/issues/5428
- https://www.davd.io/posts/2025-02-05-reimplementing-google-reader-api-in-2025/
- https://www.goldenhillsoftware.com/2026/09/unread-50/
- https://www.reederapp.com/classic/
