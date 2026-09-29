# Soak-period reports, 2026-09-28 to 2026-09-29

The one-week beta.1 soak began on 2026-09-27 at 21:42 ET, when the owner started using the deployed build as his
daily reader. These are the defects he reported from that use, in order. The rule for the soak is in
`docs/RELEASING.md`: a real regression resets the soak clock; the fixes go out in the next beta (beta.2, not rc.1).

Where the owner's own words are in the session transcripts they are quoted lightly. For #78 and #86 the reports
reached the agent outside the transcripts read for this record (the issue text says only "reported by the owner
during the beta.1 soak period"), so those two are described from the issues, not quoted.

| Report | Issue filed (ET) | Issue | Fix PR | Fix merged (ET) |
|---|---|---|---|---|
| Fuzzy card thumbnails on some feeds | 2026-09-28 11:42 | #71 | #75 (then #76 for two regressions in it) | 2026-09-29 07:52 (#75) |
| Stale scroll position and unread articles marked read on entering a category | 2026-09-28 15:51 | #72 | #74 (then #77) | 2026-09-29 07:51 (#74) |
| Offline: "read the original" does nothing on a failed article load | 2026-09-29 08:37 | #78 | #80 | 2026-09-29 11:15 |
| A favorited folder cannot be collapsed or expanded | 2026-09-29 12:18 | #86 | #87 | 2026-09-29 13:09 |

## #71: fuzzy card thumbnails (2026-09-28, 11:42 ET)

The owner sent a screenshot of a Cards-layout card (a news story about curbside electric-vehicle charging) and asked:
"Open an issue for the screenshot above. Fuzzy images from various feeds." The photo itself was fine at native size but
looked mushy and upscaled in the card. The agent filed #71 with two suspected causes and no root cause yet: the card's
fixed-ratio image box stretching a small source past its native size, and the thumbnail pipeline only ever
downscaling (a source narrower than the 800 px target reaches the browser at native size and is then stretched). It
asked whoever picked it up to compare the image's natural size with its rendered size first. It could not attach the
screenshot (the CLI cannot upload issue images) and described it instead.

Outcome: PR #75 (opened 2026-09-29 07:40) changed the lead-image picker to choose by size (the largest `srcset`
candidate or declared width and height) instead of the first `<img>`; the changelog names a small fixed-size crop
ahead of the real photo as the case it fixes. That fix then had two regressions found by the same day's review (a naive `srcset` comma split, and an unsized hero losing to a
tiny sized image) and a third gap (wide short banners beating the hero), all fixed in PR #76. See
[../audits/review-high-2026-09-29.md](../audits/review-high-2026-09-29.md).

## #72: stale scroll position (2026-09-28, 15:50 ET)

"Another issue to add, if I click a category that has new articles, it keeps me in the old spot, and marks the new
articles as read. It should scroll me to the top of the screen when new articles come in if I've manually refreshed
(or clicked the N new articles button)." The agent found the cause in the list's scroll restoration, which restores a
raw pixel offset: when new items were prepended above the saved position the same offset pointed at different rows,
and with mark-read-on-scroll on (it is off by default) the newly arrived rows sat above the viewport and counted as
already scrolled past. The pill's own "show new" path was already correct; the gap was entering a scope from
outside.

Outcome: PR #74 (opened 2026-09-29 07:35): entering a list whose data changed no longer restores the old offset, and
mark-read-on-scroll no longer marks rows never rendered. The morning review found three defects in that fix (the staleness check ran
once against possibly stale cached data, the seen set included the virtualizer's overscan rows, and it was lost on
remount), fixed in PR #77 together with two more found in the second review (a snap-to-top check that never
disarmed, and a flush after the setting was turned off).

## #78: offline "read the original" (2026-09-29, 08:37 ET)

From the issue: when an article fails to load, for example because the server is unreachable, the error screen said
"The article couldn't be loaded. You can read the original instead." but showed only a "Try again" button, which
just retries the failed fetch. There was no way to open the original. Cause: the article pane's error branch never
rendered an open-original action at all; the sentence promised something that did not exist. Fix (PR #80, merged 11:15 ET): a "Read the original" button using the article's URL from the list's cached card, which is normally still there
when the detail fetch fails; the body text is conditional on whether that link can be offered, so it never promises
what it cannot deliver. A test covers both buttons and was proved to fail without the fix.

## #86: a favorited folder cannot be collapsed (2026-09-29, 12:18 ET)

From the issue: in the sidebar and in Manage Feeds, a folder pinned to Favorites was a plain link row with no chevron
and no feeds under it. Fix (PR #87, merged 13:09 ET): the favorited folder gets the same chevron and lists its feeds
beneath it, sharing the folder's per-device collapsed state with the Feeds list, so collapsing it in either place
collapses both; folders start expanded. In Manage Feeds, Edit and Select mode keep favorites as plain rows, as they do
for the main folder list. The sidebar chevron became one shared `CollapseToggle` component after a review finding.

## Still open from the soak

- #57 (list-layout differentiation) and #62 (tab-bar seam): the fixes are merged; the owner said at 11:57 ET on
  2026-09-29 "I'll do the phone pass", and the two issues close on his word.
- The soak clock: reset by these fixes; the next promotion step is beta.2 (see the release-readiness record), not
  rc.1.

## Other owner direction in the same period (not defects)

- README (2026-09-28 morning, on PR #67 and the reworks after it): "Stop obsessing over the word 'list'"; the About
  section should be "just have a quote about Kipple", first after the badges; remove all references to other
  products ("This isn't a comparison tool"); add Semver, repo-size and Docker-image-size badges; and Wrapped needs a
  caveat that it is opt-in and not shared unless the reader shares it. He also objected that phrases such as "a second client for free" made no sense, and that the draft read as
  "inauthentic". These shaped PR #69.
- Parking lot (2026-09-28 08:08 ET): "all config file settings must be moved to the app itself. Users should not have
  to configure a file to run this. It should all be handled in-app. This may require a setup flow."
- Process (2026-09-29 13:53 ET): "Updating kipple-history should be part of your workflow, at the very least daily"
  (after noticing there were no entries from Sunday). It is now a rule in the Kipple `CLAUDE.md`.
- Changelog (2026-09-29 morning meeting, and again at 11:57 ET): the recurring `CHANGELOG.md` merge conflicts had to
  stop; "begin the changelog retooling. Take that all the way through please." Delivered as PR #85.

## 2026-09-29 evening

- Owner's confirmation after his phone pass of beta.2: #57 and #62 fixed and closed.
- Owner's direction after the UAT re-run: "Fix all defects", as the next beta or an X.X.1 release; and on the archive feed:
  "If someone unsubscribed from a feed, it shouldn't show up anywhere." (issue #100, fixed in beta.3). Not yet
  confirmed on his devices: how Reeder and NetNewsWire treat archived starred items after the Reader API stopped listing
  the archive feed.
