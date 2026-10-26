#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs the Graphite CLI (gt) from npm and a start-time auth script.
#
# npm is the only real install path: Graphite publishes no standalone binary,
# and its Homebrew formula is itself a wrapper around `npm install` (it depends
# on brew's node). The token is never baked into the image — auth.sh runs at
# every container start and reads GRAPHITE_TOKEN from the environment.

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

GRAPHITE_VERSION="${VERSION:-stable}"

echo "🔧 Installing graphite-dev feature..."
echo "  Version: ${GRAPHITE_VERSION}"

if ! command -v npm > /dev/null 2>&1; then
    echo "(!) npm not found — the node feature this one dependsOn should have installed it."
    exit 1
fi

if ! command -v git > /dev/null 2>&1; then
    h4_ensure_packages git
fi

# gt >= 1.0 refuses to run on git < 2.38 (most commands break even with the
# GRAPHITE_IGNORE_GIT_VERSION override). Warn rather than fail: the git
# feature or a newer base image may supply it in the final container.
GIT_VERSION="$(git --version | sed -E 's/^git version ([0-9]+\.[0-9]+).*/\1/')"
if [ "$(printf '%s\n2.38\n' "${GIT_VERSION}" | sort -V | head -1)" != "2.38" ]; then
    echo "  ⚠️  git ${GIT_VERSION} is older than 2.38, which gt requires." >&2
    echo "      Add ghcr.io/devcontainers/features/git with \"version\": \"latest\" to your devcontainer." >&2
fi

echo "📦 Installing @withgraphite/graphite-cli@${GRAPHITE_VERSION}..."
if ! npm install -g "@withgraphite/graphite-cli@${GRAPHITE_VERSION}"; then
    echo "(!) Failed to install @withgraphite/graphite-cli@${GRAPHITE_VERSION}"
    exit 1
fi

if ! gt --version > /dev/null 2>&1; then
    echo "(!) gt installation verification failed"
    exit 1
fi
echo "  ✅ gt $(gt --version 2>&1 | head -1) installed"

# Static script — runs as the container's remote user (postStartCommand), so
# $HOME is already the right one and nothing needs baking in at build time.
AUTH_SCRIPT="/usr/local/share/graphite-dev/auth.sh"
mkdir -p "$(dirname "${AUTH_SCRIPT}")"
cat > "${AUTH_SCRIPT}" << 'AUTH'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs on every container start. Authenticates gt from GRAPHITE_TOKEN, if set.
# Never fails the container start: a missing or rejected token only warns.
set -uo pipefail

if [ -z "${GRAPHITE_TOKEN:-}" ]; then
    echo "[graphite-dev] GRAPHITE_TOKEN not set — run 'gt auth --token <token>' yourself (token: https://app.graphite.com/activate)."
    exit 0
fi

if gt auth --token "${GRAPHITE_TOKEN}" > /dev/null 2>&1; then
    echo "[graphite-dev] gt authenticated from GRAPHITE_TOKEN."
else
    echo "[graphite-dev] WARN: 'gt auth --token' failed — is GRAPHITE_TOKEN valid?" >&2
fi
exit 0
AUTH
chmod 755 "${AUTH_SCRIPT}"
echo "  ✅ Installed ${AUTH_SCRIPT}"

echo
echo "🎉 graphite-dev installation complete!"
