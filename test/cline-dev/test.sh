#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing cline-dev feature..."

# Default options leave installCli=false — the CLI must not be present.
if command -v cline >/dev/null 2>&1; then
    echo "❌ FAIL: cline CLI found but installCli defaults to false"
    exit 1
fi

echo "✅ PASS: cline CLI absent under default options, as expected"

SCRIPT="/usr/local/share/cline-dev/setup-credentials.sh"

if [ ! -x "${SCRIPT}" ]; then
    echo "❌ FAIL: ${SCRIPT} is missing or not executable"
    exit 1
fi

if ! grep -q '^TARGET_HOME=' "${SCRIPT}"; then
    echo "❌ FAIL: TARGET_HOME not baked into ${SCRIPT}"
    exit 1
fi

echo "✅ PASS: setup-credentials.sh installed, executable, TARGET_HOME baked in"

# test.sh may run as a different user than the one cline-dev resolved (root on
# plain ubuntu:latest) — read the TARGET_HOME the script baked in rather than
# assuming it matches test.sh's own $HOME.
eval "$(grep '^TARGET_HOME=' "${SCRIPT}")"
TARGET="${TARGET_HOME}/.cline"

if [ ! -L "${TARGET}" ] || [ "$(readlink -f "${TARGET}")" != "/mnt/h4cline" ]; then
    echo "❌ FAIL: ${TARGET} is not a symlink to /mnt/h4cline"
    exit 1
fi

echo "✅ PASS: ${TARGET} symlinked to the volume"

if ! grep -qs ' /mnt/h4cline ' /proc/mounts; then
    echo "❌ FAIL: /mnt/h4cline is not a mounted volume"
    exit 1
fi

echo "✅ PASS: /mnt/h4cline is a mounted volume"

# Root can always write regardless of ownership, so this is only meaningful
# when test.sh runs as the non-root user cline-dev resolved.
if [ "$(id -u)" != "0" ]; then
    if ! mkdir -p "${TARGET}/data" || ! touch "${TARGET}/data/.write-test" 2>/dev/null; then
        echo "❌ FAIL: cannot write into ${TARGET} (uid $(id -u)) — the volume wasn't handed to this user"
        exit 1
    fi
    rm -f "${TARGET}/data/.write-test"
    echo "✅ PASS: ${TARGET} writable as uid $(id -u)"
fi

echo "🎉 Test passed."
