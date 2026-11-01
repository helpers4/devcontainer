#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# initRepos=all: the repos next to the workspace repo are turned into jj repos too, except
# the ones jj can't handle, which are left alone with a reason. Every one of these paths only
# warns on failure, so nothing but this scenario would notice them breaking.

set -e

fail() {
    echo "❌ FAIL: $*"
    exit 1
}
pass() { echo "✅ PASS: $*"; }

OWNER="$(stat -c '%U' /mnt/h4jj)"
as_user() {
    if [ "$(id -un)" = "${OWNER}" ]; then bash -c "$1"; else su "${OWNER}" -s /bin/bash -c "$1"; fi
}

[ "$(stat -c '%U' /workspaces)" = "${OWNER}" ] || fail "/workspaces is not owned by ${OWNER}"
pass "/workspaces is writable by ${OWNER}"

BASE="/workspaces/jj-scenario"
rm -rf "${BASE}"
as_user "
set -e
git config --global user.name 'Test User'
git config --global user.email test@example.com
mkdir -p '${BASE}'
for name in main sibling; do
    git init -q -b main '${BASE}/'\$name
    (cd '${BASE}/'\$name && echo x > f && git add f && git commit -q -m init)
done
git clone -q --depth 1 'file://${BASE}/sibling' '${BASE}/shallow'
git -C '${BASE}/main' worktree add -q '${BASE}/worktree'
git init -q -b main '${BASE}/lfs'
(cd '${BASE}/lfs' && echo '*.bin filter=lfs diff=lfs merge=lfs -text' > .gitattributes && git add .gitattributes && git commit -q -m lfs)
"
OUT="$(as_user "cd '${BASE}/main' && /usr/local/share/jj/jj-setup.sh attach" 2>&1)"
echo "${OUT}"

[ -d "${BASE}/main/.jj" ] || fail "the workspace repo was not converted"
[ -d "${BASE}/sibling/.jj" ] || fail "the sibling repo was not converted"
pass "workspace and sibling repos converted"

for name in shallow worktree lfs; do
    [ -e "${BASE}/${name}/.jj" ] && fail "${name} was converted"
    grep -q "${name}: left as a plain git repo" <<< "${OUT}" || fail "no reason given for ${name}"
done
pass "shallow clone, git worktree and LFS repo left alone, with a reason"

rm -rf "${BASE}"
echo ""
echo "🎉 all_repos scenario passed!"
