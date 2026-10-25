# Design review 1.5, Phase 5 (recapture and compare)

Recaptured with `design-shots` on main at `e6954b1c` (the 1.5.0 release code) against the Phase 0 baseline: 37 surfaces, 246 captures, none missed (Phase 0: 246, none missed). Nine more surfaces the script does not list (New page, Digest, Coffee break, Feed index, week, none and day grouping) were captured separately: 54 shots, none missed. No surface is broken. Only Paper and Midnight were captured; tablet and desktop at text sizes 0.875 and 1.5 and the other 18 themes were not looked at.

## What changed for the better

- A failing feed names its cause, when it last worked and when Kipple tries again, with Edit address and Try now.
- The article shows real bullets and numbers and one heading scale; the toolbar has Share and More last, with Mark as unread inside it.
- A New tab and New page, an unread count in the list header, feed icon tiles, a star on compact rows, and Digest, Coffee break and Group by in the list options.
- Settings are regrouped with "All devices" and "This device" tags; Advanced and About show content (Phase 0 caught them as skeletons); sign-in has Show password.
- Stats and Your year are calmer; search results are a compact list with a query hint.

## Regressions and carried items (now unticked lines on the area trackers)

1. The tab bar's active indicator cuts the top edge of the "99+" badge on Articles (phone and tablet).
2. At text size 1.5 on a phone the filter tabs wrap to two rows (the New tab) and the header takes about 30% of the screen.
3. Appearance at text size 1.5 on a phone: the size buttons clip and the theme cards put one word per line (unchanged since Phase 0).
4. In a long article on a phone a table's Notes column wraps one word per line over 7 lines (4 before).
5. The List options sheet on a phone is taller than the screen; Group by is below the fold.
6. Digest, Coffee break, New page and Feed index rows run the full pane width on tablet and desktop, so thumbnails sit far from the title.
7. Cards fit odd-shape lead pictures inside a white or black mat (deliberate in #662; the mat is a judgement call).
8. Empty states are unchanged: small text at the top of a blank pane.
9. Small items: Coffee break says "More" in one section and "12 more" in another; a failing feed's card says its retry time twice; the sync-app address wraps mid-word on a phone; a single-feed header with a long name shows only its first words; selected segmented buttons are weaker than before.

Capture caveat: the first phone pass had a cold image cache, so two list captures show blank thumbnails; retakes are fine. Article captures open the first article, which marks it read, so row counts differ from Phase 0.