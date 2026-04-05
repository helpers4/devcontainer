#!/bin/bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

# Test script for vite-plus feature

set -e

# Source test framework
source dev-container-features-test-lib

# Feature-specific tests
check "node is available" command -v node

check "npm is available" command -v npm

# Check vp (Vite+ unified CLI) installation
if command -v vp >/dev/null 2>&1; then
    check "vp CLI is available" command -v vp
    check "vp version displays" vp --version
elif [ -f "${HOME}/.vite-plus/bin/vp" ]; then
    check "vp binary exists in ~/.vite-plus/bin" test -f "${HOME}/.vite-plus/bin/vp"
else
    echo "⚠️  vp CLI not found (installVitePlus=false or installer path not in PATH)"
fi

# Check standalone Vite CLI (optional, not needed with vp)
if command -v vite >/dev/null 2>&1; then
    check "vite CLI is available" command -v vite
fi

# Check standalone Vitest CLI (optional, not needed with vp)
if command -v vitest >/dev/null 2>&1; then
    check "vitest CLI is available" command -v vitest
fi

reportResults
