# What "1.0" means, and how comparable projects did it (researched 2026-10-03)

Confidence notes: pages marked (read) were fetched and summarised by the fetch tool; (search) means a search snippet only. Navidrome, Vaultwarden, Paperless-ngx 1.0, server B 1.0, Actual and Linkding yielded no primary 1.0 post; they are listed as gaps rather than guessed.

## (a) Specs

SemVer 2.0.0 (https://semver.org/, read):
- 0.y.z is initial development, anything may change. 1.0.0 "defines the public API"; after that, compatibility is kept for features and fixes, and only incompatible changes bump major.
- Deprecate first: document it, ship a minor that carries the deprecation, remove in the next major.
- Pre-releases sort below the release and carry no compatibility guarantee.
- FAQ: release 1.0.0 when the software is in production use and has a stable API users depend on. If you ship a breaking change by mistake in a minor, fix it at once with a new minor that restores compatibility. If the API changes daily, stay at 0.y.z.
- The spec never says what the "public API" is. The author must declare it. That is the real 1.0 work for Kipple.

Keep a Changelog 1.1.0 (https://keepachangelog.com/en/1.1.0/, read): six change types (Added, Changed, Deprecated, Removed, Fixed, Security); newest first, dated, an Unreleased section; yanked releases get a [YANKED] tag; say whether you follow SemVer; breaking changes must be prominent. Kipple's fragment-based flow already satisfies this. It has no Deprecated-then-Removed habit and no YANKED convention written down.

What a 1.0 commitment implies for Kipple (my reading, not a source):
- Public API: Google Reader endpoints under /api/greader.php as clients (client A, client B) use them; HTTP/web UI routes are not API unless declared.
- Data format: SQLite schema is internal but migrations must be forward-only and safe; the backup zip/snapshot format and `kipple restore` are the user-facing data contract.
- Settings keys and env vars (KIPPLE_*): once 1.0, rename or removal needs deprecation then major.
- Docker tags: X.Y.Z immutable (already done); `latest`, `X`, `X.Y` start meaning something only after a stable tag exists. Document that 1.x pulls on `1` are safe.
- Go's model (https://go.dev/doc/go1compat, read) is the best template: promise covers a named surface, and explicitly excludes security fixes, bugs, unspecified behaviour, internals. Kipple should write the same two lists.

## (b) Case studies

Go 1 (https://go.dev/blog/go1, https://go.dev/doc/go1compat, https://go.dev/doc/devel/release, read). Released 2012-03-28. Before it, the team deliberately landed all planned incompatible cleanups (package reorg, time, error type, go command) and shipped a migration tool (go fix). Promise written as a document with explicit exclusions. After: go1.0.1 on 2012-04-25 (escape-analysis memory corruption), 1.0.2 on 2012-06-13 (map key bugs), 1.0.3 on 2012-09-21. Roughly monthly patches, then quieter. Lesson: even the most careful 1.0 had a memory-safety bug in month one; the compat promise excludes bugs.

Rust 1.0 (https://blog.rust-lang.org/2014/12/12/1.0-Timeline/, https://blog.rust-lang.org/2015/02/13/Final-1.0-timeline/, https://blog.rust-lang.org/2015/04/03/Rust-1.0-beta/, https://blog.rust-lang.org/2015/05/15/Rust-1.0/, read/search). Alpha 2015-01-09 (feature-complete, breaking changes still allowed), beta 2015-04-03 (everything shipping marked stable, no breakage unless severe, only testing/bugfix/polish), release 2015-05-15, six weeks after beta. Feature gating via release channels enforced the promise mechanically. Six-week train started at once. Same shape as Kipple's alpha/beta/rc, with a hard "beta changes no stable surface" rule.

Immich 2.0.0 (https://immich.app/blog/stable-release, https://github.com/immich-app/immich/releases/tag/v2.0.0, https://github.com/immich-app/immich/releases/tag/v1.136.0, https://immich.app/blog/2024-year-in-review, read). Stable on 2025-10-01 after years of weekly 1.x releases. Target had been Q1 2025, so it slipped about 6 months. Breaking changes counted down: 12 in 2023, 8 in 2024; v1.136 said it was among the last before stable (absolute media paths, API-key scope). Their stated blocker was fundamental mobile sync/timeline/upload rewrites: "can't honestly call it stable" before. Promise: SemVer, any v2.x mobile app works with any v2.x server. v2.0.0 itself was a no-op upgrade (compose pull and up); the breaking work was front-loaded into 1.x. Blog still pushes 3-2-1 backups. Lesson: spend breaking changes before 1.0, make 2.0.0 boring.

Jellyfin 10.11 (https://jellyfin.org/posts/jellyfin-release-10.11.0, https://jellywatch.app/blog/jellyfin-10-11-ef-core-migration-chaos-lessons-learned-2026, https://jellywatch.app/blog/jellyfin-version-12-0-versioning-change-roadmap-2026, read; the jellywatch pages are third-party commentary, not the project). Not a 1.0 but the best pitfall case. First "stable" 10.0.0 in Jan 2019 only because the fork inherited Emby's numbering. 10.11.0 (Oct 2025) replaced raw SQLite with EF Core: six months of dev plus six months of RC (twice their usual), and still failed for many users on real-world library sizes and odd legacy data; 10.11.1 fixed migrations, 10.11.2 performance, point releases continued through 10.11.11. Advice to users: full manual backup, wait for first point release. Project is now considering skipping 11 and calling the next release 12.0 because a minor number hid a disruptive change (April 2026 article). Lessons: a small RC tester pool cannot reproduce scale and legacy-data edge cases; a version number that understates risk costs trust; a migration needs an automatic rollback copy (they wrote library.db.old).

Mealie 1.0.0 (https://github.com/mealie-recipes/mealie/releases/tag/v1.0.0, https://docs.mealie.io/changelog/v1.0.0/, read/search). Betas from about March 2022 (beta of 2022-05-22 still fixing v0.5 migration), release candidates through 2023, v1.0.0 on 2024-01-20: roughly two years of beta/RC. Required before 1.0: migration from v0.5.6 working (separate guide, backup stressed; "believe we've fixed all the migration issues" seen in RCs). After: promised more frequent releases and the return of the `latest` tag; steady releases since (3.28.0 on 2026-09-24). Regret visible in the record: a very long pre-release period where users ran betas as production and `latest` was withheld. Lesson: the migration from the old data model was the entire blocker. Kipple has no old-version cohort, so this is smaller for it.

Forgejo (https://forgejo.org/docs/v1.19/user/semver/ and search result, search). Adopted real SemVer at 7.0.0 after 1.19, 1.20, 1.21 each contained breaking changes under a non-semver scheme. Their promise names the surfaces: CLI, REST API, GUI. Lesson: they had to restart the numbering to get an honest signal; Kipple choosing to promise less, explicitly, is the cheaper route.

server B ((link removed) read). v2 was a full Go rewrite on 2018-01-11; no 1.0-style stability ceremony found. Useful as a reminder that the closest comparable (Go, SQLite/Postgres, Google Reader/Fever API) reached long-term stability by shipping small, boring releases, not by a gate list.

Home Assistant (search, https://community.home-assistant.io/t/stable-release-versions/686912): no 1.0; calendar versions, monthly release with a one-week beta, breaking changes listed in release notes. Evidence that a short beta plus loud breaking-change notes can work at huge scale, but they have a large beta population.

Linkding: v1.0.0 labelled "initial stable release" (search, releasealert listing). No criteria published. Vaultwarden: 1.0.0 on 2020-10-25 per a third-party role listing (search); no primary criteria found. Navidrome: still 0.x at 0.56.1; no maintainer statement found. Paperless-ngx: v2.0.0 got 2.0.1 within the first week for small fixes (search, low confidence). Actual Budget: nothing found. These show the common pattern: many small self-hosted projects either never declare 1.0 or declare it with no ceremony.

Jellyfin/Mealie/Immich show the same thing: the real 1.0 blocker is always a data-model change that was pending, never polish.

## (c) Common pitfalls (synthesised from the cases above; no single source)

1. A pending data migration at 1.0 (Mealie 0.5, Jellyfin 10.11). Fix: do it before, and keep an automatic pre-migration copy (Kipple already writes pre-migration-<old>-<new>-<ns>.db).
2. Version number understating risk (Jellyfin, Forgejo). Fix: write the compatibility surface down.
3. Promise too wide (Go excludes bugs, unspecified behaviour, security, tools). Fix: a short "not covered" list.
4. Small tester pool, so RC finds only what the testers do (Jellyfin). Real-world data volume matters more than weeks.
5. First patch within 1 to 4 weeks is normal (Go 1.0.1 at 27 days; Paperless 2.0.1 within a week; Jellyfin 10.11.1). Plan for 1.0.1 and do not treat it as failure.
6. Breaking changes left for 1.0 or just after (Immich counted them down first).
7. Docs gaps: upgrade, backup, restore, and what "stable" covers.
8. Slipping dates: Immich 6 months, Mealie two years.
9. Support load on `latest`/floating tags; mislabelling `latest` as stable (Mealie withheld it).

## (d) Soak length and credible single-user evidence

Observed betas/RCs: Rust beta 6 weeks (alpha to release about 4 months), Jellyfin RC 6 months (twice normal), Home Assistant beta 1 week (large crowd), Mealie months to two years, Immich long public beta of the sync rewrite. Kipple's 1 week + few days is at the short end, appropriate only because there is one user. I found no primary source giving an industry-standard length; length tracks tester count and data diversity.

Credible evidence for one dogfooder, in my judgement:
- Calendar time with real feeds covering the periodic events: at least one full backup/restore rehearsal, one upgrade-with-migration from the previous tag, one image pull by digest, and a refresh loop through feed failures. Duration matters less than having exercised each lifecycle path once.
- Restore test on a clean machine (a stranger's path): pull image, run wizard, import OPML, restore a backup.
- Upgrade matrix: previous beta to rc with real data; rollback via snapshot.
- Reader clients: client A and client B sync after upgrade.
- Zero P0/P1 over the window, plus a record (in kipple-history) of what was exercised, so "soak" is a log not a feeling.
- Unlike the multi-user cases, there is no cohort of other people's data. Fuzz, UAT suites and a synthetic large-data seed (many feeds, 100k+ items) substitute for tester diversity.

## Kipple's plan compared

Read: C:\kipple\docs\RELEASING.md, C:\kipple-history\plans\0.6-0.7-1.0-plan.md. Local state: no stability/compatibility document in docs/ (grep found incidental mentions only); CHANGELOG top is 0.7.0-beta.1 (2026-10-03).

Present and strong: immutable image tags, signed digests, tag protection, rollback via pre-migration snapshot, fragment changelog, fuzz, UAT suites, regression resets the soak clock, breaking-before-1.0 pushed into 0.6 and 0.7 (matches Immich's front-loading and Go's pre-1 cleanup).

Lacks:
1. A written compatibility promise (the 1.0 deliverable): what is the public API, data contract, config surface, and what is excluded (Go-style two lists). RELEASING.md says breaking changes to Reader API, backup format and settings keys need a major, but nothing defines them, and the web UI routes, env vars, CLI subcommands (`kipple restore`, `version`) and image tag policy are not listed.
2. A deprecation policy (deprecate in a minor, remove in the next major) and a Deprecated/YANKED convention.
3. A migration-compat statement: schema upgrades supported from which versions (e.g. any 1.x to latest 1.x; and from the last 0.x?). Jellyfin required 10.10.7 specifically.
4. A tested restore of a backup across versions (an old-format backup restored by the 1.0 binary) and a statement that backups made by 1.x restore on any later 1.x.
5. A patch/support policy: that only the latest 1.x is supported, expected 1.0.x cadence, how a bad stable gets pulled (the `latest` rollback is there, good).
6. Large-data and legacy-data evidence (Jellyfin's failure mode): a seeded 100k+ item DB upgrade timing and memory check.
7. Fresh-install-by-a-stranger evidence beyond the owner (the first-time Docker walkthrough is listed; make it mandatory on a machine that is not the dev or deploy hosts, arm64 once).

Over-does for one user:
- Two soaks (week-long plus a second few-day soak) plus a go/no-go "meeting" with a single person; one rc soak with the lifecycle checklist above gives the same evidence.
- Website screenshots, badges (Codecov/Scorecard/Views) and website version text in every release's checklist, including prereleases; keep for stable only.
- Fuzz by hand every release plus Suite 1 by hand plus `/code-review high` plus CI: for a patch rc, CI plus delta review is enough (the CLAUDE.md "don't re-verify what CI proved" already says so).
- Reader-API, settings-key and image-tag rules are fine but sprawling; the doc is 227 lines and mixes policy with the owner's host runbook, which the plan itself says is moving out.

## 0.8.0 first, or straight to rc.1?

Recommend straight to rc.1 (from the 0.7.0 line, so 0.7.0-rc.1 or the next prerelease on that line, following the plan's own step), not a 0.8.0.
Reason: the cases say a 0.x release is justified only when a breaking change or data-model migration is still pending (Mealie, Jellyfin, Immich). The plan already lists the JSON-blob-to-tables work as "after 1.0". That is the one item that could force a post-1.0 schema migration and a risky major-grade change. Decide it now: either do it before rc.1 (then it is a 0.8.0-beta, a real reason for one), or accept it as an additive, backward-compatible migration after 1.0 and write that into the compatibility doc (schema is internal; backup restore is the contract, and migrations are forward-only with a pre-migration snapshot). If it can be made migration-safe without changing the Reader API, backup format or settings keys, rc.1 now is right and no 0.8.0 is needed. If it would change the backup format, do 0.8.0 first.
Also before rc.1: write the compatibility/stability doc and a deprecation policy as the one thing that distinguishes 1.0 from 0.7.0 (the plan currently says "no code change" for 1.0, which is the gap: 1.0 is a document plus evidence).
