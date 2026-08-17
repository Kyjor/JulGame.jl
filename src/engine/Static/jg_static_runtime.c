#include <stdint.h>

/* Julia Union{T,Nothing} stores a non-zero sentinel for nothing (not address 0).
   Capture once from Julia via static_set_julia_nothing. */
static void *jg_julia_nothing = 0;
/* Type tag of boxed Ptr{Nothing}. Union{Mutable,Ptr{Nothing}}(C_NULL) boxes a
   fresh object each time (not a singleton), so compare typeof instead. */
static void *jg_ptr_nothing_type = 0;

void static_set_julia_nothing(void *p)
{
    jg_julia_nothing = p;
}

void static_set_julia_ptr_nothing_type(void *p)
{
    jg_ptr_nothing_type = p;
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
    if (jg_ptr_nothing_type != 0) {
        void *ty = *(void **)((char *)p - sizeof(void *));
        if (ty == jg_ptr_nothing_type)
            return 1;
    }
    return 0;
}
