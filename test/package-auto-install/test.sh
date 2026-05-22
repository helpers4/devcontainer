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

# Run installer once; capture both output and exit code so the checks can assert
# that the installer succeeded AND that each directory was actually processed.
_dirs_rc=0
_dirs_out="$(DIRECTORIES=/tmp/test-dirs-a,/tmp/test-dirs-b /usr/local/bin/devcontainer-package-install 2>&1)" \
    || _dirs_rc=$?
export _dirs_out _dirs_rc

check "directories option processes first dir" \
    bash -c 'printf "%s\n" "$_dirs_out" | grep -qF "[/tmp/test-dirs-a]"'

check "directories option processes second dir" \
    bash -c 'printf "%s\n" "$_dirs_out" | grep -qF "[/tmp/test-dirs-b]"'

check "directories option installer exits successfully" \
    bash -c '[ "$_dirs_rc" -eq 0 ]'

unset _dirs_out _dirs_rc

check "directories overrides workingDirectory" bash -c \
    'out=$(DIRECTORIES=/tmp/test-dirs-a WORKINGDIRECTORY=/nonexistent /usr/local/bin/devcontainer-package-install 2>&1) && printf "%s\n" "$out" | grep -qF "[/tmp/test-dirs-a]"'

rm -rf /tmp/test-dirs-a /tmp/test-dirs-b

# ── autoDiscover option ───────────────────────────────────────────────────────

# Use absolute paths in the .code-workspace to avoid resolution edge cases.
# Guard mkdir with a conditional so set -e does not abort the whole test
# if /workspaces is not writable (non-standard base images).
if mkdir -p /workspaces/test-autodiscover/frontend \
            /workspaces/test-autodiscover/backend 2>/dev/null; then

    cat > /workspaces/test-autodiscover/test.code-workspace << 'EOF'
{
  "folders": [
    { "path": "/workspaces/test-autodiscover/frontend" },
    { "path": "/workspaces/test-autodiscover/backend" }
  ]
}
EOF
    cat > /workspaces/test-autodiscover/frontend/package.json << 'EOF'
{ "name": "ws-frontend", "version": "1.0.0" }
EOF
    cat > /workspaces/test-autodiscover/backend/package.json << 'EOF'
{ "name": "ws-backend", "version": "1.0.0" }
EOF

    # Capture output and exit code once so both directory checks and the success
    # check all use the same run, and a failing installer cannot hide behind grep.
    _auto_rc=0
    _auto_out="$(AUTODISCOVER=true /usr/local/bin/devcontainer-package-install 2>&1)" \
        || _auto_rc=$?
    export _auto_out _auto_rc

    check "autoDiscover finds frontend folder" \
        bash -c '[ "$_auto_rc" -eq 0 ] && printf "%s\n" "$_auto_out" | grep -q "test-autodiscover/frontend"'

    check "autoDiscover finds backend folder" \
        bash -c '[ "$_auto_rc" -eq 0 ] && printf "%s\n" "$_auto_out" | grep -q "test-autodiscover/backend"'

    unset _auto_out _auto_rc

    rm -rf /workspaces/test-autodiscover
else
    echo "⚠️  /workspaces not writable — skipping autoDiscover tests"
fi

reportResults
