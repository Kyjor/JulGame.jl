#!/usr/bin/env bash
# Requires Emscripten on PATH (emsdk: `source emsdk_env.sh`).
set -euo pipefail
cd "$(dirname "$0")"
OUT_DIR="../src/platform/sdl-wasm"
mkdir -p "$OUT_DIR"
FUNCS='["_main","_glue_init","_glue_render_square_frame","_glue_poll_quit","_glue_SDL_GetTicks","_glue_get_renderer","_glue_SDL_RenderClear","_glue_SDL_RenderPresent","_glue_SDL_RenderSetLogicalSize","_glue_SDL_SetRenderDrawBlendMode_BLEND","_glue_SDL_SetRenderDrawColor","_glue_SDL_GetRenderDrawColor_packed","_glue_SDL_RenderFillRectF","_glue_IMG_Load","_glue_wasm_alloc_copy","_glue_SDL_RWFromConstMem","_glue_IMG_Load_RW","_glue_SDL_CreateTextureFromSurface","_glue_SDL_FreeSurface","_glue_SDL_DestroyTexture","_glue_SDL_GetError","_glue_SDL_ClearError","_glue_surface_w","_glue_surface_h","_glue_SDL_SetTextureColorMod","_glue_SDL_SetTextureAlphaMod","_glue_SDL_GetTextureColorMod_packed","_glue_render_copy_ex","_glue_render_copy_ex_f","_glue_TTF_OpenFont","_glue_TTF_OpenFontRW","_glue_TTF_RenderUTF8_Blended","_glue_TTF_CloseFont","_glue_input_poll_event","_glue_input_event_type","_glue_input_event_button_x","_glue_input_event_button_y","_glue_input_event_button_button","_glue_input_event_window_event","_glue_input_get_mouse_x","_glue_input_get_mouse_y","_glue_input_get_keyboard_state","_glue_input_get_num_scancodes","_glue_input_key_down","_glue_SDL_Init_subsystem","_glue_SDL_NumJoysticks","_glue_Mix_OpenAudio","_glue_Mix_Quit","_glue_Mix_LoadWAV","_glue_Mix_LoadMUS","_glue_Mix_FreeChunk","_glue_Mix_FreeMusic","_glue_Mix_Volume","_glue_Mix_VolumeMusic","_glue_Mix_MasterVolume","_glue_Mix_PlayChannel","_glue_Mix_PlayMusic","_glue_Mix_PlayingMusic","_glue_Mix_PausedMusic","_glue_Mix_PauseMusic","_glue_Mix_ResumeMusic","_glue_Mix_HaltMusic","_glue_Mix_GetError"]'
# SINGLE_FILE: embed .wasm in .js so itch.io/CDN never does a separate wasm fetch (often 403).
emcc main.c -o "$OUT_DIR/julgame.js" \
  -s USE_SDL=2 \
  -s USE_SDL_IMAGE=2 \
  -s USE_SDL_MIXER=2 \
  -s USE_SDL_TTF=2 \
  -s SDL2_MIXER_FORMATS='["wav","mp3","ogg"]' \
  -s SDL2_IMAGE_FORMATS=png,jpg \
  -s USE_LIBPNG=1 \
  -s USE_ZLIB=1 \
  -s WASM=1 \
  -s SINGLE_FILE=1 \
  -s MODULARIZE=1 \
  -s EXPORT_ES6=1 \
  -s INVOKE_RUN=0 \
  -s FORCE_FILESYSTEM=1 \
  -s EXPORTED_FUNCTIONS="$FUNCS" \
  -s EXPORTED_RUNTIME_METHODS="['cwrap','FS','HEAPU8']" \
  -O2
