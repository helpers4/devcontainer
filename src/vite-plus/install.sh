#!/usr/bin/env bash

# Vite+ DevContainer Feature
# Copyright (c) 2025 helpers4
# Licensed under AGPL-3.0 - see LICENSE file for details
#
# Sets up Vite+ development environment with Oxc, Vitest, and VS Code configuration

set -e

echo "🔧 Setting up viteplus devcontainer feature..."

# Get options
INSTALL_VITE="${INSTALLVITE:-true}"
INSTALL_VITEST="${INSTALLVITEST:-true}"
INSTALL_VITE_PLUS="${INSTALLVITEPLUS:-false}"
INSTALL_OXC="${INSTALLOXC:-true}"
ENABLE_EXPERIMENTAL_FORMATTER="${ENABLEEXPERIMENTALFORMATTER:-true}"

# Check if node/npm is available
if ! command -v npm >/dev/null 2>&1; then
    echo "❌ npm not found. Please ensure Node.js feature is installed first."
    exit 1
fi

# Install Oxc CLI globally if requested
if [ "$INSTALL_OXC" = "true" ]; then
    echo "📦 Installing Oxc CLI globally..."
    if npm install -g oxc-language-server 2>/dev/null; then
        echo "✅ Oxc CLI installed"
        
        # Verify installation
        if command -v oxc >/dev/null 2>&1; then
            OXC_VERSION=$(oxc --version 2>/dev/null || echo "unknown")
            echo "   Version: ${OXC_VERSION}"
        fi
    else
        echo "⚠️  Failed to install Oxc CLI, but continuing..."
    fi
fi

# Install Vite if requested
if [ "$INSTALL_VITE" = "true" ]; then
    echo "📦 Installing Vite CLI globally..."
    if npm install -g vite 2>/dev/null; then
        echo "✅ Vite CLI installed"
        if command -v vite >/dev/null 2>&1; then
            VITE_VERSION=$(vite --version 2>/dev/null || echo "unknown")
            echo "   Version: ${VITE_VERSION}"
        fi
    else
        echo "⚠️  Failed to install Vite CLI, but continuing..."
    fi
fi

# Install Vitest if requested
if [ "$INSTALL_VITEST" = "true" ]; then
    echo "📦 Installing Vitest CLI globally..."
    if npm install -g vitest 2>/dev/null; then
        echo "✅ Vitest CLI installed"
        if command -v vitest >/dev/null 2>&1; then
            VITEST_VERSION=$(vitest --version 2>/dev/null || echo "unknown")
            echo "   Version: ${VITEST_VERSION}"
        fi
    else
        echo "⚠️  Failed to install Vitest CLI, but continuing..."
    fi
fi

# Install Vite+ if requested (currently in early access)
if [ "$INSTALL_VITE_PLUS" = "true" ]; then
    echo "📦 Installing Vite+ CLI globally..."
    echo "   Note: Vite+ is currently in early access"
    
    # Check if vite+ is available on npm
    if npm view vite-plus version >/dev/null 2>&1; then
        if npm install -g vite-plus 2>/dev/null; then
            echo "✅ Vite+ CLI installed"
            if command -v vite-plus >/dev/null 2>&1; then
                VITEPLUS_VERSION=$(vite-plus --version 2>/dev/null || echo "unknown")
                echo "   Version: ${VITEPLUS_VERSION}"
            fi
        else
            echo "⚠️  Failed to install Vite+ CLI"
            echo "   You may need to wait for official release or join early access"
        fi
    else
        echo "ℹ️  Vite+ not yet available on npm"
        echo "   Register at: https://tally.so/r/nGWebL"
    fi
fi

# Create a helper script for project setup
cat > /usr/local/bin/vite-plus-init << 'EOFSCRIPT'
#!/usr/bin/env bash

# Vite+ Project Initialization Helper
set -e

echo "🚀 Vite+ Project Setup Helper"
echo ""

# Check if we're in a project directory
if [ ! -f "package.json" ]; then
    echo "❌ No package.json found. Please run this from your project root."
    exit 1
fi

echo "📋 Recommended Vite+ dependencies:"
echo ""
echo "Core toolchain:"
echo "  npm install -D vite vitest oxc-linter oxc-formatter"
echo ""
echo "For React projects:"
echo "  npm install -D @vitejs/plugin-react"
echo ""
echo "For Vue projects:"
echo "  npm install -D @vitejs/plugin-vue"
echo ""
echo "For type checking:"
echo "  npm install -D typescript @types/node"
echo ""
echo "Example vite.config.ts:"
echo "  import { defineConfig } from 'vite'"
echo "  export default defineConfig({"
echo "    plugins: [],"
echo "    test: {"
echo "      globals: true,"
echo "      environment: 'happy-dom'"
echo "    }"
echo "  })"
echo ""
echo "Example oxc.config.json:"
echo "  {"
echo "    \"lint\": {"
echo "      \"rules\": {}"
echo "    },"
echo "    \"format\": {"
echo "      \"indentWidth\": 2"
echo "    }"
echo "  }"
echo ""
EOFSCRIPT

chmod +x /usr/local/bin/vite-plus-init

echo ""
echo "✅ Vite+ feature installed successfully!"
echo ""
echo "📝 Next steps:"
echo "   1. Your VS Code is now configured with Oxc formatter and Vitest"
echo "   2. Run 'vite-plus-init' in your project to see setup recommendations"
echo "   3. Install project dependencies with your package manager"
echo ""
echo "🔗 Resources:"
echo "   - Vite+: https://viteplus.dev/"
echo "   - Vitest: https://vitest.dev/"
echo "   - Oxc: https://oxc.rs/"
echo "   - Vite: https://vite.dev/"
