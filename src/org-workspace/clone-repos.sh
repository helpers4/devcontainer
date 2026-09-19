#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Clones the org's repos into a volume, links them into /workspaces and keeps the
# multi-root .code-workspace file up to date. Runs from the project's root folder.
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

org_from_origin() {
    local url
    url="$(git -C "${PROJECT_DIR}" remote get-url origin 2>/dev/null)" || return 1
    ORG="$(sed -nE 's#^(https?://([^@/]+@)?|ssh://git@|git@)github\.com[:/]([^/]+)/[^/]+$#\3#p' <<<"${url}")"
    [ -n "${ORG}" ]
}

org_from_gh() {
    ORG="$(cd "${PROJECT_DIR}" && gh repo view --json owner -q .owner.login 2>/dev/null)" && [ -n "${ORG}" ]
}

resolve_org() {
    ORG="${ORG_OPTION}"
    [ -n "${ORG}" ] && return 0
    org_from_origin && return 0
    retry 3 org_from_gh && return 0
    warn "could not find the org (no GitHub origin remote, and 'gh repo view' failed). Set the 'org' option."
    exit 0
}

# discover_repos: fills REPO_LIST with the org's repos, filtered by the autoDiscover tokens.
discover_repos() {
    local tokens="${AUTO_DISCOVER_OPTION:-true}" token visibility=0
    [ "${tokens}" = "true" ] && tokens="public,private"

    local -a list
    csv_to_array "${tokens}" list
    for token in "${list[@]}"; do
        case "${token}" in
            public | private | internal) visibility=$((visibility + 1)) ;;
            fork | archived) ;;
            *) warn "unknown autoDiscover value '${token}' (expected public, private, internal, fork or archived)." ;;
        esac
    done
    has_token() { [[ ",${tokens}," == *",$1,"* ]]; }

    # gh takes a single --visibility. With several (or none), it lists everything you can see.
    local -a args=(--limit 1000 --json name -q '.[].name')
    if [ "${visibility}" -eq 1 ]; then
        for token in public private internal; do
            has_token "${token}" && args+=(--visibility "${token}")
        done
    fi
    has_token fork || args+=(--source)
    has_token archived || args+=(--no-archived)

    local found=""
    list_from_gh() { found="$(gh repo list "${ORG}" "${args[@]}" 2>/dev/null)"; }
    if ! retry 3 list_from_gh; then
        warn "'gh repo list ${ORG}' failed, no repos discovered."
        return 0
    fi
    if [ -z "${found}" ]; then
        warn "'gh repo list ${ORG}' returned no repos. Check your GitHub access and the autoDiscover filters."
        return 0
    fi
    mapfile -t REPO_LIST <<<"${found}"
    REPO_LIST_COMPLETE=true
}

# resolve_repos: fills REPO_LIST, minus the excluded repos.
# REPO_LIST_COMPLETE is true when the list can be trusted as "everything we want". Only then
# is it safe to remove the repos that are not in it.
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
        [ -z "${repo}" ] || [ -n "${EXCLUDED[${repo}]:-}" ] || kept+=("${repo}")
    done
    REPO_LIST=("${kept[@]}")
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

# prune_repo <name>: unlink a repo that is no longer wanted and delete its clone if that is safe.
prune_repo() {
    local name="$1" link="${WORKSPACES_DIR}/$1" clone="${VOLUME_DIR}/$1"
    if [ -L "${link}" ] && [[ "$(readlink "${link}")" == "${VOLUME_DIR}/"* ]]; then
        rm -f "${link}" && DROPPED+=("${name}")
    fi
    if clone_is_disposable "${clone}"; then
        rm -rf "${clone}" && echo "   removed ${name}"
    else
        warn "${name} is no longer wanted, but its clone in ${VOLUME_DIR} may hold local work, so it was kept."
    fi
}

prune_repos() {
    [ "${REPO_LIST_COMPLETE}" = true ] || return 0
    local -A wanted=()
    local repo dir
    for repo in "${REPO_LIST[@]}"; do wanted["${repo}"]=1; done
    while IFS= read -r dir; do
        [ -n "${wanted[$(basename "${dir}")]:-}" ] || prune_repo "$(basename "${dir}")"
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

        # Never touch what is already there: our own link, or a folder someone put there.
        if [ -e "${link}" ]; then
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

# update_workspace: adds the missing folders to the .code-workspace file, removes the ones that
# were excluded or pruned, and leaves everything else (names, settings) alone.
# The file is written the way VS Code writes it: tabs, no final newline.
update_workspace() {
    local file="${PROJECT_DIR}/${CODE_WORKSPACE_NAME_OPTION:-${ORG}.code-workspace}"
    local base='{}' listed dir path
    local -A known=()

    if [ -e "${file}" ]; then
        if ! jq -e 'type == "object"' "${file}" >/dev/null 2>&1; then
            warn "${file} is not plain JSON (comments?), left as it is."
            return 0
        fi
        base="$(cat "${file}")"
        # Compare resolved paths: "." and "../.dev" are the same folder.
        while IFS= read -r listed; do
            [ -n "${listed}" ] && known["$(cd "${PROJECT_DIR}" && realpath -m -- "${listed}")"]=1
        done < <(jq -r '.folders[]?.path // empty' "${file}")
    fi

    local add='[]'
    while IFS= read -r dir; do
        [ -n "${EXCLUDED[$(basename "${dir}")]:-}" ] && continue
        path="$(realpath -- "${dir}")"
        [ -n "${known[${path}]:-}" ] && continue
        known["${path}"]=1
        add="$(jq -c --arg p "../$(basename "${dir}")" '. + [{path: $p}]' <<<"${add}")"
    done < <(list_checkouts "${WORKSPACES_DIR}")

    local drop
    drop="$(printf '%s\n' "${EXCLUDE_LIST[@]}" "${DROPPED[@]}" | jq -R . | jq -sc 'map(select(length > 0))')"

    local new
    if ! new="$(jq --tab --argjson add "${add}" --argjson drop "${drop}" '
        .folders = (
            [(.folders // [])[] | select(((.path // "") | split("/") | .[-1]) as $name | ($drop | index($name)) | not)]
            + $add
        )' <<<"${base}")"; then
        warn "could not update ${file}."
        return 0
    fi

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
    DROPPED=()
    resolve_repos
    prune_repos
    clone_repos
    if [ "${GENERATE_CODE_WORKSPACE_OPTION}" = "true" ]; then
        update_workspace
    fi
}

main
