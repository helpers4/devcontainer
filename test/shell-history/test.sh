#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing shell-history feature..."

STAGED="/mnt/h4history"
SCRIPT="/usr/local/share/shell-history/setup-volume.sh"

if [ ! -x "${SCRIPT}" ]; then
    echo "❌ FAIL: ${SCRIPT} is missing or not executable"
    exit 1
fi
echo "✅ PASS: setup-volume.sh installed"

if ! grep -qs " ${STAGED} " /proc/mounts; then
    echo "❌ FAIL: ${STAGED} is not a mounted volume"
    exit 1
fi
echo "✅ PASS: ${STAGED} is a mounted volume"

PERMISSIONS="$(stat -c '%a' "${STAGED}")"
if [ "${PERMISSIONS}" != "700" ]; then
    echo "❌ FAIL: ${STAGED} has mode ${PERMISSIONS}, expected 700 (history can hold secrets)"
    exit 1
fi
echo "✅ PASS: ${STAGED} is private (700)"

# test.sh may run as root while the feature configured a non-root user — find
# that user from the volume's owner rather than assuming test.sh's own $HOME.
OWNER="$(stat -c '%U' "${STAGED}")"
OWNER_HOME="$(getent passwd "${OWNER}" | cut -d: -f6)"

check_shell() {
    local shell="$1" rc_file="$2" history_file="$3"
    command -v "${shell}" >/dev/null 2>&1 || return 0

    local count
    count="$(grep -c '^# >>> helpers4 shell-history >>>$' "${OWNER_HOME}/${rc_file}" || true)"
    if [ "${count}" != "1" ]; then
        echo "❌ FAIL: ${rc_file} holds ${count} shell-history blocks, expected exactly 1"
        exit 1
    fi
    echo "✅ PASS: ${rc_file} holds one shell-history block"

    if [ "$(readlink -f "${OWNER_HOME}/.${shell}_history")" != "${STAGED}/${history_file}" ]; then
        echo "❌ FAIL: ~/.${shell}_history does not point to ${STAGED}/${history_file}"
        exit 1
    fi
    echo "✅ PASS: ~/.${shell}_history points to the volume"
}

check_shell bash .bashrc bash_history
check_shell zsh .zshrc zsh_history

# The setting that actually matters: what an interactive shell of that user
# ends up with, after the distro's own rc defaults ran.
run_as_owner() {
    if [ "$(id -un)" = "${OWNER}" ]; then
        "$@"
    else
        su "${OWNER}" -s /bin/bash -c "$(printf '%q ' "$@")"
    fi
}

if command -v bash >/dev/null 2>&1; then
    # shellcheck disable=SC2016 # expanded by the shell under test, not this one
    RESULT="$(run_as_owner bash -ic 'echo "${HISTFILE}|${HISTFILESIZE}|${PROMPT_COMMAND}"' 2>/dev/null | tail -n 1)"
    case "${RESULT}" in
        "${STAGED}/bash_history|10000|"*"history -a"*) echo "✅ PASS: interactive bash uses the volume (${RESULT%%|*})" ;;
        *) echo "❌ FAIL: interactive bash got HISTFILE|HISTFILESIZE|PROMPT_COMMAND = '${RESULT}'"; exit 1 ;;
    esac

    # Commands passed with -c never reach history — feed them on stdin instead.
    echo 'echo helpers4-history-probe' | run_as_owner bash -i >/dev/null 2>&1 || true
    if ! grep -q 'helpers4-history-probe' "${STAGED}/bash_history"; then
        echo "❌ FAIL: a command run in bash did not reach ${STAGED}/bash_history"
        exit 1
    fi
    echo "✅ PASS: bash history written to the volume"
fi

if command -v zsh >/dev/null 2>&1; then
    # shellcheck disable=SC2016 # expanded by the shell under test, not this one
    RESULT="$(run_as_owner zsh -ic 'echo "${HISTFILE}"' 2>/dev/null | tail -n 1)"
    if [ "${RESULT}" != "${STAGED}/zsh_history" ]; then
        echo "❌ FAIL: interactive zsh got HISTFILE='${RESULT}'"
        exit 1
    fi
    echo "✅ PASS: interactive zsh uses the volume"
fi

echo "🎉 Test passed."
