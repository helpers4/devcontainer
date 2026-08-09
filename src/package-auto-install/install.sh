#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

set -euo pipefail

# Bootstrap helpers4 shared library. helpers4-common installs it; if running
# standalone (e.g. devcontainer features test), create it inline so the feature
# is self-contained without a GHCR pull.
if [ ! -f /usr/local/share/helpers4/common.sh ]; then
    mkdir -p /usr/local/share/helpers4
    cat > /usr/local/share/helpers4/common.sh << 'H4_COMMON'
# shellcheck shell=bash
h4_detect_user() {
    USERNAME="${USERNAME:-${_REMOTE_USER:-automatic}}"
    if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
        USERNAME=""
        local _uid1000
        _uid1000="$(awk -v val=1000 -F: '$3==val{print $1; exit}' /etc/passwd 2>/dev/null || true)"
        local candidate
        for candidate in vscode node codespace "${_uid1000}"; do
            if [ -n "${candidate}" ] && id -u "${candidate}" >/dev/null 2>&1; then
                USERNAME="${candidate}"; break
            fi
        done
        [ -z "${USERNAME}" ] && USERNAME=root
    elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" >/dev/null 2>&1; then
        USERNAME=root
    fi
    export USERNAME
}
h4_resolve_home() {
    if [ "${USERNAME}" = "root" ]; then
        USER_HOME=/root
    else
        USER_HOME="$(getent passwd "${USERNAME}" 2>/dev/null | cut -d: -f6)"
        [ -n "${USER_HOME}" ] || USER_HOME="/home/${USERNAME}"
    fi
    export USER_HOME
}
h4_apt_update() {
    if [ "$(find /var/lib/apt/lists -maxdepth 1 \( -name '*.lz4' -o -name '*.gz' \) 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y -q
    fi
}
h4_ensure_packages() {
    local missing=() pkg
    for pkg in "$@"; do dpkg -s "${pkg}" >/dev/null 2>&1 || missing+=("${pkg}"); done
    if [ "${#missing[@]}" -gt 0 ]; then
        h4_apt_update
        apt-get install -y -q --no-install-recommends "${missing[@]}"
    fi
}
H4_COMMON
fi
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

h4_ensure_packages jq

echo "🔧 Setting up package-auto-install devcontainer feature..."

# Get options
COMMAND="${COMMAND:-auto}"
PACKAGE_MANAGER="${PACKAGEMANAGER:-auto}"
WORKING_DIR="${WORKINGDIRECTORY:-/workspaces}"
SKIP_IF_EXISTS="${SKIPIFNODEMODULESEXISTS:-false}"
ADDITIONAL_ARGS="${ADDITIONALARGS:-}"
DIRECTORIES="${DIRECTORIES:-}"
AUTO_DISCOVER="${AUTODISCOVER:-false}"

# Create the installation script
cat > /usr/local/bin/devcontainer-package-install << 'EOFSCRIPT'
#!/usr/bin/env bash
set -euo pipefail

# Get configuration from environment or use defaults
COMMAND="${COMMAND:-auto}"
PACKAGE_MANAGER="${PACKAGEMANAGER:-auto}"
WORKING_DIR="${WORKINGDIRECTORY:-/workspaces}"
SKIP_IF_EXISTS="${SKIPIFNODEMODULESEXISTS:-false}"
ADDITIONAL_ARGS="${ADDITIONALARGS:-}"
DIRECTORIES="${DIRECTORIES:-}"
AUTO_DISCOVER="${AUTODISCOVER:-false}"

echo "📦 Starting automatic package installation..."

# ── Directory discovery ────────────────────────────────────────────────────────

# Parse a VS Code / Cursor .code-workspace file; print one resolved path per line
_parse_code_workspace() {
    local wsfile="$1"
    local wsdir folder_path resolved
    wsdir="$(cd "$(dirname "$wsfile")" && pwd)"
    if command -v jq >/dev/null 2>&1; then
        while IFS= read -r folder_path; do
            [ -n "$folder_path" ] || continue
            case "$folder_path" in
                /*) echo "$folder_path" ;;
                *)  resolved="$(realpath -m "$wsdir/$folder_path" 2>/dev/null)" \
                    && echo "$resolved" || echo "$wsdir/$folder_path" ;;
            esac
        done < <(jq -r '.folders[]?.path // empty' "$wsfile" 2>/dev/null)
    else
        while IFS= read -r folder_path; do
            [ -n "$folder_path" ] || continue
            case "$folder_path" in
                /*) echo "$folder_path" ;;
                *)  echo "$wsdir/$folder_path" ;;
            esac
        done < <(
            grep -o '"path"[[:space:]]*:[[:space:]]*"[^"]*"' "$wsfile" 2>/dev/null \
                | sed 's/.*"path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/'
        )
    fi
}

# Parse an IntelliJ modules.xml; print one module root directory per line
_parse_intellij_modules() {
    local modules_xml="$1"
    local project_dir iml_filepath module_dir
    project_dir="$(dirname "$(dirname "$modules_xml")")"  # parent of .idea/
    while IFS= read -r iml_filepath; do
        iml_filepath="${iml_filepath//\$PROJECT_DIR\$/$project_dir}"
        module_dir="$(dirname "$iml_filepath")"
        [ -d "$module_dir" ] && echo "$module_dir"
    done < <(
        grep -o 'filepath="[^"]*"' "$modules_xml" 2>/dev/null \
            | sed 's/filepath="\([^"]*\)"/\1/'
    )
}

# Print all directories to process, one per line.
# DIRECTORIES branch preserves user-specified order; autoDiscover branch deduplicates via sort -u.
_discover_dirs() {
    # 1. Explicit comma-separated list (highest priority)
    if [ -n "$DIRECTORIES" ]; then
        echo "$DIRECTORIES" | tr ',' '\n' \
            | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' \
            | grep -v '^$' || true
        return
    fi

    # 2. Auto-discover from IDE workspace / project files
    if [ "$AUTO_DISCOVER" = "true" ]; then
        local discovered
        discovered="$(
            {
                # VS Code / Cursor: *.code-workspace
                while IFS= read -r wsfile; do
                    _parse_code_workspace "$wsfile"
                done < <(find /workspaces -maxdepth 3 -name "*.code-workspace" 2>/dev/null)

                # IntelliJ IDEA: .idea/modules.xml
                while IFS= read -r modules_xml; do
                    _parse_intellij_modules "$modules_xml"
                done < <(find /workspaces -maxdepth 4 -name "modules.xml" -path "*/.idea/*" 2>/dev/null)
            } | sort -u | grep -v '^$' || true
        )"
        if [ -n "$discovered" ]; then
            echo "$discovered"
            return
        fi
        echo "   ⚠️  autoDiscover: no workspace files found, falling back to workingDirectory" >&2
    fi

    # 3. Fallback: single workingDirectory (original behaviour)
    if [ ! -d "${WORKING_DIR}" ]; then
        if [ -d "/workspaces" ] && [ "$(ls -A /workspaces 2>/dev/null)" ]; then
            WORKING_DIR="/workspaces/$(ls /workspaces | head -n1)"
            echo "   Detected workspace: ${WORKING_DIR}" >&2
        else
            echo "❌ Working directory not found: ${WORKING_DIR}" >&2
            return 1
        fi
    fi
    echo "$WORKING_DIR"
}

# ── Package manager helpers ────────────────────────────────────────────────────

_get_pm_from_json() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.packageManager // empty' package.json 2>/dev/null | cut -d'@' -f1 || true
    else
        grep -o '"packageManager"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null \
            | sed 's/.*"\([^@"]*\)[@"].*/\1/' || true
    fi
}

_setup_corepack() {
    local pm_field
    pm_field="$(_get_pm_from_json)"
    [ -n "$pm_field" ] || return 0
    echo "   Found packageManager: $pm_field" >&2
    if ! command -v corepack >/dev/null 2>&1; then
        echo "   Installing corepack..." >&2
        npm install -g corepack 2>/dev/null || echo "   ⚠️  corepack install failed" >&2
    fi
    command -v corepack >/dev/null 2>&1 \
        && corepack enable 2>/dev/null && echo "   ✅ corepack enabled" >&2
    echo "$pm_field"
}

_detect_pm() {
    local from_json
    from_json="$(_setup_corepack)"
    [ -n "$from_json" ] && echo "$from_json" && return
    [ -f "pnpm-lock.yaml" ]    && echo "pnpm" && return
    [ -f "yarn.lock" ]         && echo "yarn" && return
    [ -f "package-lock.json" ] && echo "npm"  && return
    echo "npm"
}

_get_install_cmd() {
    local pm="$1"
    case "$pm" in
        npm)  [ -f "package-lock.json" ]  && echo "ci"                        || echo "install" ;;
        pnpm) [ -f "pnpm-lock.yaml" ]     && echo "install --frozen-lockfile"  || echo "install" ;;
        yarn)
            local v
            v="$(yarn --version 2>/dev/null | cut -d. -f1)"
            if [ "${v:-0}" -ge 2 ] 2>/dev/null; then
                [ -f "yarn.lock" ] && echo "install --immutable" || echo "install"
            else
                [ -f "yarn.lock" ] && echo "install --frozen-lockfile" || echo "install"
            fi
            ;;
        # nub install delegates to whichever underlying lockfile is present —
        # no separate frozen/CI-safe flag documented, so no lockfile branch
        # here (unlike npm/pnpm/yarn above); revisit if nub adds one.
        nub) echo "install" ;;
        *) echo "install" ;;
    esac
}

# ── Install in a single directory ─────────────────────────────────────────────

_install_in_dir() {
    local dir="$1"
    local pm cmd
    if [ ! -d "$dir" ]; then
        echo "   ⚠️  Not found: $dir — skipping"
        return 0
    fi
    (
        cd "$dir" || exit 1
        if [ ! -f "package.json" ]; then
            echo "   ℹ️  No package.json in $dir — skipping"
            exit 0
        fi
        if [ "$SKIP_IF_EXISTS" = "true" ] && [ -d "node_modules" ]; then
            echo "   ✅ node_modules exists in $dir — skipping"
            exit 0
        fi
        pm="$PACKAGE_MANAGER"
        [ "$pm" = "auto" ] && pm="$(_detect_pm)"
        if ! command -v "$pm" >/dev/null 2>&1; then
            echo "   ❌ Package manager '$pm' not found in $dir"
            exit 1
        fi
        cmd="$COMMAND"
        [ "$cmd" = "auto" ] && cmd="$(_get_install_cmd "$pm")"
        echo "   🚀 [$dir] → $pm $cmd ${ADDITIONAL_ARGS}"
        # shellcheck disable=SC2086
        if $pm $cmd $ADDITIONAL_ARGS; then
            echo "   ✅ [$dir] done"
        else
            echo "   ❌ [$dir] failed"
            exit 1
        fi
    )
}

# ── Main ──────────────────────────────────────────────────────────────────────

export CI=true

mapfile -t DIRS < <(_discover_dirs)

if [ "${#DIRS[@]}" -eq 0 ]; then
    echo "❌ No directories to install in"
    exit 1
fi

if [ "${#DIRS[@]}" -gt 1 ]; then
    echo "   Directories (${#DIRS[@]}):"
    for d in "${DIRS[@]}"; do echo "   → $d"; done
    echo ""
else
    echo "   Working directory: ${DIRS[0]}"
fi

FAILED=0
for dir in "${DIRS[@]}"; do
    _install_in_dir "$dir" || FAILED=$((FAILED + 1))
done

echo ""
if [ "$FAILED" -eq 0 ]; then
    echo "✅ Package installation complete"
else
    echo "❌ Package installation complete with $FAILED failure(s)"
    exit 1
fi
EOFSCRIPT

# Make the script executable
chmod +x /usr/local/bin/devcontainer-package-install

# Store configuration in environment for the script
cat >> /etc/environment << EOF
COMMAND=${COMMAND}
PACKAGEMANAGER=${PACKAGE_MANAGER}
WORKINGDIRECTORY="${WORKING_DIR}"
SKIPIFNODEMODULESEXISTS=${SKIP_IF_EXISTS}
ADDITIONALARGS="${ADDITIONAL_ARGS}"
DIRECTORIES="${DIRECTORIES}"
AUTODISCOVER=${AUTO_DISCOVER}
EOF

echo "✅ package-auto-install feature installed"
echo "   The installation will run automatically after container creation"
