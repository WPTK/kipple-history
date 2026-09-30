# Overnight audit of the setup wizard stack, 2026-09-29 night to 2026-09-30

Scope: `v0.3.0-beta.3..main` at `14960f2`, that is the wizard stack (#91, #111, #114, #117, #118, #119, #121) and #122.
Times ET. Written at about 23:05 on 09-29; the fix PRs did not exist yet (`gh pr list` showed none open at 23:02), so
their state is stated as pending, not as done. The owner's rule applies: every confirmed finding is fixed or filed, and
there is no "not fixing" list.

## Method

- A full test pass by one agent.
- A four-pass adversarial review of the range, then re-verification of the first-round findings by the fix agents.
- A rehearsal of migration 0010 on a real database (below).
- Findings were filed as GitHub issues in milestone "0.5.0 - Setup wizard and pull-and-run image", 22:48 to 22:58.
  Only #128 and the rebinding item carry a graded severity (medium); the rest were not graded when filed, and the
  issue labels (bug, area) are all this file has to go on.

## Issues filed

| # | Area | Finding | State at 23:02 |
|---|---|---|---|
| 124 | infra | The pull-and-run compose file has no `container_name`, so `docker logs kipple` and `docker exec kipple /kipple setup-token` in the quickstart fail (Compose names it `<project>-kipple-1`); the build-from-source example does set it | Open (#130 duplicate, closed 23:00) |
| 125 | infra | Published images carry `org.opencontainers.image.version=sha-<commit>` (metadata-action overrides the Dockerfile label) and the binary's build date is unknown | Open |
| 126 | infra | `base.digest` label repeats the base image digest; Dependabot rewrites only `FROM`, so the label goes stale on the first bump | Open |
| 127 | infra | The release workflow can move `latest`, `X.Y` and `X` backwards, e.g. re-running an older release's run after a newer one shipped | Open |
| 128 | backend, security (medium) | Open gate: a client-chosen `*.ts.net` Host skips the forwarded-header check when the TCP peer is loopback, so a same-machine reverse proxy that passes Host through can expose an open-mode instance | Open |
| 131 | backend | About reports open mode as Cloudflare Access (`auth_mode` derived from the hash alone) and shows the time zone from process start | Open (#123 and #129 duplicates, closed 23:00) |
| 132 | docs | Docs drift after the time zone and port change (`docs/design.md`, the stats dictionary, a compose example comment) | Open |
| 133 | web | Wizard can leave the zone on UTC: "Skip the rest of setup" on step 3, or a stale `/welcome/<step>` address, bypasses the zone write | Open |
| 134 | web | The signed-out screen shows the password form on any `/api/instance` failure and the form ignores `409 open_mode` | Open |
| 135 | web | Theme step: a preview is written to the device profile and Skip leaves the device pinned with explicit overrides | Open |

## First-round findings not yet filed as separate issues

Verified by reading only, and being re-verified by the fix agents before any change:

- DNS rebinding through `.local` and single-label hosts in open mode (medium).
- A restore-port trap.
- `kipple password` accepts "change-me".
- Login guesses are not counted once an account is locked.
- Token file permissions on Windows.
- The tailnet check for `100.64.0.0/10`.
- Release concurrency and overwrite guards.
- Nine small frontend issues.

## Migration 0010 rehearsal

Run on a real schema-9 database built with `v0.3.0-beta.3`, not a synthetic one. Result: data preserved; `tz`,
`legacy_port` and `setup_completed_at` stamped; the pre-migration snapshot written; integrity checks pass; rolling back
with the beta.3 binary works. Known limit, accepted by the owner: an explicit UTC choice cannot be told from the default on
the first run after an upgrade.

## Fixes

Three fix agents were launched: backend and security (Opus), the release workflow, and the frontend wizard. Each opens one
PR and leaves it open for the owner's morning review. Nothing is merged or deployed overnight. At 23:02 none of the three
PRs existed; check the pull request list for their numbers and state.
