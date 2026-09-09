#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2026 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Exercises installCli:true — the default-off code path that plain test.sh
# never runs, and the exact class of gap that let vite-plus's own installer
# regression go unnoticed: an install.sh that degrades gracefully (warns
# instead of aborting) on a failed CLI install looks identical in CI to one
# that succeeded, unless something actually asserts the binary landed.

set -e

echo "Testing claude-dev with installCli:true..."

if [ ! -x /usr/local/bin/claude ]; then
    echo "❌ FAIL: /usr/local/bin/claude missing — installCli:true did not install the CLI"
    exit 1
fi
echo "✅ PASS: /usr/local/bin/claude present"

if ! /usr/local/bin/claude --version >/dev/null 2>&1; then
    echo "❌ FAIL: /usr/local/bin/claude exists but does not run"
    exit 1
fi
echo "✅ PASS: claude --version runs"

echo "🎉 Test passed."
