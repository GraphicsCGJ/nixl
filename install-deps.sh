#!/bin/bash
# NIXL Host Installation - System Dependencies Setup
# This script must be run with sudo privileges

set -e

# Check for root/sudo
if [ "$EUID" -ne 0 ]; then
  echo "Error: This script must be run with sudo. Try: sudo $0"
  exit 1
fi

echo "=== NIXL Host Installation - System Dependencies ==="
echo "This script will install system dependencies required for building NIXL"
echo ""

# Update package lists
echo "[1/5] Updating package lists..."
apt-get update

# Install core build tools and dependencies
echo "[2/5] Installing build tools and development libraries..."
apt-get install -y \
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
echo "[3/5] Installing RDMA/InfiniBand libraries..."
apt-get install -y \
  autoconf libnuma-dev librdmacm-dev ibverbs-providers \
  libibverbs-dev rdma-core ibverbs-utils libibumad-dev

# Build and install UCX from source (requires >= 1.17 for UCS_BIT_GET)
UCX_VERSION="1.17.0"
echo "[4/5] Building UCX ${UCX_VERSION} from source..."
cd /tmp
if [ ! -d "ucx-${UCX_VERSION}" ]; then
  wget -q "https://github.com/openucx/ucx/releases/download/v${UCX_VERSION}/ucx-${UCX_VERSION}.tar.gz"
  tar xf "ucx-${UCX_VERSION}.tar.gz"
fi
cd "ucx-${UCX_VERSION}"
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
make -j$(nproc) && make install
ldconfig
echo "  ✓ UCX ${UCX_VERSION} installed"

# Install etcd-cpp-api (required for metadata exchange)
echo "[5/5] Building and installing etcd-cpp-api..."
cd /tmp
if [ ! -d "etcd-cpp-apiv3" ]; then
  git clone --depth 1 https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3.git
fi
cd etcd-cpp-apiv3
sed -i '/^find_dependency(cpprestsdk)$/d' etcd-cpp-api-config.in.cmake 2>/dev/null || true
mkdir -p build && cd build
cmake .. \
  -DBUILD_ETCD_CORE_ONLY=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc) && make install
ldconfig
echo "  ✓ etcd-cpp-api installed"

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
