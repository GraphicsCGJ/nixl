#!/bin/bash
# NIXL Host Installation - Build NIXL and NIXLBench
# This script can be run without sudo

set -e

# Configuration
NIXL_INSTALL_PREFIX="${NIXL_INSTALL_PREFIX:-$HOME/.local/nixl}"
NIXLBENCH_INSTALL_PREFIX="${NIXLBENCH_INSTALL_PREFIX:-$HOME/.local/nixlbench}"
NIXL_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NIXLBENCH_SOURCE_DIR="${NIXL_SOURCE_DIR}/benchmark/nixlbench"
BUILD_TYPE="${BUILD_TYPE:-release}"

echo "=== NIXL Host Installation - Build ==="
echo ""
echo "Configuration:"
echo "  Source Directory: $NIXL_SOURCE_DIR"
echo "  NIXL Install Prefix: $NIXL_INSTALL_PREFIX"
echo "  NIXLBench Install Prefix: $NIXLBENCH_INSTALL_PREFIX"
echo "  Build Type: $BUILD_TYPE"
echo ""

# Create virtual environment if needed
if [ ! -d ".venv" ]; then
  echo "[1/5] Creating Python virtual environment..."
  python3.12 -m venv .venv
  source .venv/bin/activate
  pip install --upgrade pip setuptools wheel
  pip install meson pybind11 patchelf pyYAML click tabulate torch
else
  echo "[1/5] Using existing Python virtual environment..."
  source .venv/bin/activate
fi

# Build NIXL
echo "[2/5] Building NIXL library..."
cd "$NIXL_SOURCE_DIR"
rm -rf build
meson setup build --prefix=$NIXL_INSTALL_PREFIX --buildtype=$BUILD_TYPE
cd build
ninja
echo "    ℹ Next: sudo ninja install (requires root)"

echo "[3/5] Installing NIXL..."
ninja install
echo "    ✓ NIXL installed to: $NIXL_INSTALL_PREFIX"

# Build NIXLBench
echo ""
echo "[4/5] Building NIXLBench benchmark tool..."
cd "$NIXLBENCH_SOURCE_DIR"
rm -rf build
meson setup build \
  -Dnixl_path=$NIXL_INSTALL_PREFIX/ \
  -Dprefix=$NIXLBENCH_INSTALL_PREFIX \
  --buildtype=$BUILD_TYPE
cd build
ninja
echo "[5/5] Installing NIXLBench..."
ninja install
echo "    ✓ NIXLBench installed to: $NIXLBENCH_INSTALL_PREFIX"

echo ""
echo "=== Build & Installation Complete ==="
echo ""
echo "✓ NIXL:       $NIXL_INSTALL_PREFIX"
echo "✓ NIXLBench:  $NIXLBENCH_INSTALL_PREFIX"
echo ""
echo "📌 환경 변수 설정 (추가 단계):"
echo ""
echo "  ~/.bashrc 또는 ~/.zshrc에 다음 추가:"
echo ""
echo "  export PATH=$NIXLBENCH_INSTALL_PREFIX/bin:$NIXL_INSTALL_PREFIX/bin:\$PATH"
echo "  export LD_LIBRARY_PATH=$NIXLBENCH_INSTALL_PREFIX/lib:$NIXL_INSTALL_PREFIX/lib/x86_64-linux-gnu:\$LD_LIBRARY_PATH"
echo ""
echo "  적용:"
echo "  source ~/.bashrc"
echo ""
echo "✅ sudo 필요 없음! 모든 설치가 완료되었습니다."
echo ""
