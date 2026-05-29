#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_A="$ROOT/lib_desktop/libsc_game.a"
# shellcheck source=deps/sdl2_paths.sh
source "$ROOT/deps/sdl2_paths.sh"

if [[ ! -f "$LIB_A" ]]; then
    echo "❌ Missing $LIB_A — run: julia compile_library.jl desktop"
    exit 1
fi

# Linux (GNU nm): " T sc_run" — macOS (Mach-O): " T _sc_run"
if ! nm "$LIB_A" 2>/dev/null | grep -qE '[[:space:]]T[[:space:]]+_?sc_run$'; then
    echo "❌ $LIB_A has no compiled Julia symbols (sc_run missing from nm)"
    echo "   Run: julia compile_library.jl desktop"
    echo "   If the archive is up to date and this persists: StaticCompiler may need Julia ≤1.10 — see README.md"
    exit 1
fi

if [[ -z "$SDL2_LIBDIR" || ! -f "$SDL2_LIBDIR/libSDL2.a" ]]; then
    echo "ℹ️  Vendored SDL2 not built — running deps/build_sdl2.sh"
    "$ROOT/deps/build_sdl2.sh"
    source "$ROOT/deps/sdl2_paths.sh"
fi

if [[ -z "$SDL2_IMAGE_LIBDIR" || ! -f "$SDL2_IMAGE_LIBDIR/libSDL2_image.a" ]]; then
    echo "ℹ️  Vendored SDL2_image not built — running deps/build_sdl2_image.sh"
    "$ROOT/deps/build_sdl2_image.sh"
    source "$ROOT/deps/sdl2_paths.sh"
fi

if [[ -z "$SDL2_MIXER_LIBDIR" || ! -f "$SDL2_MIXER_LIBDIR/libSDL2_mixer.a" ]]; then
    echo "ℹ️  Vendored SDL2_mixer not built — running deps/build_sdl2_mixer.sh"
    "$ROOT/deps/build_sdl2_mixer.sh"
    source "$ROOT/deps/sdl2_paths.sh"
fi

SDL2_CONFIG="$SDL2_PREFIX/bin/sdl2-config"
read -r -a SDL_CFLAGS <<< "$("$SDL2_CONFIG" --cflags)"
# Full static SDL line from sdl2-config (Linux: transitive -l…; macOS: -framework… + libSDL2.a).
read -r -a SDL_STATIC_LIBS <<< "$("$SDL2_CONFIG" --static-libs)"

SDL2_IMAGE_STATIC_LIBS=()
if [[ -n "${SDL2_IMAGE_PKGCONFIG:-}" && -f "$SDL2_IMAGE_PKGCONFIG/SDL2_image.pc" ]] \
    && command -v pkg-config >/dev/null 2>&1; then
    PKG_CONFIG_PATH="${SDL2_IMAGE_PKGCONFIG}:${SDL2_PKGCONFIG:-}${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export PKG_CONFIG_PATH
    read -r -a SDL2_IMAGE_STATIC_LIBS <<< "$(pkg-config --static --libs SDL2_image)"
else
    SDL2_IMAGE_STATIC_LIBS=("$SDL2_IMAGE_LIBDIR/libSDL2_image.a")
fi

SDL2_MIXER_STATIC_LIBS=()
if [[ -n "${SDL2_MIXER_PKGCONFIG:-}" && -f "$SDL2_MIXER_PKGCONFIG/SDL2_mixer.pc" ]] \
    && command -v pkg-config >/dev/null 2>&1; then
    PKG_CONFIG_PATH="${SDL2_MIXER_PKGCONFIG}:${SDL2_IMAGE_PKGCONFIG:-}:${SDL2_PKGCONFIG:-}${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
    export PKG_CONFIG_PATH
    read -r -a SDL2_MIXER_STATIC_LIBS <<< "$(pkg-config --static --libs SDL2_mixer)"
else
    SDL2_MIXER_STATIC_LIBS=("$SDL2_MIXER_LIBDIR/libSDL2_mixer.a")
fi

LINK_FLAGS=()
if [[ "${STATIC:-0}" == "1" ]]; then
    if [[ ! -f /usr/lib64/libc.a && ! -f /usr/lib/x86_64-linux-gnu/libc.a ]]; then
        echo "❌ STATIC=1 needs glibc-static"
        echo "   Fedora: sudo dnf install glibc-static"
        echo "   Debian: sudo apt install libc6-dev"
        exit 1
    fi
    LINK_FLAGS=(-static)
    echo "🔨 Fully static link (no glibc version lock on target) ..."
else
    echo "🔨 Linking host with static SDL2 + SDL2_image + SDL2_mixer ..."
fi

# bash 3.2 + set -u: empty "${arr[@]}" errors; bash 4.4+ allows it. ${arr[@]+…} is portable.
gcc "${LINK_FLAGS[@]+"${LINK_FLAGS[@]}"}" -o "$ROOT/host" "$ROOT/host.c" -I"$ROOT/lib_desktop" "${SDL_CFLAGS[@]+"${SDL_CFLAGS[@]}"}" \
    "$LIB_A" \
    "${SDL2_MIXER_STATIC_LIBS[@]+"${SDL2_MIXER_STATIC_LIBS[@]}"}" \
    "${SDL2_IMAGE_STATIC_LIBS[@]+"${SDL2_IMAGE_STATIC_LIBS[@]}"}" \
    "${SDL_STATIC_LIBS[@]+"${SDL_STATIC_LIBS[@]}"}" \
    -pthread -lm -ldl

if ldd "$ROOT/host" 2>/dev/null | grep -q libSDL; then
    echo "⚠️  host still links libSDL dynamically"
    ldd "$ROOT/host" | grep SDL
    exit 1
fi

echo "✅ Built: $ROOT/host (SDL2 + SDL2_image + SDL2_mixer static, no SDL3)"
ls -lh "$ROOT/host"
if [[ "${STATIC:-0}" == "1" ]]; then
    echo "   fully static — should run on older Linux VMs"
    ldd "$ROOT/host" 2>&1 || echo "   (static binary — not a dynamic executable)"
else
    ldd "$ROOT/host" 2>/dev/null || true
    # GNU grep -oP only; glibc symbol scan is Linux ELF anyway.
    if [[ "$(uname -s)" == Linux ]]; then
        max_glibc="$(objdump -T "$ROOT/host" 2>/dev/null | grep -oP 'GLIBC_[0-9.]+' | sort -V | tail -1 || true)"
        if [[ -n "$max_glibc" ]]; then
            echo "   requires $max_glibc on target (built on this machine's glibc)"
            echo "   older VMs: build on target, or: STATIC=1 ./build_host.sh (needs glibc-static)"
        fi
    fi
fi
