#!/usr/bin/env bash

# Test script for essential-dev feature

set -e

echo "🧪 Testing essential-dev feature..."

# The only real, build-time artifact this feature writes to disk — the VS
# Code extensions/settings in its manifest are applied by the devcontainer
# CLI itself, not by install.sh, so there's nothing else on the filesystem
# to assert here.
FIXUP="$(git config --system --get alias.fixup || true)"
if [ "${FIXUP}" != "commit --fixup" ]; then
    echo "❌ FAIL: git alias.fixup is '${FIXUP}', expected 'commit --fixup'"
    exit 1
fi
echo "✅ PASS: git alias.fixup configured"

POLISH="$(git config --system --get alias.polish || true)"
if [ "${POLISH}" != "rebase -i --autosquash origin/HEAD" ]; then
    echo "❌ FAIL: git alias.polish is '${POLISH}', expected 'rebase -i --autosquash origin/HEAD'"
    exit 1
fi
echo "✅ PASS: git alias.polish configured"

echo "✅ essential-dev tests passed"
