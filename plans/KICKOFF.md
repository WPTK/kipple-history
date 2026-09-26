# Kipple kickoff prompt

This is the project brief agreed with the owner on 2026-09-24. CLAUDE.md holds the condensed
decisions; this file is the full statement of requirements and process. Start in plan mode.

---

We are building Kipple, a self-hosted RSS reader to replace yarr on Host-A.
Multi-week project. Start in plan mode. Ultracode is on for this project.
CLAUDE.md in this repo holds the fixed decisions; treat it as settled.

## Architecture (decided)
- Go backend, React + TypeScript + Vite + Tailwind + shadcn frontend, SQLite in
  WAL mode. The built frontend is embedded in the Go binary. One Docker image,
  one container, one port. Named volume for the database. No other services.
- Runs on Host-A (Ubuntu, 192.0.2.50, user kipple) in compose project `host-a`,
  /home/user/stack/docker-compose.yml, 10m x 3 log rotation like the rest.
- Keeps https://rss.example.com through Host-B's cloudflared and the existing
  Cloudflare Access setup. The Google Reader API path needs a bypass policy the
  same way /fever has one today; the UI stays behind the email OTP.
- GitHub is the source of truth: private repo `Kipple` under my account.
  Working copies at C:\kipple on Host-B (already a git repo) and /home/user/kipple
  on Host-A. Host-A has Docker but no Go, so the Dockerfile is a multi-stage build
  and Host-A pulls and builds the image; nothing is deployed from an unpushed
  tree. No secrets or hostnames in committed files, use .env and an example
  file.
- Migrate from yarr's OPML at /home/user/newsblur-export.opml (138 feeds, 15
  folders). Pause yarr, do not remove it, until I say so.

## Hard requirements
1. Read, unread and starred state lives on the server and syncs to every
   client.
2. Google Reader API (the FreshRSS/Miniflux flavor) for iOS apps. No Fever.
   Primary phone client is Reeder Classic, secondary is NetNewsWire. Before
   designing the API, verify what each of those two apps actually sends and
   expects, including quirks other servers had to work around, and test
   against both before phase 1 is done.
3. Full OPML import and export. RSS, Atom and JSON Feed.
4. Refresh follows the standard reader model: a background poll every 30
   minutes by default, adjustable globally and per feed. Conditional requests
   with ETag and Last-Modified so unchanged feeds cost nothing. Exponential
   backoff for feeds that keep failing, reset on the next success. A manual
   refresh (button, pull-to-refresh, or the r key) fetches every feed now.
   API clients read stored items and never trigger fetches. Fetches run
   concurrently with a sane cap, and the UI streams new items in as they land.
5. Retention is a setting: keep the newest N items per feed, choices 50, 100,
   250, 500, 1000 and unlimited, global default with a per-feed override.
   Starred items are never trimmed. Keep a compact record of trimmed item IDs
   and their read state so the Reader API stays consistent. Trim runs after
   each fetch, never on page load.
6. Web UI polished enough to live alongside Reeder. Installable to the iOS
   home screen as a standalone PWA with safe-area handling, and equally good
   on desktop. Keyboard shortcuts on desktop (j/k, s, o, r, m), swipe actions
   on mobile.
7. Full-text extraction for truncated feeds, toggleable per feed and per
   article, plus a one-tap open of the original page. Image proxy so mixed
   content never breaks the article view.
8. Share button uses the OS share sheet via the Web Share API, with copy-link
   fallback where that API is missing.
9. Typography: selectable font family and size, separately for the article
   body and the UI. Bundled fonts, self-hosted, no CDN: Literata, Charter,
   Vollkorn, Gentium Book Plus, Source Serif 4, Arvo, Inter, Manrope, Source
   Sans 3, JetBrains Mono, Source Code Pro. System fonts offered when present:
   New York, SF Pro, SF Mono on Apple devices, Georgia and Menlo. Default body
   font is New York on Apple devices and Literata everywhere else. Subset the
   bundled fonts so the first load stays small.
10. Themes: white, off-white, sepia, soft green, brown, dark, follow-system.
11. Layouts: compact list, magazine cards, and a clean article view. Search
    across stored articles. Feedly is the reference for feel, especially its
    magazine and card views with images up front. Rejected for reference:
    NewsBlur (too much), FreshRSS (boring, no magazine view), Miniflux (too
    plain).
12. Feed health view: last success, last error, consecutive failures, current
    backoff, dead feeds, redirect notices, per-feed fetch history.
13. Estimated reading time on cards only if it is a trivial add. Skip it if
    it costs a day.

## Statistics (schema now, UI in phase 4)
Track: article opened, active reading seconds (tab visible and focused only),
scroll depth, starred, opened-original, shared, source feed, folder, hour and
weekday, and which client (web or API). Bulk mark-as-read and mark-read-on-
scroll are not reads and are excluded from every stat. Views: most-read
sources, reading by hour and weekday, time per source, feeds I never open,
streaks. Stats events are never trimmed with articles. CSV export.

## Non-goals
No AI features of any kind. Single user. No social features. No notifications
of any kind. No uptime monitoring.

## Process
- Phases: 1 fetch, store, retention, Google Reader API, and Reeder Classic
  syncing; 2 web UI reading experience; 3 themes, typography and PWA polish;
  4 stats. Each phase ends with me using it for a day before the next.
- Use workflows for research (Reader API spec and Reeder Classic and
  NetNewsWire quirks, Go feed and readability libraries), for design (judge
  panel on the data model and the fetch scheduler), and for review. Sonnet
  for routine code with Opus as advisor and reviewer. Never Haiku. One writer
  on Host-A at a time.
- Tests for feed parsing, the Reader API contract, the fetch scheduler and
  backoff, retention with starred items, and the stats event rules.
- Verify iOS layout in the browser pane at the mobile preset before calling
  any UI phase done. Run /code-review high before every deploy.
- Add the volume to the Proton off-site backup once it holds real data.
- Save decisions and gotchas to memory as we go.

## Definition of done
Reeder Classic syncs read state both ways within 60 s of a change, and
NetNewsWire connects. OPML round-trips losslessly. New items appear within one
poll interval without me touching anything, and within 15 s of a manual
refresh on LAN. Retention trims to the chosen cap and never touches starred
items. The UI is usable one-handed on an iPhone. Feed health shows every
feed's last fetch. Stats show a week of my real reading. Image size under
50 MB, idle memory under 100 MB.
