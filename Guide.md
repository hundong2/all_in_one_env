# Environment setup guide

이 문서는 `all_in_one_env`를 실제 main project에 붙여서 개발환경을 설정하는 방법을 설명합니다.

## 1. Submodule로 추가

main project 루트에서 실행합니다.

```bash
git submodule add https://github.com/hundong2/all_in_one_env tools/all_in_one_env
git submodule update --init --recursive
```

이미 submodule이 등록되어 있다면 최신 상태로 갱신합니다.

```bash
git submodule update --remote --merge tools/all_in_one_env
```

## 2. 설치 전 dry-run

실제 설치 전에 어떤 명령이 실행될지 확인합니다.

Linux/macOS/Git Bash/WSL:

```bash
./tools/all_in_one_env/scripts/aio-env.sh install cpp23 --project "$PWD" --dry-run
./tools/all_in_one_env/scripts/aio-env.sh install dotnet10 --project "$PWD" --dry-run
./tools/all_in_one_env/scripts/aio-env.sh install python3.13 --project "$PWD" --dry-run
```

Windows PowerShell:

```powershell
.\tools\all_in_one_env\scripts\aio-env.ps1 install cpp23 --project . --dry-run
.\tools\all_in_one_env\scripts\aio-env.ps1 install dotnet10 --project . --dry-run
.\tools\all_in_one_env\scripts\aio-env.ps1 install python3.13 --project . --dry-run
```

## 3. 필요한 개발환경 설치

`make`가 있는 환경에서는 아래 형태를 권장합니다.

```bash
make -C tools/all_in_one_env install cpp23 PROJECT_DIR="$PWD"
make -C tools/all_in_one_env install dotnet10 PROJECT_DIR="$PWD"
make -C tools/all_in_one_env install python3.13 PROJECT_DIR="$PWD"
make -C tools/all_in_one_env install rust PROJECT_DIR="$PWD"
make -C tools/all_in_one_env install go PROJECT_DIR="$PWD"
```

Windows에서 `make`가 없다면 PowerShell script를 직접 실행합니다.

```powershell
.\tools\all_in_one_env\scripts\aio-env.ps1 install cpp23 --project .
.\tools\all_in_one_env\scripts\aio-env.ps1 install dotnet10 --project .
.\tools\all_in_one_env\scripts\aio-env.ps1 install python3.13 --project .
.\tools\all_in_one_env\scripts\aio-env.ps1 install rust --project .
.\tools\all_in_one_env\scripts\aio-env.ps1 install go --project .
```

## 4. 기존 설치 확인

설치 없이 현재 환경만 확인할 수 있습니다.

```bash
make -C tools/all_in_one_env verify cpp23 PROJECT_DIR="$PWD"
make -C tools/all_in_one_env verify dotnet10 PROJECT_DIR="$PWD"
make -C tools/all_in_one_env verify python PROJECT_DIR="$PWD"
make -C tools/all_in_one_env verify all PROJECT_DIR="$PWD"
```

PowerShell:

```powershell
.\tools\all_in_one_env\scripts\aio-env.ps1 verify cpp23 --project .
.\tools\all_in_one_env\scripts\aio-env.ps1 verify dotnet10 --project .
.\tools\all_in_one_env\scripts\aio-env.ps1 verify python --project .
.\tools\all_in_one_env\scripts\aio-env.ps1 verify all --project .
```

## 5. VS Code 설정 생성

main project의 `.vscode` 설정을 생성합니다.

```bash
make -C tools/all_in_one_env vscode all PROJECT_DIR="$PWD"
```

PowerShell:

```powershell
.\tools\all_in_one_env\scripts\aio-env.ps1 vscode all --project .
```

생성 대상:

- `.vscode/tasks.json`
- `.vscode/launch.json`
- `.vscode/extensions.json`
- `.vscode/settings.json`

기존 파일이 있으면 덮어쓰지 않고 `.vscode/aio-env.*.json`으로 생성합니다. 강제로 덮어쓰려면 `AIO_FORCE=1`을 설정합니다.

```bash
AIO_FORCE=1 make -C tools/all_in_one_env vscode all PROJECT_DIR="$PWD"
```

```powershell
$env:AIO_FORCE = "1"
.\tools\all_in_one_env\scripts\aio-env.ps1 vscode all --project .
```

## 6. Python uv 기본 흐름

Python 프로젝트는 `uv`를 기준으로 관리합니다.

```bash
make -C tools/all_in_one_env install python3.13 PROJECT_DIR="$PWD"
uv init
uv add pytest ruff
uv run python main.py
uv run pytest
```

이미 `pyproject.toml`이 있으면 `uv sync`가 실행됩니다. `requirements.txt`만 있으면 `uv pip install -r requirements.txt`가 실행됩니다. `.venv`가 이미 있으면 새로 만들지 않습니다.

## 7. Docker 기반 빌드환경

로컬 toolchain 설치 대신 Docker image를 사용할 수 있습니다.

```bash
make -C tools/all_in_one_env docker-build DOCKER_LANG=cpp
make -C tools/all_in_one_env docker-run DOCKER_LANG=cpp PROJECT_DIR="$PWD"

make -C tools/all_in_one_env docker-build DOCKER_LANG=dotnet DOCKER_BUILD_ARGS="--build-arg DOTNET_SDK_TAG=10.0"
make -C tools/all_in_one_env docker-run DOCKER_LANG=dotnet PROJECT_DIR="$PWD"

make -C tools/all_in_one_env docker-build DOCKER_LANG=python DOCKER_BUILD_ARGS="--build-arg PYTHON_TAG=3.13-slim"
make -C tools/all_in_one_env docker-run DOCKER_LANG=python PROJECT_DIR="$PWD"
```

세부 image 인자는 [docker/README.md](docker/README.md)를 참고하세요.

## 8. Parent project Makefile 예시

main project에 wrapper target을 두면 팀원이 명령을 짧게 사용할 수 있습니다.

```makefile
ENV_REPO := tools/all_in_one_env

.PHONY: env-cpp env-python env-vscode env-verify

env-cpp:
	$(MAKE) -C $(ENV_REPO) install cpp23 PROJECT_DIR=$(CURDIR)

env-python:
	$(MAKE) -C $(ENV_REPO) install python3.13 PROJECT_DIR=$(CURDIR)

env-vscode:
	$(MAKE) -C $(ENV_REPO) vscode all PROJECT_DIR=$(CURDIR)

env-verify:
	$(MAKE) -C $(ENV_REPO) verify all PROJECT_DIR=$(CURDIR)
```

## 9. Target 요약

| Target | 목적 |
| --- | --- |
| `cpp17`, `cpp20`, `cpp23` | 요청한 C++ 표준을 compile 가능한 toolchain 확인/설치 |
| `dotnet10` | .NET 10 SDK 확인/설치 |
| `dotnet11-preview` | .NET 11 preview SDK 확인/설치 |
| `python`, `python3.x`, `uv` | uv 설치, Python 설치, `.venv` 생성, dependency sync |
| `rust` | rustup stable, rustfmt, clippy 확인/설치 |
| `go` | Go toolchain 확인/설치 |
| `all` | 기본 개발환경 묶음 |
