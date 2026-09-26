# Evidence captured from the live server

Raw logs captured from the Host-A deployment so questions about real client behavior can be settled from
data. Logs are redacted: no cookies, tokens or addresses (the request logger already redacts the token
`T`; a scan for hostnames, IPs and credentials found nothing).

## reeder-alpha2-2026-09-26.log

Kipple `v0.2.0-alpha.2`, `KIPPLE_LOG_LEVEL=debug` and `KIPPLE_LOG_GREADER_FORMS=1`. Captured 2026-09-26 after
The owner pulled to refresh in Reeder Classic several times and marked the "aviation" category as read.

29 Reader API requests from `Reeder/5060003`:

| Count | Request |
|---|---|
| 9 | `GET stream/items/ids` |
| 15 | `POST stream/items/contents` |
| 3 | `GET subscription/list` |
| 1 | `GET token` |
| 1 | `POST edit-tag` |

### Finding: Reeder marks a category read with edit-tag, not mark-all-as-read

The single mark-read request was `POST /reader/api/0/edit-tag` with form keys `T`, `a`, `i`:

- `a` = `user/-/state/com.google/read` (add the read state)
- `i` = **424 item ids** (the three logged samples are the first three of 424)

Reeder listed every unread item id in the category and sent them in one request. It did **not** call
`mark-all-as-read`, and no `ts` parameter was sent. So for this Reeder action, open question 1 in
`docs/research/open-questions.md` (the unit of `ts`) never arises. Kipple's digit-count parsing of `ts`
stays as a hedge for other clients or actions.

### Consequence for read inference (`stats.api_single_read_is_open`)

A bulk mark (folder or "mark all") arrives as one `edit-tag` with many ids (424 here). A single article read
is one id. The id count is a clean signal to tell bulk marks (not a "read" for stats) from single-article
reads. Inference stays off by default; this is the evidence to turn it on later if wanted.

The item ids are the 16-hex-digit long form (`00065c5f65078dc1`), as designed.
