#!/usr/bin/env bash
# Phase 0.2: compile j_sdl_init/j_sdl_quit and link smoke against SDL2.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT/lib_desktop"
OUT="$ROOT/smoke_sdl_init"

echo "Compiling j_sdl_init / j_sdl_quit (StaticCompiler)..."
(cd "$ROOT" && julia --project=. -e '
using StaticCompiler
include("library.jl")
isdir("lib_desktop") || mkdir("lib_desktop")
StaticCompiler.generate_obj(j_sdl_init, (), "lib_desktop", "j_sdl_init", emit_llvm_only=false)
StaticCompiler.generate_obj(j_sdl_quit, (), "lib_desktop", "j_sdl_quit", emit_llvm_only=false)
println("ok")
')

SDL_CFLAGS="$(pkg-config --cflags sdl2)"
SDL_LIBS="$(pkg-config --libs sdl2)"

# shellcheck disable=SC2086
gcc -O2 -Wall -Wextra $SDL_CFLAGS \
  -o "$OUT" \
  "$ROOT/smoke_sdl_init.c" \
  "$LIB_DIR/j_sdl_init.o" \
  "$LIB_DIR/j_sdl_quit.o" \
  $SDL_LIBS

echo "Built: $OUT"
"$OUT"
