#include <stdio.h>
#include <stdint.h>
#include <SDL.h>
#include "jg_sdl_globals.h"

int32_t jg_engine_init(void);

/* Phase 0.3: window + renderer created; handles stored in C globals. */
int main(void)
{
    if (jg_engine_init() != 0) {
        fprintf(stderr, "FAIL: jg_engine_init\n");
        return 1;
    }

    uint64_t win = jg_get_window();
    uint64_t ren = jg_get_renderer();
    if (win == 0 || ren == 0) {
        fprintf(stderr, "FAIL: window=%llu renderer=%llu\n",
                (unsigned long long)win, (unsigned long long)ren);
        return 1;
    }

    SDL_Renderer *renderer = (SDL_Renderer *)(uintptr_t)ren;
    /* Clear to a visible color + present, then hold so the window is obvious. */
    SDL_SetRenderDrawColor(renderer, 40, 120, 200, 255);
    SDL_RenderClear(renderer);
    SDL_RenderPresent(renderer);
    printf("Window up — holding 3s...\n");
    fflush(stdout);
    SDL_Delay(3000);

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow((SDL_Window *)(uintptr_t)win);
    SDL_Quit();

    printf("OK Phase 0.3: jg_engine_init window+renderer\n");
    return 0;
}
