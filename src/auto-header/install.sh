#!/usr/bin/env bash
# This file is part of helpers4.
# Copyright (C) 2025 baxyz
# SPDX-License-Identifier: LGPL-3.0-or-later
#
# auto-header devcontainer feature — installer.
#
# Generates the psi-header VS Code settings from the feature options and
# writes them directly to the remote user's Machine settings inside the
# container, so every workspace opened in the container picks them up
# automatically — no need for users to edit .code-workspace or .vscode/.

set -e

echo "🔧 Setting up auto-header devcontainer feature..."

# ---------------------------------------------------------------------------
# Read feature options (devcontainer-feature.json)
# ---------------------------------------------------------------------------
HEADER_TYPE="${HEADERTYPE:-simple}"
PROJECT_NAME="${PROJECTNAME}"
LICENSE="${LICENSE:-MIT}"
COMPANY="${COMPANY}"
CONTRIBUTORS="${CONTRIBUTORS}"
SINCE_YEAR="${SINCEYEAR}"
CUSTOM_HEADER_LINES="${CUSTOMHEADERLINES}"

[ -z "$PROJECT_NAME" ] && PROJECT_NAME="$(basename "$PWD")"
[ -z "$SINCE_YEAR" ] && SINCE_YEAR="$(date +%Y)"

if [ "$HEADER_TYPE" != "simple" ] && [ "$HEADER_TYPE" != "custom" ]; then
    echo "❌ headerType must be 'simple' or 'custom'"
    exit 1
fi
if [ "$HEADER_TYPE" = "custom" ] && [ -z "$CUSTOM_HEADER_LINES" ]; then
    echo "❌ customHeaderLines is required when headerType is 'custom'"
    exit 1
fi

# Persist the raw config (informational; not strictly needed once Machine
# settings are written, but useful for debugging / inspection / tests).
CONFIG_DIR="/etc/h4-auto-header"
mkdir -p "$CONFIG_DIR"

# Resolve the remote user's home up-front so we can persist the path the
# installer actually writes to (build-time and runtime may resolve users
# differently — `_REMOTE_USER` is set during build but not when tests run).
TARGET_USER="${_REMOTE_USER:-${REMOTE_USER:-node}}"
if PASSWD_ENTRY=$(getent passwd "$TARGET_USER" 2>/dev/null); then
    TARGET_HOME=$(printf '%s\n' "$PASSWD_ENTRY" | cut -d: -f6)
fi
[ -z "${TARGET_HOME:-}" ] && TARGET_HOME="/home/$TARGET_USER"
MACHINE_FILE="$TARGET_HOME/.vscode-server/data/Machine/settings.json"

jq -n \
    --arg headerType "$HEADER_TYPE" \
    --arg projectName "$PROJECT_NAME" \
    --arg license "$LICENSE" \
    --arg company "$COMPANY" \
    --arg contributors "$CONTRIBUTORS" \
    --arg sinceYear "$SINCE_YEAR" \
    --arg customHeaderLines "$CUSTOM_HEADER_LINES" \
    --arg targetUser "$TARGET_USER" \
    --arg targetHome "$TARGET_HOME" \
    --arg machineSettingsFile "$MACHINE_FILE" \
    '{headerType:$headerType,projectName:$projectName,license:$license,company:$company,contributors:$contributors,sinceYear:$sinceYear,customHeaderLines:$customHeaderLines,targetUser:$targetUser,targetHome:$targetHome,machineSettingsFile:$machineSettingsFile}' \
    > "$CONFIG_DIR/config.json"

# ---------------------------------------------------------------------------
# Build the psi-header settings JSON from the feature options.
# ---------------------------------------------------------------------------
CURRENT_YEAR=$(date +%Y)
if [ "$SINCE_YEAR" = "$CURRENT_YEAR" ]; then
    COPYRIGHT_YEARS="$SINCE_YEAR"
else
    COPYRIGHT_YEARS="$SINCE_YEAR-$CURRENT_YEAR"
fi

if [ -n "$COMPANY" ]; then
    COPYRIGHT_ENTITY="$COMPANY"
else
    COPYRIGHT_ENTITY="$PROJECT_NAME"
fi

if [ "$HEADER_TYPE" = "custom" ]; then
    # Custom mode: user provides the literal header lines (separated by '\n').
    # Placeholders are substituted before injection: {{projectName}}, {{license}},
    # {{company}}, {{contributors}}, {{sinceYear}}, {{currentYear}},
    # {{copyrightYears}}, {{author}}.
    EXPANDED="$CUSTOM_HEADER_LINES"
    EXPANDED="${EXPANDED//\{\{projectName\}\}/$PROJECT_NAME}"
    EXPANDED="${EXPANDED//\{\{license\}\}/$LICENSE}"
    EXPANDED="${EXPANDED//\{\{company\}\}/${COMPANY:-}}"
    EXPANDED="${EXPANDED//\{\{contributors\}\}/${CONTRIBUTORS:-}}"
    EXPANDED="${EXPANDED//\{\{sinceYear\}\}/$SINCE_YEAR}"
    EXPANDED="${EXPANDED//\{\{currentYear\}\}/$CURRENT_YEAR}"
    EXPANDED="${EXPANDED//\{\{copyrightYears\}\}/$COPYRIGHT_YEARS}"
    EXPANDED="${EXPANDED//\{\{author\}\}/$COPYRIGHT_ENTITY}"
    # Split on the two-character sequence "\n" into a JSON string array.
    TEMPLATE_LINES=$(jq -Rn --arg s "$EXPANDED" '$s | split("\\n")' 2>/dev/null || echo '')
    # Validate the resulting JSON; fall back to simple template on any error.
    if ! printf '%s' "$TEMPLATE_LINES" | jq -e 'type == "array"' >/dev/null 2>&1; then
        echo "⚠️  customHeaderLines could not be parsed, falling back to simple header"
        TEMPLATE_LINES=$(jq -n \
            --arg p "This file is part of $PROJECT_NAME." \
            --arg c "Copyright (C) $COPYRIGHT_YEARS $COPYRIGHT_ENTITY" \
            --arg s "SPDX-License-Identifier: $LICENSE" \
            '[$p,$c,$s]')
    fi
else
    TEMPLATE_LINES=$(jq -n \
        --arg p "This file is part of $PROJECT_NAME." \
        --arg c "Copyright (C) $COPYRIGHT_YEARS $COPYRIGHT_ENTITY" \
        --arg s "SPDX-License-Identifier: $LICENSE" \
        '[$p,$c,$s]')
fi

mk_template() {
    jq -n --arg lang "$1" --argjson lines "$TEMPLATE_LINES" \
        '{language:$lang, template:$lines}'
}
mk_lang_block() {
    # $1=lang $2=begin $3=prefix $4=end
    jq -n --arg lang "$1" --arg begin "$2" --arg prefix "$3" --arg end "$4" \
        '{language:$lang, begin:$begin, prefix:$prefix, end:$end, blankLinesAfter:1}'
}

TEMPLATES=$(jq -s '.' \
    <(mk_template typescript) \
    <(mk_template javascript) \
    <(mk_template python) \
    <(mk_template shell) \
    <(mk_template shellscript) \
    <(mk_template yaml) \
    <(mk_template markdown) \
    <(mk_template html) \
    <(mk_template css) \
    <(mk_template jsonc))

LANG_CONFIG=$(jq -s '.' \
    <(mk_lang_block typescript "/**" " * " " */") \
    <(mk_lang_block javascript "/**" " * " " */") \
    <(mk_lang_block python "###" "# " "###") \
    <(mk_lang_block shell "" "# " "") \
    <(mk_lang_block shellscript "" "# " "") \
    <(mk_lang_block yaml "" "# " "") \
    <(mk_lang_block markdown "<!--" "" "-->") \
    <(mk_lang_block html "<!--" "" "-->") \
    <(mk_lang_block css "/*" " * " " */") \
    <(mk_lang_block jsonc "" "// " ""))

PSI=$(jq -n \
    --arg author "$COPYRIGHT_ENTITY" \
    --arg company "${COMPANY:-}" \
    --argjson templates "$TEMPLATES" \
    --argjson langs "$LANG_CONFIG" \
    '{
        "psi-header.config": {
            author: $author,
            authorEmail: "",
            license: "Custom",
            company: $company,
            forceToTop: true
        },
        "psi-header.templates": $templates,
        "psi-header.changes-tracking": {
            isActive: true,
            modAuthor: $author,
            modDate: " - modDate",
            modDateFormat: "dd/MM/yyyy",
            include: ["typescript","javascript","python","shell","shellscript","yaml","markdown","html","css","jsonc"],
            exclude: ["plaintext"]
        },
        "psi-header.lang-config": $langs
    }')

# ---------------------------------------------------------------------------
# Apply the psi-header settings to the remote user's Machine settings.
# Machine settings live at:
#   ~/.vscode-server/data/Machine/settings.json
# They are loaded by VS Code for any workspace opened in this container.
# ($TARGET_USER / $TARGET_HOME / $MACHINE_FILE were resolved above.)
# ---------------------------------------------------------------------------
MACHINE_DIR="$TARGET_HOME/.vscode-server/data/Machine"

mkdir -p "$MACHINE_DIR"
if [ ! -f "$MACHINE_FILE" ]; then
    echo "{}" > "$MACHINE_FILE"
fi

# Strip JSONC line comments before merging (VS Code tolerates them, jq doesn't).
# If the existing settings.json is unparseable AFTER stripping comments, we
# refuse to silently overwrite it: a backup is always produced, and the user
# is asked to fix the file manually. This avoids data-loss when the user has
# hand-edited their Machine settings with a syntax error.
TMP_EXISTING=$(mktemp)
sed -E 's://[^"]*$::g' "$MACHINE_FILE" > "$TMP_EXISTING" || cp "$MACHINE_FILE" "$TMP_EXISTING"
if ! jq -e . "$TMP_EXISTING" >/dev/null 2>&1; then
    BACKUP="$MACHINE_FILE.bak.$(date +%Y%m%d-%H%M%S)"
    cp -f "$MACHINE_FILE" "$BACKUP" 2>/dev/null || true
    echo "❌ $MACHINE_FILE is not valid JSON (even after stripping // comments)."
    echo "   A backup has been written to: $BACKUP"
    echo "   Refusing to overwrite to avoid losing your settings."
    echo "   Fix the file manually and rebuild the container, or delete it to start fresh."
    rm -f "$TMP_EXISTING"
    exit 1
fi

jq -s '.[0] * .[1]' "$TMP_EXISTING" <(echo "$PSI") > "$MACHINE_FILE"
rm -f "$TMP_EXISTING"

chown -R "$TARGET_USER":"$TARGET_USER" "$TARGET_HOME/.vscode-server" 2>/dev/null || true

echo "✅ psi-header settings written to $MACHINE_FILE"
echo "✅ auto-header feature installed"
echo "   Project: $PROJECT_NAME | License: $LICENSE | Since: $SINCE_YEAR"
echo "💡 Settings active for every workspace opened in this container."
