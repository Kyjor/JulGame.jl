#include <stdio.h>
#include <SDL.h>
#include "jg_static.h"

/* Demo/smoke host — owns the loop. Library only exposes init/frame/shutdown. */
int main(void)
{
    if (jg_engine_init() != 0) {
        fprintf(stderr, "jg_engine_init failed\n");
        return 1;
    }

    /* Timed exit for automated smoke; window-close also stops via jg_frame. */
    const Uint32 start = SDL_GetTicks();
    while (jg_frame() != 0) {
        if (SDL_GetTicks() - start >= 3000)
            break;
    }

    jg_engine_shutdown();
    return 0;
}
