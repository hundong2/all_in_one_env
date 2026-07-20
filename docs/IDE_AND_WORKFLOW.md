# IDE and workflow guide

## 공통 권장 방식

submodule로 이 레포를 넣고, 실제 프로젝트 루트에서 필요한 target만 설치/검증합니다.

```bash
git submodule add https://github.com/hundong2/all_in_one_env tools/all_in_one_env
make -C tools/all_in_one_env install cpp23 PROJECT_DIR=$PWD
make -C tools/all_in_one_env vscode all PROJECT_DIR=$PWD
```

기존 `.vscode/tasks.json`, `.vscode/launch.json`, `.vscode/settings.json`이 있으면 덮어쓰지 않고 `aio-env.*.json`으로 생성합니다. 기존 프로젝트 설정에 필요한 항목만 merge해서 쓰는 흐름을 권장합니다.

## C++

실무에서는 CMake 기반 구성이 가장 무난합니다. Windows는 Visual Studio Community 또는 Build Tools + VS Code 조합이 좋고, Linux/macOS는 GCC/Clang + CMake + Ninja 조합이 관리하기 쉽습니다.

추천 IDE:

- Visual Studio: Windows C++ 디버깅과 MSVC 사용이 가장 쉽습니다.
- VS Code: CMake Tools, C/C++ extension, clangd 조합으로 가볍게 운영하기 좋습니다.
- CLion: CMake 프로젝트를 많이 다루는 팀에서 생산성이 좋습니다.

## .NET / C#

.NET 10처럼 LTS/STS가 명확한 버전은 프로젝트의 `global.json`으로 SDK 버전을 고정하는 편이 좋습니다. .NET 11 preview 같은 preview SDK는 제품 코드보다는 실험 branch나 별도 container에서 사용하는 것이 안전합니다.

추천 IDE:

- Visual Studio: Windows에서 .NET 개발과 디버깅 경험이 가장 안정적입니다.
- Rider: cross-platform .NET과 대형 solution 작업에 강합니다.
- VS Code: C# Dev Kit으로 가벼운 프로젝트를 빠르게 열 수 있습니다.

## Python

이 레포는 `uv`를 기본으로 사용합니다. 새 프로젝트는 `pyproject.toml`과 `.python-version`을 두고, 실행은 `uv run ...`, 의존성 동기화는 `uv sync`로 맞추는 방식이 단순합니다.

추천 IDE:

- PyCharm: Python 전용 프로젝트와 테스트/디버깅 구성이 쉽습니다.
- VS Code: Python extension + Ruff + uv 조합이 가볍고 빠릅니다.

## Rust

Rust는 `rustup`으로 toolchain을 관리하고, `rustfmt`, `clippy`, `rust-analyzer`를 기본으로 둡니다.

추천 IDE:

- VS Code: rust-analyzer와 CodeLLDB 조합이 표준에 가깝습니다.
- RustRover/CLion: 복잡한 workspace나 디버깅이 많은 팀에서 편합니다.

## Go

Go는 공식 toolchain + `gopls`가 핵심입니다. VS Code Go extension 또는 GoLand를 쓰면 test/debug/run 구성이 빠릅니다.

## Docker / Dev Containers

팀 전체가 같은 compiler와 SDK를 써야 한다면 Docker 기반 개발환경을 우선 고려하세요. 로컬 설치는 IDE와 디버깅 편의성이 좋고, Docker는 CI와 재현성이 좋습니다. VS Code 사용자라면 이 레포의 `docker/*/Dockerfile`을 `.devcontainer/devcontainer.json`에서 참조하는 방식이 가장 쉽게 확장됩니다.
