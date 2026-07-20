#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="${TMPDIR:-/tmp}/aio-env-smoke-$$"
mkdir -p "$TMP/project"
trap 'rm -rf "$TMP"' EXIT

bash "$ROOT/scripts/aio-env.sh" list >/dev/null
bash "$ROOT/scripts/aio-env.sh" vscode all --project "$TMP/project"

export AIO_DRY_RUN=1

for target in cpp17 cpp20 cpp23 dotnet10 dotnet11-preview python python3.13 rust go; do
  bash "$ROOT/scripts/aio-env.sh" install "$target" --project "$TMP/project" >/dev/null 2>&1
done

printf '[aio-env] smoke harness OK\n'
