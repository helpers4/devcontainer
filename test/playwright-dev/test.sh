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

reportResults
