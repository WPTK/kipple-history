# UAT run logs, September to October 2026

Moved out of `docs/maintainers/uat-plan.md` in the code repo on 2026-10-26 (Build 10, Meeting 10 item 11). The plan states
the suites; the results of dated runs live here. Suite 2 (agent-driven scenarios, 2026-09-27 and 2026-09-29), Suite 3
(owner devices), Suite 4 (migration and restore drill) and Suite 5 (fresh-machine walkthrough) follow, in that order.

**Executed 2026-09-27.** Driven by Claude in the desktop app's built-in browser pane against a throwaway local
instance (`npm run seed` on 127.0.0.1:7092, its own temp data dir, a build of `main`), plus a local
test feed served from the same temp dir so arrivals and filter matches could be controlled. The pane stayed
hidden behind other windows for the whole run, which has side effects worth knowing before re-running this: the
page reports `document.visibilityState` "hidden" and never has focus, CSS transitions, `ResizeObserver` and
media-query change events only advance when a frame is actually drawn (a screenshot forces one), react-query
pauses retries, and active reading time is never recorded. Where that mattered it is said below; none of it is a
Kipple defect. Defects found: three fixed in PR #45, two copy questions filed as issues #43 and #44 for the owner.

- TC-F1 **pass.** Adding `https://blog.rust-lang.org/` (a site, not a feed) discovered the feed and showed 10
  items within about 3 s.
- TC-F2 **pass, with a substitute fixture.** The 138-feed OPML export was not available to the agent; a
  6-feed OPML with two folders, a top-level feed and one duplicate was used instead. Result: 5 added, 2 folders
  created, 1 already present and left in its original folder, top-level feed placed in Uncategorized. The
  summary's "1 feed was already in Kipple and left as they are" mixed singular and plural (fixed, PR #45).
- TC-F3 **pass.** Re-importing the export into the same instance added nothing; importing it into a second,
  empty instance and exporting again gave a byte-identical file, including `kipple:interval` and
  `kipple:retention` overrides.
- TC-F4 **pass.** Poll interval (2 h), retention (newest 50) and layout (Cards, a per-device override) set on one
  feed all survived a server restart, and the feed opened in Cards.
- TC-F5 **pass.** Deleting a feed with 2 starred items (the dialog showed the count, keep-starred default)
  moved them to "Unsubscribed (starred)"; both stayed in Starred with their original feed name, and Stats lists
  the feed as "(unsubscribed)".
- TC-R1 **pass.** All five layouts render real content with images through `/img/`, no horizontal overflow and
  no `undefined`/`NaN` text. (Overlapping Editorial rows in one screenshot were the hidden-pane
  `ResizeObserver` stall, gone once a frame was drawn.)
- TC-R2 **pass.** Each density step changes both the list variables and the article line height and measure
  (1.4 to 1.8); the Settings live preview matches the applied values exactly and the choice is saved to the
  device profile.
- TC-R3 **pass after a fix.** j/k, m (with the dim-then-leave behavior when moving off, and undo), s, o, c, r,
  z, `?` and the 15 s undo toast behave as specified. `/` from another screen opened Search with the caret on
  the heading instead of the search box (the shell's heading focus ran after Search focused its box); fixed in
  PR #45 with regression tests. Other in-app arrivals at Search keep heading focus and a page load still puts the
  caret in the box.
- TC-R4 **pass.** Short list plus More themes and Accessibility themes groups; all 20 schemes apply, body text
  contrast 7.8:1 or better on every one; Signal's danger is magenta (`#a0006a`), Carbon is neutral gray-black and
  Fountain clearly navy with cream text.
- TC-R5 **pass.** Follow system switches Paper/Midnight with the color scheme; On a schedule with custom picks
  (Linen by day, Graphite by night) switched to Graphite at the night boundary and back to Linen at the day
  boundary without a reload.
- TC-R6 **pass, auto-read partly.** Mute (created in the UI), mark read, auto-star and highlight each acted on a
  new matching item as it arrived; Muted lists the muted item with its rule and Restore brings it back unread; a
  saved search is in the sidebar with its count. Auto-read after N days is measured from crawl time by design,
  so on a fresh instance the preview correctly finds nothing (the catch-up path itself is covered by store
  tests). The highlight rule always said "Hasn't matched anything yet" because highlights are never counted;
  fixed in PR #45.
- TC-R7 **pass.** With the list loaded, an item that arrived afterwards stayed unread after Shift+A while the
  three loaded ones were marked read. The empty state then says new ones appear after the next refresh while
  the "1 new article" pill is showing (issue #44).
- TC-S1 **pass.** `runner` finds "runners", `run` finds "running"; the saved search re-runs to the same result
  list later.
- TC-T1 **pass (short session).** Opens and reads from the session show up with matching numbers in all four
  ranges, the Items/Minutes toggle and folder rollup, never-opened feeds and streaks. A full day of the owner's
  real reading is still worth a look in Suite 3.
- TC-T2 **pass.** CSV, JSON and JSON Lines raw exports and the JSON summary all parse and carry the same event
  count; with titles and links off, `item_title`/`item_url` are null and no URL or title appears anywhere; the
  data dictionary downloads as Markdown.
- TC-T3 **pass.** Delete a range showed "No events in that range" for a range without data and the right count
  for today, then a second confirmation; Delete all only enables on the exact `DELETE ALL`; Stats shows the empty
  state afterwards. Turning statistics off stopped recording and hid Stats, and on again resumed recording, both
  without a reload.
- TC-T4 **pass.** Your year gives a plausible summary, the share sheet copies the text (top sources only when
  switched on) and saves a PNG; a failing summary request shows "Try again", which recovers. When a year has
  opens but no reads, the "Only 1 day of reading" notice contradicts "No days with reading" (issue #43).
- TC-A1, TC-A2, TC-A3 **skipped.** They need a Reader API client on the owner's devices; not
  executable by an agent.
- TC-C1 **pass (negative case only).** Without Access configured the login form requires the password: an empty
  password is refused, including with a forged `Cf-Access-Jwt-Assertion` header. The positive case needs a real
  Cloudflare Access setup and was not testable here.
- TC-C2 **pass.** Generate API password asks for the web password, shows the new one once and copies it; that
  password signs in on `ClientLogin` and lists subscriptions, and the web password does not.
- TC-C3 **pass.** The restore half is Suite 4's drill below; the web backup export here produced a valid zip
  with the expected contents summary and warning.
- TC-P1 **pass.** Manifest (standalone, scope and start `/`), 192/512/maskable icons and a 180 px
  `apple-touch-icon` all load at their declared sizes; `viewport-fit=cover` with safe-area insets in the CSS; at
  the mobile preset (375 px) no screen scrolls sideways and the bottom tab bar is in place.
- TC-P2 **blocked in the pane, checked statically.** The built-in browser refuses every service worker
  registration, even a one-line worker on another local origin, so the live update could not be exercised. The
  built `sw.js` precaches the page's hashed `index-*.js`/`.css` and the lazy chunks, and `update()` runs on
  `visibilitychange`. The live check belongs on a real browser in Suite 3.

**Re-executed 2026-09-29** (the rc.1 re-verification, `docs/maintainers/RELEASING.md`). Build of `main` whose product code
is identical to the beta tag, with `web/dist` rebuilt first. Throwaway instance from `npm run seed` on port 7092 with
its own temp data dir, plus a local test feed server in the same temp dir for controlled arrivals, lead-image and
filter cases (added through OPML with `allow_private_net` turned on for those two feeds). Driven by Claude with
headless Chromium through Playwright scripts rather than the desktop pane, so unlike 2026-09-27 the page was visible
and focused (active reading time was recorded) and service workers could register. Screenshots were read for
everything visual. Everything, scripts and data dir included, was deleted afterwards; nothing touched the Kipple server or the
live instance. Result: 21 of the 26 cases pass, 1 fails (TC-C3, a P2 display bug), 4 skipped or blocked (TC-A1..A3,
TC-P2 live update). Of the 11 checks for what changed since 2026-09-27, 8 pass and 3 fail (all P2). No P0 or P1.
Defects are numbered B2-1 to B2-9 below for the findings doc.

- TC-F1 **pass.** Add feed with a site address (not a feed URL) discovered the feed; "First fetch finished: 10
  articles" about 1.5 s after Add.
- TC-F2 **pass, with the substitute fixture.** Same shape as before (two folders, two top-level feeds, one feed
  already present in another folder), imported from Manage Feeds > Import OPML: 5 added, 2 folders created, "1
  feed was already in Kipple and was left as it is" (the PR #45 wording holds), top-level feeds in Uncategorized,
  the duplicate left in its original folder.
- TC-F3 **pass.** Re-import into the same instance: 0 added, 14 already present. Exported, imported into a second
  empty instance with `kipple import`, exported again: identical except that the two loopback test feeds lose
  `kipple:allow_private_net="1"`, which the import summary says it does on purpose (a private address is imported
  with that switch off). `kipple:interval` and `kipple:retention` survive the round trip.
- TC-F4 **pass.** Layout Cards, check every 2 hours and newest 50, set from the feed editor, plus a custom 100-minute
  interval on another feed, all survived a server restart; the feed opened in Cards.
- TC-F5 **pass.** Deleting a feed with 2 starred articles showed the count and the keep-starred default; both stayed
  in Starred under the old feed name and Stats lists the feed as "(unsubscribed)". See B2-8 for where the archive
  feed shows up.
- TC-R1 **pass.** All five layouts at 1400 px and at a 390 px phone: images through `/img/` and all loaded, no
  sideways scroll, no `undefined`/`NaN`/`Invalid Date` in lists. See the Cards and Email - Compact check below and
  B2-7.
- TC-R2 **pass.** Dense to Airy: the Settings preview's `--row-py`/`--row-min` equal the list row's values at every
  step, and the reading pane's line height goes 1.4, 1.5, 1.6, 1.7, 1.8 with the measure narrowing (664 to 571 px).
- TC-R3 **pass.** j/k select and open beside the list; s stars and unstars; m on the open article marks it read,
  it stays while open and leaves when you move off (wide), or leaves after 1.5 s (phone); z undoes; c toggles
  Compact and back; Enter opens; o/v opens the original in a new tab; u returns focus to the list; [ and ] change
  feed; Shift+G and g g scroll to the bottom and top (they scroll, they do not move the selection); g i/a/s/f/,
  navigate; `/` from Manage Feeds lands in the search box; `?` opens the overlay; r refreshes; { marks the rows above
  with an undo toast. The undo toast stayed about 13 s after the action.
- TC-R4 **pass.** Short list plus More themes and Accessibility themes, 20 radios matching `schemes.json`; every
  scheme applies; heading text contrast 7.8:1 (Cocoa Mid) to 21:1, secondary text 5.4:1 or better; Signal's danger
  token is `#a0006a`, Carbon is neutral near-black (18,19,21) and Fountain navy (19,40,79).
- TC-R5 **pass.** Follow system with Linen/Graphite picks switched Linen, Graphite, Linen as the color scheme
  changed, without a reload.
- TC-R8 **pass.** With a controlled clock: Paper at 20:59:50, Midnight after 21:00 without a reload; the first
  paint at 22:00 is already Midnight; across midnight it stays Midnight and turns Paper after 07:00 the next day;
  equal times keep Paper all day; picking Paper ends the schedule; a second signed-in browser (a new device) kept
  Follow system.
- TC-R6 **pass, auto-read partly.** A mute rule created in the UI, and mark-read, star and highlight rules, each acted
  on a new matching arrival (muted hidden from Unread and All, zebra read, walrus starred, "Pelican" marked in the
  list); Muted lists the article with "Muted by" and Restore brings it back unread; Filters shows "Matched 1 article"
  on the three counting rules. Auto-read preview on a fresh instance finds nothing, as expected (crawl time).
- TC-R7 **pass.** With 9 unread rows loaded, an arrival from another tab's refresh stayed unread after Shift+A while
  all 9 were marked read. The empty state reads "1 new article arrived. Load them above to continue reading." (B2-9).
- TC-S1 **pass.** `runner` finds "runners", `run` finds "running" and "runs" (11 results); the saved search appears in
  the sidebar with its count and re-runs to the same 11 results.
- TC-T1 **pass (short session).** Five articles read with scrolling plus earlier opens: Stats shows 7 items and 3 min
  in all four ranges, matching the API; per feed Go Blog 3, NASA 2, Ars Technica 1, UAT Local Two 1; folder rollup
  Dev seed 6 (4 feeds), UAT Local 1; Minutes toggle, never-opened list (9 feeds) and a 1-day streak all agree.
- TC-T2 **pass.** CSV, JSON and JSON Lines raw exports all carry the same 67 events and columns; the JSON summary's
  totals match Stats; with titles and links off, `item_title`/`item_url` are null on every row and no URL appears in
  the file; the data dictionary downloads as Markdown.
- TC-T3 **pass.** Delete a date range: "No events in that range" for January, "67 events will be deleted" for today,
  then a second "Yes, delete 67 events"; Delete all only enables on the exact `DELETE ALL`; Stats shows zeros after.
  Statistics off stopped recording and removed Stats from the navigation, on resumed it, both without a reload.
- TC-T4 **pass.** Your year shows a plausible summary; the share sheet copies the text (top sources and longest read
  only when switched on) and downloads `kipple-2026.png`, which looks right; a failing summary request shows "The
  server returned an error. Try again." and Try again recovers.
- TC-A1, TC-A2, TC-A3 **skipped.** They need a Reader API client on the owner's devices. As a substitute,
  the Reader API regression replay (below) was run by hand with curl against the instance: ClientLogin with the API
  password (the web password is refused), token, user-info, subscription/list with ETag (304 on a match, 200 after a
  change), tag/list, unread-count (244, the same as the unread ids), stream/items/ids paging (6 pages of 50, 275 ids)
  with `xt=read` and starred, stream/items/contents, edit-tag read/unread/star (seen by the web API at once),
  quickadd (the new subscription is in the next list call), subscription/edit move and unsubscribe, and
  mark-all-as-read on one feed with `ts` in seconds, milliseconds, microseconds and nanoseconds: each marked exactly
  the 6 items up to the cut and none after. All as expected; it is not a substitute for the real clients.
- TC-C1 **pass (negative case only).** An empty password is refused (401), also with a forged
  `Cf-Access-Jwt-Assertion` header. The positive case needs a real Cloudflare Access setup: blocked.
- TC-C2 **pass.** Generate API password asks for the web password, shows the new one once and copies it (24
  characters); it signs in on ClientLogin and lists 15 subscriptions; the web password gets `BadAuthentication`.
- TC-C3 **fail (P2, B2-1).** The export works: a zip with `kipple.db`, `feeds.opml`, `settings.json`, `RESTORE.txt`
  and `manifest.json`, and `kipple restore --yes` into another empty data dir verified the checksums and integrity
  (14 feeds, 252 items, 3 starred). But the Download backup dialog's "Made" row reads "Invalid Date".
- TC-P1 **pass.** Manifest standalone with scope and start `/`; 192, 512 and maskable 512 icons and the 180 px
  `apple-touch-icon` all load at their declared sizes; `viewport-fit=cover` and safe-area rules present; at 375 px
  no screen scrolls sideways (lists, Feeds, Search, Stats, Wrapped, Settings and its groups, Feed Health, an article)
  and the bottom tab bar sits at the bottom edge.
- TC-P2 **blocked (live update), static checks pass.** The built `sw.js` precaches every hashed asset the page loads,
  and `update()` runs on `visibilitychange` (`web/src/lib/offline.ts`). Headless Chromium does register and activate
  the worker (the desktop pane could not), but a simulated deploy could not be observed from a script; the live check
  stays with a real browser.

What changed since 2026-09-27:

- Settings in six groups **pass.** Bare `/settings` opens Appearance; each of the six addresses shows its
  group with the rail's current item marked; a rail click puts focus on the group heading. On a phone, `/settings`
  is the group list with "Paper / Midnight · Default font", the check interval and "Recording on" under their groups;
  a group opens on its own page with a back button, focus on its heading, and back returns focus to the group row.
  No sideways scroll in any group at 390 px.
- Cards card shell and Email - Compact **pass.** Cards has the raised, bordered card with an inset rounded image at
  1400 px and in the single phone column, where it is clearly different from Editorial. Email - Compact shows no
  favicon at either width; Compact shows one.
- Manage Feeds Edit and Select, folders **pass.** A plain visit shows no grips or pencils; Edit shows them, Select
  shows checkboxes, a range hint and a Select all / Move to folder / Delete bar. A folder collapsed on this device
  opens in Edit and Select and is collapsed again afterwards; collapsing is shared with the sidebar and works on a
  phone. Bulk move of 2 feeds and bulk delete of 1 did what the dialogs said. A favorited folder gets a chevron in
  Favorites in the sidebar and in Manage Feeds, sharing its state with the folder; Edit and Select show it as a plain
  row.
- Feed Health Select mode **pass.** With two feeds ticked and a search hiding one, the count reads 1 and Turn off,
  Turn on and Delete each acted only on the visible ticked feed; the header checkbox cleared only the visible one.
  See B2-5.
- Manage this feed **pass.** A list row's ⋯ menu opens the feed editor for that article's feed. See B2-6.
- Lead image by size **pass.** Test articles: a 300x100 crop before a 1200x800 photo, a `srcset` with 400w and 1600w,
  a 728x90 banner before a photo, and a 48x48 avatar before an unsized photo; each picked the photo (or the 1600w
  candidate), and the cards show them.
- "N new articles" only for a manual refresh **fail (P2, B2-2).** No pill for a scheduled poll (a controlled arrival
  fetched by the scheduler) or for a new feed's first fetch; a pill and announcement for a refresh from this or another
  tab and for Refresh all. But an OPML import shows the pill.
- Scroll restore **fail (P2, B2-3).** Coming back to a list you left does not restore where you were, and leaves gaps
  between rows.
- Mark as read while scrolling **pass.** Jumping from the top to the bottom marked only the 4 rows that were on
  screen at the top, none of the 36 skipped; scrolling down gradually marked the 13 rows actually scrolled past.
  Switching the setting off inside the 0.7 s settle window cannot be done from the UI with the list on screen (the
  switch is only in Settings), so that edge case was not exercised here.
- "Couldn't open this article" **fail (P2, B2-4).** With the server unreachable and the browser online, the screen
  shows Try again and Read the original, which opens the article's address in a new tab (phone and wide). With the
  browser itself offline it never gets there.
- Check interval labels **pass.** A 100-minute per-feed interval reads "Every 1 hour 40 minutes" in the feed editor,
  and a global 100 minutes shows the same under Sync & Feeds in the phone group list.
- Hacker News showed "Having trouble" for most of the run: the feed timed out from here, which is not a Kipple defect.

Defects:

- **B2-1 (P2)** Backup dialog "Made: Invalid Date". Steps: Settings, Account & Devices, Export backup. Observed:
  the summary's "Made" row says "Invalid Date". Expected: the time the backup was taken. Cause seen in the code:
  `manifest.created_at` is an RFC 3339 string and `AccountSection.tsx` passes it to `fullDate()`, which expects Unix
  seconds. Suite 1's S5 check never opens this dialog, so it cannot catch it.
- **B2-2 (P2)** The "N new articles" pill fires for an OPML import. Steps: open All articles; import an OPML with one
  new feed (Manage Feeds > Import OPML, or `POST /api/opml` from another tab). Observed: within about 1 s the list
  shows "20 new articles" and the status region announces it; the only feed fetched in that window was the imported
  one. Expected: no pill and no announcement for an import run (changelog #56 and #79).
- **B2-3 (P2)** Returning to a list leaves gaps between rows and the wrong position. Steps: open a feed's list with
  30 or more text-only rows (Editorial), scroll about 2200 px, go to Settings, then Back. Observed: rows measured 158 px
  tall (170 px on a phone) are placed 190 px apart, so about 30 px of blank space shows between rows, and the row
  that was at 154 px from the top is at 865 px (176 to 579 px on a phone), so the reader lands 2 to 4 rows above
  where they were. The gaps stay on the rows mounted at return, even after scrolling; rows rendered later are spaced
  correctly. It happens with or without new arrivals. Expected: the rows sit where they were, without gaps.
- **B2-4 (P2)** Offline, an article not already loaded never finishes loading. Steps: with the browser offline (the
  offline banner showing), open an article from the list. Observed: a loading skeleton for as long as it was watched
  (25 s): no "Couldn't open this article", no Try again, and on a phone no top bar or back button, only the offline
  banner, so an installed PWA has no visible way back. Expected: the error screen with its back button (Read the
  original is moot offline, but Try again and back are not).
- **B2-5 (P3)** Feed Health: after a bulk Delete, Select mode stays on and a feed ticked earlier but hidden by the
  search stays ticked ("1 selected" when the search is cleared); after Turn on or Turn off, Select mode ends and the
  ticks clear. The "Deleted 1 feed" toast also covers the middle of the selection bar.
- **B2-6 (P3)** "Manage this feed" is only in a list row's ⋯ menu. The open article's own ⋯ menu (the reader
  toolbar) has only Open original and Mute similar…, so on a phone it cannot be reached from the article you are
  reading.
- **B2-7 (P3)** The list header's title truncates at desktop widths: "Al…" for All articles in Email - Compact at
  1400 px, "UAT Local …" in Editorial, and the same in Cards, where the list below is full width.
- **B2-8 (P3)** The archive feed "Unsubscribed (starred)" is listed in the sidebar under the default folder with a
  count, while Manage Feeds leaves it out and `docs/design.md` calls it hidden. Owner's call whether the sidebar row
  is wanted as the way to reach it.
- **B2-9 (P3)** The empty state after Shift+A says "1 new article arrived. Load them above" (plural pronoun for
  one); related to issue #44.

Filed 2026-09-29 as issues #92 (B2-1), #93 (B2-2), #94 (B2-3), #95 (B2-4), #96 (B2-5), #97 (B2-6), #98 (B2-7), #99 (B2-9)
and #100 (B2-8, the owner's call). None is P0 or P1, so the soak clock is not affected.


----

**Passed 2026-09-27** (owner feedback). Owner: "all Suite 3 testing seems to indicate 'pass'
from my phone." Covers TC-D1 through TC-D4 as exercised in ordinary daily use of the beta build, not a
one-time scripted pass. TC-D4 closes risk-register R1 (moved to Closed as C4) and issue #30.


----

**Executed 2026-09-27.** Copied the live nightly snapshot (`kipple-snapshot.db`, taken 04:10 that day, schema 8,
138 feeds, 6594 items) off the running container with `docker cp` (never touching `kipple.db` itself), restored
it onto a brand-new throwaway volume with the currently-deployed image (`kipple:local`):
`kipple restore` reported the backup passed its integrity checks with no previous database to keep. Starting a
throwaway container against that volume also exercised a real migration rehearsal for free, the snapshot was
one migration behind the live schema, so startup applied `0009_stats_summary_indexes.sql` automatically,
confirmed by the log line, and the container came up `(healthy)` on `/healthz` immediately after. The live
`kipple` container was never stopped, restarted or otherwise touched throughout (verified via `docker ps`
before and after). All throwaway artifacts (test container, test volume, copied snapshot file) were removed
afterward. Both TC-C3 and the standing migration-rehearsal checklist item are satisfied by this one drill.

**Re-executed 2026-09-29** (image built from the beta tag). Two restores
of real snapshots, each onto its own brand-new throwaway volume with the deployed image, each followed by a throwaway
container on that volume (no published port, 128 MB cap). Nothing touched the live `kipple` container (same container
id and start time before and after), the `kipple` volume or `kipple:local`; the snapshots were copied to a scratch file
first (never `kipple.db`), and every throwaway container, volume and file was removed afterwards.

- **Latest snapshot** (nightly, 04:10 that day): `kipple restore` reported schema 9, 135 feeds, 8,525 items, passes
  the integrity checks, 3 web sessions signed out, no previous database to keep. Container healthy after about 8 s, no
  migration needed (beta.1 to beta.2 has none), `kipple healthcheck` ok. The database read back out of the volume
  passes `PRAGMA integrity_check` with 135 feeds and 8,525 items.
- **Migration rehearsal** (the schema-8 copy taken before the beta.1 deploy): restored as schema 8, 138 feeds, 6,594
  items. Starting the beta.2 image applied `0009_stats_summary_indexes.sql` in the startup log, wrote
  `pre-migration-8-9-<ns>.db` (70,684,672 bytes, `0600`) into `/data/backup` first, and was healthy about 8 s later; the
  migrated database passes the integrity check with the same counts.
- **Restore over an existing database:** `kipple restore` onto a volume that already held a database moved the old one
  to `/data/backup/pre-restore-20260929-194812Z`, restored, and printed how to undo it.
- Result: TC-C3's restore half, the standing migration-rehearsal item and the restore drill all **pass** on beta.2.


----

**Status.** Executed 2026-10-03 against a published prerelease image on the owner's Linux server (Docker Engine, amd64), with throwaway
containers and volumes on their own ports, the live instance untouched, everything removed afterwards. Driven with `curl`
against the published API, so the browser-only steps (A3, A8 to A12, B1's wording, B3's reload) were not repeated by hand:
the wizard script (`npm run uat:wizard`) covers them against a source build.

- **A1** pulled anonymously and the digest equals the release notes; healthy in about 25 s. **A2** exactly one `no account
  yet` line. **A4** `GET /api/bootstrap` 401, login 409 `setup_required`, `/healthz` 200. **A5** restart: the same one line,
  setup still open. **A6** two simultaneous claims: one 201 with a cookie, one 409 `already_set_up` with none. **A7** a
  4- and 5-character password refused (400, with the reason) and a 6-character one accepted, the minimum then; since
  rc.2 it is 8 (the wizard flow covers it). **A13** the setup route
  answers 404 afterwards. **A14** restart with an account: normal mode, no `no account yet` line, healthy.
- **B** (open mode, over the API): no acknowledgement gets 400 `ack_required`; with it the account is created; an unexpected
  `Host` gets 421; a forwarded header gets 403; a request from the Docker bridge is admitted silently (204).
- **C** `gh attestation verify` on the image succeeds and names this repository's `release.yml` at the release tag; `cosign`
  itself was not installed, so the deploy guide's exact `cosign verify` line was not run.
- **Also:** the container runs read-only as uid 65532 with all capabilities dropped (compose file); a bind mount without the `chown`
  fails with `data dir lock ... permission denied`, as the deploy guide says.
- **Not run:** Run D (arm64; no arm64 machine), Run E (the tag was built from source with Docker alone for the deploy, and
  reports the release tag), the Reader API client connection (Settings, Account & Devices) and the manual browser steps above.
- **Findings:** none. One note: the `no account yet` line says the container "listens on :1919", which is the in-container
  port, not the published one.

### Prior runs (the pre-wizard Quickstart)

Kept as history; the steps above replace that walkthrough.

**Executed 2026-09-27.** Fresh `git clone` of the public repo into an isolated throwaway location (a separate
container name, image tag and volume, so it couldn't collide with or affect the real deployment), following
only `README.md` as it existed before this run, no other context. Finding: `README.md` had no concrete
clone-to-login sequence, and `docker-compose.example.yml`'s own top comment told the reader not to run it
standalone and to see `CLAUDE.md` instead, which isn't written for outsiders. Working it out by convention
(`cp .env.example .env`, `cp docker-compose.example.yml docker-compose.yml`, set `KIPPLE_PASSWORD`,
`docker compose build && up -d`) worked cleanly, all 9 migrations applied, the account was created, `/healthz`
passed, and a login (verified via the API directly: `Origin` header and `X-Kipple-Client: web` are required,
same as a real browser sends) returned an authenticated session. So the underlying path was never broken, just
undocumented for a newcomer. Fixed: `README.md` gained a Quickstart section with the exact sequence that
worked, and the compose example's comment now says it works standalone. Everything (container, image, network,
volume) was torn down afterward; the live production container was confirmed untouched throughout.

**Re-executed 2026-09-29 on `main` at `c4124c0` (beta.2 plus the screenshot tooling).**

A fresh `git clone` of the public repository on a Docker host, following the README Quickstart verbatim
(`cp .env.example .env`, `cp docker-compose.example.yml docker-compose.yml`, set `KIPPLE_PASSWORD`, `docker compose
build`, `docker compose up -d`). The only departures are isolation from the real deployment on that host: a different
container name, a loopback port, a different image tag and a compose project name (`-p`); the test password was a
throwaway value.

- **Pass.** Build succeeded; the container was healthy within about a minute of starting; `healthz` 200; a login with
  the default username `owner` and the password from `.env` returned 204 (with the `Origin` and `X-Kipple-Client: web`
  headers a browser sends) and `bootstrap` 200; `kipple import -` accepted an OPML on standard input (one folder, one
  feed); `kipple api-password` printed a new Reader API password once; the backup export answered 200 with a summary of
  the contents (schema 9, 1 feed); the container ran read-only as uid 65532 with the 256 MB cap from the compose file.
- **Finding, P3:** a Quickstart build reports version `dev` (`kipple version`, the backup's `kipple_version`) because the
  Quickstart does not pass `KIPPLE_VERSION`/`KIPPLE_VCS_REF`; the compose file's comment explains it, the README does not.
  A newcomer cannot tell which release they are running. The planned published image would settle this; until then a
  one-line note in the Quickstart is enough.
- Torn down afterwards (`down -v`, image removed); the live container was untouched. Suite 5 must be run again once the
  setup-wizard work changes the Quickstart.
