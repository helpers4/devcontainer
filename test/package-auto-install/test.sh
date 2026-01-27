#!/bin/bash

# Test script for package-auto-install feature

set -e

# Source test framework
source dev-container-features-test-lib

# Feature-specific tests
check "CI environment variable is set" bash -c 'echo $CI | grep -q "true"'

check "installation script exists" test -f /usr/local/bin/devcontainer-package-install

check "installation script is executable" test -x /usr/local/bin/devcontainer-package-install

# Create a test package.json
mkdir -p /tmp/test-package
cd /tmp/test-package

cat > package.json << 'EOF'
{
  "name": "test-package",
  "version": "1.0.0",
  "dependencies": {
    "lodash": "^4.17.21"
  }
}
EOF

# Test npm detection (create package-lock.json)
check "npm package manager detection" bash -c 'WORKINGDIRECTORY=/tmp/test-package PACKAGEMANAGER=auto /usr/local/bin/devcontainer-package-install 2>&1 | grep -q "npm"'

# Clean up
rm -rf /tmp/test-package/node_modules /tmp/test-package/package-lock.json

# Test pnpm detection
cat > pnpm-lock.yaml << 'EOF'
lockfileVersion: '6.0'
EOF

if command -v pnpm >/dev/null 2>&1; then
    check "pnpm package manager detection" bash -c 'WORKINGDIRECTORY=/tmp/test-package PACKAGEMANAGER=auto /usr/local/bin/devcontainer-package-install 2>&1 | grep -q "pnpm"'
else
    echo "⚠️  pnpm not available, skipping pnpm tests"
fi

# Clean up
cd /
rm -rf /tmp/test-package

reportResults
