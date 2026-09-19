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

[ -x "${CLONE_SCRIPT}" ] && pass "${CLONE_SCRIPT} installed and executable" \
    || fail "${CLONE_SCRIPT} not found or not executable"

bash -n "${CLONE_SCRIPT}" && pass "valid bash syntax" || fail "bash syntax error in ${CLONE_SCRIPT}"

command -v jq >/dev/null 2>&1 && pass "jq is available" || fail "jq is not available"

# install.sh's own option header (skipped when testing a repo checkout via CLONE_SCRIPT).
OPTIONS_ENV="/usr/local/share/org-workspace/options.env"
if [ "${CLONE_SCRIPT}" = "/usr/local/share/org-workspace/clone-repos.sh" ]; then
    grep -q '^AUTO_DISCOVER_OPTION=' "${OPTIONS_ENV}" && grep -q '^EXCLUDE_OPTION=' "${OPTIONS_ENV}" \
        && pass "option values baked into ${OPTIONS_ENV}" || fail "${OPTIONS_ENV} is missing its baked-in options"

    if [ "$(id -u)" -ne 0 ] || [ -z "${_REMOTE_USER:-}" ]; then
        [ -w /workspaces ] && pass "/workspaces is writable by $(id -un)" \
            || fail "/workspaces is not writable by $(id -un) — the clone script can't create sibling links"
    fi
fi

# ── Behaviour, against a sandbox with a fake gh ──────────────────────────────
# The real script is run end to end, with `gh` replaced so no network or auth is needed and
# failures can be injected at will. Every case must exit 0: a non-zero postStartCommand makes
# the devcontainer CLI skip every later lifecycle command.

SANDBOX="$(mktemp -d)"
trap 'rm -rf "${SANDBOX}"' EXIT

mkdir -p "${SANDBOX}/bin"
cat >"${SANDBOX}/bin/gh" <<'GH'
#!/usr/bin/env bash
case "$1 $2" in
    "repo view") echo "${FAKE_ORG:-acme}" ;;
    "repo list") [ -n "${FAKE_LIST_FAIL:-}" ] && exit 1; printf '%s\n' ${FAKE_REPOS:-} ;;
    "repo clone")
        name="${3#*/}"
        case " ${FAKE_CLONE_FAIL:-} " in *" ${name} "*) echo "fake: no access" >&2; exit 1 ;; esac
        mkdir -p "$4" && git init -q "$4" ;;
esac
GH
chmod +x "${SANDBOX}/bin/gh"

# new_case <options...> — fresh /workspaces-like layout; options become the options file.
new_case() {
    CASE="$(mktemp -d "${SANDBOX}/case.XXXXXX")"
    mkdir -p "${CASE}/ws/boot" "${CASE}/staged"
    git init -q "${CASE}/ws/boot"
    printf '%s\n' "$@" >"${CASE}/options.env"
}

# run_case — runs the script from the bootstrap dir; sets RC and OUT.
run_case() {
    set +e
    OUT="$(cd "${CASE}/ws/boot" && PATH="${EXTRA_PATH:+${EXTRA_PATH}:}${SANDBOX}/bin:${PATH}" \
        H4_ORG_WORKSPACE_OPTIONS="${CASE}/options.env" H4_ORG_WORKSPACE_STAGED="${CASE}/staged" \
        H4_ORG_WORKSPACE_RETRY_DELAY=0 bash "${CLONE_SCRIPT}" 2>&1)"
    RC=$?
    set -e
}

folders() { jq -r '.folders[].path' "${CASE}/ws/boot/${1:-acme.code-workspace}" | sort | tr '\n' ' '; }

# 1. autoDiscover (default) + exclude
new_case "AUTO_DISCOVER_OPTION=true" "EXCLUDE_OPTION=' skip-me , other '"
FAKE_REPOS="a b skip-me other" run_case
[ "${RC}" -eq 0 ] || fail "exit ${RC} on the happy path"
[ -L "${CASE}/ws/a" ] && [ -L "${CASE}/ws/b" ] || fail "discovered repos not linked"
[ ! -e "${CASE}/ws/skip-me" ] && [ ! -e "${CASE}/ws/other" ] || fail "excluded repos were cloned"
[ "$(folders)" = "../a ../b ../boot " ] && pass "autoDiscover + exclude: a, b, boot" || fail "unexpected folders: $(folders)"

# 2. explicit repos always win over autoDiscover, and exclude still applies
new_case "REPOS_OPTION='x, y ,z'" "AUTO_DISCOVER_OPTION=true" "EXCLUDE_OPTION=z"
FAKE_REPOS="a b" run_case
[ "${RC}" -eq 0 ] && [ -L "${CASE}/ws/x" ] && [ -L "${CASE}/ws/y" ] && [ ! -e "${CASE}/ws/a" ] && [ ! -e "${CASE}/ws/z" ] \
    && pass "repos overrides autoDiscover, exclude applies to both" || fail "repos/autoDiscover precedence broken"

# 3. autoDiscover=false with no repos: nothing cloned, still exit 0
new_case "AUTO_DISCOVER_OPTION=false"
FAKE_REPOS="a" run_case
[ "${RC}" -eq 0 ] && [ ! -e "${CASE}/ws/a" ] && pass "autoDiscover=false clones nothing" || fail "autoDiscover=false misbehaved"

# 4. failure injection: none of these may ever fail the attach
new_case "AUTO_DISCOVER_OPTION=true"
FAKE_REPOS="good bad" FAKE_CLONE_FAIL="bad" run_case
[ "${RC}" -eq 0 ] && [ -L "${CASE}/ws/good" ] && [ ! -e "${CASE}/ws/bad" ] && [ ! -e "${CASE}/staged/.bad.clone-tmp" ] \
    && pass "one failing clone: exit 0, the rest still cloned, no leftovers" || fail "a failing clone broke the run (rc=${RC})"

new_case "AUTO_DISCOVER_OPTION=true"
FAKE_REPOS="a" FAKE_LIST_FAIL=1 run_case
[ "${RC}" -eq 0 ] && pass "gh repo list failing: exit 0" || fail "gh repo list failure exited ${RC}"

mkdir -p "${SANDBOX}/badln"
printf '#!/bin/sh\necho "ln: Permission denied" >&2\nexit 1\n' >"${SANDBOX}/badln/ln"
chmod +x "${SANDBOX}/badln/ln"
new_case "AUTO_DISCOVER_OPTION=true"
FAKE_REPOS="a" EXTRA_PATH="${SANDBOX}/badln" run_case
[ "${RC}" -eq 0 ] && pass "symlink creation failing (read-only /workspaces): exit 0" || fail "ln failure exited ${RC}"

new_case "AUTO_DISCOVER_OPTION=true"
mkdir "${CASE}/staged/half"
FAKE_REPOS="half" run_case
[ "${RC}" -eq 0 ] && [ -d "${CASE}/staged/half" ] && [ ! -e "${CASE}/ws/half" ] \
    && pass "a .git-less dir in the volume is left alone, not treated as a finished clone" || fail "half-cloned dir mishandled"

new_case "AUTO_DISCOVER_OPTION=true" "UNBOUND_TRIGGER=1"
echo 'echo "$THIS_IS_UNSET"' >>"${CASE}/options.env"
FAKE_REPOS="a" run_case
[ "${RC}" -eq 0 ] && pass "unforeseen error (unbound variable): exit 0 backstop holds" || fail "unbound variable exited ${RC}"

# 5. merge into an existing, hand-formatted workspace file
new_case "REPOS_OPTION=a,gone" "EXCLUDE_OPTION=gone"
printf '{\n\t"folders": [\n\t\t{\n\t\t\t"name": "🧰 boot",\n\t\t\t"path": "."\n\t\t},\n\t\t{\n\t\t\t"path": "../gone"\n\t\t}\n\t],\n\t"settings": {\n\t\t"k": 1\n\t}\n}' \
    >"${CASE}/ws/boot/acme.code-workspace"
run_case
W="${CASE}/ws/boot/acme.code-workspace"
[ "${RC}" -eq 0 ] || fail "merge exited ${RC}"
[ "$(jq '[.folders[] | select(.path == "." or .path == "../boot")] | length' "${W}")" = 1 ] \
    && pass "'.' and '../boot' not listed twice" || fail "bootstrap folder duplicated: $(folders)"
[ "$(jq -r '.folders[0].name' "${W}")" = "🧰 boot" ] && pass "hand-written folder names (emoji) preserved" || fail "folder name lost"
[ "$(folders)" = ". ../a " ] && pass "excluded repo dropped from an existing file" || fail "unexpected folders: $(folders)"
[ "$(jq '.settings.k' "${W}")" = 1 ] && pass "other keys untouched" || fail "settings lost"
grep -q "$(printf '^\t"folders"')" "${W}" && pass "tab indentation preserved" || fail "indentation changed"
[ -n "$(tail -c1 "${W}")" ] && pass "missing trailing newline preserved" || fail "trailing newline added"
BEFORE="$(cat "${W}")"
run_case
[ "$(cat "${W}")" = "${BEFORE}" ] && echo "${OUT}" | grep -q "already up to date" \
    && pass "second run is a no-op" || fail "second run modified the file"

# 6. a workspace file that isn't plain JSON (comments) must never be overwritten
new_case "REPOS_OPTION=a"
printf '{\n  // my folders\n  "folders": []\n}\n' >"${CASE}/ws/boot/acme.code-workspace"
run_case
[ "${RC}" -eq 0 ] && grep -q "my folders" "${CASE}/ws/boot/acme.code-workspace" \
    && pass "JSONC workspace file left untouched" || fail "JSONC workspace file was overwritten"

# 7. excluding a previously linked repo removes the stale symlink but keeps the clone
new_case "REPOS_OPTION=a,b"
run_case
sed -i 's/^REPOS_OPTION=.*/REPOS_OPTION=a,b\nEXCLUDE_OPTION=b/' "${CASE}/options.env"
run_case
[ ! -e "${CASE}/ws/b" ] && [ -d "${CASE}/staged/b/.git" ] && ! folders | grep -q '\.\./b ' \
    && pass "newly excluded repo unlinked, clone kept" || fail "exclude cleanup wrong"

echo ""
echo "✅ All org-workspace feature tests passed!"
