#include <stdint.h>

/* Julia Union{T,Nothing} stores a non-zero sentinel for nothing (not address 0).
   Capture once from Julia via static_set_julia_nothing. */
static void *jg_julia_nothing = 0;

void static_set_julia_nothing(void *p)
{
    jg_julia_nothing = p;
}

void *static_get_julia_nothing(void)
{
    return jg_julia_nothing;
}

int32_t static_ptr_is_julia_nothing(void *p)
{
    if (p == 0)
        return 1;
    if (jg_julia_nothing != 0 && p == jg_julia_nothing)
        return 1;
    return 0;
}
