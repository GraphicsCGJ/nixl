#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# Check if NIXL is properly installed (Python package + C++ bindings)

# Installation paths (same as build.sh defaults)
NIXL_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$NIXL_SOURCE_DIR/env.sh" ] && source "$NIXL_SOURCE_DIR/env.sh"
NIXL_INSTALL_PREFIX="${NIXL_INSTALL_PREFIX:-$NIXL_SOURCE_DIR/install/nixl}"
ARCH=$(uname -m); [ "$ARCH" = "arm64" ] && ARCH="aarch64"
NIXL_LIB_PATH="$NIXL_INSTALL_PREFIX/lib/$ARCH-linux-gnu"
NIXL_BIN_PATH="$NIXL_INSTALL_PREFIX/bin"

check_nixl_installed() {
    # Check 1: Python package installed via pip
    if ! python3 -c "import nixl" 2>/dev/null; then
        return 1  # Python package not installed
    fi

    # Check 2: C++ shared libraries compiled and installed
    # Look for .so files (nixl library objects)
    if ! find "$NIXL_LIB_PATH" -name "*.so*" 2>/dev/null | grep -q .; then
        return 1  # No .so files found
    fi

    # Check 3: Binary executables installed
    if ! find "$NIXL_BIN_PATH" -type f -executable 2>/dev/null | grep -q .; then
        return 1  # No executables found
    fi

    # Check 4: Try to import and access nixl functionality
    if ! python3 -c "import nixl; nixl.__version__" 2>/dev/null; then
        return 1  # Module loaded but version not accessible
    fi

    return 0  # All checks passed
}

# Detailed check (verbose output)
check_nixl_detailed() {
    echo "=== NIXL Installation Check ==="
    echo ""

    # Check Python package
    echo "1. Python Package (nixl-cu12):"
    if python3 -c "import nixl" 2>/dev/null; then
        VERSION=$(python3 -c "import importlib.metadata; print(importlib.metadata.version('nixl-cu12'))" 2>/dev/null)
        echo "   ✓ Installed (version: $VERSION)"
    else
        echo "   ✗ NOT installed"
    fi
    echo ""

    # Check C++ libraries
    echo "2. C++ Libraries (.so files):"
    echo "   Path: $NIXL_LIB_PATH"
    SO_COUNT=$(find "$NIXL_LIB_PATH" -name "*.so*" 2>/dev/null | wc -l)
    if [ "$SO_COUNT" -gt 0 ]; then
        echo "   ✓ Found $SO_COUNT library files"
        find "$NIXL_LIB_PATH" -name "*.so*" 2>/dev/null | sed 's/^/     - /'
    else
        echo "   ✗ NO library files found"
    fi
    echo ""

    # Check binaries
    echo "3. Binary Executables:"
    echo "   Path: $NIXL_BIN_PATH"
    BIN_COUNT=$(find "$NIXL_BIN_PATH" -type f -executable 2>/dev/null | wc -l)
    if [ "$BIN_COUNT" -gt 0 ]; then
        echo "   ✓ Found $BIN_COUNT executable(s)"
        find "$NIXL_BIN_PATH" -type f -executable 2>/dev/null | sed 's/^/     - /'
    else
        echo "   ✗ NO executables found"
    fi
    echo ""

    # Overall status
    echo "=== Summary ==="
    if check_nixl_installed; then
        echo "✓ NIXL is FULLY installed and ready to use"
        return 0
    else
        echo "✗ NIXL is NOT properly installed"
        return 1
    fi
}

# Main execution
if [ "${1:-}" = "-v" ] || [ "${1:-}" = "--verbose" ] || [ "${1:-}" = "--detailed" ]; then
    check_nixl_detailed
    EXIT_CODE=$?
else
    # Simple true/false output
    if check_nixl_installed; then
        echo "true"
        exit 0
    else
        echo "false"
        exit 1
    fi
fi

exit $EXIT_CODE
