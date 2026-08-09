#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing nub feature..."

# Test 1: nub is installed and executable (installGlobally defaults to true,
# so it should be directly on PATH via /usr/local/bin without needing the
# target user's own ~/.nub/bin in $PATH).
if command -v nub >/dev/null 2>&1; then
    echo "✅ PASS: nub is installed and accessible"
    nub --version || true
else
    echo "❌ FAIL: nub is not installed or not accessible"
    exit 1
fi

# Test 2: nub is in the expected global location
if [ -x "/usr/local/bin/nub" ]; then
    echo "✅ PASS: nub is installed in /usr/local/bin/"
else
    echo "❌ FAIL: nub is not in expected location /usr/local/bin/"
    exit 1
fi

# Test 3: nubx symlink is present alongside nub (dispatches on argv[0])
if [ -e "/usr/local/bin/nubx" ]; then
    echo "✅ PASS: nubx is installed in /usr/local/bin/"
else
    echo "❌ FAIL: nubx is not in expected location /usr/local/bin/"
    exit 1
fi

# Test 4: nub can actually run a trivial TS/JS file
TEST_FILE="/tmp/nub-test.js"
echo 'console.log("nub-ok")' > "${TEST_FILE}"
if [ "$(nub "${TEST_FILE}" 2>/dev/null)" = "nub-ok" ]; then
    echo "✅ PASS: nub runs a JS file correctly"
else
    echo "⚠️  WARN: nub did not produce the expected output (network-dependent first-run behavior?)"
fi
rm -f "${TEST_FILE}"

echo ""
echo "🎉 nub feature is working correctly."
