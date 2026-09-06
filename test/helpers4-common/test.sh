#!/bin/bash
# Copyright (C) 2025 baxyz — LGPL-3.0-or-later
set -e

echo "Testing helpers4-common feature..."

COMMON_SH="/usr/local/share/helpers4/common.sh"

# Test 1: common.sh exists and is readable
if [ -r "${COMMON_SH}" ]; then
    echo "✅ PASS: ${COMMON_SH} exists and is readable"
else
    echo "❌ FAIL: ${COMMON_SH} not found"
    exit 1
fi

# Test 2: common.sh exports the expected functions
# shellcheck source=/dev/null
. "${COMMON_SH}"
for fn in h4_detect_user h4_resolve_home h4_apt_update h4_ensure_packages; do
    if declare -f "${fn}" >/dev/null 2>&1; then
        echo "✅ PASS: function ${fn} defined"
    else
        echo "❌ FAIL: function ${fn} not defined after sourcing common.sh"
        exit 1
    fi
done

# Test 4: h4_detect_user resolves a non-empty USERNAME
h4_detect_user
if [ -n "${USERNAME}" ]; then
    echo "✅ PASS: h4_detect_user → USERNAME=${USERNAME}"
else
    echo "❌ FAIL: h4_detect_user returned empty USERNAME"
    exit 1
fi

# Test 5: h4_resolve_home resolves a non-empty USER_HOME
h4_resolve_home
if [ -n "${USER_HOME}" ]; then
    echo "✅ PASS: h4_resolve_home → USER_HOME=${USER_HOME}"
else
    echo "❌ FAIL: h4_resolve_home returned empty USER_HOME"
    exit 1
fi

# Test 6: h4_detect_cloud_env is defined and sets IS_CLOUD_ENV/ENV_LABEL
if declare -f h4_detect_cloud_env >/dev/null 2>&1; then
    echo "✅ PASS: function h4_detect_cloud_env defined"
else
    echo "❌ FAIL: function h4_detect_cloud_env not defined after sourcing common.sh"
    exit 1
fi
h4_detect_cloud_env
if [ -n "${IS_CLOUD_ENV}" ] && [ -n "${ENV_LABEL}" ]; then
    echo "✅ PASS: h4_detect_cloud_env → IS_CLOUD_ENV=${IS_CLOUD_ENV} ENV_LABEL=${ENV_LABEL}"
else
    echo "❌ FAIL: h4_detect_cloud_env left IS_CLOUD_ENV/ENV_LABEL unset"
    exit 1
fi

# Test 7: git-config-self-heal.sh installed and executable
SELF_HEAL="/usr/local/share/helpers4/git-config-self-heal.sh"
if [ -x "${SELF_HEAL}" ]; then
    echo "✅ PASS: ${SELF_HEAL} installed and executable"
else
    echo "❌ FAIL: ${SELF_HEAL} not found or not executable"
    exit 1
fi

# Test 8: self-heal end-to-end — a credential.helper shelling out to an
# absolute path that doesn't resolve gets rewritten to the bare command name
# once a same-named binary is found on $PATH; a value that isn't an absolute
# path (already bare, or a relative/other-shaped command) is left untouched.
# Needs git, which a minimal base image (e.g. plain ubuntu:latest) may not
# have preinstalled — same as essential-dev, ensure it via h4_ensure_packages
# rather than assuming.
command -v git >/dev/null 2>&1 || h4_ensure_packages git

TEST_HOME=$(mktemp -d)
TEST_BIN="${TEST_HOME}/bin"
mkdir -p "${TEST_BIN}"
printf '#!/bin/sh\ntrue\n' > "${TEST_BIN}/fakegh"
chmod +x "${TEST_BIN}/fakegh"

git config --file "${TEST_HOME}/.gitconfig" credential.helper "!/does/not/exist/fakegh auth git-credential"
git config --file "${TEST_HOME}/.gitconfig" core.editor "code --wait"

HOME="${TEST_HOME}" PATH="${TEST_BIN}:${PATH}" "${SELF_HEAL}" >/tmp/self-heal-test8.log 2>&1

if git config --file "${TEST_HOME}/.gitconfig" --get credential.helper | grep -qF "!fakegh auth git-credential"; then
    echo "✅ PASS: self-heal rewrote a stale absolute-path credential.helper to the \$PATH-resolved bare command"
else
    echo "❌ FAIL: self-heal did not rewrite the stale credential.helper"
    cat /tmp/self-heal-test8.log
    rm -rf "${TEST_HOME}"
    exit 1
fi

if git config --file "${TEST_HOME}/.gitconfig" --get core.editor | grep -qF "code --wait"; then
    echo "✅ PASS: self-heal left a non-absolute-path command (core.editor) untouched"
else
    echo "❌ FAIL: self-heal incorrectly modified a non-absolute-path core.editor value"
    rm -rf "${TEST_HOME}"
    exit 1
fi
rm -rf "${TEST_HOME}"

echo ""
echo "🎉 helpers4-common tests passed."
