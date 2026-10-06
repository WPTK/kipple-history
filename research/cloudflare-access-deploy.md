# cloudflare-access-deploy

# Kipple behind Cloudflare Tunnel + Access at rss.example.com - research findings (2026-09-24)

Legend: **[V]** = verified in primary source (quoted/linked). **[I]** = inferred from verified facts. **[U]** = unverified / third-party.

---

## 0. Current state and what changes

- Tunnel ingress for `rss.example.com` today: `service: https://192.0.2.50:7070`, `originRequest.originServerName: <tailscale hostname>` → yarr. Kipple will listen on plain HTTP on a LAN port on the same host (Host-A, 192.0.2.50).
- Access today: one OTP-protected app for the hostname, plus a separate Bypass app scoped to `rss.example.com/fever`. The same two-app pattern carries over; the bypass path changes to the Reader API prefix.
- cloudflared is remotely managed (token-based) and runs on Host-B, not on Host-A. Requests reach Kipple from Host-B's LAN IP (Docker NAT), not from Cloudflare IPs. **[I]**

---

## 1. Access path-scoped self-hosted apps, precedence, Bypass, non-browser clients

### 1.1 Path scoping and precedence [V]
Source: https://developers.cloudflare.com/cloudflare-one/access-controls/policies/app-paths/ (last updated Apr 17, 2026)

> "Application paths define the URLs protected by an Access policy. When adding a self-hosted application to Access, you can choose to protect the entire website by entering its apex domain, or alternatively, protect specific subdomains and paths."

> "When multiple rules are set for a common root path, the more specific rule takes precedence. For example, when setting rules for `dashboard.com/eng` and `dashboard.com/eng/exec` separately, the more specific rule for `dashboard.com/eng/exec` takes precedence, and no rule is inherited from `dashboard.com/eng`. If no separate, specific rule is set for `dashboard.com/eng/exec`, it will inherit any rules set for `dashboard.com/eng`."

So: App A = `rss.example.com` (path empty → whole host; Allow email OTP). App B = `rss.example.com/api/greader.php` (Bypass Everyone). App B is the more specific rule and wins for its subtree; everything else inherits App A. No wildcard is needed on App B: a path app inherits downward to its sub-paths by the rule above.

Wildcard rules (same page):
> "When you create an application for a specific subdomain or path, you can use asterisks (`*`) as wildcards."
> `example.com` or `example.com/*` covers `example.com`, `example.com/alpha`, `example.com/beta`.
> `example.com/alpha/*` covers `example.com/alpha/one`, `example.com/alpha/two`; does **not** cover `example.com/alpha` or `example.com`.
> `example.com/foo*/bar` covers `example.com/foo/bar`, `example.com/food/bar`, `example.com/food/stuff/bar` ("Using a wildcard in the middle of the Path field covers multiple segments of the URL").
> Limitations: "At most one wildcard in between each dot in the Subdomain" and "At most one wildcard in between each slash in the Path."
> Unsupported in app paths: port numbers ("Access will strip the port number and redirect"), query strings, `#` anchors.

API/Terraform field names [V] (https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/zero_trust_access_application.md, mirrors the REST schema):
- `domain` (String) "The primary hostname and path secured by Access." Example in the doc: `domain = "test.example.com/admin"`, `type = "self_hosted"`.
- `destinations[]` with `type = "public"`, `uri` - "Public destinations' URIs can include a domain and path with wildcards". `destinations` supersedes the deprecated `self_hosted_domains`.
- `policies[]` - "The policies that Access applies to the application, in ascending order of precedence"; each has `precedence` (Number, unique per app) and `decision`.
- `decision` "Available values: `allow`, `deny`, `non_identity`, `bypass`." (`non_identity` = Service Auth.)
- `service_auth_401_redirect` (Boolean) "Returns a 401 status code when the request is blocked by a Service Auth policy."
- `http_only_cookie_attribute`, `same_site_cookie_attribute`, `path_cookie_attribute` ("Enables cookie paths to scope an application's JWT to the application path. If disabled, the JWT will scope to the hostname by default"), `enable_binding_cookie`, `options_preflight_bypass`, `read_service_tokens_from_header`, `skip_interstitial` ("Enables automatic authentication through cloudflared"), `session_duration` (Go duration string), response `aud` "Audience tag."

Community caveat [U]: searches surfaced two 2025 community threads ("Policy Inheritance Not Prioritizing Most Specific Path", https://community.cloudflare.com/t/policy-inheritance-not-prioritizing-most-specific-path/820213 and "How do application wildcards deal with multiple matches?", https://community.cloudflare.com/t/how-do-application-wildcards-deal-with-multiple-matches/816924) reporting inconsistent precedence, chiefly when two *wildcard* patterns overlap. Could not read them (Cloudflare bot challenge on both HTML and Discourse JSON). Mitigation: avoid wildcards on the bypass app (a plain path prefix inherits downward anyway) and verify with curl after creation (see §7).

### 1.2 Policy actions, Bypass semantics, evaluation order [V]
Source: https://developers.cloudflare.com/cloudflare-one/access-controls/policies/ (last updated Sep 4, 2026)

> "The Bypass action in Cloudflare Access disables Access enforcement for specific traffic."
> Warning: "Bypass does not enforce any Access security controls and requests are not logged. Bypass policies should be tested before deploying to production. Consider using Service Auth if you would like to enforce policies and maintain logging without requiring user authentication."
> "Bypass policies do not support identity-based rule types ... you will not be able to apply certain identity-based selectors (such as email)."
> Worked example: "create an Access application for the domain `test.example.com/admin/<your-url>` and add the Bypass policy": `Bypass | Include | Everyone | Everyone`.
> "When applying a Bypass action, security settings revert to the defaults configured for the zone and any configured Page Rules. If Always use HTTPS is enabled for the site, then traffic to the bypassed destination continues in HTTPS."
> Evaluation order (from the policies page as rendered by WebFetch): "Bypass and Service Auth policies are evaluated first, from top to bottom as shown in the UI. Then, Block and Allow policies are evaluated based on their order from top to bottom." Evaluation stops once a user matches an Allow or Block.
> Selector table: `Everyone` - "Allows, denies, or bypasses access to everyone." Not identity-based, so valid in a Bypass policy.
> "All Access applications are deny by default -- a user must match an Allow policy before they are granted access." (self-hosted app page)

Bypass incompatibility (only matters if you ever add posture checks): Bypass policies containing device-posture rules do not work when Zaraz is on or a Worker intercepts the request.

### 1.3 Service Auth alternative [V] and why it does not fit client A
Source: https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/ (Sep 22, 2026)
> "add the following to the headers of any HTTP request: `CF-Access-Client-Id: <CLIENT_ID>` `CF-Access-Client-Secret: <CLIENT_SECRET>`"
> Single-header variant: set `read_service_tokens_from_header` (e.g. `"Authorization"`) via `PUT /accounts/$ACCOUNT_ID/access/apps/$APP_ID`; the client must then send `Authorization: {"cf-access-client-id": "<CLIENT_ID>", "cf-access-client-secret": "<CLIENT_SECRET>"}`.
> "Make sure to set the policy action to Service Auth; otherwise, Access will prompt for an identity provider login."
> New Client Secret format since 2026-08-26: `cfast_[40 alphanumeric characters][8-character checksum]`.

Why not viable here [I]: client A and client B cannot add custom headers, and the Reader protocol already uses `Authorization: GoogleLogin auth=<token>`, which cannot double as the JSON service-token header. Service Auth with `service_auth_401_redirect=true` would at least turn the failure into a 401 instead of a 302, but the clients still could not authenticate. Bypass is the only Access action that lets these clients through.

Other non-viable/heavyweight options [I]: `cloudflared access` / `cf-access-token` header (CLI only); WARP client with "Authenticate with Cloudflare One Client" (would require WARP on every iOS device; not researched further).

### 1.4 What Access does to an unauthenticated non-browser request (why the API path must be bypassed)
- [V] Authorization-cookie page (https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/): "Cloudflare checks every HTTP request bound for that site to ensure that the request has a valid `CF_Authorization` cookie. If a request does not include the cookie, Access will block the request."
- [V] Session-management page (https://developers.cloudflare.com/cloudflare-one/access-controls/access-settings/session-management/): "By default, failed Cloudflare One Client authentication requests return a `302` redirect to the Access login page. API clients, command-line tools, and automation often cannot complete this browser login flow." (The 401 toggle described there - `warp_auth_non_browser_401` - applies only to Cloudflare One Client authentication; the AJAX 401 needs `X-Requested-With: XMLHttpRequest` and only covers *expired* sessions.)
- [V] CORS page: preflight OPTIONS without the cookie "will return a `403` error"; simple requests without login get redirected to the login page.
- [U] Redirect target shape as reported by multiple users (community + GitHub issues, e.g. https://community.cloudflare.com/t/cloudflare-access-service-token-returning-302-found-despite-correct-policy-setup/842026 and https://github.com/GlassHaven/Haven/issues/643): `302 Found`, `Location: https://<team>.cloudflareaccess.com/cdn-cgi/access/login/<hostname>?kid=<...>&redirect_url=<original path>&meta=<...>`. The login page itself is an HTML page hosted on the team domain (customizable per https://developers.cloudflare.com/cloudflare-one/reusable-components/custom-pages/access-login-page/).
- [I] Net effect for client A/client B against an OTP-protected `/accounts/ClientLogin`: they POST credentials, receive a 302 to `*.cloudflareaccess.com`; URLSession follows it and gets a 200 `text/html` login page body that is not `SID=...`/`Auth=...`, so the client reports "invalid credentials"/"unexpected response". Every subsequent `/reader/api/0/*` call fails identically. Nothing the client can do fixes this; the path must not be under Access enforcement.

---

## 2. Does the API prefix choice matter for Access? Recommend a layout.

### Client behavior [V]
- FreshRSS docs (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/docs/en/developers/06_GoogleReader_API.md): "point your mobile application to the `greader.php` address (e.g. `https://freshrss.example.net/api/greader.php`)"; examples `POST .../api/greader.php/accounts/ClientLogin`, `GET .../api/greader.php/reader/api/0/subscription/list?output=json`, `.../reader/api/0/token`, `.../reader/api/0/stream/contents/reading-list`, `.../reader/api/0/subscription/edit`. client A is in the compatible-clients table; the FreshRSS docs' instruction is to type the API address (including `/api/greader.php`) plus username and API password into the client. Third-party guides confirm client A's "Server" field takes `https://host/api/greader.php` [U].
- client B source (https://raw.githubusercontent.com/Ranchero-Software/client B/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift): `case login = "/accounts/ClientLogin"`, `case token = "/reader/api/0/token"`, `tagList = "/reader/api/0/tag/list"`, `subscriptionList = "/reader/api/0/subscription/list"`, `subscriptionEdit = "/reader/api/0/subscription/edit"`, `subscriptionAdd = "/reader/api/0/subscription/quickadd"`, `subscriptionImport = "/reader/api/0/subscription/import"`, `contents = "/reader/api/0/stream/items/contents"`, `itemIds = "/reader/api/0/stream/items/ids"`, `editTag = "/reader/api/0/edit-tag"`, `disableTag`, `renameTag`. Base URL: `case .generic, .freshRSS: return accountSettings.endpointURL` - i.e. the user-entered URL is used verbatim and endpoints are appended with `appendingPathComponent`. The macOS account sheet placeholder is `"https://fresh.rss.net/api/greader.php"` (Mac/Preferences/Accounts/AccountsReaderAPIWindowController.swift line 46).
- Miniflux source (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go): routes are mounted at the site root: `POST /accounts/ClientLogin`, `GET /reader/api/0/token`, `POST /reader/api/0/edit-tag`, `GET /reader/api/0/tag/list`, `GET /reader/api/0/user-info`, `GET /reader/api/0/subscription/list`, `POST /reader/api/0/subscription/edit`, `POST /reader/api/0/subscription/quickadd`, `GET /reader/api/0/stream/items/ids`, `POST /reader/api/0/stream/items/contents`, `POST /reader/api/0/mark-all-as-read`, plus `GET|POST /reader/api/0/` fallback. Miniflux users therefore enter the bare site URL in clients.

### Access implications [I from §1]
- Single prefix (`/api/greader.php`): one Bypass app with `domain: rss.example.com/api/greader.php`. Everything the clients call is under that prefix because they append `/accounts/ClientLogin` and `/reader/api/0/...` to the entered URL.
- Miniflux-style root layout: needs **two** Bypass apps (`rss.example.com/accounts/ClientLogin` and `rss.example.com/reader/api/0`), and it puts generic-looking `/accounts` and `/reader` prefixes on the public host where they can collide with UI routes and where a mistaken UI route under `/reader/...` would silently become public.

### Recommendation
Serve the Reader API only at `/api/greader.php` (match `^/api/greader.php(/|$)` in Kipple's router). Create exactly one extra Access app: `rss.example.com/api/greader.php`, policy `Bypass` / `Include: Everyone`, `decision: bypass`. Do **not** add a wildcard. Delete the old `/fever` bypass app once yarr is retired (it is harmless while yarr is paused, but it is a public hole if Kipple ever answers `/fever`). Never mount anything else under `/api/greader.php`. Kipple must enforce its own auth (username + API password → `Auth=` token) on this prefix because Access is not there; return `401` with a short plain-text body (not a redirect) for bad credentials so the apps show a sensible error.

Also: never use `/cdn-cgi/` paths in Kipple - [V] "This endpoint is managed and served by Cloudflare. It cannot be modified or customized." (https://developers.cloudflare.com/fundamentals/reference/cdn-cgi-endpoint/). Access uses `/cdn-cgi/access/...` on the protected hostname.

---

## 3. Optional hardening: validating the Access JWT; telling tunnel traffic from LAN traffic

### 3.1 JWT delivery and validation [V]
Source: https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/ (May 6, 2026)
> "When Cloudflare sends a request to your origin, the request will include an application token as a `Cf-Access-Jwt-Assertion` request header. Requests made through a browser will also pass the token as a `CF_Authorization` cookie."
> "We recommend validating the `Cf-Access-Jwt-Assertion` header instead of the `CF_Authorization` cookie, since the cookie is not guaranteed to be passed."
> Keys: `https://<your-team-name>.cloudflareaccess.com/cdn-cgi/access/certs` - returns `keys` (JWK), `public_cert` (current PEM), `public_certs` (both PEM). "By default, Access rotates the signing key every 6 weeks ... Previous keys remain valid for 7 days after rotation." "Do not fetch the current key from `public_cert` ... Instead, match the `kid` value in the JWT to the corresponding certificate in `public_certs`" (or use the JWKS `keys` with `kid`).
> AUD: "Cloudflare Access assigns a unique AUD tag to each application. The `aud` claim in the token payload specifies which application the JWT is valid for." Dashboard: Zero Trust > Access controls > Applications > Configure > Additional settings > Application Audience (AUD) Tag. "The AUD tag will never change unless you delete or recreate the Access application."

Go example given by Cloudflare (verbatim core):
```go
import "github.com/coreos/go-oidc/v3/oidc"
teamDomain = "https://test.cloudflareaccess.com"
certsURL   = fmt.Sprintf("%s/cdn-cgi/access/certs", teamDomain)
policyAUD  = "<aud tag>"
config   = &oidc.Config{ClientID: policyAUD}
keySet   = oidc.NewRemoteKeySet(ctx, certsURL)
verifier = oidc.NewVerifier(teamDomain, keySet, config)
// in middleware:
accessJWT := r.Header.Get("Cf-Access-Jwt-Assertion")
if accessJWT == "" { w.WriteHeader(http.StatusUnauthorized); return }
_, err := verifier.Verify(r.Context(), accessJWT)
```
Claims [V] (https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/application-token/): header `alg: RS256`, `kid`, `typ: JWT`; payload `aud: [<aud>]`, `email`, `exp`, `iat`, `nbf`, `iss: https://<team>.cloudflareaccess.com`, `type: "app"`, `identity_nonce`, `sub`, `country`. Also: "Unless your application is connected to Access through Cloudflare Tunnel, your application must validate the token to ensure the security of your origin. Validation of the header alone is not sufficient - the JWT and signature must be confirmed to avoid identity spoofing."
- Access also sets `Cf-Access-Authenticated-User-Email` on requests to the origin [V: shown in https://developers.cloudflare.com/cloudflare-one/tutorials/access-workers/ example output `"Cf-Access-Authenticated-User-Email": "user@example.com"`]. Treat it as display-only; it is a plain header and forgeable from the LAN.
- cloudflared can validate for you: originRequest `access: {required: true, teamName, audTag: [...]}` ("Protect with Access" in the route's Access settings) - [V] "Requires cloudflared to validate the Cloudflare Access JWT prior to proxying traffic to your origin ... For all L7 requests to these hostnames, Access will send the JWT to cloudflared as a `Cf-Access-Jwt-Assertion` request header." **Pitfall [I]:** this is per ingress rule for the whole hostname; requests on the bypassed API path carry no JWT and would be rejected by cloudflared. Only usable if you split the ingress into two rules (a `path` regex rule for `^/api/greader.php` without `access`, and the hostname rule with `access`). Simpler: do not enable it; validate in Kipple.

### 3.2 Design recommendation [I]
- UI requests arriving through the tunnel carry a valid `Cf-Access-Jwt-Assertion` on every request (Access re-checks each request). Kipple can treat a verified JWT (signature via JWKS by `kid`, `iss` == team domain, `aud` contains the UI app's AUD, `exp`/`nbf`) as the authenticated session and skip its own login entirely; no Kipple cookie is needed for tunnel traffic. Cache JWKS for ~1h, re-fetch on unknown `kid`.
- Keep a local password login + Kipple session cookie for LAN access (no Access there). Whether to trust the JWT at all should also be gated on the request coming from the tunnel host (below); otherwise a LAN device that captured a JWT could replay it until `exp` (Access session duration, default 24h).
- Alternatively skip all of this and keep only a local password login behind Access - simpler, and OTP is already the outer wall. The JWT path is an optional convenience (no double login), not a security requirement, because Access already blocks unauthenticated tunnel traffic. The one thing that *is* required either way: Kipple must not accept `Cf-Access-Jwt-Assertion` as proof on the `/api/greader.php` path (Access does not inject it there because enforcement is bypassed; any value present was supplied by the client).

### 3.3 Distinguishing tunnel traffic from LAN traffic
Headers the Cloudflare edge adds/overwrites on requests to the origin [V] (https://developers.cloudflare.com/fundamentals/reference/http-headers/):
- `CF-Connecting-IP` - "provides the client IP address connecting to Cloudflare to the origin web server. This header will only be sent on the traffic from Cloudflare's edge to your origin web server."
- `X-Forwarded-For` - "If there was no existing `X-Forwarded-For` header in the request sent to Cloudflare, `X-Forwarded-For` has an identical value to the `CF-Connecting-IP` header" (appends otherwise). Cloudflare recommends `CF-Connecting-IP` over XFF.
- `X-Forwarded-Proto` - "used to identify the protocol (HTTP or HTTPS) that a visitor used to connect to Cloudflare. By default, the protocol used is `https` ... For incoming requests, the value of this header will be set to the protocol the client used (`http` or `https`). If the client set a different value, it will be overwritten."
- `Cf-Ray` - "a hashed value that encodes information about the data center and the visitor's request. For example: `Cf-Ray: 230b030023ae2822-SJC`." Sent to origins.
- `CF-Visitor` - `CF-Visitor: { "scheme":"https"}`; `CF-IPCountry` (2-letter code); `CDN-Loop: cloudflare`; `Connection` is always rewritten to `Keep-Alive`; `Accept-Encoding` is always rewritten to `br, gzip`.
- Cloudflare "passes all HTTP request headers to your origin web server" (only invalid names per NGINX rules are dropped).

What cloudflared itself does [V, source]:
- `ingress/origin_proxy.go` `httpService.RoundTrip`: rewrites only `req.URL.Host`/`Scheme` to the origin; preserves the eyeball `Host` (so Kipple sees `Host: rss.example.com`) unless `httpHostHeader` is set, in which case "Pass the original Host header as X-Forwarded-Host". It adds no `X-Forwarded-For`/`X-Real-IP` of its own (grep of proxy/, ingress/, connection/ found none). Edge headers pass through unchanged.
- Useful terms page [V]: "`cloudflared` operates as a secure connector daemon rather than a local reverse proxy. It forwards requests directly to the configured local service without altering request URI paths or performing local load balancing."

Pitfall [I]: every one of those headers is trivially forgeable by any LAN client hitting `http://192.0.2.50:<port>` directly. The only non-forgeable signals are (a) the TCP source address, which for tunnel traffic is the cloudflared host - Host-B, `192.0.2.192` (Docker default-bridge NAT), and (b) a cryptographically valid `Cf-Access-Jwt-Assertion`. Rule: consult `CF-Connecting-IP`/`X-Forwarded-Proto`/`Cf-Ray` only when `RemoteAddr` is the trusted tunnel host IP (make it a config value, e.g. `KIPPLE_TRUSTED_PROXY_IPS=192.0.2.192`); otherwise treat the request as LAN, scheme `http`, client IP = `RemoteAddr`.

---

## 4. Remotely managed tunnel: editing ingress, what token-based cloudflared can do, no restart needed

- [V] Definition (https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/tunnel-useful-terms/): "A remotely-managed tunnel is a tunnel that was created in the Cloudflare dashboard under Networking > Tunnels. Tunnel configuration is stored in Cloudflare, which allows you to manage the tunnel from the dashboard or using the API."
- [V] Dashboard editing (https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/): "1. In the Cloudflare dashboard, go to Networking > Tunnels and select your tunnel. 2. Go to the Routes tab. 3. Select Edit route from the action menu on the published application ... 4. Expand Additional application settings and modify origin parameters under the HTTP, TLS, or Connection categories. 5. Select Save changes." Route creation: "Path routing: Specifying a path routes matching requests to the service URL, but does not strip or rewrite the path. The service receives the complete request path."
- [V] API: `PUT /accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations` with body `{"config":{"ingress":[{"hostname":..., "service":..., "path":..., "originRequest":{...}}], "originRequest":{...}}}`; response `result.{account_id,tunnel_id,config,created_at,source,version}` where `version` is "The version of the Tunnel Configuration". `GET` on the same path returns the current config; its `source` field: "Indicates if this is a locally or remotely configured tunnel. If `local`, manage the tunnel using a YAML file on the origin machine. If `cloudflare`, manage the tunnel's configuration on the Zero Trust dashboard." Enum `local` | `cloudflare`. `ingress[].service`: "Protocol and address of destination server. Supported protocols: http://, https://, unix://, tcp://, ssh://, rdp://, unix+tls://, smb://." `ingress[].path`: "Requests with this path route to this public hostname." originRequest fields: `originServerName` ("Hostname that cloudflared should expect from your origin server certificate. If empty, cloudflared uses the hostname from the service URL"), `noTLSVerify`, `caPool`, `matchSNItoHost`, `httpHostHeader`, `connectTimeout` (default 30s), `tlsTimeout` (10s), `keepAliveTimeout` (1m30s), `keepAliveConnections` (100), `tcpKeepAlive` (30s), `http2Origin`, `disableChunkedEncoding`, `noHappyEyeballs`, `proxyType`, `access`.
  - **PUT replaces the whole config** [I from HTTP semantics + the body shape]: GET first, edit only the rss.example.com rule, PUT the entire `ingress` array back including every other hostname and the trailing catch-all (`"service": "http_status:404"`), otherwise requests.<redacted-host> / other.example.com drop. `path` is a Go regexp (see below), leave it unset for the whole host.
- [V] How the change reaches cloudflared without a restart (cloudflared source, master): `connection/quic_connection.go`: "// UpdateConfiguration is the RPC method invoked by edge when there is a new configuration" → `q.orchestrator.UpdateConfig(version, config)`. `orchestration/orchestrator.go` `UpdateConfig`: ignores if `o.currentVersion >= version` ("Current version is equal or newer than received version"), otherwise unmarshals, `updateIngress(...)`, sets `currentVersion` and logs `Msg("Updated to new configuration")` with `version` and `config`. `tunnelrpc/pogs/configuration_manager.go`: "UpdateConfiguration is the call provided to cloudflared to load the latest remote configuration." So: save in dashboard or PUT via API → edge pushes the new version over the existing tunnel connections → cloudflared swaps its ingress in place. Verification: `docker logs cloudflared 2>&1 | grep "Updated to new configuration"` on Host-B.
- [V] Path matching engine in cloudflared (`ingress/rule.go`): `Path *Regexp` "an optional regex that can specify path-driven ingress rules"; `Matches(hostname, path)` = host match AND (`Path == nil` OR `Path.Regexp.MatchString(path)`). Config-file docs: "Cloudflare parses the path regex using the Go `syntax` package" and "`cloudflared` matches request paths to evaluate rules, but it forwards the full request path to your service without modifying or stripping it."
- What a token-based cloudflared can/cannot do [V/U]: `cloudflared tunnel run --token <TOKEN>` is the run mode for remotely-managed tunnels ("`--token` - Tunnel token (remotely-managed tunnels)", https://developers.cloudflare.com/tunnel/configuration/). Run flags (`--loglevel`, `--logfile`, `--protocol`, `--metrics`, `--region`) are local; ingress/origin settings are not - docs direct remote-tunnel users to the dashboard for origin parameters and to the config file only for locally-managed tunnels. GitHub issues cloudflare/cloudflared#633, #933, #1029, #1520 describe that with `TUNNEL_TOKEN`/`--token` local `config.yml` ingress is ignored and cloudflared warns about "no ingress rules" even though remote rules load fine [U, issue text not re-read here]. Host-B rule still applies: never recreate the cloudflared container to make a routing change - none is needed.
- The concrete rule change: `{"hostname":"rss.example.com","service":"http://192.0.2.50:<KIPPLE_PORT>"}` with **no** `originRequest.originServerName` and no `noTLSVerify` (TLS options are irrelevant to an `http://` service). The Tailscale hostname can go entirely; DNS CNAME `rss.example.com → <UUID>.cfargotunnel.com` is unchanged. Keep defaults for `connectTimeout`/`keepAliveTimeout`; consider raising `keepAliveConnections` only if you see connection churn.

---

## 5. Cookies for an app behind cloudflared with a plain-HTTP origin

- Client sees `https://rss.example.com`; the browser's notion of "secure context" is the edge TLS, so `Secure` cookies set by a plain-HTTP origin are accepted and sent [I from MDN + the edge always using HTTPS: MDN "Secure: Indicates that the cookie is sent to the server only when a request is made with the `https:` scheme (except on localhost)"]. Go's `http.SetCookie` does not care about the origin's own scheme.
- `X-Forwarded-Proto: https` [V, §3.3]. cloudflared passes it through unchanged [V, no rewriting in source]. Use it (only from the trusted proxy IP) to decide `Secure`.
- LAN access at `http://192.0.2.50:<port>`: browsers will not send `Secure` cookies over plain http, so a hard-coded `Secure` breaks LAN login. Set `Secure` conditionally: true when the effective scheme is https (trusted `X-Forwarded-Proto`/`CF-Visitor` or real TLS), false on LAN http. This also rules out `__Host-`/`__Secure-` prefixes unless LAN access is dropped.
- SameSite [V MDN]: `Lax` = same-site requests plus cross-site top-level safe navigations; `Strict` = same-site only; `None` requires `Secure`. Access's own defaults: application-domain `CF_Authorization` "HttpOnly: Admin choice (Default: None)", "SameSite: Admin choice (Default: None)", and "If you are receiving the ERR_TOO_MANY_REDIRECTS errors, make sure your SameSite setting is set to None or Lax." - leave Access's cookie settings at defaults or Lax; do not enable "Cookie Path Attribute" or "Binding cookie" (binding cookie is browser-only and Cloudflare says not to use it for non-browser tools; irrelevant on the bypassed API anyway).
- iOS standalone PWA [U, firt.dev / netguru / Apple forums]: a home-screen web app has its own cookie/Web Storage/IndexedDB partition separate from Safari (one-time cookie copy at install time). Consequences: the user must log in (Access OTP and, if used, Kipple) inside the PWA; a Safari login does not carry over. The OTP email "sign in" link opens in Safari, not the PWA, so the flow inside the PWA is: request code → read code from Mail → type it into the PWA [I]. Same-site first-party cookies with `SameSite=Lax` work normally inside the PWA. WebKit's 7-day ITP cap targets script-writable storage; server-set `HttpOnly` cookies are not subject to it [U, general WebKit knowledge].
- Recommended Kipple session cookie: name `kipple_session`; `Path=/`; no `Domain` (host-only); `HttpOnly`; `SameSite=Lax`; `Secure` when effective scheme is https; `Max-Age` ≈ 30 days (longer than Access's session so the Access OTP, not Kipple, is the thing that expires first); rotate on login. Consider `Cache-Control: private, no-store` on any response that sets it. If you adopt §3.2 (trust the Access JWT), tunnel traffic needs no Kipple cookie at all; the cookie exists for LAN only.
- Access session duration for the UI app: default 24h ("If neither are set, defaults to 24 hours"); configurable per app/policy up to the dashboard's maximum; a long duration (e.g. 1 month) reduces OTP prompts on the phone.

---

## 6. Cloudflare-specific gotchas for a feed reader behind the proxy

### 6.1 Timeouts [V] (https://developers.cloudflare.com/fundamentals/reference/connection-limits/, updated Jul 23, 2026 - note the task's "100 s" is outdated)
Between Cloudflare and origin: Complete TCP Connection 19 s (522); TCP ACK Timeout 90 s (522); TCP Keep-Alive Interval 30 s (520); **Proxy Idle Timeout 900 s (520)**; **Proxy Read Timeout 125 s (524)**, "Yes, for Enterprise zones" configurable; Proxy Write Timeout 30 s (524); HTTP/2 Connection Idle 900 s. Between client and Cloudflare: HTTP/1.1 keep-alive 400 s, HTTP/2 idle 400 s. 524 page: "the origin did not provide an HTTP response before the default 125 seconds Proxy Read Timeout" and "Enterprise customers can increase the 524 timeout up to 6,000 seconds". For tunnels: "refer to Origin configuration to view or modify your connection settings" (keepAliveTimeout 1m30s etc.).

### 6.2 SSE
- cloudflared flushing [V, `connection/connection.go` master]: `flushableContentTypes = []string{"text/event-stream", "application/grpc", "application/x-ndjson"}`; `shouldFlush(headers)` returns true when `Content-Length` is absent, or `Transfer-Encoding` contains `chunked`, or `Content-Type` has one of those prefixes. Comment: "some frameworks don't respect the `Content-Type` header ... assume that responses without `Content-Length` or with `Transfer-Encoding: chunked` are streams, and therefore, should be flushed right away to the eyeball." In `connection/http2.go` `WriteRespHeaders` sets `rp.shouldFlush = true` when `shouldFlush(header)` and flushes on every write. Over QUIC (the default protocol) the adapter writes straight to the QUIC stream ("no-op Flush because this adapter is over a quic.Stream").
- Known issue [U]: cloudflare/cloudflared#1449 (open; cloudflared 2025.2.1) reports GET SSE buffered until close on a **Quick Tunnel** while POST streams; reporter and others say named tunnels stream line-by-line. #199 (closed, 2019-era) was the original "SSE buffered" report. Test the real named tunnel with `curl -N https://rss.example.com/events` before relying on SSE.
- Edge: `text/event-stream` is **not** in Cloudflare's compressible content-type list [V, https://developers.cloudflare.com/speed/optimization/content/compression/ - list contains text/html, text/plain, application/json, application/rss+xml, application/xml, ... but not text/event-stream], so Cloudflare will not gzip/brotli the stream. Still send `Cache-Control: no-cache, no-transform` (Cloudflare: "If you do not want a particular response from your origin to be encoded with Brotli/Gzip ... include a `cache-control: no-transform` HTTP header") and `X-Accel-Buffering: no` (harmless), no `Content-Length`. Send a heartbeat comment (`: ping\n\n`) every 15-30 s so no read gap approaches the 125 s Proxy Read Timeout and the 30 s TCP keep-alive/idle logic never sees a silent stream; expect connections to drop on Cloudflare deploys and reconnect with `Last-Event-ID` [I]. Cloudflare's own advice for long HTTP requests is status polling; SSE with heartbeats is the accepted pattern.
- Not needed for the Reader API: client A/NNW use plain request/response; SSE is UI-only.

### 6.3 WebSockets [V] (https://developers.cloudflare.com/network/websockets/)
"Cloudflare supports proxied WebSocket connections without additional configuration." "WebSockets are supported on all Cloudflare plans." Zone toggle at Network > WebSockets. "Cloudflare will close a WebSocket connection when no data is transmitted in either direction for a period of time ... implement a client-side heartbeat (ping/pong) mechanism." "When Cloudflare releases new code to its global network, we may restart servers, which terminates WebSockets connections." Not compatible with Argo Smart Routing. cloudflared handles the 101 upgrade (`proxy/proxy.go` `if resp.StatusCode == http.StatusSwitchingProtocols` path). SSE is simpler for Kipple's one-way needs.

### 6.4 Request body limit [V] (https://developers.cloudflare.com/cache/concepts/default-cache-behavior/#upload-limits)
"Max upload size | 100 MB | 100 MB | 200 MB | Up to 5 GB" (Free / Pro / Business / Enterprise). OPML imports are far below this. Request headers total 128 KB; URL 16 KB.

### 6.5 Caching [V]
"Cloudflare only caches based on file extension and not by MIME type. The Cloudflare CDN does not cache HTML or JSON by default." "Cloudflare does not cache the resource when: The `Cache-Control` header is set to `private`, `no-store`, `no-cache`, or `max-age=0`." Free/Pro/Business have Origin Cache Control on and cannot disable it. Set `Cache-Control: private, no-store` on every Reader API and UI JSON response and on HTML; static assets with hashed filenames can be `public, max-age=31536000, immutable`. Note the Bypass path is still subject to zone-level cache/Page Rules ("security settings revert to the defaults configured for the zone and any configured Page Rules"), so a "Cache Everything" rule would also cache API JSON - do not add one for this host. `Accept-Encoding` to the origin is always `br, gzip`; Kipple may gzip JSON itself or let the edge do it (application/json is compressible).

### 6.6 Image proxy vs. the API [I]
Kipple's image proxy (e.g. `/img?u=...`) lives under the OTP-protected app: fine for the browser/PWA (has `CF_Authorization`). client A/NNW have no Access cookie, so any `<img src="https://rss.example.com/img?...">` in API item content would 302 to the login page → broken images. API responses must return original remote image URLs (no rewriting); the UI-only rewrite must happen client-side or in a UI-specific endpoint. Do not put an image proxy under `/api/greader.php` either - that would be an unauthenticated open proxy on a public host.

---

## 7. Verification checklist after cutover (curl from outside the LAN, e.g. phone on cellular or `curl` via a VPS)
```
curl -sI https://rss.example.com/                      # expect 302 → https://<team>.cloudflareaccess.com/cdn-cgi/access/login/rss.example.com?...
curl -si -X POST -d 'Email=owner&Passwd=wrong' https://rss.example.com/api/greader.php/accounts/ClientLogin
                                                    # expect Kipple's own 401/403 text, NOT a 302 to cloudflareaccess.com (proves Bypass wins)
curl -si https://rss.example.com/api/greader.php/reader/api/0/user-info   # 401 from Kipple, not 302
curl -sI https://rss.example.com/fever                 # after removing the old bypass app: 302 to Access
docker logs cloudflared 2>&1 | grep -c "Updated to new configuration"   # on Host-B, confirms the pushed ingress version
```
Then add the FreshRSS account in client A (Server `https://rss.example.com/api/greader.php`) and client B (FreshRSS, API URL same value).


## Claims
- [high LB] Cloudflare Access: when multiple applications cover a common root path, the more specific path wins and sub-paths without their own app inherit the parent app's rules ("the more specific rule for dashboard.com/eng/exec takes precedence, and no rule is inherited from dashboard.com/eng. If no separate, specific rule is set ... it will inherit any rules set for dashboard.com/eng"). (https://developers.cloudflare.com/cloudflare-one/access-controls/policies/app-paths/)
- [high] Access application paths support `*` wildcards in subdomain and path with at most one wildcard per dot/slash segment; `example.com/alpha/*` does not cover `example.com/alpha`; a mid-path wildcard covers multiple segments; ports, query strings and `#` anchors are unsupported in app paths. (https://developers.cloudflare.com/cloudflare-one/access-controls/policies/app-paths/)
- [high LB] The Bypass action disables Access enforcement for matching traffic, is not logged, cannot use identity selectors, and Cloudflare's documented pattern is a separate application scoped to the path (e.g. `test.example.com/admin/<your-url>`) with policy `Bypass | Include | Everyone`. (https://developers.cloudflare.com/cloudflare-one/access-controls/policies/)
- [high] Access evaluates Bypass and Service Auth policies first (top to bottom), then Block and Allow; Access is deny-by-default so a user must match an Allow policy. (https://developers.cloudflare.com/cloudflare-one/access-controls/policies/)
- [high LB] Access checks every HTTP request for a valid `CF_Authorization` cookie and blocks requests without it; failed non-browser authentication returns a 302 redirect to the Access login page by default, and API clients/CLI tools cannot complete that flow. (https://developers.cloudflare.com/cloudflare-one/access-controls/access-settings/session-management/)
- [medium] The unauthenticated redirect target is `https://<team>.cloudflareaccess.com/cdn-cgi/access/login/<hostname>?kid=...&redirect_url=<path>&meta=...`, an HTML login page. (https://community.cloudflare.com/t/cloudflare-access-service-token-returning-302-found-despite-correct-policy-setup/842026)
- [high LB] Service tokens are presented as `CF-Access-Client-Id` and `CF-Access-Client-Secret` request headers (or a single configured header via `read_service_tokens_from_header` carrying a JSON object), and require a Service Auth policy; client A/client B cannot send these, so Service Auth is not viable for the Reader API. (https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/)
- [high] Access application schema: `domain` is "The primary hostname and path secured by Access" (example `test.example.com/admin`); `destinations[].uri` may include domain+path with wildcards; `policies[]` have `precedence`; policy `decision` values are `allow`, `deny`, `non_identity`, `bypass`; `service_auth_401_redirect` returns 401 for Service Auth blocks; cookie attributes `http_only_cookie_attribute`, `same_site_cookie_attribute`, `path_cookie_attribute`, `enable_binding_cookie`; response includes `aud`. (https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/zero_trust_access_application.md)
- [high LB] FreshRSS clients are pointed at `https://host/api/greader.php` and call `/api/greader.php/accounts/ClientLogin` and `/api/greader.php/reader/api/0/...`; client A is listed as a compatible client. (https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/docs/en/developers/06_GoogleReader_API.md)
- [high LB] client B's Reader API client uses the user-entered endpoint URL verbatim as the base (`case .generic, .freshRSS: return accountSettings.endpointURL`) and appends `/accounts/ClientLogin`, `/reader/api/0/token`, `/reader/api/0/tag/list`, `/reader/api/0/subscription/list|edit|quickadd|import`, `/reader/api/0/stream/items/contents|ids`, `/reader/api/0/edit-tag`, `/reader/api/0/disable-tag`, `/reader/api/0/rename-tag`; the macOS placeholder is `https://fresh.rss.net/api/greader.php`. (https://raw.githubusercontent.com/Ranchero-Software/client B/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift)
- [high LB] Miniflux mounts the Google Reader API at the site root: `POST /accounts/ClientLogin`, `GET /reader/api/0/token`, `/reader/api/0/edit-tag`, `/reader/api/0/tag/list`, `/reader/api/0/user-info`, `/reader/api/0/subscription/list|edit|quickadd`, `/reader/api/0/stream/items/ids|contents`, `/reader/api/0/mark-all-as-read`, plus a `/reader/api/0/` fallback - a root layout would need two Access bypass apps. (https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go)
- [high LB] Access sends the application JWT to the origin as the `Cf-Access-Jwt-Assertion` request header (and as the `CF_Authorization` cookie for browsers); Cloudflare recommends validating the header, not the cookie. (https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/)
- [high LB] Access public signing keys are at `https://<team-name>.cloudflareaccess.com/cdn-cgi/access/certs` (`keys` JWK set, `public_cert`, `public_certs`); keys rotate every 6 weeks with the previous key valid 7 more days; match by `kid`, not `public_cert`. (https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/)
- [high LB] The JWT `aud` claim carries the application's AUD tag (dashboard: Applications > Configure > Additional settings > Application Audience (AUD) Tag), which never changes unless the app is deleted/recreated; payload also has `email`, `exp`, `iat`, `nbf`, `iss` (team domain URL), `type: app`, `identity_nonce`, `sub`, `country`; algorithm RS256. (https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/application-token/)
- [high] Cloudflare's Go validation example uses `github.com/coreos/go-oidc/v3/oidc`: `oidc.NewRemoteKeySet(ctx, certsURL)` + `oidc.NewVerifier(teamDomain, keySet, &oidc.Config{ClientID: policyAUD})`, reading `r.Header.Get("Cf-Access-Jwt-Assertion")`. (https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/)
- [high LB] Origin must validate the JWT signature, not just the header's presence: "Validation of the header alone is not sufficient - the JWT and signature must be confirmed to avoid identity spoofing." (https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/application-token/)
- [high LB] cloudflared's `access` origin parameter ("Protect with Access") makes cloudflared validate `Cf-Access-Jwt-Assertion` for all L7 requests on that ingress rule; enabling it on the whole rss.example.com rule would reject the bypassed API path, which carries no JWT. (https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/)
- [high LB] Cloudflare's edge adds `CF-Connecting-IP` (only on edge→origin traffic), `X-Forwarded-For`, `X-Forwarded-Proto` (set to the client's protocol, `https` by default, client-supplied values overwritten), `Cf-Ray`, `CF-Visitor: {"scheme":"https"}`, `CF-IPCountry`, `CDN-Loop: cloudflare`; it also forces `Connection: Keep-Alive` and `Accept-Encoding: br, gzip` toward the origin. (https://developers.cloudflare.com/fundamentals/reference/http-headers/)
- [high LB] cloudflared forwards requests to the origin without altering the URI path, preserves the eyeball `Host` header (unless `httpHostHeader` is set, in which case the original Host goes to `X-Forwarded-Host`), and adds no `X-Forwarded-For`/`X-Real-IP` of its own; edge headers pass through. (https://raw.githubusercontent.com/cloudflare/cloudflared/master/ingress/origin_proxy.go)
- [high LB] Remotely-managed tunnel configuration is stored at Cloudflare and edited in the dashboard (Networking > Tunnels > Routes > Edit route > Additional application settings) or via `PUT /accounts/{account_id}/cfd_tunnel/{tunnel_id}/configurations` with `config.ingress[{hostname,service,path,originRequest}]`; `GET` returns `config`, `version`, and `source` (`local` | `cloudflare`). (https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/subresources/configurations/methods/get/)
- [high LB] A running cloudflared receives new remote configuration via the edge-invoked `UpdateConfiguration` RPC and applies it in place (`Orchestrator.UpdateConfig` → `updateIngress`, logs "Updated to new configuration" with the version), so ingress changes need no cloudflared restart. (https://raw.githubusercontent.com/cloudflare/cloudflared/master/orchestration/orchestrator.go)
- [high] Ingress `path` is a Go regexp (`Path *Regexp`, matched with `MatchString`); cloudflared matches paths only for rule selection and forwards the full path unmodified. (https://raw.githubusercontent.com/cloudflare/cloudflared/master/ingress/rule.go)
- [high LB] `originServerName` is the hostname cloudflared expects on the origin's TLS certificate (default: hostname from the service URL); it and `noTLSVerify` are TLS-only settings and are irrelevant once the service is `http://192.0.2.50:<port>`. (https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/)
- [high] Cloudflare↔origin limits: Proxy Read Timeout 125 s (HTTP 524, Enterprise-configurable up to 6000 s), Proxy Write Timeout 30 s, Proxy Idle Timeout 900 s, TCP connect 19 s (522), TCP keep-alive interval 30 s; client↔Cloudflare HTTP/1.1 keep-alive and HTTP/2 idle 400 s. (The commonly cited 100 s figure is outdated.) (https://developers.cloudflare.com/fundamentals/reference/connection-limits/)
- [high] cloudflared flushes response bytes to the edge immediately when `Content-Type` starts with `text/event-stream`, `application/grpc` or `application/x-ndjson`, or when `Content-Length` is absent, or when `Transfer-Encoding` contains `chunked` (`shouldFlush` in connection/connection.go); over QUIC writes go directly to the stream. (https://raw.githubusercontent.com/cloudflare/cloudflared/master/connection/connection.go)
- [high] `text/event-stream` is not in Cloudflare's list of compressible content types, so the edge will not gzip/brotli SSE; `cache-control: no-transform` from the origin additionally prevents recompression and Content-Length changes. (https://developers.cloudflare.com/speed/optimization/content/compression/)
- [high] WebSockets are proxied on all plans without extra configuration; Cloudflare closes idle WebSocket connections and may terminate them on deploys, so a heartbeat is recommended. (https://developers.cloudflare.com/network/websockets/)
- [high] Max upload (request body) size is 100 MB on Free and Pro, 200 MB Business, up to 5 GB Enterprise. (https://developers.cloudflare.com/cache/concepts/default-cache-behavior/)
- [high] Cloudflare does not cache HTML or JSON by default (caching is by file extension) and does not cache when the origin sends `Cache-Control: private`, `no-store`, `no-cache`, or `max-age=0`; Free/Pro/Business have Origin Cache Control enabled and cannot disable it. (https://developers.cloudflare.com/cache/concepts/default-cache-behavior/)
- [high] Access's application-domain `CF_Authorization` cookie defaults to HttpOnly/SameSite = admin choice (default None); Cloudflare warns that SameSite=Strict can cause ERR_TOO_MANY_REDIRECTS and to use None or Lax; Binding Cookie and HttpOnly should not be enabled for non-browser tools. (https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/)
- [high] MDN: `Secure` cookies are sent only over `https:` (except localhost); `SameSite=Lax` sends the cookie for same-site requests and cross-site top-level safe navigations; `SameSite=None` requires `Secure`. (https://raw.githubusercontent.com/mdn/content/main/files/en-us/web/http/reference/headers/set-cookie/index.md)
- [medium] On iOS, a home-screen (standalone) web app has a cookie/storage partition separate from Safari, with a one-time cookie copy when the app is added; logins do not carry over between Safari and the PWA. (https://firt.dev/ios-14/)
- [high] The `/cdn-cgi/` path on every proxied hostname is managed and served by Cloudflare and cannot be customized; Access uses `/cdn-cgi/access/...` there, so Kipple must not route anything under `/cdn-cgi/`. (https://developers.cloudflare.com/fundamentals/reference/cdn-cgi-endpoint/)
- [medium] cloudflared GitHub issue #1449 (open, cloudflared 2025.2.1) reports GET SSE responses buffered until connection close on Quick Tunnels while POST streams; named tunnels are reported to stream correctly. (https://github.com/cloudflare/cloudflared/issues/1449)
- [medium] With `--token`/`TUNNEL_TOKEN`, a local `config.yml` ingress section is ignored and cloudflared always uses the remotely-managed configuration (GitHub issues #633, #933, #1029, #1520). (https://github.com/cloudflare/cloudflared/issues/633)

## Open questions
- Path-app precedence edge cases: two 2025 community threads (820213, 816924) report inconsistent 'most specific wins' behavior, apparently when overlapping *wildcard* patterns are involved; could not read them (Cloudflare bot challenge). Verify empirically after creating the `rss.example.com/api/greader.php` Bypass app: `curl -si -X POST .../api/greader.php/accounts/ClientLogin` must return Kipple's own 401/403, not a 302 to cloudflareaccess.com.
- Access path matching case sensitivity and treatment of a dot in the path segment (`greader.php`) are not documented; the existing `/fever` bypass proves plain-path bypass apps work, but confirm `.php` in the path is accepted by the dashboard/API.
- Whether Cloudflare strips or overwrites a client-supplied `Cf-Access-Jwt-Assertion` header on Bypass paths is not documented; treat it as untrusted on `/api/greader.php` regardless (Kipple must never honor it there).
- Whether the Access application-domain `CF_Authorization` cookie is forwarded to the origin in all cases (docs say the cookie 'is not guaranteed to be passed'); design around the header only.
- Exact TCP source address Kipple will see for tunnel traffic (expected Host-B 192.0.2.192 via Docker default-bridge NAT; would differ if cloudflared were moved to Host-A or to host networking). Confirm from Kipple's access log before hard-coding a trusted-proxy IP.
- Whether the Cloudflare API `PUT .../cfd_tunnel/{id}/configurations` accepts a partial `ingress` array or requires the full set (treat as full replacement: GET, edit one rule, PUT everything back including the `http_status:404` catch-all).
- SSE behavior through this specific named tunnel over QUIC vs http2 fallback has not been tested; issue #1449 concerns Quick Tunnels but a live `curl -N` test is cheap and should gate any UI dependence on SSE.
- iOS OTP flow inside a standalone PWA: the emailed sign-in link opens Safari (separate cookie jar); confirm that typing the 6-digit code inside the PWA completes Access login, and consider raising the UI app's Access session duration to reduce prompts.
- Access session-duration maximum and the interaction with Kipple's own 30-day cookie (if the JWT-trust design in §3.2 is adopted, Kipple's cookie is LAN-only and this does not matter).

## Sources
- https://developers.cloudflare.com/cloudflare-one/access-controls/policies/app-paths/
- https://developers.cloudflare.com/cloudflare-one/access-controls/policies/
- https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/self-hosted-public-app/
- https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/
- https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/validating-json/
- https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/application-token/
- https://developers.cloudflare.com/cloudflare-one/access-controls/applications/http-apps/authorization-cookie/cors/
- https://developers.cloudflare.com/cloudflare-one/access-controls/access-settings/session-management/
- https://developers.cloudflare.com/cloudflare-one/access-controls/service-credentials/service-tokens/
- https://developers.cloudflare.com/cloudflare-one/access-controls/troubleshooting/
- https://developers.cloudflare.com/cloudflare-one/tutorials/access-workers/
- https://developers.cloudflare.com/cloudflare-one/reusable-components/custom-pages/access-login-page/
- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/configure-tunnels/origin-parameters/
- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/create-remote-tunnel/
- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/get-started/tunnel-useful-terms/
- https://developers.cloudflare.com/cloudflare-one/networks/connectors/cloudflare-tunnel/routing-to-tunnel/
- https://developers.cloudflare.com/tunnel/configuration/
- https://developers.cloudflare.com/tunnel/features/locally-managed-tunnels/configuration-file/
- https://developers.cloudflare.com/tunnel/troubleshooting/
- https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/subresources/configurations/methods/update/
- https://developers.cloudflare.com/api/resources/zero_trust/subresources/tunnels/subresources/cloudflared/subresources/configurations/methods/get/
- https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/zero_trust_access_application.md
- https://raw.githubusercontent.com/cloudflare/terraform-provider-cloudflare/main/docs/resources/zero_trust_access_policy.md
- https://developers.cloudflare.com/fundamentals/reference/http-headers/
- https://developers.cloudflare.com/fundamentals/reference/connection-limits/
- https://developers.cloudflare.com/fundamentals/reference/cdn-cgi-endpoint/
- https://developers.cloudflare.com/support/troubleshooting/http-status-codes/cloudflare-5xx-errors/error-524/
- https://developers.cloudflare.com/network/websockets/
- https://developers.cloudflare.com/speed/optimization/content/compression/
- https://developers.cloudflare.com/cache/concepts/default-cache-behavior/
- https://developers.cloudflare.com/cache/concepts/cache-control/
- https://raw.githubusercontent.com/cloudflare/cloudflared/master/connection/connection.go
- https://raw.githubusercontent.com/cloudflare/cloudflared/master/connection/http2.go
- https://raw.githubusercontent.com/cloudflare/cloudflared/master/connection/quic_connection.go
- https://raw.githubusercontent.com/cloudflare/cloudflared/master/orchestration/orchestrator.go
- https://raw.githubusercontent.com/cloudflare/cloudflared/master/tunnelrpc/pogs/configuration_manager.go
- https://raw.githubusercontent.com/cloudflare/cloudflared/master/ingress/origin_proxy.go
- https://raw.githubusercontent.com/cloudflare/cloudflared/master/ingress/rule.go
- https://raw.githubusercontent.com/cloudflare/cloudflared/master/proxy/proxy.go
- https://github.com/cloudflare/cloudflared/issues/1449
- https://github.com/cloudflare/cloudflared/issues/199
- https://github.com/cloudflare/cloudflared/issues/633
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/docs/en/developers/06_GoogleReader_API.md
- https://raw.githubusercontent.com/FreshRSS/FreshRSS/edge/docs/en/users/06_Mobile_access.md
- https://raw.githubusercontent.com/Ranchero-Software/client B/main/Modules/Account/Sources/Account/ReaderAPI/ReaderAPICaller.swift
- https://raw.githubusercontent.com/Ranchero-Software/client B/main/Mac/Preferences/Accounts/AccountsReaderAPIWindowController.swift
- https://raw.githubusercontent.com/miniflux/v2/main/internal/googlereader/handler.go
- https://raw.githubusercontent.com/mdn/content/main/files/en-us/web/http/reference/headers/set-cookie/index.md
- https://firt.dev/ios-14/
- https://www.netguru.com/blog/how-to-share-session-cookie-or-state-between-pwa-in-standalone-mode-and-safari-on-ios
- https://community.cloudflare.com/t/cloudflare-access-service-token-returning-302-found-despite-correct-policy-setup/842026
- https://community.cloudflare.com/t/policy-inheritance-not-prioritizing-most-specific-path/820213
- https://community.cloudflare.com/t/how-do-application-wildcards-deal-with-multiple-matches/816924
- https://wilw.dev/blog/2021/07/12/freshrss/
