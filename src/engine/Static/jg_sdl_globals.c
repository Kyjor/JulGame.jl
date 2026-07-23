#include "jg_sdl_globals.h"

/* Static storage shared by host + StaticCompiler Julia via llvmcall later. */
static uint64_t g_window = 0;
static uint64_t g_renderer = 0;
static int32_t g_frames_rendered = 0;

void jg_set_window(uint64_t window)
{
    g_window = window;
}

uint64_t jg_get_window(void)
{
    return g_window;
}

void jg_set_renderer(uint64_t renderer)
{
    g_renderer = renderer;
}

uint64_t jg_get_renderer(void)
{
    return g_renderer;
}

int32_t jg_get_frames_rendered(void)
{
    return g_frames_rendered;
}

void jg_note_frame_rendered(void)
{
    g_frames_rendered += 1;
}
