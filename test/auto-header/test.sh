#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Test the auto-header feature: it should write valid psi-header.* settings
# directly into the remote user's Machine settings.json.

set -e

echo "🧪 Testing auto-header feature..."

# ---------------------------------------------------------------------------
# 1. Raw config persisted by the installer
# ---------------------------------------------------------------------------
CONFIG_FILE="/etc/h4-auto-header/config.json"
echo ""
echo "Test 1: configuration file"
if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ $CONFIG_FILE not found"
    exit 1
fi
if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
    echo "❌ $CONFIG_FILE is not valid JSON"
    exit 1
fi
for key in headerType projectName license sinceYear; do
    if ! jq -e ".$key" "$CONFIG_FILE" >/dev/null; then
        echo "❌ Key '$key' missing from $CONFIG_FILE"
        exit 1
    fi
done
echo "✅ Configuration file present and valid"

# ---------------------------------------------------------------------------
# 2. Machine settings written by the installer
# ---------------------------------------------------------------------------
TARGET_USER="${_REMOTE_USER:-${REMOTE_USER:-node}}"
if PASSWD_ENTRY=$(getent passwd "$TARGET_USER" 2>/dev/null); then
    TARGET_HOME=$(printf '%s\n' "$PASSWD_ENTRY" | cut -d: -f6)
fi
[ -z "${TARGET_HOME:-}" ] && TARGET_HOME="/home/$TARGET_USER"
MACHINE_FILE="$TARGET_HOME/.vscode-server/data/Machine/settings.json"

echo ""
echo "Test 2: Machine settings.json"
if [ ! -f "$MACHINE_FILE" ]; then
    echo "❌ $MACHINE_FILE not created by installer"
    exit 1
fi
if ! jq empty "$MACHINE_FILE" 2>/dev/null; then
    echo "❌ $MACHINE_FILE is not valid JSON"
    cat "$MACHINE_FILE"
    exit 1
fi
echo "✅ Machine settings file is valid JSON"

# ---------------------------------------------------------------------------
# 3. psi-header.* keys present and substituted with real values
# ---------------------------------------------------------------------------
echo ""
echo "Test 3: psi-header keys"
for key in "psi-header.config" "psi-header.templates" "psi-header.changes-tracking" "psi-header.lang-config"; do
    if ! jq -e ".[\"$key\"]" "$MACHINE_FILE" >/dev/null; then
        echo "❌ Missing key: $key"
        exit 1
    fi
done
echo "✅ All psi-header.* keys present"

if grep -q '<<' "$MACHINE_FILE"; then
    echo "❌ Found '<<' placeholders in generated file (should be real values):"
    grep '<<' "$MACHINE_FILE"
    exit 1
fi
echo "✅ No '<<' placeholders — real values used"

AUTHOR=$(jq -r '.["psi-header.config"].author' "$MACHINE_FILE")
[ -n "$AUTHOR" ] && [ "$AUTHOR" != "null" ] || { echo "❌ author missing"; exit 1; }
echo "✅ Real author value: $AUTHOR"

if ! jq -e '.["psi-header.templates"][0].template[1] | test("Copyright \\(C\\) [0-9]")' "$MACHINE_FILE" >/dev/null; then
    echo "❌ Copyright line in templates does not contain a year"
    exit 1
fi
echo "✅ Copyright year present in templates"

if ! jq -e '.["psi-header.templates"][0].template[2] | test("SPDX-License-Identifier: [A-Za-z0-9.+-]+")' "$MACHINE_FILE" >/dev/null; then
    echo "❌ SPDX license identifier missing"
    exit 1
fi
echo "✅ SPDX license identifier present"

echo ""
echo "✅ All tests passed!"
echo ""
echo "📋 Summary:"
echo "   - Config persisted at $CONFIG_FILE"
echo "   - psi-header.* settings written to $MACHINE_FILE"
echo "   - Real values used (no '<<' placeholders)"
echo "   - Settings active for any workspace opened in this container"
