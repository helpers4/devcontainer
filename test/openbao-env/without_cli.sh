#!/bin/bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# installCli:false — the loader must work without the bao CLI (curl + jq only), and a
# configured but unreachable server must never break a shell.

set -e

fail() { echo "❌ FAIL: $*"; exit 1; }
pass() { echo "✅ PASS: $*"; }

echo "Testing openbao-env with installCli:false..."

[ ! -e /usr/local/bin/bao ] || fail "bao installed although installCli is false"
pass "no bao CLI"
[ -x /usr/local/bin/openbao-env ] || fail "openbao-env missing"
pass "openbao-env present"
grep -q '^CFG_PATHS=orgs/test$' /usr/local/share/openbao-env/config || fail "paths option not baked into the config"
pass "paths option in config"

out="$(openbao-env status)" || fail "status failed"
case "${out}" in *"http://127.0.0.1:9"*) ;; *) fail "status doesn't show the address option" ;; esac
pass "status shows the configured address"

out="$(BAO_TOKEN=tok-must-not-leak timeout 30 bash -lc 'echo SHELL-OK' 2>&1)" || fail "login shell failed"
case "${out}" in *SHELL-OK*) ;; *) fail "login shell didn't run its command" ;; esac
case "${out}" in *tok-must-not-leak*) fail "token printed" ;; esac
pass "login shell survives an unreachable server"

echo "🎉 Test passed."
