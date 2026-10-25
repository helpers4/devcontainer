#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Exercises remoteControl:true — default-off, and its failure mode is silent by design:
# claude-rc never fails the container start (it warns and returns 0), so a missing CLI,
# a missing tmux or a loop that never started all look like success unless asserted here.
# No login exists in CI, so the loop is expected to sit waiting for one.

set -e

echo "Testing claude-dev with remoteControl:true..."

if [ ! -x /usr/local/bin/claude ]; then
    echo "❌ FAIL: /usr/local/bin/claude missing — remoteControl:true must imply installCli"
    exit 1
fi
echo "✅ PASS: remoteControl implied the CLI install"

if ! command -v tmux >/dev/null 2>&1; then
    echo "❌ FAIL: tmux missing — remoteControl:true must install it"
    exit 1
fi
echo "✅ PASS: tmux installed"

ENV_FILE=/usr/local/share/claude-dev/remote-control.env
if ! grep -q '^RC_ENABLED=true$' "${ENV_FILE}"; then
    echo "❌ FAIL: ${ENV_FILE} doesn't record RC_ENABLED=true"
    exit 1
fi
echo "✅ PASS: options baked into ${ENV_FILE}"

# postStartCommand already ran before this script; give tmux a moment if it's still starting.
for _ in 1 2 3 4 5; do
    pgrep -f 'claude-rc loop$' >/dev/null 2>&1 && break
    sleep 1
done
if ! pgrep -f 'claude-rc loop$' >/dev/null 2>&1; then
    echo "❌ FAIL: the Remote Control loop isn't running — postStartCommand didn't start it"
    exit 1
fi
echo "✅ PASS: Remote Control loop running"

# The name option is sanitized ("h4 test" → "h4-test") before it reaches the session list.
STATE="$(find /tmp /run/user -path '*claude-rc-*/state.env' 2>/dev/null | head -n 1)"
if [ -z "${STATE}" ] || ! grep -q '^RC_NAME=h4-test$' "${STATE}"; then
    echo "❌ FAIL: resolved name isn't h4-test (state file: ${STATE:-none})"
    exit 1
fi
echo "✅ PASS: session name resolved to h4-test"

echo "🎉 Test passed."
