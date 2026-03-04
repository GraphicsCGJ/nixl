#!/bin/bash

# SPDX-License-Identifier: Apache-2.0
# NIXLBench Run Script - Execute benchmarks locally with ETCD coordination
# Supports single and multi-instance benchmarking with automatic environment setup

set -e

# Resolve script location
NIXL_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load env.sh if available; otherwise fall back to install/ defaults
if [ -f "$NIXL_SOURCE_DIR/env.sh" ]; then
    source "$NIXL_SOURCE_DIR/env.sh"
fi

# Configuration
NIXL_INSTALL_PREFIX="${NIXL_INSTALL_PREFIX:-$NIXL_SOURCE_DIR/install/nixl}"
NIXLBENCH_INSTALL_PREFIX="${NIXLBENCH_INSTALL_PREFIX:-$NIXL_SOURCE_DIR/install/nixlbench}"
ETCD_PORT="${ETCD_PORT:-2379}"
ETCD_PEER_PORT="${ETCD_PEER_PORT:-2380}"
BENCHMARK_GROUP="${BENCHMARK_GROUP:-default}"
TIMEOUT="${TIMEOUT:-120}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[✗]${NC} $*"
}

# Check if nixlbench is installed
check_installation() {
    if [ ! -f "$NIXLBENCH_INSTALL_PREFIX/bin/nixlbench" ]; then
        log_error "NIXLBench not found at $NIXLBENCH_INSTALL_PREFIX/bin/nixlbench"
        log_info "Please run: ./build.sh"
        exit 1
    fi
    log_success "NIXLBench found"
}

# Setup environment variables (env.sh already sourced at top; this handles the case it was absent)
setup_env() {
    if [ -f "$NIXL_SOURCE_DIR/env.sh" ]; then
        log_success "Environment loaded from env.sh"
    else
        log_warn "env.sh not found — run ./build.sh first to generate it"
    fi
}

# Get next available TCP port
get_next_port() {
    local port=$1
    while netstat -tuln 2>/dev/null | grep -q ":$port "; do
        ((port++))
    done
    echo $port
}

# Start ETCD server
start_etcd() {
    log_info "Starting ETCD server..."

    ETCD_PORT=$(get_next_port $ETCD_PORT)
    ETCD_PEER_PORT=$(get_next_port $ETCD_PEER_PORT)

    log_info "ETCD ports: client=$ETCD_PORT, peer=$ETCD_PEER_PORT"

    # Try docker first
    if command -v docker &> /dev/null && docker ps &> /dev/null; then
        log_info "Using Docker for ETCD..."
        docker run -d --name "etcd-${ETCD_PORT}" \
            -p "${ETCD_PORT}:2379" \
            -p "${ETCD_PEER_PORT}:2380" \
            quay.io/coreos/etcd:v3.5.18 \
            /usr/local/bin/etcd \
            --data-dir=/etcd-data \
            --listen-client-urls=http://0.0.0.0:2379 \
            --advertise-client-urls=http://127.0.0.1:2379 \
            --listen-peer-urls=http://0.0.0.0:2380 \
            --initial-advertise-peer-urls=http://127.0.0.1:2380 \
            --initial-cluster=default=http://127.0.0.1:2380 2>/dev/null || true
        ETCD_PID=""
    # Try native etcd
    elif command -v etcd &> /dev/null; then
        log_info "Using native ETCD..."
        etcd --data-dir=/tmp/etcd-data-${ETCD_PORT} \
            --listen-client-urls="http://127.0.0.1:${ETCD_PORT}" \
            --advertise-client-urls="http://127.0.0.1:${ETCD_PORT}" \
            --listen-peer-urls="http://127.0.0.1:${ETCD_PEER_PORT}" \
            --initial-advertise-peer-urls="http://127.0.0.1:${ETCD_PEER_PORT}" \
            --initial-cluster="default=http://127.0.0.1:${ETCD_PEER_PORT}" \
            --log-level=warn > /tmp/etcd-${ETCD_PORT}.log 2>&1 &
        ETCD_PID=$!
    else
        log_error "ETCD not found. Please install Docker or native ETCD."
        exit 1
    fi

    # Wait for ETCD to be ready
    log_info "Waiting for ETCD to be ready..."
    for i in {1..30}; do
        if curl -s "http://127.0.0.1:${ETCD_PORT}/version" > /dev/null 2>&1; then
            log_success "ETCD is ready at http://127.0.0.1:${ETCD_PORT}"
            export NIXL_ETCD_ENDPOINTS="http://127.0.0.1:${ETCD_PORT}"
            return 0
        fi
        sleep 1
    done

    log_error "ETCD failed to start"
    exit 1
}

# Stop ETCD server
stop_etcd() {
    if [ -n "${ETCD_PID}" ]; then
        log_info "Stopping ETCD (PID: $ETCD_PID)..."
        kill -9 "$ETCD_PID" 2>/dev/null || true
    else
        log_info "Stopping ETCD containers..."
        docker rm -f "etcd-${ETCD_PORT}" 2>/dev/null || true
    fi
}

# Run nixlbench
run_benchmark() {
    local backend="${1:-POSIX}"
    shift
    local extra_args="$@"

    log_info "Starting NIXLBench (backend: $backend)"

    # Default parameters for stable local testing
    local default_params=(
        "--filepath" "/tmp/nixlbench-test-$$.dat"
        "--total_buffer_size" "100000000"  # 100MB
        "--start_block_size" "65536"       # 64KB
        "--max_block_size" "65536"
        "--start_batch_size" "4"
        "--max_batch_size" "4"
        "--num_iter" "100"
        "--warmup_iter" "10"
    )

    # Run based on backend
    case "$backend" in
        POSIX|GDS|GDS_MT|GUSLI)
            # Storage backends (no ETCD required for single instance)
            log_info "Running storage backend benchmark..."
            "$NIXLBENCH_INSTALL_PREFIX/bin/nixlbench" \
                "--backend" "$backend" \
                "${default_params[@]}" \
                $extra_args
            ;;
        UCX|GPUNETIO|Mooncake|LIBFABRIC)
            # Network backends (ETCD required)
            if [ -z "$NIXL_ETCD_ENDPOINTS" ]; then
                start_etcd
            fi

            log_info "Running network backend benchmark (waiting for second instance)..."
            log_warn "To test with two workers, run this in another terminal:"
            log_warn "  sleep 3 && $0 $backend"

            "$NIXLBENCH_INSTALL_PREFIX/bin/nixlbench" \
                "--etcd_endpoints" "$NIXL_ETCD_ENDPOINTS" \
                "--backend" "$backend" \
                "--benchmark_group" "$BENCHMARK_GROUP" \
                "${default_params[@]}" \
                "--initiator_seg_type" "DRAM" \
                "--target_seg_type" "DRAM" \
                "--check_consistency" \
                $extra_args
            ;;
        *)
            log_error "Unknown backend: $backend"
            exit 1
            ;;
    esac

    log_success "Benchmark completed"
}

# Show usage
show_usage() {
    cat << 'EOF'
Usage: ./run_nixlbench.sh [BACKEND] [OPTIONS]

BACKENDS:
  POSIX       - POSIX file I/O (default)
  GDS         - GPU Direct Storage (requires GPU)
  GDS_MT      - Multi-threaded GDS
  GUSLI       - G3+ User Space Storage Library
  UCX         - Network communication (requires ETCD)
  GPUNETIO    - GPU networking (requires GPU + DOCA)
  Mooncake    - Mooncake backend
  LIBFABRIC   - Libfabric backend

COMMON OPTIONS:
  --help, -h           Show this help message
  --verbose, -v        Verbose output
  --check-consistency  Enable data consistency checking
  --num-iter N         Number of iterations (default: 100)
  --block-size N       Block size in bytes (default: 65536)
  --buffer-size N      Total buffer size (default: 100MB)
  --no-etcd            Skip ETCD startup (use if already running)

EXAMPLES:
  # Basic POSIX storage benchmark
  ./run_nixlbench.sh POSIX

  # GDS benchmark with custom parameters
  ./run_nixlbench.sh GDS --num_iter 1000 --max_block_size 1048576

  # UCX network benchmark (requires two instances)
  ./run_nixlbench.sh UCX
  # In another terminal:
  sleep 3 && ./run_nixlbench.sh UCX

  # Check consistency
  ./run_nixlbench.sh POSIX --check_consistency

For more options, see option_report.md
EOF
}

# Cleanup on exit
cleanup() {
    log_info "Cleaning up..."
    stop_etcd
}

trap cleanup EXIT

# Main
main() {
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        show_usage
        exit 0
    fi

    check_installation
    setup_env

    local backend="${1:-POSIX}"
    shift || true

    # Check for no-etcd flag
    if [[ "$@" == *"--no-etcd"* ]]; then
        log_warn "ETCD startup skipped"
    fi

    run_benchmark "$backend" "$@"
}

main "$@"
