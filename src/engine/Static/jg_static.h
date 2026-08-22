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

// Shape
/* scale_units_bits is a Float64 bit pattern (reinterpret) */
void static_draw_shape(void *shape, void *renderer, void *camera, int64_t scale_units_bits);

// SoundSource (SDL_mixer)
void static_toggle_sound(void *sound_source, void *sound, int32_t loops);
int32_t static_stop_music(void);
/* Caller must set sound = NULL afterward. */
void static_unload_sound(int32_t is_music, void *sound);
/* volume/channel must be pre-clamped by the caller. */
int32_t static_set_volume(int32_t is_music, int32_t channel, int32_t volume);
int32_t static_play_sound(int32_t is_music, void *sound, int32_t channel, int32_t loops);
int32_t static_set_master_volume(int32_t volume);
/* Disk load only. Concatenates base_path + /assets/sounds/ + sound_path. */
void *static_load_sound(int32_t is_music, const uint8_t *base_path, const uint8_t *sound_path);
/* Sets isMusic, Mix-loads, returns C_NULL on SDL error (already printed). */
void *static_load_sound_source(void *sound_source, int32_t is_music, const uint8_t *base_path, const uint8_t *sound_path);

// Sprite (non-effect). Concatenates base_path + /assets/images/ + image_path.
void *static_load_image(const uint8_t *base_path, const uint8_t *image_path);
void *static_create_texture_from_surface(void *renderer, void *surface);
void static_destroy_texture(void *texture);
void static_free_surface(void *surface);
void static_surface_size(void *surface, int32_t *out_width_height);
void static_set_texture_color(void *texture, int32_t red, int32_t green, int32_t blue, int32_t alpha);
void static_sdl_clear_error(void);
int32_t static_draw_sprite(
    void *sprite, void *renderer, void *camera, void *texture, void *transform,
    int64_t scale_units_bits, int64_t default_pixels_per_unit,
    int32_t has_crop, int32_t crop_x, int32_t crop_y, int32_t crop_z, int32_t crop_t,
    int32_t size_x, int32_t size_y,
    int64_t pixels_per_unit, int32_t is_flipped, int32_t is_float_precision, int32_t anchor,
    double *screen_rect);

#ifdef __cplusplus
}
#endif

#endif /* JG_STATIC_H */
