#!/usr/bin/env bash
# Phase 0.6: freestanding host owns loop; links library init/frame/shutdown.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT/lib_desktop"
OUT="$ROOT/host"

echo "Compiling jg_engine_init / jg_frame / jg_engine_shutdown..."
(cd "$ROOT" && julia --project=. -e '
using StaticCompiler
include("library.jl")
isdir("lib_desktop") || mkdir("lib_desktop")
StaticCompiler.generate_obj(jg_engine_init, (), "lib_desktop", "jg_engine_init", emit_llvm_only=false)
StaticCompiler.generate_obj(jg_frame, (), "lib_desktop", "jg_frame", emit_llvm_only=false)
StaticCompiler.generate_obj(jg_engine_shutdown, (), "lib_desktop", "jg_engine_shutdown", emit_llvm_only=false)
println("ok")
')

SDL_CFLAGS="$(pkg-config --cflags sdl2)"
SDL_LIBS="$(pkg-config --libs sdl2)"

# shellcheck disable=SC2086
gcc -O2 -Wall -Wextra $SDL_CFLAGS -I"$ROOT" \
  -o "$OUT" \
  "$ROOT/host.c" \
  "$LIB_DIR/jg_engine_init.o" \
  "$LIB_DIR/jg_frame.o" \
  "$LIB_DIR/jg_engine_shutdown.o" \
  "$ROOT/jg_sdl_globals.c" \
  $SDL_LIBS

echo "Built: $OUT (no julia binary required)"
"$OUT"
echo "OK Phase 0.6: host owns loop over lib API"
