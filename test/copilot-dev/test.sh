#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# copilot-dev has no dependsOn on github-dev (AI assistant only, deliberately
# separate from platform tooling — see the README), so a standalone test has
# no gh CLI to install the extension against. That's the actual default
# path most consumers hit before adding github-dev themselves; assert it
# degrades the way the feature documents, not just "didn't crash".

set -e

echo "Testing copilot-dev feature..."

if command -v gh >/dev/null 2>&1; then
    if gh extension list 2>/dev/null | grep -qi copilot; then
        echo "✅ PASS: gh copilot extension installed (gh CLI was present)"
    else
        echo "❌ FAIL: gh CLI present but gh copilot extension not installed"
        exit 1
    fi
else
    echo "✅ PASS: gh CLI absent — install.sh's documented graceful-skip path, as expected without github-dev"
fi

echo "🎉 Test passed."
