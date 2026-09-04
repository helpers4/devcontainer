#!/bin/bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing bitwarden-secrets-manager feature..."

if command -v bws >/dev/null 2>&1; then
    echo "✅ PASS: bws is installed and accessible"
    bws --version
else
    echo "❌ FAIL: bws is not installed or not accessible"
    exit 1
fi

if [ -x "/usr/local/bin/bws" ]; then
    echo "✅ PASS: bws is installed in /usr/local/bin/"
else
    echo "❌ FAIL: bws is not in expected location /usr/local/bin/"
    exit 1
fi

if ! bws --version >/dev/null 2>&1; then
    echo "❌ FAIL: bws --version failed"
    exit 1
fi
echo "✅ PASS: bws --version runs successfully"

echo "🎉 Test passed."
