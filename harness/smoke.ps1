$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSCommandPath)
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("aio-env-smoke-" + [Guid]::NewGuid().ToString("N"))
$project = Join-Path $tmp "project"
New-Item -ItemType Directory -Force -Path $project | Out-Null

$oldDryRun = $env:AIO_DRY_RUN
$env:AIO_DRY_RUN = "1"

try {
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\aio-env.ps1") list | Out-Null
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\aio-env.ps1") vscode all --project $project | Out-Null

    foreach ($target in @("cpp17", "cpp20", "cpp23", "dotnet10", "dotnet11-preview", "python", "python3.13", "rust", "go")) {
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root "scripts\aio-env.ps1") install $target --project $project | Out-Null
    }

    Write-Host "[aio-env] smoke harness OK"
} finally {
    if ($null -eq $oldDryRun) {
        Remove-Item Env:\AIO_DRY_RUN -ErrorAction SilentlyContinue
    } else {
        $env:AIO_DRY_RUN = $oldDryRun
    }
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
