#!/usr/bin/env bash
# Build / verify libjg_static shared lib (Julia StaticCompiler output, no SDL).
# Produces: lib_desktop/libjg_static.{dylib|so|dll}, lib_desktop/libjg_static.a, lib_desktop/jg_static.h
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="$ROOT/lib_desktop"
HEADER="$LIB_DIR/jg_static.h"
LIB_A="$LIB_DIR/libjg_static.a"

case "$(uname -s)" in
    Darwin) LIB_EXT="dylib" ;;
    MINGW*|MSYS*|CYGWIN*|Windows_NT) LIB_EXT="dll" ;;
    *) LIB_EXT="so" ;;
esac
LIB_SHARED="$LIB_DIR/libjg_static.$LIB_EXT"

if [[ "${REBUILD:-0}" == "1" || ! -f "$LIB_SHARED" ]]; then
    echo "🔨 Compiling Julia static library (desktop)..."
    (cd "$ROOT" && julia --project=. compile_library.jl desktop)
fi

if [[ ! -f "$LIB_SHARED" ]]; then
    echo "❌ Missing $LIB_SHARED"
    echo "   Run: (cd $ROOT && julia --project=. compile_library.jl desktop)"
    echo "   Needs Julia 1.11 + Project.toml StaticCompiler (not global 0.7.2 on 1.11)."
    exit 1
fi

if [[ ! -f "$LIB_A" ]]; then
    echo "⚠️  Missing $LIB_A (shared lib exists)"
fi

if ! nm -gU "$LIB_SHARED" 2>/dev/null | grep -qE '[[:space:]]T[[:space:]]+_?static_is_mouse_inside_element$'; then
    if ! nm -D "$LIB_SHARED" 2>/dev/null | grep -qE '[[:space:]]T[[:space:]]+_?static_is_mouse_inside_element$'; then
        if ! nm "$LIB_SHARED" 2>/dev/null | grep -qE '[[:space:]]T[[:space:]]+_?static_is_mouse_inside_element$'; then
            echo "❌ $LIB_SHARED is missing static_is_mouse_inside_element"
            echo "   Rebuild: REBUILD=1 $0"
            exit 1
        fi
    fi
fi

if [[ -f "$HEADER" ]]; then
    echo "✅ Header: $HEADER"
fi

echo "✅ Built: $LIB_SHARED (no SDL)"
ls -lh "$LIB_SHARED"
if [[ "$(uname -s)" == "Darwin" ]] && command -v otool >/dev/null 2>&1; then
    if otool -L "$LIB_SHARED" 2>/dev/null | grep -qi sdl; then
        echo "⚠️  unexpected SDL dependency:"
        otool -L "$LIB_SHARED" | grep -i sdl || true
        exit 1
    fi
    echo "   dynamic deps:"
    otool -L "$LIB_SHARED" 2>/dev/null | sed 's/^/      /' || true
elif command -v ldd >/dev/null 2>&1; then
    if ldd "$LIB_SHARED" 2>/dev/null | grep -qi sdl; then
        echo "⚠️  unexpected SDL dependency:"
        ldd "$LIB_SHARED" | grep -i sdl || true
        exit 1
    fi
    echo "   dynamic deps:"
    ldd "$LIB_SHARED" 2>/dev/null | sed 's/^/      /' || true
fi

# --- SDL host executable (disabled) ---
# When you need a test binary again, restore host.c + sc_run and uncomment below.
#
# source "$ROOT/deps/sdl2_paths.sh"
# ... vendored SDL2 / SDL2_image / SDL2_mixer ...
# gcc ... -o "$ROOT/host" "$ROOT/host.c" -I"$LIB_DIR" "$LIB_A" ... SDL libs ...
#
# Called from Julia via ccall((:static_is_mouse_inside_element, path_to_libjg_static), ...)
