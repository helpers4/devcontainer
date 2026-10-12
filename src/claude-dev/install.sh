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

INSTALL_CLI="${INSTALLCLI:-false}"

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

# USERNAME is injected by the devcontainer CLI from the 'username' feature option.
# h4_detect_user falls back to UID-1000 candidate or root when not explicitly set.
USERNAME="${USERNAME:-"automatic"}"
h4_detect_user
h4_resolve_home

echo "🔧 Configuring claude-dev feature..."
echo "  Username:    ${USERNAME}"
echo "  Home:        ${USER_HOME}"
echo "  Install CLI: ${INSTALL_CLI}"

# Generate the runtime credentials script with TARGET_HOME baked in via printf %q.
# Generating rather than copying means postCreateCommand always targets the correct
# user's home regardless of which user the container runtime invokes the script as.
#
# This exact path is also peon-ping's own proxy for "is claude-dev installed" (its
# install.sh checks for this file directly) — keep the two in sync if it ever moves.
SCRIPT="/usr/local/share/claude-dev/setup-credentials.sh"
mkdir -p "$(dirname "${SCRIPT}")"

{
    cat << 'HEADER'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs once, at container creation (postCreateCommand) — the named volume is already
# mounted by then (Docker attaches mounts at container creation, before any command runs
# inside it; postCreateCommand fires exactly once per container instance, including a fresh
# instance created by a rebuild, never again on a plain restart of the same instance).
# Replaces TARGET_HOME/.claude with a symlink to it so credentials and all Claude config
# persist across rebuilds.
set -euo pipefail
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh
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

# Exclusive to this devcontainer (${devcontainerId} — see devcontainer-feature.json), so no
# --shared — see h4_ensure_volume_writable's own comment in helpers4-common/install.sh for why
# that flag choice follows the volume's scoping key.
h4_ensure_volume_writable "${STAGED}"

# TARGET is an ordinary directory here, not yet a symlink (this is the first and only time
# this script runs for this container instance) — it may already hold files another feature
# wrote into ~/.claude at *image build* time, before this volume existed to write into (the
# volume is only attached once the container is created, not during the image build that
# produced it). Add whatever's missing to the volume; never overwrite what's already there —
# the volume's own accumulated state (real credentials, a user's actual settings.json edits,
# memory) always wins over a fresh build's defaults. A feature whose build-time file already
# exists in the volume from a previous build simply won't see that particular update land
# here; it should install via its own postCreateCommand instead (ordered after this one via
# installsAfter) if it needs to keep pace with rebuilds — see peon-ping for the pattern.
if [ -d "${TARGET}" ] && [ ! -L "${TARGET}" ]; then
    cp -rn "${TARGET}/." "${STAGED}/" 2>/dev/null || true
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
