# Research 1: the owner's five links vs Kipple's release process

Fetch notes: pages 1, 2, 4, 5 read through WebFetch (summarized by its small model, so item-level, not verbatim). Page 3 (Medium) returned 403 to WebFetch and archives were blocked; read in full through the browser pane. Page 2 is very short.

## 1. Frugal Testing, QA release readiness (https://www.frugaltesting.com/blog/best-practices-for-qa-release-readiness-a-complete-pre-launch-testing-guide)
Says: textbook QA pipeline: test plan with roles/timelines, functional + smoke + sanity + integration + system, automated and visual regression in CI, cross-browser/device, load testing (JMeter/k6), defect triage by severity, compliance and risk assessment, UAT with explicit acceptance criteria, a go/no-go framework, release notes (plain language, grouped, critical fixes first, KNOWN OUTSTANDING ISSUES listed), post-deploy monitoring and comparison to pre-release results, plus pitfalls (skipping UAT, no structure, no known-issues list).
Fluff: nearly all of it; no thresholds, metrics or templates. Concrete and useful: acceptance criteria written before testing, severity-ordered triage, known-issues section in release notes, post-release comparison of live vs pre-release behaviour, smoke test of the built artifact.
Applies to one-owner: acceptance criteria, triage, known issues in notes, smoke test, regression in CI, cross-browser. Skip: team roles, compliance audits, stakeholder meetings, load testing at scale.

## 2. Docsie, "Version 1.0" glossary (https://www.docsie.io/blog/glossary/version-1-0/)
Says: 1.0 = production-ready, not perfect; core features done; stable; secure; documented (install, tutorials, API reference); versioning and release process in place; support/help docs. Docs advice: document the 3-5 primary user journeys, clear information architecture with search, a feedback channel, maintenance owner and schedule, progressive disclosure.
Fluff: most of it (definitional). Concrete: "3-5 core journeys documented", "never launch without a feedback mechanism", "docs have an owner and a review habit".
Applies: journeys docs, feedback channel (GitHub issues/discussions), docs freshness. Skip: documentation team workflows.

## 3. Victor Ronin, "How to build version 1.0" (https://medium.com/@victor.ronin/how-to-build-version-1-0-44158bba09ae)
Says: product people decide scope (engineers over-build); build a 0.1 kernel first; expect to throw code away and take conscious shortcuts to revisit; cut to the bone: ask what can be subtracted from 1.0 and still be viable; choose proven, trending-up tech, or what you know; timebox milestones and shrink scope rather than move dates; bring someone who has done it.
Fluff: greenfield/company framing; it is about BUILDING 1.0, not releasing it. Concrete and relevant: subtract, don't add; timebox and cut scope; do not carry prototype code into production.
Applies: subtract-first (matches Kipple's no-band-aid/delete rule and the beta-adds-no-features rule), timebox 1.0 date with a cut list. Skip: product-vs-engineer split (owner is both), tech choice (already made).

## 4. Asana, release management (https://asana.com/resources/release-management)
Says: five phases (plan, build, test, prepare, deploy); standardized documented process; automation; cross-functional meetings; post-release review feeding the next release; rollback plan with snapshots and restore scripts defined before deploy; risk register; fresh reviewers for final QA; KPI analysis after deploy; project closure.
Fluff: stakeholder summaries, kickoff meetings, business case, agile vs waterfall.
Concrete: rollback planned beforehand, risk register, post-release review, final QA by someone who did not build it, KPI check after deploy.

## 5. Process Street, software release readiness checklist (https://www.process.st/templates/software-release-readiness-checklist/)
20 tasks: requirements doc complete; test extensively; QA approval; cross-platform check; review all bug reports; release-manager approval; document new features; internal trial run; review system requirements; analyst approval; plan rollout; user guide/help files; all changes committed to version control; check data migration needs; DBA approval; rollback plan; risk mitigation plan; client communication; test support readiness; support-manager approval.
Fluff: the five role approvals (QA, release mgr, analyst, DBA, support mgr) are enterprise sign-offs.
Concrete: version-control cleanliness, data migration check, rollback plan, system requirements accuracy, internal trial run (dogfood), user-facing release announcement, review of every open bug.

## Comparison with docs/RELEASING.md and docs/uat-plan.md

| Practice (source) | Status | Where / what is missing | Worth it for one owner? |
|---|---|---|---|
| Written acceptance/exit criteria (1,5) | COVERED | uat-plan.md Entry/Exit criteria; RELEASING.md promotion gates | Yes, done |
| Severity-triaged defects, P0-P3 (1) | COVERED | uat-plan.md severity table; findings doc | Yes, done |
| Go/no-go sign-off (1) | COVERED | RELEASING.md RC -> 1.0.0 meeting, MEETINGS.md | Yes, done |
| Smoke test of built artifact (1) | COVERED | RELEASING step 10, release.yml smoke test, Suite 5 | Yes, done |
| Automated regression in CI (1) | COVERED | CI, Vitest, go test, Playwright UAT, fuzz | Yes, done |
| Visual regression (1) | MISSING | Suite 1 has axe/contrast/overflow but no screenshot diffs | Low value; skip or do a manual look at screenshots |
| Cross-browser/platform (1,5) | PARTLY | Suite 1 is Chromium only; Safari/iOS via Suite 3, owner devices; no Firefox, no desktop Safari | Worth one manual pass on Firefox and desktop Safari before 1.0 |
| Load/performance (1) | PARTLY | Only "memory flat after minutes" (step 10); no big-library test | Skip load testing; do one large-database check (e.g. 100k items, many feeds) for startup, search, memory |
| Compliance checks (1) | PARTLY | SECURITY.md, Trivy, gosec, govulncheck, cosign, scorecard | Enough; skip audits |
| Risk register (1,4,5) | COVERED | uat-plan references a risk register (R1/C4) in kipple-history | Yes, confirm it is current before 1.0 |
| Known issues listed in release notes (1) | PARTLY | Open P2/P3 issues (#92-#100 etc.) are tracked but no "Known issues" section in notes/changelog template | Yes, cheap; list them in the 1.0 notes |
| Plain-language release notes with top paragraph (1,5) | COVERED | changes/_intro.md, CHANGELOG | Done |
| Rollback plan tested before deploy (4,5) | COVERED | RELEASING Rollback, deploy.md, Suite 4 restore drill | Done. Note: rollback of the pull-by-digest path is described, not drilled |
| Data migration check (5) | COVERED | Suite 4 migration rehearsal on a copy; pre-migration snapshot | Done |
| All changes committed / tag on exact commit (5) | COVERED | Steps 1, 6, 8; tag ruleset | Done |
| Documentation + user guide (2,5) | COVERED | README, docs/deploy.md; documentation run (#42) | Done |
| Core user journeys documented, 3-5 (2) | PARTLY | Docs exist; no explicit "journeys" list mapped to docs | Cheap check: README quickstart, import OPML, connect Reeder/NNW, backup/restore, upgrade |
| Feedback channel (2) | PARTLY | GitHub issues; SECURITY.md for security; no stated place for general feedback/support expectations | Yes, one README line (issues/discussions, single-maintainer, best-effort) |
| Internal trial run / dogfood (5) | COVERED | Soak periods of the owner's real daily use | Done |
| Fresh-eyes final QA by someone other than builder (4) | PARTLY | Claude executes UAT and Claude wrote the code; the fresh-machine Suite 5 is closest | Consider one outside tester or a cold read of README on a clean machine (Suite 5 Run D arm64 and A3/A8-A12 by hand are still undone) |
| System requirements accuracy (5) | PARTLY | Not an explicit step | Add: README states Docker, arch, RAM, browsers, Reader clients tested |
| Post-release review / retrospective (4) | PARTLY | kipple-history after every release/incident | Fine; add a short 1.0 retro entry |
| Post-release monitoring / KPI (1,4) | PARTLY | Step 10 verify; project non-goal is "no monitoring" | One-time 48-hour log/memory check after 1.0 is enough |
| Subtract scope, timebox (3) | COVERED/PARTLY | Beta no-features rule, no-band-aid rule; no explicit 1.0 date or "cut list" | Yes: set a target date and a list of what is deferred to 1.1 (parking-lot exists) |
| Customer comms (5) | COVERED | GitHub Release, website, changelog | Done |
| Support readiness test (5) | MISSING | n/a | Skip, enterprise |
| Role approvals QA/DBA/analyst/support (5) | n/a | Owner is every role | Skip, enterprise |
| Stakeholder kickoff, business case, WBS (4) | n/a | | Skip |
| KPI/analytics, A/B (4) | n/a | | Skip; project forbids monitoring |

## Gaps worth acting on before 1.0
1. A "Known issues" section in the 1.0 release notes (open P2/P3 list).
2. A large-library sanity check (size, startup, search, memory), the one real performance risk for a feed reader.
3. Firefox and desktop Safari manual pass (Suite 1 is Chromium-only).
4. Finish Suite 5 items not yet run: Run D (arm64), Run E, A10 with Reeder/NNW, the browser-only wizard steps, and a literal `cosign verify` (only `gh attestation verify` was run); TC-A1..A3 real client checks still skipped.
5. README: stated requirements, feedback/support expectations, and a short list of core journeys that docs cover.
6. A 1.0 date plus an explicit "deferred to 1.1" list (timebox and subtract).
7. Drill the pull-by-digest rollback once (only the build-from-tag rollback has been exercised).
