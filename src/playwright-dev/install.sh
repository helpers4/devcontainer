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

# Bootstrap helpers4 shared library. helpers4-common installs it; if running
# standalone (e.g. devcontainer features test), create it inline so the feature
# is self-contained without a GHCR pull.
if [ ! -f /usr/local/share/helpers4/common.sh ]; then
    mkdir -p /usr/local/share/helpers4
    cat > /usr/local/share/helpers4/common.sh << 'H4_COMMON'
# shellcheck shell=bash
h4_detect_user() {
    USERNAME="${USERNAME:-${_REMOTE_USER:-automatic}}"
    if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
        USERNAME=""
        local _uid1000
        _uid1000="$(awk -v val=1000 -F: '$3==val{print $1; exit}' /etc/passwd 2>/dev/null || true)"
        local candidate
        for candidate in vscode node codespace "${_uid1000}"; do
            if [ -n "${candidate}" ] && id -u "${candidate}" >/dev/null 2>&1; then
                USERNAME="${candidate}"; break
            fi
        done
        [ -z "${USERNAME}" ] && USERNAME=root
    elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" >/dev/null 2>&1; then
        USERNAME=root
    fi
    export USERNAME
}
h4_resolve_home() {
    if [ "${USERNAME}" = "root" ]; then
        USER_HOME=/root
    else
        USER_HOME="$(getent passwd "${USERNAME}" 2>/dev/null | cut -d: -f6)"
        [ -n "${USER_HOME}" ] || USER_HOME="/home/${USERNAME}"
    fi
    export USER_HOME
}
h4_apt_update() {
    if [ "$(find /var/lib/apt/lists -maxdepth 1 \( -name '*.lz4' -o -name '*.gz' \) 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y -q
    fi
}
h4_ensure_packages() {
    local missing=() pkg
    for pkg in "$@"; do dpkg -s "${pkg}" >/dev/null 2>&1 || missing+=("${pkg}"); done
    if [ "${#missing[@]}" -gt 0 ]; then
        h4_apt_update
        apt-get install -y -q --no-install-recommends "${missing[@]}"
    fi
}
H4_COMMON
fi
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

# Named volumes are created root-owned; hand the cache to the current user so
# Playwright's installer can write to it.
cache_owner="$(stat -c '%u' "${BROWSERS_PATH}" 2>/dev/null || echo 'unknown')"
if [ "${cache_owner}" != "$(id -u)" ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$(id -u):$(id -g)" "${BROWSERS_PATH}" \
            || echo "⚠️  playwright-dev: chown failed — Playwright may not be able to write to the cache"
    else
        echo "⚠️  playwright-dev: cache is owned by uid ${cache_owner} and sudo is unavailable; downloads will fail (EACCES)"
    fi
fi

# Download the actual browser binaries only if not already fetched for this
# browser selection. A completion marker (rather than "directory non-empty")
# is used so an interrupted first download gets retried on the next start
# instead of being silently treated as done forever; the marker is scoped
# per browser selection so switching the `browsers` option after a rebuild
# re-triggers a download instead of trusting a stale, incomplete cache.
MARKER="${BROWSERS_PATH}/.h4-installed-${BROWSER_ARG:-all}"
if [ ! -f "${MARKER}" ]; then
    echo "📥 playwright-dev: downloading browser binaries (${BROWSER_ARG:-all}) into ${BROWSERS_PATH}..."
    # No @latest pin — see install.sh's install-deps step for why.
    # shellcheck disable=SC2086
    if npx -y playwright install ${BROWSER_ARG}; then
        touch "${MARKER}"
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
