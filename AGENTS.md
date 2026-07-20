# Agent maintenance guide

이 저장소의 목적은 parent repository에 submodule로 들어가 개발환경 설치, 검증, VS Code 실행 설정, Docker 빌드환경을 제공하는 것입니다. 유지보수 agent는 아래 규칙을 우선합니다.

## Contract

- `make install <target>`는 기존 toolchain을 먼저 확인하고, 없는 경우에만 설치를 시도합니다.
- `make verify <target>`는 설치 없이 현재 환경을 보고합니다.
- `make vscode <target>`는 parent project의 기존 `.vscode/*.json`을 기본적으로 덮어쓰지 않습니다. 덮어쓰기는 `AIO_FORCE=1`일 때만 허용합니다.
- `PROJECT_DIR`은 실제 main project root를 가리킵니다. submodule 내부 경로와 혼동하지 마세요.
- 설치 명령 변경 전에는 `AIO_DRY_RUN=1`로 dry-run 출력이 깨지지 않는지 확인합니다.

## Supported targets

- C++: `cpp17`, `cpp20`, `cpp23`, alias `c++17`, `c++20`, `c++23`
- .NET: `dotnet10`, `dotnet11-preview`
- Python: `python`, `python3.x`, `uv`
- Rust: `rust`
- Go: `go`
- Aggregate: `all`

## Update checklist

1. 공식 upstream 문서에서 최신 설치 채널, preview 이름, Docker tag를 확인합니다.
2. `scripts/aio-env.sh`와 `scripts/aio-env.ps1`의 target alias와 설치 로직을 같이 수정합니다.
3. README, Docker README, IDE guide의 예시 명령을 같이 갱신합니다.
4. Dockerfile은 가능한 한 `ARG`로 버전 tag를 받게 유지합니다.
5. 기존 `.vscode` 파일을 덮어쓰지 않는 동작을 유지합니다.
6. 아래 harness를 실행합니다.

```bash
make harness
AIO_DRY_RUN=1 ./scripts/aio-env.sh install cpp23
./scripts/aio-env.sh install cpp23 --dry-run
```

Windows:

```powershell
make harness
$env:AIO_DRY_RUN = "1"
.\scripts\aio-env.ps1 install dotnet11-preview
.\scripts\aio-env.ps1 install dotnet11-preview --dry-run
```

## Source refresh points

- .NET install script: https://learn.microsoft.com/en-us/dotnet/core/tools/dotnet-install-script
- .NET support policy: https://dotnet.microsoft.com/en-us/platform/support/policy/dotnet-core
- .NET Docker images: https://learn.microsoft.com/en-us/dotnet/architecture/microservices/net-core-net-framework-containers/official-net-docker-images
- uv installation: https://docs.astral.sh/uv/getting-started/installation/
- Rust installation: https://www.rust-lang.org/tools/install/
- Go installation: https://go.dev/doc/install
- MSVC C++ build tools: https://learn.microsoft.com/en-us/cpp/build/building-on-the-command-line
- Clang C++ status: https://clang.llvm.org/cxx_status.html

## Practical rules

- Prefer user-local installers when possible: `.NET` install script, `uv`, `rustup`.
- Use OS package managers only for system build tools where user-local install is impractical.
- Do not pin volatile preview versions in scripts unless a project explicitly requires it.
- Keep installers idempotent. Detection and verification should be cheaper and safer than installation.
- If adding a new language, implement `install`, `verify`, VS Code recommendation, Dockerfile, README entry, and harness target together.
