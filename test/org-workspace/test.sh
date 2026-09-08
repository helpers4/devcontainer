#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing org-workspace feature..."

# Test 1: clone-repos.sh installed and executable
CLONE_SCRIPT="/usr/local/share/org-workspace/clone-repos.sh"
if [ -x "${CLONE_SCRIPT}" ]; then
    echo "✅ PASS: ${CLONE_SCRIPT} installed and executable"
else
    echo "❌ FAIL: ${CLONE_SCRIPT} not found or not executable"
    exit 1
fi

# Test 2: the generated script has valid bash syntax
if bash -n "${CLONE_SCRIPT}"; then
    echo "✅ PASS: ${CLONE_SCRIPT} has valid bash syntax"
else
    echo "❌ FAIL: ${CLONE_SCRIPT} has a bash syntax error"
    exit 1
fi

# Test 3: jq is available (needed by clone-repos.sh to write/merge the .code-workspace file)
if command -v jq >/dev/null 2>&1; then
    echo "✅ PASS: jq is available"
else
    echo "❌ FAIL: jq is not available"
    exit 1
fi

# Test 4: the option values this run was configured with are baked into the generated script
# (a spot check, not exhaustive — confirms the printf %q header actually ran).
if grep -q '^ORG_OPTION=' "${CLONE_SCRIPT}" && grep -q '^AUTO_DISCOVER_OPTION=' "${CLONE_SCRIPT}"; then
    echo "✅ PASS: option values baked into ${CLONE_SCRIPT}"
else
    echo "❌ FAIL: ${CLONE_SCRIPT} is missing its baked-in option header"
    exit 1
fi

echo ""
echo "✅ All org-workspace feature tests passed!"
