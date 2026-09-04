#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing cline-dev feature..."

# Default options leave installCli=false — the CLI must not be present.
if command -v cline >/dev/null 2>&1; then
    echo "❌ FAIL: cline CLI found but installCli defaults to false"
    exit 1
fi

echo "✅ PASS: cline CLI absent under default options, as expected"
echo "🎉 Test passed."
