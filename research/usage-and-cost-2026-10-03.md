# Usage and cost of building Kipple (2026-09-24 to 2026-10-02)

Source: the session transcripts of the Kipple project on the dev machine (main sessions, subagents, workflows and the
review sessions), duplicate message entries removed, the largest output count kept per message. Work done on another
machine or in a session that did not log here is not counted. Prices are Anthropic's official price list read on
2026-10-03 (platform pricing page). The owner is on a flat Max 5x subscription, so this is the API-equivalent cost, not
what he paid.

## Tokens

| Model | Fresh input | Output | Cache read | Cache write | Messages |
|---|---|---|---|---|---|
| Opus 5.5 | 24K | 6.55M | 2.17B | 65.7M | 12,062 |
| Sonnet 5 | 19K | 7.61M | 2.46B | 36.8M | 9,348 |
| Sonnet 5.5 | 7K | 0.98M | 0.84B | 18.4M | 3,396 |
| Fable 5.1 | 26K | 2.25M | 0.10B | 11.4M | 909 |
| Opus 5 | under 1K | 7K | 9.0M | 0.4M | 23 |
| Haiku 4.5 | under 1K | 5K | 1.0M | 0.1M | 19 |
| **Total** | 77K | 17.4M | 5.58B | 132.7M | 25,903 |

Main sessions: 5,234 messages, about 396K tokens of context re-read per message (2.07B cache reads, 37%). Subagents:
20,678 messages, about 169K per message (3.50B, 63%).

## Cost at the official rates (per million tokens)

Fable 5.1 10 in / 50 out / 0.25 cache read / 12.50 cache write (5 min) / 20 (1 h); Opus 5.5 4 / 20 / 0.20 / 5 / 8;
Opus 5 5 / 25 / 0.50 / 6.25 / 10; Sonnet 5 and 5.5 2 / 10 / 0.20 / 2.5 / 4; Haiku 4.5 1 / 5 / 0.10 / 1.25 / 2. Cache
writes were split into 5-minute and 1-hour by what each message logged (14% were 1-hour).

| Model | Cost |
|---|---|
| Opus 5.5 | about $895 |
| Sonnet 5 | about $674 |
| Fable 5.1 | about $285 |
| Sonnet 5.5 | about $235 |
| Opus 5 | about $9 |
| Haiku 4.5 | under $1 |
| **Total** | **about $2,100** |

By token type: cache reads about $1,123 (54%), cache writes about $645, output about $330, fresh input under $1. A first
estimate at the rates of earlier models had been about $3,170 (CHALLENGES 64).

## What it implies

- The cost is context re-read on every turn, not what is written. Subagents account for most of it because each starts
  with a large context and runs many turns.
- Instruction files (the project file, the memory index and the owner's global file) were about 3% of the total; the
  larger saving is behavioural. Changes made: a "Working economy" section in `CLAUDE.md` (Sonnet by default, Opus only
  for risky review and design, no re-verifying what CI already proved, small tool output, one task per session; no cap on
  subagents, by the owner's choice), a smaller memory index, and a global file split so the server-operations manual loads
  only in sessions started in its own folder.
- 19 messages came from a Haiku model, against the project's never-Haiku rule; the source was not traced.
