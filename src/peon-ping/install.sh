#!/usr/bin/env bash

# Peon Ping DevContainer Feature
# Copyright (c) 2025 helpers4
# Licensed under AGPL-3.0 - see LICENSE file for details
#
# Installs peon-ping and configures multi-IDE hooks for AI agent sound notifications

set -e

# Feature options (env vars auto-generated from devcontainer-feature.json)
PACKS="${PACKS:-"default"}"
NO_RC="${NORC:-"true"}"
IDE_SETUP="${IDESETUP:-"vscode"}"
VOLUME="${VOLUME:-"0.5"}"

USERNAME="${USERNAME:-"${_REMOTE_USER:-"automatic"}"}"

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

# Determine the appropriate non-root user
if [ "${USERNAME}" = "auto" ] || [ "${USERNAME}" = "automatic" ]; then
    USERNAME=""
    POSSIBLE_USERS=("vscode" "node" "codespace" "$(awk -v val=1000 -F ":" '$3==val{print $1}' /etc/passwd)")
    for CURRENT_USER in "${POSSIBLE_USERS[@]}"; do
        if id -u "${CURRENT_USER}" > /dev/null 2>&1; then
            USERNAME="${CURRENT_USER}"
            break
        fi
    done
    if [ "${USERNAME}" = "" ]; then
        USERNAME=root
    fi
elif [ "${USERNAME}" = "none" ] || ! id -u "${USERNAME}" > /dev/null 2>&1; then
    USERNAME=root
fi

USER_HOME=$(eval echo "~${USERNAME}")

# Clean up
cleanup() {
    rm -rf /var/lib/apt/lists/*
}

trap cleanup EXIT

# Ensure apt is in non-interactive mode
export DEBIAN_FRONTEND=noninteractive

echo "🎮 Installing peon-ping feature..."
echo "   Username: ${USERNAME}"
echo "   Packs: ${PACKS}"
echo "   Volume: ${VOLUME}"

# ── Helpers ──────────────────────────────────────────────────────────────────

apt_get_update() {
    if [ "$(find /var/lib/apt/lists/* 2>/dev/null | wc -l)" = "0" ]; then
        echo "Running apt-get update..."
        apt-get update -y
    fi
}

check_packages() {
    if ! dpkg -s "$@" > /dev/null 2>&1; then
        apt_get_update
        apt-get -y install --no-install-recommends "$@"
    fi
}

# ── Prerequisites ────────────────────────────────────────────────────────────

echo "🔧 Installing prerequisites..."
check_packages curl ca-certificates python3 alsa-utils

# ── Install peon-ping ────────────────────────────────────────────────────────

echo "🔧 Installing peon-ping..."

INSTALLER_ARGS="--global"

if [ "${PACKS}" = "all" ]; then
    INSTALLER_ARGS="${INSTALLER_ARGS} --all"
elif [ "${PACKS}" != "default" ]; then
    INSTALLER_ARGS="${INSTALLER_ARGS} --packs=${PACKS}"
fi

if [ "${NO_RC}" = "true" ]; then
    INSTALLER_ARGS="${INSTALLER_ARGS} --no-rc"
fi

# Run installer as the target user (peon-ping handles non-interactive detection)
su - "${USERNAME}" -c "curl -fsSL https://raw.githubusercontent.com/PeonPing/peon-ping/main/install.sh | bash -s -- ${INSTALLER_ARGS}" || {
    echo "❌ peon-ping installation failed"
    exit 1
}

# ── Set volume ───────────────────────────────────────────────────────────────

PEON_CONFIG_DIR="${USER_HOME}/.claude/hooks/peon-ping"
PEON_CONFIG="${PEON_CONFIG_DIR}/config.json"

if [ -f "${PEON_CONFIG}" ] && command -v python3 > /dev/null 2>&1; then
    echo "🔧 Setting volume to ${VOLUME}..."
    python3 << PYEOF
import json
path = "${PEON_CONFIG}"
with open(path) as f:
    cfg = json.load(f)
cfg["volume"] = float("${VOLUME}")
with open(path, "w") as f:
    json.dump(cfg, f, indent=2)
    f.write("\n")
PYEOF
fi

# ── Hook configuration helpers ───────────────────────────────────────────────

# Parse ideSetup option into a lookup function
# "all" → every IDE, "none" → skip, csv → only listed
# "vscode" and "copilot" are treated as synonyms
ide_enabled() {
    local ide="$1"
    local setup="${IDE_SETUP}"
    case "${setup}" in
        all)  return 0 ;;
        none) return 1 ;;
        *)    echo ",${setup}," | sed 's/copilot/vscode/gi; s/vscode/vscode/gi' | grep -qi ",${ide}," ;;
    esac
}

# Merge peon-ping hooks into a JSON hooks file (idempotent).
# Usage: merge_hooks_json <target_file> <hooks_json_string>
merge_hooks_json() {
    local target="$1"
    local new_hooks="$2"

    python3 << PYEOF
import json, os

target_path = "${target}"
new_hooks = json.loads("""${new_hooks}""")

if os.path.exists(target_path):
    with open(target_path) as f:
        data = json.load(f)
else:
    os.makedirs(os.path.dirname(target_path), exist_ok=True)
    data = {"version": 1, "hooks": {}}

existing_hooks = data.setdefault("hooks", {})

for event, entries in new_hooks.items():
    event_list = existing_hooks.setdefault(event, [])
    existing_cmds = [e.get("bash", e.get("command", "")) for e in event_list]
    for entry in entries:
        cmd = entry.get("bash", entry.get("command", ""))
        if not any("peon-ping" in c for c in existing_cmds):
            event_list.append(entry)

data["hooks"] = existing_hooks
with open(target_path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
}

# ── GitHub Copilot hooks ─────────────────────────────────────────────────────

if ide_enabled vscode; then
    echo "🔧 Configuring GitHub Copilot hooks..."

    # Create a helper script that generates .github/hooks/hooks.json in the
    # current workspace.  Users can call it manually or via postCreateCommand.
    cat > /usr/local/bin/peon-ping-copilot-setup << 'SETUPEOF'
#!/usr/bin/env bash
# Generate .github/hooks/hooks.json for GitHub Copilot agent mode.
# Run from the workspace root or pass the target directory as $1.
set -e

TARGET_DIR="${1:-.}"
HOOKS_DIR="${TARGET_DIR}/.github/hooks"
HOOKS_FILE="${HOOKS_DIR}/hooks.json"

mkdir -p "${HOOKS_DIR}"

if [ -f "${HOOKS_FILE}" ]; then
    python3 << 'PYEOF'
import json, os

path = os.environ.get("HOOKS_FILE", ".github/hooks/hooks.json")
if not os.path.exists(path):
    exit(0)

with open(path) as f:
    data = json.load(f)

hooks = data.setdefault("hooks", {})
new_entries = {
    "sessionStart":          [{"type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh sessionStart"}],
    "userPromptSubmitted":   [{"type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh userPromptSubmitted"}],
    "postToolUse":           [{"type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh postToolUse"}],
    "errorOccurred":         [{"type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh errorOccurred"}]
}

for event, entries in new_entries.items():
    event_list = hooks.setdefault(event, [])
    existing_cmds = [e.get("bash", e.get("command", "")) for e in event_list]
    for entry in entries:
        if not any("peon-ping" in c for c in existing_cmds):
            event_list.append(entry)

data["hooks"] = hooks
with open(path, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PYEOF
else
    cat > "${HOOKS_FILE}" << 'JSONEOF'
{
  "version": 1,
  "hooks": {
    "sessionStart": [
      { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh sessionStart" }
    ],
    "userPromptSubmitted": [
      { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh userPromptSubmitted" }
    ],
    "postToolUse": [
      { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh postToolUse" }
    ],
    "errorOccurred": [
      { "type": "command", "bash": "bash ~/.claude/hooks/peon-ping/adapters/copilot.sh errorOccurred" }
    ]
  }
}
JSONEOF
fi

echo "✅ Copilot hooks written to ${HOOKS_FILE}"
SETUPEOF
    chmod +x /usr/local/bin/peon-ping-copilot-setup

    echo "   ✅ Helper installed: peon-ping-copilot-setup"
    echo "   Run it from your workspace root (or add to postCreateCommand) to generate .github/hooks/hooks.json"
fi

# ── Cursor hooks ─────────────────────────────────────────────────────────────

if ide_enabled cursor; then
    echo "🔧 Configuring Cursor hooks..."

    CURSOR_HOOKS_JSON='{
        "afterAgentResponse": [{"command": "bash ~/.claude/hooks/peon-ping/adapters/cursor.sh afterAgentResponse"}],
        "stop":               [{"command": "bash ~/.claude/hooks/peon-ping/adapters/cursor.sh stop"}]
    }'

    CURSOR_HOOKS_FILE="${USER_HOME}/.cursor/hooks.json"
    merge_hooks_json "${CURSOR_HOOKS_FILE}" "${CURSOR_HOOKS_JSON}"
    chown -R "${USERNAME}:${USERNAME}" "${USER_HOME}/.cursor" 2>/dev/null || true

    echo "   ✅ Cursor hooks written to ${CURSOR_HOOKS_FILE}"
fi

# ── OpenAI Codex hooks ───────────────────────────────────────────────────────

if ide_enabled codex; then
    echo "🔧 Configuring Codex hooks..."

    CODEX_CONFIG_DIR="${USER_HOME}/.codex"
    CODEX_CONFIG="${CODEX_CONFIG_DIR}/config.toml"

    mkdir -p "${CODEX_CONFIG_DIR}"

    if [ -f "${CODEX_CONFIG}" ]; then
        if ! grep -q "peon-ping" "${CODEX_CONFIG}"; then
            printf '\nnotify = ["bash", "~/.claude/hooks/peon-ping/adapters/codex.sh"]\n' >> "${CODEX_CONFIG}"
        fi
    else
        cat > "${CODEX_CONFIG}" << 'EOF'
notify = ["bash", "~/.claude/hooks/peon-ping/adapters/codex.sh"]
EOF
    fi

    chown -R "${USERNAME}:${USERNAME}" "${CODEX_CONFIG_DIR}" 2>/dev/null || true

    echo "   ✅ Codex hooks written to ${CODEX_CONFIG}"
fi

# ── Verify installation ─────────────────────────────────────────────────────

echo ""
echo "🔍 Verifying installation..."

PEON_BIN="${USER_HOME}/.local/bin/peon"
if [ -x "${PEON_BIN}" ] || su - "${USERNAME}" -c "command -v peon" > /dev/null 2>&1; then
    echo "   ✅ peon binary found"
else
    echo "   ⚠️  peon binary not found in PATH (may need shell restart)"
fi

if [ -d "${PEON_CONFIG_DIR}" ]; then
    echo "   ✅ peon-ping config directory found at ${PEON_CONFIG_DIR}"
else
    echo "   ⚠️  peon-ping config directory not found"
fi

echo ""
echo "🎮 peon-ping installation complete!"
echo ""
echo "   ⚠️  IMPORTANT — Audio in devcontainers:"
echo "   Start the relay on your HOST machine:"
echo ""
echo "       peon relay --daemon"
echo ""
echo "   The container routes audio to host.docker.internal:19998 automatically."
echo ""
