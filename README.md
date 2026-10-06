# kipple-history

The story of building [Kipple](https://github.com/WPTK/Kipple), a self-hosted RSS reader with a Google Reader
API sync endpoint, with an AI coding agent (Claude Code). It is kept apart from the code repository so the code
repository can go public without the working notes, testing evidence and deployment details that came with the
build.

This repository was written to be private, because the raw material (transcripts, memory notes, the owner's testing
notes, a Reeder sync log) contains personal and deployment details: first names, internal hostnames and IP addresses,
tunnel and device names. It has been public since 2026-09-27 09:49 ET, and that was not safe at first: it went public
before the scrub was finished, and `DECISIONS.md` carried two real server hostnames and one path with a Windows account
name. That was found on 2026-09-28, the current files were scrubbed the same night, and the whole git history was
rewritten and force-pushed with the owner's go-ahead on the morning of 2026-09-28 (see item 26 of
[CHALLENGES.md](CHALLENGES.md)). Anyone who cloned or viewed it before the rewrite may still have the old text; a
rewrite cannot undo that. The rule stands for everything added here: use Host-A (deploy target) and Host-B
(dev and admin machine), `rss.example.com` for the public hostname, no IP addresses, no Windows account name or profile
paths, no email addresses, no surname, no device or tunnel names, no tokens. A private duplicate of the repository that
existed for the purpose was deleted on 2026-09-29. The code repo is `WPTK/Kipple` (public since 2026-09-26 11:03 ET).

The material was assembled on 2026-09-26 from the Kipple repository history, the agent's memory notes and the
session transcripts, and updated at each milestone. It now covers 2026-09-24 to 2026-10-06: phases 1 to 5, the public
release, the local deep review, `v0.3.0-alpha.4` to `v0.3.0-beta.3`, the beta feedback round, the setup wizard stack and its
overnight audit, `v0.5.0-beta.1` and `-beta.2`, the 0.6 and 0.7 root-cause work (`v0.6.0-beta.1`, `v0.7.0-beta.1` and `-beta.2`),
nested folders and the scale work (`v0.8.0-beta.1`), the perf-only `v0.8.0-beta.2` (tagged and deployed 2026-10-05, schema 13), `v0.8.0-beta.3` (tagged and deployed 2026-10-05, schema 16) and the issue and
housekeeping meeting of 2026-10-05. Nothing was rewritten after the fact except the redactions described in this file. Sunday 2026-09-27
daytime through Tuesday 2026-09-29 were added late, on 2026-09-29, after the owner noticed the gap; those entries were
written from the transcripts, the Kipple git log and pull requests and the memory notes, not from the notes taken at the
time. From now on this repository is updated at least daily.

## How to read it

Start with the synthesis documents, then drop into the sources they link to.

| File | What it is |
|---|---|
| [TIMELINE.md](TIMELINE.md) | Dated chronology, hour by hour where it matters, with tags and phases |
| [MILESTONES.md](MILESTONES.md) | Each release and phase (planning to `v0.8.0-beta.3`): what shipped, what shaped it, size in commits and lines |
| [MEETINGS.md](MEETINGS.md) | Every decision session: date, type, what was decided, approximate message counts |
| [CHALLENGES.md](CHALLENGES.md) | Real problems with cause, fix and lesson (73 items) |
| [parking-lot.md](parking-lot.md) | Deferred ideas, follow-ups with their status, and the owner's standing rules |
| [DECISIONS.md](DECISIONS.md) | Standing and later decisions, each with its source |

Primary sources:

| Folder | Content |
|---|---|
| [diary/](diary/) | The agent's engineering diary, one file per day, written for the article |
| [human-feedback/](human-feedback/) | the owner's testing notes and evidence (Reeder sync log) |
| [audits/](audits/) | The 285-item docs-versus-code audit, the `CLAUDE.md` proposals, the local deep review with its second round, and later audits and reviews |
| [research/](research/) | 26 research reports (plus two colour-scheme data files) and design-meeting prework (client behaviour, libraries, UI, colour) |
| [plans/](plans/) | Current plans (`0.6-0.7-1.0-plan.md`, `0.8-1.0-plan.md`), the original plan, design, UI decisions, the setup wizard design, phase 3 and phase 4 handoffs, both kickoff briefs, `CLAUDE.md`, changelog; the documents that were removed from the Kipple repo carry a "historical snapshot" header |
| [plans/history/](plans/history/) | Earlier revisions of plan, design and `CLAUDE.md`, and the first kickoff prompt, named `<doc>-<date>-<shortsha>.md` |

The documents in `plans/` and `plans/history/` are snapshots (most refreshed 2026-09-29, at `v0.3.0-beta.2` preparation; the plan, the handoffs and the setup wizard design were archived 2026-10-05 and are no longer in the Kipple repo; earlier revisions are in `plans/history/`); the
living copies stay in the Kipple repo.

## Conventions

- Voice: plain and factual. Mistakes are stated with cause and fix.
- Times are US Eastern (UTC-4), converted from the UTC timestamps in the transcripts unless noted. The diary uses
  UTC in some places.
- Message counts and dollar and token figures are estimates unless a source gives an exact number. Precise counts
  can be recomputed from the session transcripts, which are not stored here.
- Commit hashes refer to the Kipple repository.
- "the owner" is the owner. His surname does not appear anywhere in this repository and must not be added.

## Numbers at a glance

At `v0.2.0` (about three calendar days in): 354 commits and six tags, 544 files, about 114,000 added lines, of
which about 63,500 are Go (about 31,000 of it tests). At `v0.3.0-alpha.3` (the evening of day three, after the
repository history was rewritten for going public): 492 commits, ten tags, 615 tracked files, about 75,400 lines of
Go (about 38,800 of them tests) and about 30,500 lines under `web/src`. At the `v0.3.0-beta.2` release branch (day
six, 2026-09-29): 645 commits, twelve tags (`v0.3.0-beta.1` is the latest; alpha.5 and alpha.6 were never tagged),
712 tracked files, about 83,800 lines of Go (about 43,200 of them tests) and about 40,000 lines under `web/src`; 44
pull requests merged since alpha.3. See [MILESTONES.md](MILESTONES.md) for the breakdown and what the counts do and do
not mean.

At `origin/main` on 2026-10-05 (after `v0.8.0-beta.1`, with the `v0.8.0-beta.2` release commit merged): 739 commits, twenty
tags pushed (`v0.8.0-beta.1` is the latest; `v0.8.0-beta.2` was tagged 2026-10-05, so 21 tags then), 833 tracked files, about 96,800
lines of Go (about 50,800 of them tests, 432 Go files) and about 47,000 lines under `web/src`. Schema 13 with migration 0013
(the perf build).

## Scrub check

`scripts/scrub-check.ps1` (PowerShell 7) checks text against the scrub rules before it lands here. It cannot
know the owner's private terms, so those live in an untracked file on each machine that commits.

What it checks:

- Generic rules, built in: em and en dashes, IPv4 addresses (except 127.0.0.1, 0.0.0.0 and the documentation
  ranges), email addresses (except example domains), and the names of reader apps.
- Owner terms, from `.scrub-terms.local` at the repository root: host names and labels, the owner's domain,
  account names, private address ranges, the real name. The file is in `.gitignore` and must never be committed.

Run it:

```
pwsh scripts/scrub-check.ps1            # staged changes (default)
pwsh scripts/scrub-check.ps1 -All       # every tracked text file
pwsh scripts/scrub-check.ps1 -Verbose   # step-by-step trace
```

It prints `file:line: rule name` for each hit and never prints the matched text; owner rules are named
`owner-term:lineN`, where N is the line in `.scrub-terms.local`. Exit codes: 0 clean, 1 at least one hit, 2 usage or
environment error (the message names the failing step and the fix).

Terms file format: one literal term or regular expression per line, matched case-insensitively; blank lines and lines
starting with `#` are ignored. A line that is not a valid regular expression is reported by line number and matched as
a literal string.

Add a rule:

- A generic rule (useful to everyone): add one `ConvertTo-ScrubRule` line to `Get-GenericRule` in the script and a
  case to `scripts/scrub-check.Tests.ps1`.
- An owner term: add a line to `.scrub-terms.local`. Nothing is committed.

Run its tests (Pester 5 or later): `pwsh -Command "Invoke-Pester scripts/scrub-check.Tests.ps1 -Output Detailed"`.

Commit hook: `.githooks/pre-commit` runs the staged check. A hook is opt-in per clone; enable it once with:

```
git config core.hooksPath .githooks
```

If it breaks:

- Nothing runs on commit: the hook is not enabled in this clone. Run the `git config` command above.
- The check warns that owner terms are not loaded: `.scrub-terms.local` is missing, so only the generic rules run.
  Recreate the file from the owner's copy.
- `pwsh` not found: install PowerShell 7 or commit with the hook disabled and run the check by hand.

## Redaction note

One hostname in [research/cloudflare-access-deploy.md](research/cloudflare-access-deploy.md) contained the
owner's surname and was replaced with `<redacted-host>`. Everything else is verbatim.
