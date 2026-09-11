#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Exercises peon-ping alongside claude-dev — the combination that used to leave the peon binary
# a dead symlink and every Claude Code hook silently unregistered, because claude-dev's own
# postStartCommand replaces ~/.claude with a symlink to a persistent volume on every start,
# discarding whatever peon-ping had installed straight into it at build time. Plain test.sh
# (installed alone, without claude-dev) can't catch this — it only exercises the direct-install
# code path.

set -e

echo "Testing peon-ping with claude-dev..."

# Read the same TARGET_HOME claude-dev's own postStartCommand baked in and used — see
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

STABLE_HOME="${TARGET_HOME}/.local/share/peon-ping/claude-home"
if [ ! -d "${STABLE_HOME}/hooks/peon-ping" ]; then
    echo "❌ FAIL: peon-ping's install not found at ${STABLE_HOME}/hooks/peon-ping"
    exit 1
fi
echo "✅ PASS: peon-ping installed outside ~/.claude at ${STABLE_HOME}"

if [ ! -L "${CLAUDE_DIR}/hooks/peon-ping" ] || [ "$(readlink -f "${CLAUDE_DIR}/hooks/peon-ping")" != "$(readlink -f "${STABLE_HOME}/hooks/peon-ping")" ]; then
    echo "❌ FAIL: ${CLAUDE_DIR}/hooks/peon-ping is not linked to ${STABLE_HOME}/hooks/peon-ping — seed-claude-hooks.sh didn't run (or ran before claude-dev's postStartCommand)"
    exit 1
fi
echo "✅ PASS: ${CLAUDE_DIR}/hooks/peon-ping linked into the real ~/.claude"

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
    echo "❌ FAIL: no peon-ping command found in ${SETTINGS}'s hooks — merge into the real settings.json didn't happen"
    exit 1
fi
echo "✅ PASS: peon-ping hook entries merged into the real ${SETTINGS}"

echo "🎉 Test passed."
