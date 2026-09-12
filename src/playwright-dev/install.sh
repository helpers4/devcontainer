#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Sets up a Playwright browser-automation environment: OS-level dependencies
# for headless Chromium/Firefox/WebKit (via the official `playwright
# install-deps`, rather than a hand-maintained apt package list that would
# drift across base-image OS versions), plus a postCreateCommand guard that
# downloads the browser binaries themselves into a Docker named volume shared
# across rebuilds — the same store-across-rebuilds shape as the pnpm-store
# feature, because /workspaces (and any other volume mount) isn't available
# yet at image build time, only once the container actually starts.
#
# Deliberately does NOT install the `playwright` npm package itself — that
# stays a devDependency of the consuming project, so the CLI version always
# matches the project's own Playwright version instead of drifting from a
# separately-installed global one.

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

echo "🔧 Setting up playwright-dev devcontainer feature..."

# Get options
BROWSERS="${BROWSERS:-all}"
INSTALL_DEPS="${INSTALLDEPS:-true}"

# Fixed path — kept in sync with "containerEnv" / "mounts" in devcontainer-feature.json.
BROWSERS_PATH="/usr/local/share/playwright-browsers"

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ This script must be run as root."
    exit 1
fi

h4_detect_user
h4_resolve_home
export DEBIAN_FRONTEND=noninteractive

if ! command -v npm >/dev/null 2>&1; then
    echo "❌ npm not found. Please ensure Node.js is installed first (this feature depends on typescript-dev)."
    exit 1
fi

h4_ensure_packages ca-certificates

# "all" installs deps for every browser Playwright supports; a single engine
# name restricts `install-deps` to that one.
browser_arg=""
if [ "${BROWSERS}" != "all" ]; then
    browser_arg="${BROWSERS}"
fi

if [ "${INSTALL_DEPS}" = "true" ]; then
    echo "📦 Installing OS dependencies for Playwright browser(s): ${BROWSERS}..."
    # No @latest pin: npx resolves the project's own devDependency version
    # first if one is already installed, falling back to the newest release
    # only when nothing local exists yet (e.g. here, at image build time,
    # before the workspace is even mounted).
    # shellcheck disable=SC2086
    if npx -y playwright install-deps ${browser_arg}; then
        echo "✅ Playwright OS dependencies installed (${BROWSERS})"
    else
        echo "❌ Failed to install Playwright OS dependencies."
        exit 1
    fi
else
    echo "ℹ️  Skipping OS dependency install (installDeps=false)."
fi

# Pre-create the mountpoint during the image build, same rationale as
# pnpm-store's STORE_DIR: the named volume shadows it once the container
# starts, but a valid, correctly-owned directory must exist beforehand for
# any tool that touches it before the volume is attached.
mkdir -p "${BROWSERS_PATH}" || true
if [ "${USERNAME}" != "root" ]; then
    USER_GROUP="$(id -gn "${USERNAME}" 2>/dev/null || echo "${USERNAME}")"
    chown "${USERNAME}:${USER_GROUP}" "${BROWSERS_PATH}" 2>/dev/null || true
fi
echo "  ✅ Created browser cache directory at ${BROWSERS_PATH}"

# Install the postCreate guard script. It runs once the volume is mounted, so
# it can take ownership of the cache and download the actual browser binaries
# (the image-build step above only installs OS packages, not the browsers
# themselves — those need the volume, which isn't available until container
# start, exactly like pnpm-store's guard).
GUARD="/usr/local/bin/devcontainer-playwright-browsers"

{
    cat <<'HEADER'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
set -euo pipefail
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh
HEADER
    printf 'BROWSERS_PATH=%q\n' "${BROWSERS_PATH}"
    printf 'BROWSER_ARG=%q\n' "${browser_arg}"
} > "${GUARD}"

cat >> "${GUARD}" <<'EOF'

echo "🎭 playwright-dev: ensuring browser cache at ${BROWSERS_PATH}"

if [ ! -d "${BROWSERS_PATH}" ]; then
    mkdir -p "${BROWSERS_PATH}" 2>/dev/null \
        || { command -v sudo >/dev/null 2>&1 && sudo mkdir -p "${BROWSERS_PATH}"; } \
        || { echo "❌ playwright-dev: could not create ${BROWSERS_PATH}"; exit 1; }
fi

# Shared across every local project for this host OS user (${localEnv:USER} — see
# devcontainer-feature.json), so --shared (see h4_ensure_volume_writable's own comment in
# helpers4-common/install.sh for why). Safe unlike claude-dev/mistral-dev's credentials
# volumes: browser binaries are just downloaded artifacts, not an identity/permissions
# surface, so sharing them across a user's own projects has none of the cross-project bleed
# risk that made claude-dev/mistral-dev move away from it.
h4_ensure_volume_writable "${BROWSERS_PATH}" --shared

# Download the actual browser binaries only if not already fetched for this Playwright
# version + browser selection. A completion marker (rather than "directory non-empty") is
# used so an interrupted first download gets retried on the next start instead of being
# silently treated as done forever; the marker is scoped per browser selection so switching
# the `browsers` option after a rebuild re-triggers a download instead of trusting a stale,
# incomplete cache.
#
# The Playwright version is also part of the marker now that this volume is shared across
# every local project (see devcontainer-feature.json): two projects can pin different
# Playwright versions needing different browser revisions. Playwright's own cache already
# namespaces binaries by revision (e.g. chromium-1091/) so this never collides — it only
# guards our own "already installed" shortcut from wrongly skipping a download some other
# project's version never actually fetched.
# If the version can't be resolved (offline, transient npx/registry hiccup), don't fall back
# to a generic marker — on this shared volume, a different project hitting the same failure
# would collide on it and could wrongly skip a browser revision it doesn't actually have.
# Skipping the marker check entirely instead just always re-runs the (idempotent, revision-
# aware) install below for this one start.
PLAYWRIGHT_VERSION="$(npx -y playwright --version 2>/dev/null | awk '{print $NF}')"
MARKER=""
[ -n "${PLAYWRIGHT_VERSION}" ] && MARKER="${BROWSERS_PATH}/.h4-installed-${PLAYWRIGHT_VERSION}-${BROWSER_ARG:-all}"
if [ -z "${MARKER}" ] || [ ! -f "${MARKER}" ]; then
    echo "📥 playwright-dev: downloading browser binaries (${BROWSER_ARG:-all}) into ${BROWSERS_PATH}..."
    # No @latest pin — see install.sh's install-deps step for why.
    # shellcheck disable=SC2086
    if npx -y playwright install ${BROWSER_ARG}; then
        [ -n "${MARKER}" ] && touch "${MARKER}"
        echo "✅ playwright-dev: browsers installed"
    else
        echo "⚠️  playwright-dev: browser download failed — check network access, or run 'npx playwright install' manually"
    fi
else
    echo "✅ playwright-dev: browser cache already populated, skipping download"
fi
EOF

chmod +x "${GUARD}"
echo "  ✅ Installed guard script at ${GUARD}"

echo ""
echo "✅ playwright-dev feature installed successfully!"
echo ""
echo "📝 Browser binaries are cached in a Docker volume, shared across rebuilds:"
echo "   PLAYWRIGHT_BROWSERS_PATH=${BROWSERS_PATH}"
echo ""
echo "🔗 Resources:"
echo "   - Playwright: https://playwright.dev/"
echo "   - VS Code extension: https://marketplace.visualstudio.com/items?itemName=ms-playwright.playwright"
