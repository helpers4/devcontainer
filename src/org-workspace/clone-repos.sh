#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at container START (postStartCommand) — clones every target repo into the persistent
# named volume mounted at /mnt/h4org-workspace, symlinks each into a sibling /workspaces
# folder (so a rebuild doesn't lose uncommitted local changes — only the volume, not the
# symlink, needs to survive), and generates/merges a multi-root .code-workspace file at the
# bootstrap repo's own root (so it's committable and shareable with the rest of the org).
#
# Never fails the attach: a non-zero exit from a Feature's postStartCommand makes the
# devcontainer CLI skip every lifecycle command that follows it, for every other Feature and
# for the project's own too. So there is deliberately no `set -e`, every step that can fail is
# handled where it happens (counted and warned about, never fatal), and the EXIT trap below is
# the backstop for anything unforeseen — including an unbound variable under `set -u`.
set -uo pipefail
trap 'exit 0' EXIT

# Baked in by install.sh (feature options are only available as env vars during install, not
# later when postStartCommand runs). Both paths are overridable so tests can run this script
# against a sandbox instead of the real /usr/local/share and /mnt.
OPTIONS_FILE="${H4_ORG_WORKSPACE_OPTIONS:-/usr/local/share/org-workspace/options.env}"
STAGED="${H4_ORG_WORKSPACE_STAGED:-/mnt/h4org-workspace}"
RETRY_DELAY="${H4_ORG_WORKSPACE_RETRY_DELAY:-2}"

ORG_OPTION=""
REPOS_OPTION=""
AUTO_DISCOVER_OPTION="true"
EXCLUDE_OPTION=""
GENERATE_CODE_WORKSPACE_OPTION="true"
CODE_WORKSPACE_NAME_OPTION=""

warn() { echo "[org-workspace] WARN: $*" >&2; }

# retry <attempts> <command...> — a fresh container start often races gh's own auth/network
# readiness, so one transient failure shouldn't decide "nothing to clone".
retry() {
    local attempts="$1" i
    shift
    for ((i = 1; i <= attempts; i++)); do
        "$@" && return 0
        [ "${i}" -lt "${attempts}" ] && sleep "${RETRY_DELAY}"
    done
    return 1
}

trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "${s}"
}

# csv_to_array <csv> <array-name> — trimmed, empty items dropped.
csv_to_array() {
    local -n _out="$2"
    local -a _raw=()
    local _item
    _out=()
    IFS=',' read -r -a _raw <<<"$1"
    for _item in "${_raw[@]}"; do
        _item="$(trim "${_item}")"
        [ -n "${_item}" ] && _out+=("${_item}")
    done
}

if [ -f "${OPTIONS_FILE}" ]; then
    # shellcheck source=/dev/null
    . "${OPTIONS_FILE}"
else
    warn "${OPTIONS_FILE} not found (was install.sh run?) — using defaults."
fi

BOOTSTRAP_DIR="$(pwd)"
WORKSPACE_ROOT="$(cd "${BOOTSTRAP_DIR}/.." && pwd)"

if [ ! -d "${STAGED}" ]; then
    warn "${STAGED} not mounted — nothing to clone into, skipping."
    exit 0
fi

if [ -f /usr/local/share/helpers4/common.sh ]; then
    # shellcheck source=/dev/null
    . /usr/local/share/helpers4/common.sh
    # This volume is exclusive to this devcontainer (keyed by ${devcontainerId} — see
    # devcontainer-feature.json), so no --shared: no other container can be concurrently using it.
    h4_ensure_volume_writable "${STAGED}"
fi
if [ ! -w "${STAGED}" ]; then
    warn "${STAGED} is not writable — skipping."
    exit 0
fi

# install.sh chowns /workspaces to the remote user at build time; this covers images/hosts
# where that didn't stick (e.g. Codespaces provisioning its own /workspaces).
if [ ! -w "${WORKSPACE_ROOT}" ]; then
    if ! { command -v sudo >/dev/null 2>&1 && sudo -n chown "$(id -u):$(id -g)" "${WORKSPACE_ROOT}" 2>/dev/null; }; then
        warn "${WORKSPACE_ROOT} is not writable by $(id -un) and sudo is unavailable — cannot create sibling links, skipping."
        exit 0
    fi
fi

if ! command -v gh >/dev/null 2>&1; then
    warn "gh CLI not found (is github-dev installed?) — skipping."
    exit 0
fi

# ── Resolve the org ──────────────────────────────────────────────────────────
ORG="${ORG_OPTION}"
detect_org() {
    ORG="$(cd "${BOOTSTRAP_DIR}" && gh repo view --json owner -q .owner.login 2>/dev/null)" && [ -n "${ORG}" ]
}
if [ -z "${ORG}" ] && ! retry 3 detect_org; then
    warn "could not auto-detect the org from ${BOOTSTRAP_DIR}'s origin remote, and no 'org' option was set — skipping."
    exit 0
fi

# ── Resolve the repo list ────────────────────────────────────────────────────
# An explicit 'repos' always wins over 'autoDiscover'.
REPO_LIST=()
# Set only when REPO_LIST is a list we can trust as "everything wanted" — an explicit 'repos',
# or a discovery that actually succeeded. Pruning below is gated on it: a transient
# `gh repo list` failure must never look like "the org has no repos any more".
LIST_RELIABLE=false
if [ -n "${REPOS_OPTION}" ]; then
    csv_to_array "${REPOS_OPTION}" REPO_LIST
    LIST_RELIABLE=true
elif [ "${AUTO_DISCOVER_OPTION}" != "false" ]; then
    TOKENS="${AUTO_DISCOVER_OPTION:-true}"
    [ "${TOKENS}" = "true" ] && TOKENS="public,private"

    _has_token() {
        case ",${TOKENS}," in *",$1,"*) return 0 ;; *) return 1 ;; esac
    }

    GH_LIST_ARGS=(--limit 1000 --json name -q '.[].name')

    # --visibility only accepts one value — only pass it when exactly one of
    # public/private/internal was requested; any other combination (multiple, or none of the
    # three) means "no visibility filter", matching gh's own default of "whatever your auth can
    # see".
    VIS_COUNT=0
    _has_token public && VIS_COUNT=$((VIS_COUNT + 1))
    _has_token private && VIS_COUNT=$((VIS_COUNT + 1))
    _has_token internal && VIS_COUNT=$((VIS_COUNT + 1))
    if [ "${VIS_COUNT}" -eq 1 ]; then
        _has_token public && GH_LIST_ARGS+=(--visibility public)
        _has_token private && GH_LIST_ARGS+=(--visibility private)
        _has_token internal && GH_LIST_ARGS+=(--visibility internal)
    fi

    _has_token fork || GH_LIST_ARGS+=(--source)
    _has_token archived || GH_LIST_ARGS+=(--no-archived)

    DISCOVERED=""
    discover() { DISCOVERED="$(gh repo list "${ORG}" "${GH_LIST_ARGS[@]}" 2>/dev/null)"; }
    if retry 3 discover; then
        mapfile -t REPO_LIST <<<"${DISCOVERED}"
        LIST_RELIABLE=true
    else
        warn "'gh repo list ${ORG}' failed after 3 attempts — nothing discovered."
    fi
fi

# ── Apply 'exclude' (to explicit and discovered lists alike) ─────────────────
EXCLUDE_LIST=()
csv_to_array "${EXCLUDE_OPTION}" EXCLUDE_LIST
declare -A EXCLUDED=()
for name in "${EXCLUDE_LIST[@]}"; do EXCLUDED["${name}"]=1; done

FILTERED=()
for repo in "${REPO_LIST[@]}"; do
    [ -z "${repo}" ] && continue
    [ -n "${EXCLUDED[${repo}]:-}" ] && continue
    FILTERED+=("${repo}")
done
REPO_LIST=("${FILTERED[@]}")

# ── Prune what is no longer wanted ───────────────────────────────────────────
# Anything this Feature cloned into the volume that isn't in the final list any more — newly
# excluded, archived, deleted from the org, dropped from 'repos' — loses its symlink and its
# .code-workspace entry. The clone itself is only deleted when nothing could be lost with it
# (no uncommitted change, no commit that exists nowhere else, no stash); otherwise it stays in
# the volume with a warning.
declare -A WANTED=()
for repo in "${REPO_LIST[@]}"; do WANTED["${repo}"]=1; done

# Names to drop from an existing .code-workspace: everything excluded, plus what gets pruned.
UNLISTED=("${EXCLUDE_LIST[@]}")

clone_is_disposable() {
    local dir="$1"
    [ -z "$(git -C "${dir}" status --porcelain 2>/dev/null)" ] || return 1
    [ -z "$(git -C "${dir}" stash list 2>/dev/null)" ] || return 1
    [ -z "$(git -C "${dir}" log --branches --not --remotes --oneline -1 2>/dev/null)" ] || return 1
}

prune_repo() {
    local name="$1" dir="${STAGED}/$1" link="${WORKSPACE_ROOT}/$1"
    if [ -L "${link}" ] && [[ "$(readlink "${link}")" == "${STAGED}/"* ]]; then
        rm -f "${link}" && UNLISTED+=("${name}")
    fi
    if [ -d "${dir}/.git" ]; then
        if clone_is_disposable "${dir}"; then
            rm -rf "${dir}" && echo "   ➖ ${name}: no longer wanted, removed"
        else
            warn "${name}: no longer wanted but its clone in ${STAGED} has local changes or unpushed commits — kept."
        fi
    fi
}

if [ "${LIST_RELIABLE}" = true ]; then
    for dir in "${STAGED}"/*/; do
        [ -d "${dir}/.git" ] || continue
        name="$(basename "${dir}")"
        [ -n "${WANTED[${name}]:-}" ] || prune_repo "${name}"
    done
fi
# An excluded repo may be linked while never having been cloned by this Feature (an old link).
for name in "${EXCLUDE_LIST[@]}"; do
    [ -n "${WANTED[${name}]:-}" ] && continue
    link="${WORKSPACE_ROOT}/${name}"
    if [ -L "${link}" ] && [[ "$(readlink "${link}")" == "${STAGED}/"* ]]; then
        rm -f "${link}"
    fi
done

if [ "${#REPO_LIST[@]}" -eq 0 ]; then
    echo "[org-workspace] No repos to clone (none configured/discovered, or all excluded)."
fi

# ── Clone (or re-link an already-cloned) repo, skip anything already present ────────────────
CLONED=0
SKIPPED=0
FAILED=0
CLONE_ERR=""

for repo in "${REPO_LIST[@]}"; do
    TARGET_LINK="${WORKSPACE_ROOT}/${repo}"
    VOLUME_DIR="${STAGED}/${repo}"
    TMP_DIR="${STAGED}/.${repo}.clone-tmp"

    if [ -e "${TARGET_LINK}" ]; then
        # Already present — a prior run's symlink, or a bind-mount/manual clone someone else
        # already set up. Never overwrite an existing directory here.
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [ ! -d "${VOLUME_DIR}/.git" ]; then
        if [ -e "${VOLUME_DIR}" ]; then
            # Not ours to delete (an older, non-atomic run's half-clone, or user data).
            warn "${VOLUME_DIR} exists without a .git — not touching it, skipping ${repo}."
            FAILED=$((FAILED + 1))
            continue
        fi

        # Clone next to the destination, then rename: a clone interrupted by a container
        # stop never leaves a half-populated ${VOLUME_DIR} that the check above would later
        # mistake for a finished one.
        clone_one() {
            rm -rf "${TMP_DIR}"
            CLONE_ERR="$(gh repo clone "${ORG}/${repo}" "${TMP_DIR}" -- --quiet 2>&1 >/dev/null)"
        }
        if ! { retry 2 clone_one && mv "${TMP_DIR}" "${VOLUME_DIR}"; }; then
            rm -rf "${TMP_DIR}"
            FAILED=$((FAILED + 1))
            warn "${repo}: clone failed — ${CLONE_ERR:-unknown error} (no access, or repo doesn't exist)"
            continue
        fi
    fi

    if ln -sfn "${VOLUME_DIR}" "${TARGET_LINK}"; then
        CLONED=$((CLONED + 1))
        echo "   ✅ ${repo}"
    else
        FAILED=$((FAILED + 1))
        warn "${repo}: could not create symlink ${TARGET_LINK}"
    fi
done

echo "[org-workspace] ${CLONED} cloned/linked, ${SKIPPED} already present, ${FAILED} failed (org: ${ORG})"

# ── Generate or update the multi-root .code-workspace file ──────────────────────────────────
update_code_workspace() {
    local ws_name="${CODE_WORKSPACE_NAME_OPTION:-${ORG}.code-workspace}"
    local ws_path="${BOOTSTRAP_DIR}/${ws_name}"

    # Every direct subdirectory of WORKSPACE_ROOT that looks like a real git checkout — covers
    # the bootstrap repo itself, anything pre-existing (bind-mounts, manual clones), and
    # whatever this run just cloned/linked, without depending on this run's own repo list (a
    # prior run, or a manual addition, may have folders this run never touched).
    # `find -L ... -type d` rather than a bash glob: a bare `*/` glob skips dot-prefixed
    # directories (e.g. a real org repo named ".github" or ".dev") unless dotglob is set, and
    # plain `find` (without -L) reports our own symlinks into the volume as type "l", not "d".
    local -a dirs=()
    local dir
    while IFS= read -r dir; do
        [ -d "${dir}/.git" ] || continue
        [ -n "${EXCLUDED[$(basename "${dir}")]:-}" ] && continue
        dirs+=("${dir}")
    done < <(find -L "${WORKSPACE_ROOT}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort)

    local existing=false
    if [ -e "${ws_path}" ]; then
        # VS Code accepts comments/trailing commas in a .code-workspace; jq doesn't. Never
        # replace a file we can't parse — it's the user's, and possibly hand-edited.
        if ! jq -e 'type == "object"' "${ws_path}" >/dev/null 2>&1; then
            warn "${ws_path} exists but isn't plain JSON (comments?) — left untouched."
            return 0
        fi
        existing=true
    fi

    # Folders already listed, compared by resolved path — "." and "../.dev" are the same
    # folder, and a string comparison would list it twice. Relative paths in the file are
    # relative to the file's own directory, i.e. BOOTSTRAP_DIR.
    local -A have=()
    local p
    if [ "${existing}" = true ]; then
        while IFS= read -r p; do
            [ -z "${p}" ] && continue
            case "${p}" in /*) ;; *) p="${BOOTSTRAP_DIR}/${p}" ;; esac
            have["$(realpath -m -- "${p}")"]=1
        done < <(jq -r '(.folders // [])[] | .path // empty' "${ws_path}" 2>/dev/null)
    fi

    local new_json="[]" rp
    for dir in "${dirs[@]}"; do
        rp="$(realpath -- "${dir}")"
        [ -n "${have[${rp}]:-}" ] && continue
        have["${rp}"]=1
        new_json="$(jq -c --arg p "../$(basename "${dir}")" '. + [{"path": $p}]' <<<"${new_json}")"
    done

    if [ "${existing}" = false ]; then
        jq -n --argjson folders "${new_json}" '{folders: $folders}' >"${ws_path}" \
            && echo "[org-workspace] Generated ${ws_path}" \
            || warn "could not write ${ws_path}"
    else
        local ex_json="[]" name
        for name in "${UNLISTED[@]}"; do
            ex_json="$(jq -c --arg n "${name}" '. + [$n]' <<<"${ex_json}")"
        done

        # Match the file's own indentation and trailing-newline habit, so a hand-formatted
        # (tabs, 4 spaces, ...) committed file doesn't turn into a whole-file diff.
        local -a indent=(--indent 2)
        if grep -q "$(printf '^\t')" "${ws_path}"; then
            indent=(--tab)
        else
            local n
            n="$(grep -m1 -o '^ \+' "${ws_path}" | head -1 | awk '{print length}')"
            [ -n "${n}" ] && [ "${n}" -ge 1 ] && [ "${n}" -le 7 ] && indent=(--indent "${n}")
        fi

        local tmp="${ws_path}.tmp"
        # Existing entries for excluded or just-pruned repos are dropped; every other key and
        # entry — names, emoji, settings — is left as it was.
        if ! jq "${indent[@]}" --argjson new "${new_json}" --argjson ex "${ex_json}" '
                .folders = (
                    ((.folders // []) | map(select(((.path // "") | split("/") | .[-1]) as $b | ($ex | index($b)) | not)))
                    + $new
                )' "${ws_path}" >"${tmp}"; then
            rm -f "${tmp}"
            warn "could not update ${ws_path}"
            return 0
        fi
        if [ -n "$(tail -c1 "${ws_path}")" ]; then
            printf '%s' "$(cat "${tmp}")" >"${tmp}.nonl" && mv "${tmp}.nonl" "${tmp}"
        fi
        if cmp -s "${tmp}" "${ws_path}"; then
            rm -f "${tmp}"
            echo "[org-workspace] ${ws_path} already up to date"
        else
            # cat rather than mv: keeps the file's own inode and permissions.
            cat "${tmp}" >"${ws_path}" && rm -f "${tmp}" \
                && echo "[org-workspace] Updated ${ws_path} (merged folders, other settings untouched)" \
                || warn "could not write ${ws_path}"
        fi
    fi

    echo "[org-workspace] To switch VS Code to it: File > Open Workspace from File... -> ${ws_path}"
}

if [ "${GENERATE_CODE_WORKSPACE_OPTION}" = "true" ]; then
    update_code_workspace
fi

exit 0
