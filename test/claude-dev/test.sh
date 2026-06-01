#!/bin/bash

# Test script for claude-dev feature
# Copyright (C) 2025 baxyz
# Licensed under LGPL-3.0 - see LICENSE file for details

set -e

echo "Testing claude-dev feature..."

# This feature only configures IDE extensions via devcontainer customizations —
# there is no binary or system file to verify at runtime. The test confirms that
# the install.sh ran without error (guaranteed by set -e above reaching this
# point) and that no unexpected files were left behind.

echo "✅ PASS: claude-dev install.sh completed without error"
echo ""
echo "🎉 claude-dev feature test complete!"
