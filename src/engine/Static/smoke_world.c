#include <stdio.h>
#include <stdint.h>
#include "jg_static.h"

/* Phase 1.1: create + destroy World (no SDL). */
int main(void)
{
    void *w = jg_world_create();
    if (w == NULL) {
        fprintf(stderr, "FAIL: jg_world_create returned NULL\n");
        return 1;
    }

    if (jg_world_destroy(w) != 0) {
        fprintf(stderr, "FAIL: jg_world_destroy\n");
        return 1;
    }

    if (jg_world_destroy(NULL) == 0) {
        fprintf(stderr, "FAIL: destroy(NULL) should fail\n");
        return 1;
    }

    printf("OK Phase 1.1: jg_world_create / jg_world_destroy\n");
    return 0;
}
