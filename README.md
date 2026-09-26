# kipple-history

The story of building [Kipple](https://github.com/WPTK/Kipple), a self-hosted RSS reader with a Google Reader
API sync endpoint, with an AI coding agent (Claude Code). It is kept apart from the code repository so the code
repository can go public without the working notes, testing evidence and deployment details that came with the
build.

This repository is private on purpose. It contains personal and deployment details: first names, internal
hostnames and IP addresses, tunnel and device names, real-device testing notes, and a Reeder sync log. Do not
make it public without a scrub pass. The code repo is `WPTK/Kipple` (private for now).

The material was assembled on 2026-09-26 from the Kipple repository history, the agent's memory notes and the
session transcripts. It covers 2026-09-24 to 2026-09-26. Nothing here was rewritten after the fact except a
single redaction (see the note at the end).

## How to read it

Start with the synthesis documents, then drop into the sources they link to.

| File | What it is |
|---|---|
| [TIMELINE.md](TIMELINE.md) | Dated chronology, hour by hour where it matters, with tags and phases |
| [MILESTONES.md](MILESTONES.md) | Each release and phase: what shipped, what shaped it, size in commits and lines |
| [MEETINGS.md](MEETINGS.md) | Every decision session: date, type, what was decided, approximate message counts |
| [CHALLENGES.md](CHALLENGES.md) | Real problems with cause, fix and lesson |
| [DECISIONS.md](DECISIONS.md) | Standing and later decisions, each with its source |

Primary sources:

| Folder | Content |
|---|---|
| [diary/](diary/) | The agent's engineering diary, one file per day, written for the article |
| [human-feedback/](human-feedback/) | the owner's testing notes and evidence (Reeder sync log) |
| [audits/](audits/) | The 285-item docs-versus-code audit and the `CLAUDE.md` proposals |
| [research/](research/) | 21 research reports and design-meeting prework (client behaviour, libraries, UI, colour) |
| [plans/](plans/) | Current plan, design, UI decisions, phase 3 handoff, both kickoff briefs, `CLAUDE.md`, changelog |
| [plans/history/](plans/history/) | Earlier revisions of plan, design and `CLAUDE.md`, and the first kickoff prompt, named `<doc>-<date>-<shortsha>.md` |

The documents in `plans/` and `plans/history/` are snapshots taken on 2026-09-26; the living copies stay in the
Kipple repo.

## Conventions

- Voice: plain and factual. Mistakes are stated with cause and fix.
- Times are US Eastern (UTC-4), converted from the UTC timestamps in the transcripts unless noted. The diary uses
  UTC in some places.
- Message counts and dollar and token figures are estimates unless a source gives an exact number. Precise counts
  can be recomputed from the session transcripts, which are not stored here.
- Commit hashes refer to the Kipple repository.
- "the owner" is the owner. His surname does not appear anywhere in this repository and must not be added.

## Numbers at a glance

354 commits and six tags from `v0.1.0` to `v0.2.0` in about three calendar days; 544 files and about 114,000
added lines at `v0.2.0`, of which about 63,500 lines are Go (about 31,000 of it tests). See
[MILESTONES.md](MILESTONES.md) for the breakdown and what the counts do and do not mean.

## Redaction note

One hostname in [research/cloudflare-access-deploy.md](research/cloudflare-access-deploy.md) contained the
owner's surname and was replaced with `<redacted-host>`. Everything else is verbatim.
