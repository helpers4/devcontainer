#!/bin/bash

# Test script for github-dev feature
# Copyright (c) 2025 helpers4
# Licensed under LGPL-3.0 - see LICENSE file for details

set -e

echo "Testing github-dev feature..."

# Test 1: gh CLI is installed and executable
if command -v gh >/dev/null 2>&1; then
    GH_VER="$(gh --version | head -1)"
    echo "PASS: gh CLI installed: ${GH_VER}"
else
    echo "FAIL: gh CLI not found"
    exit 1
fi

# Test 2: gh is in /usr/local/bin
if [ -x /usr/local/bin/gh ]; then
    echo "PASS: gh installed at /usr/local/bin/gh"
else
    echo "FAIL: gh not found at /usr/local/bin/gh"
    exit 1
fi

# Test 3: gh version is parseable (basic sanity)
GH_VERSION_NUM="$(gh --version | head -1 | awk '{print $3}')"
if [ -n "${GH_VERSION_NUM}" ]; then
    echo "PASS: gh version parseable: ${GH_VERSION_NUM}"
else
    echo "WARN: could not parse gh version number"
fi

# Test 4: gh-auth.sh profile.d script is installed
if [ -f /etc/profile.d/gh-auth.sh ]; then
    echo "PASS: /etc/profile.d/gh-auth.sh present"
else
    echo "FAIL: /etc/profile.d/gh-auth.sh not found"
    exit 1
fi

# Test 5: gh-auth.sh is readable (not executable — it is sourced)
if [ -r /etc/profile.d/gh-auth.sh ]; then
    echo "PASS: /etc/profile.d/gh-auth.sh is readable"
else
    echo "FAIL: /etc/profile.d/gh-auth.sh is not readable"
    exit 1
fi

echo ""
echo "github-dev feature test complete!"
