# NIXL 호스트 설치 - 빠른 시작 가이드

Docker 대신 **호스트에 직접 설치**하는 방법입니다. 약 30-60분이 소요됩니다.

## 📋 준비 확인

현재 상태:
- ✅ NIXL 소스 코드 다운로드 완료
- ✅ `install-deps.sh` - 시스템 의존성 설치 스크립트
- ✅ `build.sh` - 빌드 스크립트
- ✅ `HOST_SETUP.md` - 상세 설명서

## 🚀 빠른 설치 (4단계)

### 1️⃣ 시스템 의존성 설치 (sudo 필요, 10-15분)

```bash
cd /home/gj/nixl
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
cd /home/gj/nixl
./build.sh
```

**자동으로 수행:**
1. Python virtual environment 생성
2. Python 패키지 설치 (meson, pybind11, torch 등)
3. NIXL 라이브러리 빌드 및 설치
4. NIXLBench 도구 빌드 및 설치

설치 위치:
- NIXL:       `~/.local/nixl`
- NIXLBench:  `~/.local/nixlbench`

## 🔧 환경 설정

`~/.bashrc` 또는 `~/.zshrc`에 추가:

```bash
export PATH=$HOME/.local/nixlbench/bin:$HOME/.local/nixl/bin:$PATH
export LD_LIBRARY_PATH=$HOME/.local/nixlbench/lib:$HOME/.local/nixl/lib/x86_64-linux-gnu:$LD_LIBRARY_PATH
```

적용:
```bash
source ~/.bashrc
```

## ✅ 설치 확인

```bash
# 설치 확인
which nixlbench
nixlbench --help

# 바이너리 확인
ls -la /usr/local/nixlbench/bin/
```

## 🎯 첫 벤치마크 실행

### ETCD 서버 시작 (별도 터미널)

```bash
docker run -d --name etcd-server \
  -p 2379:2379 \
  quay.io/coreos/etcd:v3.5.18
```

### 기본 벤치마크 실행

```bash
sleep 2 && timeout 30 nixlbench \
  --etcd_endpoints http://localhost:2379 \
  --backend POSIX \
  --filepath /tmp/nixl_test \
  --num_iter 10 \
  --warmup_iter 2
```

## 📚 더 알아보기

자세한 설명은 **`HOST_SETUP.md`** 참조:

- **시스템 요구사항** 확인
- **트러블슈팅** 가이드
- **벤치마크 옵션** 설명
- **성능 최적화** 팁
- **다양한 백엔드** 사용법

## ⚠️ 문제 발생 시

1. **Meson 에러**: `rm -rf build && ./build.sh` 다시 실행
2. **CUDA 찾을 수 없음**: CUDA 경로 설정 확인
3. **라이브러리 찾을 수 없음**: `sudo ldconfig` 실행
4. **ETCD 연결 안 됨**: Docker 설치 및 ETCD 서버 시작 확인

자세한 트러블슈팅은 `HOST_SETUP.md`의 **트러블슈팅** 섹션 참조

## 📝 주요 파일

```
/home/gj/nixl/
├── install-deps.sh      ← 시스템 의존성 설치 (sudo)
├── build.sh             ← NIXL/NIXLBench 빌드 (일반 사용자)
├── QUICKSTART.md        ← 이 파일
├── HOST_SETUP.md        ← 상세 설명서
├── benchmark/
│   └── nixlbench/
│       └── README.md    ← NIXLBench 완전 설명서
└── build/               ← 빌드 아티팩트 (자동 생성)
```

## 🔗 유용한 링크

- **GitHub**: https://github.com/ai-dynamo/nixl
- **ETCD**: https://etcd.io/docs/
- **UCX**: https://openucx.readthedocs.io/

---

**예상 소요 시간**: 30-60분 (인터넷 속도에 따라 다름)
**마지막 업데이트**: 2025년 3월
