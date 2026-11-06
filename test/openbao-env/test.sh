#!/bin/bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Default options: installCli true, no paths, no address. Checks the install and that
# every entry point degrades cleanly when there is no server.

set -e

fail() { echo "❌ FAIL: $*"; exit 1; }
pass() { echo "✅ PASS: $*"; }

echo "Testing openbao-env feature (defaults)..."

[ -r /usr/local/share/openbao-env/loader.sh ] || fail "loader missing"
pass "loader installed"
[ -x /usr/local/bin/openbao-env ] || fail "openbao-env CLI missing"
pass "openbao-env CLI installed"
grep -q 'loader.sh' /etc/profile.d/openbao-env.sh || fail "profile.d hook missing"
pass "profile.d hook"
grep -q 'helpers4 openbao-env' /etc/bash.bashrc || fail "/etc/bash.bashrc hook missing"
pass "bash.bashrc hook"
if [ -f /etc/zsh/zshrc ]; then
    grep -q 'helpers4 openbao-env' /etc/zsh/zshrc || fail "/etc/zsh/zshrc hook missing"
    pass "zshrc hook"
fi

command -v bao > /dev/null || fail "bao CLI missing (installCli defaults to true)"
bao version > /dev/null || fail "bao version failed"
pass "bao CLI runs: $(bao version)"

command -v jq > /dev/null && command -v curl > /dev/null || fail "curl/jq missing"
pass "curl + jq present"

# The loader is POSIX sh: dash must parse it.
sh -n /usr/local/share/openbao-env/loader.sh || fail "loader is not valid POSIX sh"
pass "loader parses with sh"

openbao-env status > /dev/null || fail "openbao-env status failed with nothing configured"
pass "openbao-env status works unconfigured"
openbao-env check || fail "openbao-env check failed"
pass "openbao-env check exits 0"

# Configured, but the server doesn't answer: refresh fails cleanly, never echoes the token.
out="$(BAO_ADDR=http://127.0.0.1:9 OPENBAO_PATHS=orgs/x BAO_TOKEN=tok-must-not-leak \
    timeout 20 openbao-env refresh 2>&1)" && fail "refresh succeeded without a server"
case "${out}" in *tok-must-not-leak*) fail "refresh printed the token" ;; esac
case "${out}" in *"no answer"*) ;; *) fail "refresh error doesn't name the cause: ${out}" ;; esac
pass "refresh fails cleanly without a server"

# A login shell with the same setup: must not block, must not die, must not leak options.
start=$(date +%s)
out="$(BAO_ADDR=http://127.0.0.1:9 OPENBAO_PATHS=orgs/x BAO_TOKEN=tok-must-not-leak \
    timeout 30 bash -lic 'case $- in *e*) echo ERREXIT;; esac; case $- in *x*) echo XTRACE;; esac; echo SHELL-OK' 2>&1)" \
    || fail "login shell failed"
case "${out}" in *SHELL-OK*) ;; *) fail "login shell didn't run its command" ;; esac
case "${out}" in *ERREXIT* | *XTRACE*) fail "loader leaked shell options" ;; esac
case "${out}" in *tok-must-not-leak*) fail "login shell printed the token" ;; esac
[ $(($(date +%s) - start)) -le 20 ] || fail "login shell took too long"
pass "login shell survives an unreachable server"

rm -rf /dev/shm/openbao
echo "🎉 Test passed."
