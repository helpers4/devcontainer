#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Exercises peon-ping alongside claude-dev: both register through postCreateCommand (not at
# image build time, when no volume is mounted yet), ordered by installsAfter so claude-dev's
# postCreateCommand (which links ~/.claude to its persistent volume) runs first. The hooks must
# therefore land in the volume-backed settings.json — plain test.sh (no claude-dev) can't tell
# that case from an ordinary ~/.claude directory.

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

SETTINGS="${CLAUDE_DIR}/settings.json"
if [ ! -f "${SETTINGS}" ]; then
    echo "❌ FAIL: ${SETTINGS} not found — peon-ping register didn't run into the real ~/.claude"
    exit 1
fi
if ! jq -e '[.hooks[][].hooks[] | select(.command | contains("peon-ping hook"))] | length > 0' "${SETTINGS}" >/dev/null; then
    echo "❌ FAIL: no peon-ping hook command found in ${SETTINGS}'s hooks"
    exit 1
fi
echo "✅ PASS: peon-ping hook entries present in the volume-backed ${SETTINGS}"

echo "🎉 Test passed."
