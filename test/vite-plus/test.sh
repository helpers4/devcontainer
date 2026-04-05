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
# vp is required by default (installVitePlus=true), so this must pass
check "vp CLI is available" command -v vp
check "vp version displays" vp --version

# Check standalone Vite CLI (optional, not needed with vp)
if command -v vite >/dev/null 2>&1; then
    check "vite CLI is available" command -v vite
fi

# Check standalone Vitest CLI (optional, not needed with vp)
if command -v vitest >/dev/null 2>&1; then
    check "vitest CLI is available" command -v vitest
fi

reportResults
