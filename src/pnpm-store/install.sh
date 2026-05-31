#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# pnpm-store: configure a shared pnpm store on the same filesystem as the code.
#
# pnpm links packages into node_modules with hardlinks, which cannot cross a
# filesystem boundary. When the store lives on a different filesystem than the
# repos (e.g. a Docker named volume vs. bind-mounted repos), pnpm silently
# abandons the shared store and recreates a .pnpm-store inside the project.
# This feature points the store at a path on the same filesystem and guards
# against the cross-device situation.

set -euo pipefail

STORE_DIR="${STOREDIR:-/workspaces/.pnpm-store}"
SET_GLOBAL_CONFIG="${SETGLOBALCONFIG:-true}"
FAIL_IF_CROSS_DEVICE="${FAILIFCROSSDEVICE:-false}"
CHECK_AGAINST="${CHECKAGAINST:-/workspaces}"
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
echo "  Set global config: ${SET_GLOBAL_CONFIG}"
echo "  Fail cross-device: ${FAIL_IF_CROSS_DEVICE}"
echo "  Check against:     ${CHECK_AGAINST}"

# Resolve the user's home directory
if [ "${USERNAME}" = "root" ]; then
    USER_HOME="/root"
else
    USER_HOME="$(getent passwd "${USERNAME}" | cut -d: -f6)"
    [ -n "${USER_HOME}" ] || USER_HOME="/home/${USERNAME}"
fi

# 1. Persist store-dir into the user's ~/.npmrc (read by pnpm).
#    Done at build time so it does not depend on pnpm being runnable yet.
if [ "${SET_GLOBAL_CONFIG}" = "true" ]; then
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
fi

# 2. Install the postCreate guard script. It runs once the bind mounts are in
#    place, so it can create/own the store and verify it shares the repos'
#    filesystem.
GUARD="/usr/local/bin/devcontainer-pnpm-store"

# Header with the resolved, feature-scoped values.
# Use printf %q to safely quote path values — handles spaces and special chars.
{
    cat <<'HEADER'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
set -euo pipefail
HEADER
    printf 'STORE_DIR=%q\n' "${STORE_DIR}"
    printf 'CHECK_AGAINST=%q\n' "${CHECK_AGAINST}"
    printf 'FAIL_IF_CROSS_DEVICE=%q\n' "${FAIL_IF_CROSS_DEVICE}"
} > "${GUARD}"

# Body (literal — not expanded at install time).
cat >> "${GUARD}" <<'EOF'

echo "📦 pnpm-store: ensuring store at ${STORE_DIR}"

if ! mkdir -p "${STORE_DIR}" 2>/dev/null; then
    # Fallback: try with sudo (needed when the parent directory is root-owned
    # and the current user is non-root, e.g. in devcontainer features tests).
    if command -v sudo >/dev/null 2>&1 \
            && sudo mkdir -p "${STORE_DIR}" 2>/dev/null \
            && sudo chown "$(id -u):$(id -g)" "${STORE_DIR}" 2>/dev/null; then
        : # created via sudo
    else
        echo "❌ pnpm-store: could not create store directory ${STORE_DIR}"
        echo "   Check that the path is writable or that the bind-mount is in place."
        exit 1
    fi
fi

# Take ownership of the store only when needed — recursive chown is expensive
# on large stores (tens of thousands of files shared across rebuilds).
if [ -d "${STORE_DIR}" ]; then
    store_owner="$(stat -c '%u' "${STORE_DIR}" 2>/dev/null || echo '')"
    if [ -n "${store_owner}" ] && [ "${store_owner}" != "$(id -u)" ] && command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$(id -u):$(id -g)" "${STORE_DIR}" 2>/dev/null || true
    fi
fi

store_dev=""
if [ -d "${STORE_DIR}" ]; then
    store_dev="$(stat -c '%d' "${STORE_DIR}" 2>/dev/null || true)"
fi

if [ -z "${store_dev}" ]; then
    echo "❌ pnpm-store: could not determine the filesystem of ${STORE_DIR}."
    echo "   The directory may not exist or may not be readable."
    if [ "${FAIL_IF_CROSS_DEVICE}" = "true" ]; then
        exit 1
    fi
    echo "   (failIfCrossDevice=false → skipping filesystem check)"
fi

mismatch=0
if [ -n "${store_dev}" ] && [ -d "${CHECK_AGAINST}" ]; then
    for repo in "${CHECK_AGAINST}"/*; do
        [ -d "${repo}" ] || continue
        # Skip the store directory itself.
        [ "${repo}" = "${STORE_DIR}" ] && continue
        repo_dev="$(stat -c '%d' "${repo}" 2>/dev/null || echo '')"
        [ -n "${repo_dev}" ] || continue
        if [ "${repo_dev}" != "${store_dev}" ]; then
            echo "⚠️  pnpm-store: ${repo} (fs ${repo_dev}) is on a different filesystem than the store (fs ${store_dev})"
            mismatch=1
        fi
    done
fi

if [ "${mismatch}" -ne 0 ]; then
    echo ""
    echo "❌ pnpm-store: the pnpm store is on a different filesystem than one or more repos."
    echo "   pnpm hardlinks packages into node_modules and cannot cross filesystems,"
    echo "   so it would silently create a .pnpm-store inside each repo."
    echo ""
    echo "   Fix: bind-mount a host folder that is a sibling of your repos onto"
    echo "        ${STORE_DIR}, e.g. in devcontainer.json:"
    echo ""
    echo "        \"mounts\": ["
    echo "          \"source=\${localWorkspaceFolder}/../.pnpm-store,target=${STORE_DIR},type=bind,consistency=cached\""
    echo "        ]"
    echo ""
    if [ "${FAIL_IF_CROSS_DEVICE}" = "true" ]; then
        exit 1
    fi
    echo "   (failIfCrossDevice=false → continuing despite the mismatch)"
elif [ -n "${store_dev}" ]; then
    echo "✅ pnpm-store: store shares the repos' filesystem — hardlinks will work."
fi

# Confirm pnpm picked up the configured store, when available.
if command -v pnpm >/dev/null 2>&1; then
    configured="$(pnpm config get store-dir 2>/dev/null || echo '')"
    echo "ℹ️  pnpm store-dir = ${configured}"
else
    echo "ℹ️  pnpm not found on PATH yet; store-dir is set in ~/.npmrc for when it is."
fi
EOF

chmod +x "${GUARD}"
echo "  ✅ Installed guard script at ${GUARD}"

echo "🎉 pnpm-store configuration complete!"
