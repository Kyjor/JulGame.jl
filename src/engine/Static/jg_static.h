#ifndef JG_STATIC_H
#define JG_STATIC_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Returns 1 if mouse is inside element rect, else 0. */
/* element_right = element_x + width, element_bottom = element_y + height */
int32_t static_is_mouse_inside_element(
    int32_t mouse_x, int32_t mouse_y,
    int32_t element_x, int32_t element_y,
    int32_t element_right, int32_t element_bottom);

/* First 1-based hit index in layer order, or -1. Arrays length n. */
int32_t static_ui_hit_test_batch(
    int32_t mouse_x, int32_t mouse_y,
    const int32_t *xs, const int32_t *ys,
    const int32_t *rights, const int32_t *bottoms,
    int32_t n);

void static_play_animation_once(void *animator, int32_t animation_index);
void static_force_frame_update(void *animator, int32_t frame_index);
void static_update(void *animator, int32_t current_render_time);

/* Julia nothing sentinel (Union{T,Nothing} bit pattern). Call once from Julia. */
void static_set_julia_nothing(void *p);
void *static_get_julia_nothing(void);
int32_t static_ptr_is_julia_nothing(void *p);

// Rigidbody
/* x_bits/y_bits are Float64 bit patterns (reinterpret), not integer values */
void static_add_velocity(void *rigidbody, int64_t x_bits, int64_t y_bits);

/* Phase 0 shell — SDL via llvmcall inside StaticCompiler objects */
int32_t j_sdl_init(void);
int32_t j_sdl_quit(void);
int32_t jg_engine_init(void);
int32_t jg_frame(void); /* 1 = continue, 0 = stop (quit) */
int32_t jg_engine_shutdown(void);

/* Phase 1 — World (host owns ptr; pass into later APIs) */
void *jg_world_create(void);
int32_t jg_world_destroy(void *world);

/* Transform slab — x_bits/y_bits are Float64 bit patterns */
int32_t jg_transform_set_pos(void *world, int32_t index, int64_t x_bits, int64_t y_bits);
int32_t jg_transform_get_pos(void *world, int32_t index, int64_t *out_x_bits, int64_t *out_y_bits);

#ifdef __cplusplus
}
#endif

#endif /* JG_STATIC_H */
