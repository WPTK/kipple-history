# Research 4: docs and ops readiness for Kipple 1.0 (2026-10-03)

## Sources read (paraphrased)
- Diataxis (https://diataxis.fr/): four doc forms (tutorial, how-to, reference, explanation); keep them separate.
- Immich backup/restore (https://docs.immich.app/administration/backup-and-restore): states what a backup does NOT contain, restore via UI or CLI, version-mismatch migration warning, DB-before-files ordering. No explicit "test your restore" drill.
- Miniflux upgrade (https://miniflux.app/docs/upgrade.html): back up and verify the backup first, read release notes for breaking changes, migrations run on start (`RUN_MIGRATIONS`); no downgrade guidance at all.
- SemVer (https://semver.org/): 1.0.0 defines the public API; deprecate by documenting and shipping a minor that warns, remove only in a major; needs a declared public API.
- SQLite backup API (https://www.sqlite.org/backup.html), WAL (https://www.sqlite.org/wal.html), VACUUM (https://www.sqlite.org/lang_vacuum.html): copy db+wal+shm together or use backup API / VACUUM INTO; WAL can grow without bound with overlapping readers or disabled autocheckpoint (default 1000 pages); VACUUM needs up to 2x free space; auto_vacuum trades fragmentation for no rebuild.
- WCAG 2.2 new AA criteria (https://www.w3.org/WAI/standards-guidelines/wcag/new-in-22/): focus not obscured (2.4.11), dragging alternative (2.5.7), target size 24px (2.5.8), consistent help (3.2.6), accessible authentication (3.3.8).
- WAI easy checks (https://www.w3.org/WAI/test-evaluate/easy-checks/): page title, headings, contrast, skip link, visible focus, language, zoom, labels. The sensible small-project audit: automated axe scan plus keyboard-only pass, 200% zoom/reflow, one screen reader pass, reduced motion.
- 5-user usability (https://trymata.com/blog/5-user-rule-for-user-testing/ and similar summaries of Nielsen/Landauer): one user finds roughly a third of problems, five roughly 85%; diminishing returns, so run small rounds and fix between them. One real stranger beats zero.
- GitHub issue forms and config.yml contact links (https://docs.github.com/en/communities/using-templates-to-encourage-useful-issues-and-pull-requests/configuring-issue-templates-for-your-repository).
- Web search summaries on WAL-mode backup/VACUUM INTO (oneuptime, photostructure); treated as secondary.
- Not fetched in full: Vaultwarden wiki, Paperless-ngx docs (norms taken from general knowledge: Paperless/Vaultwarden each have a FAQ/troubleshooting page, a proxy-recipes page, and a full env-var reference; Miniflux has a configuration reference listing every variable). Flag as unverified.

## Gap list (Kipple)
Legend: COVERED / PARTLY / MISSING. Worth = worth doing before 1.0 for one owner. Effort S/M/L.

### (a) Docs structure
| Practice | Status | Where / gap | Worth | Effort |
|---|---|---|---|---|
| Tutorial/quickstart | COVERED | README Quickstart + wizard; Suite 5 walks it literally | - | - |
| Install, upgrade, backup, restore, rollback how-tos | COVERED | docs/deploy.md (backup export, restore, new empty volume, rollback via pre-migration snapshot, disk space) | - | - |
| Env var reference | COVERED | .env.example documents every var; README table of common ones | - | - |
| Troubleshooting / FAQ page | MISSING | Only scattered hints (README: "docker logs kipple"; deploy.md refused-start text). No symptom -> cause page (won't start, 1033/tunnel, login loops, clients can't connect, feed errors, disk full) | Yes | M |
| Reverse proxy recipes | PARTLY | deploy.md mentions Caddy/nginx/Cloudflare Tunnel and KIPPLE_TRUSTED_PROXY_IPS; no copy-paste Caddy/nginx/Traefik snippet; Cloudflare covered | Yes (top 2-3 snippets) | S |
| Docs separated by Diataxis type | PARTLY | deploy.md is 579 lines mixing reference, how-to, explanation; docs/README.md is an index. Splitting is nice-to-have; a TOC at top of deploy.md is the cheap fix | Skip split; add TOC/anchors | S |
| Self-hoster docs vs internal history | PARTLY | docs/ mixes HANDOFF-*, plan, parking-lot with user docs; docs/README.md explains. Consider moving history into a docs/internal/ folder | Optional | S |
| Reader-API client setup page (Reeder/NNW) | PARTLY | README after-setup lines; design.md has the contract. No short how-to with screenshots/exact fields | Maybe | S |

### (b) Upgrade and migration safety
| Practice | Status | Where / gap | Worth | Effort |
|---|---|---|---|---|
| Pre-migration snapshot, disk check, refuse-newer-schema | COVERED | deploy.md "Roll back an upgrade", "Disk space"; Suite 4 | - | - |
| Tested restore drill | COVERED | uat-plan Suite 4 (executed 2026-09-27, 2026-09-29) | Re-run once on the rc image | S |
| Downgrade policy | COVERED | No down migrations; restore pre-migration snapshot (deploy.md) | - | - |
| Release-notes breaking-change practice | COVERED | changes/ fragments + CHANGELOG; deploy.md says read top paragraph of skipped releases | - | - |
| Expand/contract discipline for schema | PARTLY | CLAUDE.md states the rule; no written note that 1.x migrations must be additive so N-1 binary can read N schema within a minor line. Decide and document: "1.x minor upgrades may migrate; downgrade = restore" is already the policy, just state it as a 1.0 promise | Yes (one paragraph) | S |
| Stability promise / public API declaration for 1.x | PARTLY | RELEASING.md says breaking Reader API, backup format, settings keys need a major bump after 1.0. Not user-facing: no page lists what "public" means (Reader API endpoints, export zip format, env vars, settings keys, image tags, volume layout) | Yes | S |
| Deprecation policy | MISSING | No statement (e.g. "deprecated in a minor with a changelog + log warning, removed no sooner than next major"). Matters for env vars and settings keys | Yes, short | S |
| Backup-format compatibility across versions | PARTLY | Restore of older exports implied; no stated rule "newer Kipple restores any older 1.x export; older refuses newer" | Yes (document + one test of restoring a 0.x export on the rc) | S |
| Skip-release upgrade test | PARTLY | Rollback doc mentions 8-11 skips; no recorded test of upgrading from the oldest supported version straight to 1.0 | Yes | S |

### (c) Release verification
| Practice | Status | Where / gap | Worth | Effort |
|---|---|---|---|---|
| Smoke test on published artifact | COVERED | release.yml builds, scans, smoke-tests, signs; cosign verify documented | - | - |
| Post-publish pull-and-run check of the pushed tag (not a local build) | PARTLY | Suite 5 does fresh-machine walkthrough; do it once on the exact 1.0.0-rc digest from GHCR, amd64 and arm64 | Yes | S |
| Clean-room first-time-user test | PARTLY | Suite 5 is executed by the owner/agent who knows the product. No test by someone who is not the author | Yes: 1 to 3 people | M |
| Usability check method | MISSING | No script. Method for 1 to 5 people: 3 tasks (install from README, add a feed + import OPML, connect a sync client), silent observer, think-aloud, record where they stall, fix, re-run. One person already surfaces about a third of problems | Yes, 1-3 testers | M |
| Staged rollout / canary for single instance | COVERED | Owner's own server runs beta soak 1 week, rc soak few days (RELEASING.md); pull-by-digest; `latest` re-point rollback | - | - |
| Image tag policy (latest = stable only, prereleases never float) | COVERED | RELEASING.md rollback section; prereleases refused for latest | - | - |

### (d) SQLite ops and baselines
| Practice | Status | Where / gap | Worth | Effort |
|---|---|---|---|---|
| Online backup (VACUUM INTO) for snapshot/export | COVERED | maint.go nightly snapshot; deploy.md "never copy db while running" | - | - |
| WAL checkpointing | COVERED | hourly passive checkpoint in maint.go; migration WAL discussed in deploy.md | Optional: confirm a TRUNCATE checkpoint at snapshot time so -wal doesn't sit large | S |
| Integrity check | COVERED | restore reports integrity checks; Suite 4 runs PRAGMA integrity_check | - | - |
| Space reclaim (VACUUM / auto_vacuum) and DB growth guidance | MISSING | No user-facing note: how fast the db grows per feed/item, what retention does, whether space is returned after trimming, how to compact | Yes, short note | S |
| Large-scale behavior | PARTLY | design.md has a 10,000 items x 50 rules figure, a 138-feed commit-gate fairness test, R2 (600k-item feed delete). No recorded end-to-end baseline | - | - |
| Recorded performance baseline | MISSING | No table of: feeds, items, db size, RSS memory after refresh, startup time, migration time, list/API latency at a realistic size (suggest 150 feeds/100k items and a 1000-feed/1M-item stress). Owner's real data (about 135 feeds, 8.5k items) is a data point to record. Memory: design says <100 MB budget, compose caps 256m; no measurement recorded in docs | Yes | M |
| Stated sizing guidance for strangers | MISSING | Minimum RAM/disk, expected image-cache growth (cap 1 GiB, documented) | Yes (follows the baseline) | S |

### (e) Accessibility
| Practice | Status | Where / gap | Worth | Effort |
|---|---|---|---|---|
| Automated axe WCAG 2.2 AA scan, every screen, 2 themes | COVERED | uat-plan Suite 1 S3, with waivers file | - | - |
| Contrast across 20 schemes | COVERED | CI "theme contrast" job | - | - |
| Reduced motion, prefers-contrast | COVERED | ui-decisions.md line 13; prefers-reduced-motion in index.css | - | - |
| Manual keyboard-only pass | PARTLY | TC-R3 covers shortcuts; no recorded full tab-order/focus-visible/focus-not-obscured pass (2.4.11) | Yes | S |
| Screen reader pass | MISSING | No VoiceOver/NVDA run recorded (article list, reader pane, dialogs, live region for new items) | Yes, one pass with VoiceOver (owner has iPhone/Mac?) or NVDA, 30 min on 3 flows | S-M |
| Target size 24px, drag alternatives (swipe gestures), 200% zoom reflow | MISSING | Swipe gestures need a non-drag alternative (2.5.7); touch targets unmeasured | Yes: check, record | S |
| Published accessibility statement | MISSING | One short paragraph: standard aimed for, known gaps, how to report | Cheap, do | S |
| Paid/external audit | MISSING | Not warranted for a single-user OSS reader | Skip | L |

### (f) Compatibility matrix
| Practice | Status | Where / gap | Worth | Effort |
|---|---|---|---|---|
| Browser/device matrix | MISSING | uat-plan names desktop Chrome + iPhone PWA only (owner's devices). No published "supported browsers" (Safari, Firefox, Chrome/Edge latest two; iOS 16+? Android Chrome) | Yes: a table + Playwright runs in webkit/firefox/chromium (axe suite already exists, adding projects is cheap) | S-M |
| Sync client matrix | PARTLY | Reeder Classic and NetNewsWire are named; TC-A1..A3 were skipped in some runs (uat-plan 268, 352). Third-party clients (FeedMe, Fluent Reader, Newsboat, Reeder 5?) untested/unlisted | Yes: state "tested with X version", "others may work" | S |
| Platform matrix (amd64/arm64, Docker, Podman, Synology/Unraid) | PARTLY | amd64+arm64 image verified (Suite 5 line ~569). Podman/NAS untested; say so | Say so | S |

### (g) Support process
| Practice | Status | Where / gap | Worth | Effort |
|---|---|---|---|---|
| SECURITY.md with private reporting | COVERED | SECURITY.md | - | - |
| Triage expectation (no SLA) | COVERED | SECURITY.md "Issue triage" | - | - |
| Supported versions | PARTLY | SECURITY.md: only latest tag and main, "prerelease software" (will be stale at 1.0). Needs a 1.x line: latest 1.x minor gets fixes; older minors do not; upgrade path stated | Yes (must update at 1.0) | S |
| Issue templates (bug/feature, config.yml) | MISSING | .github has only pull_request_template.md, no ISSUE_TEMPLATE. Add a bug form asking version (`kipple version -v`), install method, proxy/tunnel, logs, client; a feature form; config.yml contact link to security advisory | Yes | S |
| Discussions / Q&A channel | PARTLY | README says issues are the only place. With strangers, enable GitHub Discussions (Q&A) or state "questions are welcome as issues using the question template" | Optional | S |
| Statement of what is/is not supported | PARTLY | README: "one person", SECURITY: not a public service. Missing explicit list: single user only, no multi-user, no Fever, Docker image only (building from source best-effort), reverse proxies you configure, no hosted service | Yes | S |
| Community expectations (CONTRIBUTING, code of conduct) | PARTLY | CONTRIBUTING.md exists (46 lines); no CODE_OF_CONDUCT. Scope boundaries (non-goals) live in CLAUDE.md, not user-facing; link them so feature requests can be closed fast | Yes: add non-goals list to README/CONTRIBUTING; CoC optional | S |

## Ranked: worth doing before 1.0
1. Cold-reader test by a non-author (1-3 people) of README->first feed->sync client: M. Biggest unknown; Suite 5 is author-run.
2. Troubleshooting/FAQ page (symptom -> cause -> fix) plus 2-3 reverse-proxy snippets: M.
3. Recorded performance/footprint baseline and sizing guidance (feeds, items, db size, RSS, startup, migration time; own data plus a synthetic large seed): M.
4. Stability and deprecation policy page for 1.x (what is public API, deprecation rule, backup-format compatibility, downgrade = restore): S.
5. Update SECURITY.md supported versions for 1.x; add "what is supported / not supported" paragraph: S.
6. Issue templates (bug form requires version + install method + logs; config.yml) and enable private reporting check: S.
7. Browser/client compatibility table; run axe/Playwright suite on webkit + firefox: S-M.
8. A11y: manual keyboard pass, one screen-reader pass, 24px target/drag-alternative check, short accessibility statement: S-M.
9. Re-run restore drill and a skip-version upgrade (oldest 0.x -> rc) on the published rc digest: S.
10. DB growth / compaction note (retention effect, when to VACUUM, free-space rule): S.

## Skip
External accessibility audit, formal SLA, Diataxis restructure of deploy.md (add a TOC instead), multi-person usability lab, forum/chat, load testing beyond one synthetic large-seed run, CoC beyond a standard file.
