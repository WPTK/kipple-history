# CLAUDE.md: proposed edits for the owner to approve

Source: `docs/audits/docs-audit-2026-09-26.md`, section "CLAUDE.md (decisions and non-goals vs what
shipped)". Each proposal was re-checked against the code at the phase-2 tip. Nothing below has been
applied: these touch "Decisions (do not relitigate)" or the non-goals, or need a call from the owner.

Already applied to CLAUDE.md as pure facts: the dev port (7080, `npm run seed`, `KIPPLE_ADDR` and
`KIPPLE_DATA` for a by-hand run), the package list (`extract` instead of `readability`, plus `sched`,
`api`, `imgproxy`, `imgcache`, `filter`, `backup`), the final Docker stage (distroless static nonroot,
uid 65532), and the finished CI TODO (the web job now runs lint, Vitest, build, contrast and
`npm audit`).

## 1. Themes (Decisions)

Now: "**Themes:** white, off-white, sepia, soft green, brown, dark, OLED dark (true black), follow-system."

Code: 20 color schemes (`web/src/theme/schemes.json` is the source of truth): 9 light (Paper, Linen,
Newsprint, Parchment, Directory, Cocoa Kraft, Airmail, Stationery, Tissue), 4 dark (Graphite, Midnight,
Cocoa Mid, Fountain) and 7 accessibility (Foolscap, Tracing, Signal, Carbon, Lamplight, Inkwell,
Teletype), plus follow-system with separate day and night picks (default Paper and Midnight). The old
ids are read-time aliases (`internal/store/uibootstrap.go`). This follows the owner's round-2 decisions in
`docs/ui-decisions.md`.

Proposed: "**Themes:** 20 color schemes (`web/src/theme/schemes.json` is the source of truth) plus
follow-system with separate day and night picks (default Paper and Midnight). The original seven names are
aliases: white=Paper, off-white=Linen, sepia=Parchment, soft green=Directory, brown=Cocoa Kraft,
dark=Graphite, OLED=Midnight."

Reason: the list describes the first draft; the shipped set is the owner's round-2 choice.

## 2. Fonts (Decisions)

Now: bundled list includes Charter; system list lacks Charter.

Code: fonts come from `@fontsource` (`web/package.json`, `web/src/lib/fonts.ts`). Charter is not bundled
(system-only, where the device has it), and Atkinson Hyperlegible Next is bundled ("Easy to read", per
`docs/ui-decisions.md`). The default body font is `ui-serif` (New York on Apple), then Literata.

Proposed: "**Fonts:** bundled through @fontsource and self-hosted, no CDN: Literata, Vollkorn, Gentium
Book Plus, Source Serif 4, Arvo, Inter, Manrope, Source Sans 3, JetBrains Mono, Source Code Pro,
Atkinson Hyperlegible Next. System when present: New York, Charter, SF Pro, SF Mono, Georgia, Menlo.
Default body: New York on Apple, Literata elsewhere."

Reason: Charter's licence could not be confirmed for bundling (see `web/README.md`), and the owner asked for
Atkinson Hyperlegible Next in round 1.

## 3. Retention: "Trim after fetch only" (Decisions)

Now: "... Trimmed IDs and read state kept for API consistency. Trim after fetch only."

Code: retention also runs when the global or a per-feed retention setting changes and on "Apply retention
now" (`POST /api/retention/apply`); the ledger is purged after `max(180 days, retention.restore_days + 7)`
and stubs after `retention.restore_days` (`internal/api/settings.go`, `internal/store/maint.go`).

Proposed: "Trim after each fetch and when retention changes (a settings change or Apply retention now).
Trimmed ids and read state are kept for API consistency, purged once the item has been gone from its feed
for 180 days (longer if `retention.restore_days` needs it)."

Reason: the code trims on settings changes, and the ledger is no longer kept forever.

## 4. Refresh: "API clients never trigger fetches" (Decisions)

Code: a Reader API subscribe that adds a feed (`quickadd`, `subscription/edit`, import) wakes the
scheduler, so the new (already due) feed is fetched on an immediate tick. The setting
`greader.subscribe_fetch_now` is stored and validated but not yet read by any code (reserved).

Proposed: "API clients never trigger fetches of existing feeds; a feed added from a client is fetched on
the next scheduler tick, which the add brings forward."

Reason: the rule as written is not what the code does for newly added feeds.

## 5. "No secrets or hostnames committed" (Layout)

Code and config are clean apart from test fixtures, but committed docs name the deployment:
`docs/plan.md` (many hits), `docs/research/cloudflare-access-deploy.md`, `docs/design.md`,
`docs/deploy.md` and CLAUDE.md itself carry the public hostname, LAN addresses and the Tailscale name.

Two options, the owner's call:

- Scope the rule: "No secrets committed; no hostnames or IPs in code, config or examples; docs may name
  the deployment."
- Or scrub the docs of hostnames and addresses (a large edit across the research files).

## 6. Non-goals: "no multi-user" (Decisions)

Not a contradiction, but undocumented: per-device appearance profiles on the single account (a device
cookie, cap 50, 5 new devices per login session per day; theme, fonts, density and layouts per device;
`internal/store/devices.go`, `internal/api/devices.go`).

Proposed: append to the non-goals line: "Per-device appearance profiles (one account, many browsers) are
not multi-user."

## 7. Process phases

Now: "Phases: 1 fetch/store/retention/Reader API; 2 reading UI; 3 themes, fonts, PWA; 4 stats."

Code: themes, fonts and device profiles shipped on `phase-2`; no manifest or service worker yet.
`docs/plan.md` already says so.

Proposed: "Phases: 1 fetch/store/retention/Reader API; 2 reading UI (including themes and fonts); 3 PWA
(manifest, service worker, install, offline); 4 stats."

## 8. Deploy: the exact Access bypass path

Now: "the Reader API path gets a Cloudflare Access bypass".

Code: the Reader API lives under `/api/greader.php` (bypassed, including its `/icon/` URLs). It also
answers root `/accounts/ClientLogin` and `/reader/api/0/*` (the LAN "Reader" account type), which stay
behind Access (`internal/greader/api.go`).

Proposed: "the Access bypass covers exactly the `/api/greader.php` prefix of the public host (the Reader
API and its `/icon/` URLs); root `/accounts/ClientLogin` and `/reader/api/0/*` answer too but stay behind
Access."

## 9. Reserved settings (FYI, no edit)

`greader.ot_includes_user_changes`, `greader.subscribe_fetch_now` and `stats.api_single_read_is_open` are
stored and validated but not yet read by any code (reserved). CLAUDE.md does not mention them, so nothing
to change; the documents that did now say so.
