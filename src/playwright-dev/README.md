# Playwright Development Environment (playwright-dev)

OS-level dependencies for headless Chromium, Firefox, and WebKit, a browser-binary cache shared across rebuilds via a Docker named volume, and the official Playwright Test VS Code extension — pre-configured so `npx playwright test` and `npx playwright install` just work, without re-downloading browsers on every rebuild.

## Why this feature exists

Headless browser automation (Playwright, and anything built on Chromium's DevTools Protocol — including `WebAuthn.addVirtualAuthenticator`, useful for testing passkey/WebAuthn flows without physical hardware) needs a real browser binary plus a long list of OS shared libraries. `npx playwright install --with-deps` can fetch both, but:

- it needs `sudo`/root at test-run time to apt-install system packages,
- it re-downloads the browser binaries into `~/.cache/ms-playwright` on every fresh container, since that path isn't normally persisted.

This feature moves both steps into the devcontainer lifecycle: OS packages are installed once at image build time (via the official `playwright install-deps`, not a hand-maintained apt list that would drift across base-image OS versions), and the browser binaries are downloaded once into a named volume that survives rebuilds — the same shape as the `pnpm-store` feature.

It deliberately does **not** install the `playwright` npm package itself — that stays a devDependency of the consuming project, so the CLI version always matches the project's own Playwright version instead of drifting from a separately-installed global one.

### Alternative: Microsoft's prebuilt Playwright image

Microsoft publishes `mcr.microsoft.com/playwright:v<version>-<os>`, a Docker image with browsers and OS deps already baked in — zero install time, nothing to cache. If you don't need to compose with other `helpers4` features on top of your own base image, using that image directly as `"image"` is simpler than this feature. The tradeoff is that it pins your whole devcontainer to Microsoft's base image and Playwright version, instead of adding browser support to whatever base image and feature set (`typescript-dev`, `vite-plus`, `pnpm-store`, …) you're already using.

## Usage

Add this feature to your `devcontainer.json`:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/playwright-dev:1": {}
    }
}
```

This will:
1. Install the OS packages required to run Chromium, Firefox, and WebKit headless
2. Set `PLAYWRIGHT_BROWSERS_PATH` to a Docker-volume-backed path shared across rebuilds
3. Download the browser binaries into that volume on first container start
4. Install the official Playwright Test VS Code extension, pre-configured

### Chromium only

If your project only needs Chromium (e.g. CDP-based WebAuthn testing), skip the Firefox/WebKit dependencies to keep the image smaller:

```json
{
    "features": {
        "ghcr.io/helpers4/devcontainer/playwright-dev:1": {
            "browsers": "chromium"
        }
    }
}
```

## Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `browsers` | string (`chromium` \| `firefox` \| `webkit` \| `all`) | `all` | Which browser engine(s) to install OS-level dependencies for, and to pre-download into the shared cache. |
| `installDeps` | boolean | `true` | Install the OS packages required to run the selected browser(s) headless, via `playwright install-deps`. Disable if the base image already provides them. |

## IDE support

| Editor | Status | ID |
| ------ | ------ | -- |
| VS Code | ✅ | `ms-playwright.playwright` |
| Cursor | ✅ | `ms-playwright.playwright` (same registry as VS Code) |
| WebStorm / IntelliJ IDEA (2023.3+) | ℹ️ | Playwright tests are recognized natively via the built-in Test Automation plugin — not something this feature installs, nothing to configure here. |
| Zed | 🔜 | no standard devcontainer customization format yet |

## Browser cache volume

Binaries live in a Docker named volume (`helpers4-playwright-browsers-${devcontainerId}`) mounted at `/usr/local/share/playwright-browsers`, exposed to every shell via `PLAYWRIGHT_BROWSERS_PATH`. A `postCreateCommand` guard script takes ownership of the volume at container creation and downloads the browsers only if they haven't been fetched yet for the current `browsers` selection — so a rebuild reuses what's already there instead of re-fetching.

```bash
# Confirm what's cached
ls "$PLAYWRIGHT_BROWSERS_PATH"
```

## VS Code Extension Included

### Playwright Test for VS Code (ms-playwright.playwright)
- Test explorer: run/debug Playwright tests from the sidebar
- Pick locators, record new tests (codegen), and view traces inline

Settings applied:

```json
{
  "playwright.reuseBrowser": true,
  "playwright.showTrace": true
}
```

## Testing a WebAuthn/passkey flow without hardware

Chromium's DevTools Protocol exposes `WebAuthn.addVirtualAuthenticator` — no extra software authenticator needed. With Playwright:

```ts
const client = await context.newCDPSession(page);
await client.send("WebAuthn.enable");
await client.send("WebAuthn.addVirtualAuthenticator", {
  options: {
    protocol: "ctap2",
    transport: "internal",
    hasResidentKey: true,
    hasUserVerification: true,
    isUserVerified: true,
  },
});
```

## Works Great With

```json
{
  "features": {
    "ghcr.io/helpers4/devcontainer/playwright-dev:1": {},
    "ghcr.io/helpers4/devcontainer/typescript-dev:1": {},
    "ghcr.io/helpers4/devcontainer/vite-plus:1": {},
    "ghcr.io/helpers4/devcontainer/pnpm-store:1": {}
  }
}
```

## Troubleshooting

### Browsers didn't download on first start

The guard script needs network access at `postCreateCommand` time. Re-run it manually, or install directly:

```bash
npx playwright install
```

### `install-deps` fails on an unsupported base image

`playwright install-deps` only knows the apt package names for the Debian/Ubuntu versions Playwright officially supports. Pin your base image to one of those, or set `installDeps: false` and install the equivalent packages yourself.

## Links

- **Playwright**: https://playwright.dev/
- **VS Code extension**: https://marketplace.visualstudio.com/items?itemName=ms-playwright.playwright
- **CDP WebAuthn domain**: https://chromedevtools.github.io/devtools-protocol/tot/WebAuthn/

## Version History

- **v1.1.0**: Switched from an inline copy of `helpers4-common`'s bootstrap (user detection, apt
  helpers) to a direct `dependsOn` on the `helpers4-common` feature — no behavior change, just a
  single source of truth for that logic instead of a copy every feature had to keep in sync.
- **v1.0.1**: Dropped the `@latest` pin from both `npx playwright` calls — it was forcing the newest registry release instead of the project's own pinned version. Added `ghcr.io/devcontainers/features/node:1` to `dependsOn`: `typescript-dev` alone doesn't install Node, so the `npm not found` guard wasn't actually covered. The browser-cache guard now writes a completion marker instead of trusting a non-empty directory, so an interrupted download doesn't get stuck as a permanently broken cache. Added an "IDE support" table and documented the `mcr.microsoft.com/playwright` prebuilt-image alternative.
- **v1.0.0**: Initial release.

## License

LGPL-3.0 - See LICENSE file for details
