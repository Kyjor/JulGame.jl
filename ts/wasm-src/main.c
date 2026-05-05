/*
 * SDL2 + Emscripten glue. TS drives the frame loop (requestAnimationFrame).
 * Build from ts/: npm run build:wasm
 */
#include <SDL.h>
#include <emscripten.h>
#include <math.h>

static SDL_Window *window = NULL;
static SDL_Renderer *renderer = NULL;

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    /* TS calls glue_init; keep main empty when using -s INVOKE_RUN=0 */
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int glue_init(int width, int height) {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        return -1;
    }
    if (SDL_CreateWindowAndRenderer(width, height, 0, &window, &renderer) != 0) {
        return -2;
    }
    return 0;
}

EMSCRIPTEN_KEEPALIVE
void glue_render_square_frame(void) {
    if (renderer == NULL) {
        return;
    }
    printf("renderer: %p\n", renderer);
    double t = emscripten_get_now() / 1000.0;
    Uint8 bg_r = (Uint8)(18 + sin(t * 0.8) * 12);
    Uint8 bg_g = (Uint8)(22 + sin(t * 0.5) * 10);
    Uint8 bg_b = (Uint8)(40 + sin(t * 0.6) * 15);

    SDL_SetRenderDrawColor(renderer, bg_r, bg_g, bg_b, 255);
    SDL_RenderClear(renderer);

    SDL_SetRenderDrawColor(renderer, 120, 220, 180, 255);
    int size = (int)(140.0 + sin(t * 2.5) * 24.0);
    int cx = 400;
    int cy = 300;
    SDL_Rect r = { cx - size / 2, cy - size / 2, size, size };
    SDL_RenderFillRect(renderer, &r);

    SDL_RenderPresent(renderer);
}

EMSCRIPTEN_KEEPALIVE
int glue_poll_quit(void) {
    SDL_Event e;
    while (SDL_PollEvent(&e)) {
        if (e.type == SDL_QUIT) {
            return 1;
        }
    }
    return 0;
}
