#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Installs org-workspace: generates a postStartCommand script that clones every target repo of
# a GitHub org into a persistent named volume, symlinks each into a sibling /workspaces folder,
# and generates/merges a multi-root .code-workspace file at the bootstrap repo's own root.

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root.'
    exit 1
fi

h4_ensure_packages jq

# Feature options — env var names are the option id uppercased (devcontainers CLI convention).
ORG_OPTION="${ORG:-}"
REPOS_OPTION="${REPOS:-}"
AUTO_DISCOVER_OPTION="${AUTODISCOVER:-false}"
GENERATE_CODE_WORKSPACE_OPTION="${GENERATECODEWORKSPACE:-true}"
CODE_WORKSPACE_NAME_OPTION="${CODEWORKSPACENAME:-}"

SCRIPT="/usr/local/share/org-workspace/clone-repos.sh"
mkdir -p "$(dirname "${SCRIPT}")"

# Header with the resolved, feature-scoped option values — baked in now since feature options
# are only available as env vars during this install.sh run, not later when postStartCommand
# actually executes the generated script.
{
    cat <<'HEADER'
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
# Best-effort: never fails the attach. A repo that can't be resolved or cloned is warned about
# and skipped, not treated as fatal for the rest of the run.
set -euo pipefail
HEADER
    printf 'ORG_OPTION=%q\n' "${ORG_OPTION}"
    printf 'REPOS_OPTION=%q\n' "${REPOS_OPTION}"
    printf 'AUTO_DISCOVER_OPTION=%q\n' "${AUTO_DISCOVER_OPTION}"
    printf 'GENERATE_CODE_WORKSPACE_OPTION=%q\n' "${GENERATE_CODE_WORKSPACE_OPTION}"
    printf 'CODE_WORKSPACE_NAME_OPTION=%q\n' "${CODE_WORKSPACE_NAME_OPTION}"
} >"${SCRIPT}"

# Body (literal — not expanded at install time).
cat >>"${SCRIPT}" <<'EOF'

STAGED="/mnt/h4org-workspace"
BOOTSTRAP_DIR="$(pwd)"
WORKSPACE_ROOT="$(cd "${BOOTSTRAP_DIR}/.." && pwd)"

if [ ! -d "${STAGED}" ]; then
    echo "[org-workspace] WARN: ${STAGED} not mounted — nothing to clone into, skipping." >&2
    exit 0
fi

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

# This volume is exclusive to this devcontainer (keyed by ${devcontainerId} — see
# devcontainer-feature.json), so no --shared: no other container can be concurrently using it.
h4_ensure_volume_writable "${STAGED}"

if ! command -v gh >/dev/null 2>&1; then
    echo "[org-workspace] WARN: gh CLI not found (is github-dev installed?) — skipping." >&2
    exit 0
fi

# ── Resolve the org ──────────────────────────────────────────────────────────
ORG="${ORG_OPTION}"
if [ -z "${ORG}" ]; then
    ORG="$(cd "${BOOTSTRAP_DIR}" && gh repo view --json owner -q .owner.login 2>/dev/null || true)"
    if [ -z "${ORG}" ]; then
        echo "[org-workspace] WARN: could not auto-detect the org from ${BOOTSTRAP_DIR}'s origin remote, and no 'org' option was set — skipping." >&2
        exit 0
    fi
fi

# ── Resolve the repo list ────────────────────────────────────────────────────
REPO_LIST=()
if [ -n "${REPOS_OPTION}" ]; then
    IFS=',' read -r -a REPO_LIST <<<"${REPOS_OPTION}"
elif [ -n "${AUTO_DISCOVER_OPTION}" ] && [ "${AUTO_DISCOVER_OPTION}" != "false" ]; then
    TOKENS="${AUTO_DISCOVER_OPTION}"
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

    mapfile -t REPO_LIST < <(gh repo list "${ORG}" "${GH_LIST_ARGS[@]}" 2>/dev/null || true)
fi

if [ "${#REPO_LIST[@]}" -eq 0 ]; then
    echo "[org-workspace] No repos configured (set 'repos' or 'autoDiscover') or discovered — nothing to clone."
    exit 0
fi

# ── Clone (or re-link an already-cloned) repo, skip anything already present ────────────────
CLONED=0
SKIPPED=0
FAILED=0

for repo in "${REPO_LIST[@]}"; do
    [ -z "${repo}" ] && continue
    TARGET_LINK="${WORKSPACE_ROOT}/${repo}"
    VOLUME_DIR="${STAGED}/${repo}"

    if [ -e "${TARGET_LINK}" ]; then
        # Already present — a prior run's symlink, or a bind-mount/manual clone someone else
        # already set up. Never overwrite an existing directory here.
        SKIPPED=$((SKIPPED + 1))
        continue
    fi

    if [ -d "${VOLUME_DIR}/.git" ]; then
        # Cloned on a prior run (volume persisted across a rebuild); only the symlink is gone.
        ln -sfn "${VOLUME_DIR}" "${TARGET_LINK}"
        CLONED=$((CLONED + 1))
        continue
    fi

    if gh repo clone "${ORG}/${repo}" "${VOLUME_DIR}" -- --quiet 2>/dev/null; then
        ln -sfn "${VOLUME_DIR}" "${TARGET_LINK}"
        CLONED=$((CLONED + 1))
        echo "   ✅ ${repo}: cloned"
    else
        FAILED=$((FAILED + 1))
        echo "   ⚠️  ${repo}: clone failed (no access, or repo doesn't exist)" >&2
    fi
done

echo "[org-workspace] ${CLONED} cloned/linked, ${SKIPPED} already present, ${FAILED} failed (org: ${ORG})"

# ── Generate or update the multi-root .code-workspace file ──────────────────────────────────
if [ "${GENERATE_CODE_WORKSPACE_OPTION}" = "true" ]; then
    WS_NAME="${CODE_WORKSPACE_NAME_OPTION}"
    [ -z "${WS_NAME}" ] && WS_NAME="${ORG}.code-workspace"
    WS_PATH="${BOOTSTRAP_DIR}/${WS_NAME}"

    # Every direct subdirectory of WORKSPACE_ROOT that looks like a real git checkout — covers
    # the bootstrap repo itself, anything pre-existing (bind-mounts, manual clones), and
    # whatever this run just cloned/linked, without depending on this run's own repo list (a
    # prior run, or a manual addition, may have folders this run never touched).
    # `find -L ... -type d` rather than a bash glob: a bare `*/` glob skips dot-prefixed
    # directories (e.g. a real org repo named ".github" or ".dev") unless dotglob is set, and
    # plain `find` (without -L) reports our own symlinks into the volume as type "l", not "d".
    FOLDERS_JSON="[]"
    while IFS= read -r dir; do
        [ -d "${dir}/.git" ] || continue
        name="$(basename "${dir}")"
        FOLDERS_JSON="$(printf '%s' "${FOLDERS_JSON}" | jq --arg p "../${name}" '. + [{"path": $p}]')"
    done < <(find -L "${WORKSPACE_ROOT}" -mindepth 1 -maxdepth 1 -type d)

    if [ -f "${WS_PATH}" ] && jq empty "${WS_PATH}" 2>/dev/null; then
        # Existing valid workspace file (possibly hand-edited, or committed by a teammate) —
        # merge folder paths into it, deduplicated, leaving every other key (settings,
        # extensions, launch, ...) untouched.
        jq --argjson new "${FOLDERS_JSON}" \
            '.folders = ((.folders // []) + $new | unique_by(.path))' \
            "${WS_PATH}" >"${WS_PATH}.tmp" && mv "${WS_PATH}.tmp" "${WS_PATH}"
        echo "[org-workspace] Updated ${WS_PATH} (merged folders, other settings untouched)"
    else
        jq -n --argjson folders "${FOLDERS_JSON}" '{folders: $folders}' >"${WS_PATH}"
        echo "[org-workspace] Generated ${WS_PATH}"
    fi

    echo "[org-workspace] To switch VS Code to it: File > Open Workspace from File... -> ${WS_PATH}"
fi
EOF

chmod +x "${SCRIPT}"
echo "  ✅ Installed ${SCRIPT}"
