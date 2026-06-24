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
h4_detect_user
h4_resolve_home

echo "🔧 Configuring mistral-dev feature..."
echo "  Username:    ${USERNAME}"
echo "  Home:        ${USER_HOME}"
echo "  Install CLI: ${INSTALL_CLI}"

# ============================================================================
# 1. Generate the runtime credentials script with TARGET_HOME baked in.
# ============================================================================
# Generating rather than copying means postStartCommand always targets the
# correct user's home regardless of which user the container runtime invokes
# the script as.

SCRIPT="/usr/local/share/mistral-dev/setup-credentials.sh"
mkdir -p "$(dirname "${SCRIPT}")"

{
    cat << 'HEADER'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at container START (postStartCommand) — bind mounts are available.
# Replaces TARGET_HOME/.vibe with a symlink to the host-mounted directory
# so credentials and all Mistral Vibe config persist across rebuilds.
set -euo pipefail
HEADER
    printf 'TARGET_HOME=%q\n' "${USER_HOME}"
} > "${SCRIPT}"

cat >> "${SCRIPT}" << 'EOF'

STAGED="/mnt/h4vibe"
TARGET="${TARGET_HOME}/.vibe"

if [ ! -d "${STAGED}" ]; then
    echo "[mistral-dev] ERROR: ${STAGED} is not mounted — cannot link ~/.vibe" >&2
    exit 1
fi

rm -rf "${TARGET}"
ln -sf "${STAGED}" "${TARGET}"
echo "[mistral-dev] ~/.vibe linked to host — credentials persist across rebuilds."
EOF

chmod +x "${SCRIPT}"
echo "  ✅ Installed ${SCRIPT}"

# ============================================================================
# 2. Optionally install the Mistral Vibe CLI.
# ============================================================================

if [ "${INSTALL_CLI}" = "true" ]; then
    echo ""
    echo "Installing Mistral Vibe CLI..."

    # Prefer uv (fast, self-contained); fall back to pip if uv is absent.
    if command -v uv >/dev/null 2>&1; then
        UV_TOOL_BIN_DIR=/usr/local/bin uv tool install mistral-vibe
        echo "  ✅ vibe installed via uv"
    elif command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1; then
        PIP_CMD="$(command -v pip3 2>/dev/null || command -v pip)"
        # Ensure Python 3.12+ — Vibe requires it.
        PYTHON_CMD="$(command -v python3 2>/dev/null || command -v python 2>/dev/null || true)"
        if [ -z "${PYTHON_CMD}" ]; then
            echo "  ⚠️  Python not found — skipping Vibe CLI install. Install Python 3.12+ and re-run pip install mistral-vibe." >&2
        else
            PY_VER="$("${PYTHON_CMD}" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
            PY_MAJOR="${PY_VER%%.*}"
            PY_MINOR="${PY_VER##*.}"
            if [ "${PY_MAJOR}" -lt 3 ] || { [ "${PY_MAJOR}" -eq 3 ] && [ "${PY_MINOR}" -lt 12 ]; }; then
                echo "  ⚠️  Python ${PY_VER} found but Vibe CLI requires 3.12+ — skipping CLI install." >&2
            else
                "${PIP_CMD}" install --quiet mistral-vibe
                echo "  ✅ vibe installed via pip (Python ${PY_VER})"
            fi
        fi
    else
        echo "  ⚠️  Neither uv nor pip found — skipping Vibe CLI install." >&2
        echo "      To install manually: curl -LsSf https://mistral.ai/vibe/install.sh | bash" >&2
    fi
fi

echo ""
echo "🎉 mistral-dev configuration complete!"
