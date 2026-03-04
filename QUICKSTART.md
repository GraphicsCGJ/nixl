# NIXL 호스트 설치 - 빠른 시작 가이드

Docker 대신 **호스트에 직접 설치**하는 방법입니다. 약 30-60분이 소요됩니다.

## 📋 준비 확인

현재 상태:
- ✅ NIXL 소스 코드 다운로드 완료
- ✅ `install-deps.sh` - 시스템 의존성 설치 스크립트
- ✅ `build.sh` - 빌드 스크립트
- ✅ `check_nixl_installed.sh` - 설치 확인 스크립트
- ✅ `run_nixlbench.sh` - 벤치마크 실행 스크립트
- ✅ `HOST_SETUP.md` - 상세 설명서

## 🚀 빠른 설치 (4단계)

### 1️⃣ 시스템 의존성 설치 (sudo 필요, 10-15분)

```bash
cd ~/nixl
sudo ./install-deps.sh
```

**설치되는 것:**
- CMake, Meson, Ninja
- GCC/G++ build tools
- gflags, grpc, protobuf 라이브러리
- RDMA/InfiniBand 라이브러리
- Python 개발 패키지
- ETCD 서버/클라이언트

### 2️⃣ CUDA 설치 (선택사항, GPU 필요 시, 10분)

GPU가 없으면 스킵해도 됩니다.

```bash
wget https://developer.download.nvidia.com/compute/cuda/12.8.0/local_installers/cuda_12.8.0_550.54.15_linux.run
sudo sh cuda_12.8.0_550.54.15_linux.run

# 환경 변수 설정
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

### 3️⃣ NIXL 빌드 및 설치 (일반 사용자, 30-45분)

```bash
cd ~/nixl
./build.sh
```

**자동으로 수행:**
1. Python virtual environment 생성 (`.venv/`)
2. Python 패키지 설치 (meson, pybind11, torch 등)
3. NIXL 라이브러리 빌드 및 설치
4. NIXLBench 도구 빌드 및 설치
5. `env.sh` 자동 생성

**설치 위치 (모두 `~/nixl` 안에 위치):**
- NIXL:      `~/nixl/install/nixl/`
- NIXLBench: `~/nixl/install/nixlbench/`

### 4️⃣ 환경 설정

빌드 후 자동 생성된 `env.sh`를 source합니다:

```bash
source ~/nixl/env.sh
```

매 세션마다 자동 적용하려면 `~/.bashrc`에 추가:

```bash
echo 'source ~/nixl/env.sh' >> ~/.bashrc
source ~/.bashrc
```

## ✅ 설치 확인

```bash
# 간단 확인 (true/false)
./check_nixl_installed.sh

# 상세 확인
./check_nixl_installed.sh -v
```

## 🎯 첫 벤치마크 실행

```bash
# POSIX 스토리지 벤치마크 (가장 간단, ETCD 불필요)
./run_nixlbench.sh POSIX

# 네트워크 벤치마크 (ETCD 자동 시작, 두 인스턴스 필요)
./run_nixlbench.sh UCX
# 다른 터미널에서:
sleep 3 && ./run_nixlbench.sh UCX

# 도움말
./run_nixlbench.sh --help
```

옵션 전체 설명은 **`option_report.md`** 참조.

## 🗑️ Tear Down

빌드 결과물이 모두 `~/nixl` 안에 있으므로, 디렉토리 하나만 삭제하면 완전히 제거됩니다:

```bash
rm -rf ~/nixl
```

## 📚 더 알아보기

자세한 설명은 **`HOST_SETUP.md`** 참조:

- **시스템 요구사항** 확인
- **트러블슈팅** 가이드
- **성능 최적화** 팁
- **다양한 백엔드** 사용법

## ⚠️ 문제 발생 시

1. **Meson 에러**: `rm -rf build && ./build.sh` 다시 실행
2. **CUDA 찾을 수 없음**: CUDA 경로 설정 확인
3. **라이브러리 찾을 수 없음**: `source ./env.sh` 재실행
4. **ETCD 연결 안 됨**: Docker 설치 및 ETCD 서버 시작 확인

자세한 트러블슈팅은 `HOST_SETUP.md`의 **트러블슈팅** 섹션 참조

## 📝 주요 파일

```
~/nixl/
├── install-deps.sh          ← 시스템 의존성 설치 (sudo)
├── build.sh                 ← NIXL/NIXLBench 빌드 (일반 사용자)
├── env.sh                   ← 환경 변수 (빌드 후 자동 생성)
├── check_nixl_installed.sh  ← 설치 확인
├── run_nixlbench.sh         ← 벤치마크 실행
├── option_report.md         ← 옵션 전체 설명
├── QUICKSTART.md            ← 이 파일
├── HOST_SETUP.md            ← 상세 설명서
├── install/                 ← 빌드 결과물 (빌드 후 생성)
│   ├── nixl/
│   └── nixlbench/
├── .venv/                   ← Python 가상 환경 (빌드 후 생성)
└── benchmark/
    └── nixlbench/
        └── README.md        ← NIXLBench 완전 설명서
```

## 🔗 유용한 링크

- **GitHub**: https://github.com/ai-dynamo/nixl
- **ETCD**: https://etcd.io/docs/
- **UCX**: https://openucx.readthedocs.io/

---

**예상 소요 시간**: 30-60분 (인터넷 속도에 따라 다름)
**마지막 업데이트**: 2026년 3월
