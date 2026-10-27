# UI decisions: process log (moved from the Kipple repo)

## Parking lot additions

Design system / static demo site / pull-and-run image; Cloudflare Access JWT; passwordless login; scheduled
auto-night. The parking lot itself is kept outside this repository. (Cloudflare Access JWT and passwordless login
shipped in phase 5 as #40, the scheduled auto-night theme as #41.)

## Next chunks

All four steps are done (historical list).

1. Round-2 research (colors, layouts incl. Inbox, keymap, gesture spec, filters brainstorm, accessibility spec).
2. Consolidate into a UI spec and update `design.md` (audit contradictions).
3. Backend items these decisions add (image cache, mute filters, mark above/below, oldest-first order,
   per-device settings, backup export, security headers, FTS stemming, health status reconciliation).
4. Frontend build after the owner signs off the UI spec.

### Working agreement
- Commit and open PRs without asking. Merge docs-only PRs when CI is green. Code PR for `phase-2` opens at
  deploy time. Reviews (Opus, high) after every two or three backend steps; fix all findings.
