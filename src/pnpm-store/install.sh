#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# pnpm-store: share a single pnpm content-addressable store across every repo
# and across rebuilds.
#
# The store lives in a Docker named volume (declared in devcontainer-feature.json)
# mounted at /workspaces/.pnpm-store, and pnpm is pointed at it via ~/.npmrc.
# A named volume is created automatically by Docker, so the feature is fully
# autonomous — no host directory to pre-create, works on first run everywhere.
# pnpm hardlinks from the store when the workspace shares the store's filesystem
# (e.g. Codespaces / clone-in-volume) and transparently falls back to copy/CoW
# otherwise; either way the store is shared and no stray .pnpm-store folders are
# created inside the repos.

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

# Fixed path — kept in sync with the "mounts" target in devcontainer-feature.json.
STORE_DIR="/workspaces/.pnpm-store"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

h4_detect_user
h4_resolve_home

echo "🔧 Configuring pnpm-store feature..."
echo "  Username:          ${USERNAME}"
echo "  Store directory:   ${STORE_DIR}"

# 1. Persist store-dir into the user's ~/.npmrc (read by pnpm).
#    Done at build time so it does not depend on pnpm being runnable yet.
NPMRC="${USER_HOME}/.npmrc"
# Ensure the home directory exists — minimal base images (e.g. ubuntu:latest)
# define the user in /etc/passwd but may not create their home directory.
USER_GROUP=""
mkdir -p "${USER_HOME}"
if [ "${USERNAME}" != "root" ]; then
    USER_GROUP="$(id -gn "${USERNAME}" 2>/dev/null || echo "${USERNAME}")"
    chown "${USERNAME}:${USER_GROUP}" "${USER_HOME}" 2>/dev/null || true
fi
touch "${NPMRC}"
# Strip any existing store-dir lines (grep -v exits 1 on empty output,
# so use || true to prevent set -e from aborting the mv).
{ grep -v '^store-dir=' "${NPMRC}" 2>/dev/null || true; } > "${NPMRC}.tmp"
mv "${NPMRC}.tmp" "${NPMRC}"
echo "store-dir=${STORE_DIR}" >> "${NPMRC}"
if [ "${USERNAME}" != "root" ]; then
    chown "${USERNAME}:${USER_GROUP}" "${NPMRC}" 2>/dev/null || true
fi
echo "  ✅ Wrote store-dir to ${NPMRC}"

# 1b. pnpm 11 dropped support for non-auth settings (incl. store-dir) in
#     .npmrc — they must live in ~/.config/pnpm/config.yaml instead. Write
#     both so the feature works whether the resolved pnpm is <11 or >=11.
PNPM_CONFIG_DIR="${USER_HOME}/.config/pnpm"
PNPM_CONFIG_YAML="${PNPM_CONFIG_DIR}/config.yaml"
mkdir -p "${PNPM_CONFIG_DIR}"
cat > "${PNPM_CONFIG_YAML}" <<YAML
storeDir: ${STORE_DIR}
YAML
if [ "${USERNAME}" != "root" ]; then
    chown -R "${USERNAME}:${USER_GROUP}" "${USER_HOME}/.config" 2>/dev/null || true
fi
echo "  ✅ Wrote storeDir to ${PNPM_CONFIG_YAML}"

# Create STORE_DIR during the image build so pnpm can use the configured path
# immediately. Without this, any pnpm invocation in a later feature (e.g.
# vite-plus) fails because /workspaces is not mounted at Docker build time and
# pnpm cannot create the store directory as a non-root user.
# The named volume declared in devcontainer-feature.json shadows this directory
# at container start — that's intentional.
mkdir -p "${STORE_DIR}" || true
if [ "${USERNAME}" != "root" ]; then
    chown "${USERNAME}:${USER_GROUP}" "${STORE_DIR}" 2>/dev/null || true
fi
echo "  ✅ Created store directory at ${STORE_DIR}"

# 2. Install the postCreate guard script. It runs once the volume is mounted,
#    so it can take ownership of the store and confirm pnpm uses it.
GUARD="/usr/local/bin/devcontainer-pnpm-store"

# Header with the resolved, feature-scoped value.
# Use printf %q to safely quote the path — handles spaces and special chars.
{
    cat <<'HEADER'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
set -euo pipefail
HEADER
    printf 'STORE_DIR=%q\n' "${STORE_DIR}"
} > "${GUARD}"

# Body (literal — not expanded at install time).
cat >> "${GUARD}" <<'EOF'

echo "📦 pnpm-store: ensuring store at ${STORE_DIR}"

# The named volume is mounted by the container runtime; just make sure the
# mountpoint exists (it normally does) for non-volume fallback scenarios.
if [ ! -d "${STORE_DIR}" ]; then
    mkdir -p "${STORE_DIR}" 2>/dev/null \
        || { command -v sudo >/dev/null 2>&1 && sudo mkdir -p "${STORE_DIR}"; } \
        || { echo "❌ pnpm-store: could not create ${STORE_DIR}"; exit 1; }
fi

# Named volumes are created root-owned; hand the store to the current user so
# pnpm can write to it. Only chown when needed (recursive chown is expensive on
# a populated store shared across rebuilds).
# stat failure (NFS root-squash, overlay FS) is treated as "unknown" — attempt
# chown anyway rather than silently skipping it.
store_owner="$(stat -c '%u' "${STORE_DIR}" 2>/dev/null || echo 'unknown')"
if [ "${store_owner}" != "$(id -u)" ]; then
    if command -v sudo >/dev/null 2>&1; then
        if ! sudo chown -R "$(id -u):$(id -g)" "${STORE_DIR}"; then
            echo "⚠️  pnpm-store: chown failed — pnpm may not be able to write to the store"
        fi
    else
        echo "⚠️  pnpm-store: store is owned by uid ${store_owner} and sudo is unavailable; pnpm writes will fail (EACCES)"
    fi
fi

# Re-apply store-dir to ~/.npmrc so it survives dotfiles-sync or any other
# tool that may have overwritten the file between image build and container start.
# Write to .tmp first — ~/.npmrc is never left in a partial state on failure.
NPMRC="${HOME}/.npmrc"
{ grep -v '^store-dir=' "${NPMRC}" 2>/dev/null || true; } > "${NPMRC}.tmp"
echo "store-dir=${STORE_DIR}" >> "${NPMRC}.tmp"
mv "${NPMRC}.tmp" "${NPMRC}"
echo "✅ pnpm-store: store-dir=${STORE_DIR} written to ${NPMRC}"

# pnpm 11 dropped support for non-auth settings (incl. store-dir) in .npmrc —
# they must live in ~/.config/pnpm/config.yaml. Re-apply for the same reason
# as above (dotfiles-sync or a fresh install may not have it).
PNPM_CONFIG_DIR="${HOME}/.config/pnpm"
PNPM_CONFIG_YAML="${PNPM_CONFIG_DIR}/config.yaml"
mkdir -p "${PNPM_CONFIG_DIR}"
echo "storeDir: ${STORE_DIR}" > "${PNPM_CONFIG_YAML}"
echo "✅ pnpm-store: storeDir=${STORE_DIR} written to ${PNPM_CONFIG_YAML}"

# Confirm pnpm picked up the configured store, when available.
# pnpm config get returns the literal string "undefined" (exit 0) when the key
# is unset — treat it the same as empty.
if command -v pnpm >/dev/null 2>&1; then
    configured="$(pnpm config get store-dir 2>/dev/null || true)"
    if [ "${configured}" = "${STORE_DIR}" ]; then
        echo "✅ pnpm-store: pnpm confirms store-dir = ${configured}"
    elif [ -z "${configured}" ] || [ "${configured}" = "undefined" ]; then
        echo "⚠️  pnpm-store: pnpm could not resolve store-dir; verify with: pnpm config get store-dir"
    else
        echo "⚠️  pnpm-store: pnpm reports store-dir = ${configured} (expected ${STORE_DIR}); a local .npmrc may be overriding it"
    fi
else
    echo "ℹ️  pnpm-store: pnpm not on PATH yet; store-dir is set in ~/.npmrc and ~/.config/pnpm/config.yaml for when it is."
fi
EOF

chmod +x "${GUARD}"
echo "  ✅ Installed guard script at ${GUARD}"

echo "🎉 pnpm-store configuration complete!"
