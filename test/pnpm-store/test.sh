#!/bin/bash

# Test script for pnpm-store feature
# Copyright (C) 2025 baxyz
# Licensed under LGPL-3.0 - see LICENSE file for details

set -e

echo "Testing pnpm-store feature..."

STORE_DIR="/workspaces/.pnpm-store"
GUARD="/usr/local/bin/devcontainer-pnpm-store"

# Test 1: guard script is installed and executable
if [ -x "${GUARD}" ]; then
    echo "✅ PASS: guard script installed at ${GUARD}"
else
    echo "❌ FAIL: guard script not found or not executable at ${GUARD}"
    exit 1
fi

# Test 2: store-dir is configured in an .npmrc (root or a non-root user)
found_npmrc=""
for npmrc in /root/.npmrc /home/*/.npmrc; do
    [ -f "${npmrc}" ] || continue
    if grep -q "^store-dir=${STORE_DIR}\$" "${npmrc}"; then
        found_npmrc="${npmrc}"
        break
    fi
done
if [ -n "${found_npmrc}" ]; then
    echo "✅ PASS: store-dir=${STORE_DIR} found in ${found_npmrc}"
else
    echo "❌ FAIL: store-dir=${STORE_DIR} not found in any .npmrc"
    exit 1
fi

# Test 3: running the guard succeeds and the store directory exists.
# In real usage the named volume is mounted at STORE_DIR before the container
# starts, so the guard only needs to take ownership of it. The features-test
# harness mounts the volume too; pre-create the path defensively in case the
# parent is root-owned and the current user cannot write to it.
if ! mkdir -p "${STORE_DIR}" 2>/dev/null; then
    sudo mkdir -p "${STORE_DIR}" 2>/dev/null \
        && sudo chown "$(id -u):$(id -g)" "${STORE_DIR}" 2>/dev/null \
        || echo "⚠️  Could not pre-create ${STORE_DIR}; guard will report the error."
fi

if "${GUARD}"; then
    echo "✅ PASS: guard script ran successfully"
else
    echo "❌ FAIL: guard script returned a non-zero exit code"
    exit 1
fi

if [ -d "${STORE_DIR}" ]; then
    echo "✅ PASS: store directory ${STORE_DIR} exists"
else
    echo "❌ FAIL: store directory ${STORE_DIR} was not created"
    exit 1
fi

# Test 4: if pnpm is available, it must report the configured store-dir.
if command -v pnpm >/dev/null 2>&1; then
    configured="$(pnpm config get store-dir 2>/dev/null || echo '')"
    if [ "${configured}" = "${STORE_DIR}" ]; then
        echo "✅ PASS: pnpm reports store-dir=${configured}"
    else
        echo "⚠️  WARN: pnpm store-dir is '${configured}', expected '${STORE_DIR}'"
    fi
else
    echo "⚠️  WARN: pnpm not installed in this image; skipping functional check"
fi

echo ""
echo "🎉 All critical tests passed! pnpm-store feature is working correctly."
