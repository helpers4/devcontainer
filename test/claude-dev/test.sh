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
echo "🎉 Test passed."
