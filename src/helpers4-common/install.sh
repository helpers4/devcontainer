#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# helpers4-common: install the shared helpers4 library.
# All other helpers4 features depend on this feature.

set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "Script must be run as root."
    exit 1
fi

echo "🔧 Installing helpers4-common..."

# ── Install common.sh ──────────────────────────────────────────────────────
COMMON_DIR="/usr/local/share/helpers4"
COMMON_SH="${COMMON_DIR}/common.sh"
mkdir -p "${COMMON_DIR}"

cat > "${COMMON_SH}" << 'COMMON_EOF'
#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Shared helpers for helpers4 devcontainer install.sh scripts.
# Source at the top of install.sh:  . /usr/local/share/helpers4/common.sh

# h4_detect_user — resolve the effective non-root user into $USERNAME.
# Priority: explicit USERNAME/REMOTE_USER env > vscode > node > codespace > uid=1000 > root.
h4_detect_user() {
    USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"
    if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
        USERNAME=""
        local _uid1000
        _uid1000="$(awk -v val=1000 -F: '$3==val{print $1; exit}' /etc/passwd 2>/dev/null || true)"
        local candidate
        for candidate in "vscode" "node" "codespace" "${_uid1000}"; do
            if [ -n "${candidate}" ] && id -u "${candidate}" >/dev/null 2>&1; then
                USERNAME="${candidate}"
                break
            fi
        done
        [ -z "${USERNAME}" ] && USERNAME="root"
    elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" >/dev/null 2>&1; then
        USERNAME="root"
    fi
    export USERNAME
}

# h4_resolve_home — set $USER_HOME for $USERNAME. Call h4_detect_user first.
h4_resolve_home() {
    if [ "${USERNAME}" = "root" ]; then
        USER_HOME="/root"
    else
        USER_HOME="$(getent passwd "${USERNAME}" 2>/dev/null | cut -d: -f6)"
        [ -n "${USER_HOME}" ] || USER_HOME="/home/${USERNAME}"
    fi
    export USER_HOME
}

# h4_apt_update — update apt lists only when stale (no-op if already fresh).
h4_apt_update() {
    if [ "$(find /var/lib/apt/lists -maxdepth 1 \( -name '*.lz4' -o -name '*.gz' \) 2>/dev/null | wc -l)" = "0" ]; then
        apt-get update -y -q
    fi
}

# h4_ensure_packages — install packages only if not already present.
h4_ensure_packages() {
    local missing=() pkg
    for pkg in "$@"; do
        dpkg -s "${pkg}" >/dev/null 2>&1 || missing+=("${pkg}")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        h4_apt_update
        apt-get install -y -q --no-install-recommends "${missing[@]}"
    fi
}
COMMON_EOF

chmod 644 "${COMMON_SH}"
echo "  ✅ Installed ${COMMON_SH}"

echo "🎉 helpers4-common ready."
