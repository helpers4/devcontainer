#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs org-workspace: puts clone-repos.sh and its options in place.

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root.'
    exit 1
fi

h4_ensure_packages jq

# The CLI passes every option as an env var, with the defaults from devcontainer-feature.json.
ORG_OPTION="${ORG:-}"
REPOS_OPTION="${REPOS:-}"
AUTO_DISCOVER_OPTION="${AUTODISCOVER:-}"
EXCLUDE_OPTION="${EXCLUDE:-}"
GENERATE_CODE_WORKSPACE_OPTION="${GENERATECODEWORKSPACE:-}"
CODE_WORKSPACE_NAME_OPTION="${CODEWORKSPACENAME:-}"

# clone-repos.sh creates its links in /workspaces, which the image owns as root.
mkdir -p /workspaces
if [ -n "${_REMOTE_USER:-}" ] && [ "${_REMOTE_USER}" != "root" ] && id "${_REMOTE_USER}" >/dev/null 2>&1; then
    chown "${_REMOTE_USER}" /workspaces || echo "Warning: could not chown /workspaces to ${_REMOTE_USER}" >&2
fi

# The options only exist as env vars during this install, so save them for clone-repos.sh.
INSTALL_DIR="/usr/local/share/org-workspace"
mkdir -p "${INSTALL_DIR}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
install -m 0755 "${SCRIPT_DIR}/clone-repos.sh" "${INSTALL_DIR}/clone-repos.sh"
{
    printf 'ORG_OPTION=%q\n' "${ORG_OPTION}"
    printf 'REPOS_OPTION=%q\n' "${REPOS_OPTION}"
    printf 'AUTO_DISCOVER_OPTION=%q\n' "${AUTO_DISCOVER_OPTION}"
    printf 'EXCLUDE_OPTION=%q\n' "${EXCLUDE_OPTION}"
    printf 'GENERATE_CODE_WORKSPACE_OPTION=%q\n' "${GENERATE_CODE_WORKSPACE_OPTION}"
    printf 'CODE_WORKSPACE_NAME_OPTION=%q\n' "${CODE_WORKSPACE_NAME_OPTION}"
} >"${INSTALL_DIR}/options.env"

echo "  Installed ${INSTALL_DIR}/clone-repos.sh"
