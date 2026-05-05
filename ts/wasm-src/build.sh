#!/usr/bin/env bash
# Requires Emscripten on PATH (emsdk: `source emsdk_env.sh`).
set -euo pipefail
cd "$(dirname "$0")"
OUT_DIR="../src/platform/sdl-wasm"
mkdir -p "$OUT_DIR"
emcc main.c -o "$OUT_DIR/julgame.js" \
  -s USE_SDL=2 \
  -s WASM=1 \
  -s MODULARIZE=1 \
  -s EXPORT_ES6=1 \
  -s INVOKE_RUN=0 \
  -s EXPORTED_FUNCTIONS="['_main','_glue_init','_glue_render_square_frame','_glue_poll_quit']" \
  -s EXPORTED_RUNTIME_METHODS="['cwrap']" \
  -O2
