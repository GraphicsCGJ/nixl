# NIXL Host Installation Guide

이 가이드는 Docker를 사용하지 않고 **Linux 호스트에 직접 NIXL과 NIXLBench를 설치하고 실행**하는 방법을 설명합니다.

## 목차

1. [시스템 요구사항](#시스템-요구사항)
2. [빠른 시작](#빠른-시작)
3. [상세 설치 과정](#상세-설치-과정)
4. [ETCD 설정](#etcd-설정)
5. [기본 벤치마크 실행](#기본-벤치마크-실행)
6. [트러블슈팅](#트러블슈팅)

## 시스템 요구사항

### 하드웨어
- **CPU**: x86_64 또는 aarch64 아키텍처
- **RAM**: 최소 8GB (컴파일 시 16GB+ 권장)
- **저장공간**: 최소 20GB 여유 공간
- **GPU**: NVIDIA GPU (선택사항, GPU 기능 사용 시 필수)

### 운영체제
- **OS**: Ubuntu 22.04/24.04 LTS (권장) 또는 RHEL 기반
- **Python**: 3.12+ (벤치마크 유틸리티용)

### 필수 소프트웨어
- Git
- CMake (≥3.20)
- Meson (빌드 시스템)
- Ninja (빌드 백엔드)
- GCC/Clang

## 빠른 시작

### Step 1: 시스템 의존성 설치 (sudo 필요)

```bash
cd /home/gj/nixl
sudo ./install-deps.sh
```

이 스크립트는 다음을 설치합니다:
- Build tools (build-essential, cmake, ninja, pkg-config)
- 개발 라이브러리 (gflags, grpc, protobuf 등)
- RDMA/InfiniBand 라이브러리
- Python 개발 패키지
- ETCD 서버 및 클라이언트

### Step 2: 수동 의존성 설치 (필요한 경우)

#### CUDA Toolkit (GPU 지원 필요 시)

```bash
wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_550.54.15_linux.run
sudo sh cuda_12.8.0_550.54.15_linux.run

# CUDA 경로 설정
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

#### UCX (통신 라이브러리)

```bash
# 옵션 1: 시스템 패키지 사용 (권장)
sudo apt-get install -y libucx-dev

# 옵션 2: 소스에서 빌드
git clone https://github.com/openucx/ucx.git
cd ucx
./autogen.sh
./contrib/configure-release --with-cuda=/usr/local/cuda --enable-mt
make -j$(nproc) && sudo make install
```

#### etcd-cpp-api (메타데이터 교환용, 필수)

```bash
git clone --depth 1 https://github.com/etcd-cpp-apiv3/etcd-cpp-apiv3.git
cd etcd-cpp-apiv3

# CMake 설정에서 cpprestsdk 의존성 제거 (apt로 이미 설치됨)
sed -i '/^find_dependency(cpprestsdk)$/d' etcd-cpp-api-config.in.cmake

# 빌드 및 설치
mkdir build && cd build
cmake .. \
  -DBUILD_ETCD_CORE_ONLY=ON \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc) && sudo make install
sudo ldconfig
```

### Step 3: NIXL과 NIXLBench 빌드 및 설치

```bash
cd /home/gj/nixl
./build.sh
```

이 스크립트는:
1. Python virtual environment 생성
2. NIXL 라이브러리 빌드 및 설치 (자동)
3. NIXLBench 도구 빌드 및 설치 (자동)

**설치 위치:**
- NIXL:       `~/.local/nixl`
- NIXLBench:  `~/.local/nixlbench`

### Step 4: 환경 변수 설정

```bash
# ~/.bashrc 또는 ~/.zshrc에 추가
export PATH=$HOME/.local/nixlbench/bin:$HOME/.local/nixl/bin:$PATH
export LD_LIBRARY_PATH=$HOME/.local/nixlbench/lib:$HOME/.local/nixl/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH

# 설정 적용
source ~/.bashrc
```

## 상세 설치 과정

### 설치 디렉토리 구조

```
/home/gj/nixl/
├── install-deps.sh          # 시스템 의존성 설치 (sudo 필요)
├── build.sh                 # NIXL/NIXLBench 빌드 (일반 사용자)
├── build/                   # NIXL 빌드 아티팩트
├── benchmark/
│   └── nixlbench/
│       ├── build/           # NIXLBench 빌드 아티팩트
│       └── README.md        # NIXLBench 상세 문서
└── [기타 NIXL 소스 파일]
```

### 설치 위치

기본 설치 위치 (sudo 불필요):
- **NIXL**: `~/.local/nixl/`
- **NIXLBench**: `~/.local/nixlbench/`

커스텀 위치로 설치하려면:

```bash
NIXL_INSTALL_PREFIX=/path/to/nixl \
NIXLBENCH_INSTALL_PREFIX=/path/to/nixlbench \
BUILD_TYPE=release \
./build.sh
```

예시 (시스템 전체에 설치, sudo 필요):
```bash
NIXL_INSTALL_PREFIX=/usr/local/nixl \
NIXLBENCH_INSTALL_PREFIX=/usr/local/nixlbench \
./build.sh
```

## ETCD 설정

### ETCD 서버 시작

NIXL 벤치마크는 워커 조정을 위해 ETCD를 사용합니다:

#### 옵션 1: Docker 사용 (권장)

```bash
docker run -d --name etcd-server \
  -p 2379:2379 -p 2380:2380 \
  quay.io/coreos/etcd:v3.5.18 \
  /usr/local/bin/etcd \
  --data-dir=/etcd-data \
  --listen-client-urls=http://0.0.0.0:2379 \
  --advertise-client-urls=http://0.0.0.0:2379 \
  --listen-peer-urls=http://0.0.0.0:2380 \
  --initial-advertise-peer-urls=http://0.0.0.0:2380 \
  --initial-cluster=default=http://0.0.0.0:2380
```

#### 옵션 2: 네이티브 설치

```bash
# 이미 install-deps.sh로 설치됨
sudo systemctl start etcd
sudo systemctl enable etcd

# 상태 확인
sudo systemctl status etcd
```

### ETCD 연결 확인

```bash
# ETCD 상태 확인
etcdctl endpoint health

# 버전 확인
etcdctl version
```

## 기본 벤치마크 실행

### 1. CPU 메모리 벤치마크 (가장 간단)

ETCD 없이 DRAM을 사용한 기본 벤치마크:

```bash
# ETCD 서버 시작 (별도 터미널에서)
docker run -d --name etcd-server -p 2379:2379 quay.io/coreos/etcd:v3.5.18

# 벤치마크 실행
sleep 2 && nixlbench --etcd_endpoints http://localhost:2379 --backend POSIX --filepath /tmp/test_file
```

### 2. GPU 메모리 벤치마크 (VRAM)

GPU가 있는 경우:

```bash
# 먼저 ETCD 시작
docker run -d --name etcd-server -p 2379:2379 quay.io/coreos/etcd:v3.5.18

# VRAM 전송 벤치마크
sleep 2 && nixlbench \
  --etcd_endpoints http://localhost:2379 \
  --backend UCX \
  --initiator_seg_type VRAM \
  --target_seg_type VRAM
```

### 3. 네트워크 벤치마크 (UCX)

```bash
# 다중 인스턴스 실행 (2개의 터미널에서)

# 터미널 1 (초기화)
nixlbench \
  --etcd_endpoints http://etcd-server:2379 \
  --backend UCX \
  --initiator_seg_type VRAM \
  --target_seg_type VRAM

# 터미널 2 (60초 이내에 실행)
sleep 2 && nixlbench \
  --etcd_endpoints http://etcd-server:2379 \
  --backend UCX \
  --initiator_seg_type VRAM \
  --target_seg_type VRAM
```

## 명령행 옵션

### 핵심 옵션

```bash
--etcd_endpoints URL              # ETCD 서버 주소 (기본값: http://localhost:2379)
--backend NAME                    # 통신 백엔드: UCX, GDS, POSIX, OBJ, GUSLI (기본값: UCX)
--worker_type NAME                # 워커 타입: nixl, nvshmem (기본값: nixl)
--benchmark_group NAME            # 벤치마크 그룹 이름
```

### 메모리 및 전송 설정

```bash
--initiator_seg_type TYPE         # Initiator 메모리: DRAM, VRAM (기본값: DRAM)
--target_seg_type TYPE            # Target 메모리: DRAM, VRAM (기본값: DRAM)
--total_buffer_size SIZE          # 버퍼 크기 (기본값: 8GiB)
--start_block_size SIZE            # 시작 블록 크기 (기본값: 4KiB)
--max_block_size SIZE              # 최대 블록 크기 (기본값: 64MiB)
--num_iter NUM                     # 반복 횟수 (기본값: 1000)
--num_threads NUM                  # 스레드 수 (기본값: 1)
```

### 저장소 백엔드 옵션

```bash
--filepath PATH                   # 저장소 파일 경로
--storage_enable_direct           # Direct I/O 활성화
```

자세한 옵션은 `benchmark/nixlbench/README.md` 참조

## 벤치마크 예제

### 기본 POSIX 저장소 벤치마크

```bash
nixlbench \
  --backend POSIX \
  --filepath /tmp/benchmark_test \
  --num_iter 100 \
  --warmup_iter 10
```

### 멀티스레드 네트워크 벤치마크

```bash
nixlbench \
  --etcd_endpoints http://localhost:2379 \
  --backend UCX \
  --num_threads 4 \
  --enable_pt \
  --progress_threads 2 \
  --warmup_iter 50 \
  --num_iter 500
```

### GDS (GPU Direct Storage) 벤치마크

```bash
nixlbench \
  --backend GDS \
  --filepath /mnt/nvme/test_file \
  --gds_batch_pool_size 64 \
  --gds_batch_limit 256
```

## 성능 최적화

### CPU Affinity 설정

```bash
taskset -c 0-7 nixlbench --backend UCX ...
```

### NUMA 시스템

```bash
numactl --cpunodebind=0 --membind=0 nixlbench --backend UCX ...
```

### 네트워크 튜닝

```bash
echo 'net.core.rmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
echo 'net.core.wmem_max = 134217728' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
```

## 트러블슈팅

### CUDA를 찾을 수 없음

```bash
# CUDA 경로 설정
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH

# 설치 확인
nvcc --version
```

### 라이브러리를 찾을 수 없음

```bash
# 라이브러리 캐시 업데이트
sudo ldconfig

# 동적 링크 정보 확인
ldd /usr/local/nixlbench/bin/nixlbench
```

### GPU 접근 오류

```bash
# GPU 확인
nvidia-smi

# CUDA 드라이버 확인
cat /proc/driver/nvidia/version

# GPU/NIC 토폴로지 확인
nvidia-smi topo -m
```

### UCX 네트워크 문제

```bash
# 사용 가능한 디바이스 확인
ibv_devices        # RDMA 디바이스
ibv_devinfo -v     # 상세 정보
ucx_info -d        # UCX 디바이스

# UCX 디버그 로깅
export UCX_LOG_LEVEL=DEBUG
```

### ETCD 정리 (벤치마크 실패 후)

```bash
# 이전 벤치마크 데이터 삭제
ETCDCTL_API=3 etcdctl del "xferbench" --prefix=true
```

### 빌드 오류

#### Meson 설정 오류

```bash
# 빌드 디렉토리 재초기화
cd /home/gj/nixl
rm -rf build
./build.sh
```

#### Python 의존성 오류

```bash
# Virtual environment 재생성
rm -rf .venv
./build.sh
```

## 설치 검증

### 설치 확인

```bash
# 설치된 바이너리 확인
ls -la ~/.local/nixlbench/bin/
ls -la ~/.local/nixl/bin/

# 라이브러리 확인
ls -la ~/.local/nixl/lib/x86_64-linux-gnu/

# PATH에 추가되었는지 확인
which nixlbench
```

### 간단한 테스트 실행

```bash
# ETCD 서버 시작
docker run -d --name etcd-server -p 2379:2379 quay.io/coreos/etcd:v3.5.18

# 기본 벤치마크 실행 (20초 정도)
sleep 2 && timeout 30 nixlbench \
  --etcd_endpoints http://localhost:2379 \
  --backend POSIX \
  --filepath /tmp/nixl_test \
  --num_iter 10 \
  --warmup_iter 2
```

## 추가 리소스

- **NIXL 소스**: https://github.com/ai-dynamo/nixl
- **NIXLBench 상세 가이드**: `benchmark/nixlbench/README.md`
- **UCX 문서**: https://openucx.readthedocs.io/
- **ETCD 문서**: https://etcd.io/docs/

## 지원

문제 발생 시:
1. `build/meson-logs/` 디렉토리의 로그 확인
2. 위 트러블슈팅 섹션 참조
3. GitHub Issues: https://github.com/ai-dynamo/nixl/issues

---

**작성일**: 2025년 3월
**NIXL 버전**: 최신 (main branch)
**테스트 환경**: Ubuntu 24.04 LTS
