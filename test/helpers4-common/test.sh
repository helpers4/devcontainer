#!/bin/bash
# Copyright (C) 2025 baxyz — LGPL-3.0-or-later
set -e

echo "Testing helpers4-common feature..."

COMMON_SH="/usr/local/share/helpers4/common.sh"

# Test 1: common.sh exists and is readable
if [ -r "${COMMON_SH}" ]; then
    echo "✅ PASS: ${COMMON_SH} exists and is readable"
else
    echo "❌ FAIL: ${COMMON_SH} not found"
    exit 1
fi

# Test 2: common.sh exports the expected functions
# shellcheck source=/dev/null
. "${COMMON_SH}"
for fn in h4_detect_user h4_resolve_home h4_apt_update h4_ensure_packages; do
    if declare -f "${fn}" >/dev/null 2>&1; then
        echo "✅ PASS: function ${fn} defined"
    else
        echo "❌ FAIL: function ${fn} not defined after sourcing common.sh"
        exit 1
    fi
done

# Test 4: h4_detect_user resolves a non-empty USERNAME
h4_detect_user
if [ -n "${USERNAME}" ]; then
    echo "✅ PASS: h4_detect_user → USERNAME=${USERNAME}"
else
    echo "❌ FAIL: h4_detect_user returned empty USERNAME"
    exit 1
fi

# Test 5: h4_resolve_home resolves a non-empty USER_HOME
h4_resolve_home
if [ -n "${USER_HOME}" ]; then
    echo "✅ PASS: h4_resolve_home → USER_HOME=${USER_HOME}"
else
    echo "❌ FAIL: h4_resolve_home returned empty USER_HOME"
    exit 1
fi

echo ""
echo "🎉 helpers4-common tests passed."
