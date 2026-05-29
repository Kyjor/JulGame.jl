#include <stdio.h>
#include <stdint.h>
#include "sc_game.h"

static int g_running = 1;
int square_x = 100;
int square_y = 0;

#ifdef __EMSCRIPTEN__
static uint64_t texture = 0;
static uint64_t sound = 0;
#else
static SDL_Texture *texture = NULL;
static Mix_Chunk *sound = NULL;
#endif

void game_load(void)
{
    g_running = 1;
#ifdef __EMSCRIPTEN__
    texture = j_load_image((uint64_t)(uintptr_t)"assets/images/fly.png");
    sound = j_load_sound((uint64_t)(uintptr_t)"assets/Jump.wav");
#else
    texture = j_load_image("assets/images/fly.png");
    sound = j_load_sound("assets/Jump.wav");
#endif
}

void game_update(void)
{
   
}

void game_draw(void)
{
#ifdef __EMSCRIPTEN__
    if (texture != 0)
        j_draw(texture, square_x, square_y, 64, 64);
    else
        fprintf(stderr, "texture is NULL\n");
#else
    if (texture != NULL)
        j_draw(texture, square_x, square_y, 64, 64);
    else
        fprintf(stderr, "texture is NULL\n");
#endif
}

void game_key_pressed(int32_t key)
{
    if (key == 'q')
        fprintf(stderr, "pressed q\n");
    if (key == SC_KEY_ESCAPE)
        g_running = 0;
    if (key == 'a')
        square_x -= 10;
    if (key == 'd')
        square_x += 10;
    if (key == 'w')
        square_y -= 10;
    if (key == 's')
        square_y += 10;
    if (key == SC_KEY_SPACE)
        j_play_sound(sound);
}

void game_key_released(int32_t key)
{
    if (key == 'z')
        fprintf(stderr, "released z\n");
}

int32_t game_should_continue(void)
{
    return g_running ? 1 : 0;
}

void game_shutdown(void)
{
}

int main(void)
{
#ifdef __EMSCRIPTEN__
    /* sc_engine_init from index.js after runtime is ready */
    return 0;
#else
    int32_t code = sc_run();
    if (code != 0)
        fprintf(stderr, "sc_run failed (%d)\n", code);
    return code;
#endif
}
