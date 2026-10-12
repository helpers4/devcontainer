#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Clones the org's repos into a volume, links them into /workspaces and keeps the
# multi-root .code-workspace file up to date. Runs from the project's root folder.
#
# Three kinds of folders live in /workspaces:
# - the project folder, where this runs: never touched;
# - our links into the volume: created and removed to follow the org's repo list;
# - anything else (mounts, folders you put there): never touched on disk, but listed in the
#   .code-workspace file like the rest.
#
# Always exits 0: if this fails, the devcontainer CLI skips the lifecycle commands after
# it. Errors are printed and the run continues.
set -uo pipefail
on_exit() {
    local rc=$?
    [ "${rc}" -eq 0 ] || echo "[org-workspace] internal error (exit ${rc}), continuing." >&2
    exit 0
}
trap on_exit EXIT

# These can be overridden so the tests can run the script in a sandbox.
OPTIONS_FILE="${H4_ORG_WORKSPACE_OPTIONS:-/usr/local/share/org-workspace/options.env}"
VOLUME_DIR="${H4_ORG_WORKSPACE_VOLUME:-/mnt/h4org-workspace}"
RETRY_DELAY="${H4_ORG_WORKSPACE_RETRY_DELAY:-2}"

PROJECT_DIR="$(pwd)"
WORKSPACES_DIR="$(cd "${PROJECT_DIR}/.." && pwd)"

warn() { echo "[org-workspace] WARN: $*" >&2; }

# retry <attempts> <command...>
# gh is sometimes not ready yet right after the container starts.
retry() {
    local attempts="$1" i
    shift
    for ((i = 1; i <= attempts; i++)); do
        "$@" && return 0
        [ "${i}" -lt "${attempts}" ] && sleep "${RETRY_DELAY}"
    done
    return 1
}

# csv_to_array <csv> <array name>: split on commas, trim, drop empty items.
csv_to_array() {
    local -n _out="$2"
    local -a _raw=()
    local _item
    _out=()
    IFS=',' read -r -a _raw <<<"$1"
    for _item in "${_raw[@]}"; do
        _item="${_item#"${_item%%[![:space:]]*}"}"
        _item="${_item%"${_item##*[![:space:]]}"}"
        [ -n "${_item}" ] && _out+=("${_item}")
    done
}

# list_checkouts <dir>: the git checkouts directly inside <dir>, dot-named ones included.
list_checkouts() {
    local d
    while IFS= read -r d; do
        [ -d "${d}/.git" ] && echo "${d}"
    done < <(find -L "$1" -mindepth 1 -maxdepth 1 -type d -not -name '*.clone-tmp' 2>/dev/null | sort)
}

check_environment() {
    if [ ! -f "${OPTIONS_FILE}" ]; then
        warn "${OPTIONS_FILE} not found, nothing to do."
        exit 0
    fi
    # shellcheck source=/dev/null
    . "${OPTIONS_FILE}"

    if [ ! -d "${VOLUME_DIR}" ]; then
        warn "${VOLUME_DIR} is not mounted, nothing to do."
        exit 0
    fi
    if [ -f /usr/local/share/helpers4/common.sh ]; then
        # shellcheck source=/dev/null
        . /usr/local/share/helpers4/common.sh
        h4_ensure_volume_writable "${VOLUME_DIR}"
    fi
    if [ ! -w "${VOLUME_DIR}" ]; then
        warn "${VOLUME_DIR} is not writable, nothing to do."
        exit 0
    fi

    # install.sh already makes /workspaces writable. This covers hosts that reset it.
    if [ ! -w "${WORKSPACES_DIR}" ]; then
        if ! { command -v sudo >/dev/null 2>&1 && sudo -n chown "$(id -u):$(id -g)" "${WORKSPACES_DIR}" 2>/dev/null; }; then
            warn "cannot write to ${WORKSPACES_DIR}, nothing to do."
            exit 0
        fi
    fi

    if ! command -v gh >/dev/null 2>&1; then
        warn "gh is not installed, nothing to do."
        exit 0
    fi
}

# origin_repo <dir>: prints "<owner>/<repo>" for a GitHub origin remote, nothing otherwise.
origin_repo() {
    local url
    url="$(git -C "$1" remote get-url origin 2>/dev/null)" || return 0
    sed -nE 's#^(https?://([^@/]+@)?|ssh://git@|git@)github\.com[:/]([^/]+)/([^/]+)$#\3/\4#p' <<<"${url%.git}"
}

org_from_gh() {
    ORG="$(cd "${PROJECT_DIR}" && gh repo view --json owner -q .owner.login 2>/dev/null)" && [ -n "${ORG}" ]
}

# resolve_org: sets ORG, and MASTER_REPO, the org repo the project folder holds.
resolve_org() {
    local origin
    origin="$(origin_repo "${PROJECT_DIR}")"
    ORG="${ORG_OPTION}"
    [ -n "${ORG}" ] || ORG="${origin%%/*}"
    if [ -z "${ORG}" ] && ! retry 3 org_from_gh; then
        warn "could not find the org (no GitHub origin remote, and 'gh repo view' failed). Set the 'org' option."
        exit 0
    fi
    # Without a matching origin, the folder name is the best guess.
    MASTER_REPO="$(basename "${PROJECT_DIR}")"
    [ -n "${origin}" ] && [ "${origin%%/*}" = "${ORG}" ] && MASTER_REPO="${origin#*/}"
}

# fetch_org_repos: ORG_REPOS is every repo of the org as JSON, with its status. Empty on failure.
fetch_org_repos() {
    local err
    err="$(mktemp)"
    ORG_REPOS=""
    list_from_gh() {
        ORG_REPOS="$(gh repo list "${ORG}" --limit 1000 --json name,visibility,isFork,isArchived 2>"${err}")" \
            && jq -e 'type == "array"' >/dev/null 2>&1 <<<"${ORG_REPOS}"
    }
    if ! retry 3 list_from_gh; then
        warn "'gh repo list ${ORG}' failed: $(head -c 300 "${err}" | tr '\n' ' ')"
        ORG_REPOS=""
    fi
    rm -f "${err}"
}

# discover_repos: fills REPO_LIST with the org's repos, filtered by the autoDiscover tokens.
discover_repos() {
    local tokens="${AUTO_DISCOVER_OPTION:-true}" token
    [ "${tokens}" = "true" ] && tokens="public,private"

    local -a list visibility=()
    local fork=false archived=false
    csv_to_array "${tokens}" list
    for token in "${list[@]}"; do
        case "${token}" in
            public | private | internal) visibility+=("${token^^}") ;;
            fork) fork=true ;;
            archived) archived=true ;;
            *) warn "unknown autoDiscover value '${token}' (expected public, private, internal, fork or archived)." ;;
        esac
    done

    [ -n "${ORG_REPOS}" ] || return 0
    local found
    found="$(jq -r --argjson fork "${fork}" --argjson archived "${archived}" \
        --args '
        .[]
        | .visibility as $v
        | select(($ARGS.positional | length) == 0 or any($ARGS.positional[]; . == $v))
        | select($fork or (.isFork | not))
        | select($archived or (.isArchived | not))
        | .name' "${visibility[@]}" <<<"${ORG_REPOS}")"
    if [ -z "${found}" ]; then
        warn "'gh repo list ${ORG}' returned no repos. Check your GitHub access and the autoDiscover filters."
        return 0
    fi
    mapfile -t REPO_LIST <<<"${found}"
    REPO_LIST_COMPLETE=true
}

# resolve_repos: fills REPO_LIST with the repos to clone, minus the excluded ones and the project's.
# REPO_LIST_COMPLETE is true when the list can be trusted as "everything we want". Only then
# is it safe to unlink the repos that are not in it.
resolve_repos() {
    REPO_LIST=()
    REPO_LIST_COMPLETE=false
    if [ -n "${REPOS_OPTION}" ]; then
        csv_to_array "${REPOS_OPTION}" REPO_LIST
        [ "${#REPO_LIST[@]}" -gt 0 ] && REPO_LIST_COMPLETE=true
    elif [ "${AUTO_DISCOVER_OPTION}" != "false" ]; then
        discover_repos
    fi

    csv_to_array "${EXCLUDE_OPTION}" EXCLUDE_LIST
    declare -gA EXCLUDED=()
    local name repo
    for name in "${EXCLUDE_LIST[@]}"; do EXCLUDED["${name}"]=1; done

    local -a kept=()
    for repo in "${REPO_LIST[@]}"; do
        [ -z "${repo}" ] || [ -n "${EXCLUDED[${repo}]:-}" ] || [ "${repo}" = "${MASTER_REPO}" ] || kept+=("${repo}")
    done
    REPO_LIST=("${kept[@]}")
}

# is_our_link <path>: true for a link this script made, into the volume.
is_our_link() {
    [ -L "$1" ] && [[ "$(readlink "$1")" == "${VOLUME_DIR}/"* ]]
}

# clone_is_disposable <dir>: true only if git confirms that deleting the clone loses nothing.
# Anything git cannot answer counts as "not disposable".
clone_is_disposable() {
    local dir="$1" out
    # Uncommitted changes and ignored files (.env, dist/...). node_modules can be reinstalled.
    out="$(git -C "${dir}" status --porcelain --ignored 2>/dev/null)" || return 1
    if [ -n "${out}" ] && grep -Evq '^!! (.*/)?node_modules/$' <<<"${out}"; then
        return 1
    fi

    git -C "${dir}" rev-parse -q --verify refs/stash >/dev/null 2>&1 && return 1

    # Commits that no remote has: on a branch, a tag, or a detached HEAD.
    out="$(git -C "${dir}" rev-list -n 1 HEAD --branches --tags --not --remotes 2>/dev/null)" || return 1
    [ -z "${out}" ]
}

# prune_repos: unlinks the repos that are no longer wanted and deletes their clones when that
# is safe. Only our links are touched: the project folder and mounted folders never are.
prune_repos() {
    [ "${REPO_LIST_COMPLETE}" = true ] || return 0
    local -A wanted=()
    local repo path name
    for repo in "${REPO_LIST[@]}"; do wanted["${repo}"]=1; done

    for path in "${WORKSPACES_DIR}"/* "${WORKSPACES_DIR}"/.[!.]*; do
        name="$(basename "${path}")"
        if is_our_link "${path}" && [ -z "${wanted[${name}]:-}" ]; then
            rm -f "${path}" && echo "   unlinked ${name}"
        fi
    done

    while IFS= read -r path; do
        name="$(basename "${path}")"
        [ -n "${wanted[${name}]:-}" ] && continue
        if clone_is_disposable "${path}"; then
            rm -rf "${path}" && echo "   removed ${name}"
        else
            warn "${name} is no longer wanted, but its clone in ${VOLUME_DIR} may hold local work, so it was kept."
        fi
    done < <(list_checkouts "${VOLUME_DIR}")
}

clone_repos() {
    local repo link clone tmp
    local cloned=0 present=0 failed=0
    CLONE_ERR=""

    for repo in "${REPO_LIST[@]}"; do
        link="${WORKSPACES_DIR}/${repo}"
        clone="${VOLUME_DIR}/${repo}"
        tmp="${VOLUME_DIR}/.${repo}.clone-tmp"

        # Our link, still pointing at a clone: nothing to do. Anything else of that name (a mount,
        # a folder, someone's own link) is not ours and is left alone.
        if is_our_link "${link}"; then
            if [ -d "${link}/.git" ]; then
                present=$((present + 1))
                continue
            fi
        elif [ -e "${link}" ] || [ -L "${link}" ]; then
            present=$((present + 1))
            continue
        fi

        if [ ! -d "${clone}/.git" ]; then
            if [ -e "${clone}" ]; then
                warn "${clone} exists but is not a git checkout, skipping ${repo}."
                failed=$((failed + 1))
                continue
            fi
            # Clone next to the target and rename, so an interrupted clone leaves no half folder.
            clone_to_tmp() {
                rm -rf "${tmp}"
                CLONE_ERR="$(gh repo clone "${ORG}/${repo}" "${tmp}" -- --quiet 2>&1 >/dev/null)"
            }
            if ! { retry 2 clone_to_tmp && mv "${tmp}" "${clone}"; }; then
                rm -rf "${tmp}"
                failed=$((failed + 1))
                warn "could not clone ${repo}: ${CLONE_ERR:-unknown error}"
                continue
            fi
        fi

        if ln -sfn "${clone}" "${link}"; then
            cloned=$((cloned + 1))
            echo "   linked ${repo}"
        else
            failed=$((failed + 1))
            warn "could not link ${link}"
        fi
    done

    echo "[org-workspace] ${cloned} linked, ${present} already there, ${failed} failed (org: ${ORG})"
}

# One icon per repo, the first that applies: archived, fork, then visibility.
ICONS='["🌍", "🔒", "🏢", "🔀", "📦"]'
LABELS_JQ='
    map({key: .name, value: ((
        if .isArchived then "📦"
        elif .isFork then "🔀"
        elif .visibility == "PRIVATE" then "🔒"
        elif .visibility == "INTERNAL" then "🏢"
        else "🌍" end) + " " + .name)})
    | from_entries'

# update_workspace: the .code-workspace file lists what is in /workspaces.
# - Entries for /workspaces/<name> follow the disk: added when the folder is a git checkout
#   (cloned or mounted), removed when it is gone or excluded.
# - The project folder's entry is added if missing, never removed.
# - Other entries (outside /workspaces, "uri" entries) are left alone.
# - A folder's name gets its status icon, unless you renamed it: only a missing name, the
#   plain repo name or a name with one of our icons is updated.
# The file is written the way VS Code writes it: tabs, no final newline.
update_workspace() {
    local file="${PROJECT_DIR}/${CODE_WORKSPACE_NAME_OPTION:-${ORG}.code-workspace}"
    local base='{"folders": []}' listed resolved info='[]' kind name

    if [ -e "${file}" ]; then
        if ! jq -e 'type == "object"' "${file}" >/dev/null 2>&1; then
            warn "${file} is not plain JSON (comments?), left as it is."
            return 0
        fi
        base="$(cat "${file}")"
    fi

    # What each existing entry points at. Symlinks are not followed: /workspaces/<name> is the
    # identity of a folder, wherever it really lives.
    while IFS= read -r listed; do
        kind=other name=""
        if [ -n "${listed}" ]; then
            resolved="$(cd "${PROJECT_DIR}" && realpath -m -s -- "${listed}")"
            if [ "${resolved}" = "${PROJECT_DIR}" ]; then
                kind=project
            elif [ "$(dirname "${resolved}")" = "${WORKSPACES_DIR}" ]; then
                kind=sibling name="$(basename "${resolved}")"
            fi
        fi
        info="$(jq -c --arg k "${kind}" --arg n "${name}" '. + [{kind: $k, name: $n}]' <<<"${info}")"
    done < <(jq -r '(.folders // [])[] | .path // ""' <<<"${base}")

    local -a present=()
    local dir
    while IFS= read -r dir; do
        name="$(basename "${dir}")"
        [ "${dir}" = "${PROJECT_DIR}" ] || [ -n "${EXCLUDED[${name}]:-}" ] || present+=("${name}")
    done < <(list_checkouts "${WORKSPACES_DIR}")

    local labels='{}'
    [ -n "${ORG_REPOS}" ] && labels="$(jq -c "${LABELS_JQ}" <<<"${ORG_REPOS}")"

    local new
    if ! new="$(jq --tab --argjson info "${info}" --argjson labels "${labels}" --argjson icons "${ICONS}" \
        --arg project "${MASTER_REPO}" --args '
        def generated($n): . as $name | $name == null or $name == $n or any($icons[]; . + " " + $n == $name);
        def with_name($n):
            if $labels[$n] == null then .
            elif has("name") then (if .name | generated($n) then .name = $labels[$n] else . end)
            else {name: $labels[$n]} + . end;
        . as $doc
        | ($ARGS.positional) as $present
        | (.folders // []) as $folders
        | reduce range(0; $folders | length) as $i ({out: [], seen: {}, project: false};
            $folders[$i] as $e | $info[$i] as $k
            | if $k.kind == "project" then .project = true | .out += [$e | with_name($project)]
              elif $k.kind == "other" then .out += [$e]
              elif any($present[]; . == $k.name) and (.seen[$k.name] | not) then
                  .seen[$k.name] = true | .out += [$e | with_name($k.name)]
              else . end)
        | . as $r
        | ((if $r.project then [] else [{path: "."} | with_name($project)] end)
            + $r.out
            + [$present[] | select($r.seen[.] | not) | . as $n | {path: ("../" + $n)} | with_name($n)]) as $out
        | $doc | .folders = $out
        ' "${present[@]}" <<<"${base}")"; then
        warn "could not update ${file}."
        return 0
    fi
    # A new file starts with the folders only.
    [ -e "${file}" ] || base=""

    if [ "${new}" = "${base}" ]; then
        echo "[org-workspace] ${file} is up to date"
    elif printf '%s' "${new}" >"${file}"; then
        echo "[org-workspace] wrote ${file}"
        echo "[org-workspace] Open it with File > Open Workspace from File..."
    else
        warn "could not write ${file}."
    fi
}

main() {
    check_environment
    resolve_org
    fetch_org_repos
    resolve_repos
    prune_repos
    clone_repos
    if [ "${GENERATE_CODE_WORKSPACE_OPTION}" = "true" ]; then
        update_workspace
    fi
}

main
