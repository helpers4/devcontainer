#!/bin/bash

# Test script for peon-ping feature
# Copyright (c) 2025 helpers4
# Licensed under AGPL-3.0 - see LICENSE file for details

set -e

echo "Testing peon-ping feature..."

# Test 1: Check if peon binary is accessible
if command -v peon >/dev/null 2>&1; then
    echo "✅ PASS: peon binary is accessible"
else
    # Check common install location directly
    PEON_BIN="${HOME}/.local/bin/peon"
    if [ -x "${PEON_BIN}" ]; then
        echo "✅ PASS: peon binary found at ${PEON_BIN}"
    else
        echo "❌ FAIL: peon binary not found"
        exit 1
    fi
fi

# Test 2: Check peon-ping runtime directory
PEON_DIR="${HOME}/.claude/hooks/peon-ping"
if [ -d "${PEON_DIR}" ]; then
    echo "✅ PASS: peon-ping runtime directory exists at ${PEON_DIR}"
else
    echo "❌ FAIL: peon-ping runtime directory not found at ${PEON_DIR}"
    exit 1
fi

# Test 3: Check config.json exists
PEON_CONFIG="${PEON_DIR}/config.json"
if [ -f "${PEON_CONFIG}" ]; then
    echo "✅ PASS: config.json exists"
else
    echo "❌ FAIL: config.json not found at ${PEON_CONFIG}"
    exit 1
fi

# Test 4: Check that adapters directory exists
ADAPTERS_DIR="${PEON_DIR}/adapters"
if [ -d "${ADAPTERS_DIR}" ]; then
    echo "✅ PASS: adapters directory exists"
else
    echo "⚠️  WARN: adapters directory not found at ${ADAPTERS_DIR}"
fi

# Test 5: Check copilot adapter is available
if [ -f "${ADAPTERS_DIR}/copilot.sh" ]; then
    echo "✅ PASS: copilot adapter found"
else
    echo "⚠️  WARN: copilot adapter not found"
fi

# Test 6: Check peon-ping-copilot-setup helper is installed
if [ -x /usr/local/bin/peon-ping-copilot-setup ]; then
    echo "✅ PASS: peon-ping-copilot-setup helper installed"
else
    echo "⚠️  WARN: peon-ping-copilot-setup helper not found"
fi

# Test 7: Check that python3 is available (required dependency)
if command -v python3 >/dev/null 2>&1; then
    echo "✅ PASS: python3 is available"
else
    echo "❌ FAIL: python3 is not available"
    exit 1
fi

echo ""
echo "✅ All peon-ping feature tests passed!"
