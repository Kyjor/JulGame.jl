#include <stdio.h>
#include <stdint.h>

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
