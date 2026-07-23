#!/usr/bin/env bash
# Phase 0.3: compile jg_engine_init and link smoke (window should briefly appear).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT/lib_desktop"
OUT="$ROOT/smoke_engine_init"

echo "Compiling jg_engine_init (StaticCompiler)..."
(cd "$ROOT" && julia --project=. -e '
using StaticCompiler
include("library.jl")
isdir("lib_desktop") || mkdir("lib_desktop")
StaticCompiler.generate_obj(jg_engine_init, (), "lib_desktop", "jg_engine_init", emit_llvm_only=false)
println("ok")
')

SDL_CFLAGS="$(pkg-config --cflags sdl2)"
SDL_LIBS="$(pkg-config --libs sdl2)"

# shellcheck disable=SC2086
gcc -O2 -Wall -Wextra $SDL_CFLAGS -I"$ROOT" \
  -o "$OUT" \
  "$ROOT/smoke_engine_init.c" \
  "$LIB_DIR/jg_engine_init.o" \
  "$ROOT/jg_sdl_globals.c" \
  $SDL_LIBS

echo "Built: $OUT"
"$OUT"
