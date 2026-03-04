#!/bin/bash
# NIXL Host Installation - System Dependencies Setup

set -e

# ---------------------------------------------------------------------------
# Uninstall: remove previously source-built dependencies from /usr/local
# ---------------------------------------------------------------------------
uninstall_deps() {
  echo "  Removing UCX..."
  sudo rm -f  /usr/local/lib/libucm.so*  \
              /usr/local/lib/libucp.so*  \
              /usr/local/lib/libucs.so*  \
              /usr/local/lib/libucs_signal.so* \
              /usr/local/lib/libuct.so*
  sudo rm -f  /usr/local/lib/pkgconfig/ucx*.pc \
              /usr/local/lib/pkgconfig/ucx-*.pc
  sudo rm -rf /usr/local/include/ucm \
              /usr/local/include/ucp \
              /usr/local/include/ucs \
              /usr/local/include/uct \
              /usr/local/lib/ucx \
              /usr/local/lib/cmake/ucx
  sudo rm -f  /usr/local/bin/ucx_info \
              /usr/local/bin/ucx_perftest \
              /usr/local/bin/ucx_perftest_daemon \
              /usr/local/bin/ucx_read_profile \
              /usr/local/bin/io_demo

  echo "  Removing etcd-cpp-api..."
  sudo rm -f  /usr/local/lib/libetcd-cpp-api*.so*
  sudo rm -rf /usr/local/include/etcd \
              /usr/local/lib/cmake/etcd-cpp-api

  echo "  Removing /tmp build directories..."
  sudo rm -rf /tmp/ucx-master /tmp/ucx-*.* /tmp/etcd-cpp-apiv3

  sudo ldconfig
  echo "  ✓ Uninstall complete"
}

# ---------------------------------------------------------------------------
echo "=== NIXL Host Installation - System Dependencies ==="
echo "This script will install system dependencies required for building NIXL"
echo ""

# Uninstall previous source-built deps before reinstalling
echo "[0/6] Uninstalling previous source-built dependencies..."
uninstall_deps
echo ""

# Update package lists
echo "[1/6] Updating package lists..."
sudo apt-get update

# Install core build tools and dependencies
echo "[2/6] Installing build tools and development libraries..."
sudo apt-get install -y \
  build-essential cmake ninja-build pkg-config \
  autotools-dev automake libtool libz-dev flex \
  libgtest-dev hwloc libhwloc-dev libgflags-dev \
  libgrpc-dev libgrpc++-dev libprotobuf-dev \
  libaio-dev liburing-dev protobuf-compiler-grpc \
  libcpprest-dev etcd-server etcd-client \
  pybind11-dev libclang-dev libcurl4-openssl-dev \
  libssl-dev uuid-dev libxml2-dev zlib1g-dev python3-dev python3-pip \
  git curl wget

# Install RDMA/InfiniBand packages
echo "[3/6] Installing RDMA/InfiniBand libraries..."
sudo apt-get install -y \
  autoconf libnuma-dev librdmacm-dev ibverbs-providers \
  libibverbs-dev rdma-core ibverbs-utils libibumad-dev

# Remove apt UCX packages to avoid header conflicts with source-built UCX
sudo apt-get remove -y libucx-dev libucx0 2>/dev/null || true

# Build and install UCX from git master (UCS_BIT_GET is only in master, not yet released)
echo "[4/6] Building UCX from git master..."
git clone --depth 1 https://github.com/openucx/ucx.git /tmp/ucx-master
cd /tmp/ucx-master
./autogen.sh
./configure \
  --prefix=/usr/local \
  --with-rdmacm \
  --with-verbs \
  --without-cuda \
  --enable-shared \
  --disable-static \
  --disable-logging \
  --disable-debug \
  --disable-assertions \
  --disable-params-check
make -j$(nproc) && sudo make install
sudo ldconfig
echo "  ✓ UCX (master) installed"

# Install etcd-cpp-api (required for metadata exchange)
echo "[5/6] Building and installing etcd-cpp-api..."
git clone --depth 1 https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3.git /tmp/etcd-cpp-apiv3
cd /tmp/etcd-cpp-apiv3
sed -i '/^find_dependency(cpprestsdk)$/d' etcd-cpp-api-config.in.cmake 2>/dev/null || true
mkdir -p build && cd build
cmake .. \
  -DBUILD_ETCD_CORE_ONLY=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc) && sudo make install
sudo ldconfig
echo "  ✓ etcd-cpp-api installed"

# Cleanup /tmp build directories
echo "  Cleaning up /tmp build directories..."
sudo rm -rf /tmp/ucx-master /tmp/etcd-cpp-apiv3

# Install Python package manager (uv) - optional
echo "[6/6] uv (Python package manager) installation..."
if command -v uv &> /dev/null; then
  echo "  ✓ uv is already installed"
else
  echo "  Note: uv is optional. The build script uses standard venv if uv is not available."
  echo "  To install uv: curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

echo ""
echo "✓ System dependencies installed successfully!"
echo ""
echo "Next steps:"
echo "1. Install CUDA Toolkit (if GPU support needed):"
echo "   wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_550.54.15_linux.run"
echo "   sudo sh cuda_12.8.0_550.54.15_linux.run"
echo ""
echo "2. Run the build script:"
echo "   ./build.sh"
echo ""
