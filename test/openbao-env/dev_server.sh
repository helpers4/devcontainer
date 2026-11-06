#!/bin/bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# End to end against `bao server -dev` in the container: wrapped secret_id from files,
# AppRole from env, BAO_TOKEN, path override order, existing variables kept, the
# single-use secret-id file deleted, the cached token reused by refresh, root runs leaving
# the state to the remote user. Test values are dummies, but never printed anyway.

set -e

# Root for the server setup; the loader itself runs as the remote user below.
if [ "$(id -u)" -ne 0 ]; then
    exec sudo -E bash "$0" "$@"
fi

fail() { echo "❌ FAIL: $*"; exit 1; }
pass() { echo "✅ PASS: $*"; }

. /usr/local/share/openbao-env/config
U="${CFG_USER}"
[ "${U}" != "root" ] || fail "expected a non-root remote user on this image"
D=/dev/shm/openbao
ADDR=http://127.0.0.1:8200

as_user() { runuser -u "${U}" -- env -u BAO_TOKEN -u BAO_ADDR "$@"; }
bao_root() { BAO_ADDR="${ADDR}" BAO_TOKEN=root-test bao "$@"; }

echo "Testing openbao-env against a dev server..."

bao server -dev -dev-root-token-id=root-test -dev-listen-address=127.0.0.1:8200 \
    > /tmp/bao-dev.log 2>&1 &
SERVER_PID=$!
trap 'kill ${SERVER_PID} 2>/dev/null || true' EXIT
curl -fs --retry 30 --retry-delay 1 --retry-connrefused "${ADDR}/v1/sys/health" > /dev/null \
    || fail "dev server didn't start"
pass "dev server up"

bao_root secrets enable -path=kv kv-v2 > /dev/null
bao_root kv put kv/shared/common SHARED_ONLY=v-shared DUP=v-dup-shared 'BAD-NAME=v-bad' > /dev/null
bao_root kv put kv/orgs/test ORG_ONLY=v-org DUP=v-dup-org PRESET=v-preset EMPTY=v-empty \
    'MULTI=line one
it'"'"'s line two' > /dev/null
bao_root policy write read-test - > /dev/null << 'EOF'
path "kv/data/shared/common" { capabilities = ["read"] }
path "kv/data/orgs/test" { capabilities = ["read"] }
EOF
bao_root auth enable approle > /dev/null
bao_root write auth/approle/role/test token_policies=read-test token_ttl=1h token_max_ttl=4h > /dev/null
ROLE_ID="$(bao_root read -field=role_id auth/approle/role/test/role-id)"
pass "server seeded"

drop_wrapped() {
    mkdir -p "${D}"
    printf '%s\n' "${ROLE_ID}" > "${D}/role-id"
    bao_root write -f -wrap-ttl=120s -field=wrapping_token auth/approle/role/test/secret-id \
        > "${D}/wrapped-secret-id"
    chown -R "${U}:" "${D}"
    chmod 700 "${D}"
    chmod 600 "${D}"/*
}

CHECK=/tmp/openbao-check.sh
cat > "${CHECK}" << 'EOF'
f() { echo "❌ FAIL (in shell): $*"; exit 1; }
[ "${SHARED_ONLY:-}" = v-shared ] || f "SHARED_ONLY not loaded"
[ "${ORG_ONLY:-}" = v-org ] || f "ORG_ONLY not loaded"
[ "${DUP:-}" = v-dup-org ] || f "DUP: the later path (orgs/test) must win"
[ "${PRESET:-}" = mine ] || f "PRESET: an already-set variable was overwritten"
[ "${EMPTY:-}" = v-empty ] || f "EMPTY: an empty variable must count as unset"
[ "${MULTI:-}" = "line one
it's line two" ] || f "MULTI: quoting broken"
case " ${OPENBAO_ENV_KEYS:-} " in *" PRESET "*) f "PRESET listed as loaded";; esac
case $- in *e*) f "errexit leaked";; esac
echo SHELL-OK
EOF
chmod 644 "${CHECK}"

# ── b. wrapped secret_id files ────────────────────────────────────────────────
rm -rf "${D}"
drop_wrapped
out="$(as_user PRESET=mine EMPTY= bash -lc ". ${CHECK}" 2>&1)" || fail "wrapped: ${out}"
case "${out}" in *SHELL-OK*) ;; *) fail "wrapped: ${out}" ;; esac
pass "wrapped secret_id: loaded, override order, existing kept, empty replaced, quoting"
[ ! -e "${D}/wrapped-secret-id" ] || fail "wrapped-secret-id not deleted after use"
pass "wrapped-secret-id deleted after use"
[ "$(stat -c '%a %U' "${D}")" = "700 ${U}" ] || fail "state dir: $(stat -c '%a %U' "${D}")"
[ "$(stat -c '%a %U' "${D}/env")" = "600 ${U}" ] || fail "cache: $(stat -c '%a %U' "${D}/env")"
[ "$(stat -c '%a %U' "${D}/token")" = "600 ${U}" ] || fail "token: $(stat -c '%a %U' "${D}/token")"
pass "dir 700, cache and token 600, owned by ${U}"
leftover="$(find "${D}" -maxdepth 1 -name '.tmp.*' | wc -l)"
[ "${leftover}" -eq 0 ] || fail "${leftover} temp file(s) left in ${D} after the first load"
pass "no temp file left after the first load"

# Concurrent shells (one fetches, the others wait for the lock): still no leftovers.
rm -f "${D}/env"
pids=""
for _ in 1 2 3 4; do
    as_user bash -lc 'true' 2> /dev/null &
    pids="${pids} $!"
done
# Not a bare `wait`: that would also wait for the dev server.
for pid in ${pids}; do wait "${pid}"; done
leftover="$(find "${D}" -maxdepth 1 -name '.tmp.*' | wc -l)"
[ "${leftover}" -eq 0 ] || fail "${leftover} temp file(s) left in ${D} after concurrent loads"
[ -f "${D}/env" ] || fail "concurrent loads produced no cache"
pass "no temp file left after concurrent loads"
grep -q "BAD-NAME" "${D}/env" && fail "invalid name written to the cache"
pass "invalid variable name skipped"

# Status: names, never values.
status="$(as_user openbao-env status 2>&1)"
for v in v-shared v-org v-dup v-preset v-empty v-bad "line one" "${ROLE_ID}"; do
    case "${status}" in *"${v}"*) fail "status printed a secret value" ;; esac
done
case "${status}" in *ORG_ONLY*SHARED_ONLY* | *SHARED_ONLY*ORG_ONLY*) ;; *) fail "status doesn't list key names" ;; esac
pass "status lists key names, no values"

# ── refresh with the cached token only, and a new shell sees the new value ───────
bao_root kv patch kv/orgs/test ORG_ONLY=v-org-2 > /dev/null
out="$(as_user bash -lc '[ "$ORG_ONLY" = v-org ] || exit 3
    openbao-env refresh > /dev/null || exit 4
    . /usr/local/share/openbao-env/loader.sh
    [ "$ORG_ONLY" = v-org-2 ] || exit 5
    bash -c ". /usr/local/share/openbao-env/loader.sh; [ \"\$ORG_ONLY\" = v-org-2 ] || exit 6"' 2>&1)" \
    || fail "refresh via cached token / reload (exit $?)"
pass "refresh reuses the cached token; a reload replaces values it set itself"
bao_root kv patch kv/orgs/test ORG_ONLY=v-org > /dev/null

# ── a root shell leaves the state to the remote user ─────────────────────────────
as_user openbao-env clear > /dev/null
env -u BAO_TOKEN -u BAO_ADDR BAO_ROLE_ID="${ROLE_ID}" \
    BAO_SECRET_ID="$(bao_root write -f -field=secret_id auth/approle/role/test/secret-id)" \
    bash -lc 'true' 2> /dev/null
[ "$(stat -c '%U' "${D}/env")" = "${U}" ] || fail "root run left ${D}/env owned by $(stat -c '%U' "${D}/env")"
pass "root run chowns the state to ${U}"

# ── c. BAO_ROLE_ID + BAO_SECRET_ID ───────────────────────────────────────────────
rm -rf "${D}"
SECRET_ID="$(bao_root write -f -field=secret_id auth/approle/role/test/secret-id)"
out="$(as_user BAO_ROLE_ID="${ROLE_ID}" BAO_SECRET_ID="${SECRET_ID}" PRESET=mine EMPTY= \
    bash -lc ". ${CHECK}" 2>&1)" || fail "env approle: ${out}"
case "${out}" in *SHELL-OK*) ;; *) fail "env approle: ${out}" ;; esac
pass "BAO_ROLE_ID/BAO_SECRET_ID: loaded"

# ── a. BAO_TOKEN ─────────────────────────────────────────────────────────────────
rm -rf "${D}"
out="$(as_user BAO_TOKEN=root-test PRESET=mine EMPTY= bash -lc ". ${CHECK}" 2>&1)" \
    || fail "BAO_TOKEN: ${out}"
case "${out}" in *SHELL-OK*) ;; *) fail "BAO_TOKEN: ${out}" ;; esac
pass "BAO_TOKEN: loaded"

# ── a bad wrapped token: one warning naming the cause, file dropped, shell fine ───
rm -rf "${D}"
mkdir -p "${D}"
printf '%s\n' "${ROLE_ID}" > "${D}/role-id"
echo "not-a-real-wrapping-token" > "${D}/wrapped-secret-id"
chown -R "${U}:" "${D}"
out="$(as_user bash -lc 'echo SHELL-OK' 2>&1)" || fail "bad wrapped token broke the shell"
case "${out}" in *SHELL-OK*) ;; *) fail "bad wrapped token: ${out}" ;; esac
case "${out}" in *"unwrapping"*) ;; *) fail "warning doesn't name the cause: ${out}" ;; esac
case "${out}" in *not-a-real-wrapping-token*) fail "wrapping token printed" ;; esac
[ ! -e "${D}/wrapped-secret-id" ] || fail "rejected wrapped-secret-id not deleted"
pass "bad wrapped token: clean warning, file deleted"

rm -rf "${D}" "${CHECK}"
echo "🎉 Test passed."
