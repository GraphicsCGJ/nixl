#!/bin/bash
# NIXL Host Installation - System Dependencies Setup
# This script must be run with sudo privileges

set -e

echo "=== NIXL Host Installation - System Dependencies ==="
echo "This script will install system dependencies required for building NIXL"
echo ""

# Update package lists
echo "[1/4] Updating package lists..."
apt-get update

# Install core build tools and dependencies
echo "[2/4] Installing build tools and development libraries..."
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
echo "[3/4] Installing RDMA/InfiniBand libraries..."
apt-get install -y \
  autoconf libnuma-dev librdmacm-dev ibverbs-providers \
  libibverbs-dev rdma-core ibverbs-utils libibumad-dev

# Install Python package manager (uv) - optional
echo "[4/4] uv (Python package manager) installation..."
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
