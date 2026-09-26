# Local review, round 2 (2026-09-26): reviewing the fixes

After eight fixer agents merged into PR #13, three read-only Opus agents reviewed the merged diff by area
(security/auth/fetch, store/filters/api, web) and a fourth reviewed the favicon PR (#9). They found regressions that
the fixes themselves introduced. Everything was fixed in a second round (fix2 branches, merged into #13, and the
favicon branch) with tests.

## Regressions found in the fixes

- **ClientLogin budget refused correct passwords.** The pre-hash budget counted every attempt, so a client sharing
  the owner's key (carrier NAT, or a wrong trusted-proxy setting) could get 401 without the password being checked;
  a retry during a slow login got an immediate 401; a remembered success cleared everyone's budget. Fixed: only
  failures count, a second concurrent attempt waits, over-budget attempts wait two seconds and are then checked.
- **Basic auth dropped on subdomain redirects**, and a redirect migration within one site (`example.com` to
  `www.example.com`, `nas` to `nas.lan`) cleared the feed's credentials and network exceptions. Fixed: same-site
  moves keep them; a move to another site while any is set stays pending.
- **OPML import skipped LAN feeds** (private literal addresses) that used to import with the exception off.
- **LAN full-text extraction broke** when article links used another hostname than the feed host.
- **Shutdown reserve was not really reserved** for the database close.
- **Stored filters no longer compiled** under the tighter regex limits; one such rule made every filter create, edit,
  preview and apply fail with an error that named the wrong rule; ingest silently dropped it while the UI showed it
  enabled. Fixed: limits apply to the rule being written plus the set sum over enabled rules; old rules are disabled
  with a visible reason; the set cap now admits about 40 typical alternations.
- **A feed delete in committed batches was not atomic:** a client timeout or crash mid-delete left a subscribed feed
  with its history gone, then re-fetched as new unread items with new ids. Fixed: mark the feed first (never fetched
  again), purge in batches, remove; a retry or the next start finishes it.
- **The search-index rebuild** held the writer up to 45 s and made every other write time out; now those writes
  answer 503 with Retry-After.
- **Web:** the sign-in screen said "wrong password" when the access-proxy sign-in had expired; a stalled queue request
  blocked every online change; the queue could resurrect a row the flush had deleted; bulk mark hid rows the server
  had skipped for other reasons; scroll-to-read retried with an error toast at every pause; a failed background
  refetch replaced the reader with a full-screen error; the error boundary could not recover a failed lazy screen.
- **Favicon PR:** the private-network grant covered every host the lookup touched (reproduced: a LAN feed whose site
  link pointed at loopback made two requests to loopback); the busy check returned "not busy" when the dispatcher
  was slow; no per-site pacing; a changing site link reset the backoff; user names and passwords in a page or icon
  URL were sent as Basic auth by Go's client (worse than reported); ICO files were only checked structurally.

## Checked and found sound (selected)

Lock ordering between apply, auto-read and shutdown; the retention batching invariants (starred and held items,
ledger, unread counters, no spin on an empty batch); imgproxy secret swap and cache accounting; sanitizer parameter
anchors; the `ot` migration and every read/star state-change path (a separate review of PR #15 found nothing real).

## After the merge

GitHub CI with `-race` caught two test-only defects: a data race in the shutdown-stage fakes and an image test that
raced a client abort against an upstream cut. See [../CHALLENGES.md](../CHALLENGES.md) item 20.
