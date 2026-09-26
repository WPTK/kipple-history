# Research reports (2026-09-24)

Primary-source findings gathered by a nine-agent research workflow before phase 1 was designed.
Each file ends with the discrete claims it rests on (with confidence and source URL), open
questions, and the full source list. The plan (`docs/plan.md`) and design (`docs/design.md`) cite
these by file name.

| File | What it settles |
|---|---|
| `greader-freshrss.md` | The Google Reader API exactly as FreshRSS `p/api/greader.php` serves it: every endpoint, parameter, response shape, id and timestamp encoding |
| `greader-miniflux.md` | Miniflux's Go implementation: routes, structs, id parsing, client-specific quirks in comments |
| `item-id-and-quirks.md` | Item ids, timestamp units, stream/edit semantics reconciled across FreshRSS, Miniflux, CommaFeed, TT-RSS, BazQux, Inoreader, The Old Reader; client quirk catalog; explicit disagreements |
| `reeder-classic.md` | Reeder Classic's account types, login form, sync request sequence, Swift-decoding strictness, server-maintainer fix log |
| `netnewswire.md` | NetNewsWire's Reader API client read from its Swift source: endpoints, params, id conversion, sync algorithm, issues |
| `fetch-prior-art.md` | How Miniflux, yarr, FreshRSS and Feedbin poll, dedup, back off, handle redirects and clean up; concrete rules for Kipple |
| `go-libraries.md` | Library survey with versions, licenses, CGO, gotchas; the pinned set |
| `cloudflare-access-deploy.md` | Access path apps and Bypass, JWT hardening, tunnel ingress editing, cookies behind cloudflared, SSE/caching gotchas, cutover checklist |
| `pwa-ui-fonts.md` | iOS standalone PWA constraints (iOS 18–27), UI stack state, Feedly layout anatomy, font sources and subsetting |
| `lemon24-reader.md` | lemon24/reader (Python feed-reader library) as prior art for internals: SQLite discipline, update decisions, content hashing, dedup, FTS5, reading time, UA fallback; 39 ADOPT/CONSIDER/REJECT deltas |

Verification: 40 load-bearing API claims were sent to adversarial verifiers; 10 survived, 1 was
corrected (FreshRSS's fullwidth escaping detail — irrelevant to Kipple, which does not escape), and
29 could not be re-run because of session usage limits. Those 29 are each corroborated by at least
two of the independent reports above.

Open questions from every report are triaged in `open-questions.md` (decided / hedged-then-observed /
verify-at-step / no action).
