#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME — the named volume is NOT attached yet.
# Points the target user's bash, zsh and fish history at /mnt/h4history, where
# Docker attaches the volume at container creation, before any shell starts.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

MAX_HISTORY_SIZE="${MAXHISTORYSIZE:-10000}"

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

# USERNAME is injected by the devcontainer CLI from the 'username' feature option.
USERNAME="${USERNAME:-"automatic"}"
h4_detect_user
h4_resolve_home

case "${MAX_HISTORY_SIZE}" in
    '' | *[!0-9]*)
        echo "(!) maxHistorySize must be a whole number, got '${MAX_HISTORY_SIZE}'" >&2
        exit 1
        ;;
esac

STAGED="/mnt/h4history"
USER_GROUP="$(id -gn "${USERNAME}" 2>/dev/null || echo "${USERNAME}")"
MARK_BEGIN="# >>> helpers4 shell-history >>>"
MARK_END="# <<< helpers4 shell-history <<<"

echo "🔧 Configuring shell-history feature..."
echo "  Username:         ${USERNAME}"
echo "  Home:             ${USER_HOME}"
echo "  Max history size: ${MAX_HISTORY_SIZE}"

# The mount point is created here, owned by the target user and private (history
# often holds tokens typed on a command line): Docker copies a mount point's
# ownership into an empty named volume the first time it's attached.
mkdir -p "${STAGED}"

# Replaces any block a previous run wrote, so running this again never stacks
# duplicates. The block goes last so it wins over the distro's own defaults
# (Debian's ~/.bashrc sets HISTSIZE=1000 / HISTFILESIZE=2000).
write_block() {
    local rc_file="$1" block="$2"
    touch "${rc_file}"
    if grep -qF "${MARK_BEGIN}" "${rc_file}"; then
        sed -i "/^${MARK_BEGIN}\$/,/^${MARK_END}\$/d" "${rc_file}"
    fi
    printf '\n%s\n%s\n%s\n' "${MARK_BEGIN}" "${block}" "${MARK_END}" >> "${rc_file}"
    chown "${USERNAME}:${USER_GROUP}" "${rc_file}"
}

# A history file at the usual path, written at build time by an earlier step,
# is kept in the new location; the usual path then points there, for tools that
# read it directly instead of $HISTFILE.
link_default_path() {
    local default_path="$1" history_file="$2"
    if [ -f "${default_path}" ] && [ ! -L "${default_path}" ]; then
        cat "${default_path}" >> "${history_file}"
        rm -f "${default_path}"
    fi
    ln -sfn "${history_file}" "${default_path}"
    chown -h "${USERNAME}:${USER_GROUP}" "${default_path}"
}

CONFIGURED=""

if command -v bash >/dev/null 2>&1; then
    touch "${STAGED}/bash_history"
    # history -a writes each command as soon as it runs: without it bash only
    # saves on a clean exit, and a container stop or a closed VS Code terminal
    # loses the whole session.
    write_block "${USER_HOME}/.bashrc" "export HISTFILE=${STAGED}/bash_history
HISTSIZE=${MAX_HISTORY_SIZE}
HISTFILESIZE=${MAX_HISTORY_SIZE}
HISTCONTROL=ignoreboth
shopt -s histappend
case \";\${PROMPT_COMMAND:-};\" in
    *'history -a'*) ;;
    *) PROMPT_COMMAND=\"history -a\${PROMPT_COMMAND:+; \${PROMPT_COMMAND}}\" ;;
esac"
    link_default_path "${USER_HOME}/.bash_history" "${STAGED}/bash_history"
    CONFIGURED="${CONFIGURED} bash"
fi

if command -v zsh >/dev/null 2>&1; then
    touch "${STAGED}/zsh_history"
    # SHARE_HISTORY already appends each command as it runs; zsh's docs advise
    # against also setting INC_APPEND_HISTORY with it.
    write_block "${USER_HOME}/.zshrc" "export HISTFILE=${STAGED}/zsh_history
HISTSIZE=${MAX_HISTORY_SIZE}
SAVEHIST=${MAX_HISTORY_SIZE}
setopt SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_SPACE"
    link_default_path "${USER_HOME}/.zsh_history" "${STAGED}/zsh_history"
    CONFIGURED="${CONFIGURED} zsh"
fi

if command -v fish >/dev/null 2>&1; then
    # fish has no setting for its history path, and rewrites the file through a
    # temporary file it then renames — a link to the file itself would be
    # replaced by a plain file on the first save. Linking the whole directory
    # keeps that rename inside the volume.
    FISH_DATA="${USER_HOME}/.local/share/fish"
    mkdir -p "${STAGED}/fish" "$(dirname "${FISH_DATA}")"
    if [ -d "${FISH_DATA}" ] && [ ! -L "${FISH_DATA}" ]; then
        cp -a "${FISH_DATA}/." "${STAGED}/fish/"
        rm -rf "${FISH_DATA}"
    fi
    ln -sfn "${STAGED}/fish" "${FISH_DATA}"
    chown -h "${USERNAME}:${USER_GROUP}" "${FISH_DATA}"
    chown "${USERNAME}:${USER_GROUP}" "${USER_HOME}/.local" "${USER_HOME}/.local/share" 2>/dev/null || true
    CONFIGURED="${CONFIGURED} fish"
fi

if [ -z "${CONFIGURED}" ]; then
    echo "(!) None of bash, zsh or fish is installed — nothing to configure." >&2
    exit 1
fi

chown -R "${USERNAME}:${USER_GROUP}" "${STAGED}"
chmod 700 "${STAGED}"
find "${STAGED}" -maxdepth 1 -type f -exec chmod 600 {} +

# Runs once per container instance (postCreateCommand), as the container user.
SCRIPT="/usr/local/share/shell-history/setup-volume.sh"
mkdir -p "$(dirname "${SCRIPT}")"
cat > "${SCRIPT}" << 'EOF'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs once per container instance (postCreateCommand) — the named volume is mounted.
# Makes sure the current user can write to it, and brings in the history the former
# shell-history-per-project feature kept under /workspaces/.shell-history (only ever
# persisted where /workspaces itself was, e.g. GitHub Codespaces).
set -euo pipefail
# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

STAGED="/mnt/h4history"
LEGACY="/workspaces/.shell-history"

if ! grep -qs " ${STAGED} " /proc/mounts; then
    echo "[shell-history] WARN: ${STAGED} is not a mounted volume — history won't persist across rebuilds" >&2
fi

# Exclusive to this devcontainer (${devcontainerId} — see devcontainer-feature.json), so no
# --shared — see h4_ensure_volume_writable's own comment in helpers4-common/install.sh for why
# that flag choice follows the volume's scoping key.
h4_ensure_volume_writable "${STAGED}"

for name in bash_history zsh_history; do
    if [ -s "${LEGACY}/.${name}" ] && [ ! -s "${STAGED}/${name}" ]; then
        cp "${LEGACY}/.${name}" "${STAGED}/${name}"
        chmod 600 "${STAGED}/${name}"
        echo "[shell-history] Imported ${LEGACY}/.${name}"
    fi
done
EOF
chmod 755 "${SCRIPT}"

echo "  ✅ Configured:${CONFIGURED} — history kept in ${STAGED}"
echo ""
echo "🎉 shell-history configuration complete!"
