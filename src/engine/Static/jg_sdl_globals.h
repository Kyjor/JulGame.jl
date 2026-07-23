#ifndef JG_SDL_GLOBALS_H
#define JG_SDL_GLOBALS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Shared across separately compiled StaticCompiler .o files (sc-game pattern).
   Handles stored as uint64_t so wasm/native FFI stays consistent. */

void jg_set_window(uint64_t window);
uint64_t jg_get_window(void);

void jg_set_renderer(uint64_t renderer);
uint64_t jg_get_renderer(void);

int32_t jg_get_frames_rendered(void);
void jg_note_frame_rendered(void);

#ifdef __cplusplus
}
#endif

#endif /* JG_SDL_GLOBALS_H */
