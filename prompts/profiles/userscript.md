Stack: Userscript (Tampermonkey / Violentmonkey / Greasemonkey).

Prioritize:
- `@version` header matches project version string everywhere (README, CHANGELOG, repo tags)
- `@updateURL` + `@downloadURL` pointing at GitHub raw URLs for auto-update
- `@run-at` choice: `document-start` for anti-FOUC CSS; `document-end` for DOM-ready logic
- `@inject-into content` for Tampermonkey MV3 compatibility (avoids sandbox quirks)
- No minification — users should be able to read what they're running
- DOM targeting: structure/attributes, not obfuscated class names that change weekly
- Shadow DOM for injected UI on sites with aggressive style resets
- `trustedTypes.createPolicy()` for innerHTML/insertAdjacentHTML on YouTube/Google/strict-CSP sites
- IndexedDB for cross-tab shared state; `GM_setValue`/`GM_getValue` for settings
- `@grant` list minimized — each added grant reduces user trust
- Settings overlay: `pointer-events: none` when inactive to avoid intercepting clicks
- Scoped CSS via body classes + CSS custom properties (no leaking into host page)
- Hostname matches precise (`@match` not `@include` where possible)
- `unsafeWindow` required for page-context access in sandboxed runtimes

Common bug class: absorbing external CSS snippets without namespacing breaks the host site.
