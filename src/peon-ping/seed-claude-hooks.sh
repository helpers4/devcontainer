#!/usr/bin/env bash

# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# Runs on postStartCommand, after the claude-dev feature's own postStartCommand (if present)
# has replaced ~/.claude with a symlink to its persistent, per-devcontainer Docker volume — see
# install.sh for why peon-ping's actual install (binary, packs, adapters, skills) lives outside
# ~/.claude instead of inside it. This script re-attaches that install to the real ~/.claude
# (whatever it is right now, symlinked or not) so Claude Code's own hook/skill discovery — and
# the Cursor/Codex adapters, which hardcode ~/.claude/hooks/peon-ping/adapters/*.sh — find it.
#
# Best-effort and idempotent: safe to run on every start; no-ops if peon-ping's Claude Code
# hooks were never installed (e.g. ideSetup excluded vscode).

set -uo pipefail

PEON_STABLE_HOME="${HOME}/.local/share/peon-ping/claude-home"
CLAUDE_DIR="${HOME}/.claude"
HOOKS_FRAGMENT="${HOME}/.local/share/peon-ping/claude-hooks.json"

[ -d "${PEON_STABLE_HOME}/hooks/peon-ping" ] || exit 0

mkdir -p "${CLAUDE_DIR}/hooks" "${CLAUDE_DIR}/skills"

# Re-link every start: cheap, and avoids drift if the install path ever changes.
ln -sf "${PEON_STABLE_HOME}/hooks/peon-ping" "${CLAUDE_DIR}/hooks/peon-ping"

for skill_dir in "${PEON_STABLE_HOME}"/skills/peon-ping-*; do
    [ -d "${skill_dir}" ] || continue
    ln -sf "${skill_dir}" "${CLAUDE_DIR}/skills/$(basename "${skill_dir}")"
done

[ -f "${HOOKS_FRAGMENT}" ] || exit 0
command -v python3 > /dev/null 2>&1 || exit 0

CLAUDE_DIR="${CLAUDE_DIR}" HOOKS_FRAGMENT="${HOOKS_FRAGMENT}" python3 << 'PYEOF'
import json
import os

claude_dir = os.environ["CLAUDE_DIR"]
fragment_path = os.environ["HOOKS_FRAGMENT"]
settings_path = os.path.join(claude_dir, "settings.json")

with open(fragment_path) as f:
    new_hooks = json.load(f)

try:
    with open(settings_path) as f:
        settings = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    settings = {}

existing_hooks = settings.setdefault("hooks", {})


def commands(entry):
    return [h.get("command", "") for h in entry.get("hooks", [])]


# Dedup by the same "peon-ping" substring marker install.sh's own merge_hooks_json (Cursor/
# Copilot) uses, not exact command equality — existing_cmds is a static snapshot taken before
# this event's entries are appended (matching merge_hooks_json), so a second, distinct
# peon-ping-owned entry for the same event (e.g. UserPromptSubmit's slash-command handlers
# alongside its sound-player hook) still gets added within this same run; only a *previous*
# run's already-registered entries get skipped on the next one.
for event, entries in new_hooks.items():
    event_list = existing_hooks.setdefault(event, [])
    existing_cmds = {c for e in event_list for c in commands(e)}
    for entry in entries:
        if not any("peon-ping" in c for c in existing_cmds):
            event_list.append(entry)

settings["hooks"] = existing_hooks
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF

exit 0
