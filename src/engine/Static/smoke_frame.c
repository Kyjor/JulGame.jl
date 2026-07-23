#include <stdio.h>
#include <stdint.h>
#include <SDL.h>
#include "jg_sdl_globals.h"

int32_t jg_engine_init(void);
int32_t jg_frame(void);

/* Phase 0.4: call jg_frame in a loop (~3s of blue clears). */
int main(void)
{
    if (jg_engine_init() != 0) {
        fprintf(stderr, "FAIL: jg_engine_init\n");
        return 1;
    }

    printf("Running jg_frame for ~3s...\n");
    fflush(stdout);

    const Uint32 start = SDL_GetTicks();
    int frames = 0;
    while (SDL_GetTicks() - start < 3000) {
        if (jg_frame() == 0) {
            fprintf(stderr, "FAIL: jg_frame returned 0\n");
            return 1;
        }
        frames += 1;
        SDL_Delay(16);
    }

    if (jg_get_frames_rendered() <= 0) {
        fprintf(stderr, "FAIL: frames_rendered=%d\n", jg_get_frames_rendered());
        return 1;
    }

    uint64_t win = jg_get_window();
    uint64_t ren = jg_get_renderer();
    SDL_DestroyRenderer((SDL_Renderer *)(uintptr_t)ren);
    SDL_DestroyWindow((SDL_Window *)(uintptr_t)win);
    SDL_Quit();

    printf("OK Phase 0.4: jg_frame clear+present (%d frames, counter=%d)\n",
           frames, jg_get_frames_rendered());
    return 0;
}
