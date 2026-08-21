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
/* Type tag of boxed Ptr{Nothing} (Union{Mutable,Ptr{Nothing}} == C_NULL). */
void static_set_julia_ptr_nothing_type(void *p);
void *static_get_julia_nothing(void);
int32_t static_ptr_is_julia_nothing(void *p);

// Rigidbody
/* x_bits/y_bits are Float64 bit patterns (reinterpret), not integer values */
void static_add_velocity(void *rigidbody, int64_t x_bits, int64_t y_bits);
void static_apply_forces(void *rigidbody, int64_t dt_bits, int64_t gravity_bits);

// Camera
/* scale_units_bits is a Float64 bit pattern (reinterpret) */
void static_update_camera(void *camera, void *renderer, int64_t scale_units_bits);

#ifdef __cplusplus
}
#endif

#endif /* JG_STATIC_H */
