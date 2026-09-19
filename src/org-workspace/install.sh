#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs org-workspace: ships a postStartCommand script that clones every target repo of
# a GitHub org into a persistent named volume, symlinks each into a sibling /workspaces folder,
# and generates/merges a multi-root .code-workspace file at the bootstrap repo's own root.

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root.'
    exit 1
fi

h4_ensure_packages jq

# Feature options — env var names are the option id uppercased (devcontainers CLI convention).
ORG_OPTION="${ORG:-}"
REPOS_OPTION="${REPOS:-}"
AUTO_DISCOVER_OPTION="${AUTODISCOVER:-true}"
EXCLUDE_OPTION="${EXCLUDE:-}"
GENERATE_CODE_WORKSPACE_OPTION="${GENERATECODEWORKSPACE:-true}"
CODE_WORKSPACE_NAME_OPTION="${CODEWORKSPACENAME:-}"

# clone-repos.sh creates its sibling symlinks directly under /workspaces, which the image
# ships as root:root — with no per-repo mountpoint pre-creating them (the hand-written `mounts`
# this Feature replaces did that as a side effect), the remote user couldn't create anything
# there. Non-recursive: only the directory itself, never what's inside it.
mkdir -p /workspaces
if [ -n "${_REMOTE_USER:-}" ] && [ "${_REMOTE_USER}" != "root" ] && id "${_REMOTE_USER}" >/dev/null 2>&1; then
    chown "${_REMOTE_USER}" /workspaces || echo "⚠️  could not chown /workspaces to ${_REMOTE_USER}" >&2
fi

INSTALL_DIR="/usr/local/share/org-workspace"
mkdir -p "${INSTALL_DIR}"

# The script itself is a regular file shipped with the Feature (so it can be shellcheck'd and
# tested); only the option values are baked in — feature options are only available as env
# vars during this install.sh run, not later when postStartCommand actually executes it.
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

echo "  ✅ Installed ${INSTALL_DIR}/clone-repos.sh"
