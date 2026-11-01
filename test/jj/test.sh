#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing jj feature..."

SETUP="/usr/local/share/jj/jj-setup.sh"
STAGED="/mnt/h4jj"
GIT_CONF="/etc/jj/conf.d/10-helpers4-git.toml"

fail() {
    echo "❌ FAIL: $*"
    exit 1
}
pass() { echo "✅ PASS: $*"; }

# test.sh may run as root while the feature configured a non-root user — find that user from
# the volume's owner, and run what that user would run as them.
OWNER="$(stat -c '%U' "${STAGED}")"
OWNER_HOME="$(getent passwd "${OWNER}" | cut -d: -f6)"
as_user() {
    if [ "$(id -un)" = "${OWNER}" ]; then
        bash -c "$1" < /dev/null
    else
        su "${OWNER}" -s /bin/bash -c "$1" < /dev/null
    fi
}

# ── Install ──────────────────────────────────────────────────────────────────
command -v jj > /dev/null 2>&1 || fail "jj is not on PATH"
[ -x /usr/local/bin/jj ] || fail "jj is not in /usr/local/bin"
pass "$(jj --version)"

[ -s /usr/share/bash-completion/completions/jj ] || fail "bash completion missing"
[ -s /usr/local/share/zsh/site-functions/_jj ] || fail "zsh completion missing"
pass "bash and zsh completions installed"

[ "$(stat -c '%a' /tmp)" = "1777" ] || fail "/tmp lost its 1777 mode during the install"
pass "/tmp still 1777"

# ── Volume ───────────────────────────────────────────────────────────────────
grep -qs " ${STAGED} " /proc/mounts || fail "${STAGED} is not a mounted volume"
[ "$(stat -c '%a' "${STAGED}")" = "700" ] || fail "${STAGED} is not private (700)"
[ "$(readlink -f "${OWNER_HOME}/.config/jj")" = "${STAGED}" ] || fail "$OWNER_HOME/.config/jj does not point to ${STAGED}"
as_user "jj config set --user ui.default-command log" || fail "user config is not writable"
grep -q 'default-command' "${STAGED}/config.toml" || fail "user config did not land in the volume"
pass ".config/jj lives in the volume and is writable"

# ── Agent sessions ───────────────────────────────────────────────────────────
[ "$(as_user 'jj config get ui.paginate')" = "auto" ] || fail "pager changed outside agent sessions"
[ "$(as_user 'CLAUDECODE=1 jj config get ui.paginate')" = "never" ] || fail "pager still on under CLAUDECODE"
[ "$(as_user 'AI_AGENT=some-agent jj config get ui.paginate')" = "never" ] || fail "pager still on under AI_AGENT"
pass "agent-only config applies under CLAUDECODE and AI_AGENT only"

# ── Attach: identity, signing, repo init ─────────────────────────────────────
REPO="${OWNER_HOME}/jj-test-repo"
REMOTE="${OWNER_HOME}/jj-test-remote.git"
rm -rf "${REPO}" "${REMOTE}"
as_user "
set -e
git config --global --unset commit.gpgsign || true
git config --global user.name 'Test User'
git config --global user.email test@example.com
git init -q --bare -b main '${REMOTE}'
git init -q -b main '${REPO}'
cd '${REPO}'
echo one > file && git add file && git commit -q -m init
git remote add origin '${REMOTE}' && git push -q -u origin main
# Signing with a key that doesn't exist here, as a host config copied in would: set after
# the commit above, which git itself would then refuse to make.
git config --global commit.gpgsign true
git config --global gpg.format ssh
git config --global user.signingkey ~/missing-key.pub
"
OUT="$(as_user "cd '${REPO}' && ${SETUP} attach" 2>&1)"
echo "${OUT}"

# initRepos=auto: a repo that only ever saw git is left alone.
[ -e "${REPO}/.jj" ] && fail "a plain git repo was turned into a jj repo"
grep -q 'plain git, no jj commit in their history: jj-test-repo' <<< "${OUT}" || fail "the plain git repo is not listed"
pass "plain git repo left untouched"

# Someone pushes a commit made with jj: the repo's history now says it's used with jj.
as_user "
set -e
rm -rf ~/jj-test-other
jj git clone --quiet '${REMOTE}' ~/jj-test-other
cd ~/jj-test-other && echo jj > other && jj commit -m 'made with jj' --quiet
jj bookmark move main --to @- --quiet && jj git push --bookmark main --quiet
cd '${REPO}' && git pull -q
"
rm -rf "${OWNER_HOME}/jj-test-other"
OUT="$(as_user "cd '${REPO}' && ${SETUP} attach" 2>&1)"
echo "${OUT}"

[ -d "${REPO}/.jj" ] || fail "a repo with jj commits in its history was not turned into a jj repo"
[ -d "${REPO}/.git" ] || fail "the jj repo is not colocated"
pass "repo with jj history turned into a colocated jj repo"

grep -q 'user.email = "test@example.com"' "${GIT_CONF}" || fail "git identity not written to ${GIT_CONF}"
[ "$(as_user "cd '${REPO}' && jj config get user.name")" = "Test User" ] || fail "jj does not see the git identity"
pass "jj uses the git identity"

grep -q 'signing' "${GIT_CONF}" && fail "signing enabled with a key file that doesn't exist"
grep -q "won't sign" <<< "${OUT}" || fail "no warning about the missing signing key"
# The git commit that jj never touched has no change-id: the check reads headers, not messages.
as_user "cd '${REPO}' && git cat-file -p HEAD~1" | grep -q '^change-id ' && fail "the git-made commit has a change-id header"
pass "signing left off when the key is missing"

as_user "cd '${REPO}' && jj bookmark list --tracked" | grep -q '^main' || fail "main@origin is not tracked"
pass "upstream branch tracked"

as_user "cd '${REPO}' && echo two > file && jj commit -m second --quiet && jj bookmark move main --to @- --quiet && jj git push --bookmark main --quiet" \
    || fail "commit and push with jj failed"
[ "$(as_user "git -C '${REMOTE}' log -1 --format=%s main")" = "second" ] || fail "the push did not reach the remote"
pass "jj commit and jj git push work"

OUT="$(as_user "cd '${REPO}' && ${SETUP} attach" 2>&1)"
grep -q 'now a colocated jj repo' <<< "${OUT}" && fail "a second attach converted the repo again"
pass "a second attach changes nothing"

rm -rf "${REPO}" "${REMOTE}"
as_user "git config --global --unset commit.gpgsign; git config --global --unset gpg.format; git config --global --unset user.signingkey" || true

echo ""
echo "🎉 All jj tests passed!"
