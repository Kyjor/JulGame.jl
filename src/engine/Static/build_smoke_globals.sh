#!/usr/bin/env bash
# Phase 0.1: compile + link C SDL globals smoke test (no Julia, no SDL).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUT="$ROOT/smoke_globals"

gcc -O2 -Wall -Wextra -I"$ROOT" \
  -o "$OUT" \
  "$ROOT/smoke_globals.c" \
  "$ROOT/jg_sdl_globals.c"

echo "Built: $OUT"
"$OUT"
