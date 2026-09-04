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

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

# USERNAME is injected by the devcontainer CLI from the 'username' feature option.
# h4_detect_user falls back to UID-1000 candidate or root when not explicitly set.
USERNAME="${_BUILD_ARG_USERNAME:-"${USERNAME:-"automatic"}"}"
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
# Runs at container START (postStartCommand) — the named volume is mounted.
# Replaces TARGET_HOME/.vibe with a symlink to it so credentials and all
# Mistral Vibe config persist across rebuilds.
set -euo pipefail
HEADER
    printf 'TARGET_HOME=%q\n' "${USER_HOME}"
} > "${SCRIPT}"

cat >> "${SCRIPT}" << 'EOF'

STAGED="/mnt/h4vibe"
TARGET="${TARGET_HOME}/.vibe"

if [ ! -d "${STAGED}" ]; then
    echo "[mistral-dev] WARN: ${STAGED} not mounted — ~/.vibe not linked, no persistence across rebuilds" >&2
    exit 0
fi

# Docker creates a named volume root-owned; hand it to the current user so
# Mistral Vibe can write into it. Unlike pnpm-store's volume (exclusive per
# container, keyed by ${devcontainerId}), this one is deliberately shared
# across every local project for the same host OS user — a second,
# concurrently-running project can have a different container UID. So: claim
# ownership only once, the first time the volume is still root-owned; if it
# already belongs to a *different* non-root user (another project's
# container), don't steal it out from under a possibly still-running session
# there — just grant world read/write instead, so both UIDs can use it
# without an ownership tug-of-war on every start.
staged_owner="$(stat -c '%u' "${STAGED}" 2>/dev/null || echo 'unknown')"
if [ "${staged_owner}" = "0" ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo chown -R "$(id -u):$(id -g)" "${STAGED}" \
            || echo "[mistral-dev] WARN: chown of ${STAGED} failed — writes may fail (EACCES)" >&2
    else
        echo "[mistral-dev] WARN: ${STAGED} is root-owned and sudo is unavailable; writes will fail (EACCES)" >&2
    fi
elif [ "${staged_owner}" != "$(id -u)" ]; then
    if command -v sudo >/dev/null 2>&1; then
        sudo chmod -R o+rwX "${STAGED}" \
            || echo "[mistral-dev] WARN: chmod of ${STAGED} failed — writes may fail (EACCES)" >&2
    else
        echo "[mistral-dev] WARN: ${STAGED} is owned by uid ${staged_owner} and sudo is unavailable; writes will fail (EACCES)" >&2
    fi
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
