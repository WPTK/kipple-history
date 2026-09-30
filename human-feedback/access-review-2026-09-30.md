# Access review, 2026-09-30

Paraphrased; the session transcripts are not stored here. The time of day is not recorded (midday). See MEETINGS 46 and
CHALLENGES 48.

## What he said

- "You've done this 1000 times before but now you suddenly can't." He was pointing at the same kinds of action being
  allowed one time and blocked the next.
- After the review he applied the fix himself: a replacement hook with an allow-list, allow entries, and a corrected
  environment text (the repositories are public, not private).
- The GitHub display name "BK" is fine; it is not his surname or real name (DECISIONS.md).

## What changed

| Before | After |
|---|---|
| A non-deterministic classifier decided; prose rules in memory | A deterministic hook with an allow-list decides |
| The environment text said the repositories were private | Corrected |
| A regex docker hook matched docker words in any command text | Replaced |
| A `soft_deny` entry flagged every `ssh` to the deploy host | Handled in the new allow entries and hook (details are his configuration, not recorded here) |

The first real test of the new hook was the read-only backup copy to a backup drive. It went through.
