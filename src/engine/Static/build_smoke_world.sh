#!/usr/bin/env bash
# Phase 1.1: World malloc/free (no SDL).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT/lib_desktop"
OUT="$ROOT/smoke_world"

echo "Compiling jg_world_create / jg_world_destroy..."
(cd "$ROOT" && julia --project=. -e '
using StaticCompiler
include("library.jl")
isdir("lib_desktop") || mkdir("lib_desktop")
StaticCompiler.generate_obj(jg_world_create, (), "lib_desktop", "jg_world_create", emit_llvm_only=false)
StaticCompiler.generate_obj(jg_world_destroy, (Ptr{Cvoid},), "lib_desktop", "jg_world_destroy", emit_llvm_only=false)
println("ok")
')

gcc -O2 -Wall -Wextra -I"$ROOT" \
  -o "$OUT" \
  "$ROOT/smoke_world.c" \
  "$LIB_DIR/jg_world_create.o" \
  "$LIB_DIR/jg_world_destroy.o"

echo "Built: $OUT"
"$OUT"
