#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs on postStartCommand — host.docker.internal doesn't resolve out of the box on native
# Linux Docker (only Docker Desktop injects that DNS entry automatically), which breaks the
# audio relay peon-ping depends on. Rather than requiring every consumer to add `runArgs:
# ["--add-host=host.docker.internal:host-gateway"]` to their own devcontainer.json, this derives
# the same IP — the container's default gateway, exactly what that runArgs flag resolves to —
# from /proc/net/route (no extra package needed, unlike `ip route`) and writes it to /etc/hosts
# directly, entirely inside the container's own filesystem namespace.
#
# Best-effort and idempotent: safe to run on every start, only warns if it can't fix it.

command -v getent >/dev/null 2>&1 || exit 0

if getent hosts host.docker.internal >/dev/null 2>&1; then
    exit 0 # already resolves — Docker Desktop, or a previous run of this script
fi

GATEWAY_HEX="$(awk '$2 == "00000000" { print $3; exit }' /proc/net/route 2>/dev/null)"

if [ -z "${GATEWAY_HEX}" ]; then
    echo "⚠️  peon-ping: could not determine the default gateway — host.docker.internal will not resolve. See README 'Audio in Devcontainers' for the manual runArgs fallback." >&2
    exit 0
fi

# /proc/net/route stores the gateway as a little-endian hex IP — reverse the byte order.
GATEWAY_IP="$(printf '%d.%d.%d.%d' \
    "0x${GATEWAY_HEX:6:2}" "0x${GATEWAY_HEX:4:2}" "0x${GATEWAY_HEX:2:2}" "0x${GATEWAY_HEX:0:2}")"

ENTRY="${GATEWAY_IP} host.docker.internal"
if echo "${ENTRY}" >>/etc/hosts 2>/dev/null; then
    echo "✅ peon-ping: added host.docker.internal (${GATEWAY_IP}) to /etc/hosts"
elif command -v sudo >/dev/null 2>&1 && echo "${ENTRY}" | sudo tee -a /etc/hosts >/dev/null 2>&1; then
    echo "✅ peon-ping: added host.docker.internal (${GATEWAY_IP}) to /etc/hosts"
else
    echo "⚠️  peon-ping: could not write /etc/hosts — host.docker.internal will not resolve. See README 'Audio in Devcontainers' for the manual runArgs fallback." >&2
fi

exit 0
