#include <stdio.h>
#include <stdint.h>
#include <string.h>
#include "jg_static.h"

static int64_t f64_bits(double v)
{
    int64_t bits;
    memcpy(&bits, &v, sizeof(bits));
    return bits;
}

static double bits_f64(int64_t bits)
{
    double v;
    memcpy(&v, &bits, sizeof(v));
    return v;
}

/* Phase 1.2: one hardcoded transform; set/get pos; printf. */
int main(void)
{
    void *w = jg_world_create();
    if (w == NULL) {
        fprintf(stderr, "FAIL: jg_world_create\n");
        return 1;
    }

    if (jg_transform_set_pos(w, 0, f64_bits(12.5), f64_bits(-3.25)) != 0) {
        fprintf(stderr, "FAIL: jg_transform_set_pos\n");
        jg_world_destroy(w);
        return 1;
    }

    int64_t xb = 0, yb = 0;
    if (jg_transform_get_pos(w, 0, &xb, &yb) != 0) {
        fprintf(stderr, "FAIL: jg_transform_get_pos\n");
        jg_world_destroy(w);
        return 1;
    }

    double x = bits_f64(xb);
    double y = bits_f64(yb);
    printf("transform[0] = (%.2f, %.2f)\n", x, y);

    if (x != 12.5 || y != -3.25) {
        fprintf(stderr, "FAIL: expected (12.50, -3.25)\n");
        jg_world_destroy(w);
        return 1;
    }

    if (jg_transform_set_pos(w, 1, f64_bits(0.0), f64_bits(0.0)) == 0) {
        fprintf(stderr, "FAIL: index 1 should be out of range (length=1)\n");
        jg_world_destroy(w);
        return 1;
    }

    jg_world_destroy(w);
    printf("OK Phase 1.2: transform slab get/set_pos\n");
    return 0;
}
