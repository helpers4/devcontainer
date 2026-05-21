#!/usr/bin/env bash

# Package Auto-Install DevContainer Feature
# Copyright (C) 2025 baxyz
# Licensed under LGPL-3.0 - see LICENSE file for details
#
# Automatically detects and installs npm/yarn/pnpm packages

set -e

echo "🔧 Setting up package-auto-install devcontainer feature..."

# Get options
COMMAND="${COMMAND:-auto}"
PACKAGE_MANAGER="${PACKAGEMANAGER:-auto}"
WORKING_DIR="${WORKINGDIRECTORY:-/workspaces}"
SKIP_IF_EXISTS="${SKIPIFNODEMODULESEXISTS:-false}"
ADDITIONAL_ARGS="${ADDITIONALARGS:-}"

# Create the installation script
cat > /usr/local/bin/devcontainer-package-install << 'EOFSCRIPT'
#!/usr/bin/env bash

set -e

# Get configuration from environment or use defaults
COMMAND="${COMMAND:-auto}"
PACKAGE_MANAGER="${PACKAGEMANAGER:-auto}"
WORKING_DIR="${WORKINGDIRECTORY:-/workspaces}"
SKIP_IF_EXISTS="${SKIPIFNODEMODULESEXISTS:-false}"
ADDITIONAL_ARGS="${ADDITIONALARGS:-}"

echo "📦 Starting automatic package installation..."
echo "   Working directory: ${WORKING_DIR}"

# Find the actual workspace directory
if [ ! -d "${WORKING_DIR}" ]; then
    # Try to find workspace
    if [ -d "/workspaces" ] && [ "$(ls -A /workspaces 2>/dev/null)" ]; then
        WORKING_DIR="/workspaces/$(ls /workspaces | head -n1)"
        echo "   Detected workspace: ${WORKING_DIR}"
    else
        echo "❌ Working directory not found: ${WORKING_DIR}"
        exit 0
    fi
fi

cd "${WORKING_DIR}" || {
    echo "❌ Cannot access directory: ${WORKING_DIR}"
    exit 0
}

# Check if package.json exists
if [ ! -f "package.json" ]; then
    echo "ℹ️  No package.json found, skipping installation"
    exit 0
fi

# Check if node_modules exists and skip if requested
if [ "$SKIP_IF_EXISTS" = "true" ] && [ -d "node_modules" ]; then
    echo "✅ node_modules already exists, skipping installation"
    exit 0
fi

# Extract packageManager field from package.json
get_package_manager_from_json() {
    if command -v jq >/dev/null 2>&1; then
        jq -r '.packageManager // empty' package.json 2>/dev/null | cut -d'@' -f1
    else
        grep -o '"packageManager"[[:space:]]*:[[:space:]]*"[^"]*"' package.json 2>/dev/null | \
            sed 's/.*"\([^@"]*\)[@"].*/\1/'
    fi
}

# Setup corepack if packageManager field exists
setup_corepack() {
    local pkg_manager_field=$(get_package_manager_from_json)
    
    if [ -n "$pkg_manager_field" ]; then
        echo "   Found packageManager: $pkg_manager_field"
        
        if ! command -v corepack >/dev/null 2>&1; then
            echo "   Installing corepack..."
            npm install -g corepack 2>/dev/null || echo "   ⚠️  corepack install failed"
        fi
        
        if command -v corepack >/dev/null 2>&1; then
            corepack enable 2>/dev/null && echo "   ✅ corepack enabled"
        fi
        
        echo "$pkg_manager_field"
    fi
}

# Detect package manager
detect_package_manager() {
    # Priority 1: packageManager field in package.json
    local from_json=$(setup_corepack)
    if [ -n "$from_json" ]; then
        echo "$from_json"
        return
    fi
    
    # Priority 2: lockfiles
    [ -f "pnpm-lock.yaml" ] && echo "pnpm" && return
    [ -f "yarn.lock" ] && echo "yarn" && return
    [ -f "package-lock.json" ] && echo "npm" && return
    
    # Default
    echo "npm"
}

# Auto-detect package manager if needed
if [ "$PACKAGE_MANAGER" = "auto" ]; then
    PACKAGE_MANAGER=$(detect_package_manager)
    echo "   Package manager: ${PACKAGE_MANAGER}"
fi

# Check if package manager is available
if ! command -v "${PACKAGE_MANAGER}" >/dev/null 2>&1; then
    echo "❌ Package manager '${PACKAGE_MANAGER}' not found"
    exit 1
fi

# Detect install command if auto
get_install_command() {
    case "$PACKAGE_MANAGER" in
        npm)
            [ -f "package-lock.json" ] && echo "ci" || echo "install"
            ;;
        pnpm)
            [ -f "pnpm-lock.yaml" ] && echo "install --frozen-lockfile" || echo "install"
            ;;
        yarn)
            local yarn_version=$(yarn --version 2>/dev/null | cut -d. -f1)
            if [ "$yarn_version" -ge 2 ] 2>/dev/null; then
                [ -f "yarn.lock" ] && echo "install --immutable" || echo "install"
            else
                [ -f "yarn.lock" ] && echo "install --frozen-lockfile" || echo "install"
            fi
            ;;
        *)
            echo "install"
            ;;
    esac
}

if [ "$COMMAND" = "auto" ]; then
    COMMAND=$(get_install_command)
fi

# Ensure CI=true is set
export CI=true

# Run the installation
echo "🚀 Running: ${PACKAGE_MANAGER} ${COMMAND} ${ADDITIONAL_ARGS}"
echo ""

if ${PACKAGE_MANAGER} ${COMMAND} ${ADDITIONAL_ARGS}; then
    echo ""
    echo "✅ Package installation completed successfully"
    exit 0
else
    echo ""
    echo "❌ Package installation failed with exit code $?"
    exit 1
fi
EOFSCRIPT

# Make the script executable
chmod +x /usr/local/bin/devcontainer-package-install

# Store configuration in environment for the script
cat >> /etc/environment << EOF
COMMAND=${COMMAND}
PACKAGEMANAGER=${PACKAGE_MANAGER}
WORKINGDIRECTORY=${WORKING_DIR}
SKIPIFNODEMODULESEXISTS=${SKIP_IF_EXISTS}
ADDITIONALARGS=${ADDITIONAL_ARGS}
EOF

echo "✅ package-auto-install feature installed"
echo "   The installation will run automatically after container creation"
