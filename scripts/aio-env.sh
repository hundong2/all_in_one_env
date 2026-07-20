#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DRY_RUN="${AIO_DRY_RUN:-0}"
PROJECT_DIR="${PROJECT_DIR:-$PWD}"

log() {
  printf '[aio-env] %s\n' "$*"
}

warn() {
  printf '[aio-env] WARN: %s\n' "$*" >&2
}

die() {
  printf '[aio-env] ERROR: %s\n' "$*" >&2
  exit 1
}

has() {
  command -v "$1" >/dev/null 2>&1
}

run() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '+'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}

run_shell() {
  if [ "$DRY_RUN" = "1" ]; then
    printf '+ %s\n' "$*"
  else
    sh -c "$*"
  fi
}

as_root() {
  if [ "${EUID:-$(id -u)}" -eq 0 ]; then
    run "$@"
  elif has sudo; then
    run sudo "$@"
  else
    warn "root 권한이 필요하지만 sudo를 찾을 수 없습니다: $*"
    return 1
  fi
}

usage() {
  cat <<'EOF'
all_in_one_env

Usage:
  make install cpp23
  make install c++23
  make install dotnet10
  make install dotnet11-preview
  make install python3.13
  make install rust
  make install go
  make verify all
  make vscode all PROJECT_DIR=/path/to/main-project

Direct:
  ./scripts/aio-env.sh install cpp23 --project /path/to/main-project
  ./scripts/aio-env.sh verify dotnet10
  ./scripts/aio-env.sh vscode python

Targets:
  cpp17, cpp20, cpp23, c++17, c++20, c++23
  dotnet10, dotnet11-preview
  python, python3.13, uv
  rust
  go
  all

Environment:
  PROJECT_DIR=/path        Main project root when this repo is used as a submodule.
  AIO_DRY_RUN=1            Print install commands without running them.
  AIO_FORCE=1              Overwrite generated .vscode files.
EOF
}

list_targets() {
  cat <<'EOF'
cpp17
cpp20
cpp23
dotnet10
dotnet11-preview
python
python3.13
rust
go
all
EOF
}

normalize_target() {
  local raw="$1"
  local t
  t="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -d '[:space:]' | tr '_' '-')"

  case "$t" in
    c++17|cpp17|cxx17) printf 'cpp17\n' ;;
    c++20|cpp20|cxx20) printf 'cpp20\n' ;;
    c++23|cpp23|cxx23) printf 'cpp23\n' ;;
    dotnet10|net10|csharp10|c#10) printf 'dotnet10\n' ;;
    dotnet11|net11|dotnet11-preview|dotnet11preview|net11-preview|net11preview|csharp11-preview|csharp11preview|c#11-preview|c#11preview) printf 'dotnet11-preview\n' ;;
    python|py|uv) printf 'python\n' ;;
    rust|rs) printf 'rust\n' ;;
    go|golang) printf 'go\n' ;;
    all) printf 'all\n' ;;
    *)
      if [[ "$t" =~ ^python([0-9]+(\.[0-9]+)?)$ ]]; then
        printf 'python:%s\n' "${BASH_REMATCH[1]}"
      elif [[ "$t" =~ ^py([0-9]+(\.[0-9]+)?)$ ]]; then
        printf 'python:%s\n' "${BASH_REMATCH[1]}"
      else
        die "알 수 없는 target입니다: $raw"
      fi
      ;;
  esac
}

expand_targets() {
  local normalized=()
  local item
  for item in "$@"; do
    normalized+=("$(normalize_target "$item")")
  done

  if [ "${#normalized[@]}" -eq 0 ]; then
    return 0
  fi

  local expanded=()
  for item in "${normalized[@]}"; do
    if [ "$item" = "all" ]; then
      expanded+=(cpp23 dotnet10 python rust go)
    else
      expanded+=("$item")
    fi
  done

  printf '%s\n' "${expanded[@]}"
}

parse_args() {
  COMMAND="${1:-help}"
  shift || true
  TARGETS=()

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --project)
        [ "$#" -ge 2 ] || die "--project 값이 필요합니다."
        PROJECT_DIR="$2"
        shift 2
        ;;
      --project=*)
        PROJECT_DIR="${1#--project=}"
        shift
        ;;
      --dry-run)
        DRY_RUN=1
        shift
        ;;
      --help|-h)
        COMMAND=help
        shift
        ;;
      *)
        TARGETS+=("$1")
        shift
        ;;
    esac
  done

  if [ -d "$PROJECT_DIR" ]; then
    PROJECT_DIR="$(cd "$PROJECT_DIR" && pwd)"
  fi
}

ensure_project_dir() {
  if [ ! -d "$PROJECT_DIR" ]; then
    run mkdir -p "$PROJECT_DIR"
  fi
}

select_cpp_compiler() {
  if [ -n "${CXX:-}" ] && has "$CXX"; then
    printf '%s\n' "$CXX"
    return 0
  fi

  local compiler
  for compiler in c++ g++ clang++ cl; do
    if has "$compiler"; then
      printf '%s\n' "$compiler"
      return 0
    fi
  done

  return 1
}

candidate_cpp_compilers() {
  if [ -n "${CXX:-}" ] && has "$CXX"; then
    printf '%s\n' "$CXX"
  fi

  local compiler
  for compiler in c++ g++ clang++ cl; do
    if has "$compiler"; then
      printf '%s\n' "$compiler"
    fi
  done
}

cpp_standard_number() {
  case "$1" in
    cpp17) printf '17\n' ;;
    cpp20) printf '20\n' ;;
    cpp23) printf '23\n' ;;
    *) die "C++ target이 아닙니다: $1" ;;
  esac
}

cpp_threshold() {
  case "$1" in
    17) printf '201703L\n' ;;
    20) printf '202002L\n' ;;
    23) printf '202100L\n' ;;
    *) die "지원하지 않는 C++ 표준입니다: $1" ;;
  esac
}

try_cpp_standard() {
  local standard="$1"
  local compiler
  local found=1

  local tmp
  tmp="$(mktemp -d)"
  local src="$tmp/main.cpp"
  local exe="$tmp/a.out"
  local threshold
  threshold="$(cpp_threshold "$standard")"

  cat >"$src" <<EOF
#ifndef __cplusplus
#error "not compiling as C++"
#endif
#if __cplusplus < $threshold
#error "compiler does not report the requested standard"
#endif
int main() { return 0; }
EOF

  while IFS= read -r compiler; do
    local name
    name="$(basename "$compiler" | tr '[:upper:]' '[:lower:]')"
    local flags=()
    case "$name" in
      cl|cl.exe)
        case "$standard" in
          17) flags=("/std:c++17") ;;
          20) flags=("/std:c++20") ;;
          23) flags=("/std:c++latest") ;;
        esac
        if "$compiler" /nologo /EHsc /Zc:__cplusplus "${flags[@]}" "$src" "/Fe:$tmp/main.exe" >/dev/null 2>&1; then
          found=0
          break
        fi
        ;;
      *)
        case "$standard" in
          17) flags=("-std=c++17") ;;
          20) flags=("-std=c++20") ;;
          23) flags=("-std=c++23" "-std=c++2b") ;;
        esac

        local flag
        for flag in "${flags[@]}"; do
          if "$compiler" "$flag" "$src" -o "$exe" >/dev/null 2>&1; then
            found=0
            break
          fi
        done
        [ "$found" -eq 0 ] && break
        ;;
    esac
  done < <(candidate_cpp_compilers)

  rm -rf "$tmp"
  return "$found"
}

install_linux_cpp() {
  if has apt-get; then
    as_root apt-get update
    as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y build-essential cmake ninja-build gdb clang lldb
  elif has dnf; then
    as_root dnf install -y gcc gcc-c++ cmake ninja-build gdb clang lldb
  elif has pacman; then
    as_root pacman -Sy --needed base-devel cmake ninja gdb clang lldb
  elif has zypper; then
    as_root zypper install -y gcc gcc-c++ cmake ninja gdb clang lldb
  elif has apk; then
    as_root apk add build-base cmake ninja gdb clang lldb
  else
    warn "지원하는 Linux 패키지 매니저를 찾지 못했습니다. GCC/Clang, CMake, Ninja, debugger를 수동 설치하세요."
  fi
}

install_macos_cpp() {
  if has xcode-select && ! xcode-select -p >/dev/null 2>&1; then
    run xcode-select --install || true
  fi

  if has brew; then
    run brew install cmake ninja llvm gcc
  else
    warn "Homebrew가 없습니다. Xcode Command Line Tools, CMake, Ninja 설치 여부를 확인하세요."
  fi
}

install_cpp() {
  local target="$1"
  local standard
  standard="$(cpp_standard_number "$target")"

  if try_cpp_standard "$standard" && has cmake; then
    log "C++$standard 개발환경이 이미 확인되었습니다."
    has ninja || warn "ninja를 찾지 못했습니다. CMake 기본 generator를 쓰거나 ninja를 별도 설치하세요."
    return 0
  fi

  log "C++$standard 개발환경을 설치/보강합니다."
  case "$(uname -s)" in
    Darwin) install_macos_cpp ;;
    Linux) install_linux_cpp ;;
    MINGW*|MSYS*|CYGWIN*) warn "Windows에서는 scripts/aio-env.ps1 또는 make를 PowerShell 환경에서 실행하세요." ;;
    *) warn "지원하지 않는 OS입니다. C++ 컴파일러, CMake, Ninja를 수동 설치하세요." ;;
  esac

  verify_cpp "$target"
}

verify_cpp() {
  local target="$1"
  local standard
  standard="$(cpp_standard_number "$target")"

  if select_cpp_compiler >/dev/null; then
    local compiler
    compiler="$(select_cpp_compiler)"
    log "C++ compiler: $compiler"
    "$compiler" --version 2>/dev/null | head -n 1 || true
  else
    warn "C++ compiler를 찾지 못했습니다."
  fi

  if try_cpp_standard "$standard"; then
    log "C++$standard compile check: OK"
  else
    warn "C++$standard compile check: FAILED"
  fi

  if has cmake; then cmake --version | head -n 1; else warn "cmake를 찾지 못했습니다."; fi
  if has ninja; then ninja --version | sed 's/^/[aio-env] ninja: /'; else warn "ninja를 찾지 못했습니다."; fi
}

dotnet_major_for() {
  case "$1" in
    dotnet10) printf '10\n' ;;
    dotnet11-preview) printf '11\n' ;;
    *) die ".NET target이 아닙니다: $1" ;;
  esac
}

dotnet_quality_for() {
  case "$1" in
    dotnet10) printf 'GA\n' ;;
    dotnet11-preview) printf 'preview\n' ;;
    *) die ".NET target이 아닙니다: $1" ;;
  esac
}

dotnet_sdk_installed() {
  local major="$1"
  has dotnet || return 1
  dotnet --list-sdks 2>/dev/null | awk '{print $1}' | grep -Eq "^${major}\."
}

install_dotnet() {
  local target="$1"
  local major quality channel installer tmp
  major="$(dotnet_major_for "$target")"
  quality="$(dotnet_quality_for "$target")"
  channel="${major}.0"

  export DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}"
  export PATH="$DOTNET_ROOT:$PATH"

  if dotnet_sdk_installed "$major"; then
    log ".NET SDK $major.x가 이미 설치되어 있습니다."
    verify_dotnet "$target"
    return 0
  fi

  log ".NET SDK channel=$channel quality=$quality 설치를 시작합니다."
  tmp="$(mktemp -d)"
  installer="$tmp/dotnet-install.sh"
  if has curl; then
    run curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$installer"
  elif has wget; then
    run wget -q https://dot.net/v1/dotnet-install.sh -O "$installer"
  else
    die "curl 또는 wget이 필요합니다."
  fi

  run bash "$installer" --channel "$channel" --quality "$quality" --install-dir "$DOTNET_ROOT"
  log "현재 shell에서 DOTNET_ROOT=$DOTNET_ROOT, PATH에 \$DOTNET_ROOT를 추가했습니다."
  verify_dotnet "$target"
}

verify_dotnet() {
  local target="$1"
  local major
  major="$(dotnet_major_for "$target")"

  export DOTNET_ROOT="${DOTNET_ROOT:-$HOME/.dotnet}"
  export PATH="$DOTNET_ROOT:$PATH"

  if has dotnet; then
    dotnet --info | sed -n '1,12p'
    if dotnet_sdk_installed "$major"; then
      log ".NET SDK $major.x check: OK"
    else
      warn ".NET SDK $major.x를 찾지 못했습니다."
    fi
  else
    warn "dotnet CLI를 찾지 못했습니다."
  fi
}

python_version_for() {
  local target="$1"
  if [[ "$target" == python:* ]]; then
    printf '%s\n' "${target#python:}"
    return 0
  fi

  if [ -f "$PROJECT_DIR/.python-version" ]; then
    sed -n '1p' "$PROJECT_DIR/.python-version"
  fi
}

ensure_uv() {
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"
  if has uv; then
    log "uv가 이미 설치되어 있습니다: $(uv --version)"
    return 0
  fi

  log "uv를 설치합니다."
  if has curl; then
    run_shell "curl -LsSf https://astral.sh/uv/install.sh | sh"
  elif has wget; then
    run_shell "wget -qO- https://astral.sh/uv/install.sh | sh"
  else
    die "uv 설치에는 curl 또는 wget이 필요합니다."
  fi
}

install_python() {
  local target="$1"
  local version
  ensure_project_dir
  ensure_uv
  version="$(python_version_for "$target" || true)"

  if [ -n "$version" ]; then
    log "uv managed Python $version 설치를 확인합니다."
    run uv python install "$version"
  fi

  if [ -d "$PROJECT_DIR/.venv" ]; then
    log "$PROJECT_DIR/.venv 가 이미 있어 새 venv를 만들지 않습니다."
  else
    if [ -n "$version" ]; then
      (cd "$PROJECT_DIR" && run uv venv --python "$version")
    else
      (cd "$PROJECT_DIR" && run uv venv)
    fi
  fi

  if [ -f "$PROJECT_DIR/pyproject.toml" ]; then
    (cd "$PROJECT_DIR" && run uv sync)
  elif [ -f "$PROJECT_DIR/requirements.txt" ]; then
    (cd "$PROJECT_DIR" && run uv pip install -r requirements.txt)
  else
    log "pyproject.toml 또는 requirements.txt가 없어 dependency sync는 건너뜁니다."
  fi

  verify_python "$target"
}

verify_python() {
  local target="$1"
  ensure_project_dir
  export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

  if has uv; then
    uv --version
    if [ -d "$PROJECT_DIR/.venv" ]; then
      log "Python venv: $PROJECT_DIR/.venv"
      (cd "$PROJECT_DIR" && uv run python --version) || true
    else
      warn "$PROJECT_DIR/.venv 를 찾지 못했습니다."
    fi
  else
    warn "uv를 찾지 못했습니다."
  fi

  if [ "$target" != "python" ] && [[ "$target" == python:* ]]; then
    log "requested Python: ${target#python:}"
  fi
}

install_rust() {
  export PATH="$HOME/.cargo/bin:$PATH"
  if has rustup; then
    log "rustup이 이미 설치되어 있습니다."
  elif has cargo; then
    log "cargo가 이미 설치되어 있습니다. rustup 기반 관리는 건너뜁니다."
    verify_rust
    return 0
  else
    log "rustup으로 Rust stable toolchain을 설치합니다."
    if has curl; then
      run_shell "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
    else
      die "rustup 설치에는 curl이 필요합니다."
    fi
  fi

  run rustup toolchain install stable
  run rustup default stable
  run rustup component add rustfmt clippy
  verify_rust
}

verify_rust() {
  export PATH="$HOME/.cargo/bin:$PATH"
  if has rustc; then rustc --version; else warn "rustc를 찾지 못했습니다."; fi
  if has cargo; then cargo --version; else warn "cargo를 찾지 못했습니다."; fi
  if has rustup; then rustup show active-toolchain || true; fi
}

install_go() {
  if has go; then
    log "Go가 이미 설치되어 있습니다."
    verify_go
    return 0
  fi

  log "Go를 설치합니다."
  case "$(uname -s)" in
    Darwin)
      if has brew; then run brew install go; else warn "Homebrew가 없습니다. https://go.dev/dl 에서 Go installer를 사용하세요."; fi
      ;;
    Linux)
      if has apt-get; then
        as_root apt-get update
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y golang-go
      elif has dnf; then
        as_root dnf install -y golang
      elif has pacman; then
        as_root pacman -Sy --needed go
      elif has zypper; then
        as_root zypper install -y go
      elif has apk; then
        as_root apk add go
      else
        warn "지원하는 Linux 패키지 매니저를 찾지 못했습니다. https://go.dev/dl 에서 Go를 설치하세요."
      fi
      ;;
    *) warn "지원하지 않는 OS입니다. https://go.dev/dl 에서 Go를 설치하세요." ;;
  esac

  verify_go
}

verify_go() {
  if has go; then go version; else warn "go CLI를 찾지 못했습니다."; fi
}

write_file_if_missing() {
  local path="$1"
  local generator="$2"
  local force="${AIO_FORCE:-0}"
  local actual="$path"

  if [ -f "$path" ] && [ "$force" != "1" ]; then
    local dir base
    dir="$(dirname "$path")"
    base="$(basename "$path")"
    actual="$dir/aio-env.$base"
    warn "$path 가 이미 있어 덮어쓰지 않습니다. $actual 로 생성합니다."
  fi

  if [ "$DRY_RUN" = "1" ]; then
    printf '+ write %s\n' "$actual"
    return 0
  fi

  "$generator" >"$actual"
  log "wrote $actual"
}

generate_tasks_json() {
  cat <<'EOF'
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "C++: configure (CMake)",
      "type": "shell",
      "command": "cmake",
      "args": ["-S", "${workspaceFolder}", "-B", "${workspaceFolder}/build", "-DCMAKE_BUILD_TYPE=Debug"],
      "problemMatcher": []
    },
    {
      "label": "C++: build (CMake)",
      "type": "shell",
      "command": "cmake",
      "args": ["--build", "${workspaceFolder}/build", "--config", "Debug"],
      "dependsOn": "C++: configure (CMake)",
      "problemMatcher": ["$gcc"]
    },
    {
      "label": ".NET: build",
      "type": "process",
      "command": "dotnet",
      "args": ["build", "${workspaceFolder}"],
      "problemMatcher": "$msCompile"
    },
    {
      "label": "Python: run current file (uv)",
      "type": "process",
      "command": "uv",
      "args": ["run", "python", "${file}"],
      "options": { "cwd": "${workspaceFolder}" },
      "problemMatcher": []
    },
    {
      "label": "Rust: build",
      "type": "process",
      "command": "cargo",
      "args": ["build"],
      "options": { "cwd": "${workspaceFolder}" },
      "problemMatcher": ["$rustc"]
    },
    {
      "label": "Go: run current file",
      "type": "process",
      "command": "go",
      "args": ["run", "${file}"],
      "options": { "cwd": "${workspaceFolder}" },
      "problemMatcher": []
    }
  ]
}
EOF
}

generate_launch_json() {
  cat <<'EOF'
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "C++: debug build/app",
      "type": "cppdbg",
      "request": "launch",
      "program": "${workspaceFolder}/build/app",
      "args": [],
      "stopAtEntry": false,
      "cwd": "${workspaceFolder}",
      "environment": [],
      "externalConsole": false,
      "MIMode": "gdb",
      "preLaunchTask": "C++: build (CMake)"
    },
    {
      "name": ".NET: launch project dll",
      "type": "coreclr",
      "request": "launch",
      "program": "${workspaceFolder}/bin/Debug/net10.0/REPLACE_WITH_PROJECT_DLL.dll",
      "args": [],
      "cwd": "${workspaceFolder}",
      "console": "integratedTerminal",
      "stopAtEntry": false,
      "preLaunchTask": ".NET: build"
    },
    {
      "name": "Python: current file (uv venv)",
      "type": "debugpy",
      "request": "launch",
      "program": "${file}",
      "console": "integratedTerminal",
      "cwd": "${workspaceFolder}",
      "justMyCode": true
    },
    {
      "name": "Rust: debug target/debug binary",
      "type": "lldb",
      "request": "launch",
      "program": "${workspaceFolder}/target/debug/REPLACE_WITH_BINARY",
      "args": [],
      "cwd": "${workspaceFolder}",
      "preLaunchTask": "Rust: build"
    },
    {
      "name": "Go: debug package",
      "type": "go",
      "request": "launch",
      "mode": "auto",
      "program": "${fileDirname}",
      "cwd": "${workspaceFolder}"
    }
  ]
}
EOF
}

generate_extensions_json() {
  cat <<'EOF'
{
  "recommendations": [
    "ms-vscode.cpptools",
    "ms-vscode.cmake-tools",
    "ms-dotnettools.csdevkit",
    "ms-dotnettools.csharp",
    "ms-python.python",
    "charliermarsh.ruff",
    "rust-lang.rust-analyzer",
    "vadimcn.vscode-lldb",
    "golang.go"
  ]
}
EOF
}

generate_settings_json() {
  cat <<'EOF'
{
  "cmake.configureOnOpen": false,
  "python.terminal.activateEnvironment": true,
  "python.analysis.typeCheckingMode": "basic",
  "rust-analyzer.check.command": "clippy",
  "go.toolsManagement.autoUpdate": true
}
EOF
}

setup_vscode() {
  ensure_project_dir
  run mkdir -p "$PROJECT_DIR/.vscode"
  write_file_if_missing "$PROJECT_DIR/.vscode/tasks.json" generate_tasks_json
  write_file_if_missing "$PROJECT_DIR/.vscode/launch.json" generate_launch_json
  write_file_if_missing "$PROJECT_DIR/.vscode/extensions.json" generate_extensions_json
  write_file_if_missing "$PROJECT_DIR/.vscode/settings.json" generate_settings_json
}

run_harness() {
  local script="$REPO_ROOT/harness/smoke.sh"
  run bash "$script"
}

install_target() {
  case "$1" in
    cpp17|cpp20|cpp23) install_cpp "$1" ;;
    dotnet10|dotnet11-preview) install_dotnet "$1" ;;
    python|python:*) install_python "$1" ;;
    rust) install_rust ;;
    go) install_go ;;
    *) die "지원하지 않는 target입니다: $1" ;;
  esac
}

verify_target() {
  case "$1" in
    cpp17|cpp20|cpp23) verify_cpp "$1" ;;
    dotnet10|dotnet11-preview) verify_dotnet "$1" ;;
    python|python:*) verify_python "$1" ;;
    rust) verify_rust ;;
    go) verify_go ;;
    *) die "지원하지 않는 target입니다: $1" ;;
  esac
}

main() {
  parse_args "$@"

  case "$COMMAND" in
    help) usage ;;
    list|targets) list_targets ;;
    install)
      if [ "${#TARGETS[@]}" -eq 0 ]; then
        die "install target이 필요합니다. 예: make install cpp23"
      fi
      EXPANDED_TARGETS=()
      while IFS= read -r target; do EXPANDED_TARGETS+=("$target"); done < <(expand_targets "${TARGETS[@]}")
      for target in "${EXPANDED_TARGETS[@]}"; do install_target "$target"; done
      ;;
    verify)
      if [ "${#TARGETS[@]}" -eq 0 ]; then TARGETS=(all); fi
      EXPANDED_TARGETS=()
      while IFS= read -r target; do EXPANDED_TARGETS+=("$target"); done < <(expand_targets "${TARGETS[@]}")
      for target in "${EXPANDED_TARGETS[@]}"; do verify_target "$target"; done
      ;;
    vscode)
      setup_vscode
      ;;
    harness)
      run_harness
      ;;
    *)
      die "알 수 없는 command입니다: $COMMAND"
      ;;
  esac
}

main "$@"
