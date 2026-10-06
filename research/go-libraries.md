# go-libraries

# Kipple Go library selection - research findings (2026-09-24)

Toolchain baseline: `go.dev/dl/?mode=json` lists **go1.27.1** as current stable; Go 1.27 shipped August 2026 (release notes). Nothing in Go 1.27 notes changes `net/http` routing, `embed`, `io/fs` or `database/sql` in ways that affect the choices below; the 1.27 net/http changes are HTTP/2 priority, body auto-drain on close, `Server.MaxHeaderValueCount`, and ALPN on user-provided conns.

Every version/date below is from `proxy.golang.org/<module>/@latest` (queried 2026-09-24) unless stated; repo metadata from the GitHub API.

---

## 1. Feed parsing - `github.com/mmcdole/gofeed` v1.4.2

- **Version/date:** v1.4.2, 2026-08-20. Prior releases v1.4.1 (2026-08-10), v1.4.0 (2026-07-11), before that v1.3.0 (2024-03-01). Repo pushed 2026-09-14, 18 open issues, not archived. **Maintenance: active again since July 2026** after a 2-year gap.
- **License:** MIT. **CGO:** none.
- **go.mod:** `go 1.25.0`; deps `github.com/mmcdole/goxpp/v2 v2.0.0`, `golang.org/x/net v0.58.0`, `golang.org/x/text` (indirect), `testify` (tests). v1.4.0 removed `jsoniter` (now `encoding/json`) and `goquery`/`cascadia` (now direct `x/net/html` traversal). Dependency footprint is tiny.
- **Formats (README):** RSS 0.90-2.0, Atom 0.3/1.0, JSON Feed 1.0/1.1.
- **Universal model (feed.go, verbatim fields):**
  - `Feed{Title, Description, Link, FeedLink, Links []string, Updated, UpdatedParsed *time.Time, Published, PublishedParsed *time.Time, Author *Person (deprecated), Authors []*Person, Language, Image *Image, Copyright, Generator, Categories []string, DublinCoreExt, ITunesExt, Extensions ext.Extensions, Custom map[string]string, Items []*Item, FeedType, FeedVersion}` plus unexported `originalFeed` (so positional `Feed{...}` literals no longer compile).
  - `Item{Title, Description, Content, Link, Links []string, Updated, UpdatedParsed, Published, PublishedParsed, Author, Authors, GUID string, Image *Image, Categories []string, Enclosures []*Enclosure, DublinCoreExt, ITunesExt, Extensions, Custom}`
  - `Person{Name, Email, URL}`, `Image{URL, Title}`, `Enclosure{URL, Length string, Type}`.
- **Extensions:** `type Extensions map[string]map[string][]Extension` keyed by namespace prefix then element name; `Extension{Name, Value, Attrs map[string]string, Children map[string][]Extension}`. Built-in typed structs only for Dublin Core and iTunes. **`media:` (Media RSS) is only available through `Item.Extensions["media"]`** - there is no typed struct. `content:encoded` is mapped to `rss.Item.Content` → `Item.Content` (v1.4.1 notes "preserves compatibility with commonly seen content:encoded namespace variants").
- **Field precedence (translator.go, verified):**
  - RSS `Item.GUID = rssItem.GUID.Value` where `rss.GUID{Value, IsPermalink string}`; v1.4.0 "Correct RSS guid isPermaLink handling". Atom `GUID = entry.ID`; JSON `GUID = id`.
  - Atom `Item.Link` = first `<link rel="alternate">` (`firstLinkWithRel("alternate", ...)`); `Item.Links` collects rel `""`, `alternate`, `self`; enclosures from `rel="enclosure"` links; `Published` falls back to `Updated` when absent.
  - JSON: `Content = content_html || content_text`; `Image = image || banner_image`; attachments → Enclosures with `Length = size_in_bytes`.
  - `translateItemImage` (RSS): `itunes:image` → `media:content` whose `type` or `medium` attr contains "image" → first enclosure with `image/` type → first `<img>` in `Content` → first `<img>` in `Description`. The HTML scan can be disabled with `DefaultRSSTranslator.DisableContentImageScan = true` (v1.4.0).
  - RSS `rss.Item` keeps both `Enclosure *Enclosure` and `Enclosures []*Enclosure`; universal `Item.Enclosures` gets all.
- **Dates:** `shared.ParseDate` with a large layout table (~199 quoted layouts in dateparser.go) plus named-zone handling; v1.4.0 fixed named timezone offsets and added layouts. Non-parseable dates leave `*Parsed == nil` - Kipple must fall back to fetch time.
- **Charset handling (internal/shared/charsetconv.go, verbatim):**
  ```go
  func NewXMLParser(r io.Reader) *xpp.Parser {
      d := xml.NewDecoder(r)
      d.Strict = false
      d.CharsetReader = NewReaderLabel   // wraps golang.org/x/net/html/charset.NewReaderLabel
      return xpp.New(d)
  }
  ```
  So the encoding comes **only from the XML declaration's `encoding=` label**; gofeed never looks at HTTP `Content-Type`. A `NewControlCharFilterReader` strips illegal C0 control bytes before parsing. `Strict=false` tolerates unescaped entities etc.
- **Parser options (parser.go):** `Parser{AtomTranslator, RSSTranslator, JSONTranslator, UserAgent, AuthConfig *Auth, Client *http.Client, MaxByteSize int64, KeepOriginalFeed bool}`. `ParseURL` applies a 30 s default timeout; `ParseURLWithContext(url, ctx)`; `Parse(io.Reader)`; `ParseString`. `MaxByteSize` returns `ErrResponseTooLarge` rather than truncating. Feed type detection peeks only the first 4096 bytes (`detectionPeekSize`) - "A feed whose root element starts beyond this window is not detected" (v1.4.2 fixed JSON feeds larger than the window). `ErrFeedTypeNotDetected`, `HTTPError{StatusCode, Status}`.
- **Gotchas for Kipple:**
  1. `ParseURL` sends only `User-Agent` (+ optional Basic auth). No ETag/If-Modified-Since, no gzip control, no redirect policy. **Do your own HTTP and call `Parse(body)`.**
  2. Feeds whose declared encoding lies: gofeed will decode per the label. Pre-decode yourself (see §9) and hand gofeed UTF-8 bytes.
  3. Sharing one `*Parser` across goroutines is now race-free (v1.4.0 #278) - default translators/client are shared package-level singletons.
  4. Atom `<link rel="alternate">` missing → `Item.Link == ""`; check `Links[0]`.
- **Alternatives:** `github.com/go-syndication/feed` v0.1.1 (2026-07-27, BSD-3, stdlib-only, `go 1.26.4`) - minimal model (`Entry{ID, Title, Author, Summary, Content, Link, Published, Media}`), no extensions, no RSS 1.0/Atom 0.3, too young. Not a replacement. gofeed is the pick.

---

## 2. SQLite drivers

### Pragmas (sqlite.org/pragma.html, verbatim excerpts)
- `journal_mode`: "The WAL journaling mode is persistent; after being set it stays in effect across multiple database connections and after closing and reopening the database."
- `synchronous=NORMAL`: "WAL mode is safe from corruption with synchronous=NORMAL ... WAL mode is always consistent with synchronous=NORMAL, but WAL mode does lose durability. A transaction committed in WAL mode with synchronous=NORMAL might roll back following a power loss or system crash." FULL "is atomic, consistent, isolated, and durable (ACID) in WAL mode".
- `busy_timeout=ms`: per-connection busy handler; "Each database connection can only have a single busy handler."
- `foreign_keys`: "the default setting for foreign key enforcement is OFF ... applications should set the foreign key enforcement flag as required by the application and not depend on the default setting." Must be set per connection, and "is a no-op within a transaction".
- `user_version`: "the user-version integer at offset 60 in the database header ... SQLite makes no use of the user-version itself."
- `wal_autocheckpoint`: default 1000 pages, PASSIVE. WAL doc: "there can only be one writer at a time"; readers don't block writers; checkpoint starvation if a reader is always active; WAL "does not work over a network filesystem" (shared-memory wal-index) - irrelevant for a named Docker volume on local disk, but do not put the DB on NFS/SMB.
- `lang_transaction.html`: "If the first statement after BEGIN DEFERRED is a SELECT, then a read transaction is started. Subsequent write statements will upgrade the transaction to a write transaction if possible, or return SQLITE_BUSY." → **busy_timeout does not save a DEFERRED read→write upgrade**; open write transactions with `BEGIN IMMEDIATE` (`_txlock=immediate` in both pure-Go drivers).

Recommended DSN pragmas: `busy_timeout=5000` (first), `journal_mode=WAL`, `synchronous=NORMAL`, `foreign_keys=ON`, optionally `temp_store=MEMORY`, `cache_size=-8000` (8 MB) - the last two are conventional, not verified here.

### `modernc.org/sqlite` v1.59.0 (2026-09-15) - **recommended**
- Canonical repo gitlab.com/cznic/sqlite (GitHub is a mirror). CHANGELOG.md already lists a v1.59.1 entry dated 2026-09-15 (vfs.FS.Close hardening, 32-bit handle wrap fix, pcache contract panics) but the module proxy's `@latest` is v1.59.0 - check again at pin time.
- **License:** BSD-3-Clause; SQLite itself public domain; bundled `sqlite-vec` MIT. Ships SBOMs and `LICENSE-3RD-PARTY.md`.
- **CGO:** none ("CGo-free port"). **SQLite 3.53.4** on linux/amd64 and linux/arm64 (doc.go table).
- **go.mod:** `go 1.25.0`; requires `modernc.org/libc v1.75.7`, `modernc.org/mathutil v1.7.1`, `modernc.org/fileutil v1.4.0`, `golang.org/x/sys v0.47.0`, and oddly `github.com/google/pprof` (direct). doc.go: "When you import this package you should use in your go.mod file the exact same version of modernc.org/libc as seen in the go.mod file of this repository" (**fragile libc pairing**; retract history shows several broken tags: v1.33.0, v1.34.3, v1.42.0).
- **FTS5: compiled in.** modernc.org/libsqlite3 `generator.go` passes `-DSQLITE_ENABLE_FTS5`, `-DSQLITE_ENABLE_JSON1`, `-DSQLITE_ENABLE_RTREE`, `-DSQLITE_ENABLE_MATH_FUNCTIONS`, `-DSQLITE_ENABLE_STAT4`, `-DSQLITE_ENABLE_SESSION`, `-DSQLITE_ENABLE_PREUPDATE_HOOK`, `-DSQLITE_ENABLE_UNLOCK_NOTIFY`, `-DSQLITE_THREADSAFE=1`, `-DSQLITE_DEFAULT_MEMSTATUS=0`. No import or registration step.
- **Driver name:** `"sqlite"` (`sql.Open("sqlite", dsn)`). **DSN parameters (sqlite.go, verified in code):** repeatable `_pragma=<pragma text>` (driver executes `"pragma " + v`, so `_pragma=busy_timeout(5000)` or `_pragma=journal_mode(WAL)`; `busy_timeout` entries are pushed first, the rest run in case-insensitive lexicographic order), mattn-compatible shorthands `_busy_timeout`/`_timeout`, `_journal_mode`/`_journal`, `_synchronous`/`_sync`, `_foreign_keys`/`_fk`, `_auto_vacuum`/`_vacuum`, `_query_only`, plus `_txlock=deferred|immediate|exclusive`, `_time_format`, `_time_integer_format` (unix/unix_milli/unix_micro/unix_nano), `_timezone`, `_inttotime`, `_texttotime`, `_error_rc`, `_defensive`. SQLite URI params (`mode=ro` etc.) pass through when using `file:` DSNs.
- **Performance (doc.go, measured Sept 2026, Go 1.27, libc v1.75.7):** CPU-bound queries 1.3×-2.0× slower than C SQLite; "I/O-bound work is dominated by the operating system either way"; scaling across 4 connections at least as good as C. cvilsmeier go-sqlite-bench (2026-03-23, go1.26.0, journal_mode=DELETE, synchronous=FULL): Simple insert 1M rows mattn 1480 ms / modernc 2419 / ncruces 2719; query 871 / 758 / 850. Real: insert 1586 / 1759 / 1469, query 104 / 130 / 129. Complex: insert 812 / 1554 / 1749, query 998 / 1068 / 1263. modernc.org/sqlite-bench TL;DR scorecard (go1.26.5, modernc v1.55.0, ncruces v0.35.2, mattn v1.14.49): mattn 112 pts, modernc 57, ncruces 39.
- **Memory / concurrency (doc.go):** "database/sql opens connections without limit by default. Each connection carries its own page cache and its own libc thread state ... Bound the pool with sql.DB.SetMaxOpenConns". Connection-scoped state (PRAGMAs set via Exec, ATTACH, temp tables) persists across pool borrowers - set pragmas in the DSN, not with `db.Exec`. Every connection opens with `SQLITE_OPEN_FULLMUTEX` but "two goroutines using one connection can corrupt memory" via `sql.Conn.Raw`. Optional OFD locks on Linux: `MODERNC_SQLITE_OFD_LOCK=1` or `sqlite.OFDLocking()` before first open (prevents an unrelated `os.File.Close` in-process from dropping POSIX locks - worth enabling).
- **Static build:** `CGO_ENABLED=0 go build` works, scratch/distroless-static fine. Binary size: not measured from a primary source in this research (estimate 10-20 MB added; verify in CI).
- **Compile cost:** the transpiled amalgamation is large; first build is slow. Use `RUN --mount=type=cache,target=/root/.cache/go-build --mount=type=cache,target=/go/pkg/mod` in the Dockerfile (inferred best practice).

### `github.com/ncruces/go-sqlite3` v0.35.6 (2026-09-23) - strong alternative
- **License:** MIT. `go 1.26.0`. **CGO:** none. Deps: `github.com/ncruces/go-sqlite3-wasm/v6 v6.3.35304` (version encodes SQLite 3.53.04 - matches release v0.35.3 "SQLite 3.53.4"), `ncruces/julianday`, `ncruces/sort`, `ncruces/wbt`, `x/sys v0.48.0`. **wazero is gone:** v0.32.0 "likely the last version of this package to depend on wazero"; v0.33.2 breaking change "removing this import from your code: `import _ "github.com/ncruces/go-sqlite3/embed"`"; v0.33.3 "one of the first versions of this package to use wasm2go" (Wasm translated to Go source ahead of time). README: "Go and x/sys are the only required dependencies."
- **FTS5 is NOT in the base package since v0.35.0 (2026-06-11):** "the FTS5 and R*Tree/Geopoly extensions are now compiled separately. This is a breaking change" done "to keep the code size small (and compile times relatively fast)". You must `import "github.com/ncruces/go-sqlite3/ext/fts5"` and call `fts5.Register(conn *sqlite3.Conn) error` on **every connection**, e.g. `driver.Open(dsn, func(c *sqlite3.Conn) error { return fts5.Register(c) })` (driver.Open takes up to two per-connection callbacks). v0.35.4 added custom FTS5 tokenizers (`RegisterCustom`, `API.CreateTokenizer`) and `PRAGMA mmap_size`.
- **Driver name:** `"sqlite3"`, DSN: filename or `file:` URI; `_pragma=busy_timeout(10000)` (repeatable), `_txlock=deferred|immediate|exclusive`, `_timefmt=auto|sqlite|rfc3339|<layout>`. "If no PRAGMAs are specified, a busy timeout of 1 minute is set." Order matters: "encryption keys, busy timeout and locking mode should be the first PRAGMAs set".
- **VFS/WAL (vfs/README.md):** pure-Go VFS; Linux uses OFD locks (needs Linux ≥ 3.15) and `mmap` shared memory for the WAL index - full WAL support on linux/amd64 and arm64 per the support matrix. `sqlite3_flock`/`sqlite3_dotlk` build tags exist for exotic platforms; "Concurrently accessing databases using incompatible VFSes will eventually corrupt data" (only matters if another process opens the same file with C SQLite - the `sqlite3` CLI on the host uses the standard unix VFS, which the default config is compatible with).
- **Memory:** README: "Because each database connection executes within a Wasm sandboxed environment, memory usage will be higher than alternatives." Discussion #361 notes a 4 GB per-connection linear-memory ceiling and (at the time) inability to mmap. v0.35.5 shipped "new memory allocator in ncruces/wasm2go#52".
- **Compile cost caveat:** discussion #361 reports compiling the wasm2go sources took "~40 seconds and 4GiB of RAM" on one machine. If Host-A is RAM-constrained, this is a Docker-build risk (unverified on Host-A).
- Bench: slightly behind modernc in both scorecards above (mixed on inserts).

### `github.com/mattn/go-sqlite3` v1.14.52 (2026-09-05)
- MIT, `go 1.21`, SQLite 3.53.4 bundled. **CGO required**: "you are required to set the environment variable `CGO_ENABLED=1` and have a `gcc` compiler present". FTS5 via build tag `sqlite_fts5` (`go build -tags "fts5"` also documented). Static build for scratch requires musl: Alpine `apk add --update gcc musl-dev`, then `-ldflags "-linkmode external -extldflags -static"`. Best raw performance (scorecard 112 vs 57/39) but breaks "Docker alone, scratch, no CGO" simplicity and cross-compilation. 149 open issues. Not recommended for Kipple.

### `zombiezen.com/go/sqlite` v1.4.2 (2025-05-23)
- ISC. No `database/sql` driver by design (crawshaw-style `Conn`/`Stmt`, `sqlitex` helpers, `sqlitemigration` pool using `PRAGMA user_version` + `application_id`). go.mod pins `modernc.org/sqlite v1.37.1` + `modernc.org/libc v1.65.7` (16 months stale; MVS will lift modernc if you also require v1.59.0 but the libc pairing rule then rests on you). Last release 16 months ago. Nice API, wrong maintenance cadence for a new project.

### Verdict
**modernc.org/sqlite v1.59.0** with `database/sql`: FTS5/JSON1 built in with no per-connection registration, better benchmark standing than ncruces, straightforward static build, and it is what goose/golang-migrate target. Pin `modernc.org/libc` to exactly v1.75.7. Runtime pattern: one `*sql.DB` for writes with `SetMaxOpenConns(1)` and `_txlock=immediate`, a second `*sql.DB` on the same file for reads with `SetMaxOpenConns(4)` (or a single pool of 4 and all write paths using `BEGIN IMMEDIATE`) - inferred standard practice, consistent with the "one writer at a time" WAL rule. Run `PRAGMA wal_checkpoint(TRUNCATE)` after the nightly trim and `PRAGMA optimize` periodically. ncruces is the fallback if modernc's libc pin ever bites; switching cost is the driver name, DSN spelling, and FTS5 registration.

### FTS5 schema notes (sqlite.org/fts5.html)
External-content table over `articles`: `CREATE VIRTUAL TABLE articles_fts USING fts5(title, content, content='articles', content_rowid='id', tokenize='unicode61 remove_diacritics 2');` with AFTER INSERT/DELETE/UPDATE triggers using the `INSERT INTO articles_fts(articles_fts, rowid, title, content) VALUES('delete', old.id, old.title, old.content)` form. Query `WHERE articles_fts MATCH ? ORDER BY rank`; `snippet(articles_fts, 1, '<mark>', '</mark>', '…', 24)`; `highlight()`. Trigram tokenizer (`tokenize="trigram"`) enables substring/LIKE matching but needs ≥3-char queries. Maintenance: `INSERT INTO articles_fts(articles_fts) VALUES('optimize')` after trims, `'rebuild'` after bulk imports. Index plain text (strip HTML with bluemonday `StrictPolicy()` before insert) so retention trims stay cheap.

---

## 3. Readability / full-text extraction

- **`github.com/go-shiori/go-readability` is ARCHIVED** (GitHub `archived: true`, last push 2025-12-05). README: "This package is deprecated in favor of codeberg.org/readeck/go-readability/v2"; go.mod carries `// Deprecated:`. It tracked Readability.js v0.5.0. Do not use.
- **`codeberg.org/readeck/go-readability/v2` v2.1.2 (2026-06-18)**, MIT, `go 1.23.0`. "compatible with Readability.js v0.6.0" (2025-03-03). Deps: `go-shiori/dom` (2023, shared by all forks), `itlightning/dateparse`, `x/net v0.41.0`, plus CLI-only `tint`, `isatty`, `pflag`. API (readability.go/article.go): `FromReader(io.Reader, *url.URL) (Article, error)`, `FromDocument(*html.Node, *url.URL)`, `FromURL(url string, timeout, ...RequestWith)`, `CheckDocument(*html.Node) bool`; `Article` methods `Title() Byline() Excerpt() SiteName() ImageURL() Favicon() Language() PublishedTime() ModifiedTime() RenderHTML(io.Writer) RenderText(io.Writer)`. `Parser` options: `MaxElemsToParse, NTopCandidates, CharThresholds, ClassesToPreserve, KeepClasses, TagsToScore, Logger *slog.Logger, DisableJSONLD, AllowedVideoRegex`. Relative URLs are resolved against the page URL you pass ("The base URL resolves relative links ... it is never fetched"). Lazy images: `fixLazyImages` handles `data-src`/`srcset`-style attributes and strips tiny base64 placeholder `src` (<133 B, non-SVG) when another attribute holds a real image URL; `unwrapNoscriptImages` promotes `<noscript><img>` fallbacks; `rxLazyImageSrcset`/`rxSrcsetURL` rewrite srcset. FORK.md: Medium `<figure>` image fix, 53.7 ms → 25.1 ms and 73.7 MB → 5.2 MB allocations on a large Wikipedia page.
- **`github.com/markusmobius/go-readabilityV2` v0.6.0 (2026-09-17)**, MIT, `go 1.26.0`/toolchain 1.27.1, pushed 2026-09-24. A library-only fork of readeck v2 at commit b18540d ("Everything outside the core extraction library has been removed: URL fetching, request modifiers, the CLI and HTTP server"), same `FromReader/FromDocument/NewParser/CheckDocument` API, "single-threaded ... give each engine its own parser". Deps: `go-shiori/dom`, `itlightning/dateparse`, `x/net v0.59.0` only. Benchmark (2026-09-23, 2,659 pages): F1 LegoNews 87.83 % / ScrapingHub 95.21 % / WCXB 78.48 %, 2.67 ms/page extraction (fastest of the three).
- **`github.com/markusmobius/go-trafilatura/v2` v2.2.2 (2026-09-21)**, Apache-2.0, `go 1.26.0`. Best accuracy (F1 90.88 / 96.16 / 78.49, 6.8 ms/page) but: heavy deps (`go-htmldate`, `go-py3langid` in-process language model, `go-dateparser`, `wasilibs/go-re2` which drags `tetratelabs/wazero v1.12.0` in as an indirect dep, `zerolog`, `etree`, `go-domdistiller`, `go-readabilityV2`); own README says "The returned HTML is not a security sanitizer" and (historical comparison) "doesn't really good at extracting images"; `Options.IncludeImages` defaults false. API: `Extract(r io.Reader, opts Options) (*ExtractResult, error)`, `ExtractDocument(*html.Node, Options)`; `Options{Config, OriginalURL *url.URL, InputEncoding, TargetLanguage, EnableFallback, FallbackCandidates, Focus, ExcludeComments, ExcludeTables, IncludeImages, IncludeLinks, BlacklistedAuthors, Deduplicate, HasEssentialMetadata, MaxTreeSize, EnableLog, HtmlDateMode, HtmlDateOptions, HtmlDateOverride, PruneSelector}`; `ExtractResult{ContentNode *html.Node, CommentsNode, ContentText, CommentsText, Metadata{Title, Author, URL, Hostname, Description, Sitename, Date, Categories, Tags, ID, Fingerprint, License, Language, Image, PageType}}`. Wrong fit for a magazine-style reader; keep as a future opt-in "alternate extractor".
- **`github.com/markusmobius/go-domdistiller` v1.0.0** (module 2024-09-26; GitHub release object created 2026-09-15 for the same tag), MIT, `go 1.20`, deps `go-shiori/dom`, `zerolog`, `gohtml`, `x/net`, `x/text`. Chromium DOM Distiller port, "Good at extracting images", zero errors on the benchmark, F1 86.74 / 92.74 / 74.40, 3.6 ms/page. Original upstream archived. Viable but no better than Readability for blog/news content.
- **Verdict:** `github.com/markusmobius/go-readabilityV2 v0.6.0` (fallback `codeberg.org/readeck/go-readability/v2 v2.1.2`, identical API, adds FromURL). Pipeline: fetch HTML with the SSRF-safe client (§6) → `charset.NewReader(body, contentType)` → `readability.FromReader(r, pageURL)` → `article.RenderHTML(&buf)` → bluemonday policy (§4) with `RewriteSrc` to the image proxy → store. `Article.ImageURL()` gives the lead image for cards; `CheckDocument` lets you skip pages that are not article-like.

---

## 4. HTML sanitization - `github.com/microcosm-cc/bluemonday` v1.0.27

- **Version:** v1.0.27 (2024-07-04); last push 2025-04-04; 35 open issues; go.mod retracts `[v1.0.0, v1.0.25]`. **License:** BSD-3. `go 1.19`. Deps `aymerick/douceur` + `gorilla/css` (CSS value sanitizer), `x/net v0.26.0`. Slow-moving but stable; it is the only serious Go HTML sanitizer.
- **UGCPolicy() (policies.go) allows:** standard attrs `id, title, dir, lang`; `AllowStandardURLs()` = `RequireParseableURLs(true)`, `AllowRelativeURLs(true)`, schemes `mailto http https`, `RequireNoFollowOnLinks(true)`; elements `article aside details(open) figure section summary h1-h6 hgroup blockquote(cite) br div hr p span wbr a(href) map/area abbr acronym cite code dfn em figcaption mark s samp strong sub sup var q(cite) time(datetime) b i pre small strike tt u bdi/bdo(dir) rp rt ruby del/ins(cite,datetime) meter progress`, `AllowLists()`, `AllowTables()`, `AllowImages()` (img: `align alt height width src`). Explicitly **not** permitted: `class`, `style`, `script`, and "audio canvas embed iframe object param source svg track video". `script`/`style` contents are skipped entirely (default skip-content list).
- **Feed policy tweaks (all verified API):**
  ```go
  p := bluemonday.UGCPolicy()
  p.AllowAttrs("srcset", "sizes", "loading", "decoding").OnElements("img")
  p.AllowElements("picture")
  p.AllowAttrs("srcset", "type", "media", "sizes").OnElements("source")
  p.AllowAttrs("src", "controls", "poster", "preload", "loop", "muted", "playsinline").OnElements("video", "audio")
  p.AllowAttrs("src", "type").OnElements("source")
  p.AllowAttrs("src").Matching(regexp.MustCompile(`^https://(www\.)?(youtube-nocookie|youtube)\.com/embed/[\w-]+`)).OnElements("iframe")
  p.AllowAttrs("allowfullscreen", "width", "height", "frameborder", "loading").OnElements("iframe")
  p.RequireSandboxOnIFrame(bluemonday.SandboxAllowScripts, bluemonday.SandboxAllowSameOrigin, bluemonday.SandboxAllowPopups)
  p.AddTargetBlankToFullyQualifiedLinks(true)
  p.RequireNoReferrerOnLinks(true)          // adds rel="noreferrer" (implies noopener per HTML spec)
  p.RewriteSrc(func(u *url.URL) { /* mutate u in place to point at /img/{sig}/{b64} */ })
  ```
  - `RewriteSrc(fn func(*url.URL))` (policy.go): "rewrite the src attribute ... (e.g. <img>, <script>, <iframe>) using the provided function"; it is invoked from sanitize.go only when the attribute was parsed as a URL (`RequireParseableURLs` is on via AllowStandardURLs). It covers `src`, **not `srcset`** - either drop `srcset` for feed content or rewrite it in a pre-pass with `x/net/html`.
  - `AllowURLSchemeWithCustomPolicy(scheme, func(*url.URL) bool)` is **global per scheme** (applies to every https URL on every element), so do not use it for iframe host allow-listing; use the `Matching(regexp)` on the iframe `src` attribute as above.
  - There is no explicit `noopener` code path; sanitize.go only injects `nofollow`, `noreferrer`, `target="_blank"`. `noreferrer` implies `noopener` in browsers (spec behavior, not from bluemonday docs).
  - Relative URLs: `AllowRelativeURLs(true)` keeps them; resolve them against the article/feed URL **before** sanitizing (readability already does this when given the base URL; gofeed resolves `xml:base` for RSS/Atom content since v1.4.0).
  - `AllowDataURIImages()` exists (gif/jpeg/png/webp) - leave off; route everything through the proxy instead.
- For FTS indexing use `bluemonday.StrictPolicy().Sanitize(html)` to get text.

---

## 5. OPML

- **`github.com/gilliek/go-opml` v1.0.0 (2014-06-07)**, BSD-3, last commit 2014-06-10, **no go.mod** (GOPATH-era, uses `ioutil`, `NewOPMLFromURL` does a bare `http.Get`). Dead. Its entire value is a 70-line struct set, which is the right shape to copy:
  ```go
  type OPML struct { XMLName xml.Name `xml:"opml"`; Version string `xml:"version,attr"`; Head Head `xml:"head"`; Body Body `xml:"body"` }
  type Head struct { Title string `xml:"title"`; DateCreated string `xml:"dateCreated,omitempty"`; ... }
  type Body struct { Outlines []Outline `xml:"outline"` }
  type Outline struct {
      Outlines []Outline `xml:"outline"`
      Text     string    `xml:"text,attr"`
      Type     string    `xml:"type,attr,omitempty"`
      XMLURL   string    `xml:"xmlUrl,attr,omitempty"`
      HTMLURL  string    `xml:"htmlUrl,attr,omitempty"`
      Title    string    `xml:"title,attr,omitempty"`
      Category, Language, Version, Description string ...
  }
  ```
  `encoding/xml` handles the recursive `Outlines` field natively; export with `xml.Header + xml.MarshalIndent(doc, "", "\t")`.
- **OPML 2.0 spec (opml.org/spec2.opml):** "<opml> is an XML element, with a single required attribute, version; a <head> element and a <body> element, both of which are required." "An <outline> is an XML element containing at least one required attribute, text ... A missing text attribute in any outline element is an error." Subscription lists: "Required attributes: type, text, xmlUrl. For outline elements whose type is rss, the text attribute should initially be the top-level title element in the feed being pointed to, however since it is user-editable, processors should not depend on it always containing the title of the feed. xmlUrl is the http address of the feed." "Optional attributes: description, htmlUrl, language, title, version. htmlUrl is the top-level link element."
- **Import rules to implement (inferred from spec + ecosystem practice):** treat any outline with a non-empty `xmlUrl` as a feed regardless of `type` (many exporters write `type="rss"` for Atom, or omit it); name = `text`, fall back to `title`; folder = outline without `xmlUrl` that has children; flatten nested folders to one level (Reader-API clients only model one level of labels); on export write both `text` and `title`, `type="rss"`, `xmlUrl`, `htmlUrl`. Case-insensitive attribute matching is not something encoding/xml does, so also accept `xmlurl` by post-processing `xml:",any,attr"` if you meet a sloppy exporter (NewsBlur's export uses the standard spelling - verify against `/home/user/newsblur-export.opml`).

---

## 6. Image proxy

### `willnorris.com/go/imageproxy` v0.13.0 (2025-06-06) - not recommended as a library
- Apache-2.0, `go 1.25.8`, pushed 2026-08-10, 62 open issues. Library entry: `func NewProxy(transport http.RoundTripper, cache Cache) *Proxy`; `Proxy` fields (imageproxy.go, verbatim names): `Client, Cache, AllowHosts, DenyHosts, Referrers, IncludeReferer, FollowRedirects, DefaultBaseURL, Logger, SignatureKeys [][]byte, ScaleUp, Timeout, Verbose, ContentTypes, UserAgent, PassRequestHeaders, PassResponseHeaders, MinimumCacheDuration, ForceCache`. URL form `/{options}/{remote_url}`, signature option `s{base64url(HMAC-SHA256(key, url))}` (`validSignature` accepts HMAC over `r.URL.String()` or over URL+options-in-fragment).
- **No SSRF protection at resolution time.** `allowed()` checks only `ValidUntil`, `Referrers`, `DenyHosts`, `AllowHosts`, `SignatureKeys`; `hostMatches` compares hostname strings, `*.suffix`, or CIDR **only when the URL host is an IP literal**. A hostname resolving to 10.x/127.x is not blocked. With signed URLs (which is Kipple's mode, since any feed host must be allowed), signed URLs for `http://192.0.2.192:32400/...` would be fetched.
- Root package imports `prometheus/client_golang` (+promhttp), `gregjones/httpcache`, `fcjr/aia-transport-go`, `disintegration/imaging`, `muesli/smartcrop`, `rwcarlsen/goexif`, `golang.org/x/image/{bmp,tiff,webp}`, `gifresize` - pure Go but a large tree for something Kipple does not need (no resizing required; the goal is privacy + mixed-content avoidance + caching). The AWS/GCS/Azure/Redis modules in go.mod live in cache sub-packages and are not linked unless imported.

### `github.com/doyensec/safeurl` v0.2.5 (2026-06-11)
- Apache-2.0, `go 1.24.0`, 116 stars, 1 open issue. go.mod requires `github.com/miekg/dns v1.1.66` but only `testing/servers.go` imports it (client.go/config.go/ip.go do not) - it will not be linked into Kipple.
- **Mechanism (client.go, verified):** `transport.DialContext = (&net.Dialer{Resolver: wc.resolver, Control: buildRunFunc(wc)}).DialContext`. The `Control` hook runs **after DNS resolution on the concrete `address`**, so it defeats DNS rebinding and hostname→private-IP tricks: rejects `tcp6` unless `IsIPv6Enabled` (default **false** - enable it), checks `AllowedPorts` (default `80, 443`), `AllowedIPs/AllowedIPsCIDR` allowlist, `BlockedIPs/BlockedIPsCIDR`, then a built-in `privateNetworks` list: `10/8, 172.16/12, 192.168/16, 127/8, 0/8, 169.254/16, 192.0.0/24, 192.0.2/24, 198.51.100/24, 203.0.113/24, 192.88.99/24, 198.18/15, 224/4, 240/4, 255.255.255[.]255/32, 100.64/10, ::/128, ::1/128, 100::/64, 2001::/23, 2001:2::/48, 2001:db8::/32, 2001::/32, fc00::/7, fe80::/10, ff00::/8, 2002::/16, 64:ff9b::/96, 64:ff9b:1::/48, 5f00::/16, 2001:10::/28, 2001:20::/28, 3fff::/20, 100:0:0:1::/64`. Scheme check defaults to `http, https`; credentials in URL blocked unless `AllowSendingCredentials`.
- API is a wrapper (`safeurl.Client(cfg) *WrappedClient` with `Get/Head/Post/PostForm/Do`), not an `*http.Client`; you can pass your own `*http.Transport` (panics if it sets `Dial`/`DialTLS`/`DialTLSContext`). `Config{Timeout, CheckRedirect, Jar, ...}`.
- **Recommendation:** copy the pattern rather than import: a `net.Dialer{Control: ...}` that parses the dialed IP with `netip.ParseAddr` and rejects `IsPrivate() || IsLoopback() || IsLinkLocalUnicast() || IsLinkLocalMulticast() || IsMulticast() || IsUnspecified()` plus the 100.64/10 (CGNAT) and NAT64/6to4 ranges above; ~40 lines, stdlib only, and the same transport serves feed fetching, readability fetching, favicon fetching and the image proxy. Redirect hops reuse the dialer, so each hop is re-checked; cap hops with `CheckRedirect` (≤5).

### Hand-rolled proxy design (recommended)
Route `GET /img/{sig}/{u}` where `u = base64url(originalURL)` and `sig = base64url(HMAC-SHA256(secret, originalURL))[:N]`; `hmac.Equal` compare; reject non-http(s); fetch with the safe client (`Timeout` 15 s, `User-Agent` set, no cookies, `Accept: image/*`); `io.LimitReader(resp.Body, maxBytes+1)` and 502 if exceeded; sniff the first 512 B with `http.DetectContentType` and allow-list `image/jpeg, image/png, image/gif, image/webp, image/avif` (treat `image/svg+xml` as opt-in and serve it with `Content-Security-Policy: sandbox` + `X-Content-Type-Options: nosniff` or just deny); pass through `ETag`/`Last-Modified` and honor `If-None-Match`; respond `Cache-Control: public, max-age=604800`; optional on-disk LRU under `/data/imgcache`. Bluemonday's `RewriteSrc` produces the proxied URL at sanitize time so stored HTML already points at the proxy.

---

## 7. Migrations

- **`github.com/pressly/goose/v3` v3.28.0 (2026-09-02)**, MIT, `go 1.26.0`, very active (11.5k stars). The library packages (`goose.go`, `provider.go`, `up.go`, `dialect.go`) import only stdlib, internal packages and `go.uber.org/multierr`; the driver zoo in go.mod (`clickhouse-go`, `pgx`, `go-mssqldb`, `ydb`, `libsql`, `modernc.org/sqlite v1.57.0`, `moby` ...) is for `cmd/goose` and tests and is **not linked** into an app that imports the root package - but it bloats `go.sum` and `go mod download`. Modern API: `goose.NewProvider(database.DialectSQLite3, db, embedFS, opts...)` (fsys may be `embed.FS` or `fs.Sub`), `p.Up(ctx)`, `p.Status`, `p.HasPending`, `p.GetDBVersion`; options `WithTableName, WithVerbose, WithSlog, WithAllowOutofOrder, WithDisableVersioning, WithGoMigrations, WithLocker, WithSessionLocker, WithExcludeNames/Versions, WithIsolateDDL`. Legacy API: `goose.SetBaseFS(embedMigrations); goose.SetDialect("sqlite3"); goose.Up(db, "migrations")` ("we pass "migrations" as directory argument in Up because embedding saves directory structure"). SQL files need `-- +goose Up` / `-- +goose Down` markers; state table `goose_db_version`.
- **`github.com/golang-migrate/migrate/v4` v4.20.1 (2026-09-09)**, MIT, `go 1.25.11`. go.mod has 40+ direct deps (AWS, GCS, Spanner, Mongo, Neo4j, Snowflake ...); the `database/sqlite` driver uses modernc (pinned at the antique `modernc.org/sqlite v1.18.1` in its go.mod; MVS will lift it to yours) and "will automatically wrap each migration in an implicit transaction by default" (`x-no-tx-wrap` to disable); `database/sqlite3` uses mattn (CGO). Source `source/iofs.New(fsys, path)`. State table `schema_migrations` with a `dirty` flag that needs manual repair after a failed migration. Heavy for a single-binary app.
- **`github.com/rubenv/sql-migrate` v1.8.1 (2025-11-20)**, MIT, `go 1.25.0`, built on `go-gorp/gorp/v3`; `EmbedFileSystemMigrationSource{FileSystem: dbMigrations, Root: "migrations"}`; `-- +migrate Up/Down` markers. go.mod lists `mattn/go-sqlite3` and Oracle drivers (CLI/tests). Middle ground, but gorp is a dependency you would otherwise never want.
- **Hand-rolled (recommended):** `//go:embed migrations/*.sql`, files `0001_init.sql ...`, read `PRAGMA user_version`, for each newer file run `BEGIN IMMEDIATE; <sql>; PRAGMA user_version = N; COMMIT` (SQLite DDL is transactional; zombiezen's `sqlitemigration` does exactly `"%s;\nPRAGMA user_version = %d;\n"` and also stamps `PRAGMA application_id` to refuse foreign databases - copy that). ~60 lines, zero deps, no down migrations (restore from the nightly backup instead). If the owner wants a tool later, goose's Provider API is the only one worth adopting.

---

## 8. HTTP routing - stdlib `net/http` is enough

- `ServeMux` doc (Go master `server.go`, verbatim): "In general, a pattern looks like `[METHOD ][HOST]/[PATH]`"; "A pattern with the method GET matches both GET and HEAD requests. Otherwise, the method must match exactly."; "A path can include wildcard segments of the form {NAME} or {NAME...}"; "Wildcards must be full path segments"; "A trailing slash in a path acts as an anonymous "..." wildcard."; "The special wildcard {$} matches only the end of the URL."; precedence: "the most specific pattern takes precedence ... If neither is more specific, then the patterns conflict" and `Handle`/`HandleFunc` **panic** on conflict at registration; trailing-slash redirect for subtree patterns unless the bare path is registered; request sanitizing collapses `.`/`..`/repeated slashes with a redirect; "Escaped path elements such as "%2e" for "." and "%2f" for "/" are preserved". Values via `r.PathValue("id")`. GODEBUG `httpmuxgo121=1` restores 1.21 behavior.
- For Kipple: `mux.HandleFunc("GET /api/feeds/{id}", ...)`, `"POST /reader/api/0/edit-tag"`, `"GET /reader/api/0/stream/contents/{stream...}"` (stream IDs contain slashes - the `...` wildcard handles `user/-/state/com.google/reading-list`), `"GET /img/{sig}/{u}"`, `"GET /assets/"` (subtree), and `"/"` catch-all for the SPA. Note Google Reader clients also hit `/accounts/ClientLogin` (POST) and `/reader/api/0/token`. 405 handling: when a path matches but the method does not, ServeMux replies 405 with an `Allow` header (Go 1.22 behavior; not quoted above - verify with a test). Middleware = `func(http.Handler) http.Handler` chains; write a 10-line `group` helper if you want prefix-scoped middleware.
- `github.com/go-chi/chi/v5` v5.3.2 (2026-08-20), MIT, `go 1.24`, zero deps - take it only if you want `chi.Router` groups and its `middleware` package; it is fully compatible with stdlib handlers. `github.com/labstack/echo/v5` v5.3.1 (2026-07-21; v5 is a new major line with API changes, deps `x/net`, `x/time`) - not needed, and the framework `Context` style fights the Reader API's plain form/JSON handlers.

---

## 9. Charset / encoding

- `golang.org/x/net` v0.59.0 (2026-09-08), `golang.org/x/text` v0.42.0 (2026-09-08), both BSD-3. `x/net/html/charset` exports `DetermineEncoding(content []byte, contentType string) (e encoding.Encoding, name string, certain bool)`, `Lookup(label string) (encoding.Encoding, string)`, `NewReader(r io.Reader, contentType string) (io.Reader, error)`, `NewReaderLabel(label string, input io.Reader) (io.Reader, error)` ("suitable for use as encoding/xml.Decoder's CharsetReader function").
- `DetermineEncoding` algorithm (charset.go, verified): first 1024 bytes only; BOM → `certain=true`; `Content-Type` `charset=` param → `certain=true`; `<meta>` prescan → `certain=false`; else UTF-8 sniff / fallback. It implements the WHATWG HTML algorithm and is the right tool for **HTML** (readability, autodiscovery, favicon pages).
- **Feeds that lie:** gofeed only honors the XML declaration label (see §1). Strategy: read the body into memory (you already cap it at `MaxByteSize`), then (1) if BOM → trust BOM; (2) else take the XML declaration's `encoding` if present, else HTTP `charset`, else assume UTF-8; (3) if the chosen encoding is UTF-8 but `utf8.Valid(body)` is false, re-try with the HTTP charset, then `windows-1252` (superset of ISO-8859-1, the usual liar); (4) decode with `charset.NewReaderLabel` to UTF-8 and **rewrite or strip the `encoding=` attribute in the XML declaration** before `gofeed.Parse`, otherwise gofeed will re-decode already-UTF-8 bytes as the declared charset. `encoding/xml` itself only accepts UTF-8 (and UTF-16 via BOM in recent versions) without a `CharsetReader`.
- No other library is needed; `x/text/encoding/htmlindex` is what `charset.Lookup` wraps.

---

## 10. Feed autodiscovery and favicons - roll your own (reference: Miniflux, Apache-2.0)

- No maintained standalone Go autodiscovery library exists; gofeed does not do it. Miniflux `internal/reader/subscription/finder.go` is the best reference implementation: single DOM walk over `link[type]` dispatching on `application/rss+xml`, `application/atom+xml`, `application/feed+json`, `application/json` (skipping hrefs containing `/wp-json/`), href resolved to absolute against the page URL (honoring `<base href>` and `<link rel="canonical">`), `title` attr as the label; then well-known fallbacks `atom.xml, feed.atom, feed.xml, feed/, index.rss, index.xml, rss.xml, rss/, rss/feed.xml` probed at the site root and the current directory **with redirects disabled** ("Some websites redirects unknown URLs to the home page"); plus YouTube (`https://www.youtube.com/feeds/videos.xml?channel_id=…` / `playlist_id=…`) and GitHub special cases. Implement with `x/net/html` tokenizer (~80 lines). Also accept a URL that is already a feed (sniff with `gofeed.DetectFeedType`).
- Favicons - Miniflux `internal/reader/icon/finder.go`: order is (1) the feed's own icon (`gofeed.Feed.Image.URL`, from Atom `<icon>`/`<logo>` or RSS `<image>`), (2) HTML at the site URL then the root: query `link[rel='icon' i][href], link[rel='shortcut icon' i][href], link[rel='icon shortcut' i][href], link[rel='apple-touch-icon'][href]`, resolve to absolute, accept `data:` URLs, (3) `/favicon.ico` at the root. Store bytes + MIME in SQLite; Miniflux only resizes `image/jpeg, image/png, image/gif, image/webp` (cap 4096 px) and minifies SVG - Go's stdlib has no ICO decoder, so keep `.ico` bytes as-is and serve them with their content type (browsers render them). Serve at `/api/feeds/{id}/icon` with `Cache-Control: public, max-age=86400` and an ETag. No Google s2 dependency.

---

## 11. Background scheduling - no library

- `github.com/robfig/cron/v3` v3.0.1 is from 2020-01-04 (repo last pushed 2024-07, 173 open issues). Unneeded: Kipple's schedule is "every 30 min, per-feed override, backoff, manual refresh", which is a due-time column, not cron syntax.
- Pattern: store `next_fetch_at` per feed; one scheduler goroutine with `time.NewTicker(1 * time.Minute)` selects feeds `WHERE next_fetch_at <= now AND NOT disabled ORDER BY next_fetch_at LIMIT n`, hands them to a bounded worker pool (`golang.org/x/sync/semaphore` or a buffered channel, 4-8 workers), each worker owns its HTTP fetch and then hands rows to the single DB writer (a channel-fed goroutine or the `SetMaxOpenConns(1)` writer pool). On failure set `next_fetch_at = now + min(30m * 2^failures, 24h)` with jitter. Manual refresh = send on a channel that the scheduler selects on. Shutdown: `ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)`; `srv.Shutdown(shutdownCtx)`; cancel the scheduler ctx and `wg.Wait()`; Docker's default stop grace is 10 s, so per-fetch HTTP timeouts must be ≤ ~8 s or be context-cancelled. Run `PRAGMA wal_checkpoint(TRUNCATE)` on shutdown. `golang.org/x/sync` v0.23.0 (2026-08-31) for `errgroup`/`semaphore` is the only helper worth adding.

---

## 12. Frontend embedding

- `//go:embed all:web/dist` (the `all:` prefix is required to include dot-prefixed files such as Vite's `.vite/manifest.json`; omit `all:` if you do not need it) → `sub, _ := fs.Sub(dist, "web/dist")`.
- Assets: `mux.Handle("GET /assets/", http.FileServerFS(sub))` with a wrapper that sets `Cache-Control: public, max-age=31536000, immutable`. Vite docs: imported assets "will get hashed file names" (e.g. `/assets/img.2d8efhg.png`), `build.outDir` defaults to `"dist"`, `build.assetsDir` to `"assets"`; files in `public/` are "copied to the root of the dist directory as-is" (not hashed) - do **not** mark those immutable (fonts should be imported via CSS `url()` so they land hashed under `/assets/`, or served with a shorter max-age).
- `index.html`: serve for `GET /` and for any non-API, non-asset path (SPA fallback) with `Cache-Control: no-cache` and an `ETag` (hash of the bytes at startup); use `http.ServeContent(w, r, "index.html", modTime, bytes.NewReader(index))` so `If-None-Match` works. `FileServerFS` "redirects any request ending in "/index.html" to the same path, without the final "index.html"" and `ServeFileFS` rejects `..` - fine. `setLastModified` skips the header when modtime is zero, and `embed.FS` files have zero modtime, so conditional requests on embedded files rely on ETag, which FileServer does not generate - hence the explicit ETag on index.html; hashed assets do not need one.
- **MIME gotcha (verified in Go master `mime/type.go`):** the built-in table has `.css .js .mjs .json .svg .wasm .avif .webp .png ...` but **no `.woff`, `.woff2`, `.ttf`, `.otf`, `.webmanifest`**; on Linux Go loads `/etc/mime.types`, which does not exist in scratch/distroless-static, so Kipple's 11 bundled font families would be served as `application/octet-stream`. Call `mime.AddExtensionType(".woff2", "font/woff2")`, `".woff" → "font/woff"`, `".ttf" → "font/ttf"`, `".webmanifest" → "application/manifest+json"` in `init()`.
- Dockerfile shape: `node:22-alpine` (`npm ci && npm run build`) → `golang:1.27-alpine` (`COPY --from=web /app/web/dist ./web/dist`, `CGO_ENABLED=0 GOFLAGS=-trimpath go build -ldflags="-s -w" ./cmd/kipple`, with `--mount=type=cache` for `/go/pkg/mod` and `/root/.cache/go-build`) → `gcr.io/distroless/static-debian12:nonroot` (has CA certs and `/etc/passwd`; add `import _ "time/tzdata"` so `America/New_York` resolves without `/usr/share/zoneinfo`). Scratch works too but then copy `ca-certificates.crt` yourself. Set `GOMEMLIMIT` (e.g. `GOMEMLIMIT=96MiB`) in compose to keep idle RSS under the 100 MB target.

---

## 13. Testing

- Stdlib covers it: `net/http/httptest.NewServer` to serve feed fixtures with controllable `ETag`/`304`/charset headers, `httptest.NewRecorder` + `mux.ServeHTTP` for the Reader API, `testing/fstest.MapFS` for embed tests, `t.TempDir()` for SQLite files, `go test -race ./...`. Golden files: `testdata/<name>.golden` with an `-update` flag (`flag.Bool("update", false, ...)` + `os.WriteFile`) for sanitized HTML and Reader-API JSON bodies. Record real client A / client B request sequences once (a logging middleware) and replay them as golden request/response pairs.
- `github.com/stretchr/testify` v1.12.1 (2026-08-17), MIT - fine for `require`, but it pulls `go-spew`, `go-difflib`, `objx`, `yaml.v3`. gofeed and every readability fork already use it, so it will be in `go.sum` regardless; adopting it costs nothing extra. `github.com/google/go-cmp` is the lighter alternative for struct diffs. Recommendation: stdlib + testify `require` only, no `mock`.

---

## Recommended set (pin these)

| Concern | Choice | Version | License | CGO |
|---|---|---|---|---|
| Toolchain | Go | 1.27.1 (`go 1.26` or `1.27` in go.mod; go-readabilityV2 needs ≥1.26) | BSD-3 | - |
| Feed parsing | `github.com/mmcdole/gofeed` | v1.4.2 | MIT | no |
| SQLite | `modernc.org/sqlite` (+ `modernc.org/libc` pinned to **v1.75.7**) | v1.59.0 | BSD-3 | no |
| Readability | `github.com/markusmobius/go-readabilityV2` (alt: `codeberg.org/readeck/go-readability/v2` v2.1.2) | v0.6.0 | MIT | no |
| Sanitizer | `github.com/microcosm-cc/bluemonday` | v1.0.27 | BSD-3 | no |
| HTML/charset | `golang.org/x/net` (`html`, `html/charset`) | v0.59.0 | BSD-3 | no |
| Encodings | `golang.org/x/text` | v0.42.0 | BSD-3 | no |
| Concurrency helpers | `golang.org/x/sync` (`errgroup`, `semaphore`) | v0.23.0 | BSD-3 | no |
| Tests | `github.com/stretchr/testify` (require only) | v1.12.1 | MIT | no |
| Routing, embed, OPML, migrations, scheduler, image proxy, SSRF dialer | stdlib (`net/http` ≥1.22 mux, `embed`, `encoding/xml`, `crypto/hmac`, `net/netip`, `time`, `os/signal`) | - | - | - |

Transitive you will see: `github.com/go-shiori/dom` (2023, unmaintained but tiny; all readability forks depend on it), `itlightning/dateparse`, `mmcdole/goxpp/v2`, `aymerick/douceur`, `gorilla/css`, `modernc.org/{libc,mathutil,memory,fileutil}`, `github.com/google/pprof` (modernc direct dep), `ncruces/go-strftime`, `remyoudompheng/bigfft`, `dustin/go-humanize`.

**Deliberately not used:** `go-shiori/go-readability` (archived), `go-trafilatura` (heavy, image-weak, drags wazero via go-re2), `imageproxy` (no resolution-time SSRF guard, prometheus in root package), `safeurl` (copy the 40-line dialer instead), `goose` (acceptable second choice), `golang-migrate` (dependency sprawl, dirty-flag ops), `sql-migrate` (gorp), `go-opml` (dead, no go.mod), `robfig/cron` (2020), `chi`/`echo` (stdlib suffices), `mattn/go-sqlite3` (CGO), `zombiezen` (stale pin, no database/sql), `ncruces/go-sqlite3` (viable fallback; FTS5 needs per-connection `fts5.Register`, heavier compile).

## Claims
- [high LB] gofeed latest release is v1.4.2 published 2026-08-20; v1.4.0 (2026-07-11) requires Go 1.25+ and replaced jsoniter/goquery with encoding/json and x/net/html. (https://github.com/mmcdole/gofeed/releases)
- [high LB] gofeed's XML parser only honors the XML declaration's encoding label (xml.Decoder.CharsetReader = charset.NewReaderLabel, Strict=false); it never consults the HTTP Content-Type charset. (https://raw.githubusercontent.com/mmcdole/gofeed/master/internal/shared/charsetconv.go)
- [high LB] gofeed universal Parser.Parse detects feed type from the first 4096 bytes; RSS/Atom root elements must begin within that window. (https://raw.githubusercontent.com/mmcdole/gofeed/master/parser.go)
- [high LB] gofeed Item.GUID is rss guid value / atom id / json id; Atom Item.Link is the first rel=alternate link; Item.Image for RSS is chosen itunes:image → media:content(image) → image/* enclosure → first <img> in content/description (disable via DefaultRSSTranslator.DisableContentImageScan). (https://raw.githubusercontent.com/mmcdole/gofeed/master/translator.go)
- [high] gofeed exposes Media RSS only via the generic Item.Extensions["media"] map; typed extension structs exist only for Dublin Core and iTunes. (https://raw.githubusercontent.com/mmcdole/gofeed/master/feed.go)
- [high LB] modernc.org/sqlite latest module version is v1.59.0 (2026-09-15), BSD-3-Clause, CGO-free, SQLite 3.53.4, go 1.25.0, requires modernc.org/libc v1.75.7 and must use the exact same libc version. (https://gitlab.com/cznic/sqlite/-/raw/master/doc.go)
- [high LB] modernc.org/sqlite is built with -DSQLITE_ENABLE_FTS5 (plus JSON1, RTREE, MATH_FUNCTIONS, STAT4, SESSION, THREADSAFE=1), so FTS5 is available without any registration step. (https://gitlab.com/cznic/libsqlite3/-/raw/master/generator.go)
- [high LB] modernc.org/sqlite driver name is "sqlite"; DSN supports repeatable _pragma=<pragma text>, shorthands _busy_timeout/_journal_mode/_synchronous/_foreign_keys/_auto_vacuum/_query_only, _txlock=deferred|immediate|exclusive, _time_format, _time_integer_format; busy_timeout pragmas are applied first. (https://gitlab.com/cznic/sqlite/-/raw/master/sqlite.go)
- [high LB] modernc.org/sqlite CPU-bound queries run 1.3x-2.0x slower than C SQLite (measured Sept 2026, Go 1.27); each connection carries its own page cache and libc thread state, so the pool must be bounded with SetMaxOpenConns; connection-scoped PRAGMA state persists across pool borrowers. (https://gitlab.com/cznic/sqlite/-/raw/master/doc.go)
- [high LB] ncruces/go-sqlite3 latest is v0.35.6 (2026-09-23), MIT, go 1.26.0, no longer depends on wazero (uses wasm2go since v0.33.x); only Go and x/sys are required deps. (https://raw.githubusercontent.com/ncruces/go-sqlite3/main/go.mod)
- [high LB] Since ncruces/go-sqlite3 v0.35.0 (2026-06-11) FTS5 is a separate extension: import github.com/ncruces/go-sqlite3/ext/fts5 and call fts5.Register(conn) on each connection (e.g. via driver.Open's per-connection callback). (https://raw.githubusercontent.com/ncruces/go-sqlite3/main/ext/fts5/fts5.go)
- [high LB] ncruces/go-sqlite3 database/sql driver name is "sqlite3"; supports _pragma, _txlock, _timefmt; sets a 1 minute busy timeout if no pragmas are given. (https://raw.githubusercontent.com/ncruces/go-sqlite3/main/driver/driver.go)
- [medium] ncruces/go-sqlite3 uses OFD locks (Linux >= 3.15) and mmap shared memory for WAL on Linux; README warns memory usage is higher because each connection runs in a Wasm sandbox; discussion #361 reports a 4 GB per-connection memory ceiling and a report of ~40 s / 4 GiB RAM to compile the wasm2go sources. (https://github.com/ncruces/go-sqlite3/discussions/361)
- [high] mattn/go-sqlite3 v1.14.52 (2026-09-05) requires CGO_ENABLED=1 and gcc; FTS5 via build tag sqlite_fts5; static scratch builds need musl and -ldflags "-linkmode external -extldflags -static". (https://raw.githubusercontent.com/mattn/go-sqlite3/master/README.md)
- [high] zombiezen.com/go/sqlite latest is v1.4.2 (2025-05-23), ISC, no database/sql driver, pins modernc.org/sqlite v1.37.1 and libc v1.65.7. (https://raw.githubusercontent.com/zombiezen/go-sqlite/main/go.mod)
- [high] Benchmarks: cvilsmeier go-sqlite-bench (2026-03-23) Simple insert mattn 1480 / modernc 2419 / ncruces 2719 ms; modernc.org/sqlite-bench scorecard mattn 112, modernc 57, ncruces 39 points. (https://raw.githubusercontent.com/cvilsmeier/go-sqlite-bench/master/README.md)
- [high LB] SQLite: WAL journal_mode is persistent in the file; synchronous=NORMAL in WAL is safe from corruption but may lose the last transactions on power loss; foreign_keys defaults OFF and must be set per connection; a DEFERRED transaction that started with a SELECT returns SQLITE_BUSY (not busy-handler retry) when it later tries to write, so write transactions should use BEGIN IMMEDIATE. (https://www.sqlite.org/lang_transaction.html)
- [high LB] FTS5 external-content syntax is CREATE VIRTUAL TABLE x USING fts5(cols..., content='t', content_rowid='id') with delete-form trigger INSERT INTO x(x, rowid, cols...) VALUES('delete', old.id, ...); unicode61 supports remove_diacritics 0/1/2; trigram tokenizer needs >=3 char queries; rank/bm25(), snippet(), highlight(), 'optimize' and 'rebuild' commands exist. (https://www.sqlite.org/fts5.html)
- [high LB] github.com/go-shiori/go-readability is archived on GitHub (last push 2025-12-05) and its README/go.mod deprecate it in favor of codeberg.org/readeck/go-readability/v2. (https://raw.githubusercontent.com/go-shiori/go-readability/master/README.md)
- [high LB] codeberg.org/readeck/go-readability/v2 v2.1.2 (2026-06-18), MIT, matches Readability.js 0.6.0; API FromReader(io.Reader, *url.URL) (Article, error), FromDocument, FromURL, CheckDocument; Article has Title/Byline/Excerpt/SiteName/ImageURL/Favicon/Language/PublishedTime/ModifiedTime/RenderHTML/RenderText; includes fixLazyImages and noscript image unwrapping. (https://codeberg.org/readeck/go-readability/raw/branch/v2/readability.go)
- [high LB] github.com/markusmobius/go-readabilityV2 v0.6.0 (2026-09-17), MIT, go 1.26, is a library-only fork of readeck v2 with the same FromReader/FromDocument API, deps only go-shiori/dom, itlightning/dateparse, x/net; 2026-09-23 benchmark F1 87.83/95.21/78.48 and 2.67 ms/page. (https://raw.githubusercontent.com/markusmobius/go-readabilityV2/main/README.md)
- [high] go-trafilatura v2 module path is github.com/markusmobius/go-trafilatura/v2 v2.2.2 (2026-09-21), Apache-2.0, go 1.26, with heavy deps (go-py3langid, go-htmldate, go-re2 pulling wazero indirectly); its README states the output is not a sanitizer and images are a weak point; IncludeImages defaults false. (https://raw.githubusercontent.com/markusmobius/go-trafilatura/main/go.mod)
- [high LB] bluemonday latest is v1.0.27 (2024-07-04), BSD-3, go 1.19, deps aymerick/douceur, gorilla/css, x/net; UGCPolicy allows img (align, alt, height, width, src) but not iframe/video/audio/source/svg/style/class. (https://raw.githubusercontent.com/microcosm-cc/bluemonday/main/policies.go)
- [high LB] bluemonday Policy.RewriteSrc(fn func(*url.URL)) rewrites parsed src attribute URLs in place (img/script/iframe); AllowURLSchemeWithCustomPolicy applies per scheme globally, not per element; RequireSandboxOnIFrame and AddTargetBlankToFullyQualifiedLinks/RequireNoReferrerOnLinks exist; there is no explicit noopener injection. (https://raw.githubusercontent.com/microcosm-cc/bluemonday/main/policy.go)
- [high] github.com/gilliek/go-opml v1.0.0 dates from 2014-06-07, has no go.mod, last commit 2014-06-10; it is a 70-line encoding/xml struct wrapper. (https://raw.githubusercontent.com/gilliek/go-opml/master/opml/opml.go)
- [high LB] OPML 2.0 spec: <opml> requires version, <head> and <body>; every <outline> must have a text attribute; subscription-list outlines require type, text, xmlUrl and optionally description, htmlUrl, language, title, version. (https://opml.org/spec2.opml)
- [high LB] willnorris/imageproxy v0.13.0 (2025-06-06), Apache-2.0: Proxy.allowed() checks only ValidUntil, Referrers, DenyHosts, AllowHosts and HMAC SignatureKeys; hostMatches compares hostnames/wildcards and CIDR only for IP-literal hosts; there is no post-DNS private-IP check. (https://raw.githubusercontent.com/willnorris/imageproxy/main/imageproxy.go)
- [high] imageproxy root package imports prometheus/client_golang, gregjones/httpcache, aia-transport-go, disintegration/imaging, muesli/smartcrop, goexif, x/image and gifresize. (https://raw.githubusercontent.com/willnorris/imageproxy/main/transform.go)
- [high LB] doyensec/safeurl v0.2.5 (2026-06-11), Apache-2.0, enforces IP policy in net.Dialer.Control after DNS resolution, blocks a built-in list of private/loopback/link-local/CGNAT/multicast/NAT64/6to4 ranges, defaults to ports 80/443 and schemes http/https, and disables IPv6 by default; miekg/dns is only imported by testing/servers.go. (https://raw.githubusercontent.com/doyensec/safeurl/main/client.go)
- [high] pressly/goose v3.28.0 (2026-09-02), MIT, go 1.26.0: library root package imports only stdlib, internal packages and go.uber.org/multierr; NewProvider(dialect, db, fsys, opts...) accepts embed.FS; legacy SetBaseFS/SetDialect("sqlite3")/Up API remains. (https://raw.githubusercontent.com/pressly/goose/main/provider.go)
- [high] golang-migrate v4.20.1 (2026-09-09) database/sqlite driver uses modernc.org/sqlite (go.mod pins v1.18.1) and wraps each migration in an implicit transaction; database/sqlite3 uses mattn; source/iofs.New(fsys, path) reads embedded migrations. (https://raw.githubusercontent.com/golang-migrate/migrate/master/database/sqlite/README.md)
- [high LB] Go 1.22+ ServeMux patterns are [METHOD ][HOST]/[PATH] with {name}, {name...}, {$}; GET also matches HEAD; most-specific pattern wins and conflicting registrations panic; trailing-slash subtree redirect and request sanitizing apply; GODEBUG httpmuxgo121=1 restores old behavior. (https://raw.githubusercontent.com/golang/go/master/src/net/http/server.go)
- [high LB] x/net/html/charset.DetermineEncoding inspects up to 1024 bytes: BOM and Content-Type charset yield certain=true, <meta> prescan yields certain=false, then UTF-8 sniffing; NewReaderLabel is suitable as xml.Decoder.CharsetReader. Latest x/net is v0.59.0 and x/text v0.42.0 (2026-09-08). (https://raw.githubusercontent.com/golang/net/master/html/charset/charset.go)
- [high] Miniflux feed discovery reads link[type] for application/rss+xml, application/atom+xml, application/feed+json, application/json (skipping /wp-json/), then probes well-known paths atom.xml, feed.atom, feed.xml, feed/, index.rss, index.xml, rss.xml, rss/, rss/feed.xml with redirects disabled; favicon discovery uses link[rel='icon' i], 'shortcut icon', 'icon shortcut', apple-touch-icon then /favicon.ico, and only resizes jpeg/png/gif/webp. (https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/subscription/finder.go)
- [high] robfig/cron latest tag is v3.0.1 from 2020-01-04 (repo last pushed 2024-07-08). (https://api.github.com/repos/robfig/cron/tags)
- [high LB] Go's built-in MIME table (mime/type.go builtinTypesLower) includes .css .js .mjs .json .svg .wasm .avif .webp but not .woff, .woff2, .ttf, .otf or .webmanifest; in a scratch/distroless image with no /etc/mime.types, http.FileServer will serve bundled fonts as application/octet-stream unless mime.AddExtensionType is called. (https://raw.githubusercontent.com/golang/go/master/src/mime/type.go)
- [high] net/http setLastModified omits the Last-Modified header when modtime is zero (as it is for embed.FS files), so conditional requests for embedded files need an explicit ETag; ServeContent handles If-None-Match/If-Modified-Since/Range. (https://raw.githubusercontent.com/golang/go/master/src/net/http/fs.go)
- [high] Vite hashes imported assets (e.g. /assets/img.2d8efhg.png), build.outDir defaults to dist and build.assetsDir to assets, files in public/ are copied as-is without hashing, and build.manifest writes .vite/manifest.json. (https://vite.dev/guide/assets)
- [high] Current stable Go is go1.27.1; Go 1.27 was released in August 2026 and its net/http changes are HTTP/2 client priority, Response.Body auto-drain on close, Server.MaxHeaderValueCount and ALPN on user-provided conns. (https://go.dev/doc/go1.27)
- [high] chi v5.3.2 (2026-08-20), MIT, go 1.24, has zero dependencies; echo v5.3.1 (2026-07-21) is a new major line (v5) requiring x/net and x/time; testify v1.12.1 (2026-08-17). (https://raw.githubusercontent.com/go-chi/chi/master/go.mod)
- [low] Binary-size figures for modernc vs ncruces were not obtained from a primary source; the 10-20 MB estimate for modernc is inferred and should be measured in CI. (https://gitlab.com/cznic/sqlite/-/raw/master/README.md)

## Open questions
- Actual binary size and idle RSS of a CGO_ENABLED=0 build with modernc.org/sqlite v1.59.0 vs ncruces v0.35.6 (+ext/fts5) - no primary-source numbers found; measure with `go build -ldflags='-s -w'` and a 10-minute idle run before committing to the <50 MB image / <100 MB RSS targets.
- Docker build RAM/time on Host-A for either pure-Go SQLite driver (discussion #361 reports ~40 s / 4 GiB for the wasm2go sources; modernc's transpiled amalgamation is similarly heavy). If Host-A is small, build the image on Host-B and push, or use a BuildKit cache mount.
- modernc.org/sqlite CHANGELOG lists v1.59.1 (2026-09-15) while proxy.golang.org @latest returned v1.59.0 - confirm which tag is published when pinning, and pin modernc.org/libc to the exact version in that tag's go.mod.
- Whether Go 1.22+ ServeMux returns 405 with an Allow header for method mismatches on a matched path (expected, but not quoted from docs here) - one httptest case settles it.
- gofeed's 4 KiB feed-type detection window: check the NewsBlur OPML's feeds for any XML feeds with very large leading comments/DOCTYPE that would return ErrFeedTypeNotDetected; fallback is to sniff with the rss/atom sub-parsers directly.
- Exact OPML attribute spelling and folder nesting in /home/user/newsblur-export.opml (e.g. whether NewsBlur writes both text and title, and type="rss" on folders) - the importer rules above are inferred from the spec and general practice.
- Whether client A / client B tolerate more than one folder level via the Reader API label model - affects whether nested OPML folders are flattened on import (inferred: flatten).
- srcset handling: bluemonday RewriteSrc covers src only; decide between stripping srcset for feed content or rewriting each candidate URL in a pre-pass so responsive images also go through the proxy.

## Sources
- https://proxy.golang.org/github.com/mmcdole/gofeed/@latest
- https://github.com/mmcdole/gofeed/releases
- https://raw.githubusercontent.com/mmcdole/gofeed/master/go.mod
- https://raw.githubusercontent.com/mmcdole/gofeed/master/feed.go
- https://raw.githubusercontent.com/mmcdole/gofeed/master/parser.go
- https://raw.githubusercontent.com/mmcdole/gofeed/master/detector.go
- https://raw.githubusercontent.com/mmcdole/gofeed/master/translator.go
- https://raw.githubusercontent.com/mmcdole/gofeed/master/internal/shared/charsetconv.go
- https://raw.githubusercontent.com/mmcdole/gofeed/master/internal/shared/xmlsanitizer.go
- https://raw.githubusercontent.com/mmcdole/gofeed/master/rss/feed.go
- https://raw.githubusercontent.com/mmcdole/gofeed/master/README.md
- https://gitlab.com/cznic/sqlite/-/raw/master/go.mod
- https://gitlab.com/cznic/sqlite/-/raw/master/doc.go
- https://gitlab.com/cznic/sqlite/-/raw/master/sqlite.go
- https://gitlab.com/cznic/sqlite/-/raw/master/README.md
- https://gitlab.com/cznic/sqlite/-/raw/master/CHANGELOG.md
- https://gitlab.com/cznic/libsqlite3/-/raw/master/generator.go
- https://pkg.go.dev/modernc.org/sqlite
- https://raw.githubusercontent.com/ncruces/go-sqlite3/main/go.mod
- https://raw.githubusercontent.com/ncruces/go-sqlite3/main/README.md
- https://raw.githubusercontent.com/ncruces/go-sqlite3/main/driver/driver.go
- https://raw.githubusercontent.com/ncruces/go-sqlite3/main/vfs/README.md
- https://raw.githubusercontent.com/ncruces/go-sqlite3/main/ext/README.md
- https://raw.githubusercontent.com/ncruces/go-sqlite3/main/ext/fts5/fts5.go
- https://github.com/ncruces/go-sqlite3/releases
- https://github.com/ncruces/go-sqlite3/releases/tag/v0.35.0
- https://github.com/ncruces/go-sqlite3/releases/tag/v0.35.5
- https://github.com/ncruces/go-sqlite3/releases?page=2
- https://github.com/ncruces/go-sqlite3/discussions/361
- https://github.com/ncruces/go-sqlite3/wiki/Support-matrix
- https://raw.githubusercontent.com/ncruces/go-sqlite3-wasm/main/README.md
- https://raw.githubusercontent.com/mattn/go-sqlite3/master/README.md
- https://raw.githubusercontent.com/mattn/go-sqlite3/master/sqlite3-binding.h
- https://raw.githubusercontent.com/zombiezen/go-sqlite/main/go.mod
- https://raw.githubusercontent.com/zombiezen/go-sqlite/main/README.md
- https://raw.githubusercontent.com/zombiezen/go-sqlite/main/sqlitemigration/sqlitemigration.go
- https://raw.githubusercontent.com/cvilsmeier/go-sqlite-bench/master/README.md
- https://pkg.go.dev/modernc.org/sqlite-bench
- https://www.sqlite.org/pragma.html
- https://www.sqlite.org/lang_transaction.html
- https://www.sqlite.org/wal.html
- https://www.sqlite.org/fts5.html
- https://raw.githubusercontent.com/go-shiori/go-readability/master/README.md
- https://raw.githubusercontent.com/go-shiori/go-readability/master/go.mod
- https://codeberg.org/readeck/go-readability/raw/branch/v2/go.mod
- https://codeberg.org/readeck/go-readability/raw/branch/v2/README.md
- https://codeberg.org/readeck/go-readability/raw/branch/v2/readability.go
- https://codeberg.org/readeck/go-readability/raw/branch/v2/article.go
- https://codeberg.org/readeck/go-readability/raw/branch/v2/parser.go
- https://codeberg.org/readeck/go-readability/raw/branch/v2/FORK.md
- https://raw.githubusercontent.com/markusmobius/go-readabilityV2/main/README.md
- https://raw.githubusercontent.com/markusmobius/go-readabilityV2/main/go.mod
- https://raw.githubusercontent.com/markusmobius/go-trafilatura/main/go.mod
- https://raw.githubusercontent.com/markusmobius/go-trafilatura/main/README.md
- https://pkg.go.dev/github.com/markusmobius/go-trafilatura/v2
- https://raw.githubusercontent.com/markusmobius/go-domdistiller/main/README.md
- https://raw.githubusercontent.com/markusmobius/go-domdistiller/main/go.mod
- https://raw.githubusercontent.com/microcosm-cc/bluemonday/main/go.mod
- https://raw.githubusercontent.com/microcosm-cc/bluemonday/main/policies.go
- https://raw.githubusercontent.com/microcosm-cc/bluemonday/main/policy.go
- https://raw.githubusercontent.com/microcosm-cc/bluemonday/main/helpers.go
- https://raw.githubusercontent.com/microcosm-cc/bluemonday/main/sanitize.go
- https://raw.githubusercontent.com/gilliek/go-opml/master/opml/opml.go
- https://opml.org/spec2.opml
- https://raw.githubusercontent.com/willnorris/imageproxy/main/go.mod
- https://raw.githubusercontent.com/willnorris/imageproxy/main/imageproxy.go
- https://raw.githubusercontent.com/willnorris/imageproxy/main/transform.go
- https://raw.githubusercontent.com/willnorris/imageproxy/main/README.md
- https://raw.githubusercontent.com/doyensec/safeurl/main/go.mod
- https://raw.githubusercontent.com/doyensec/safeurl/main/README.md
- https://raw.githubusercontent.com/doyensec/safeurl/main/client.go
- https://raw.githubusercontent.com/doyensec/safeurl/main/config.go
- https://raw.githubusercontent.com/doyensec/safeurl/main/ip.go
- https://raw.githubusercontent.com/pressly/goose/main/go.mod
- https://raw.githubusercontent.com/pressly/goose/main/README.md
- https://raw.githubusercontent.com/pressly/goose/main/provider.go
- https://raw.githubusercontent.com/pressly/goose/main/provider_options.go
- https://raw.githubusercontent.com/golang-migrate/migrate/master/go.mod
- https://raw.githubusercontent.com/golang-migrate/migrate/master/database/sqlite/README.md
- https://raw.githubusercontent.com/golang-migrate/migrate/master/database/sqlite3/sqlite3.go
- https://raw.githubusercontent.com/golang-migrate/migrate/master/source/iofs/iofs.go
- https://raw.githubusercontent.com/rubenv/sql-migrate/master/go.mod
- https://raw.githubusercontent.com/rubenv/sql-migrate/master/README.md
- https://raw.githubusercontent.com/go-chi/chi/master/go.mod
- https://raw.githubusercontent.com/labstack/echo/master/go.mod
- https://api.github.com/repos/labstack/echo/releases
- https://api.github.com/repos/robfig/cron/tags
- https://raw.githubusercontent.com/golang/go/master/src/net/http/server.go
- https://raw.githubusercontent.com/golang/go/master/src/net/http/fs.go
- https://raw.githubusercontent.com/golang/go/master/src/mime/type.go
- https://go.dev/blog/routing-enhancements
- https://go.dev/doc/go1.27
- https://go.dev/dl/?mode=json
- https://raw.githubusercontent.com/golang/net/master/html/charset/charset.go
- https://pkg.go.dev/golang.org/x/net/html/charset
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/subscription/finder.go
- https://raw.githubusercontent.com/miniflux/v2/main/internal/reader/icon/finder.go
- https://raw.githubusercontent.com/go-syndication/feed/main/README.md
- https://vite.dev/guide/assets
- https://vite.dev/config/build-options
- https://proxy.golang.org/golang.org/x/net/@latest
- https://proxy.golang.org/golang.org/x/text/@latest
- https://proxy.golang.org/github.com/stretchr/testify/@latest
