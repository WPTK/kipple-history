# The owner's asks and feedback, 2026-09-29 afternoon and evening

Paraphrased; the session transcripts are not stored here. Times are parts of the day where the source has no timestamp.

## Asks (afternoon)

- A one-click Docker image install with setup included.
- A first-run setup flow for a single user on a single Docker host: theme selection, a skippable OPML import, and
  recommended feeds (his personal favorites, supplied later, skippable).
- An obscure, memorable four-digit default port.
- Phase 5 is complete (checked on GitHub, see MEETINGS 43).

Outcome: the wizard, port 1919, the release workflow and build info, all merged that evening (MILESTONES.md).

## Reports and questions (evening)

| What he said | What happened |
|---|---|
| "Read" in the stats should mean articles he actually clicked on and read, not scrolled past | Issue #120, PR #122; new rule in DECISIONS.md. His past numbers may drop |
| Where is font selection? | In the "Aa" reading menu in the article header, not Settings and not the wizard. Follow-up parked: offer it in Settings and the wizard, and check whether the Aa button is missing in his build |
| He wanted to see the wizard screenshots | They had been saved to a scratch folder and never committed; I sent them |

## Feedback on how I work

- **Wordiness.** My explanations were too wordy and full of fluff. Adopted: shorter, plainer replies.
- **Blocked merges.** He got frustrated that merges kept being blocked. The cause was the auto-mode classifier's allow
  condition ("has gone through the project's own review process"), which it could not verify; he fixed it by editing the
  allow rule in the local settings himself. I do not edit permission settings.
- **An invented "standard order".** He objected that I kept presenting a merge order as if it were a standing rule. It was
  my proposal each time (CHALLENGES 41).
