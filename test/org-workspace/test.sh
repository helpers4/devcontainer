#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -e

echo "Testing org-workspace feature..."

CLONE_SCRIPT="${CLONE_SCRIPT:-/usr/local/share/org-workspace/clone-repos.sh}"

pass() { echo "✅ PASS: $*"; }
fail() { echo "❌ FAIL: $*"; exit 1; }

# ── Installation ─────────────────────────────────────────────────────────────

[ -x "${CLONE_SCRIPT}" ] && pass "${CLONE_SCRIPT} is installed and executable" \
    || fail "${CLONE_SCRIPT} not found or not executable"
bash -n "${CLONE_SCRIPT}" && pass "valid bash syntax" || fail "bash syntax error in ${CLONE_SCRIPT}"
command -v jq >/dev/null 2>&1 && pass "jq is available" || fail "jq is not available"

# Skipped when CLONE_SCRIPT points at a checkout of the repo instead of an installed feature.
if [ "${CLONE_SCRIPT}" = "/usr/local/share/org-workspace/clone-repos.sh" ]; then
    OPTIONS_ENV="/usr/local/share/org-workspace/options.env"
    grep -q '^AUTO_DISCOVER_OPTION=' "${OPTIONS_ENV}" && grep -q '^EXCLUDE_OPTION=' "${OPTIONS_ENV}" \
        && pass "options saved in ${OPTIONS_ENV}" || fail "${OPTIONS_ENV} is missing options"
    if [ "$(id -u)" -ne 0 ]; then
        [ -w /workspaces ] && pass "/workspaces is writable by $(id -un)" \
            || fail "/workspaces is not writable by $(id -un)"
    fi
fi

# ── Behaviour ────────────────────────────────────────────────────────────────
# The real script runs in a sandbox with a fake gh, so no network or auth is needed and
# failures can be injected. Every case must exit 0: a failing lifecycle command makes the
# devcontainer CLI skip the ones after it.

SANDBOX="$(mktemp -d)"
trap 'rm -rf "${SANDBOX}"' EXIT
GIT_ID=(-c user.name=t -c user.email=t@t)

mkdir -p "${SANDBOX}/bin"
cat >"${SANDBOX}/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
    "repo view") echo "${FAKE_ORG:-acme}" ;;
    "repo list") [ -n "${FAKE_LIST_FAIL:-}" ] && exit 1; printf '%s\n' ${FAKE_REPOS:-} ;;
    "repo clone")
        name="${3#*/}"
        case " ${FAKE_CLONE_FAIL:-} " in *" ${name} "*) echo "fake: no access" >&2; exit 1 ;; esac
        # A clone whose only commit is on the remote: nothing local to lose.
        git init -q -b main "$4"
        git -C "$4" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
        git -C "$4" update-ref refs/remotes/origin/main HEAD ;;
esac
GH
chmod +x "${SANDBOX}/bin/gh"

# new_case [option lines...]: a fresh project and volume, with the default options.
new_case() {
    CASE="$(mktemp -d "${SANDBOX}/case.XXXXXX")"
    mkdir -p "${CASE}/ws/boot" "${CASE}/volume"
    git init -q "${CASE}/ws/boot"
    printf '%s\n' "ORG_OPTION=''" "REPOS_OPTION=''" "AUTO_DISCOVER_OPTION=true" "EXCLUDE_OPTION=''" \
        "GENERATE_CODE_WORKSPACE_OPTION=true" "CODE_WORKSPACE_NAME_OPTION=''" "$@" >"${CASE}/options.env"
}

# run_case: runs the script from the project folder. Sets RC and OUT.
run_case() {
    set +e
    OUT="$(cd "${CASE}/ws/boot" && PATH="${EXTRA_PATH:+${EXTRA_PATH}:}${SANDBOX}/bin:${PATH}" \
        H4_ORG_WORKSPACE_OPTIONS="${CASE}/options.env" H4_ORG_WORKSPACE_VOLUME="${CASE}/volume" \
        H4_ORG_WORKSPACE_RETRY_DELAY=0 bash "${CLONE_SCRIPT}" 2>&1)"
    RC=$?
    set -e
}

ws_file() { echo "${CASE}/ws/boot/acme.code-workspace"; }
folders() { jq -r '.folders[].path' "$(ws_file)" | sort | tr '\n' ' '; }
# commit_pushed <repo>: commit everything and pretend the remote has it.
commit_pushed() {
    git -C "$1" add -A
    git -C "$1" "${GIT_ID[@]}" commit -q --allow-empty -m more
    git -C "$1" update-ref refs/remotes/origin/main HEAD
}

# ── Choosing repos ──

new_case "EXCLUDE_OPTION=' skip-me , other '"
FAKE_REPOS="a b skip-me other" run_case
[ "${RC}" -eq 0 ] && [ -L "${CASE}/ws/a" ] && [ -L "${CASE}/ws/b" ] || fail "discovered repos were not linked (rc=${RC})"
[ ! -e "${CASE}/ws/skip-me" ] && [ ! -e "${CASE}/ws/other" ] || fail "excluded repos were cloned"
[ "$(folders)" = "../a ../b ../boot " ] && pass "autoDiscover and exclude" || fail "unexpected folders: $(folders)"

new_case "REPOS_OPTION='x, y ,z'" "EXCLUDE_OPTION=z"
FAKE_REPOS="a b" run_case
[ "${RC}" -eq 0 ] && [ -L "${CASE}/ws/x" ] && [ -L "${CASE}/ws/y" ] && [ ! -e "${CASE}/ws/a" ] && [ ! -e "${CASE}/ws/z" ] \
    && pass "repos wins over autoDiscover, exclude still applies" || fail "repos/autoDiscover precedence"

new_case "AUTO_DISCOVER_OPTION=false"
FAKE_REPOS="a" run_case
[ "${RC}" -eq 0 ] && [ ! -e "${CASE}/ws/a" ] && pass "autoDiscover=false clones nothing" || fail "autoDiscover=false"

new_case "AUTO_DISCOVER_OPTION=publik"
FAKE_REPOS="a" run_case
echo "${OUT}" | grep -q "unknown autoDiscover value 'publik'" && pass "an unknown autoDiscover value is reported" \
    || fail "a typo in autoDiscover went unnoticed"

# ── Finding the org ──

for url in "git@github.com:from-origin/boot.git" "https://github.com/from-origin/boot" "https://token@github.com/from-origin/.dev.git"; do
    new_case "REPOS_OPTION=a"
    git -C "${CASE}/ws/boot" remote add origin "${url}"
    FAKE_ORG=from-gh run_case
    echo "${OUT}" | grep -q "org: from-origin" && pass "org read from origin ${url}" || fail "org not read from ${url}"
done
new_case "REPOS_OPTION=a"
FAKE_ORG=from-gh run_case
echo "${OUT}" | grep -q "org: from-gh" && pass "org comes from gh when there is no origin" || fail "no gh fallback"

# ── Failures never fail the run ──

new_case
FAKE_REPOS="good bad" FAKE_CLONE_FAIL="bad" run_case
[ "${RC}" -eq 0 ] && [ -L "${CASE}/ws/good" ] && [ ! -e "${CASE}/ws/bad" ] && [ ! -e "${CASE}/volume/.bad.clone-tmp" ] \
    && pass "a failed clone does not stop the others" || fail "a failed clone broke the run (rc=${RC})"

new_case
FAKE_REPOS="a" FAKE_LIST_FAIL=1 run_case
[ "${RC}" -eq 0 ] && pass "gh repo list failing exits 0" || fail "gh repo list failure exited ${RC}"

mkdir -p "${SANDBOX}/badln"
printf '#!/bin/sh\necho "ln: Permission denied" >&2\nexit 1\n' >"${SANDBOX}/badln/ln"
chmod +x "${SANDBOX}/badln/ln"
new_case
FAKE_REPOS="a" EXTRA_PATH="${SANDBOX}/badln" run_case
[ "${RC}" -eq 0 ] && pass "a read-only /workspaces exits 0" || fail "ln failure exited ${RC}"

new_case
mkdir "${CASE}/volume/half"
FAKE_REPOS="half" run_case
[ "${RC}" -eq 0 ] && [ -d "${CASE}/volume/half" ] && [ ! -e "${CASE}/ws/half" ] \
    && pass "a folder without .git in the volume is left alone" || fail "a folder without .git was mishandled"

new_case 'echo "${THIS_IS_UNSET}"'
FAKE_REPOS="a" run_case
[ "${RC}" -eq 0 ] && echo "${OUT}" | grep -q "internal error" \
    && pass "an unexpected error exits 0 and says so" || fail "unexpected error: rc=${RC}"

new_case
rm "${CASE}/options.env"
run_case
[ "${RC}" -eq 0 ] && pass "a missing options file exits 0" || fail "a missing options file exited ${RC}"

# ── The .code-workspace file ──

tab_file() { printf '{\n\t"folders": [\n\t\t{\n\t\t\t"name": "🧰 boot",\n\t\t\t"path": "."\n\t\t},\n\t\t{\n\t\t\t"path": "../a"\n\t\t}\n\t],\n\t"settings": {\n\t\t"k": 1\n\t}\n}'; }

new_case "REPOS_OPTION=a"
tab_file >"$(ws_file)"
BEFORE="$(cat "$(ws_file)")"
run_case
[ "${RC}" -eq 0 ] && [ "$(cat "$(ws_file)")" = "${BEFORE}" ] && echo "${OUT}" | grep -q "up to date" \
    && pass "a file already in VS Code's format is not rewritten" || fail "an up-to-date workspace file changed"

new_case "REPOS_OPTION=a,b"
tab_file | jq --indent 4 . >"$(ws_file)"
run_case
W="$(ws_file)"
[ "$(jq '[.folders[] | select(.path == "." or .path == "../boot")] | length' "${W}")" = 1 ] \
    && pass "'.' and '../boot' are listed once" || fail "the project folder is listed twice: $(folders)"
[ "$(jq -r '.folders[0].name' "${W}")" = "🧰 boot" ] && [ "$(jq '.settings.k' "${W}")" = 1 ] \
    && pass "folder names and settings are kept" || fail "names or settings were lost"
grep -q "$(printf '^\t"folders"')" "${W}" && [ "$(tail -c1 "${W}")" = "}" ] \
    && pass "written with tabs and no final newline, like VS Code" || fail "not written in VS Code's format"
[ "$(folders)" = ". ../a ../b " ] && pass "new folders are added" || fail "unexpected folders: $(folders)"

new_case "REPOS_OPTION=a" "EXCLUDE_OPTION=gone"
printf '{"folders":[{"path":"."},{"path":"../gone"}]}' >"$(ws_file)"
run_case
[ "$(folders)" = ". ../a " ] && pass "excluded repos leave the file" || fail "unexpected folders: $(folders)"

new_case "REPOS_OPTION=a"
printf '{\n  // my folders\n  "folders": []\n}\n' >"$(ws_file)"
run_case
[ "${RC}" -eq 0 ] && grep -q "my folders" "$(ws_file)" \
    && pass "a file with comments is left alone" || fail "a file with comments was overwritten"

# ── Removing repos that are no longer wanted ──

# prune_case [option lines...]: a, b and c are cloned and linked. The caller then changes the list.
prune_case() {
    new_case "$@"
    FAKE_REPOS="a b c" run_case
    [ "${RC}" -eq 0 ] && [ -L "${CASE}/ws/b" ] || fail "setup: b was not cloned"
}
# kept <name>: the link is gone but the clone is still in the volume.
kept() { [ ! -e "${CASE}/ws/$1" ] && [ -d "${CASE}/volume/$1/.git" ]; }

prune_case
FAKE_REPOS="a c" run_case
[ ! -e "${CASE}/ws/b" ] && [ ! -e "${CASE}/volume/b" ] && [ "$(folders)" = "../a ../boot ../c " ] \
    && pass "a clean repo that left the list is removed" || fail "a clean repo was not removed: $(folders)"

prune_case
echo "EXCLUDE_OPTION=b" >>"${CASE}/options.env"
FAKE_REPOS="a b c" run_case
[ ! -e "${CASE}/ws/b" ] && [ ! -e "${CASE}/volume/b" ] && pass "a newly excluded repo is removed" || fail "an excluded repo was not removed"

prune_case
git -C "${CASE}/volume/b" "${GIT_ID[@]}" commit -q --allow-empty -m local
FAKE_REPOS="a c" run_case
kept b && echo "${OUT}" | grep -q "may hold local work" && pass "an unpushed commit keeps the clone" || fail "an unpushed commit was lost"

prune_case
touch "${CASE}/volume/b/notes.txt"
FAKE_REPOS="a c" run_case
kept b && pass "an uncommitted file keeps the clone" || fail "an uncommitted file was lost"

prune_case
echo ".env" >"${CASE}/volume/b/.gitignore"
commit_pushed "${CASE}/volume/b"
echo "SECRET=1" >"${CASE}/volume/b/.env"
FAKE_REPOS="a c" run_case
kept b && pass "an ignored file (.env) keeps the clone" || fail ".env was lost"

prune_case
echo "node_modules/" >"${CASE}/volume/b/.gitignore"
commit_pushed "${CASE}/volume/b"
mkdir "${CASE}/volume/b/node_modules" && touch "${CASE}/volume/b/node_modules/x"
FAKE_REPOS="a c" run_case
[ ! -e "${CASE}/volume/b" ] && pass "node_modules alone does not keep the clone" || fail "node_modules blocked the removal"

prune_case
git -C "${CASE}/volume/b" checkout -q --detach
git -C "${CASE}/volume/b" "${GIT_ID[@]}" commit -q --allow-empty -m detached
FAKE_REPOS="a c" run_case
kept b && pass "a commit on a detached HEAD keeps the clone" || fail "a detached HEAD commit was lost"

prune_case
git -C "${CASE}/volume/b" checkout -q --detach
git -C "${CASE}/volume/b" "${GIT_ID[@]}" commit -q --allow-empty -m tagged
git -C "${CASE}/volume/b" update-ref refs/tags/only-local HEAD
git -C "${CASE}/volume/b" checkout -q main
FAKE_REPOS="a c" run_case
kept b && pass "a commit that only a tag points to keeps the clone" || fail "a tagged commit was lost"

prune_case
echo x >"${CASE}/volume/b/f"
git -C "${CASE}/volume/b" add f
git -C "${CASE}/volume/b" "${GIT_ID[@]}" stash -q
FAKE_REPOS="a c" run_case
kept b && pass "a stash keeps the clone" || fail "a stash was lost"

prune_case
rm -rf "${CASE}/volume/b/.git" && mkdir "${CASE}/volume/b/.git"
echo mine >"${CASE}/volume/b/file"
FAKE_REPOS="a c" run_case
[ -e "${CASE}/volume/b/file" ] && pass "a checkout git cannot read is kept" || fail "an unreadable checkout was deleted"

prune_case
FAKE_REPOS="" run_case
[ -L "${CASE}/ws/b" ] && [ -d "${CASE}/volume/b/.git" ] && echo "${OUT}" | grep -q "returned no repos" \
    && pass "an empty discovery removes nothing" || fail "an empty discovery emptied the workspace"

prune_case
FAKE_REPOS="a c" FAKE_LIST_FAIL=1 run_case
[ -L "${CASE}/ws/b" ] && [ -d "${CASE}/volume/b/.git" ] && pass "a failed discovery removes nothing" || fail "a failed discovery removed repos"

prune_case
sed -i 's/^AUTO_DISCOVER_OPTION=.*/AUTO_DISCOVER_OPTION=false/' "${CASE}/options.env"
FAKE_REPOS="a c" run_case
[ -d "${CASE}/volume/b/.git" ] && pass "with no list configured nothing is removed" || fail "repos were removed without a list"

new_case
FAKE_REPOS=".github a" run_case
FAKE_REPOS="a" run_case
[ ! -e "${CASE}/ws/.github" ] && [ ! -e "${CASE}/volume/.github" ] && pass "dot-named repos are removed too" || fail ".github was left behind"

echo ""
echo "✅ All org-workspace feature tests passed!"
