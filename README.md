# all_in_one_env

`all_in_one_env`는 여러 main project에서 submodule로 재사용할 수 있는 개발환경 설정 레포입니다. C++, .NET/C#, Python/uv, Rust, Go toolchain 설치 확인, 필요한 경우 설치, VS Code 실행/디버그 설정 생성, Docker 기반 빌드환경을 제공합니다.

## 유지보수용 프롬프트 사용법

언어 버전, preview channel, 설치 스크립트 URL, Docker image tag는 시간이 지나며 바뀔 수 있습니다. 이 레포를 agent로 유지보수할 때는 먼저 [AGENTS.md](AGENTS.md)를 읽게 하고, 아래 프롬프트를 작업 시작 메시지에 붙여 넣으세요.

```text
이 저장소는 여러 main project에서 submodule로 사용하는 개발환경 설정 레포입니다.
먼저 AGENTS.md를 읽고 유지보수 contract와 checklist를 따르세요.

요청:
- 공식 문서를 기준으로 C++, .NET, Python/uv, Rust, Go 설치 방법과 지원 버전을 확인하세요.
- scripts/aio-env.sh와 scripts/aio-env.ps1의 target, 설치 로직, verify 로직을 같은 의미로 유지하세요.
- 기존 toolchain이 있으면 설치하지 않고 검증만 하는 idempotent 동작을 유지하세요.
- README.md, Guide.md, docker/README.md, docs/IDE_AND_WORKFLOW.md를 함께 갱신하세요.
- Dockerfile tag는 가능한 ARG로 유지하고, preview 버전은 고정하지 말고 문서로 확인 절차를 남기세요.
- make harness, PowerShell harness, bash harness, VS Code JSON 파싱을 검증하세요.
```

실제 설치 명령을 변경하기 전에는 `--dry-run` 또는 `AIO_DRY_RUN=1`로 동작을 확인하세요.

## 환경 설정 가이드

실제 프로젝트에서 submodule로 추가하고 환경을 설정하는 자세한 절차는 [Guide.md](Guide.md)에 정리되어 있습니다. `make`가 없는 Windows 환경에서는 PowerShell script를 직접 실행하는 방법도 포함되어 있습니다.

## 빠른 사용법

main project에서 submodule로 추가합니다.

```bash
git submodule add https://github.com/hundong2/all_in_one_env tools/all_in_one_env
git submodule update --init --recursive
```

main project 루트를 `PROJECT_DIR`로 넘겨 필요한 환경만 설치합니다.

```bash
make -C tools/all_in_one_env install cpp23 PROJECT_DIR=$PWD
make -C tools/all_in_one_env install dotnet10 PROJECT_DIR=$PWD
make -C tools/all_in_one_env install dotnet11-preview PROJECT_DIR=$PWD
make -C tools/all_in_one_env install python3.13 PROJECT_DIR=$PWD
make -C tools/all_in_one_env install rust PROJECT_DIR=$PWD
make -C tools/all_in_one_env install go PROJECT_DIR=$PWD
```

Windows PowerShell에서는 직접 실행할 수도 있습니다.

```powershell
.\tools\all_in_one_env\scripts\aio-env.ps1 install cpp23 --project .
.\tools\all_in_one_env\scripts\aio-env.ps1 vscode all --project .
```

## Make command

이 레포 안에서 실행하는 경우:

```bash
make install cpp23
make install c++23
make install dotnet10
make install dotnet11-preview
make install python
make verify all
make vscode all
```

지원 target:

| Target | 내용 |
| --- | --- |
| `cpp17`, `cpp20`, `cpp23` | C++ compiler, CMake, Ninja, debugger 확인/설치 |
| `c++17`, `c++20`, `c++23` | C++ alias |
| `dotnet10` | .NET 10 SDK channel 설치/확인 |
| `dotnet11-preview` | .NET 11 preview SDK channel 설치/확인 |
| `python`, `python3.x`, `uv` | uv 설치, `.venv` 생성, `uv sync`/requirements 설치 |
| `rust` | rustup stable, rustfmt, clippy |
| `go` | Go toolchain |
| `all` | `cpp23`, `dotnet10`, `python`, `rust`, `go` |

C++의 `cpp17`, `cpp20`, `cpp23` target은 표준별로 다른 runtime을 설치하는 방식이 아니라, 요청한 언어 표준으로 compile 가능한 compiler toolchain을 확인하고 부족하면 C++ compiler/CMake/Ninja/debugger 구성을 설치 또는 보강합니다. C++23은 compiler별 지원 상태가 다르므로 GCC/Clang은 `-std=c++23` 또는 `-std=c++2b`, MSVC는 `/std:c++latest` 계열로 검증합니다.

## 기존 설치가 있을 때

설치 스크립트는 먼저 현재 컴퓨터의 toolchain을 확인합니다.

- C++: compiler가 요청 표준을 compile 할 수 있는지 확인하고 CMake/Ninja를 확인합니다.
- .NET: `dotnet --list-sdks`에서 요청 major SDK를 확인합니다.
- Python: `uv`와 project `.venv` 존재 여부를 확인합니다.
- Rust: `rustup`, `rustc`, `cargo`를 확인합니다.
- Go: `go version`을 확인합니다.

이미 확인된 항목은 새로 설치하지 않습니다. 검증만 하고 싶으면:

```bash
make verify cpp23
make verify dotnet10
make verify python
```

실제 설치 명령을 실행하지 않고 확인하려면 `--dry-run` 또는 `AIO_DRY_RUN=1`을 사용합니다. Windows PowerShell에서 WSL `bash.exe`를 호출하는 혼합 환경에서는 환경변수 전달이 달라질 수 있으므로 인자 방식이 더 안전합니다.

```bash
./scripts/aio-env.sh install cpp23 --dry-run
```

```powershell
.\scripts\aio-env.ps1 install cpp23 --dry-run
```

## Python uv workflow

Python target은 `uv`를 기본으로 사용합니다.

```bash
make install python3.13 PROJECT_DIR=$PWD
uv add pytest ruff
uv run python main.py
uv run pytest
```

프로젝트에 `pyproject.toml`이 있으면 `uv sync`를 실행하고, `requirements.txt`만 있으면 `uv pip install -r requirements.txt`를 실행합니다. `.venv`가 이미 있으면 새로 만들지 않습니다.

## VS Code 설정

```bash
make vscode all PROJECT_DIR=$PWD
```

생성 파일:

- `.vscode/tasks.json`
- `.vscode/launch.json`
- `.vscode/extensions.json`
- `.vscode/settings.json`

기존 파일이 있으면 덮어쓰지 않고 `.vscode/aio-env.*.json`으로 생성합니다. 강제로 덮어쓰려면 `AIO_FORCE=1`을 사용합니다.

## Docker 기반 개발환경

로컬 설치 대신 container에서 빌드하려면:

```bash
make docker-build DOCKER_LANG=cpp
make docker-run DOCKER_LANG=cpp PROJECT_DIR=$PWD

make docker-build DOCKER_LANG=dotnet DOCKER_BUILD_ARGS="--build-arg DOTNET_SDK_TAG=10.0"
make docker-run DOCKER_LANG=dotnet PROJECT_DIR=$PWD

make docker-build DOCKER_LANG=python DOCKER_BUILD_ARGS="--build-arg PYTHON_TAG=3.13-slim"
make docker-run DOCKER_LANG=python PROJECT_DIR=$PWD
```

자세한 내용은 [docker/README.md](docker/README.md)를 참고하세요.

## 실무 IDE 선택

- C++: Visual Studio, VS Code + CMake Tools, CLion
- .NET/C#: Visual Studio, Rider, VS Code + C# Dev Kit
- Python: PyCharm, VS Code + Python/Ruff, uv 기반 `pyproject.toml`
- Rust: VS Code + rust-analyzer/CodeLLDB, RustRover
- Go: VS Code + Go extension, GoLand

팀 단위로 compiler/SDK 버전 재현성이 중요하면 Docker 또는 Dev Container를 먼저 고려하세요. 자세한 기준은 [docs/IDE_AND_WORKFLOW.md](docs/IDE_AND_WORKFLOW.md)를 참고하세요.

## 유지보수

언어 버전과 설치 방법은 시간이 지나며 바뀝니다. agent가 이 레포를 유지보수할 때는 [AGENTS.md](AGENTS.md)의 checklist와 source refresh points를 먼저 확인해야 합니다.

로컬 smoke check:

```bash
make harness
AIO_DRY_RUN=1 ./scripts/aio-env.sh install cpp23
```
