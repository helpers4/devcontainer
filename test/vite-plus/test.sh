#!/bin/bash

# Test script for viteplus feature

set -e

# Source test framework
source dev-container-features-test-lib

# Feature-specific tests
check "viteplus-init helper exists" test -f /usr/local/bin/viteplus-init

check "viteplus-init is executable" test -x /usr/local/bin/viteplus-init

check "node is available" command -v node

check "npm is available" command -v npm

# Test that viteplus-init runs without error
check "viteplus-init helper works" bash -c 'cd /tmp && /usr/local/bin/viteplus-init 2>&1 | grep -q "package.json"'

# Check Oxc installation if enabled
if command -v oxc >/dev/null 2>&1; then
    check "oxc CLI is available" command -v oxc
    check "oxc version displays" oxc --version
else
    echo "⚠️  Oxc CLI not installed (installOxc=false)"
fi

reportResults
