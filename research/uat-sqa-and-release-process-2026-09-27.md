# UAT, SQA and release-process research, 2026-09-27

Design-meeting prework and the evaluations behind `docs/uat-plan.md`, `docs/sqa-plan.md` and the release ladder in
`docs/RELEASING.md`. Unlike the reports from 2026-09-24 to 26 this was not produced by a research workflow with a
verification pass; it is the lead session's reading of the sources the owner pointed at, given in chat during the
phase 5 planning meeting. Nothing here was independently verified beyond what each item says. The resulting
documents are in the Kipple repository; this file records the reasoning and what was rejected.

## 1. A third-party UAT skill (owner's link, 11:51 ET)

The owner asked whether an open-source Playwright-driven UAT skill would work for Kipple, or whether there were better
options, and what else the creation process should cover.

- **What it is:** a Playwright runner that captures console and network errors, audits WCAG 2.2 AA, checks
  translation keys, tests responsive layouts and produces a severity-triaged report. Reporting only; a person or agent
  still fixes the findings.
- **Concerns:** the GitHub repository and the install command named different owners (the command pulled a package
  from an unrelated scope), so it would mean installing an unverified third-party package that drives a real browser
  against a security-conscious public project. Its i18n and placeholder checks do not apply (Kipple has no i18n).
- **Decision:** do not install; keep the good ideas. Build the same checks in-repo with official Playwright and
  axe-core, reviewable, and consistent with the existing CI contrast check. This became Suite 1 (`npm run uat`,
  PR #46). Licence follow-up: Playwright is Apache-2.0 and axe-core MPL-2.0, so the plan's first "MIT only" wording was
  corrected and flagged for the owner.

## 2. Release-process gaps the same question surfaced

Four were recommended and accepted (11:54): a Reader API regression replay of recorded client A and
client B request sequences against the deployed build (the actual product surface); a migration rehearsal on a
copy of the live database as a standing checklist item; an actual restore drill instead of documented steps; and
the fresh-machine Docker walkthrough followed literally, as a single-host self-hoster. Suites 4 and 5 executed on
the same day, see [../audits/uat-results-2026-09-27.md](../audits/uat-results-2026-09-27.md).

## 3. The UAT plan itself

The owner linked a general UAT guide and asked for a plan (11:54). The lead session mapped the standard's five roles
onto a one-person project (the agent orchestrates and fixes, the owner is user, product owner and sign-off), kept its
entry and exit criteria and traceable cases, and adopted a P0 to P3 defect scale. It split execution into three tiers
so the owner does only what needs a real device: scripted (Suite 1), agent-driven scenario walkthroughs (Suite 2),
owner-only device checks (Suite 3), plus Suites 4 and 5 above. Findings were to go in a separate findings file; in
practice the plan's executed sections and the audit records hold them.

## 4. SQA plan against IEEE 730 (owner asked, 11:58)

Finding: the project had been doing software quality assurance without naming it. CI static analysis (govulncheck,
staticcheck, gosec, gitleaks, Trivy), race and fuzz tests, `/code-review high` gates, the `CLAUDE.md` conventions and
the changelog and SemVer discipline were the substance, spread over several files. The gap against an IEEE 730 outline
was that nobody could read one page and see how quality is assured. Recommendation: document existing practice, invent
no process. Four optional additions were listed and the owner told the agent to decide them at 12:03: a risk register
(built, `docs/risk-register.md`), coverage visibility (added to CI, not a gate; about 91 percent on the web app at
the time), a docs index (`docs/README.md`), and a public-repository issue-triage statement.

## 5. Alpha, beta, rc and 1.0 criteria (owner raised, 12:00)

`docs/RELEASING.md` had the basic rule but not the criteria for crossing each line. Proposal, accepted topic by topic:
beta starts when phase 5 is fully closed (feature-complete means verified, not declared); rc needs the suites
re-verified on the beta build plus a one-week soak with zero new P0 or P1 defects; 1.0.0 needs a shorter second soak,
private vulnerability reporting on, the documentation run and fresh-machine walkthrough proven, and a go/no-go meeting.
A regression found during a soak resets the clock. Suite 3 was later removed as a gate (decided the same day) because
it should stay open-ended informal checking on the owner's devices.

## 6. iOS simulator skills for Suite 3 (owner's links, 16:20 ET)

Two skills were evaluated: an iOS simulator automation skill and a collection of Apple-platform skills. Neither runs
on this machine: both need macOS with Xcode. More fundamentally the simulator is a poor stand-in for what Suite 3
tests (a real lock screen and background behavior for the `document.hasFocus()` question, real touch swipes, the
Add-to-Home-Screen flow). Conclusion: Suite 3 stays with the owner on his phone; the four checks were listed for him.
He ran them informally on beta.1 and reported all passing.

## 7. Development-pipeline skill checklist (owner's list, 16:24 ET; deferred to phase 6)

The owner pasted a five-point list of things pipelines and agents should cover and asked whether Kipple already
did. Assessment: framework and boilerplate blueprints (covered better by the auto-loaded `CLAUDE.md`), linter and type
enforcement (CI gates, stronger than a prompt), test-driven generation (tests are written with the code and coverage
is thorough, though not test-first), refactoring patterns (package layout and the `/simplify` and `/code-review`
passes), and systematic root-cause debugging (the one real gap: Kipple's `CLAUDE.md` has no debugging protocol,
unlike the ops-side one). The owner: "Toss it to phase 6."

## What produced no research file

The other diagnostic work of these days was incident analysis and is recorded as challenges: the imgproxy CI hang
(root-caused from a goroutine dump), and the tunnel error 1033 after the beta.1 deploy. The settings and layout
mockups of the following night are in [settings-and-layout-proposals-2026-09-28.md](settings-and-layout-proposals-2026-09-28.md).
