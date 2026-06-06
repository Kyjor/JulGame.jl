/*
 * SDL2 + SDL_image + Emscripten glue. TS drives the frame loop (requestAnimationFrame).
 * Build from ts/: npm run build:wasm
 */
#include <SDL.h>
#include <SDL_image.h>
#include <emscripten.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>

static SDL_Window *window = NULL;
static SDL_Renderer *renderer = NULL;

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;
    return 0;
}

EMSCRIPTEN_KEEPALIVE
int glue_init(int width, int height) {
    if (SDL_Init(SDL_INIT_VIDEO) < 0) {
        return -1;
    }
    /* Emscripten: enable PNG/JPG in wasm-src/build.sh via -s SDL2_IMAGE_FORMATS=png,jpg
     * (USE_SDL_IMAGE=2 alone can omit decoders; IMG_Init then reports "PNG not supported"). */
    int img_flags = IMG_INIT_PNG | IMG_INIT_JPG;
    int img_inited = IMG_Init(img_flags);
    if ((img_inited & img_flags) != img_flags) {
        fprintf(stderr, "IMG_Init incomplete (got 0x%x, wanted 0x%x): %s\n", (unsigned)img_inited, (unsigned)img_flags, IMG_GetError());
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
    SDL_Rect r = {cx - size / 2, cy - size / 2, size, size};
    SDL_RenderFillRect(renderer, &r);

    SDL_RenderPresent(renderer);
}

EMSCRIPTEN_KEEPALIVE
int glue_poll_quit(void) {
    /* Quit is handled by transpiled Input.poll_input via SDL_QUIT events. */
    return 0;
}

EMSCRIPTEN_KEEPALIVE
Uint32 glue_SDL_GetTicks(void) {
    return SDL_GetTicks();
}

EMSCRIPTEN_KEEPALIVE
void *glue_get_renderer(void) {
    return (void *)renderer;
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_RenderClear(void) {
    if (renderer) {
        SDL_RenderClear(renderer);
    }
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_RenderPresent(void) {
    if (renderer) {
        SDL_RenderPresent(renderer);
    }
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_SetRenderDrawBlendMode_BLEND(void) {
    if (renderer == NULL) {
        return;
    }
    SDL_SetRenderDrawBlendMode(renderer, SDL_BLENDMODE_BLEND);
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_SetRenderDrawColor(int r, int g, int b, int a) {
    if (renderer == NULL) {
        return;
    }
    SDL_SetRenderDrawColor(renderer, (Uint8)r, (Uint8)g, (Uint8)b, (Uint8)a);
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_RenderFillRectF(float x, float y, float w, float h) {
    if (renderer == NULL) {
        return;
    }
    SDL_FRect rect = {x, y, w, h};
    SDL_RenderFillRectF(renderer, &rect);
}

EMSCRIPTEN_KEEPALIVE
void *glue_IMG_Load(const char *path) {
    return IMG_Load(path);
}

EMSCRIPTEN_KEEPALIVE
void *glue_SDL_CreateTextureFromSurface(void *surface) {
    if (renderer == NULL || surface == NULL) {
        return NULL;
    }
    SDL_Surface *surf = (SDL_Surface *)surface;
    /* Direct upload (no ConvertSurfaceFormat — wasm regressions). */
    return SDL_CreateTextureFromSurface(renderer, surf);
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_RenderSetLogicalSize(int w, int h) {
    if (renderer == NULL) {
        return;
    }
    /* w or h == 0 disables logical scaling (SDL2). */
    if (w <= 0 || h <= 0) {
        SDL_RenderSetLogicalSize(renderer, 0, 0);
        return;
    }
    SDL_RenderSetLogicalSize(renderer, w, h);
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_FreeSurface(void *surface) {
    if (surface) {
        SDL_FreeSurface((SDL_Surface *)surface);
    }
}

EMSCRIPTEN_KEEPALIVE
const char *glue_SDL_GetError(void) {
    return SDL_GetError();
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_ClearError(void) {
    SDL_ClearError();
}

EMSCRIPTEN_KEEPALIVE
int glue_surface_w(void *surface) {
    if (!surface) {
        return 0;
    }
    return ((SDL_Surface *)surface)->w;
}

EMSCRIPTEN_KEEPALIVE
int glue_surface_h(void *surface) {
    if (!surface) {
        return 0;
    }
    return ((SDL_Surface *)surface)->h;
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_SetTextureColorMod(void *texture, int r, int g, int b) {
    if (!texture) {
        return;
    }
    SDL_SetTextureColorMod((SDL_Texture *)texture, (Uint8)r, (Uint8)g, (Uint8)b);
}

EMSCRIPTEN_KEEPALIVE
void glue_SDL_SetTextureAlphaMod(void *texture, int a) {
    if (!texture) {
        return;
    }
    SDL_SetTextureAlphaMod((SDL_Texture *)texture, (Uint8)a);
}

/*
 * SDL_RenderCopyEx with integer rects. Pass has_src=0 for full texture source.
 * center x,y are relative to dst rect; flip: SDL_FLIP_NONE=0, HORIZONTAL=1, VERTICAL=2
 */
EMSCRIPTEN_KEEPALIVE
int glue_render_copy_ex(void *texture, int has_src, int sx, int sy, int sw, int sh, int dx, int dy,
                        int dw, int dh, double angle, int cx, int cy, int flip) {
    if (renderer == NULL || texture == NULL) {
        return -1;
    }
    SDL_Rect src;
    SDL_Rect *psrc = NULL;
    if (has_src) {
        src.x = sx;
        src.y = sy;
        src.w = sw;
        src.h = sh;
        psrc = &src;
    }
    SDL_Rect dst = {dx, dy, dw, dh};
    SDL_Point center = {cx, cy};
    return SDL_RenderCopyEx(renderer, (SDL_Texture *)texture, psrc, &dst, angle, &center,
                            (SDL_RendererFlip)flip);
}

EMSCRIPTEN_KEEPALIVE
int glue_render_copy_ex_f(void *texture, int has_src, float sx, float sy, float sw, float sh, float dx,
                          float dy, float dw, float dh, double angle, float cx, float cy, int flip) {
    if (renderer == NULL || texture == NULL) {
        return -1;
    }
    SDL_Rect src;
    SDL_Rect *psrc = NULL;
    if (has_src) {
        src.x = (int)floorf(sx);
        src.y = (int)floorf(sy);
        src.w = (int)floorf(sw);
        src.h = (int)floorf(sh);
        psrc = &src;
    }
    SDL_Rect dst = {(int)floorf(dx), (int)floorf(dy), (int)floorf(dw), (int)floorf(dh)};
    SDL_Point center = {(int)floorf(cx), (int)floorf(cy)};
    return SDL_RenderCopyEx(renderer, (SDL_Texture *)texture, psrc, &dst, angle, &center,
                            (SDL_RendererFlip)flip);
}

/* --- Input glue (static event + keyboard state for transpiled Input.ts) --- */

static SDL_Event s_input_event;
static int s_mouse_x = 0;
static int s_mouse_y = 0;

EMSCRIPTEN_KEEPALIVE
int glue_input_poll_event(void) {
    int ok = SDL_PollEvent(&s_input_event);
    if (ok) {
        s_mouse_x = 0;
        s_mouse_y = 0;
        SDL_GetMouseState(&s_mouse_x, &s_mouse_y);
    }
    return ok;
}

EMSCRIPTEN_KEEPALIVE
Uint32 glue_input_event_type(void) {
    return s_input_event.type;
}

EMSCRIPTEN_KEEPALIVE
int glue_input_event_button_x(void) {
    return s_input_event.button.x;
}

EMSCRIPTEN_KEEPALIVE
int glue_input_event_button_y(void) {
    return s_input_event.button.y;
}

EMSCRIPTEN_KEEPALIVE
Uint8 glue_input_event_button_button(void) {
    return s_input_event.button.button;
}

EMSCRIPTEN_KEEPALIVE
Uint8 glue_input_event_window_event(void) {
    return s_input_event.window.event;
}

EMSCRIPTEN_KEEPALIVE
int glue_input_get_mouse_x(void) {
    SDL_GetMouseState(&s_mouse_x, &s_mouse_y);
    return s_mouse_x;
}

EMSCRIPTEN_KEEPALIVE
int glue_input_get_mouse_y(void) {
    SDL_GetMouseState(&s_mouse_x, &s_mouse_y);
    return s_mouse_y;
}

EMSCRIPTEN_KEEPALIVE
const Uint8 *glue_input_get_keyboard_state(void) {
    return SDL_GetKeyboardState(NULL);
}

EMSCRIPTEN_KEEPALIVE
int glue_input_get_num_scancodes(void) {
    int num = 0;
    SDL_GetKeyboardState(&num);
    return num;
}

EMSCRIPTEN_KEEPALIVE
int glue_input_key_down(int scancode) {
    int num = 0;
    const Uint8 *state = SDL_GetKeyboardState(&num);
    if (!state || scancode < 0 || scancode >= num) {
        return 0;
    }
    return state[scancode] ? 1 : 0;
}

EMSCRIPTEN_KEEPALIVE
int glue_SDL_Init_subsystem(Uint32 flags) {
    return (SDL_InitSubSystem(flags) == 0) ? 0 : -1;
}

EMSCRIPTEN_KEEPALIVE
int glue_SDL_NumJoysticks(void) {
    return SDL_NumJoysticks();
}
