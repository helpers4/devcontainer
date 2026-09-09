#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2026 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Exercises installCli:true — the default-off code path plain test.sh never
# runs. install.sh's uv branch in particular trusts `uv tool install`
# without verifying the binary actually landed afterward — assert it here
# rather than leaving that path unverified.

set -e

echo "Testing mistral-dev with installCli:true..."

if ! command -v vibe >/dev/null 2>&1; then
    echo "❌ FAIL: vibe CLI not found — installCli:true did not install it"
    exit 1
fi
echo "✅ PASS: vibe CLI on PATH"

if ! vibe --version >/dev/null 2>&1; then
    echo "❌ FAIL: vibe is on PATH but does not run"
    exit 1
fi
echo "✅ PASS: vibe --version runs"

echo "🎉 Test passed."
