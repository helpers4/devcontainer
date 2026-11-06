# shellcheck shell=sh
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# OpenBao env loader. SOURCED (never executed) from /etc/profile.d/, /etc/bash.bashrc and
# zsh's global rc, so every login or interactive shell — including the VS Code /
# devcontainer CLI userEnvProbe, which runs before every lifecycle hook — exports the
# secrets cached in /dev/shm/openbao/env.
#
# Kept deliberately small and side-effect free: POSIX sh only, no `set` of any option, no
# `exit`, every helper and variable removed again at the end. The network part (login,
# fetch, cache write) lives in the openbao-env CLI, a separate process, so nothing it does
# can leak into the user's shell.
#
# The cache is shell code written by openbao-env: one `_openbao_set NAME 'value'` line
# per key, values quoted by jq's @sh. A variable already set to a non-empty value is never
# overwritten (Codespaces secrets, containerEnv, the user's own export), unless this loader
# set it itself from an older cache (OPENBAO_ENV_KEYS / OPENBAO_ENV_STAMP): that is what
# lets a new shell pick up `openbao-env refresh` even though it inherited the old value.

_openbao_set() {
    eval "_openbao_cur=\${$1:-}"
    if [ -n "${_openbao_cur}" ]; then
        case " ${OPENBAO_ENV_KEYS:-} " in
            *" $1 "*)
                if [ "${OPENBAO_ENV_STAMP:-}" = "${_openbao_stamp}" ]; then
                    _openbao_keys="${_openbao_keys} $1"
                    return 0
                fi
                ;;
            *) return 0 ;;
        esac
    fi
    export "$1=$2"
    _openbao_keys="${_openbao_keys} $1"
}

_openbao_main() {
    _openbao_cache=/dev/shm/openbao/env
    if [ ! -f "${_openbao_cache}" ] && [ -x /usr/local/bin/openbao-env ] \
        && [ -z "${OPENBAO_ENV_DISABLE:-}" ]; then
        /usr/local/bin/openbao-env fetch --auto < /dev/null || :
    fi
    [ -f "${_openbao_cache}" ] && [ -r "${_openbao_cache}" ] || return 0
    _openbao_keys=""
    _openbao_stamp=""
    # shellcheck source=/dev/null
    . "${_openbao_cache}"
    [ -n "${_openbao_stamp}" ] || return 0
    OPENBAO_ENV_KEYS="${_openbao_keys# }"
    OPENBAO_ENV_STAMP="${_openbao_stamp}"
    export OPENBAO_ENV_KEYS OPENBAO_ENV_STAMP
}

_openbao_main
unset -f _openbao_main _openbao_set
unset _openbao_cache _openbao_cur _openbao_keys _openbao_stamp
