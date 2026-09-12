#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Exercises installCli:true — the default-off code path plain test.sh never
# runs. install.sh already degrades gracefully (warns instead of aborting)
# on a failed npm install, which is correct, but that means a real failure
# here would otherwise be silent — assert the CLI is actually there.

set -e

echo "Testing cline-dev with installCli:true..."

if ! command -v cline >/dev/null 2>&1; then
    echo "❌ FAIL: cline CLI not found — installCli:true did not install it"
    exit 1
fi
echo "✅ PASS: cline CLI on PATH"

if ! cline --version >/dev/null 2>&1; then
    echo "❌ FAIL: cline is on PATH but does not run"
    exit 1
fi
echo "✅ PASS: cline --version runs"

echo "🎉 Test passed."
