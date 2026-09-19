#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Checks that option values with spaces and commas reach clone-repos.sh unchanged.
# install.sh is the only place that writes them, and the default test never sets any.

set -e

echo "Testing org-workspace with custom options..."

# shellcheck source=/dev/null
. /usr/local/share/org-workspace/options.env

check() {
    if [ "$2" = "$3" ]; then
        echo "✅ PASS: $1 is '$3'"
    else
        echo "❌ FAIL: $1 is '$2', expected '$3'"
        exit 1
    fi
}

check org "${ORG_OPTION}" "acme"
check repos "${REPOS_OPTION}" "one, two"
check exclude "${EXCLUDE_OPTION}" "two three"
check autoDiscover "${AUTO_DISCOVER_OPTION}" "false"
check codeWorkspaceName "${CODE_WORKSPACE_NAME_OPTION}" "my space.code-workspace"

echo "🎉 Test passed."
