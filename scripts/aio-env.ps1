param(
    [Parameter(Position = 0)]
    [string]$Command = "help",

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Rest
)

$ErrorActionPreference = "Stop"
$Script:RepoRoot = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$Script:DryRun = $env:AIO_DRY_RUN -eq "1"
$Script:ProjectDir = if ($env:PROJECT_DIR) { $env:PROJECT_DIR } else { (Get-Location).Path }
$Script:Targets = @()

function Write-AioLog {
    param([string]$Message)
    Write-Host "[aio-env] $Message"
}

function Write-AioWarn {
    param([string]$Message)
    Write-Warning "[aio-env] $Message"
}

function Throw-Aio {
    param([string]$Message)
    throw "[aio-env] ERROR: $Message"
}

function Test-Command {
    param([string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Invoke-AioCommand {
    param(
        [Parameter(Mandatory = $true)][string]$FilePath,
        [string[]]$Arguments = @()
    )

    if ($Script:DryRun) {
        Write-Host ("+ {0} {1}" -f $FilePath, ($Arguments -join " "))
        return
    }

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        Throw-Aio "command failed: $FilePath $($Arguments -join ' ')"
    }
}

function Invoke-AioShell {
    param([Parameter(Mandatory = $true)][string]$CommandLine)

    if ($Script:DryRun) {
        Write-Host "+ $CommandLine"
        return
    }

    Invoke-Expression $CommandLine
    if ($LASTEXITCODE -ne 0) {
        Throw-Aio "command failed: $CommandLine"
    }
}

function Show-Usage {
@"
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
  make vscode all PROJECT_DIR=C:\path\to\main-project

Direct:
  .\scripts\aio-env.ps1 install cpp23 --project C:\path\to\main-project
  .\scripts\aio-env.ps1 verify dotnet10
  .\scripts\aio-env.ps1 vscode python

Targets:
  cpp17, cpp20, cpp23, c++17, c++20, c++23
  dotnet10, dotnet11-preview
  python, python3.13, uv
  rust
  go
  all

Environment:
  PROJECT_DIR=C:\path      Main project root when this repo is used as a submodule.
  AIO_DRY_RUN=1            Print install commands without running them.
  AIO_FORCE=1              Overwrite generated .vscode files.
"@
}

function Show-Targets {
@"
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
"@
}

function Normalize-Target {
    param([string]$Raw)

    $t = $Raw.ToLowerInvariant().Replace(" ", "").Replace("_", "-")
    switch -Regex ($t) {
        "^(c\+\+17|cpp17|cxx17)$" { return "cpp17" }
        "^(c\+\+20|cpp20|cxx20)$" { return "cpp20" }
        "^(c\+\+23|cpp23|cxx23)$" { return "cpp23" }
        "^(dotnet10|net10|csharp10|c#10)$" { return "dotnet10" }
        "^(dotnet11|net11|dotnet11-preview|dotnet11preview|net11-preview|net11preview|csharp11-preview|csharp11preview|c#11-preview|c#11preview)$" { return "dotnet11-preview" }
        "^(python|py|uv)$" { return "python" }
        "^(rust|rs)$" { return "rust" }
        "^(go|golang)$" { return "go" }
        "^all$" { return "all" }
        "^python([0-9]+(\.[0-9]+)?)$" { return "python:$($Matches[1])" }
        "^py([0-9]+(\.[0-9]+)?)$" { return "python:$($Matches[1])" }
        default { Throw-Aio "Unknown target: $Raw" }
    }
}

function Expand-Targets {
    param([string[]]$RawTargets)

    $expanded = @()
    foreach ($raw in $RawTargets) {
        $target = Normalize-Target $raw
        if ($target -eq "all") {
            $expanded += @("cpp23", "dotnet10", "python", "rust", "go")
        } else {
            $expanded += $target
        }
    }
    return $expanded
}

function Parse-Rest {
    $i = 0
    while ($i -lt $Rest.Count) {
        $item = $Rest[$i]
        if ($item -eq "--project") {
            if ($i + 1 -ge $Rest.Count) { Throw-Aio "--project requires a value." }
            $Script:ProjectDir = $Rest[$i + 1]
            $i += 2
        } elseif ($item.StartsWith("--project=")) {
            $Script:ProjectDir = $item.Substring("--project=".Length)
            $i += 1
        } elseif ($item -eq "--dry-run") {
            $Script:DryRun = $true
            $i += 1
        } elseif ($item -eq "--help" -or $item -eq "-h") {
            $Script:Command = "help"
            $i += 1
        } else {
            $Script:Targets += $item
            $i += 1
        }
    }

    if (Test-Path -LiteralPath $Script:ProjectDir -PathType Container) {
        $Script:ProjectDir = (Resolve-Path -LiteralPath $Script:ProjectDir).Path
    }
}

function Ensure-ProjectDir {
    if (-not (Test-Path -LiteralPath $Script:ProjectDir -PathType Container)) {
        if ($Script:DryRun) {
            Write-Host "+ New-Item -ItemType Directory -Force $Script:ProjectDir"
        } else {
            New-Item -ItemType Directory -Force -Path $Script:ProjectDir | Out-Null
        }
    }
}

function Find-MsvcInstall {
    $roots = @(${env:ProgramFiles(x86)}, $env:ProgramFiles) | Where-Object { $_ }
    foreach ($root in $roots) {
        $vswhere = Join-Path $root "Microsoft Visual Studio\Installer\vswhere.exe"
        if (-not (Test-Path -LiteralPath $vswhere)) { continue }

        $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2>$null
        if ($LASTEXITCODE -eq 0 -and $path) { return $path.Trim() }
    }
    return $null
}

function Get-CppCompiler {
    foreach ($name in @("cl.exe", "clang++.exe", "g++.exe")) {
        $cmd = Get-Command $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }

    $msvc = Find-MsvcInstall
    if ($msvc) { return "MSVC installed at $msvc" }
    return $null
}

function Get-CppStandardNumber {
    param([string]$Target)
    switch ($Target) {
        "cpp17" { return 17 }
        "cpp20" { return 20 }
        "cpp23" { return 23 }
        default { Throw-Aio "Not a C++ target: $Target" }
    }
}

function Get-CppThreshold {
    param([int]$Standard)
    switch ($Standard) {
        17 { return "201703L" }
        20 { return "202002L" }
        23 { return "202100L" }
        default { Throw-Aio "Unsupported C++ standard: $Standard" }
    }
}

function Test-CppStandard {
    param([int]$Standard)

    $compiler = Get-CppCompiler
    if (-not $compiler) { return $false }
    if ($compiler.StartsWith("MSVC installed at ")) {
        Write-AioLog "$compiler; run cl.exe compile checks from Developer PowerShell."
        return $true
    }

    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("aio-cpp-" + [Guid]::NewGuid().ToString("N"))
    New-Item -ItemType Directory -Force -Path $tmp | Out-Null
    $src = Join-Path $tmp "main.cpp"
    $threshold = Get-CppThreshold $Standard
    @"
#ifndef __cplusplus
#error "not compiling as C++"
#endif
#if __cplusplus < $threshold
#error "compiler does not report the requested standard"
#endif
int main() { return 0; }
"@ | Set-Content -LiteralPath $src -Encoding ASCII

    try {
        $leaf = (Split-Path -Leaf $compiler).ToLowerInvariant()
        if ($leaf -eq "cl.exe") {
            $flag = if ($Standard -eq 23) { "/std:c++latest" } else { "/std:c++$Standard" }
            & $compiler /nologo /EHsc /Zc:__cplusplus $flag $src "/Fe:$(Join-Path $tmp 'main.exe')" *> $null
            return $LASTEXITCODE -eq 0
        }

        $flags = if ($Standard -eq 23) { @("-std=c++23", "-std=c++2b") } else { @("-std=c++$Standard") }
        foreach ($flag in $flags) {
            & $compiler $flag $src -o (Join-Path $tmp "a.exe") *> $null
            if ($LASTEXITCODE -eq 0) { return $true }
        }
        return $false
    } finally {
        Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Install-Cpp {
    param([string]$Target)

    $standard = Get-CppStandardNumber $Target
    if ((Test-CppStandard $standard) -and (Test-Command "cmake")) {
        Write-AioLog "C++$standard environment already exists."
        if (-not (Test-Command "ninja")) { Write-AioWarn "ninja was not found. Use the default CMake generator or install ninja separately." }
        return
    }

    Write-AioLog "Installing or completing the C++$standard environment."
    if (Test-Command "winget") {
        Invoke-AioCommand "winget" @("install", "--id", "Microsoft.VisualStudio.2022.BuildTools", "-e", "--accept-package-agreements", "--accept-source-agreements", "--override", "--wait --quiet --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended")
        Invoke-AioCommand "winget" @("install", "--id", "Kitware.CMake", "-e", "--accept-package-agreements", "--accept-source-agreements")
        Invoke-AioCommand "winget" @("install", "--id", "Ninja-build.Ninja", "-e", "--accept-package-agreements", "--accept-source-agreements")
        Invoke-AioCommand "winget" @("install", "--id", "LLVM.LLVM", "-e", "--accept-package-agreements", "--accept-source-agreements")
    } else {
        Write-AioWarn "winget was not found. Install Visual Studio Build Tools C++ workload, CMake, and Ninja manually."
    }
    Verify-Cpp $Target
}

function Verify-Cpp {
    param([string]$Target)

    $standard = Get-CppStandardNumber $Target
    $compiler = Get-CppCompiler
    if ($compiler) {
        Write-AioLog "C++ compiler: $compiler"
    } else {
        Write-AioWarn "C++ compiler was not found."
    }

    if (Test-CppStandard $standard) {
        Write-AioLog "C++$standard compile/install check: OK"
    } else {
        Write-AioWarn "C++$standard compile check: FAILED"
    }

    if (Test-Command "cmake") { & cmake --version | Select-Object -First 1 } else { Write-AioWarn "cmake was not found." }
    if (Test-Command "ninja") { Write-AioLog "ninja: $(& ninja --version)" } else { Write-AioWarn "ninja was not found." }
}

function Get-DotnetMajor {
    param([string]$Target)
    switch ($Target) {
        "dotnet10" { return 10 }
        "dotnet11-preview" { return 11 }
        default { Throw-Aio "Not a .NET target: $Target" }
    }
}

function Get-DotnetQuality {
    param([string]$Target)
    switch ($Target) {
        "dotnet10" { return "GA" }
        "dotnet11-preview" { return "preview" }
        default { Throw-Aio "Not a .NET target: $Target" }
    }
}

function Test-DotnetSdk {
    param([int]$Major)
    if (-not (Test-Command "dotnet")) { return $false }
    $sdks = & dotnet --list-sdks 2>$null
    return $sdks -match "^$Major\."
}

function Add-DotnetPath {
    if (-not $env:DOTNET_ROOT) { $env:DOTNET_ROOT = Join-Path $HOME ".dotnet" }
    $env:PATH = "$env:DOTNET_ROOT;$env:PATH"
}

function Install-Dotnet {
    param([string]$Target)

    Add-DotnetPath
    $major = Get-DotnetMajor $Target
    $quality = Get-DotnetQuality $Target
    $channel = "$major.0"

    if (Test-DotnetSdk $major) {
        Write-AioLog ".NET SDK $major.x already exists."
        Verify-Dotnet $Target
        return
    }

    Write-AioLog "Installing .NET SDK channel=$channel quality=$quality."
    $installer = Join-Path ([System.IO.Path]::GetTempPath()) ("dotnet-install-" + [Guid]::NewGuid().ToString("N") + ".ps1")
    if ($Script:DryRun) {
        Write-Host "+ Invoke-WebRequest https://dot.net/v1/dotnet-install.ps1 -OutFile $installer"
    } else {
        Invoke-WebRequest -Uri "https://dot.net/v1/dotnet-install.ps1" -OutFile $installer
    }

    Invoke-AioCommand "powershell" @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $installer, "-Channel", $channel, "-Quality", $quality, "-InstallDir", $env:DOTNET_ROOT)
    Write-AioLog "Added DOTNET_ROOT=$env:DOTNET_ROOT to PATH for this process."
    Verify-Dotnet $Target
}

function Verify-Dotnet {
    param([string]$Target)

    Add-DotnetPath
    $major = Get-DotnetMajor $Target
    if (Test-Command "dotnet") {
        & dotnet --info | Select-Object -First 12
        if (Test-DotnetSdk $major) {
            Write-AioLog ".NET SDK $major.x check: OK"
        } else {
            Write-AioWarn ".NET SDK $major.x was not found."
        }
    } else {
        Write-AioWarn "dotnet CLI was not found."
    }
}

function Get-PythonVersion {
    param([string]$Target)
    if ($Target.StartsWith("python:")) { return $Target.Substring("python:".Length) }

    $pythonVersionFile = Join-Path $Script:ProjectDir ".python-version"
    if (Test-Path -LiteralPath $pythonVersionFile -PathType Leaf) {
        return (Get-Content -LiteralPath $pythonVersionFile -TotalCount 1).Trim()
    }
    return ""
}

function Add-UvPath {
    $env:PATH = "$(Join-Path $HOME '.local\bin');$(Join-Path $HOME '.cargo\bin');$env:PATH"
}

function Ensure-Uv {
    Add-UvPath
    if (Test-Command "uv") {
        Write-AioLog "uv already exists: $(& uv --version)"
        return
    }

    Write-AioLog "Installing uv."
    Invoke-AioShell 'powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"'
    Add-UvPath
}

function Install-Python {
    param([string]$Target)

    Ensure-ProjectDir
    Ensure-Uv
    $version = Get-PythonVersion $Target

    if ($version) {
        Write-AioLog "Ensuring uv managed Python $version."
        Invoke-AioCommand "uv" @("python", "install", $version)
    }

    $venvPath = Join-Path $Script:ProjectDir ".venv"
    if (Test-Path -LiteralPath $venvPath -PathType Container) {
        Write-AioLog "$venvPath already exists; not creating a new venv."
    } else {
        Push-Location $Script:ProjectDir
        try {
            if ($version) {
                Invoke-AioCommand "uv" @("venv", "--python", $version)
            } else {
                Invoke-AioCommand "uv" @("venv")
            }
        } finally {
            Pop-Location
        }
    }

    $pyproject = Join-Path $Script:ProjectDir "pyproject.toml"
    $requirements = Join-Path $Script:ProjectDir "requirements.txt"
    if (Test-Path -LiteralPath $pyproject -PathType Leaf) {
        Push-Location $Script:ProjectDir
        try { Invoke-AioCommand "uv" @("sync") } finally { Pop-Location }
    } elseif (Test-Path -LiteralPath $requirements -PathType Leaf) {
        Push-Location $Script:ProjectDir
        try { Invoke-AioCommand "uv" @("pip", "install", "-r", "requirements.txt") } finally { Pop-Location }
    } else {
        Write-AioLog "No pyproject.toml or requirements.txt found; skipping dependency sync."
    }

    Verify-Python $Target
}

function Verify-Python {
    param([string]$Target)

    Ensure-ProjectDir
    Add-UvPath
    if (Test-Command "uv") {
        & uv --version
        $venvPath = Join-Path $Script:ProjectDir ".venv"
        if (Test-Path -LiteralPath $venvPath -PathType Container) {
            Write-AioLog "Python venv: $venvPath"
            Push-Location $Script:ProjectDir
            try { & uv run python --version } finally { Pop-Location }
        } else {
            Write-AioWarn "$venvPath was not found."
        }
    } else {
        Write-AioWarn "uv was not found."
    }
}

function Install-Rust {
    Add-UvPath
    $env:PATH = "$(Join-Path $HOME '.cargo\bin');$env:PATH"
    if (Test-Command "rustup") {
        Write-AioLog "rustup already exists."
    } elseif (Test-Command "cargo") {
        Write-AioLog "cargo already exists; skipping rustup-based management."
        Verify-Rust
        return
    } else {
        Write-AioLog "Installing Rust stable toolchain with rustup."
        $arch = if ($env:PROCESSOR_ARCHITECTURE -match "ARM64") { "aarch64" } else { "x86_64" }
        $installer = Join-Path ([System.IO.Path]::GetTempPath()) "rustup-init.exe"
        $url = "https://win.rustup.rs/$arch"
        if ($Script:DryRun) {
            Write-Host "+ Invoke-WebRequest $url -OutFile $installer"
        } else {
            Invoke-WebRequest -Uri $url -OutFile $installer
        }
        Invoke-AioCommand $installer @("-y")
    }

    Invoke-AioCommand "rustup" @("toolchain", "install", "stable")
    Invoke-AioCommand "rustup" @("default", "stable")
    Invoke-AioCommand "rustup" @("component", "add", "rustfmt", "clippy")
    if (-not (Find-MsvcInstall)) {
        Write-AioWarn "The Windows MSVC Rust target may require Visual Studio C++ Build Tools. Also run the cpp23 install target."
    }
    Verify-Rust
}

function Verify-Rust {
    $env:PATH = "$(Join-Path $HOME '.cargo\bin');$env:PATH"
    if (Test-Command "rustc") { & rustc --version } else { Write-AioWarn "rustc was not found." }
    if (Test-Command "cargo") { & cargo --version } else { Write-AioWarn "cargo was not found." }
    if (Test-Command "rustup") { & rustup show active-toolchain }
}

function Install-Go {
    if (Test-Command "go") {
        Write-AioLog "Go already exists."
        Verify-Go
        return
    }

    Write-AioLog "Installing Go."
    if (Test-Command "winget") {
        Invoke-AioCommand "winget" @("install", "--id", "GoLang.Go", "-e", "--accept-package-agreements", "--accept-source-agreements")
    } else {
        Write-AioWarn "winget was not found. Use the Go installer from https://go.dev/dl."
    }
    Verify-Go
}

function Verify-Go {
    if (Test-Command "go") { & go version } else { Write-AioWarn "go CLI was not found." }
}

function Write-FileIfMissing {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $actual = $Path
    if ((Test-Path -LiteralPath $Path -PathType Leaf) -and $env:AIO_FORCE -ne "1") {
        $dir = Split-Path -Parent $Path
        $base = Split-Path -Leaf $Path
        $actual = Join-Path $dir "aio-env.$base"
        Write-AioWarn "$Path already exists; not overwriting it. Writing $actual instead."
    }

    if ($Script:DryRun) {
        Write-Host "+ Set-Content $actual"
    } else {
        Set-Content -LiteralPath $actual -Value $Content -Encoding UTF8
    }
    Write-AioLog "wrote $actual"
}

function Get-TasksJson {
@'
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
'@
}

function Get-LaunchJson {
@'
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
'@
}

function Get-ExtensionsJson {
@'
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
'@
}

function Get-SettingsJson {
@'
{
  "cmake.configureOnOpen": false,
  "python.terminal.activateEnvironment": true,
  "python.analysis.typeCheckingMode": "basic",
  "rust-analyzer.check.command": "clippy",
  "go.toolsManagement.autoUpdate": true
}
'@
}

function Setup-Vscode {
    Ensure-ProjectDir
    $vscode = Join-Path $Script:ProjectDir ".vscode"
    if ($Script:DryRun) {
        Write-Host "+ New-Item -ItemType Directory -Force $vscode"
    } else {
        New-Item -ItemType Directory -Force -Path $vscode | Out-Null
    }

    Write-FileIfMissing (Join-Path $vscode "tasks.json") (Get-TasksJson)
    Write-FileIfMissing (Join-Path $vscode "launch.json") (Get-LaunchJson)
    Write-FileIfMissing (Join-Path $vscode "extensions.json") (Get-ExtensionsJson)
    Write-FileIfMissing (Join-Path $vscode "settings.json") (Get-SettingsJson)
}

function Invoke-Harness {
    $script = Join-Path $Script:RepoRoot "harness\smoke.ps1"
    Invoke-AioCommand "powershell" @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $script)
}

function Install-Target {
    param([string]$Target)
    switch -Regex ($Target) {
        "^cpp(17|20|23)$" { Install-Cpp $Target; return }
        "^dotnet(10|11-preview)$" { Install-Dotnet $Target; return }
        "^python(:.*)?$" { Install-Python $Target; return }
        "^rust$" { Install-Rust; return }
        "^go$" { Install-Go; return }
        default { Throw-Aio "Unsupported target: $Target" }
    }
}

function Verify-Target {
    param([string]$Target)
    switch -Regex ($Target) {
        "^cpp(17|20|23)$" { Verify-Cpp $Target; return }
        "^dotnet(10|11-preview)$" { Verify-Dotnet $Target; return }
        "^python(:.*)?$" { Verify-Python $Target; return }
        "^rust$" { Verify-Rust; return }
        "^go$" { Verify-Go; return }
        default { Throw-Aio "Unsupported target: $Target" }
    }
}

$Script:Command = $Command
Parse-Rest

switch ($Script:Command) {
    "help" { Show-Usage }
    "list" { Show-Targets }
    "targets" { Show-Targets }
    "install" {
        if ($Script:Targets.Count -eq 0) { Throw-Aio "install requires a target, for example: make install cpp23" }
        foreach ($target in (Expand-Targets $Script:Targets)) { Install-Target $target }
    }
    "verify" {
        if ($Script:Targets.Count -eq 0) { $Script:Targets = @("all") }
        foreach ($target in (Expand-Targets $Script:Targets)) { Verify-Target $target }
    }
    "vscode" { Setup-Vscode }
    "harness" { Invoke-Harness }
    default { Throw-Aio "Unknown command: $Script:Command" }
}
