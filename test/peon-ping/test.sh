#!/bin/bash

# Test script for peon-ping feature
# Copyright (c) 2025 helpers4
# Licensed under LGPL-3.0 - see LICENSE file for details

set -e

echo "Testing peon-ping feature..."

if [ -x /usr/local/bin/peon-ping ]; then
    echo "✅ PASS: /usr/local/bin/peon-ping installed and executable"
else
    echo "❌ FAIL: /usr/local/bin/peon-ping not found or not executable"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "❌ FAIL: jq is not available"
    exit 1
fi
echo "✅ PASS: jq is available"

# postCreateCommand (peon-ping register) isn't guaranteed to have run when test.sh does, so run
# it here: it must be safe to run any number of times.
peon-ping register >/dev/null
peon-ping register >/dev/null

SETTINGS="${HOME}/.claude/settings.json"
for event in SessionStart Stop PermissionRequest; do
    count="$(jq --arg e "${event}" '[.hooks[$e][].hooks[] | select(.command | contains("peon-ping hook"))] | length' "${SETTINGS}")"
    if [ "${count}" != "1" ]; then
        echo "❌ FAIL: ${event}: expected exactly one peon-ping hook entry in ${SETTINGS}, got ${count}"
        exit 1
    fi
done
echo "✅ PASS: Claude Code hooks registered once, idempotently"

if ! grep -q "peon-ping" "${HOME}/.cursor/hooks.json" "${HOME}/.codex/config.toml"; then
    echo "❌ FAIL: Cursor and/or Codex hooks not registered"
    exit 1
fi
echo "✅ PASS: Cursor and Codex hooks registered"

# The hook must never fail or block the agent, even with no relay listening.
if ! echo '{"hook_event_name":"Stop","session_id":"123e4567-e89b-12d3-a456-426614174000"}' \
    | PEON_RELAY_HOST=127.0.0.1 PEON_RELAY_PORT=1 peon-ping hook claude; then
    echo "❌ FAIL: peon-ping hook exited non-zero with no relay running"
    exit 1
fi
if [ "$(jq -r .last_active.event "${HOME}/.claude/hooks/peon-ping/.state.json")" != "Stop" ]; then
    echo "❌ FAIL: hook didn't record the event for Peon Pet"
    exit 1
fi
echo "✅ PASS: hook exits 0 without a relay and records the event for Peon Pet"

# Whether host.docker.internal resolves depends on whether the harness ran postStartCommand.
if getent hosts host.docker.internal >/dev/null 2>&1; then
    echo "✅ PASS: host.docker.internal resolves"
else
    echo "⚠️  WARN: host.docker.internal does not resolve yet — peon-ping check runs on postStartCommand"
fi

echo ""
echo "✅ All peon-ping feature tests passed!"
