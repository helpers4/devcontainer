#!/bin/bash
set -e

SCRIPT="/usr/local/share/claude-dev/setup-credentials.sh"

if [ ! -f "${SCRIPT}" ]; then
    echo "❌ FAIL: ${SCRIPT} is missing"
    exit 1
fi

if [ ! -x "${SCRIPT}" ]; then
    echo "❌ FAIL: ${SCRIPT} is not executable"
    exit 1
fi

if ! grep -q '^TARGET_HOME=' "${SCRIPT}"; then
    echo "❌ FAIL: TARGET_HOME not baked into ${SCRIPT}"
    exit 1
fi

echo "✅ PASS: setup-credentials.sh installed, executable, TARGET_HOME baked in"

# Actually run it — devcontainer features test mounts the real named volume
# (Docker creates it automatically, unlike a bind-mount), so this exercises
# the ownership-repair logic against the same root-owned-by-default volume a
# real container gets, not just a syntax check.
if ! "${SCRIPT}"; then
    echo "❌ FAIL: ${SCRIPT} exited non-zero"
    exit 1
fi

TARGET="${HOME}/.claude"
if [ ! -L "${TARGET}" ] || [ "$(readlink -f "${TARGET}")" != "/mnt/h4claude" ]; then
    echo "❌ FAIL: ${TARGET} is not a symlink to /mnt/h4claude"
    exit 1
fi

# The regression this guards against: a fresh named volume is root-owned by
# Docker, and a non-root user (this repo's usual "vscode"/"node" default)
# gets EACCES on every write under it unless setup-credentials.sh chowned it
# first. As root this write always succeeds regardless of the fix — the
# matrix entry testing this feature on a non-root base image is what
# actually exercises the regression.
if ! touch "${TARGET}/.write-test" 2>/dev/null; then
    echo "❌ FAIL: cannot write into ${TARGET} (uid $(id -u)) — the volume wasn't handed to this user"
    exit 1
fi
rm -f "${TARGET}/.write-test"

echo "✅ PASS: ~/.claude symlinked to the volume and writable as uid $(id -u)"
echo "🎉 Test passed."
