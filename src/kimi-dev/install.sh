#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME — the named volume is NOT attached yet.
# Links ~/.kimi-code to the volume's mount point, generates the runtime script
# with TARGET_HOME baked in, and optionally installs the Kimi Code CLI.

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

echo "🔧 Configuring kimi-dev feature..."
echo "  Username:    ${USERNAME}"
echo "  Home:        ${USER_HOME}"
echo "  Install CLI: ${INSTALL_CLI}"

# ============================================================================
# 1. Link ~/.kimi-code to the volume's mount point, right now, at build time.
# ============================================================================
# Kimi Code (extension and CLI alike) keeps everything under ~/.kimi-code —
# config.toml, OAuth credentials, session state. Without a volume behind it,
# a rebuild wipes it.
#
# The link dangles in the image and becomes valid the moment Docker attaches the
# volume at container creation — before any process runs inside it, so the
# extension can never start against a plain, empty ~/.kimi-code. Creating the
# mount point here, owned by the target user, also hands a brand-new volume to
# that user: Docker copies a mount point's ownership (and content) into an empty
# named volume the first time it's attached.

STAGED="/mnt/h4kimicode"
TARGET="${USER_HOME}/.kimi-code"
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
# Generating rather than copying means postCreateCommand always targets the
# correct user's home regardless of which user the container runtime invokes
# the script as.

SCRIPT="/usr/local/share/kimi-dev/setup-credentials.sh"
mkdir -p "$(dirname "${SCRIPT}")"

{
    cat << 'HEADER'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs once per container instance (postCreateCommand) — the named volume is mounted.
# ~/.kimi-code already points at it since the image build; this only makes sure the
# volume is writable by the current user, and restores the link if something replaced it.
set -euo pipefail
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh
HEADER
    printf 'TARGET_HOME=%q\n' "${USER_HOME}"
} > "${SCRIPT}"

cat >> "${SCRIPT}" << 'EOF'

STAGED="/mnt/h4kimicode"
TARGET="${TARGET_HOME}/.kimi-code"

if ! grep -qs " ${STAGED} " /proc/mounts; then
    echo "[kimi-dev] WARN: ${STAGED} is not a mounted volume — ~/.kimi-code won't persist across rebuilds" >&2
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
echo "[kimi-dev] ~/.kimi-code linked to the volume — credentials and config persist across rebuilds."
EOF

chmod +x "${SCRIPT}"
echo "  ✅ Installed ${SCRIPT}"

# ============================================================================
# 3. Optionally install the Kimi Code CLI.
# ============================================================================
# The official installer supports KIMI_INSTALL_DIR=/usr/local, landing the
# binary directly at /usr/local/bin/kimi — already on PATH, no symlink or
# shell-rc edit needed (KIMI_NO_MODIFY_PATH=1 keeps the installer from
# touching any rc file). This must NOT default to the installer's own
# $HOME/.kimi-code install dir: that path is the volume symlink created above,
# dangling at build time, so a default install would fail — and would also
# bake the binary into the credentials volume.

if [ "${INSTALL_CLI}" = "true" ]; then
    echo ""
    echo "Installing Kimi Code CLI..."

    h4_ensure_packages curl ca-certificates

    # A transient network failure here must not abort the whole feature
    # build — degrade gracefully, like every other optional CLI install in
    # this repo.
    if curl -fsSL https://code.kimi.com/kimi-code/install.sh | KIMI_INSTALL_DIR=/usr/local KIMI_NO_MODIFY_PATH=1 bash; then
        if [ -x /usr/local/bin/kimi ]; then
            echo "  ✅ kimi CLI installed: $(/usr/local/bin/kimi --version 2>/dev/null || echo 'ok')"
        else
            echo "  ⚠️  Kimi Code CLI install finished but /usr/local/bin/kimi wasn't found — check the installer output above." >&2
        fi
    else
        echo "  ⚠️  Kimi Code CLI installer failed — skipping (network issue, unsupported platform, or code.kimi.com unreachable?)." >&2
    fi
fi

echo ""
echo "🎉 kimi-dev configuration complete!"
