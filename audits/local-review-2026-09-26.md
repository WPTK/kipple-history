# Local deep review, 2026-09-26 (replaces the billed ultra reviews)

Eight read-only Opus agents audited `main` at `640fe2c` (v0.3.0-alpha.2, as deployed), one per area. Each traced code
and listed what it found sound. Findings below are grouped by suggested fix batch. "Verified" means the lead session
re-read the cited lines. Nothing was changed by the review itself.

Areas: fetch/sched/extract, store/migrations, Reader API + auth, web UI API + sanitizer, image proxy/cache, frontend
+ service worker, filters/search/stats/full-text, ops/docker/CI/docs. No critical findings; no auth bypass or
token forgery; sanitizer, SSRF dial-time guard, signature checks and the image memory model held up.

## Batch A: security and data integrity (fix first)

1. Feed migration after a redirect keeps `http_auth`, `allow_insecure_tls`, `allow_private_net` for the new host; Go
   also keeps Authorization on same-host https->http hops. `store/fetchcommit.go:589`, `fetch/fetch.go:160`. **Verified.**
2. `allow_private_net` / insecure-TLS apply to every article link, full-text target and image in that feed (LAN
   bridge feeds can make blind GETs to internal hosts). `ftrun/ftrun.go:160`, `extract/extract.go:124`,
   `api/image.go:145`, `api/fulltext.go:135`. Allow private addresses only for the feed's own host.
3. ClientLogin has no real brute-force limit: penalty sleeps after the hash, per-IP tracking is per full IPv6
   address, custom API password minimum is 5. `greader/api.go:448`, `auth/auth.go:211,247`.
4. Passwords from `KIPPLE_PASSWORD` / `KIPPLE_API_PASSWORD` skip the length check; `.env.example` ships a working
   password. `cmd/kipple/account.go`, `.env.example`.
5. Userinfo in feed URLs (`user:pass@`) is stored, exported in OPML and shown in notes. `feedurl/feedurl.go:67`.
6. Trim and feed delete run in one 10 s write transaction; about 100k items exceeds it and the feed then fails every
   commit forever. `store/retention.go:16`, `store/subs.go:374`. Batch both. (Measured: 4.9 s and 4.1 s at 50k.)
7. Retro filter preview/apply loads only the applied rule's fields but evaluates all rules: star rules on content or
   category misfire, inverted rules fire on empty text. `store/filterretro.go:54-98,156-213`. **Verified.**
8. Regex limits do not bound ingest time (34 ms per 8 KiB item for `[a-z ]{1,400}[0-9]{3}`), and evaluation runs
   inside the write transaction. `filter/rule.go`, `store/fetchcommit.go:365`.
9. Panic anywhere in the fetch path crashes the process (`sched/worker.go:30`, no recover).
10. Live database and WAL are created 0644 in a 0755 directory. `store/db.go:212`.
11. `restore` as root leaves `kipple.lock` and `backup/` root-owned (server then fails to start or snapshot).
12. Reader API: a folder named `x/state/com.google/reading-list` is read as a state stream (mass mark-read);
    OPML import skips URL and user-agent validation and folder-name length caps.

## Batch B: web app and offline

1. Queue flush sends a row that `supersede` already deleted (flush holds its own copy); re-read by seq before each send.
2. Bulk mark-read (`itemActions.ts:146`) resets rows the server did not change to unread even when read elsewhere.
3. Malformed `?from=` blanks the app (`decodeURIComponent` in render, no error boundary). `api/queries.ts:56`.
4. Highlights are rebuilt on every counts event; article selection collapses. `lib/useHighlights.tsx`.
5. Cached bootstrap can revert device settings when offline; queue write failures are swallowed; sign-out wipe is not
   awaited and the worker can refill; `openExternal` has no scheme check; full-text button state leaks across
   articles; mark-read-on-scroll never retries.
6. Skipped from the earlier review: unread/unstar invisible to `ot` (needs a column), Access-redirect status 0.

## Batch C: images, embeds, smaller server items

1. Slow-source body reads are never recorded as failures (repeat slot exhaustion); stale thumbnail not served when
   the original 404s; per-Handler pool/budget (secret rotation doubles them); `exifOrientation` panics on short
   APP1 (recovered, 24 h refusal); cache cap ignores index rows and block rounding; thumbnail URL served immutable
   when the cache is off; SSRF blocklist gaps (`fec0::/10`, `::/96`).
2. FTS rebuild and filter un-mute exceed 10 s / 60 s limits on large libraries.
3. YouTube playlist and unlisted Vimeo embeds lose their parameters; `<area>` links skip serve-time link rules;
   imgMode cache race; late background run after shutdown; make-default skips the 8 KB cap; stats value overflow.
4. Fetch: publisher `Expires` compared to our clock; queued jobs ignore settings changes; bodies decoded twice;
   import run drops feeds on lookup error; restore trusts declared DB size; snapshot dir not fsynced.
5. Filters/stats: restore toast overstates; full-text items visible before hold; empty highlight fields; beacon
   client label; stats title snapshot; PATCH cancels apply as failed.

## Batch D: ops and docs

1. Builds report version `dev` unless VERSION is passed (fixed on Host-A compose; make it the documented default).
2. `docs/RELEASING.md` rollback says a snapshot can be copied over `kipple.db`: remove (WAL replay corrupts).
3. Deploys pull `main` not the tag; rollback leaves detached HEAD. Use `git checkout vX.Y.Z`, document returning.
4. Shutdown budget can exceed `stop_grace_period`; config validation gaps (public URL, tick floor, proxy unmap);
   base images and Trivy unpinned; seed script can delete a real directory; stale README/SECURITY text.
5. Public-repo hygiene scan: no names, emails, hostnames or paths found in tree, history, tags.
