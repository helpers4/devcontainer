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

# ── directories option ────────────────────────────────────────────────────────

mkdir -p /tmp/test-dirs-a /tmp/test-dirs-b

cat > /tmp/test-dirs-a/package.json << 'EOF'
{ "name": "dirs-a", "version": "1.0.0" }
EOF
cat > /tmp/test-dirs-b/package.json << 'EOF'
{ "name": "dirs-b", "version": "1.0.0" }
EOF

check "directories option discovers both dirs" bash -c \
    'DIRECTORIES=/tmp/test-dirs-a,/tmp/test-dirs-b /usr/local/bin/devcontainer-package-install 2>&1 | grep -c "\[/tmp/test-dirs" | grep -qE "^[2-9]"'

check "directories option takes precedence over workingDirectory" bash -c \
    'DIRECTORIES=/tmp/test-dirs-a WORKINGDIRECTORY=/nonexistent /usr/local/bin/devcontainer-package-install 2>&1 | grep -q "test-dirs-a"'

rm -rf /tmp/test-dirs-a /tmp/test-dirs-b

# ── autoDiscover option ───────────────────────────────────────────────────────

mkdir -p /workspaces/test-autodiscover/frontend /workspaces/test-autodiscover/backend

cat > /workspaces/test-autodiscover/test.code-workspace << 'EOF'
{
  "folders": [
    { "path": "frontend" },
    { "path": "backend" }
  ]
}
EOF
cat > /workspaces/test-autodiscover/frontend/package.json << 'EOF'
{ "name": "frontend", "version": "1.0.0" }
EOF
cat > /workspaces/test-autodiscover/backend/package.json << 'EOF'
{ "name": "backend", "version": "1.0.0" }
EOF

check "autoDiscover finds .code-workspace folders" bash -c \
    'AUTODISCOVER=true /usr/local/bin/devcontainer-package-install 2>&1 | grep -q "frontend"'

check "autoDiscover processes all workspace folders" bash -c \
    'AUTODISCOVER=true /usr/local/bin/devcontainer-package-install 2>&1 | grep -c "\[/workspaces" | grep -qE "^[2-9]"'

rm -rf /workspaces/test-autodiscover

reportResults
