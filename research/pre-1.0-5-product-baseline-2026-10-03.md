# Kipple product baseline vs 1.0 expectations (2026-10-03)

## Web evidence (paraphrased)
- selfhosting.sh best-of list (https://selfhosting.sh/best/rss-readers/): selection criteria are mobile-app (Reader/Fever API) support, per-feed refresh intervals, full-text search, OPML import/export, low resource use. Comparison grid also lists keyboard shortcuts, built-in full-text scraper, folders/categories/tags, filter rules, podcast playback.
- FreshRSS vs Miniflux (https://selfhosting.sh/compare/freshrss-vs-miniflux/, https://ossalt.com/guides/freshrss-vs-miniflux-2026): Miniflux wins on speed/minimalism and ships 20+ built-in integrations (Wallabag, Pinboard, Instapaper-class); FreshRSS wins on extensions, themes, WebSub. Miniflux criticisms: minimal customization, no extensions, no WebSub. Both work with Reeder, NetNewsWire, Fluent Reader.
- Migration: OPML carries subscriptions and folders only, not starred or saved items; users report no reader exports stars and that Inoreader offers a JSON path (https://discourse.netnewswire.com/t/possible-to-move-full-article-state-between-services/331, https://feeder.co/knowledge-base/rss-basics/opml-file/, https://feedviewer.app/answers/how-to-export-import-feed-lists-between-rss-readers). Feedly exports OPML only from its web app at feedly.com/i/opml.
- Common OPML complaint: imports that skip folders, no export at all (Vivaldi forum, https://forum.vivaldi.net/post/490729).
- Client landscape: Reeder, NetNewsWire, Lire, Fluent Reader, ReadKit all use the Reader API against FreshRSS/Miniflux (https://discuss.privacyguides.net/t/rss-reader-recomendation/10989.md).
- Power-user wishlist: tags/labels, filters, YouTube/Reddit as plain feeds, podcast player, read-later hooks (https://selfhostyourself.com/tags/feed-reader, https://jisaku.com/glossary/rss-reader-reeder-netnewswire-feedly-inoreader-news-2026). Reddit and r/rss search results were thin; forum evidence is weak, so this is conservative.

## Feature table (Kipple state)
| Baseline | State | Proof |
|---|---|---|
| OPML import, folders preserved, mark-old-as-read option | PRESENT | internal/opml/import.go, web/src/screens/feeds/OpmlDialog.tsx, setup wizard ImportStep.tsx, CLI `kipple import`, docs/deploy.md "OPML import and export" |
| OPML export (folders) | PRESENT | internal/opml/export.go, FeedsScreen "Export OPML", `GET /api/opml`, design.md item 34 |
| Nested folders in OPML | PARTIAL (flattened to one level; Reader labels are flat) | design.md sec 2 comment ~line 296 |
| Import from yarr/Miniflux/Feedly/Inoreader | PARTIAL (via their OPML only; no docs naming each reader or how to export from it) | README only says "from your old reader"; no per-reader guide |
| Starred/saved items | PRESENT | star state, "read later is starred" design.md 1907 |
| Export or import of starred items / article state | ABSENT (only whole-DB backup zip; no JSON/HTML starred export, no import of stars) | design.md 731, docs/deploy.md 95-110; CLI has only import/restore/version (cmd/kipple/main.go) |
| Data portability / backup and restore | PRESENT | Settings > Account > Export backup zip (db, OPML, settings.json, manifest), `kipple restore` |
| Full-text search, saved searches | PRESENT | FTS5 design.md; SearchScreen.tsx, SaveSearchDialog |
| Keyboard shortcuts | PRESENT | web/src/lib/keys.ts (j/k, m, s, o, v, gg/G, A, f, brackets, ? help) |
| Folders | PRESENT | feeds.folder_id, FeedTree.tsx, FeedEditor Folder field |
| Tags/labels per article | ABSENT (deliberate: Reader labels = folders) | design.md 1458, 1644 |
| Mark all read, above/below, undo, auto-read catch-up | PRESENT | keys.ts markAll/markAbove/markBelow/undo; AutoReadCatchUp.tsx |
| Full-text extraction (per feed, per article, global) | PRESENT | design.md item 19, `fetch.fulltext_all`, internal/extract |
| Filters/rules | PRESENT for basics (FiltersSection, FilterEditor); extensions parked #38 | web/src/screens/filters/, CHANGELOG 0004 migration |
| Podcast/media | PARTIAL: enclosures stored and served but the web UI never renders them (types.ts `enclosures: unknown`, no player); only in-content audio/video survives sanitizing; text-to-speech ListenBar exists | design.md 168, 939; ListenBar.tsx |
| YouTube | PARTIAL (works as a plain feed, embeds click-to-load, privacy-enhanced iframe) | design.md 940, 2044, 2063 |
| Reddit | PRESENT as plain feeds; UA fallback `browser_on_failure` | design.md 925 |
| Feed discovery from a page URL | PRESENT | internal/discover, AddFeedDialog.tsx |
| Per-feed settings (interval, retention, UA, layout, auth) | PRESENT | FeedEditor.tsx |
| Share / bookmarklet / subscribe-from-browser (web+feed, PWA share target) | PARTIAL: native share and copy link on articles only; no bookmarklet, no manifest share_target, no protocol handler | web/src/lib/share.ts; web/public/manifest.webmanifest |
| Mobile | PRESENT (PWA, offline reading, gestures, mobile layouts) | README, phase 3 |
| Reader API clients | PRESENT for Reeder, NetNewsWire; designed for FeedMe, Readrops; others untested in docs | design.md 1380-1416; uat-plan only names two |
| Integrations (Wallabag, Instapaper, Readwise, Pocket, webhooks) | ABSENT | no mention anywhere; Miniflux has them built in |
| i18n | ABSENT (English only, `<html lang="en">`) | web/index.html |
| Accessibility | PRESENT (WCAG options, reduced motion, high contrast schemes, dyslexia font) | docs/ui-decisions.md section Accessibility |

Note: the brief lists stats screen (#37) and filters UI (#38) as parked, but a StatsScreen, WrappedScreen and a filters settings section already ship; the parked items are the follow-ups.

## First-week traps for a stranger
1. Leaving a reader: no way to take starred items out except the SQLite-bearing backup zip. Competing readers mostly lack this too, so it is a differentiator rather than a blocker, but a stranger who stars heavily will notice.
2. Coming in: no per-reader migration instructions (Feedly web-only OPML URL, Inoreader, Miniflux, yarr). Stars and read state cannot come in; this must be stated, not discovered.
3. Podcast feeds: episodes appear with no audio player (enclosure not rendered). Probably the most visible functional hole.
4. Nested folders flattened on import: users with nested Inoreader/Feedly categories will see a flattened tree (verify the report says so; OpmlResultSummary lists skipped and merged items).
5. No read-later hooks: Miniflux users arriving from Wallabag/Instapaper setups lose that workflow.

## Recommendation
Do not add a feature release for integrations, tags, i18n, bookmarklet or filter extensions: those are either non-goals-adjacent, parked, or not table stakes for a single-user reader. Conservative call: a small 0.8.0 is justified only for the two table-stakes gaps with a clear root cause.
- 0.8.0 contents: (a) render enclosures in the article view as a native audio/video element (or link list), with the URL going through the existing safe-URL rules (no new setting); (b) a starred-articles export (JSON or HTML, one endpoint plus a button next to Export OPML) so "getting data out" is complete. Optional, docs-only: a migration page per reader (Feedly, Inoreader, Miniflux, yarr, NNW) stating what carries over (feeds, folders) and what does not (stars, read state).
- If the owner rejects code changes, go to rc.1 with the docs-only migration page and a README line that podcasts are not played inline. The docs page is cheap and should ship either way.
- Explicitly not in 0.8.0: integrations, tags, i18n, bookmarklet/share target (revisit post-1.0), nested folders.
Confidence: medium. Forum evidence was thin; the repo evidence is solid.
