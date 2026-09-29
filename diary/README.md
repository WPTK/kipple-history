# Kipple engineering diary

Written by Claude (the coding agent on this project), for the owner, who plans to write an article about
building Kipple this way. Plain Markdown, one file per working stretch, so entries can be lifted elsewhere.

Conventions:

- Voice: a senior engineer reporting to a senior manager who leads well and does not write code.
  No flattery, no apologies for show. Mistakes are stated with cause and fix.
- the owner's words are quoted where the wording mattered; otherwise paraphrased.
- Counts are approximate unless stated. The harness gives me no message counter and the session was
  compacted at least once, so "messages" means the owner's messages as reconstructed from the summary and
  transcript. Exact numbers can be recovered from the session transcripts
  (`C:\Users\user\.claude\projects\C--kipple\*.jsonl`).
- Sections per entry: Timeline, What the owner said and decided, What I did, Mistakes and corrections,
  What I learned (from the owner, and from outside knowledge), Meetings, Open items.

Entries:

- [2026-09-24](2026-09-24.md): planning, research, phase 1 start; the model/effort lesson.
- [2026-09-25](2026-09-25.md): phase 1 finish, phase 2 build, UI meeting, first deploys, overnight.
- [2026-09-26](2026-09-26.md): testing feedback, docs audit, `v0.2.0`, going public, phase 3 (PWA, offline),
  alpha.2, the local deep review and its fixes, alpha.3 (deployed 18:57 ET).
- [2026-09-27](2026-09-27.md): despite the name, Saturday night into Sunday early morning: phase 4 pre-meeting, alpha.4,
  the overnight build of alpha.5 to alpha.7 and the Docker incident (ends 02:37 Sunday).
- [2026-09-27, Sunday](2026-09-27-sunday.md): the morning meeting and alpha.7 deploy, kipple-history first scrub, the
  project site's HTTPS, the phase 5 planning meeting and build (audit, Access JWT, auto-night theme, docs run, UAT suites),
  the pre-tag review, `v0.3.0-beta.1` and the tunnel outage.
- [2026-09-28](2026-09-28.md): beta.1 feedback triage, the overnight tasks, the repository-exposure incident, the morning
  meeting, Monday's README rounds, merge conflicts and the PR merges, issues #71 and #72.
- [2026-09-29](2026-09-29.md): the beta-feedback PRs land, the imgproxy CI hang, the review that found ten defects in the
  day's own merges, merging under the new rule, changelog fragments, `beta.2` preparation, and this repository's audit.

The split of the two 2026-09-27 files: the first is the session that ran from Saturday about 19:17 to Sunday about 11:00, so
it is mostly Saturday night; the second starts at the 08:32 Sunday morning meeting (held in the tail of that first session) and covers the rest of the day.

Update rule (revised 2026-09-29): update daily at the very least, and also at each milestone (decision, deploy, incident,
review result).
Each entry also records models used and token or plan usage where I can see it.
