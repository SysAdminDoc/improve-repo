Stack: Chrome Extension (Manifest V3).

Prioritize:
- Service worker lifecycle: MV3 workers can't use `setInterval` — use `chrome.alarms`
- `chrome.storage.local` / `chrome.storage.session` over `localStorage` (workers can't access DOM storage)
- Content scripts: split MAIN-world vs ISOLATED-world for page-API interception
- Anti-FOUC: inject critical CSS at `document_start` in a separate content script entry
- Shadow DOM for UI overlays on hostile pages (style isolation)
- `declarativeNetRequest` over blocking `webRequest` (MV3 no longer allows blocking webRequest in extensions)
- `host_permissions` minimized — audit for excess scope on every release
- `web_accessible_resources` minimized — each exposed resource is fingerprint/attack surface
- CSS class prefix (`<projname>-`) or Shadow DOM to prevent leakage into host pages
- `trustedTypes.createPolicy()` on YouTube/Google/strict-CSP sites for innerHTML
- Firefox parity: MV2 fork or MV3 (which Firefox supports) — document which
- CRX3 packaging for off-store distribution; signed with stable `.pem` to preserve extension ID
- Update mechanism: Chrome Web Store, self-hosted update.xml, or GitHub releases
- Clean-profile verification before release: does it work on a fresh install?

Skip generic "add analytics" — MV3 + privacy expectations make this fraught.
