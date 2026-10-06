# pwa-ui-fonts

# Kipple UI-phase platform research (2026-09-24)

Scope: iOS standalone PWA constraints (iOS 18 → 26, plus what already changed in iOS/Safari 27), UI stack state, and the bundled-font pipeline. Everything marked **[verified]** was read in primary source/docs/source code this session; **[inferred]** is my synthesis; **[community]** is a third-party write-up not confirmed by Apple.

---

## 0. Things that changed in 2025-2026 that the brief did not assume

1. **Safari/iOS 27 has shipped.** `WebKit Features for Safari 27.0` (webkit.org/blog/18325, mid-Sept 2026; 9to5Mac 2026-09-17). PWA-relevant items **[verified]**: "Service Worker static routing API" ("declare routing rules that the browser can use to bypass the service worker entirely for certain requests"), CSS **scroll anchoring** (`overflow-anchor`), `cookieStore.set()` gains `maxAge`, ReadableStream async iteration. No changes to viewport-fit, safe-area, theme-color, Web Share, or home-screen web apps in 27.0. The brief's "current iOS 26" is one major behind; iOS 18/26/27 are the testing matrix now.
2. **iOS/iPadOS 26: every site added to Home Screen opens as a web app by default.** WebKit blog 17333 **[verified]**: "By default, every website added to the Home Screen opens as a web app. If the user prefers to add a bookmark for their browser, they can disable 'Open as Web App' when adding to Home Screen - even if the site is configured to be a web app." and "there are zero requirements for 'installability' in Safari." Manifest still matters: "If you define your icons in the manifest, they're used."
3. **Safari 26 Liquid Glass broke `theme-color` in the browser.** MDN BCD `html/elements/meta/name/theme-color` safari entry **[verified]**: `"notes": "From Safari 26, the theme color is only used for installed web apps."` In browser tabs Safari 26 tints the toolbar from the page: Ben Frain **[community]**: "By default, that tint color is taken from the background color of the body… Except when you show a fixed position element… iOS then tries to use the background-color of the fixed position element." jahir.dev reverse-engineered sampling **[community]**: a `position: fixed|sticky` element "within 4 pixels from the top or 3 pixels from the bottom on iOS; at least 80% wide on iOS or 90% wide on macOS; and at least 3 pixels high". 1ar.io **[community]**: transparent root backgrounds "often fall back to white"; always set explicit `html, body { background-color }`; `opacity:0`/`pointer-events:none` overlays still get sampled - use `display:none`. Bugs: webkit.org/b/300965 (resolved), 302272 (dup). nasedk.in notes a WebKit commit 2026-07-29 "adds system-background extensions in leading obscured inset areas" for iOS 27.
4. **iPadOS 26 windowed web apps**: `env(safe-area-inset-*)` does **not** account for the new window controls, and Window Controls Overlay is unsupported on iPadOS (dev.to/reinhart1010 **[community]**). Expect the top-left of a windowed iPad web app to be covered.
5. **`interactive-widget` viewport keyword**: WebKit implemented it in source (~Aug 2026), behind a flag in STP 252; **not shipped in Safari 26 or 27.0** (bram.us 2026-09-11 **[verified]**: "I will probably have to wait for Safari 27.1"). BCD `css/types/env/keyboard-inset-*`: `safari: version_added false` **[verified]**.
6. **shadcn/ui switched its default primitives from Radix to Base UI (July 2026)**; CLI is now `shadcn` 4.21.0; `npx shadcn init` defaults to Base UI, `-b radix` keeps Radix ("Radix is not being deprecated… every update and new component will ship for both libraries") **[verified]**. Sept 2026: components import `cn` from the `cn` package.
7. **Vite 8 (2026-03-12)** replaced Rollup+esbuild with Rolldown/Oxc; `build.rollupOptions` → `build.rolldownOptions`; default `build.target` Safari 16.0 → 16.4; Node `^20.19.0 || >=22.12.0` **[verified]**.
8. **Gentium 7.000 (2025-06-02)** renamed the families: "*Gentium Book Plus* is now *Gentium Book*", added 500/600 weights, "default line spacing has been significantly decreased", Book is a separate download **[verified]**. Google Fonts still ships "Gentium Book Plus" (6.101 statics).

Current npm versions (registry, 2026-09-24) **[verified]**: react 19.3.0, vite 8.3.1, @vitejs/plugin-react 6.1.1, tailwindcss / @tailwindcss/vite 4.3.3, shadcn 4.21.0, @tanstack/react-query 5.103.2, @tanstack/react-virtual 3.14.13, @use-gesture/react 10.3.1 (published 2024-03-21 - dormant), motion 13.4.3 (=framer-motion), react-hotkeys-hook 5.3.3, tinykeys 4.0.0 (ESM, `engines.node >=22`), vite-plugin-pwa 1.3.0, workbox-* 7.4.1, typescript 7.0.2.

---

## A. iOS standalone (Home Screen) web app

### A1. Manifest + Apple meta/link tags - what Safari actually honors
- Manifest `display`: `standalone`/`fullscreen` made a site a web app pre-iOS 26 (WebKit blog 13878 **[verified]**: "create a manifest file (with its `display` member set to `standalone` or `fullscreen`)"). firt.dev/notes/pwa-ios **[community]**: `standalone` and `browser` since 11.3; `minimal-ui`/`fullscreen` not supported (fullscreen is treated as standalone).
- `icons`: Safari 15.4+ (WebKit blog 12445 **[verified]**: "Safari and iOS use manifest-declared icons when there is no `apple-touch-icon` defined in the HTML head"). OpenPWA/firt **[community]**: `apple-touch-icon` takes precedence; SVG, `maskable`, `monochrome` are "recognized but ignored by WebKit"; iOS "doesn't support transparent icons… supply square icons with no transparency and no rounded corners; iOS will round them". Ship one 180×180 PNG `<link rel="apple-touch-icon" href="/apple-touch-icon.png">` plus manifest PNGs (192/512). iOS 18 dark/tinted icon appearance: no manifest/API support; only hack is JS-injected `apple-touch-icon` by `prefers-color-scheme` at install time (Apple forum 761615 **[community]**).
- `id`: iOS 16.4+ - "a string (in the form of a URL) that acts as the unique identifier"; multiple installs are distinguished by user-chosen name + `id` **[verified]**.
- `theme_color`: conflicting sources. firt: "since 15.0"; Progressier: ignored for the standalone status bar; BCD: from Safari 26 theme color "only used for installed web apps". Treat as **device-test item** (Open question 1).
- `background_color`, `shortcuts`: not supported (firt **[community]**). Splash: only `<link rel="apple-touch-startup-image" media="(device-width:…) and (-webkit-device-pixel-ratio:…)">` per device; Apple's archived doc **[verified]**: "By default, a screenshot of the web application the last time it was launched is used." Manifest `background_color` is not used for the launch screen on iOS.
- `<meta name="apple-mobile-web-app-capable" content="yes">` - legacy; Chrome DevTools warns and suggests `mobile-web-app-capable`; firt: Safari falls back to the Apple tag only if the manifest cannot be loaded. Include both (harmless). `<meta name="apple-mobile-web-app-title">` overrides `<title>` for the icon label. `window.navigator.standalone` (boolean, WebKit-only) detects standalone; `matchMedia('(display-mode: standalone)')` is the portable check.
- Status bar: `<meta name="apple-mobile-web-app-status-bar-style" content="default|black|black-translucent">` - "has no effect unless you first specify standalone mode" (Apple **[verified]**). Progressier **[community]**: `default` = "white background and black symbols"; `black` = all black; `black-translucent` = "entirely transparent, and the info symbols are all white… good option if the body of your app is dark", and the page draws under the status bar ("if you want to use the entire screen, set the status bar style to translucent black" - Apple **[verified]**). Consequence for Kipple's light themes: `black-translucent` gives white glyphs on your white/sepia header unless the status-bar strip is painted dark. See Open question 1.
- Install prompt: none; no `beforeinstallprompt`; users use Share → Add to Home Screen (iOS 16.4+ also from third-party browsers/SFSafariViewController if the browser opts in) **[verified]**.

### A2. viewport-fit=cover and env(safe-area-inset-*)
- `<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">`. WebKit blog 7929 **[verified]**: default `viewport-fit=auto` insets content and fills the inset "with the page's `background-color` (as specified on the `<body>` or `<html>` elements)"; `cover` lays "the page… to the full size of the screen". `env(safe-area-inset-top|right|bottom|left)` since iOS 11.2 (`constant()` only in 11.0-11.1; BCD safari 11 → env 11.1 **[verified]**). Canonical pattern: `padding-left: max(12px, env(safe-area-inset-left));` inside `@supports (padding: max(0px))`.
- Standalone vs Safari **[inferred from Apple docs + community]**: in Safari the insets also include browser chrome regions in the new bottom/compact tab modes (1ar.io guard bands: "Top bleed: 62px, Bottom bleed: 136px" for fullscreen layouts **[community]**); in standalone there is no toolbar, so `safe-area-inset-bottom` ≈ home-indicator height and `safe-area-inset-top` ≈ status bar/Dynamic Island height, and only when `black-translucent` + `viewport-fit=cover` push content under the bar. iPadOS 26 windowed mode does not expose window-control insets (A0 #4).
- `viewport-fit` values per MDN: `auto | contain | cover` **[verified]**. Also `shrink-to-fit=no` for iPad Split View (firt).

### A3. 100vh vs 100dvh vs -webkit-fill-available
- `svh/lvh/dvh` (and `svw/lvw/dvw`) shipped Safari 15.4 (WebKit blog 12445 **[verified]**: "`100dvh` refers to 100% of the dynamic viewport height - meaning the value will change as the user scrolls"). caniuse `viewport-unit-variants` ios_saf 15.4 = y **[verified]**. iOS 18+ floor means `dvh` is safe; `-webkit-fill-available` is a pre-15.4 hack and can be dropped.
- In standalone there is no collapsing toolbar, so `100vh`, `100dvh`, `100svh` coincide **[inferred]**; in Safari browser mode use `100dvh` for the shell and never `100vh`. 1ar.io **[community]**: `100dvh` "alone does not solve toolbar tinting, hidden overlays, or chrome sampling".
- Body scroll vs app shell: 1ar.io recommends against `body { overflow: hidden }` **in Safari 26 browser mode** ("let `html` remain scrollable. If you need to block page movement, block the gesture inside the shell"). In standalone an inner scroller is the standard pattern and avoids the root rubber band (A4).

### A4. Overscroll, rubber band, custom pull-to-refresh
- `overscroll-behavior`: Safari 16 (BCD **[verified]**, flagged `partial_implementation` with note "The property has no effect on scroll containers that have no scrollable overflow"; caniuse ios_saf 16.0 → 27.2 = y). Chrome docs **[verified]**: `contain` "prevents scroll chaining… local effects within the node are shown"; `none` also "prevents overscroll effects within the node itself (e.g. Android overscroll glow or iOS rubberbanding)".
- Native pull-to-refresh: Safari on iOS has none in browser or standalone (pixelfed #3786 **[community]**: standalone "does not refresh on overscrolling"). So Kipple must implement its own: inner scroller `overflow-y:auto; overscroll-behavior-y: contain;` + passive `touchstart/touchmove` that only arms when `scroller.scrollTop === 0` and `deltaY > threshold` (Chrome blog reference code **[verified]**: `if (document.scrollingElement.scrollTop === 0 && y > _startY && !document.body.classList.contains('refreshing'))`), then translate a spinner, release → call the "refresh all now" endpoint. Because the BCD note says `overscroll-behavior` is inert on non-overflowing containers, keep the `<html>` non-scrolling (`height:100dvh; overflow:hidden` on the shell **in standalone**) and put all scrolling in the inner element; root rubber-banding then never engages. iNoBounce-style JS is the fallback if a residual bounce is seen on the root **[inferred]**.

### A5. Web Share API in standalone
- `navigator.share({title,text,url,files})`: iOS Safari 12.2 (BCD safari 12.1, safari_ios mirrors **[verified]**); `text`, `files` and `navigator.canShare()` from Safari 14 / iOS 14 **[verified]**. caniuse note for iOS 13.0-13.1: "Did not support share click that would trigger a fetch call" (webkit bug 197779) - irrelevant for iOS 18+.
- Requirements (MDN **[verified]**): secure context; "must be triggered by 'user activation'"; rejects `NotAllowedError` when no transient activation, `AbortError` when the user cancels or no targets, `TypeError` on invalid data, `InvalidStateError` if another share is in progress. WebKit's transient-activation window is **5 s**: `static constexpr Seconds defaultTransientActivationDuration { 5_s };` (LocalDOMWindow.cpp **[verified]**) - an `await fetch()` before `share()` that outlasts 5 s throws `NotAllowedError`. Kipple shares only title+url (already in memory), so call `share()` synchronously in the tap handler.
- Works in standalone (share sheet appears). Sharing `files` from a home-screen app invokes Quick Look inside the app's single web view (opencode-manager PR **[community]**) - avoid files.
- Fallback (WebKit blog 10855 **[verified]**): `navigator.clipboard.writeText` "outside the scope of a user gesture… will result in the immediate rejection of the promise"; only on `https://`; supported types `text/plain`, `text/html`, `text/uri-list`, `image/png`; `ClipboardItem` accepts a Promise per MIME type so async data can still be written inside the gesture. Order: `if (navigator.share && (!navigator.canShare || navigator.canShare(data))) share() else writeText(url)`; treat `AbortError` as silent.

### A6. Service worker strategy for an SPA + API (Workbox 7 / vite-plugin-pwa 1.3)
- Hashed assets: precache (`precacheAndRoute`) - served cache-first; entries with hashes in the URL use `revision: null`, `index.html` gets an explicit revision because "HTML files… cannot include revisioning information in their URLs" (Workbox docs **[verified]**). Workbox diffs revisions on `install` and removes obsolete entries on `activate`; `cleanupOutdatedCaches()` for major-version cache renames.
- Navigation: `NavigationRoute(createHandlerBoundToURL('/index.html'), { denylist: [/^\/reader\//, /^\/api\//, /^\/greader\//] })`. vite-plugin-pwa exposes this as `workbox.navigateFallback` + `workbox.navigateFallbackDenylist: [/^\/api/]` **[verified]**. Keep the Google Reader endpoints and Kipple's JSON API out of the SW entirely (`NetworkOnly`/not routed) - TanStack Query already holds the client cache; a `NetworkFirst` SW layer on JSON would double-cache and can serve stale unread counts. If an offline article cache is wanted later, `NetworkFirst` with `networkTimeoutSeconds` on GET `/api/items/:id` is the only sane candidate.
- Avoiding a stale `index.html` on iOS: home-screen apps resume from a frozen state rather than navigating, so the browser-side update check often never fires (multiple GitHub post-mortems **[community]**; firt **[community]**: "a standalone PWA gets discarded every time the user moves to other app or Home Screen"). Mitigations: `registerType: 'autoUpdate'` (skipWaiting+clientsClaim), register with `updateViaCache: 'none'`, call `registration.update()` on `visibilitychange`/`pageshow`, listen for `controllerchange` and reload once, and serve `/index.html` with `Cache-Control: no-cache` from Go so the SW's own fetch of the precache manifest is never HTTP-cached. Also `crossorigin="anonymous"` on any cross-origin `<link>` you want precached.

### A7. Storage quota and eviction (WebKit "Updates to Storage Policy", Safari 17 **[verified]**)
- Origin quota "up to 60% of the total disk space" in browser apps (15% in other apps); overall "up to 80%". "When a web app is running standalone (as Home Screen Web App on iOS…), it has the same origin quota and overall quota as when it is opened in a browser app." Eviction "when exceeding the overall quota, when the system is under storage pressure, or when the site has not been interacted with by the user for some time", LRU by "the time of the last user interaction, or the time of the last storage operation". `navigator.storage.persist()`: "WebKit currently grants a request based on heuristics like whether the website is opened as a Home Screen Web App."
- 7-day ITP cap (WebKit blog 10218, iOS 13.4 **[verified]**): deletes "all of a website's script-writable storage after seven days of Safari use without user interaction on the site" (IndexedDB, LocalStorage, SessionStorage, SW registrations and cache). "Web applications added to the home screen are not part of Safari and thus have their own counter of days of use." Kipple keeps read state and stats server-side, so client storage is a cache only - correct already.
- Known regressions to remember: WebKit bug 272325 "REGRESSION (iOS 17.x): Session cookies being reset randomly in a Home Screen web app" (P2/Critical, unresolved as of Nov 2024, reports through 18.1); Apple forum 740065 (iOS 17.0.3 PWA loses IndexedDB, then localStorage). Design for re-login being cheap.

### A8. Push (note only)
Web Push exists only for Home Screen web apps since iOS 16.4, needs a user gesture to subscribe; Declarative Web Push from 18.4. Kipple does not want notifications - nothing to do, but do not call `Notification.requestPermission()` anywhere.

### A9. Add to Home Screen and login persistence - the important one
- **Storage is isolated by design.** WebKit bug 181849 (Brent Fulgham) **[verified]**: "The current behavior (on Apple platforms) is by design. Home Screen apps are created as isolated entities without shared state with the browser." Apple's 2024 EU statement described Home Screen web apps as having "isolation of storage".
- **Cookies are copied at install only on macOS Dock web apps, not iOS.** Safari 17 blog + WWDC23 session 10120 **[verified]**: "we copy website cookies when a web app on Mac is added to the Dock… From that point on, cookies are separate between Safari and the web app." and "Since local storage is not copied when a web app is created, users would have to re-authenticate". No WebKit source says iOS copies cookies (the "iOS 16.4+ shares first-party cookies" line circulating in some repos is unsupported). Assume the standalone Kipple starts logged out.
- Implications for Kipple **[inferred]**: (1) keep the *entire* auth state in an HttpOnly, `Secure`, long-lived first-party cookie (no localStorage token split); (2) the Cloudflare Access email-OTP for the UI will be prompted once more inside the standalone web view and then lives in its own cookie jar for the Access session duration - set that duration long (e.g., 1 month) or the standalone app re-prompts; (3) Cache Storage was reported shared between Safari and standalone (netguru **[community]**, old) - do not rely on it; (4) links outside the manifest `scope` open in SFSafariViewController inside the app (WWDC23 **[verified]**), which is fine for "open original article".
- Multiple installs of the same origin are allowed (name + `id`) **[verified]**; each has its own storage.
- iOS 17 bug: `prefers-color-scheme` changes did not apply in home-screen apps until relaunch; "Fixed in iOS 18." (Apple forum 739154 **[verified]**).

### A10. Status bar + dark mode
- `<meta name="color-scheme" content="light dark">` (Safari 12.1) and `<meta name="theme-color" media="(prefers-color-scheme: dark)" …>` (Safari 15; "browsers pick the first tag that matches"; Safari refuses colors near its close-button red) **[verified]**. Update `theme-color` from JS when the user picks white/sepia/green/brown/dark.
- In standalone, the only Apple-documented control is the three `apple-mobile-web-app-status-bar-style` values; the strip's background under `default` is white (Progressier) and under `black-translucent` is your page. For the seven Kipple themes, `black-translucent` + painting the top `env(safe-area-inset-top)` strip with the theme's header color is the robust approach, accepting white status glyphs on light themes unless device tests show `theme-color` now drives glyph color in installed apps on iOS 26 (Open question 1).

### A11. Keyboard avoidance
- Safari iOS resizes only the **visual** viewport when the keyboard opens (HTMHell **[verified]**: "the Visual Viewport gets resized but the Layout Viewport… remains unchanged"); Chrome ≥108/Firefox ≥132 do the same; `interactive-widget` unsupported in Safari (A0 #5). `VisualViewport` API is in Safari 13+ **[verified]**: on `visualViewport.resize`, set a CSS var to `visualViewport.height` (and `offsetTop`) and size the fixed bottom bar/search field from it. Kipple's only inputs are search, feed URL, settings - keep them in a sheet that uses `100dvh`-independent sizing.

### A12. Swipe-to-go-back vs custom swipe actions
- Since iOS 12.2 home-screen apps have the system **edge-swipe back/forward** gesture (firt medium article, via search **[community]**), and it cannot be disabled from web content: w3c/pointerevents#358 **[verified]** - "When using webviews like WKWebView directly, developers can disable this swipe gesture functionality, but it is not currently possible to do the same with web apps installed to the home screen." Ionic #22299 tracks the double-navigation it causes.
- Design rule for Kipple's row swipe (mark read / star) **[inferred]**: (1) never make navigation depend on a left-edge swipe; (2) ignore drags whose `pointerdown.clientX < ~24px` (edge zone) and let the system have them; (3) use a horizontal gesture with axis lock and `touch-action: pan-y` on rows so vertical scroll stays native; (4) keep history shallow - list ↔ article via `pushState` so the system back-swipe does something sensible (goes back to list), or use `replaceState` if you drive your own stack (the workaround pointerevents#358 mentions, with its own transition problems).

---

## B. UI implementation choices

### B1. Stack state (2026-09)
- **React 19.3 + Vite 8.3 + Tailwind 4.3 + shadcn 4.x.** Tailwind v4 floor: "Chrome 111, Safari 16.4, Firefox 128" **[verified]** - fine for iOS 18+. Setup: `npm i tailwindcss @tailwindcss/vite`, `plugins:[tailwindcss()]`, CSS `@import "tailwindcss";` **[verified]** (no PostCSS). shadcn Tailwind-v4 conventions **[verified]**: `@theme inline { --color-background: var(--background); }`, colors in OKLCH, `data-slot` on every primitive, no `forwardRef`, `new-york` style default (`default` deprecated), `tw-animate-css` replaces `tailwindcss-animate`, `toast` → `sonner`. Base UI is the default primitive set since July 2026 (`npx shadcn init` / `-b radix`).
- Vite 8: default `build.target` Safari 16.4; `build.rolldownOptions`; `oxc` replaces `esbuild` config; JS minifier Oxc, CSS Lightning CSS **[verified]**.

### B2. Server state - TanStack Query v5 (5.103)
Defaults **[verified]**: data is stale immediately (`staleTime: 0`), inactive queries GC'd after 5 min (`gcTime`), failed queries "silently retried 3 times, with exponential backoff", results "structurally shared". For a reader: set `staleTime` per query (items list 30 s, unread counts 10 s), `refetchOnWindowFocus` on (it is the standalone-app resume trigger), optimistic `setQueryData` for mark-read/star with `useMutation.onMutate`, and `queryClient.invalidateQueries` after the manual refresh-all call.

### B3. Long lists - TanStack Virtual v3 (3.14.13)
Options verified from `virtual-core/src/index.ts`: `count, getScrollElement, estimateSize, overscan (default 1), measureElement, getItemKey, paddingStart/End, scrollPaddingStart/End, scrollMargin, gap, lanes, horizontal, initialOffset, initialRect, initialMeasurementsCache, indexAttribute, rangeExtractor, isScrollingResetDelay, useScrollendEvent, useAnimationFrameWithResizeObserver, enabled, shouldAdjustScrollPositionOnItemSizeChange, onChange`; methods `getVirtualItems(), getTotalSize(), scrollToIndex(i,{align,behavior}), measure()`. Dynamic-height pattern: `<div data-index={row.index} ref={virtualizer.measureElement}>`. `useWindowVirtualizer` exists (uses `window` as scroll element; pair with `scrollMargin` = list offset). For Kipple use `useVirtualizer` against the inner scroller from A4 (window scrolling is what we are avoiding on iOS). Cards/magazine grids use `lanes` for multi-column masonry-ish layouts.

### B4. Gestures for row swipe actions
- **@use-gesture/react 10.3.1** (last release 2024-03-21 - maintenance is thin) **[verified]**: `useDrag(handler, { axis: 'x'|'y'|'lock', threshold, filterTaps (tapsThreshold 3px), preventScroll, preventScrollAxis, bounds, rubberband, from, swipe: { distance:[50,50], velocity:[0.5,0.5], duration:250 }, pointer:{touch:true}, eventOptions:{passive} })`; docs require `touch-action: none` on the element (use `pan-y` when only x is dragged).
- **Motion 13.4.3** (`import { motion } from "motion/react"`) **[verified]**: `drag="x"`, `dragConstraints` (object or ref), `dragElastic` (0-1), `dragMomentum`, `dragTransition`, `dragSnapToOrigin`, `dragDirectionLock` (source: `lockThreshold = 10` px), `dragListener`, `useDragControls`, `onDragStart/onDrag/onDragEnd(event, info)` with `info.point/delta/offset/velocity`, `whileDrag`. Known mobile issues (motion #1506/#1582/#185): lists of `drag="x"` items register small horizontal drags while scrolling unless `touch-action`/direction lock are set.
- **Plain Pointer Events** **[inferred recommendation]**: rows with `touch-action: pan-y`, `pointerdown` records start, `pointermove` decides axis after 10 px, `setPointerCapture`, translate via CSS var, `pointerup` commits if `|dx| > 40%` of row width or velocity high. Zero dependencies, no conflict with TanStack Virtual's `measureElement`, and easy to add the 24 px left-edge exclusion from A12. Pick Motion only if animated layout (list reorder, card enter/exit) is wanted anyway.

### B5. Keyboard shortcuts (j/k/s/o/r/m)
- **tinykeys 4.0.0** **[verified]**: `tinykeys(window, { "j": …, "Shift+D": …, "g i": … }, { event, timeout: 1000, ignore })`; matches `KeyboardEvent.key` and `.code`; `$mod` = Meta on Mac/Control elsewhere; by default ignores `[contenteditable], input, textarea, select` unless target; "~650 B"; ESM-only, `engines.node >= 22` (fine for Vite build).
- **react-hotkeys-hook 5.3.3** **[verified]**: `useHotkeys('j', cb)`, sequences `'g>h>i'` with `sequenceTimeoutMs` (1 s), modifiers `shift, alt, ctrl, meta, mod`, comma-separated multi-bindings, scopes. Either works; tinykeys is the smaller, framework-free choice - wrap it in one `useEffect` at the app root and dispatch to the focused item via TanStack Virtual's `scrollToIndex`.

### B6. Feedly layout anatomy (from the live Feedly CSS bundle `s1.feedly.com/web/main/main.b6eb…css`, 2026-09-24) **[verified]**
- Views: Title-only, Magazine, Cards (+ Article); density Compact/Comfortable; "each feed and category can have its own view" (docs.feedly.com).
- Cards: `.entry.cards { display:inline-block; margin-right:24px; vertical-align:top } .entry.cards:nth-child(3n){ margin-right:0 }` → **3 columns, 24 px gutter**; skeleton card `width: 251px`. Large card (Today view): `.LargeCardLayout { width:420px; padding:12px; border-radius:.375rem } .LargeCardLayout__visual { height:272px }` → image ≈396×272 ≈ **1.46:1 (≈3:2)**; `__title` margin-top 1rem, `__summary` `-webkit-line-clamp:3`; titles clamp at 5 lines (`.EntryTitleLink { -webkit-line-clamp:5 }`).
- Magazine: `.entry.magazine { width: min(100%, 624px) }` (single text column ≤624 px, thumbnail left); mini-magazine `.MiniMagazineLayout__visual { height:78px; width:130px }` → **5:3 thumbnail**, `gap:1rem`, `max-width:420px`. 2013 design post: thumbnails "96px wide (12 x 8)"; Material grid "all margins set at 16dp".
- Metadata: 13 px/16 px (`--font-optical-sizing: 28; font-size:13px; line-height:16px`), `.EntryMetadataSource { max-width:100px; overflow:hidden; text-overflow:ellipsis }` - source name first, `·` separator, relative time; body face `--font-sans-serif: 'InterVariable','InterVariable Fallback', sans-serif` with `font-variation-settings: "opsz"`.
- No-image handling: Feedly renders the text block without the visual (Medium design post: "fade the thumbnail away and fade the article's content in"); in card view the card keeps its column width and shrinks in height.
- Recommendation for Kipple **[inferred]**: cards `grid-template-columns: repeat(auto-fill, minmax(260px,1fr)); gap: 24px` (1 col <600 px, 2 cols ≥600, 3 ≥960, 4 ≥1280), image `aspect-ratio: 3/2; object-fit: cover` (magazine thumb 5:3 at 130×78 → 96×58 on phones), title `text-wrap: pretty` (Safari 26 **[verified]**) clamped 3 lines, source · time at 13/16. Image-less items: same card without the image block; optionally a 3:2 block filled with the source's favicon on the theme's surface color so grids stay aligned.

---

## C. Fonts

### C1. Sources, licenses, variable support, realistic subset sizes
Sizes below are the **bytes Google Fonts actually serves** for the latin (and latin-ext) `woff2` of each family, HEADed 2026-09-24 - i.e. real post-subsetting sizes (hinting stripped, variable where the family has axes). Latin range served by GF: `U+0000-00FF, U+0131, U+0152-0153, U+02BB-02BC, U+02C6, U+02DA, U+02DC, U+0304, U+0308, U+0329, U+2000-206F, U+20AC, U+2122, U+2191, U+2193, U+2212, U+2215, U+FEFF, U+FFFD`; latin-ext: `U+0100-02BA, U+02BD-02C5, U+02C7-02CC, U+02CE-02D7, U+02DD-02FF, U+0304, U+0308, U+0329, U+1D00-1DBF, U+1E00-1E9F, U+1EF2-1EFF, U+2020, U+20A0-20AB, U+20AD-20C0, U+2113, U+2C60-2C7F, U+A720-A7FF` **[verified]**.

| Face | Official files | License | Variable? | Latin woff2 (roman / italic) | Latin-ext |
|---|---|---|---|---|---|
| Literata | github.com/googlefonts/literata release **3.103** (2023-05-19, 17.5 MB zip); repo `fonts/variable/Literata[opsz,wght].ttf`, `Literata-Italic[opsz,wght].ttf`; `fonts/webfonts/Literata[opsz,wght].woff2` (+93 static woff2 incl. 7pt/36pt/72pt) | OFL 1.1 | **Yes**: opsz 7-72, wght 200-900 | 110,080 / 113,180 | 89,668 / 91,424 |
| Charter | practicaltypography.com/charter.html → "Charter 210112.zip" (238 K) "OTFs, TTFs, and webfonts" | Bitstream 1989-1992 notice: "granted permission… to use, copy, modify, sublicense, sell, and redistribute the 4 Bitstream Charter (r) Type 1 outline fonts… provided, that this notice is left intact on all copies… and that Bitstream's trademark is acknowledged" | No (statics: Roman, Italic, Bold, Bold Italic) | not on GF; expect ~25-35 KB/face after latin subset **[inferred from comparable statics]** | - |
| Vollkorn | github.com/FAlthausen/Vollkorn-Typeface (no GitHub releases) `fonts/variable/Vollkorn[wght].ttf`, `Vollkorn-Italic[wght].ttf`, `VollkornSC[wght].ttf` | OFL 1.1 | **Yes**: wght 400-900 | 46,356 / 47,528 | 37,620 / 41,256 |
| Gentium Book Plus | github.com/silnrsi/font-gentium release **v7.000** (2025-06-02) `GentiumBook-7.000.zip` 12.4 MB (TTF + WOFF + WOFF2, no regional subsets); GF `ofl/gentiumbookplus` = 6.101 statics | OFL 1.1 (RFN "Gentium", "SIL") | **No** (statics; v7 adds 500/600) | 21,564 / 24,588 (400); 21,536 / 24,632 (700) | 57,824 / 65,080 (huge: Gentium's Latin coverage) |
| Source Serif 4 | github.com/adobe-fonts/source-serif release **4.005R** (2023-01-20): `_Desktop.zip`, `_WOFF.zip`, `_WOFF2.zip`; GF `SourceSerif4[opsz,wght].ttf` | OFL 1.1 (RFN "Source") | **Yes**: opsz 8-60, wght 200-900 | 122,360 / 130,188 | 100,872 / 110,324 |
| Arvo | google/fonts `ofl/arvo` (upstream antonxheight/Arvo): Regular/Italic/Bold/BoldItalic TTF | OFL 1.1 | No; **latin only, no latin-ext** | 17,268 / 16,940 (400); 17,348 / 17,520 (700) | none |
| Inter | github.com/rsms/inter release **v4.1** (2024-11-16, 33.7 MB zip, includes `web/` woff2 + `inter.css`); GF `Inter[opsz,wght].ttf` v20 | OFL 1.1 | **Yes**: opsz 14-32, wght 100-900 | 72,920 / 79,716 | 133,336 / 146,460 |
| Manrope | github.com/googlefonts/manrope (fork of davelab6/manrope; sharanda/manrope is gone, 404) `fonts/{otf,ttf,variable,webfonts}`; GF `Manrope[wght].ttf` v4.504 | OFL 1.1 | **Yes**: wght 200-800, **no italic** | 24,836 | 15,120 |
| Source Sans 3 | github.com/adobe-fonts/source-sans release **3.052R** (2023-04-04): `VF-source-sans-3.052R.zip` 796 KB, WOFF2 zip 3.9 MB | OFL 1.1 | **Yes**: wght 200-900 | 28,740 / 28,532 | 60,088 / 59,496 |
| JetBrains Mono | github.com/JetBrains/JetBrainsMono release **v2.304** (2023-01-14, 5.6 MB; `fonts/variable`, `fonts/webfonts` woff2; NL variant without ligatures) | OFL 1.1 (build scripts Apache 2.0) | **Yes**: wght 100-800 | 40,404 / 42,964 | 15,196 / 16,520 |
| Source Code Pro | github.com/adobe-fonts/source-code-pro release **2.042R-u/1.062R-i/1.026R-vf** (2023-04-12): `VF-source-code-VF-1.026R.zip` 409 KB, WOFF2 zip | OFL 1.1 | **Yes**: wght 200-900 | 22,044 / 22,448 | 33,568 / 34,012 |

Totals: all 11 roman latin faces ≈ 0.55 MB; roman+italic latin ≈ 1.05 MB; adding latin-ext roughly doubles. Only the default face (Literata roman, 110 KB) is on the critical path; everything else loads on demand via `unicode-range` and the font picker.

Charter and Apple: Apple's system-font list shows **Charter (incl. Black), Georgia, Menlo, Palatino, Times New Roman, Courier New, Helvetica Neue, Avenir, Baskerville, Hoefler Text as iOS *and* macOS system fonts** **[verified]**. So declare `@font-face { font-family: "Charter"; src: local("Charter"), local("Charter-Roman"), url(/fonts/charter-roman.woff2) format("woff2"); }` - Apple devices never download it.

### C2. Subsetting workflow
```
pip install fonttools[woff] brotli zopfli
# variable font, latin + latin-ext, woff2:
pyftsubset "Literata[opsz,wght].ttf" \
  --unicodes="U+0000-00FF,U+0131,U+0152-0153,U+02BB-02BC,U+02C6,U+02DA,U+02DC,U+0304,U+0308,U+0329,U+2000-206F,U+20AC,U+2122,U+2191,U+2193,U+2212,U+2215,U+FEFF,U+FFFD" \
  --layout-features+=onum,pnum,tnum,smcp,c2sc,ss01 \
  --flavor=woff2 --no-hinting --desubroutinize --notdef-outline \
  --name-IDs+=7,8,9,10,11,12,13,14 --output-file=literata-latin.woff2
# second run with the latin-ext ranges → literata-latin-ext.woff2
```
pyftsubset semantics **[verified]**: `--unicodes` "comma/whitespace-separated list of Unicode codepoints or ranges as hex numbers, optionally prefixed with 'U+'"; `--layout-features` default set `calt, ccmp, clig, curs, dnom, frac, kern, liga, locl, mark, mkmk, numr, rclt, rlig, rvrn` with `=`/`+=`/`-=` and `'*'` for all; `--flavor` woff|woff2; `--no-hinting` drops glyph and font-wide hinting (Apple ignores hinting; matters little on Windows ClearType for text sizes - keep hinting for JetBrains Mono if Windows rendering looks off); `--desubroutinize` for CFF (Source fonts' OTFs); `--name-IDs` default keeps 0-6 only; `--with-zopfli` is WOFF1-only. Variable axes survive subsetting; to shrink further use `fonttools varLib.instancer Literata[opsz,wght].ttf wght=300:800 opsz=drop` (`axis=min:max` restricts, `axis=drop` pins to default; "a 'partial' instance… is produced when some of the axes are omitted, or restricted") **[verified]**. glyphhanger (`npm i -g glyphhanger`, needs `pyftsubset`) can derive a whitelist from rendered pages (`--LATIN`, `--US_ASCII`, `--whitelist=`, `--subset="*.ttf" --formats=woff2 --css`) **[verified]** but for a reader that displays arbitrary feed text, range-based subsets (latin + latin-ext as separate `@font-face` blocks with `unicode-range`) beat page-derived whitelists.

### C3. Apple system faces in CSS
- `ui-serif` → New York, `system-ui`/`-apple-system`/`ui-sans-serif` → SF Pro, `ui-monospace` → SF Mono, `ui-rounded` → SF Rounded; Safari 13.1 (macOS) / iOS 13.4; WebKit source `FontCacheCoreText.cpp` maps `"ui-serif"` → `SystemFontKind::UISerif` and treats `-webkit-system-font`, `-apple-system`, `-apple-system-font`, `system-ui`, `ui-sans-serif` identically **[verified]**. **Chrome and Firefox ignore all four `ui-*` keywords on every OS, including macOS** (caniuse extended-system-fonts **[verified]**) - so "New York on Apple" really means "New York in Safari/WebKit on Apple". Chrome on a Mac will fall through to Literata.
- `font-family: "New York"` / `"SF Pro"` by name do **not** work: WebKit's `isDotPrefixedForbiddenFont` returns null with the comment "If you want to use these fonts, use system-ui, ui-serif, ui-monospace, or ui-rounded." **[verified]**. `-apple-system-ui-serif` seen in blog posts is not in current `CSSValueKeywords.in`; rely on `ui-serif`.
- Default body stack without JS: `font-family: ui-serif, Literata, Georgia, serif;` - on Apple WebKit New York wins and the Literata `@font-face` (with `unicode-range`) is never fetched because no glyph falls through **[inferred from CSS font-matching rules]**; elsewhere `ui-serif` is skipped and Literata loads. Same for `ui-monospace, "JetBrains Mono", Menlo, Consolas, monospace`.
- Detecting Apple WebKit for the settings UI (to label the option "New York (system)"): `CSS.supports('font', '-apple-system-body')` - `-apple-system-body` and friends are compiled `enable-if=WTF_PLATFORM_COCOA` in `CSSValueKeywords.in` **[verified]**; add `-webkit-touch-callout: none` support to distinguish iOS from macOS. `navigator.userAgentData` is absent in Safari; UA sniffing for `Macintosh|iPhone|iPad` plus `navigator.maxTouchPoints > 1` (iPadOS desktop UA) is the JS fallback.
- Georgia/Menlo detection: `document.fonts.check()` is unusable (MDN **[verified]**: "System fonts return true… Nonexistent fonts return true"). Use canvas `measureText` of a pangram at 72 px with `"Georgia", monospace` vs `monospace` (and a second fallback like `serif`) and compare widths; Georgia exists on iOS/macOS/Windows, Menlo only on Apple - on Windows fall to Consolas → JetBrains Mono.

### C4. Keeping first load small
- Preload only the default body face on non-Apple: `<link rel="preload" href="/fonts/literata-latin.woff2" as="font" type="font/woff2" crossorigin>` - `crossorigin` is mandatory even same-origin ("font files must be sent over a CORS connection"); web.dev warns `preload` "ignores `unicode-range` declarations", so preload only the latin file and only one weight axis file; inject the preload conditionally (skip when `CSS.supports('font','-apple-system-body')`) **[verified + inferred]**.
- `font-display: swap` for body text (least render delay); consider `optional` for UI sans. Provide a metric-matched fallback with `size-adjust`/`ascent-override` for Literata→Georgia to kill CLS.
- Split every face into latin / latin-ext `@font-face` blocks with `unicode-range`; the browser downloads a block only "if the page contains one or more characters matching the unicode range" **[verified]**. Italic files load only when an `<em>` appears.
- Serve fonts from the Go binary with `Cache-Control: public, max-age=31536000, immutable` and hashed filenames; precache them in the SW (they are the largest assets after images).

---

## Open questions / device tests before Phase 3
See `open_questions`.

## Claims
- [high] Safari 27.0 shipped in September 2026 with a Service Worker static routing API, CSS scroll anchoring (overflow-anchor) and cookieStore.set() maxAge; it did not change viewport-fit, safe-area insets, theme-color or Web Share. (https://webkit.org/blog/18325/webkit-features-for-safari-27-0/)
- [high] On iOS 26 and iPadOS 26 every website added to the Home Screen opens as a web app by default; the user can toggle 'Open as Web App' off; no manifest is required, but a manifest's icons are still used. (https://webkit.org/blog/17333/webkit-features-in-safari-26-0/)
- [high] From Safari 26 the <meta name="theme-color"> is only used for installed web apps (MDN BCD note); in browser tabs Safari 26 derives toolbar tint from page/fixed-element backgrounds. (https://raw.githubusercontent.com/mdn/browser-compat-data/main/html/elements/meta.json)
- [high LB] Home Screen web apps on iOS have storage isolated from Safari by design (cookies, localStorage, IndexedDB, service workers are not shared). (https://bugs.webkit.org/show_bug.cgi?id=181849)
- [high LB] Safari copies website cookies into a web app only when adding to the Dock on macOS; no WebKit/Apple source states cookies are copied for iOS Home Screen web apps, and local storage is never copied. (https://developer.apple.com/videos/play/wwdc2023/10120/)
- [high] Home Screen web apps are exempt from Safari's 7-day script-writable-storage cap because they keep their own counter of days of use. (https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/)
- [high] Since Safari 17 the per-origin storage quota is up to 60% of disk (overall 80%) for browser apps, standalone Home Screen web apps get the same quota, eviction is LRU under pressure/inactivity, and navigator.storage.persist() is granted heuristically e.g. for Home Screen web apps. (https://webkit.org/blog/14403/updates-to-storage-policy/)
- [high] WebKit bug 272325 reports session cookies being randomly reset in Home Screen web apps on iOS 17.2-17.4.1 (reports through 18.1), unresolved as of Nov 2024. (https://bugs.webkit.org/show_bug.cgi?id=272325)
- [medium] iOS 17 did not apply prefers-color-scheme changes in Home Screen web apps until relaunch; fixed in iOS 18. (https://developer.apple.com/forums/thread/739154)
- [high LB] viewport-fit=cover disables Safari's automatic safe-area insetting; env(safe-area-inset-top/right/bottom/left) are available (env since iOS 11.2, constant() in 11.0-11.1); default insetting fills the inset area with the body/html background-color. (https://webkit.org/blog/7929/designing-websites-for-iphone-x/)
- [high LB] apple-mobile-web-app-status-bar-style accepts default, black, black-translucent; black-translucent lets the page use the entire screen under the status bar; the tag has no effect outside standalone mode. (https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html)
- [medium] iOS uses a screenshot of the last launch as the default launch image; custom splash requires apple-touch-startup-image per device; manifest background_color is not used for iOS splash. (https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html)
- [high] Manifest icons are honored by Safari 15.4+ only when no apple-touch-icon is present; the manifest is fetched at page load since 15.4. (https://webkit.org/blog/12445/new-webkit-features-in-safari-15-4/)
- [high] dvh/svh/lvh viewport units are supported since Safari 15.4 (iOS 15.4). (https://webkit.org/blog/12445/new-webkit-features-in-safari-15-4/)
- [high LB] overscroll-behavior is supported in Safari 16+ but marked partial: it has no effect on scroll containers that have no scrollable overflow. (https://raw.githubusercontent.com/mdn/browser-compat-data/main/css/properties/overscroll-behavior.json)
- [high] interactive-widget viewport keyword is not shipped in Safari 26/27.0 (WebKit implemented it in source, flagged in STP 252; possibly Safari 27.1); env(keyboard-inset-*) is unsupported in Safari; Safari resizes only the visual viewport when the keyboard opens. (https://www.bram.us/2026/09/11/webkit-supports-interactive-widget-and-hopefully-safari-will-too/)
- [high] navigator.share is available from iOS 12.2 (Safari 12.1); text, files and canShare from Safari 14; it requires a secure context and transient user activation and rejects with NotAllowedError/AbortError/TypeError/InvalidStateError. (https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/Navigator.json)
- [high] WebKit's transient activation window is 5 seconds (defaultTransientActivationDuration { 5_s } in LocalDOMWindow.cpp). (https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/page/LocalDOMWindow.cpp)
- [high] In Safari, navigator.clipboard.writeText/write called outside a user gesture is rejected immediately; only https; supported types text/plain, text/html, text/uri-list, image/png; ClipboardItem accepts Promises per MIME type. (https://webkit.org/blog/10855/async-clipboard-api/)
- [medium LB] The iOS system edge-swipe back/forward gesture exists in Home Screen web apps and cannot be disabled from web content (touch-action/overscroll-behavior do not affect it). (https://github.com/w3c/pointerevents/issues/358)
- [high] Web Push on iOS/iPadOS exists only for Home Screen web apps since 16.4 and requires a user gesture to subscribe. (https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/)
- [high] Workbox precaching serves precached assets cache-first, requires an explicit revision for index.html (revision:null for hashed URLs), and createHandlerBoundToURL + NavigationRoute (with denylist) is the SPA navigation pattern; vite-plugin-pwa exposes navigateFallbackDenylist. (https://developer.chrome.com/docs/workbox/modules/workbox-precaching)
- [high] shadcn/ui defaults to Base UI instead of Radix since July 2026; `npx shadcn init -b radix` keeps Radix; Radix remains supported. (https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default)
- [high] shadcn's Tailwind v4/React 19 update uses @theme inline with unwrapped CSS variables, OKLCH colors, data-slot attributes, no forwardRef, new-york as default style, and tw-animate-css instead of tailwindcss-animate. (https://ui.shadcn.com/docs/tailwind-v4)
- [high] Tailwind CSS v4 requires Chrome 111, Safari 16.4, Firefox 128; installed via @tailwindcss/vite plugin and `@import "tailwindcss"`. (https://tailwindcss.com/docs/compatibility)
- [high] Vite 8 (2026-03-12) uses Rolldown/Oxc, requires Node 20.19+/22.12+, renames build.rollupOptions to build.rolldownOptions, and raises the default build.target to Safari 16.4. (https://vite.dev/guide/migration)
- [high] TanStack Query v5 defaults: data stale immediately, inactive queries GC'd after 5 minutes, failed queries retried 3 times with exponential backoff, structural sharing on. (https://tanstack.com/query/latest/docs/framework/react/guides/important-defaults)
- [high] TanStack Virtual v3 options include count, getScrollElement, estimateSize, overscan (default 1), measureElement, getItemKey, paddingStart/End, scrollPaddingStart/End, scrollMargin, gap, lanes, horizontal, initialOffset, isScrollingResetDelay, useScrollendEvent, useAnimationFrameWithResizeObserver, shouldAdjustScrollPositionOnItemSizeChange; dynamic heights use ref={virtualizer.measureElement} with data-index. (https://raw.githubusercontent.com/TanStack/virtual/main/packages/virtual-core/src/index.ts)
- [high] @use-gesture/react's last release is 10.3.1 on 2024-03-21; useDrag supports axis 'x'|'y'|'lock', filterTaps, threshold, preventScroll, bounds, rubberband, swipe thresholds (distance 50, velocity 0.5, duration 250) and needs touch-action set on the element. (https://use-gesture.netlify.app/docs/options/)
- [high] Motion for React (motion/react) drag API: drag="x", dragConstraints, dragElastic, dragMomentum, dragTransition, dragSnapToOrigin, dragDirectionLock (10px lock threshold in source), useDragControls, onDragEnd(event, info{point,delta,offset,velocity}). (https://motion.dev/docs/react-drag)
- [high] tinykeys 4.0.0 (~650 B, ESM, node>=22) supports sequences like "g i", $mod, matches key and code, and ignores contenteditable/input/textarea/select by default; react-hotkeys-hook 5.3.3 supports sequences via 'g>h>i'. (https://github.com/jamiebuilds/tinykeys)
- [high] Feedly's live CSS uses a 3-column cards grid with 24px gutters (.entry.cards:nth-child(3n){margin-right:0}), 420px large cards with 272px-tall visuals (~3:2), 130x78 (5:3) mini-magazine thumbnails, a 624px-max magazine column, 13px/16px metadata with source ellipsized at 100px, titles clamped at 5 lines and summaries at 3. (https://s1.feedly.com/web/main/main.b6eb787752b900efe407.css)
- [high] Literata 3.103 (googlefonts/literata, OFL) is a variable font with opsz 7-72 and wght 200-900; Google Fonts serves its latin variable woff2 at 110,080 B roman / 113,180 B italic and latin-ext at 89,668 / 91,424 B. (https://fonts.googleapis.com/css2?family=Literata:ital,opsz,wght@0,7..72,200..900;1,7..72,200..900&display=swap)
- [high] Charter is distributed by Matthew Butterick as 'Charter 210112.zip' (238K, OTF/TTF/webfonts) under the 1989-1992 Bitstream notice permitting use, modification and redistribution provided the notice stays intact; it has no variable version and is preinstalled on iOS and macOS. (https://practicaltypography.com/charter.html)
- [high] Vollkorn (OFL) ships variable Vollkorn[wght].ttf, Vollkorn-Italic[wght].ttf and VollkornSC[wght].ttf (wght 400-900) in FAlthausen/Vollkorn-Typeface fonts/variable; there are no GitHub releases. (https://github.com/FAlthausen/Vollkorn-Typeface/tree/master/fonts/variable)
- [high] Gentium 7.000 (2025-06-02) renamed Gentium Book Plus to Gentium Book, added 500/600 weights, reduced default line spacing, ships static TTF/WOFF/WOFF2 only (no variable fonts, no regional subsets); Google Fonts still serves 'Gentium Book Plus' 6.101 statics. (https://raw.githubusercontent.com/silnrsi/font-gentium/master/FONTLOG.txt)
- [high] Source Serif 4.005R, Source Sans 3.052R and Source Code Pro 2.042R/1.062R/1.026R-vf (adobe-fonts, OFL with RFN 'Source') provide variable TTFs; Google Fonts serves SourceSerif4[opsz,wght] (opsz 8-60, wght 200-900), SourceSans3[wght] and SourceCodePro[wght] (200-900). (https://raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/METADATA.pb)
- [high] Arvo is static-only (Regular/Italic/Bold/BoldItalic) and Google Fonts serves it for latin only (no latin-ext subset), ~17 KB per face. (https://raw.githubusercontent.com/google/fonts/main/ofl/arvo/METADATA.pb)
- [high] Inter 4.1 (rsms/inter, 2024-11-16, OFL) and JetBrains Mono 2.304 (2023-01-14, OFL) ship variable fonts with woff2 web builds; Manrope (OFL) exists as a variable Manrope[wght].ttf (200-800, no italic) in googlefonts/manrope, the original sharanda/manrope repo is gone. (https://api.github.com/repos/rsms/inter/releases/latest)
- [high] pyftsubset: --unicodes takes hex codepoints/ranges (U+ optional), --layout-features defaults to calt,ccmp,clig,curs,dnom,frac,kern,liga,locl,mark,mkmk,numr,rclt,rlig,rvrn with =, +=, -= and '*', --flavor=woff2, --no-hinting, --desubroutinize, --name-IDs default 0-6; fonttools varLib.instancer restricts axes with axis=min:max or drops with axis=drop keeping a partial variable font. (https://fonttools.readthedocs.io/en/latest/subset/index.html)
- [high LB] WebKit maps ui-serif to New York, ui-monospace to SF Mono, ui-rounded to SF Rounded, and system-ui/-apple-system/ui-sans-serif to SF Pro, and refuses dot-prefixed system fonts by name with the comment 'If you want to use these fonts, use system-ui, ui-serif, ui-monospace, or ui-rounded'; Chrome and Firefox ignore the ui-* keywords on all platforms. (https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/platform/graphics/cocoa/FontCacheCoreText.cpp)
- [high] The -apple-system-body/-apple-system-headline font keywords are compiled only on Cocoa platforms (enable-if=WTF_PLATFORM_COCOA), so CSS.supports('font','-apple-system-body') identifies Apple WebKit. (https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/css/CSSValueKeywords.in)
- [high] Charter, Georgia and Menlo are listed by Apple as preinstalled system fonts on both iOS and macOS; New York and SF are not listed there (accessible only via ui-serif/system-ui). (https://developer.apple.com/fonts/system-fonts/)
- [high] document.fonts.check() cannot detect installed system fonts (returns true for system and nonexistent fonts); canvas measureText width comparison is the usable detection technique. (https://developer.mozilla.org/en-US/docs/Web/API/FontFaceSet/check)
- [high] Font preload requires the crossorigin attribute even for same-origin fonts and ignores unicode-range; a unicode-range @font-face block downloads only if matching characters appear. (https://web.dev/articles/font-best-practices)

## Open questions
- Standalone status bar on iOS 18/26/27: does <meta name="theme-color" media="(prefers-color-scheme: …)"> (or manifest theme_color) color the status-bar strip and/or its glyphs in an installed web app, and does `default` still force a white strip? BCD says theme-color is 'only used for installed web apps' from Safari 26 but nothing documents the exact effect. Needs a device test with all seven Kipple themes; decides whether black-translucent + self-painted safe-area strip is required.
- Did iOS 27 change anything about Home Screen web app chrome (status bar, iPad window controls, safe-area env values)? Safari 27.0 release notes are silent; test on an iOS 27 device, and re-check iPadOS 27 windowed mode safe-area behavior.
- Whether Safari 27.1 ships `interactive-widget` (WebKit implemented it Aug 2026 behind a flag). Until then keyboard avoidance must use VisualViewport.
- Cloudflare Access email-OTP inside the standalone web view: confirm the CF_Authorization cookie is set in the web app's isolated jar on first launch and that the Access session duration configured for rss.example.com keeps the standalone app signed in for weeks; also confirm the Reader API bypass path does not interfere with the SPA's own fetches.
- Exact card image ratio Feedly uses in the regular 3-column cards view (only the 420x272 large card and 130x78 mini thumbnail were measurable from CSS; the standard card's visual height may be set inline/JS). Decide 3:2 vs 16:9 for Kipple by visual test rather than by Feedly parity.
- Gentium: ship Google Fonts' 'Gentium Book Plus' 6.101 statics (name matches the CLAUDE.md decision, older metrics) or SIL's 'Gentium Book' 7.000 (new name, tighter line spacing, extra weights)? Affects the family name exposed in the font picker.
- Arvo has no latin-ext subset on Google Fonts; confirm the upstream TTF covers latin-ext (Ł, Ő, etc.) or accept fallback glyphs for those characters when Arvo is selected.
- Whether Motion or @use-gesture is worth adding at all versus ~150 lines of Pointer Events for row swipes; @use-gesture has had no release since March 2024.
- Whether `overscroll-behavior: none` on the inner scroller fully suppresses rubber-banding in standalone mode on iOS 18/26/27 or whether an iNoBounce-style touchmove guard is still needed at the scroll extremes.

## Sources
- https://webkit.org/blog/18325/webkit-features-for-safari-27-0/
- https://webkit.org/blog/17333/webkit-features-in-safari-26-0/
- https://webkit.org/blog/16993/news-from-wwdc25-web-technology-coming-this-fall-in-safari-26-beta/
- https://webkit.org/blog/17640/webkit-features-for-safari-26-2/
- https://webkit.org/blog/17862/webkit-features-for-safari-26-4/
- https://webkit.org/blog/15865/webkit-features-in-safari-18-0/
- https://webkit.org/blog/14445/webkit-features-in-safari-17-0/
- https://webkit.org/blog/14205/news-from-wwdc23-webkit-features-in-safari-17-beta/
- https://developer.apple.com/videos/play/wwdc2023/10120/
- https://webkit.org/blog/14403/updates-to-storage-policy/
- https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
- https://webkit.org/blog/12445/new-webkit-features-in-safari-15-4/
- https://webkit.org/blog/13152/webkit-features-in-safari-16-0/
- https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/
- https://webkit.org/blog/7929/designing-websites-for-iphone-x/
- https://webkit.org/blog/10855/async-clipboard-api/
- https://webkit.org/blog/3709/using-the-system-font-in-web-content/
- https://bugs.webkit.org/show_bug.cgi?id=181849
- https://bugs.webkit.org/show_bug.cgi?id=272325
- https://developer.apple.com/library/archive/documentation/AppleApplications/Reference/SafariWebContent/ConfiguringWebApplications/ConfiguringWebApplications.html
- https://developer.apple.com/fonts/system-fonts/
- https://developer.apple.com/forums/thread/739154
- https://developer.apple.com/forums/thread/740065
- https://developer.apple.com/forums/thread/710157
- https://developer.apple.com/forums/thread/761615
- https://raw.githubusercontent.com/mdn/browser-compat-data/main/html/elements/meta.json
- https://raw.githubusercontent.com/mdn/browser-compat-data/main/css/types/env.json
- https://raw.githubusercontent.com/mdn/browser-compat-data/main/css/properties/overscroll-behavior.json
- https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/Navigator.json
- https://raw.githubusercontent.com/mdn/browser-compat-data/main/api/VisualViewport.json
- https://raw.githubusercontent.com/Fyrd/caniuse/main/features-json/web-share.json
- https://raw.githubusercontent.com/Fyrd/caniuse/main/features-json/css-overscroll-behavior.json
- https://raw.githubusercontent.com/Fyrd/caniuse/main/features-json/viewport-unit-variants.json
- https://raw.githubusercontent.com/Fyrd/caniuse/main/features-json/extended-system-fonts.json
- https://developer.mozilla.org/en-US/docs/Web/API/Navigator/share
- https://developer.mozilla.org/en-US/docs/Web/HTML/Reference/Elements/meta/name/viewport
- https://developer.mozilla.org/en-US/docs/Web/API/FontFaceSet/check
- https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/page/LocalDOMWindow.cpp
- https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/platform/graphics/cocoa/FontCacheCoreText.cpp
- https://raw.githubusercontent.com/WebKit/WebKit/main/Source/WebCore/css/CSSValueKeywords.in
- https://www.bram.us/2026/09/11/webkit-supports-interactive-widget-and-hopefully-safari-will-too/
- https://www.htmhell.dev/adventcalendar/2024/4/
- https://1ar.io/updates/safari-26-liquid-glass-web/
- https://jahir.dev/blog/safari-toolbar
- https://benfrain.com/ios26-safari-theme-color-tab-tinting-with-fixed-position-elements/
- https://nasedk.in/blog/ios26-safari-toolbar-colors/
- https://dev.to/reinhart1010/pwa-in-ipados-26-is-a-joke-38g1
- https://mjtsai.com/blog/2025/10/03/web-apps-in-ios-26/
- https://github.com/w3c/pointerevents/issues/358
- https://github.com/ionic-team/ionic-framework/issues/22299
- https://firt.dev/notes/pwa-ios/
- https://firt.dev/pwa-design-tips/
- https://openpwa.net/reference/installation/ios-add-to-home-screen/
- https://intercom.help/progressier/en/articles/10574799-complete-guide-to-customizing-the-mobile-status-bar-in-a-website-or-pwa
- https://css-tricks.com/meta-theme-color-and-trickery/
- https://www.netguru.com/blog/how-to-share-session-cookie-or-state-between-pwa-in-standalone-mode-and-safari-on-ios
- https://developer.chrome.com/blog/overscroll-behavior
- https://developer.chrome.com/docs/workbox/modules/workbox-strategies
- https://developer.chrome.com/docs/workbox/modules/workbox-precaching
- https://vite-pwa-org.netlify.app/guide/
- https://vite-pwa-org.netlify.app/workbox/generate-sw.html
- https://ui.shadcn.com/docs/tailwind-v4
- https://ui.shadcn.com/docs/changelog
- https://ui.shadcn.com/docs/changelog/2026-07-base-ui-default
- https://tailwindcss.com/docs/compatibility
- https://tailwindcss.com/docs/installation/using-vite
- https://vite.dev/blog/announcing-vite8
- https://vite.dev/guide/migration
- https://tanstack.com/query/latest/docs/framework/react/guides/important-defaults
- https://tanstack.com/virtual/latest/docs/api/virtualizer
- https://raw.githubusercontent.com/TanStack/virtual/main/packages/virtual-core/src/index.ts
- https://raw.githubusercontent.com/TanStack/virtual/main/packages/react-virtual/src/index.tsx
- https://use-gesture.netlify.app/docs/options/
- https://github.com/pmndrs/use-gesture/releases
- https://motion.dev/docs/react-drag
- https://raw.githubusercontent.com/motiondivision/motion/main/packages/framer-motion/src/gestures/drag/VisualElementDragControls.ts
- https://github.com/jamiebuilds/tinykeys
- https://react-hotkeys-hook.vercel.app/docs/documentation/useHotkeys/basic-usage
- https://registry.npmjs.org/
- https://docs.feedly.com/article/276-how-do-i-change-the-views-of-my-feeds-and-source
- https://medium.com/feedly-behind-the-curtain/an-exploration-in-material-design-by-feedly-8c1a1cbdfdcd
- https://devhd.wordpress.com/2013/11/14/the-new-title-only-and-card-views/
- https://s1.feedly.com/web/main/main.b6eb787752b900efe407.css
- https://practicaltypography.com/charter.html
- https://fonttools.readthedocs.io/en/latest/subset/index.html
- https://fonttools.readthedocs.io/en/latest/varLib/instancer.html
- https://github.com/zachleat/glyphhanger
- https://web.dev/articles/font-best-practices
- https://fonts.googleapis.com/css2?family=Literata:ital,opsz,wght@0,7..72,200..900;1,7..72,200..900&display=swap
- https://raw.githubusercontent.com/google/fonts/main/ofl/literata/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/vollkorn/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/gentiumbookplus/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/sourceserif4/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/arvo/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/inter/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/manrope/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/sourcesans3/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/jetbrainsmono/METADATA.pb
- https://raw.githubusercontent.com/google/fonts/main/ofl/sourcecodepro/METADATA.pb
- https://github.com/googlefonts/literata
- https://github.com/googlefonts/literata/tree/main/fonts/webfonts
- https://github.com/FAlthausen/Vollkorn-Typeface/tree/master/fonts/variable
- https://github.com/silnrsi/font-gentium/releases
- https://raw.githubusercontent.com/silnrsi/font-gentium/master/FONTLOG.txt
- https://software.sil.org/gentium/download/
- https://github.com/adobe-fonts/source-serif/releases
- https://github.com/adobe-fonts/source-sans/releases
- https://github.com/adobe-fonts/source-code-pro/releases
- https://github.com/rsms/inter/releases
- https://github.com/googlefonts/manrope
- https://github.com/JetBrains/JetBrainsMono/releases
- https://blog.jim-nielsen.com/2020/system-fonts-on-the-web/
- https://matthew-jackson.com/blog/using-apples-new-york-font-in-css/
