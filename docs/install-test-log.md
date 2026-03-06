# NIXL 설치 / 테스트 / 제거 실행 로그

**최종 갱신:** 2026-03-06
**환경:** Ubuntu 24.04 LTS (WSL2, x86_64), Python 3.12, GCC 13.3

---

## 공통 사전 조건

NIXL 빌드/설치에 필요한 시스템 패키지:

| 패키지 | 버전 |
|---|---|
| libucx-dev / libucx0 | 1.16.0 |
| libgrpc-dev / libgrpc++-dev | 1.51.1 |
| libprotobuf-dev | 3.21.12 |
| libcpprest-dev | 2.10.19 |
| etcd-server / etcd-client | 3.4.30 |
| pybind11-dev | 2.11.1 |
| libaio-dev / liburing-dev | 시스템 기본 |
| libibverbs-dev / librdmacm-dev | 시스템 기본 |
| devscripts / debhelper | 2.23.7 / 13.14.1 |

`etcd-cpp-api`는 apt에 없으므로 별도 빌드 필요. 방법은 아래 각 설치 방법에서 설명.

---

## 방법 A: 소스 빌드 (로컬 설치)

### 0단계: etcd-cpp-apiv3 빌드 및 설치

```bash
cd ~/nixl_playbook/etcd-src
mkdir -p build && cd build
cmake .. \
    -DBUILD_ETCD_CORE_ONLY=ON \
    -DBUILD_ETCD_TESTS=OFF \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)
sudo make install
sudo ldconfig
```

### 1단계: NIXL 빌드 & 설치

```bash
cd ~/nixl

# 의존성 설치 (최초 1회)
sudo bash install-deps.sh

# 빌드 & 설치 (sudo 불필요, ./install/ 로컬 설치)
bash build.sh

# 환경 변수
source env.sh
```

**설치 경로:**
```
install/nixl/
├── bin/          nixl_example, nixl_etcd_example, telemetry_reader
├── include/      nixl.h, nixl_types.h ...
└── lib/x86_64-linux-gnu/
    ├── libnixl.so 외
    └── plugins/  libplugin_UCX.so, libplugin_POSIX.so, libtelemetry_exporter_prometheus.so

install/nixlbench/
└── bin/nixlbench
```

### 알려진 이슈

- `build/` 디렉터리가 root 소유인 경우 (debian 패키징 이력): `sudo chown -R $USER:$USER build/`
- Python 패키지명 `nixl-cu12` vs 예제 `import nixl`: shim 생성 필요 (아래 공통 이슈 참고)

### 테스트 환경 변수

```bash
export NIXL_INSTALL=./install/nixl
export LD_LIBRARY_PATH="$NIXL_INSTALL/lib/x86_64-linux-gnu:$NIXL_INSTALL/lib/x86_64-linux-gnu/plugins"
export NIXL_PLUGIN_DIR="$NIXL_INSTALL/lib/x86_64-linux-gnu/plugins"
source .venv/bin/activate
```

### 제거

```bash
rm -rf install/ build/ benchmark/nixlbench/build/
source .venv/bin/activate && pip uninstall nixl-cu12 -y

# etcd-cpp-apiv3 제거 (소스 설치한 경우)
sudo rm -f /usr/local/lib/libetcd-cpp-api*.so*
sudo rm -rf /usr/local/include/etcd /usr/local/lib/cmake/etcd-cpp-api
sudo ldconfig
```

---

## 방법 B: Debian 패키지 방식 (`.deb`)

etcd-cpp-apiv3와 NIXL을 각각 별도 .deb로 관리한다. 빌드 순서 중요.

### 1단계: etcd-cpp-apiv3 .deb 빌드 및 설치

```bash
cd ~/nixl_playbook/etcd-src

# 이전 빌드 아티팩트 정리
rm -rf debian/tmp debian/libetcd-cpp-apiv3-dev

# .deb 빌드
dpkg-buildpackage -us -uc -b

# 설치
sudo dpkg -i ~/libetcd-cpp-apiv3-dev_0.15.4-1_amd64.deb
```

**설치 경로:**

| 파일 | 경로 |
|---|---|
| `libetcd-cpp-api-core.so` | `/usr/lib/x86_64-linux-gnu/` |
| 헤더 (`etcd/*.hpp`) | `/usr/include/etcd/` |
| cmake config | `/usr/lib/x86_64-linux-gnu/cmake/etcd-cpp-api/` |

### 2단계: NIXL .deb 빌드

```bash
cd ~/nixl

# 이전 빌드 아티팩트 정리
sudo chown -R $USER:$USER obj-nixl obj-nixlbench debian 2>/dev/null || true
rm -rf obj-nixl obj-nixlbench debian/tmp debian/libnixl debian/nixlbench debian/nixl-staging

# .deb 빌드 (서명 없이)
dpkg-buildpackage -us -uc -b
```

**생성된 패키지** (`~/` 디렉터리):
```
libnixl_0.9.0-1_amd64.deb      # 라이브러리 + Python 바인딩 + 헤더
nixlbench_0.9.0-1_amd64.deb    # 벤치마크 바이너리
```

### 3단계: NIXL 설치

```bash
sudo dpkg -i ~/libnixl_0.9.0-1_amd64.deb ~/nixlbench_0.9.0-1_amd64.deb
```

**설치 경로:**

| 파일 | 경로 |
|---|---|
| `libnixl.so` 외 `.so` | `/usr/lib/` |
| `libplugin_UCX.so`, `libplugin_POSIX.so` | `/usr/lib/plugins/` |
| `libtelemetry_exporter_prometheus.so` | `/usr/lib/plugins/` |
| Python 패키지 `nixl_cu12` | `/usr/lib/python3/dist-packages/nixl_cu12/` |
| `nixlbench` 바이너리 | `/usr/bin/nixlbench` |
| 헤더 | `/usr/include/` |

### 4단계: 사전 설정 (Python shim)

예제 코드가 `import nixl`을 사용하지만 패키지명이 `nixl-cu12`이므로 shim 필요:

```bash
sudo mkdir -p /usr/lib/python3/dist-packages/nixl

sudo tee /usr/lib/python3/dist-packages/nixl/__init__.py << 'EOF'
import sys, nixl_cu12, nixl_cu12._api, nixl_cu12._bindings
sys.modules['nixl._api'] = nixl_cu12._api
sys.modules['nixl._bindings'] = nixl_cu12._bindings
from nixl_cu12 import *
EOF

sudo tee /usr/lib/python3/dist-packages/nixl/_api.py << 'EOF'
from nixl_cu12._api import *
from nixl_cu12._api import nixl_agent, nixl_agent_config
EOF

sudo tee /usr/lib/python3/dist-packages/nixl/logging.py << 'EOF'
from nixl_cu12.logging import *
from nixl_cu12.logging import get_logger
EOF
```

**환경 변수:**

```bash
export LD_LIBRARY_PATH="/usr/lib/plugins:/usr/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH"
export PYTHONPATH="/usr/lib/python3/dist-packages:$PYTHONPATH"
export NIXL_PLUGIN_DIR="/usr/lib/plugins"
```

### 5단계: 테스트 (로컬 2벌 통신)

**예제:** `examples/python/basic_two_peers.py`
**방식:** 같은 머신에서 프로세스 2개를 `127.0.0.1:5555`로 연결

```bash
# 터미널 1 - Target (먼저 실행)
python3 examples/python/basic_two_peers.py --mode target --ip 127.0.0.1 --port 5555

# 터미널 2 - Initiator
python3 examples/python/basic_two_peers.py --mode initiator --ip 127.0.0.1 --port 5555
```

**단일 터미널:**
```bash
python3 examples/python/basic_two_peers.py --mode target --ip 127.0.0.1 --port 5555 &
sleep 3
python3 examples/python/basic_two_peers.py --mode initiator --ip 127.0.0.1 --port 5555
```

**동작 흐름:**
```
Target                                    Initiator
------                                    ---------
nixlAgent("target") 생성                  nixlAgent("initiator") 생성
UCX + POSIX + Prometheus 플러그인 로드    UCX + POSIX + Prometheus 플러그인 로드
tensor = ones(10,16) 생성 및 등록         tensor = zeros(10,16) 생성 및 등록
initiator 메타데이터 대기                 target 메타데이터 fetch (127.0.0.1:5555)
target descs 전송                         target descs 수신
"Waiting for transfer" 대기              UCX READ 전송 실행
"Done_reading" 수신 → 완료              tensor == ones(10,16) 검증 통과
Test Complete.                            Test Complete.
```

**실행 결과: PASS ✓** (2026-03-06)

```
# Target 로그
Discovered and loaded backend plugin: POSIX
Discovered and loaded backend plugin: UCX
Discovered and loaded telemetry plugin: prometheus
Initialized NIXL agent: target
Running test with tensor shape (10, 16) in mode target
Waiting for transfer
Test Complete.

# Initiator 로그
Initialized NIXL agent: initiator
Initiator sending to 127.0.0.1
Ready for transfer
Selected backend: UCX
initiator Data verification passed
Test Complete.
```

### 6단계: 제거

```bash
# 1. nixl 패키지 제거 (nixlbench이 libnixl 의존이므로 순서 중요)
sudo dpkg -r nixlbench libnixl

# 2. etcd-cpp-apiv3 제거
sudo dpkg -r libetcd-cpp-apiv3-dev

# 3. nixl Python shim 제거
sudo rm -rf /usr/lib/python3/dist-packages/nixl

sudo ldconfig
```

**제거 검증:**

| 항목 | 결과 |
|---|---|
| `dpkg -l libnixl nixlbench` | ✓ 제거됨 |
| `/usr/lib/libnixl.so` | ✓ 없음 |
| `/usr/lib/plugins/` | ✓ 없음 |
| `/usr/bin/nixlbench` | ✓ 없음 |
| `/usr/lib/python3/dist-packages/nixl_cu12/` | ✓ 없음 |
| `/usr/lib/python3/dist-packages/nixl/` | ✓ 없음 |
| `libetcd-cpp-api-core.so` | ✓ 없음 |

---

## 공통 알려진 이슈

| 이슈 | 원인 | 해결 |
|---|---|---|
| `import nixl` 실패 | 패키지명 `nixl-cu12` vs 예제 코드 `from nixl._api` | shim 패키지 수동 생성 (위 참고) |
| UCX WARN 버전 불일치 | 시스템 UCX 1.16.0 < 권장 1.21 | 동작은 정상. 최신 UCX 설치 시 해결 |
| `build/` 삭제 권한 없음 | debian 패키징 시 root로 생성됨 | `sudo chown -R $USER:$USER build/` |
| CUDA 없음 | WSL 환경 | GPU 텐서 전송 불가, CPU 전송만 지원 |

---

## etcd 서버 실행 (메타데이터 교환용)

NIXL의 multi-node 메타데이터 교환 기능을 사용하려면 etcd 서버 필요:

```bash
docker run -d -p 2379:2379 quay.io/coreos/etcd:v3.5.0 \
  etcd --listen-client-urls http://0.0.0.0:2379 \
       --advertise-client-urls http://localhost:2379
```

- NIXL: `NIXL_ETCD_ENDPOINTS` 환경변수 설정 시 etcd 모드 활성화
- nixlbench: `ETCD_ENDPOINTS` 환경변수, 기본값 `http://localhost:2379`
