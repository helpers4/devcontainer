#!/bin/bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

# Test script for vite-plus feature

set -e

# Source test framework
source dev-container-features-test-lib

# Feature-specific tests
check "node is available" command -v node

check "npm is available" command -v npm

# Check vp (Vite+ unified CLI) installation
# vp is required by default (installVitePlus=true), so this must pass.
#
# "vp CLI is available" alone isn't a reliable regression check: the test
# harness runs this as a *login* shell for the target user, so `command -v
# vp` can resolve vp purely via the official installer's own PATH line in
# ~/.bashrc/~/.profile — even when this feature's own /usr/local/bin/vp
# symlink (installGlobally's actual documented contract: "system-wide ...
# without relying on the target user's own PATH") was never created. That
# gap is exactly how a real regression (VP_HOME pin missing, installer
# defaulting to a different install path) passed CI for months: the
# rc-file PATH happened to still resolve vp for this one user in a login
# shell, while root, other users, and non-login contexts got nothing.
# Assert the actual symlink exists so a broken installGlobally can't hide
# behind an incidental PATH match again.
check "vp is symlinked system-wide (/usr/local/bin/vp)" test -x /usr/local/bin/vp
check "vp CLI is available" command -v vp
check "vp version displays" vp --version

# Check standalone Vite CLI (optional, not needed with vp)
if command -v vite >/dev/null 2>&1; then
    check "vite CLI is available" command -v vite
fi

# Check standalone Vitest CLI (optional, not needed with vp)
if command -v vitest >/dev/null 2>&1; then
    check "vitest CLI is available" command -v vitest
fi

reportResults
