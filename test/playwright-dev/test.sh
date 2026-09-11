#!/bin/bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later

# Test script for playwright-dev feature

set -e

# Source test framework
source dev-container-features-test-lib

check "node is available" command -v node

check "npm is available" command -v npm

# The guard script (postCreateCommand) must be installed and executable —
# it's what actually downloads the browsers once the volume is mounted.
check "postCreate guard script is installed" test -x /usr/local/bin/devcontainer-playwright-browsers

# OS dependencies for headless Chromium are installed by default (browsers=all).
# libnss3 is a good proxy: Chromium headless fails immediately without it.
check "libnss3 is installed (Chromium OS deps)" dpkg -s libnss3

# The browser cache volume is shared across every local project for this host OS user
# (${localEnv:USER} — see devcontainer-feature.json), so the guard script must claim
# ownership with h4_ensure_volume_writable's --shared mode instead of a plain chown, or a
# second project with a different container UID gets EACCES writing into it.
check "guard script uses --shared ownership (volume is shared across projects)" \
    grep -q -- '--shared' /usr/local/bin/devcontainer-playwright-browsers

# The completion marker must be scoped by the resolved Playwright version, not just the
# browser selection — otherwise, now that the cache is shared, a project pinning a
# different Playwright version than whichever project populated the cache first would
# wrongly skip downloading the browser revision it actually needs.
check "download marker is scoped by Playwright version" \
    grep -q 'PLAYWRIGHT_VERSION' /usr/local/bin/devcontainer-playwright-browsers

reportResults
