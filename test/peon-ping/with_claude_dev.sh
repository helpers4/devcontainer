#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Exercises peon-ping alongside claude-dev: both install via postCreateCommand (not at image
# build time, when no volume is mounted yet), ordered by installsAfter so claude-dev's own
# postCreateCommand (which links ~/.claude to its persistent volume) runs first. By the time
# peon-ping's postCreateCommand runs, ~/.claude is already the real, volume-backed directory,
# so peon-ping just installs straight into it — nothing claude-dev-specific to verify beyond
# that install actually landing in the right (already-linked) place. Plain test.sh (installed
# alone, without claude-dev) only exercises that same install against an ordinary directory
# and can't tell the two cases apart.

set -e

echo "Testing peon-ping with claude-dev..."

# Read the same TARGET_HOME claude-dev's own postCreateCommand baked in and used — see
# claude-dev's test.sh for why this can differ from test.sh's own $HOME.
CLAUDE_DEV_SCRIPT="/usr/local/share/claude-dev/setup-credentials.sh"
if [ ! -f "${CLAUDE_DEV_SCRIPT}" ]; then
    echo "❌ FAIL: ${CLAUDE_DEV_SCRIPT} missing — claude-dev didn't install"
    exit 1
fi
eval "$(grep '^TARGET_HOME=' "${CLAUDE_DEV_SCRIPT}")"
CLAUDE_DIR="${TARGET_HOME}/.claude"

if [ ! -L "${CLAUDE_DIR}" ]; then
    echo "❌ FAIL: ${CLAUDE_DIR} is not a symlink to claude-dev's volume — precondition for this test not met"
    exit 1
fi
echo "✅ PASS: ${CLAUDE_DIR} is claude-dev's symlinked volume"

PEON_DIR="${CLAUDE_DIR}/hooks/peon-ping"
if [ ! -d "${PEON_DIR}" ]; then
    echo "❌ FAIL: ${PEON_DIR} not found — peon-ping's postCreateCommand didn't install into the real ~/.claude"
    exit 1
fi
echo "✅ PASS: peon-ping installed directly into the volume-backed ${PEON_DIR}"

PEON_BIN="${TARGET_HOME}/.local/bin/peon"
if [ ! -x "${PEON_BIN}" ]; then
    echo "❌ FAIL: ${PEON_BIN} missing or not executable"
    exit 1
fi
if [ ! -e "$(readlink -f "${PEON_BIN}")" ]; then
    echo "❌ FAIL: ${PEON_BIN} is a dead symlink — this is the exact bug being regression-tested"
    exit 1
fi
echo "✅ PASS: ${PEON_BIN} resolves to a real file"

SETTINGS="${CLAUDE_DIR}/settings.json"
if [ ! -f "${SETTINGS}" ]; then
    echo "❌ FAIL: ${SETTINGS} not found"
    exit 1
fi
if ! command -v python3 >/dev/null 2>&1 || ! python3 -c "
import json, sys
with open('${SETTINGS}') as f:
    hooks = json.load(f).get('hooks', {})
found = any(
    'hooks/peon-ping/' in h.get('command', '')
    for entries in hooks.values()
    for entry in entries
    for h in entry.get('hooks', [])
)
sys.exit(0 if found else 1)
"; then
    echo "❌ FAIL: no peon-ping command found in ${SETTINGS}'s hooks"
    exit 1
fi
echo "✅ PASS: peon-ping hook entries present in the real ${SETTINGS}"

echo "🎉 Test passed."
