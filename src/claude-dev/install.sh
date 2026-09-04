#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME — bind mounts are NOT available yet.
# Resolves the target user's home directory and generates the runtime
# credentials script with TARGET_HOME baked in.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

INSTALL_CLI="${_BUILD_ARG_INSTALLCLI:-${INSTALLCLI:-false}}"

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

# USERNAME is injected by the devcontainer CLI from the 'username' feature option.
# h4_detect_user falls back to UID-1000 candidate or root when not explicitly set.
USERNAME="${_BUILD_ARG_USERNAME:-"${USERNAME:-"automatic"}"}"
h4_detect_user
h4_resolve_home

echo "🔧 Configuring claude-dev feature..."
echo "  Username:    ${USERNAME}"
echo "  Home:        ${USER_HOME}"
echo "  Install CLI: ${INSTALL_CLI}"

# Generate the runtime credentials script with TARGET_HOME baked in via printf %q.
# Generating rather than copying means postStartCommand always targets the correct
# user's home regardless of which user the container runtime invokes the script as.
SCRIPT="/usr/local/share/claude-dev/setup-credentials.sh"
mkdir -p "$(dirname "${SCRIPT}")"

{
    cat << 'HEADER'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at container START (postStartCommand) — the named volume is mounted.
# Replaces TARGET_HOME/.claude with a symlink to it so credentials and all
# Claude config persist across rebuilds.
set -euo pipefail
HEADER
    printf 'TARGET_HOME=%q\n' "${USER_HOME}"
} > "${SCRIPT}"

cat >> "${SCRIPT}" << 'EOF'

STAGED="/mnt/h4claude"
TARGET="${TARGET_HOME}/.claude"

if [ ! -d "${STAGED}" ]; then
    echo "[claude-dev] WARN: ${STAGED} not mounted — ~/.claude not linked, no persistence across rebuilds" >&2
    exit 0
fi

# Docker creates a named volume root-owned; hand it to the current user so
# Claude Code can write session state, settings, and memory into it. Only
# chown when needed — a recursive chown on a populated volume shared across
# rebuilds isn't free. (Same pattern as pnpm-store's guard script.)
staged_owner="$(stat -c '%u' "${STAGED}" 2>/dev/null || echo 'unknown')"
if [ "${staged_owner}" != "$(id -u)" ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$(id -u):$(id -g)" "${STAGED}" \
            || echo "[claude-dev] WARN: chown of ${STAGED} failed — writes may fail (EACCES)" >&2
    else
        echo "[claude-dev] WARN: ${STAGED} is owned by uid ${staged_owner} and sudo is unavailable; writes will fail (EACCES)" >&2
    fi
fi

rm -rf "${TARGET}"
ln -sf "${STAGED}" "${TARGET}"
echo "[claude-dev] ~/.claude linked to host — credentials persist across rebuilds."
EOF

chmod +x "${SCRIPT}"
echo "  ✅ Installed ${SCRIPT}"

# Optionally install the Claude Code CLI via the official native installer.
# Runs as the target user so it lands in their own home (root's home is
# usually 0700, which would make a root-owned install unreachable for
# anyone else); symlinked into /usr/local/bin so it's on PATH without
# relying on that user's shell profile already including ~/.local/bin.
if [ "${INSTALL_CLI}" = "true" ]; then
    echo ""
    echo "Installing Claude Code CLI..."

    if command -v curl >/dev/null 2>&1; then
        # A transient network failure here must not abort the whole feature
        # build — degrade gracefully like the "curl not found" branch below.
        if su - "${USERNAME}" -c "curl -fsSL https://claude.ai/install.sh | bash"; then
            CLI_BIN="${USER_HOME}/.local/bin/claude"
            if [ -x "${CLI_BIN}" ]; then
                ln -sf "${CLI_BIN}" /usr/local/bin/claude
                echo "  ✅ claude CLI installed and linked to /usr/local/bin/claude"
            else
                echo "  ⚠️  Claude Code CLI install finished but ${CLI_BIN} wasn't found — check the installer output above." >&2
            fi
        else
            echo "  ⚠️  Claude Code CLI installer failed — skipping (network issue or claude.ai unreachable?)." >&2
        fi
    else
        echo "  ⚠️  curl not found — skipping Claude Code CLI install." >&2
    fi
fi

echo ""
echo "🎉 claude-dev configuration complete!"
