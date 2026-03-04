# NIXLBench Command Line Options Report

A comprehensive guide to all NIXLBench command line options, organized by category.

**Table of Contents:**
1. [Core Configuration](#1-core-configuration)
2. [Memory and Transfer Configuration](#2-memory-and-transfer-configuration)
3. [Performance and Threading](#3-performance-and-threading)
4. [Device and Network Configuration](#4-device-and-network-configuration)
5. [Storage Backend Options](#5-storage-backend-options)
6. [Backend-Specific Options](#6-backend-specific-options)
7. [Configuration File](#7-configuration-file)

---

## 1. Core Configuration

These options configure the fundamental behavior of NIXLBench.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--config_file` | `PATH` | NONE | TOML configuration file path. Command-line arguments override config file values. |
| `--runtime_type` | `NAME` | ETCD | Type of runtime for coordination. Currently only `ETCD` is supported. |
| `--worker_type` | `NAME` | nixl | Worker implementation to use: `nixl` (full-featured, all backends) or `nvshmem` (GPU-only). |
| `--backend` | `NAME` | UCX | Communication/storage backend to use. Options: `UCX`, `GDS`, `GDS_MT`, `POSIX`, `GPUNETIO`, `Mooncake`, `HF3FS`, `OBJ`, `GUSLI`, `LIBFABRIC` |
| `--benchmark_group` | `NAME` | default | Unique identifier for parallel benchmark runs. Enables coordination between multiple NIXLBench instances. |
| `--etcd_endpoints` | `URL` | http://localhost:2379 | ETCD server URL for worker coordination. Required for network backends and multi-instance storage benchmarks. |

**Usage Tips:**
- Use `--config_file` for complex multi-parameter benchmarks
- Set unique `--benchmark_group` for each parallel benchmark run
- Network backends **require** ETCD or explicit `--etcd_endpoints`

---

## 2. Memory and Transfer Configuration

These options control memory types, transfer operations, and data patterns.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--initiator_seg_type` | `TYPE` | DRAM | Memory type for initiator (sender): `DRAM` (CPU memory) or `VRAM` (GPU memory). Requires GPU hardware for VRAM. |
| `--target_seg_type` | `TYPE` | DRAM | Memory type for target (receiver): `DRAM` or `VRAM`. |
| `--scheme` | `NAME` | pairwise | Communication pattern: <br> `pairwise` - Point-to-point between pairs <br> `manytoone` - Multiple senders to single receiver <br> `onetomany` - Single sender to multiple receivers <br> `tp` - Tensor parallel optimized for distributed training |
| `--mode` | `MODE` | SG | Process mode: `SG` (Single GPU per process) or `MG` (Multi GPU per process). |
| `--op_type` | `TYPE` | WRITE | Operation type: `READ` (target to initiator) or `WRITE` (initiator to target). |
| `--check_consistency` | `FLAG` | Disabled | Enable data consistency validation. Verifies data integrity after transfers. Enables stricter testing but reduces performance. |
| `--total_buffer_size` | `SIZE` | 8GiB | Total buffer size across all devices per process. Supports units: `K`, `M`, `G`, `T` (e.g., `512M`, `4G`). |
| `--start_block_size` | `SIZE` | 4KiB | Starting block size for transfers. Iterations increase block size up to `--max_block_size`. Supports size units. |
| `--max_block_size` | `SIZE` | 64MiB | Maximum block size for transfers. |
| `--start_batch_size` | `SIZE` | 1 | Starting batch size (number of concurrent transfers per iteration). |
| `--max_batch_size` | `SIZE` | 1 | Maximum batch size. |
| `--recreate_xfer` | `FLAG` | Disabled | Recreate transfer handles for every iteration. Simulates workloads with frequent handle creation/destruction. |

**Usage Tips:**
- Use `VRAM` transfers to test GPU-direct communication (requires GPU)
- Set `--check_consistency` for correctness validation, remove for performance testing
- Increase `--max_block_size` for throughput testing, smaller for latency
- Set `--start_batch_size` and `--max_batch_size` > 1 for concurrency testing

---

## 3. Performance and Threading

Options controlling performance characteristics and threading behavior.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--num_iter` | `NUM` | 1000 | Number of iterations per block size. Each iteration transfers data of the current block size. |
| `--warmup_iter` | `NUM` | 100 | Number of warmup iterations before measuring. Allows GPU warm-up and cache stabilization. |
| `--large_blk_iter_ftr` | `NUM` | 16 | Factor to reduce iterations for large block sizes (> 1MB). For 2MB block: 1000/16 = 62.5 iterations. |
| `--num_threads` | `NUM` | 1 | Number of threads used by the benchmark. Controls CPU parallelism. |
| `--num_initiator_dev` | `NUM` | 1 | Number of devices in initiator process. For multi-GPU initiators. |
| `--num_target_dev` | `NUM` | 1 | Number of devices in target process. For multi-GPU targets. |
| `--enable_pt` | `FLAG` | Disabled | Enable progress thread for async operations (NIXL worker only). Allows background progress polling. |
| `--progress_threads` | `NUM` | 0 | Number of dedicated progress threads. Only effective with `--enable_pt`. |
| `--enable_vmm` | `FLAG` | Disabled | Enable VMM (Virtual Memory Manager) allocation for DRAM transfers. Used for CUDA Fabric integration. |

**Usage Tips:**
- Increase `--num_threads` for multi-threaded throughput testing
- `--warmup_iter` should be 10-20% of `--num_iter` for stable measurements
- Use `--large_blk_iter_ftr` to reduce test time for large transfers
- `--progress_threads` > 0 reduces CPU overhead for async operations

---

## 4. Device and Network Configuration

Options for specifying devices and network settings.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--device_list` | `LIST` | all | Comma-separated device names to use. Format varies by backend: <br> UCX/Libfabric: `mlx5_0,mlx5_1` <br> GPUNETIO: CUDA device IDs like `0,1` <br> GUSLI: `id:type:path` format (see GUSLI section) |
| `--etcd_endpoints` | `URL` | http://localhost:2379 | ETCD server endpoint. See Core Configuration. |

**Usage Tips:**
- List specific devices to pin benchmarks to particular hardware
- Leave empty to use all available devices
- For multi-node setups, ensure all instances point to the same ETCD server

---

## 5. Storage Backend Options

Options shared by storage backends (GDS, GDS_MT, POSIX, HF3FS, OBJ, AZURE_BLOB).

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--filepath` | `PATH` | - | File path for storage operations. Can be a regular file or mounted filesystem. |
| `--num_files` | `NUM` | 1 | Number of files to use for the benchmark. Distributes load across multiple files. |
| `--storage_enable_direct` | `FLAG` | Disabled | Enable direct I/O mode for storage operations. Bypasses OS cache for accurate storage measurements. Required for some backends like GUSLI. |

**Usage Tips:**
- Use `/tmp/` for quick local testing
- Use mounted NFS/SMB for network storage testing
- Set `--num_files` > 1 to parallelize file access
- Enable `--storage_enable_direct` for SSD/NVMe accurate benchmarking

---

## 6. Backend-Specific Options

### 6.1 GDS Backend (GPU Direct Storage)

Options for NVIDIA GPUDirect Storage backend. Requires NVIDIA GDS driver.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--gds_batch_pool_size` | `NUM` | 32 | Size of batch operation pool. Larger pools reduce allocation overhead. |
| `--gds_batch_limit` | `NUM` | 128 | Maximum batch size limit for GDS operations. Controls memory usage. |

**Example:**
```bash
./nixlbench --backend GDS --filepath /mnt/nvme/testfile \
  --gds_batch_pool_size 64 --gds_batch_limit 256
```

---

### 6.2 GDS_MT Backend (Multi-threaded GDS)

Options for multi-threaded GPU Direct Storage.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--gds_mt_num_threads` | `NUM` | 1 | Number of threads for GDS_MT plugin. Higher values increase parallelism but use more resources. |

**Example:**
```bash
./nixlbench --backend GDS_MT --filepath /mnt/nvme/testfile --gds_mt_num_threads 8
```

---

### 6.3 POSIX Backend

Options for standard POSIX file I/O.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--posix_api_type` | `TYPE` | AIO | API type for POSIX operations: <br> `AIO` - POSIX asynchronous I/O (libaio) <br> `URING` - io_uring (Linux 5.1+) <br> `POSIXAIO` - POSIX AIO interface |
| `--posix_ios_pool_size` | `SIZE` | 65536 | I/O submission pool size. Larger pools support more concurrent operations. |
| `--posix_kernel_queue_size` | `SIZE` | 256 | Kernel queue size for AIO and URING. Controls max in-flight I/O operations. |

**Example:**
```bash
./nixlbench --backend POSIX --filepath /tmp/testfile \
  --posix_api_type URING --posix_kernel_queue_size 512 --storage_enable_direct
```

---

### 6.4 GPUNETIO Backend

Options for NVIDIA DOCA GPUNetIO networking.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--gpunetio_device_list` | `LIST` | - | Comma-separated GPU CUDA device IDs for GPUNETIO (e.g., `0,1`). |

**Example:**
```bash
./nixlbench --etcd_endpoints http://etcd-server:2379 \
  --backend GPUNETIO --gpunetio_device_list 0,1
```

---

### 6.5 OBJ (S3) Backend

Options for Amazon S3 and S3-compatible object storage.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--obj_access_key` | `STRING` | - | AWS S3 access key ID. Can use `AWS_ACCESS_KEY_ID` env var. |
| `--obj_secret_key` | `STRING` | - | AWS S3 secret access key. Can use `AWS_SECRET_ACCESS_KEY` env var. |
| `--obj_session_token` | `STRING` | - | Optional AWS STS session token for temporary credentials. |
| `--obj_bucket_name` | `NAME` | - | S3 bucket name (must exist). |
| `--obj_scheme` | `SCHEME` | http | URL scheme: `http` or `https`. Use `https` for production. |
| `--obj_region` | `REGION` | eu-central-1 | AWS region (e.g., `us-east-1`, `eu-west-1`). |
| `--obj_use_virtual_addressing` | `FLAG` | Disabled | Use virtual-hosted-style URLs (`bucket.s3.amazonaws.com`). Default: path-style. |
| `--obj_endpoint_override` | `URL` | - | Custom S3 endpoint for S3-compatible services (e.g., MinIO, DigitalOcean). |
| `--obj_req_checksum` | `TYPE` | supported | Checksum requirement: `supported` or `required`. |

**Example - AWS S3:**
```bash
export AWS_ACCESS_KEY_ID=your-key
export AWS_SECRET_ACCESS_KEY=your-secret
./nixlbench --backend OBJ \
  --obj_bucket_name my-bucket \
  --obj_region us-east-1 \
  --obj_access_key $AWS_ACCESS_KEY_ID \
  --obj_secret_key $AWS_SECRET_ACCESS_KEY
```

**Example - MinIO (S3-compatible):**
```bash
./nixlbench --backend OBJ \
  --obj_bucket_name testbucket \
  --obj_endpoint_override http://minio-server:9000 \
  --obj_access_key minioadmin \
  --obj_secret_key minioadmin
```

---

### 6.6 AZURE_BLOB Backend

Options for Microsoft Azure Blob Storage.

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--azure_blob_account_url` | `URL` | - | Azure Blob Storage account URL (e.g., `https://myaccount.blob.core.windows.net`). |
| `--azure_blob_container_name` | `NAME` | - | Container name in Azure Blob Storage (must exist). |
| `--azure_blob_connection_string` | `STRING` | - | Connection string for Azure Blob. Format: `DefaultEndpointsProtocol=https;...` |

**Example:**
```bash
./nixlbench --backend AZURE_BLOB \
  --azure_blob_account_url https://myaccount.blob.core.windows.net \
  --azure_blob_container_name mycontainer \
  --azure_blob_connection_string "DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...;"
```

---

### 6.7 GUSLI Backend (G3+ User Space Access)

GUSLI provides high-performance direct access to block storage (files, local disks, networked servers).

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `--device_list` | `LIST` | - | Device specifications in format `id:type:path` (comma-separated). <br> **Type codes:** <br> `F` = file (e.g., `11:F:./store.bin`) <br> `K` = kernel device (e.g., `27:K:/dev/nvme0n1`) <br> `N` = networked (TCP prefix `t` or UDP prefix `u`, e.g., `20:N:t192.168.1.100`) |
| `--gusli_client_name` | `NAME` | NIXLBench | Identifier for GUSLI client connections. |
| `--gusli_max_simultaneous_requests` | `NUM` | 32 | Maximum concurrent requests per device. Higher values increase concurrency. |
| `--gusli_device_security` | `LIST` | - | Comma-separated security flags per device (e.g., `sec=0x3,sec=0x71`). |
| `--gusli_device_byte_offsets` | `LIST` | 1048576 | Comma-separated byte LBA offsets per device. Default: 1MB (1048576 bytes). |
| `--gusli_config_file` | `STRING` | - | Custom GUSLI configuration content. Auto-generated if not provided. |

**Note:** Direct I/O is automatically enabled for GUSLI backend.

**Examples:**

Single file device:
```bash
./nixlbench --backend GUSLI \
  --device_list "11:F:./store0.bin" \
  --num_initiator_dev 1 --num_target_dev 1
```

Local NVMe device:
```bash
./nixlbench --backend GUSLI \
  --device_list "27:K:/dev/nvme0n1" \
  --gusli_device_security "sec=0x7" \
  --num_initiator_dev 1 --num_target_dev 1
```

Multiple devices:
```bash
./nixlbench --backend GUSLI \
  --device_list "11:F:./store0.bin,14:K:/dev/zero,27:K:/dev/nvme0n1" \
  --gusli_device_security "sec=0x3,sec=0x71,sec=0x7" \
  --num_initiator_dev 3 --num_target_dev 3
```

Networked GUSLI server (TCP):
```bash
./nixlbench --backend GUSLI \
  --device_list "20:N:t192.168.1.100" \
  --gusli_device_security "sec=0x10" \
  --num_initiator_dev 1 --num_target_dev 1
```

High concurrency:
```bash
./nixlbench --backend GUSLI \
  --device_list "27:K:/dev/nvme0n1" \
  --gusli_max_simultaneous_requests 128 \
  --num_threads 8 \
  --total_buffer_size 16G \
  --op_type WRITE
```

---

## 7. Configuration File

NIXLBench supports TOML configuration files for complex multi-parameter setups.

### File Format

```toml
# Global configuration - all command-line parameters can be used here
config_file = "/path/to/config.toml"
runtime_type = "ETCD"
worker_type = "nixl"
backend = "POSIX"
benchmark_group = "storage-test"
etcd_endpoints = "http://localhost:2379"

# Memory configuration
initiator_seg_type = "DRAM"
target_seg_type = "DRAM"
total_buffer_size = 1073741824  # 1GB

# Transfer configuration
start_block_size = 65536
max_block_size = 1048576
start_batch_size = 4
max_batch_size = 4

# Performance
num_iter = 1000
warmup_iter = 100
num_threads = 4

# Storage specific
filepath = "/tmp/nixlbench-test.dat"
storage_enable_direct = true

# POSIX specific
posix_api_type = "URING"
posix_kernel_queue_size = 512
```

### Usage

```bash
# Using config file
./nixlbench --config_file /path/to/nixlbench.config

# Command-line overrides config file
./nixlbench --config_file /path/to/nixlbench.config --backend GDS
```

### Precedence

Command-line arguments **always override** configuration file values.

---

## Quick Reference Examples

### Quick Throughput Benchmark
```bash
./nixlbench --backend POSIX --filepath /tmp/test.dat \
  --max_block_size 1048576 --num_iter 1000
```

### Latency Measurement
```bash
./nixlbench --backend POSIX --filepath /tmp/test.dat \
  --max_block_size 4096 --num_iter 10000 --warmup_iter 1000
```

### Multi-threaded Benchmark
```bash
./nixlbench --backend POSIX --filepath /tmp/test.dat \
  --num_threads 8 --max_batch_size 8 --num_iter 500
```

### Data Integrity Test
```bash
./nixlbench --backend POSIX --filepath /tmp/test.dat \
  --check_consistency --max_block_size 65536
```

### GPU Transfer Test
```bash
./nixlbench --backend UCX --etcd_endpoints http://localhost:2379 \
  --initiator_seg_type VRAM --target_seg_type VRAM \
  --check_consistency
```

### Network Benchmark (2 instances)
```bash
# Instance 1
./nixlbench --backend UCX --etcd_endpoints http://etcd-server:2379 \
  --benchmark_group test-run-1

# Instance 2 (in separate terminal)
sleep 3 && ./nixlbench --backend UCX --etcd_endpoints http://etcd-server:2379 \
  --benchmark_group test-run-1
```

---

## Notes

- **Unit Support:** Most size parameters support units: `K` (1024), `M` (1048576), `G` (1073741824)
- **GPU Requirements:** `VRAM` transfers and `GPUNETIO` require compatible NVIDIA GPU
- **ETCD Requirement:** Network backends and multi-instance storage benchmarks require ETCD coordination
- **Direct I/O:** Storage benchmarks should use `--storage_enable_direct` for accurate SSD/NVMe measurements
- **Consistency Checking:** Enables strict validation but reduces performance; use selectively
