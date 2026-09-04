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

# devcontainer features test already ran postStartCommand (this script) as
# the feature's resolved target user before test.sh started — don't re-run
# it here, since test.sh itself may run as a different user (root on plain
# ubuntu:latest, even though claude-dev resolved a non-root "ubuntu" user
# for its own postStartCommand). Read the same TARGET_HOME the script
# baked in and already used, rather than assuming it matches test.sh's own
# $HOME.
eval "$(grep '^TARGET_HOME=' "${SCRIPT}")"
TARGET="${TARGET_HOME}/.claude"

if [ ! -L "${TARGET}" ] || [ "$(readlink -f "${TARGET}")" != "/mnt/h4claude" ]; then
    echo "❌ FAIL: ${TARGET} is not a symlink to /mnt/h4claude"
    exit 1
fi

echo "✅ PASS: ${TARGET} symlinked to the volume"

# The regression this guards against: a fresh named volume is root-owned by
# Docker, and a non-root user (this repo's usual "vscode"/"node" default)
# gets EACCES on every write under it unless setup-credentials.sh chowned it
# first. Root can always write regardless of ownership, so this check is
# only meaningful when test.sh is itself running as the same non-root user
# claude-dev resolved (true on the mcr.microsoft.com/devcontainers/base:ubuntu
# matrix entry) — skip it otherwise rather than pass trivially.
if [ "$(id -u)" != "0" ]; then
    if ! touch "${TARGET}/.write-test" 2>/dev/null; then
        echo "❌ FAIL: cannot write into ${TARGET} (uid $(id -u)) — the volume wasn't handed to this user"
        exit 1
    fi
    rm -f "${TARGET}/.write-test"
    echo "✅ PASS: ${TARGET} writable as uid $(id -u)"
fi

echo "🎉 Test passed."
