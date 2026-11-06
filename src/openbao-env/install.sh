#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs at BUILD TIME. Installs the OpenBao env loader (sourced by every shell, so the
# VS Code / devcontainer CLI userEnvProbe picks the secrets up before any lifecycle hook),
# the openbao-env CLI, and optionally the bao CLI. Nothing secret is ever written to the
# image: the secrets are fetched at runtime into /dev/shm/openbao (memory only).

set -euo pipefail

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh

h4_require_root

# Feature options
OPT_PATHS="${PATHS:-""}"
OPT_MOUNT="${MOUNT:-"kv"}"
OPT_ADDRESS="${ADDRESS:-""}"
INSTALL_CLI="${INSTALLCLI:-"true"}"
BAO_VERSION="${VERSION:-"latest"}"

h4_detect_user

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARE_DIR="/usr/local/share/openbao-env"
LOADER="${SHARE_DIR}/loader.sh"
TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "${TMP_DIR}"
}
trap cleanup EXIT

export DEBIAN_FRONTEND=noninteractive

echo "🔧 Installing openbao-env feature..."
echo "  Username:    ${USERNAME}"
echo "  paths:       ${OPT_PATHS:-(none)}"
echo "  mount:       ${OPT_MOUNT}"
echo "  address:     ${OPT_ADDRESS:-(from BAO_ADDR at runtime)}"
echo "  installCli:  ${INSTALL_CLI}"

# The loader's only runtime deps; flock (util-linux) is already in every Debian/Ubuntu base.
h4_ensure_packages curl ca-certificates jq

# ── Config, loader, CLI ──────────────────────────────────────────────────────
mkdir -p "${SHARE_DIR}"
{
    echo "# Written by the helpers4 openbao-env feature at build time — no secrets here."
    printf 'CFG_PATHS=%q\n' "${OPT_PATHS}"
    printf 'CFG_MOUNT=%q\n' "${OPT_MOUNT}"
    printf 'CFG_ADDRESS=%q\n' "${OPT_ADDRESS}"
    printf 'CFG_USER=%q\n' "${USERNAME}"
} > "${SHARE_DIR}/config"
chmod 644 "${SHARE_DIR}/config"
install -m 0644 "${SCRIPT_DIR}/loader.sh" "${LOADER}"
install -m 0755 "${SCRIPT_DIR}/openbao-env" /usr/local/bin/openbao-env
echo "  ✅ ${LOADER}, /usr/local/bin/openbao-env"

# ── Hook the loader into every shell ─────────────────────────────────────────
# Login shells (the userEnvProbe's `bash -lic`, `sh -l`): /etc/profile.d.
cat > /etc/profile.d/openbao-env.sh << EOF
# Written by the helpers4 openbao-env feature: export the secrets cached from OpenBao.
[ -r ${LOADER} ] && . ${LOADER}
EOF
chmod 644 /etc/profile.d/openbao-env.sh

MARK_BEGIN="# >>> helpers4 openbao-env >>>"
MARK_END="# <<< helpers4 openbao-env <<<"
add_block() {
    local file="$1" line="$2"
    if [ -f "${file}" ] && grep -qF "${MARK_BEGIN}" "${file}"; then
        return 0
    fi
    printf '\n%s\n%s\n%s\n' "${MARK_BEGIN}" "${line}" "${MARK_END}" >> "${file}"
    echo "  ✅ hooked into ${file}"
}

# Interactive non-login bash (VS Code terminals, `bash` from another shell).
add_block /etc/bash.bashrc "[ -r ${LOADER} ] && . ${LOADER}"

# zsh doesn't read /etc/profile.d. Only append to a global zshrc that already exists:
# creating it before the zsh package is installed would turn its conffile into a conflict.
# emulate sh: the loader is POSIX sh, and zsh doesn't word-split like sh does.
for zshrc in /etc/zsh/zshrc /etc/zshrc; do
    if [ -f "${zshrc}" ]; then
        add_block "${zshrc}" "[ -r ${LOADER} ] && emulate sh -c '. ${LOADER}'"
        break
    fi
done

# ── bao CLI (optional) ───────────────────────────────────────────────────────
if [ "${INSTALL_CLI}" = "true" ]; then
    h4_ensure_packages tar
    case "$(uname -m)" in
        x86_64) BAO_ARCH="amd64" ;;
        aarch64 | arm64 | armv8*) BAO_ARCH="arm64" ;;
        *)
            echo "(!) Architecture $(uname -m) unsupported by the bao CLI install" >&2
            exit 1
            ;;
    esac
    if [ "${BAO_VERSION}" = "latest" ]; then
        BAO_VERSION="$(h4_github_latest_tag openbao/openbao)"
        if [ -z "${BAO_VERSION}" ]; then
            echo "(!) Failed to fetch the latest OpenBao release" >&2
            exit 1
        fi
    fi
    BAO_VERSION="${BAO_VERSION#v}"
    ASSET="openbao_${BAO_VERSION}_linux_${BAO_ARCH}.tar.gz"
    RELEASE_URL="https://github.com/openbao/openbao/releases/download/v${BAO_VERSION}"

    echo "  📦 Downloading ${ASSET}..."
    if ! curl -fsSL "${RELEASE_URL}/${ASSET}" -o "${TMP_DIR}/${ASSET}"; then
        echo "(!) Failed to download ${RELEASE_URL}/${ASSET}" >&2
        echo "(!) Available releases: https://github.com/openbao/openbao/releases" >&2
        exit 1
    fi
    echo "  🔒 Verifying checksum..."
    if ! curl -fsSL "${RELEASE_URL}/checksums.txt" -o "${TMP_DIR}/checksums.txt"; then
        echo "(!) Failed to download ${RELEASE_URL}/checksums.txt" >&2
        exit 1
    fi
    if ! (cd "${TMP_DIR}" && grep " ${ASSET}\$" checksums.txt | sha256sum -c - > /dev/null); then
        echo "(!) Checksum verification failed for ${ASSET}" >&2
        exit 1
    fi
    tar -xzf "${TMP_DIR}/${ASSET}" -C "${TMP_DIR}" bao
    install -m 0755 "${TMP_DIR}/bao" /usr/local/bin/bao
    if ! INSTALLED="$(/usr/local/bin/bao version 2>&1)"; then
        echo "(!) bao installation verification failed" >&2
        exit 1
    fi
    echo "  ✅ ${INSTALLED} installed in /usr/local/bin/bao"
else
    echo "  ⏭️  bao CLI not installed (installCli: false) — the loader doesn't need it"
fi

echo
echo "🎉 openbao-env installation complete!"
echo
echo "📋 Secrets are fetched at runtime into /dev/shm/openbao (memory only)."
echo "   openbao-env status   # what is configured and loaded (names only)"
echo "   openbao-env refresh  # fetch again"
echo
