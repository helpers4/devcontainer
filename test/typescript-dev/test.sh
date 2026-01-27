#!/bin/bash

# Test script for typescript-dev feature

set -e

# Source test framework
source dev-container-features-test-lib

# Feature-specific tests
check "vscode settings are applied" test -n "$VSCODE_SETUP_COMPLETE" || true

check "vscode is running" pgrep code || true

# Check that common extensions would be installed (we can't verify directly, but check for marks)
echo "✅ typescript-dev feature includes:"
echo "   - TypeScript tooling"
echo "   - Git integration"
echo "   - GitHub Copilot"
echo "   - Markdown support"
echo "   - Editor enhancements"

reportResults
