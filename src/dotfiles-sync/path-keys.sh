#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Shared git-config path-key allowlists + helpers for dotfiles-sync.
# Sourced by both sync-files.sh (runtime) and test.sh (feature tests) so the
# two can never silently drift apart — do not hand-copy any of this.
#
# Callers must set TARGET_HOME before invoking _rehome_path_value or
# _warn_if_missing_path. _warn_if_missing_path also honors IS_CLOUD_ENV if set
# (used only to clarify the WARN message; unset is treated as not-cloud).

# Membership test for a space-separated allowlist string (e.g. PROTECTED_KEYS,
# REHOMEABLE_PATH_KEYS, VERIFY_PATH_KEYS). Args: <needle> <space-separated list>
_key_in_list() {
    local _needle="$1" _item
    for _item in ${2}; do
        [ "${_needle}" = "${_item}" ] && return 0
    done
    return 1
}

# Keys whose value is a bare filesystem path (never a shell command string)
# that may point inside the synced .ssh/.gnupg directories — e.g.
# user.signingkey with an SSH key under the host user's home. The host home
# doesn't exist in the container, but the referenced file itself is re-homed
# under TARGET_HOME/.ssh or TARGET_HOME/.gnupg by the syncs in sync-files.sh,
# so the value is rewritten to match. This is what broke commit signing
# before: the path survived the merge verbatim.
#
# include.path is deliberately NOT in this list: its most realistic value
# points under .config/git/ (which sync-files.sh copies via a separate
# copy-if-absent step), not .ssh/.gnupg, and this rewrite only knows how to
# retarget those two directories — adding include.path here without teaching
# _rehome_path_value about .config/git/ would rewrite nothing for the common
# case and just give false confidence.
#
# NOTE: `git config --list` always lowercases the key portion (e.g.
# `http.sslCert` -> `http.sslcert`), so every entry here MUST already be
# lowercase or the membership check below silently never matches.
REHOMEABLE_PATH_KEYS="user.signingkey http.sslcert http.sslkey http.sslcainfo"

# Keys worth a post-sync existence check even when no deterministic target
# path is known (gpg.program/gpg.ssh.program/core.editor/credential.helper
# point at a host binary or script — there's no container equivalent to
# rewrite them to). Includes every REHOMEABLE_PATH_KEYS entry too, so the two
# lists can't silently drift apart — see the verify pass in sync-files.sh.
VERIFY_ONLY_PATH_KEYS="gpg.program gpg.ssh.program core.editor credential.helper"
VERIFY_PATH_KEYS="${REHOMEABLE_PATH_KEYS} ${VERIFY_ONLY_PATH_KEYS}"

# Rewrite a REHOMEABLE_PATH_KEYS value that points into a .ssh/ or .gnupg/
# directory — whether written as a bare relative path (".ssh/id_ed25519") or
# as an absolute/tilde host path ("/home/alice/.ssh/id_ed25519",
# "~/.ssh/id_ed25519") — to the same relative path under TARGET_HOME. Leaves
# the value untouched if it doesn't match either form. Args: <value>. Prints
# the (possibly rewritten) value on stdout.
_rehome_path_value() {
    local _val="$1"
    case "${_val}" in
        .ssh/*)
            _val="${TARGET_HOME}/.ssh/${_val#.ssh/}"
            ;;
        */.ssh/*)
            _val="${TARGET_HOME}/.ssh/${_val#*/.ssh/}"
            ;;
        .gnupg/*)
            _val="${TARGET_HOME}/.gnupg/${_val#.gnupg/}"
            ;;
        */.gnupg/*)
            _val="${TARGET_HOME}/.gnupg/${_val#*/.gnupg/}"
            ;;
    esac
    printf '%s\n' "${_val}"
}

# Warn (non-fatal, prints nothing on success) if a path-like git-config value
# doesn't resolve to an existing file in the container. Args: <key> <raw value>.
#
# Handles, in order:
#  - a leading "!" (credential.helper's shell-invocation prefix)
#  - a leading "~/" (resolved against TARGET_HOME, checked both as a whole
#    value and per-token — see below)
#  - the value AS A WHOLE being a path that itself contains spaces (e.g. a
#    Windows path surfaced via WSL: "/mnt/c/Program Files/Git/.../gpg.exe") —
#    checked before any splitting, so this never gets truncated
#  - trailing flags or an interpreter prefix (e.g. `code --wait`, or
#    `!/usr/bin/python3 /host/only/helper.py`) — each whitespace-separated
#    token that looks like a path (leading "/" or "~/") is checked
#    individually, so an interpreter-invoked script isn't hidden behind an
#    always-present interpreter binary
_warn_if_missing_path() {
    local _key="$1" _raw="$2" _val _tok _resolved _reason

    _val="${_raw#!}"

    _resolved="${_val}"
    case "${_resolved}" in
        '~'/*) _resolved="${TARGET_HOME}${_resolved#\~}" ;;
    esac
    [ -e "${_resolved}" ] && return 0

    for _tok in ${_val}; do
        case "${_tok}" in
            '~'/*) _tok="${TARGET_HOME}${_tok#\~}" ;;
            /*) ;;
            *) continue ;;
        esac
        if [ ! -e "${_tok}" ]; then
            _reason="host-specific path?"
            case "${_tok}" in
                "${TARGET_HOME}/.gnupg"/*)
                    [ "${IS_CLOUD_ENV:-false}" = "true" ] && \
                        _reason="cloud env — .gnupg sync is skipped here, see above"
                    ;;
            esac
            echo "   WARN: ${_key}=${_raw} does not exist in container (${_reason}) [missing: ${_tok}]"
        fi
    done
}
