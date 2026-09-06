#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs on postAttachCommand — after the client (VS Code, Codespaces, ...) has
# finished its own connection bootstrap, which is when SSH agent forwarding
# and any automatic ~/.gitconfig copy actually become live. Both of those
# happen outside any devcontainer Feature's control, verbatim, with no
# awareness that a path baked into the host's config might not resolve
# inside this container — a credential.helper shelling out to a snap-managed
# `gh` at a revision-pinned path, or a gpg.format=ssh signingkey pointing at
# a public key file that only ever existed on the host. This repairs both
# classes of breakage, generically — no per-tool/per-feature knowledge baked
# in here, so it doesn't go stale as installed tools move around.
#
# Best-effort and idempotent: safe to run on every attach, never fails the
# attach, only ever warns when it can't fix something itself.

command -v git >/dev/null 2>&1 || exit 0

GITCONFIG="${HOME}/.gitconfig"
[ -f "${GITCONFIG}" ] || exit 0

# shellcheck source=/dev/null
. /usr/local/share/helpers4/common.sh
h4_detect_cloud_env

_get() {
    git config --file "${GITCONFIG}" --get "$1" 2>/dev/null || true
}

# Sets a single-valued key outright (safe for keys like user.signingkey that
# should only ever hold one value; --replace-all with no value-pattern
# collapses any pre-existing multivar down to just this one).
_set() {
    git config --file "${GITCONFIG}" --replace-all "$1" "$2" 2>/dev/null
}

# Rewrites exactly one existing value of a (possibly multi-valued) key,
# leaving any other value of that same key untouched — plain `git config
# <key> <value>` refuses outright (exit 5, "cannot overwrite multiple
# values") the moment a key like credential.helper already has more than one
# value (e.g. a blank "reset" entry alongside a real helper), which is a
# legitimate, common pattern this must not collapse.
_replace_one_value() {
    local _key="$1" _old="$2" _new="$3" _pattern
    _pattern="^$(printf '%s' "${_old}" | sed 's/[.[\*^$/]/\\&/g')\$"
    git config --file "${GITCONFIG}" --replace-all "${_key}" "${_new}" "${_pattern}" 2>/dev/null
}

FIXED=0
WARNED=0

# ── Shell-out keys: credential.helper (incl. per-URL scopes), gpg.program,
#    gpg.ssh.program, core.editor ─────────────────────────────────────────────
# A value like "!/snap/gh/751/gh auth git-credential" or "/usr/bin/some-tool
# --flag" that shells out to an absolute path which no longer resolves here.
# Rewritten to the bare command name instead of a fresh absolute path: once
# it's just relying on $PATH, it never goes stale again on a future rebuild,
# even if the tool moves.
_heal_shellout_key() {
    local _key="$1" _raw="$2" _bang="" _rest="${2}" _first _bin _new

    case "${_raw}" in
        '!'*) _bang="!"; _rest="${_raw#!}" ;;
    esac

    _first="${_rest%% *}"
    case "${_first}" in
        /*) ;;
        *) return 0 ;; # not an absolute path — nothing this script knows how to check
    esac

    [ -x "${_first}" ] && return 0 # still resolves, nothing to do

    _bin="$(basename "${_first}")"
    if command -v "${_bin}" >/dev/null 2>&1; then
        case "${_rest}" in
            "${_first}"' '*) _new="${_bang}${_bin} ${_rest#* }" ;;
            *) _new="${_bang}${_bin}" ;;
        esac
        if _replace_one_value "${_key}" "${_raw}" "${_new}"; then
            echo "   ✅ ${_key}: ${_first} -> ${_bin} (resolved on \$PATH)"
            FIXED=$((FIXED + 1))
        else
            echo "   ⚠️  ${_key}=${_raw} found ${_bin} on \$PATH but couldn't rewrite the config value"
            WARNED=$((WARNED + 1))
        fi
    else
        echo "   ⚠️  ${_key}=${_raw} does not resolve in this container (${_first} not found, no \$PATH match for ${_bin})"
        WARNED=$((WARNED + 1))
    fi
}

for key in gpg.program gpg.ssh.program core.editor; do
    val="$(_get "${key}")"
    [ -n "${val}" ] && _heal_shellout_key "${key}" "${val}"
done

while IFS= read -r line; do
    key="${line%%=*}"
    val="${line#*=}"
    [ -z "${key}" ] && continue
    _heal_shellout_key "${key}" "${val}"
done < <(git config --file "${GITCONFIG}" --get-regexp '^credential\..*\.helper$|^credential\.helper$' 2>/dev/null | sed 's/ /=/')

# ── user.signingkey (SSH-format commit signing only) ──────────────────────────
GPG_FORMAT="$(_get gpg.format)"
if [ "${GPG_FORMAT}" = "ssh" ]; then
    SIGNINGKEY="$(_get user.signingkey)"
    SIGNINGKEY="${SIGNINGKEY/#\~/${HOME}}"

    if [ -n "${SIGNINGKEY}" ] && [ ! -f "${SIGNINGKEY}" ]; then
        FOUND=""

        # Strategy 1: a file with the same basename already exists locally —
        # e.g. dotfiles-sync (or the user) placed the key under ~/.ssh or
        # ~/.gnupg, but the config value itself still carries the host's
        # original (now-wrong) directory.
        base="$(basename "${SIGNINGKEY}")"
        for dir in "${HOME}/.ssh" "${HOME}/.gnupg"; do
            if [ -f "${dir}/${base}" ]; then
                FOUND="${dir}/${base}"
                break
            fi
        done

        # Strategy 2: no local file — recover the public key live from a
        # forwarded ssh-agent, matched against user.email among its loaded
        # identities. Only ever reads/lists identities (ssh-add -L), never
        # touches private key material.
        if [ -z "${FOUND}" ] && command -v ssh-add >/dev/null 2>&1; then
            EMAIL="$(_get user.email)"
            if [ -n "${EMAIL}" ]; then
                PUBKEY="$(ssh-add -L 2>/dev/null | grep " ${EMAIL}\$" || true)"
                if [ -n "${PUBKEY}" ]; then
                    mkdir -p "$(dirname "${SIGNINGKEY}")" 2>/dev/null
                    if printf '%s\n' "${PUBKEY}" > "${SIGNINGKEY}" 2>/dev/null; then
                        chmod 644 "${SIGNINGKEY}" 2>/dev/null || true
                        FOUND="${SIGNINGKEY}"
                    fi
                fi
            fi
        fi

        if [ -n "${FOUND}" ]; then
            if [ "${FOUND}" != "${SIGNINGKEY}" ]; then
                _set user.signingkey "${FOUND}"
                echo "   ✅ user.signingkey: ${SIGNINGKEY} -> ${FOUND}"
            else
                echo "   ✅ user.signingkey: recovered from the forwarded ssh-agent"
            fi
            FIXED=$((FIXED + 1))
        else
            reason="no ssh-agent identity matched user.email, and no local key file found"
            case "${ENV_LABEL}" in
                "GitHub Codespaces")
                    reason="${ENV_LABEL} does not forward a local ssh-agent, so this can't be derived automatically here — see: https://docs.github.com/en/codespaces/managing-your-codespaces/managing-your-account-specific-secrets-for-github-codespaces (store the public key as a Codespaces secret), or use GPG-format signing, which Codespaces signs natively via its own managed proxy"
                    ;;
                *)
                    [ "${IS_CLOUD_ENV}" = "true" ] && \
                        reason="${ENV_LABEL} does not forward a local ssh-agent, so this can't be derived automatically here — check ${ENV_LABEL}'s own docs for its recommended way to make a signing key available"
                    ;;
            esac
            echo "   ⚠️  user.signingkey=${SIGNINGKEY} does not exist in this container (${reason})"
            WARNED=$((WARNED + 1))
        fi
    fi
fi

if [ "${FIXED}" -gt 0 ] || [ "${WARNED}" -gt 0 ]; then
    echo "helpers4: git config self-heal — ${FIXED} fixed, ${WARNED} still need attention"
fi

exit 0
