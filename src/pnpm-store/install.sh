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

# Fixed path — kept in sync with the "mounts" target in devcontainer-feature.json.
STORE_DIR="/workspaces/.pnpm-store"
USERNAME="${USERNAME:-"${_REMOTE_USER:-automatic}"}"

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user (same logic as other helpers4 features)
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME=${CURRENT_USER}
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" > /dev/null 2>&1; then
    USERNAME=root
fi

echo "🔧 Configuring pnpm-store feature..."
echo "  Username:          ${USERNAME}"
echo "  Store directory:   ${STORE_DIR}"

# Resolve the user's home directory
if [ "${USERNAME}" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
    [ -n "${USER_HOME}" ] || USER_HOME="/home/${USERNAME}"
fi

# 1. Persist store-dir into the user's ~/.npmrc (read by pnpm).
#    Done at build time so it does not depend on pnpm being runnable yet.
NPMRC="${USER_HOME}/.npmrc"
# Ensure the home directory exists — minimal base images (e.g. ubuntu:latest)
# define the user in /etc/passwd but may not create their home directory.
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

# Create STORE_DIR during the image build so pnpm can use the configured path
# immediately. Without this, any pnpm invocation in a later feature (e.g.
# vite-plus) fails because /workspaces is not mounted at Docker build time and
# pnpm cannot create the store directory as a non-root user.
# The named volume declared in devcontainer-feature.json shadows this directory
# at container start — that's intentional.
mkdir -p "${STORE_DIR}"
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
store_owner="$(stat -c '%u' "${STORE_DIR}" 2>/dev/null || echo '')"
if [ -n "${store_owner}" ] && [ "${store_owner}" != "$(id -u)" ] && command -v sudo >/dev/null 2>&1; then
    sudo chown -R "$(id -u):$(id -g)" "${STORE_DIR}" 2>/dev/null || true
fi

# Confirm pnpm picked up the configured store, when available.
if command -v pnpm >/dev/null 2>&1; then
    configured="$(pnpm config get store-dir 2>/dev/null || echo '')"
    echo "✅ pnpm-store: pnpm store-dir = ${configured}"
else
    echo "ℹ️  pnpm-store: pnpm not on PATH yet; store-dir is set in ~/.npmrc for when it is."
fi
EOF

chmod +x "${GUARD}"
echo "  ✅ Installed guard script at ${GUARD}"

echo "🎉 pnpm-store configuration complete!"
