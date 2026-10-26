#!/bin/bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing graphite-dev feature..."

if command -v gt >/dev/null 2>&1; then
    echo "✅ PASS: gt is installed and accessible"
else
    echo "❌ FAIL: gt is not installed or not accessible"
    exit 1
fi

if ! gt --version >/dev/null 2>&1; then
    echo "❌ FAIL: gt --version failed"
    exit 1
fi
echo "✅ PASS: gt --version runs successfully"

AUTH=/usr/local/share/graphite-dev/auth.sh
if [ -x "${AUTH}" ]; then
    echo "✅ PASS: ${AUTH} is installed"
else
    echo "❌ FAIL: ${AUTH} missing or not executable"
    exit 1
fi

# Without a token the auth script must be a harmless no-op, not a failure.
if env -u GRAPHITE_TOKEN "${AUTH}" | grep -q "GRAPHITE_TOKEN not set"; then
    echo "✅ PASS: auth.sh skips cleanly without a token"
else
    echo "❌ FAIL: auth.sh did not report a missing token"
    exit 1
fi

# A bogus token must warn but never fail (would otherwise block container start).
if GRAPHITE_TOKEN=invalid-test-token "${AUTH}" >/dev/null 2>&1; then
    echo "✅ PASS: auth.sh does not fail on a rejected token"
else
    echo "❌ FAIL: auth.sh exited non-zero on a rejected token"
    exit 1
fi

echo "🎉 Test passed."
