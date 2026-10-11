#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME — the named volume is NOT attached yet.
# Links ~/.cline to the volume's mount point, generates the runtime script with
# TARGET_HOME baked in, and optionally installs the Cline CLI.

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

echo "🔧 Configuring cline-dev feature..."
echo "  Username:    ${USERNAME}"
echo "  Home:        ${USER_HOME}"
echo "  Install CLI: ${INSTALL_CLI}"

# ============================================================================
# 1. Link ~/.cline to the volume's mount point, right now, at build time.
# ============================================================================
# Cline (extension 4.x and CLI alike) keeps everything under ~/.cline/data —
# provider API keys in settings/providers.json, global state, task history —
# not in VS Code's SecretStorage. Without a volume behind it, a rebuild wipes it.
#
# The link dangles in the image and becomes valid the moment Docker attaches the
# volume at container creation — before any process runs inside it, so the
# extension can never start against a plain, empty ~/.cline. Creating the mount
# point here, owned by the target user, also hands a brand-new volume to that
# user: Docker copies a mount point's ownership (and content) into an empty named
# volume the first time it's attached.

STAGED="/mnt/h4cline"
TARGET="${USER_HOME}/.cline"
USER_GROUP="$(id -gn "${USERNAME}" 2>/dev/null || echo "${USERNAME}")"

mkdir -p "${STAGED}"
if [ -d "${TARGET}" ] && [ ! -L "${TARGET}" ]; then
    cp -a "${TARGET}/." "${STAGED}/"
    rm -rf "${TARGET}"
fi
ln -sfn "${STAGED}" "${TARGET}"
chown -R "${USERNAME}:${USER_GROUP}" "${STAGED}"
chown -h "${USERNAME}:${USER_GROUP}" "${TARGET}"
chmod 700 "${STAGED}"
echo "  ✅ Linked ${TARGET} -> ${STAGED}"

# ============================================================================
# 2. Generate the runtime script with TARGET_HOME baked in.
# ============================================================================

SCRIPT="/usr/local/share/cline-dev/setup-credentials.sh"
mkdir -p "$(dirname "${SCRIPT}")"

{
    cat << 'HEADER'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs once per container instance (postCreateCommand) — the named volume is mounted.
# ~/.cline already points at it since the image build; this only makes sure the volume
# is writable by the current user, and restores the link if something replaced it.
set -euo pipefail
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh
HEADER
    printf 'TARGET_HOME=%q\n' "${USER_HOME}"
} > "${SCRIPT}"

cat >> "${SCRIPT}" << 'EOF'

STAGED="/mnt/h4cline"
TARGET="${TARGET_HOME}/.cline"

if ! grep -qs " ${STAGED} " /proc/mounts; then
    echo "[cline-dev] WARN: ${STAGED} is not a mounted volume — ~/.cline won't persist across rebuilds" >&2
fi

# Exclusive to this devcontainer (${devcontainerId} — see devcontainer-feature.json), so no
# --shared — see h4_ensure_volume_writable's own comment in helpers4-common/install.sh for why
# that flag choice follows the volume's scoping key.
h4_ensure_volume_writable "${STAGED}"

# Something replaced the build-time link with a plain directory: keep what's in it
# (never overwriting the volume's own state), then link again.
if [ ! -L "${TARGET}" ]; then
    if [ -d "${TARGET}" ]; then
        cp -rn "${TARGET}/." "${STAGED}/" 2>/dev/null || true
        rm -rf "${TARGET}"
    fi
    ln -sfn "${STAGED}" "${TARGET}"
fi
echo "[cline-dev] ~/.cline linked to the volume — provider keys and settings persist across rebuilds."
EOF

chmod +x "${SCRIPT}"
echo "  ✅ Installed ${SCRIPT}"

# ============================================================================
# 3. Optionally install the Cline CLI.
# ============================================================================

if [ "${INSTALL_CLI}" = "true" ]; then
    if ! command -v npm >/dev/null 2>&1; then
        echo "  ⚠️  npm not found — skipping Cline CLI install." >&2
        echo "      Add a Node.js feature (e.g. ghcr.io/devcontainers/features/node) before cline-dev, or install manually: npm install -g cline" >&2
    else
        # The cline package requires Node 22+; npm only warns (doesn't fail)
        # on an engine mismatch, so check explicitly rather than end up with
        # a CLI on PATH that fails at runtime with no build-time signal.
        NODE_MAJOR=0
        if command -v node >/dev/null 2>&1; then
            NODE_MAJOR="$(node --version | sed -E 's/^v([0-9]+).*/\1/')"
        fi
        if [ "${NODE_MAJOR}" -lt 22 ] 2>/dev/null; then
            echo "  ⚠️  Node.js $(node --version 2>/dev/null || echo 'not found') — Cline CLI requires Node 22+, skipping install." >&2
        # A transient network/registry failure here must not abort the whole
        # feature build — degrade gracefully like the "npm not found" branch.
        elif npm install -g cline; then
            echo "  ✅ cline CLI installed: $(cline --version 2>/dev/null || echo 'ok')"
        else
            echo "  ⚠️  npm install -g cline failed — skipping (network issue or registry unreachable?)." >&2
        fi
    fi
fi

echo ""
echo "🎉 cline-dev configuration complete!"
