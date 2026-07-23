#!/usr/bin/env bash
# Phase 1.2: Transform slab get/set_pos (no SDL).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT/lib_desktop"
OUT="$ROOT/smoke_transform"

echo "Compiling world + transform APIs..."
(cd "$ROOT" && julia --project=. -e '
using StaticCompiler
include("library.jl")
isdir("lib_desktop") || mkdir("lib_desktop")
StaticCompiler.generate_obj(jg_world_create, (), "lib_desktop", "jg_world_create", emit_llvm_only=false)
StaticCompiler.generate_obj(jg_world_destroy, (Ptr{Cvoid},), "lib_desktop", "jg_world_destroy", emit_llvm_only=false)
StaticCompiler.generate_obj(jg_transform_set_pos, (Ptr{Cvoid}, Int32, Int64, Int64), "lib_desktop", "jg_transform_set_pos", emit_llvm_only=false)
StaticCompiler.generate_obj(jg_transform_get_pos, (Ptr{Cvoid}, Int32, Ptr{Int64}, Ptr{Int64}), "lib_desktop", "jg_transform_get_pos", emit_llvm_only=false)
println("ok")
')

gcc -O2 -Wall -Wextra -I"$ROOT" \
  -o "$OUT" \
  "$ROOT/smoke_transform.c" \
  "$LIB_DIR/jg_world_create.o" \
  "$LIB_DIR/jg_world_destroy.o" \
  "$LIB_DIR/jg_transform_set_pos.o" \
  "$LIB_DIR/jg_transform_get_pos.o"

echo "Built: $OUT"
"$OUT"
