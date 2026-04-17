# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Auto-authenticate gh CLI if GH_TOKEN or GITHUB_TOKEN is set in the environment.
# Sourced from /etc/profile.d/ on shell startup.

_gh_auto_auth() {
    # Resolve token: prefer GH_TOKEN, fall back to GITHUB_TOKEN
    local token="${GH_TOKEN:-${GITHUB_TOKEN:-}}"

    [ -z "${token}" ] && return 0
    ! command -v gh >/dev/null 2>&1 && return 0

    # Already authenticated — skip
    if gh auth status >/dev/null 2>&1; then
        return 0
    fi

    echo "${token}" | gh auth login --with-token 2>/dev/null && \
        echo "github-dev: gh authenticated via token" || \
        echo "github-dev: gh auth failed (invalid token?)"
}

_gh_auto_auth
unset -f _gh_auto_auth
