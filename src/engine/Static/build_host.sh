#!/usr/bin/env bash
# Build / verify libsc_game.so (Julia StaticCompiler output, no SDL).
# Produces: lib_desktop/libsc_game.so, lib_desktop/libsc_game.a, lib_desktop/sc_game.h
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT/lib_desktop"
LIB_SO="$LIB_DIR/libsc_game.so"
LIB_A="$LIB_DIR/libsc_game.a"
HEADER="$LIB_DIR/sc_game.h"

if [[ "${REBUILD:-0}" == "1" || ! -f "$LIB_SO" ]]; then
    echo "🔨 Compiling Julia static library (desktop)..."
    (cd "$ROOT" && julia --project=. compile_library.jl desktop)
fi

if [[ ! -f "$LIB_SO" ]]; then
    echo "❌ Missing $LIB_SO"
    echo "   Run: (cd $ROOT && julia --project=. compile_library.jl desktop)"
    echo "   Needs Julia 1.11 + Project.toml StaticCompiler (not global 0.7.2 on 1.11)."
    exit 1
fi

if [[ ! -f "$LIB_A" ]]; then
    echo "⚠️  Missing $LIB_A (shared .so exists)"
fi

if ! nm -D "$LIB_SO" 2>/dev/null | grep -qE '[[:space:]]T[[:space:]]+_?static_is_mouse_inside_element$'; then
    if ! nm "$LIB_SO" 2>/dev/null | grep -qE '[[:space:]]T[[:space:]]+_?static_is_mouse_inside_element$'; then
        echo "❌ $LIB_SO is missing static_is_mouse_inside_element"
        echo "   Rebuild: REBUILD=1 $0"
        exit 1
    fi
fi

if [[ -f "$HEADER" ]]; then
    echo "✅ Header: $HEADER"
fi

echo "✅ Built: $LIB_SO (no SDL)"
ls -lh "$LIB_SO"
if command -v ldd >/dev/null 2>&1; then
    if ldd "$LIB_SO" 2>/dev/null | grep -qi sdl; then
        echo "⚠️  unexpected SDL dependency:"
        ldd "$LIB_SO" | grep -i sdl || true
        exit 1
    fi
    echo "   dynamic deps:"
    ldd "$LIB_SO" 2>/dev/null | sed 's/^/      /' || true
fi

# --- SDL host executable (disabled) ---
# When you need a test binary again, restore host.c + sc_run and uncomment below.
#
# source "$ROOT/deps/sdl2_paths.sh"
# ... vendored SDL2 / SDL2_image / SDL2_mixer ...
# gcc ... -o "$ROOT/host" "$ROOT/host.c" -I"$LIB_DIR" "$LIB_A" ... SDL libs ...
#
# Called from Julia via ccall((:static_is_mouse_inside_element, path_to_libsc_game.so), ...)
