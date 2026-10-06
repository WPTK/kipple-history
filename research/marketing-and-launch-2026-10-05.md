# Marketing and launch plan (planning only)

Meeting 52, 2026-10-05. Nothing here is started. The owner's framing: free, not only social media and Discord, not
only asking friends; "marketing" in quotes because there is no monetization, the goal is that people see it. Research
was done on the web on the same day; items marked **unverified** were not confirmed against a primary source.

## Rulings (the owner, 2026-10-05)

- **Launch at 1.0**, not at a beta or the release candidate.
- **Be open that Kipple is also an experiment in working with coding agents.** Say it plainly on the site and README.
- **Keep the license** (Blue Oak Model License 1.0.0, see below).
- **The demo comes later.** It stays on the plan as the biggest conversion lever, with no date.
- **Install-base stores:** research the submission processes (below). Planning only; no submissions yet.

## License: no change

Blue Oak 1.0.0 is permissive and OSI-approved (approved January 2024 after an earlier submission lapsed). Permissive
licenses are associated with the widest adoption. Nobody is blocked from trying Kipple by the license. The only argument
for MIT is instant recognition; whether GitHub's repo sidebar shows Blue Oak as "Other" is **unverified** and worth a
look. Unraid's catalog requires an OSI-approved license on the template repository, which Blue Oak satisfies.

## Positioning

server B is minimal and needs Postgres. server A is PHP and extension-driven. yarr is bare. Kipple is the reader that
looks like a good reading app and runs as one container with SQLite: magazine and card layouts, 20 themes, installable
PWA, Reader API sync for any client, a yearly Wrapped, and an unusually thorough audit trail (signed images, Scorecard,
fuzzing, a public decision record). Client policy applies: write "Reader API clients", never name apps.

## Fix before any outreach

1. A real screenshot or GIF in the README (a TODO sits there now; the website already has screenshots).
2. A try-it-now demo (deferred by the owner).
3. An honest "Kipple versus server B, server A and yarr" page, so launch threads already have the answer.
4. GitHub Discussions on, so first users have somewhere to land.
5. The agent-experiment statement on the site and README.

## Channels

- **Install-base stores** (next section).
- **Newsletters and podcasts:** selfh.st, Console.dev, the Changelog and Self-Hosted podcast. One pitch each, with a link
  people can try. **Unverified** submission details.
- **Engineering write-ups on the project's own site, then shared as articles:** SQLite WAL retention-trim cost, the
  fail-safe thumbnail decoder and its fuzzing, signed images pulled by digest, the perf pass, and the build-with-an-agent
  experiment itself (this history repository is the evidence).
- **One Show HN at 1.0.** Rules: it must be something people can run, no signup, no asking friends to vote.
- **One r/selfhosted post at 1.0.** Read the current rules first; the subreddit's stance on AI-built projects was not
  found (Reddit blocked the fetch).
- **Directories:** alternativeto.net, LibHunter.
- **awesome-selfhosted:** requires a first release more than four months old, so not before about February 2027. Its
  contributing rules ban machine/LLM-generated *contributions* to the list ("will result in a ban"). The rule is about
  the list's own pull requests, not the listed project, but the maintainers' view of an agent-built project is unknown.
  Decide whether to ask them first; the owner's disclosure ruling means the project will not hide it either way.
- **Wrapped as built-in marketing:** ship 1.0 before December so the opt-in share card lands in year-end season; a small
  "made with Kipple" footer on the card would carry the name with no telemetry.
- **Measurement without telemetry** (monitoring is a non-goal): GitHub traffic and clone insights, stars, image pull
  counts, release downloads. Check weekly.

## Install-base stores: what each one asks for

Common to all: they run the container for the user, so they need a stable image reference, a port, a data volume, an
icon, a description and screenshots. Kipple already publishes a signed multi-arch image on GHCR (`linux/amd64` and
`linux/arm64`), and the first-run setup happens in the browser, which is exactly what these stores want.

| Store | How to submit | What it requires | Fit and effort |
|---|---|---|---|
| **Unraid Community Apps** | Web portal (`ca.unraid.net/submit`): validate and scan a public GitHub repo of templates. A starter repository exists. | Public, active repo; OSI-approved `LICENSE`; `ca_profile.xml` with a filled Profile section; one Docker template XML per app (Repository tag, Name, Overview). Registry rules, support-thread requirement, moderation timing and update behavior: **unverified**, not in the docs fetched. | Highest reach for home servers. Small effort: one XML and a repo. Needs a published stable image tag (`latest` moves only at 1.0). |
| **Umbrel App Store** | Fork `getumbrel/umbrel-apps`, add a directory with `umbrel-app.yml` and compose files, pass automated tests, open a PR. The repo ships an `AGENTS.md` and skills for coding agents. | Must open to a browser UI with no SSH or log reading; sensible defaults, browser-based setup, predictable updates. Exact field list, digest pinning, review criteria and any policy on agent-assisted PRs: **unverified**. | Good fit (browser-first setup). Moderate effort. |
| **CasaOS / ZimaOS AppStore** | Fork `IceWhaleTech/CasaOS-AppStore`, add a compose-based manifest, run `scripts/build_dist.sh`, open a PR. | Must be tested on your own CasaOS first; v2 docs are the source of truth for metadata. Eligibility and maturity rules: **unverified**. | Moderate; needs a CasaOS or ZimaOS test box. |
| **Runtipi** | Fork the app store repo, add `config.json` and a compose file with `x-runtipi` metadata, test in a Runtipi instance, open a PR with screenshots. | Free and open source, official maintained image; test install, start, logs, backup and update; secrets via environment variables. Fast, clarity-and-security review. | Good fit; about 20 minutes of authoring by their guide, plus a test instance. |
| **TrueNAS community train** | Post a feature request on the TrueNAS forum, then a PR to the `truenas/apps` community train: `app.yaml`, `ix_values.yaml`, `questions.yaml`, Jinja2 compose template, tests (`basic-values.yaml`) that CI deploys and health-checks. | Prefer `ghcr.io` images; static tags; Renovate for updates; the catalog may reject or remove any app at its discretion. | Heaviest authoring of the five; do last. |

Not researched: Cloudron, YunoHost, Portainer templates, Synology and QNAP community catalogs, Docker's own listings.

### Things the stores force us to settle (inferences from our own design notes)

- **Reachability default.** The README publishes the port on `127.0.0.1` for safety; stores publish on the LAN. Open mode's
  Host gate (#254, PR #259) accepts IP literals, `localhost`, `.localhost`, `.ts.net`, the public URL host, listed names
  and the name chosen in the wizard, and deliberately rejects `.local`, `.lan` and single-word names. Several stores reach
  an app by a `.local` or single-word host name, so a store install may be refused until the user lists the name. Test this
  against each store's default host before submitting. Not verified on a real store.
- **Hardened run flags.** The README's `read_only`, `cap_drop ALL` and `tmpfs` flags may not be expressible or may be
  overridden by a store's templating. Decide which are essential.
- **Updates.** Stores want a stable tag and automated updates; `latest` only moves at a stable release, which is another
  reason to launch the stores at 1.0.
- **Agent policy.** Umbrel invites agent-built packages; awesome-selfhosted bans machine contributions to its list.
  Policies differ and should be read per store before any submission.

## Timeline (all dates soft; nothing is scheduled)

- **Now to rc.1 (not before 2026-10-11):** the five fixes above; write the comparison page and the agent-experiment text.
- **rc.1 to 1.0:** draft two articles; build the store packages and test them on a private instance (needs the owner's
  word for anything on the Kipple server).
- **1.0 week:** tag, release, signed image, `latest` moves. Show HN midweek morning (Eastern), the Reddit post the next day,
  reply to every issue within a day. Submit to the stores and directories that week.
- **Months 1 to 2:** newsletters, podcasts, write-ups.
- **December:** the Wrapped push.
- **About February 2027:** awesome-selfhosted, after the four-month rule and the disclosure question.

## Open items

- Does the owner want to ask awesome-selfhosted's maintainers about agent-built projects first, or skip the list?
- Which stores first? Recommendation: Unraid, Runtipi, Umbrel, then CasaOS, then TrueNAS.
- Wording and placement of the agent-experiment statement (README top, site, both).
- Demo: later, owner's call.

## Sources

Blue Oak OSI approval (opensource.org license-review list, January 2024); awesome-selfhosted-data CONTRIBUTING.md;
Show HN guidelines (news.ycombinator.com/showhn.html); Unraid Community Apps submit help and builder guide
(ca.unraid.net/submit); Umbrel `getumbrel/umbrel-apps` README and AGENTS.md; CasaOS-AppStore README and CONTRIBUTING.md;
Runtipi docs, "Creating apps"; TrueNAS apps CONTRIBUTIONS.md and apps.truenas.com contributing page;
self-hosted RSS reader comparisons (ssdnodes.com); permissive versus copyleft overview (fosshub.com).
