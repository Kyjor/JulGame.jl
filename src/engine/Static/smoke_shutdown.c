#include <stdio.h>
#include <stdint.h>
#include <SDL.h>
#include "jg_sdl_globals.h"

int32_t jg_engine_init(void);
int32_t jg_frame(void);
int32_t jg_engine_shutdown(void);

/* Phase 0.5: init → a few frames → shutdown; globals cleared. */
int main(void)
{
    if (jg_engine_init() != 0) {
        fprintf(stderr, "FAIL: jg_engine_init\n");
        return 1;
    }

    for (int i = 0; i < 30; i++) {
        if (jg_frame() == 0) {
            fprintf(stderr, "FAIL: jg_frame\n");
            return 1;
        }
        SDL_Delay(16);
    }

    if (jg_engine_shutdown() != 0) {
        fprintf(stderr, "FAIL: jg_engine_shutdown\n");
        return 1;
    }

    if (jg_get_window() != 0 || jg_get_renderer() != 0) {
        fprintf(stderr, "FAIL: globals not cleared after shutdown\n");
        return 1;
    }

    printf("OK Phase 0.5: jg_engine_shutdown\n");
    return 0;
}
