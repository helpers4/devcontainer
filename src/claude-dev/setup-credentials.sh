#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at container START (postStartCommand) — bind mounts are available.
# Creates a live symlink ~/.claude/.credentials.json → /mnt/h4claude/.credentials.json
# so token refreshes propagate host ↔ container automatically.

set -e

STAGED="/mnt/h4claude/.credentials.json"
TARGET="${HOME}/.claude/.credentials.json"

mkdir -p "${HOME}/.claude"

if [ -f "$STAGED" ]; then
    # Replace any existing file/symlink with a live symlink to the host mount.
    ln -sf "$STAGED" "$TARGET"
    echo "[claude-dev] Claude credentials linked from host — no re-authentication needed."
elif [ -d "$STAGED" ]; then
    # Docker created a directory because the host file didn't exist yet.
    # Authenticate once on the host (run 'claude' there) to create ~/.claude/.credentials.json,
    # then rebuild the container — subsequent starts will pick it up automatically.
    echo "[claude-dev] No host credentials found at ~/.claude/.credentials.json."
    echo "             Run 'claude' on the host once to create them, then rebuild."
fi
