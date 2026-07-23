#include <stdio.h>
#include <stdint.h>
#include "jg_sdl_globals.h"

/* Phase 0.1 smoke: link globals module; set/get must round-trip. No SDL yet. */
int main(void)
{
    const uint64_t fake_window = 0x1111222233334444ULL;
    const uint64_t fake_renderer = 0x5555666677778888ULL;

    if (jg_get_window() != 0 || jg_get_renderer() != 0 || jg_get_frames_rendered() != 0) {
        fprintf(stderr, "FAIL: globals not zero-initialized\n");
        return 1;
    }

    jg_set_window(fake_window);
    jg_set_renderer(fake_renderer);
    jg_note_frame_rendered();
    jg_note_frame_rendered();

    if (jg_get_window() != fake_window) {
        fprintf(stderr, "FAIL: window handle mismatch\n");
        return 1;
    }
    if (jg_get_renderer() != fake_renderer) {
        fprintf(stderr, "FAIL: renderer handle mismatch\n");
        return 1;
    }
    if (jg_get_frames_rendered() != 2) {
        fprintf(stderr, "FAIL: frames_rendered=%d want 2\n", jg_get_frames_rendered());
        return 1;
    }

    printf("OK Phase 0.1: SDL globals set/get/frames\n");
    return 0;
}
