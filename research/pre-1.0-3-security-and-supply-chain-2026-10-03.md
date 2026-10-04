# Kipple pre-1.0 security gap list (research 3)

Date 2026-10-03. Sources read (paraphrased):
- OpenSSF Best Practices criteria: https://www.bestpractices.dev/en/criteria/0 (passing level: password hashing with salt+stretching, no unpatched medium/high vulns >60 days, static analysis before releases, no credential leaks, https delivery, a private vuln-report route; no signing requirement at passing)
- Scorecard checks: https://github.com/ossf/scorecard/blob/main/docs/checks.md (includes SBOM, Signed-Releases, Security-Policy, Pinned-Dependencies, Token-Permissions, Fuzzing, CII-Best-Practices, Code-Review, Branch-Protection)
- SLSA levels: https://slsa.dev/spec/v1.0/levels (GitHub attest-build-provenance gives roughly Build L2; L3 needs more isolation hardening)
- OWASP SSRF cheat sheet: https://cheatsheetseries.owasp.org/cheatsheets/Server_Side_Request_Forgery_Prevention_Cheat_Sheet.html (for arbitrary-URL fetchers: deny-list private/loopback/link-local/metadata, resolve all A/AAAA and check each, plus network-layer egress rules as the backstop)
- OWASP Session Management: https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html (>=64-bit CSPRNG ids, Secure/HttpOnly/SameSite, __Host- prefix, idle AND absolute timeouts, renew id on login, server-side logout invalidation)
- OWASP CSRF: https://cheatsheetseries.owasp.org/cheatsheets/Cross-Site_Request_Forgery_Prevention_Cheat_Sheet.html (Fetch Metadata Sec-Fetch-Site, Origin check, custom header for JSON APIs, SameSite is not enough alone)
- OWASP XSS: https://cheatsheetseries.owasp.org/cheatsheets/Cross_Site_Scripting_Prevention_Cheat_Sheet.html (allowlist sanitizer, do not mutate after sanitizing, CSP as defense in depth, patch the sanitizer)
- OWASP Docker: https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html (non-root, cap-drop ALL, no-new-privileges, read-only + tmpfs, mem/pids limits, seccomp/AppArmor default, rootless daemon)
- GitHub SBOM attestations: https://docs.github.com/en/actions/security-for-github-actions/using-artifact-attestations/using-artifact-attestations-to-establish-provenance-for-builds (actions/attest with sbom-path; SBOM = contents, provenance = how built)
- security.txt (RFC 9116): https://securitytxt.org/ (Contact + Expires, served at /.well-known/security.txt by a website; meant for orgs' sites)
- EU CRA: https://digital-strategy.ec.europa.eu/en/policies/cyber-resilience-act and https://digital-strategy.ec.europa.eu/en/policies/cra-open-source
  In force 2024-12-10; manufacturer vulnerability/incident reporting from 2026-09-11 (already passed); full obligations 2027-12-11. Open source that is not monetised is not "commercial activity" and is outside manufacturer duties; "open-source steward" regime is light-touch (no fines) and applies to organisations that systematically support commercial-use OSS. A single-owner, unmonetised self-hosted reader is out of scope. Caveat: monetising it (paid support, donations tied to the product, paid hosted tier) could change that; I did not read the regulation text itself, only the Commission pages. Not legal advice.

## What the repo already has (verified by reading)
- Passing-level OpenSSF items all effectively met: argon2id, private reporting (SECURITY.md), static analysis, secret scan, Dependabot (gomod, npm, actions, docker), SHA-pinned actions and base images, fuzz (fuzz.yml), Scorecard workflow, zizmor workflow, CodeQL.
- Release: buildx provenance mode=max and sbom:true, cosign keyless sign + self-verify, actions/attest-build-provenance, Trivy per platform before tags, annotated-tag gate, immutable X.Y.Z tag (.github/workflows/release.yml).
- Container: distroless nonroot, read_only, tmpfs /tmp, cap_drop ALL, no-new-privileges, mem_limit, pids_limit, log rotation, loopback-only port, in both example compose files; hardening documented in docs/deploy.md "Health check and container hardening".
- SSRF: dial-time Dialer.Control on the resolved IP (defeats DNS rebinding), broad blocklist incl. CGNAT/NAT64/6to4/Teredo (internal/fetch/ssrf.go), per-hop scope for private-net exceptions, image proxy redirect scope tests, discover goes through the guarded transport (risk register R8).
- Headers: internal/httpx/headers.go; design.md 7.7: strict CSP (script-src 'self', no inline script, frame-ancestors none), nosniff, XFO, no-referrer, HSTS only on https, COOP, CORP, Permissions-Policy; image proxy and icons get default-src 'none'.
- Cookies: HttpOnly, SameSite=Lax, Secure when scheme is https (api.go:468-481); session id = hex sha256 stored server-side; sliding 90-day TTL.
- CSRF: Sec-Fetch-Site/Origin same-origin guard plus X-Kipple-Client header (api.go sameOrigin).
- Login throttling: per-client escalating delay, single argon2 slot, tests in internal/api/login_pacing_test.go.
- XSS: internal/sanitize with fuzz target, serve-time transform (design 7.8).

## Gap list
Legend: COVERED / PARTLY / MISSING. Worth = worth doing before 1.0 for one owner. Effort S/M/L.

| # | Practice | Status | Worth before 1.0 | Effort |
|---|---|---|---|---|
| 1 | Support/security-update policy for 1.0.x (SECURITY.md still says "prerelease"; only latest tag and main). State: 1.x latest minor gets fixes; how a fix ships (patch tag + GHCR); that older 1.y is not patched; best-effort timing; how reporters get credit; GHSA/CVE: say advisories are published via GitHub Security Advisories, CVE requested through GHSA when severity warrants | PARTLY (SECURITY.md) | YES | S |
| 2 | Threat model document (assets, actors, trust boundaries: browser, tunnel/Access, Reader API clients, hostile feed content, hostile image hosts, open mode on LAN; what is explicitly out of scope). Material exists scattered in design.md 6.3, 7.x and risk-register but no single page | PARTLY | YES, a 1-2 page STRIDE-lite doc linking existing sections; doubles as the pentest checklist | M |
| 3 | SBOM as a release artifact. buildx sbom:true embeds an SPDX attestation in the registry image, but nothing is attached to the GitHub Release, and Scorecard's SBOM check looks for release assets/files. Optional: also run actions/attest with sbom-path (so `gh attestation verify` covers the SBOM) | PARTLY | YES (cheap): generate CycloneDX/SPDX once (syft or `docker buildx imagetools inspect --format '{{ json .SBOM }}'`), upload to the release, optionally sign/attest. Document how to fetch it in docs/deploy.md "The published image" | S |
| 4 | SSRF test matrix for fetcher + image proxy. ssrf.go is thorough; verify tests cover: literal IPs in decimal/octal/hex forms, IPv4-mapped IPv6, userinfo tricks (userinfo_test exists), redirect to private host at each hop (hopscope/redirectscope exist), DNS name resolving to mixed public+private A/AAAA, non-http schemes (file:, gopher:), non-standard ports, 169.254.169.254 explicitly, and the Reader API subscribe path and OPML import path (both take URLs). I saw only one named test in ssrf_test.go; fetch_test/imagescope_test probably carry the rest | PARTLY (needs a quick audit, not a rebuild) | YES, one table-driven test hitting every URL-taking entry point | S-M |
| 5 | Network-layer SSRF backstop (OWASP says app deny-list alone is bypass-prone). Allow-private is an opt-in; deploy.md could say: if you run on a network with sensitive internal services, add an egress firewall / separate Docker network | MISSING (docs only) | Optional doc paragraph | S |
| 6 | Feed HTML sanitizer assurance: allowlist + fuzz exist; add a regression corpus of known mXSS/DOMPurify-style payloads (and confirm output is never re-mutated after sanitizing, per OWASP); SVG, `<form>`, `<base>`, `<meta refresh>`, `srcdoc`, `data:` URLs, CSS `url()`/`expression` | PARTLY (fuzz + tests) | Worth a one-time payload corpus test | S |
| 7 | Session expiry: sliding 90 days, no absolute cap and no idle timeout. OWASP's short timeouts fit banking, not a personal reader; the 90-day slide is a deliberate convenience. Check: logout deletes server row (appears to), password change/reset revokes all sessions, there is a "sign out other devices" action (devices.go suggests a list) | PARTLY | Document the choice in the threat model; add an absolute cap (e.g. 1 year) only if cheap. Skip shortening | S |
| 8 | Cookie hardening: Secure flag is conditional on scheme (needed for http LAN), so `__Host-` prefix is impossible without breaking LAN mode | PARTLY, by design | SKIP; note rationale in threat model | - |
| 9 | Session id renewal at login | Appears covered (new random id per login, stored hashed); confirm a pre-login cookie is never reused | Quick check | S |
| 10 | Login throttling | COVERED (pacing tests). Note open mode + wider bind is the real exposure; already documented in deploy.md "Open mode" | - | - |
| 11 | CSRF | COVERED (Sec-Fetch-Site/Origin + custom header). Reader API token auth is not cookie-based | - | - |
| 12 | Security headers/CSP | COVERED. Only wart is style-src 'unsafe-inline' (documented: Radix/shadcn). Do not chase nonce styles pre-1.0 | skip | - |
| 13 | Container run flags | COVERED in both example compose files. Optional extras: seccomp is Docker default; could add `user: "65532:65532"` explicit (image already nonroot), `--init` unnecessary. Compose has mem/pids limits only in build variant, not the pull variant (pull variant omits mem_limit/pids_limit/logging) | PARTLY | Make pull example match build example limits: S |
| 14 | Image CVE scanning | COVERED (Trivy in CI and in release before tagging) | - | - |
| 15 | SLSA | Build provenance L2-ish via GitHub attestation + cosign. Publish a `gh attestation verify` / `cosign verify-attestation` line next to the existing cosign verify instructions. L3 not worth chasing | PARTLY (verify docs) | S |
| 16 | OpenSSF badge | Parked on purpose. Passing level looks nearly free given the above; Silver/Gold need multi-person items (two reviewers, bus factor) the project cannot meet | Keep parked; optionally revisit passing only | S |
| 17 | security.txt | MISSING, but it is for operated websites. Kipple is self-hosted software; SECURITY.md plus GitHub PVR is the right channel. Could serve a /.well-known/security.txt pointing at the advisory URL, but no one scans a household instance | SKIP | - |
| 18 | CRA | Out of scope while unmonetised (Commission page). If monetised, reassess. A one-line statement in SECURITY.md or the threat model is enough | doc sentence only | S |
| 19 | Dependency pinning | COVERED (SHA-pinned actions, base image digests, lockfiles, npm ci) | - | - |
| 20 | Pentest checklist | MISSING as a document. Fold into the threat model: auth bypass paths (Access JWT header trust, trusted-proxy spoofing: tests exist), Reader API token, backup/restore upload (zip/db path traversal, size), OPML import (XXE, billion laughs, URL list), image proxy (decompression bombs: thumbmem exists), SQLite file permissions in volume | PARTLY | Do a one-pass self-test and record results in the SQA plan | M |
| 21 | Branch protection / code review (Scorecard) | Solo project; Code-Review check will stay low. Confirm branch protection on main (require CI, no force push, tags protected) | verify only | S |
| 22 | Pre-1.0 review practice | Already done: phase 5 audit, multiple review rounds. A last "delta review of security-sensitive diff since audit" at rc fits docs/RELEASING.md | covered | - |

## Ranked, worth doing before 1.0
1. Update SECURITY.md for 1.0.x support policy (S)
2. One-page threat model + pentest checklist, with session-lifetime and cookie rationale and CRA sentence (M)
3. SBOM attached to the GitHub Release, optional attest, verify instructions (S)
4. SSRF entry-point test audit/matrix incl. Reader API subscribe and OPML import (S-M)
5. Sanitizer payload regression corpus (S)
6. Pull compose example gets the same mem/pids/log limits (S)
7. deploy.md note on egress filtering and `gh attestation verify` (S)

## Skip
security.txt, __Host- cookie prefix, nonce-based style CSP, shortening session life, SLSA L3, OpenSSF Silver/Gold, rootless-daemon advice, CRA compliance work.
