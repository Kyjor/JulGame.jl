#include <stdio.h>
#include <stdint.h>

int32_t j_sdl_init(void);
int32_t j_sdl_quit(void);

/* Phase 0.2: call StaticCompiler j_sdl_init (llvm → SDL_Init). */
int main(void)
{
    int32_t rc = j_sdl_init();
    if (rc != 0) {
        fprintf(stderr, "FAIL: j_sdl_init returned %d\n", (int)rc);
        return 1;
    }
    j_sdl_quit();
    printf("OK Phase 0.2: j_sdl_init (SDL_INIT_VIDEO)\n");
    return 0;
}
