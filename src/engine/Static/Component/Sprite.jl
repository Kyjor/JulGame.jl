# Non-effect sprite path. Crop/texture/size/flags are args (Unions + Symbol).
# SDL_Surface.w/h on 64-bit: flags(4)+pad(4)+format(8) => w at 16, h at 20.

const SPRITE_ANCHOR_CENTER = Int32(0)
const SPRITE_ANCHOR_TOP = Int32(1)
const SPRITE_ANCHOR_BOTTOM = Int32(2)
const SPRITE_ANCHOR_LEFT = Int32(3)
const SPRITE_ANCHOR_RIGHT = Int32(4)
const SPRITE_ANCHOR_TOPLEFT = Int32(5)
const SPRITE_ANCHOR_TOPRIGHT = Int32(6)
const SPRITE_ANCHOR_BOTTOMLEFT = Int32(7)
const SPRITE_ANCHOR_BOTTOMRIGHT = Int32(8)

const SDL_FLIP_NONE = Int32(0)
const SDL_FLIP_HORIZONTAL = Int32(1)

const SDL_SURFACE_WIDTH_OFFSET = 16
const SDL_SURFACE_HEIGHT_OFFSET = 20

@inline function clamp_to_u8(value::Int64)::UInt8
    if value < Int64(0)
        return UInt8(0)
    end
    if value > Int64(255)
        return UInt8(255)
    end
    return unsafe_trunc(UInt8, value)
end

@inline function round_to_int32(value::Float64)::Int32
    if value >= Float64(0.0)
        return unsafe_trunc(Int32, value + Float64(0.5))
    end
    return unsafe_trunc(Int32, value - Float64(0.5))
end

@inline function unit_fraction(value::Float64)::Float64
    whole::Float64 = Float64(unsafe_trunc(Int64, value))
    return value - whole
end

function static_load_image(base_path::Ptr{UInt8}, image_path::Ptr{UInt8})::Ptr{Cvoid}
    full_path::Ptr{UInt8} = malloc_joined_path(base_path, image_path, ASSETS_IMAGES_INFIX)
    if full_path == C_NULL
        return C_NULL
    end
    printf(c"Loading image from %s\n", full_path)
    
    surface::Ptr{Cvoid} = llvm_IMG_Load(full_path)
    # get error message
    error_message::Ptr{UInt8} = llvm_SDL_GetError()
    if error_message != C_NULL
        printf(c"Error loading image: %s\n", error_message)
    end
    wasm_free(Ptr{Cvoid}(full_path))
    return surface
end

function static_create_texture_from_surface(renderer::Ptr{Cvoid}, surface::Ptr{Cvoid})::Ptr{Cvoid}
    if renderer == C_NULL || surface == C_NULL
        return C_NULL
    end
    return llvm_SDL_CreateTextureFromSurface(renderer, surface)
end

function static_destroy_texture(texture::Ptr{Cvoid})
    if texture == C_NULL
        return
    end
    llvm_SDL_DestroyTexture(texture)
    return
end

function static_free_surface(surface::Ptr{Cvoid})
    if surface == C_NULL
        return
    end
    llvm_SDL_FreeSurface(surface)
    return
end

# Writes width,height as Int32 at out_size[0], out_size[1].
function static_surface_size(surface::Ptr{Cvoid}, out_size::Ptr{Int32})
    if surface == C_NULL || out_size == C_NULL
        return
    end
    width::Int32 = unsafe_load(Ptr{Int32}(Ptr{UInt8}(surface) + SDL_SURFACE_WIDTH_OFFSET))
    height::Int32 = unsafe_load(Ptr{Int32}(Ptr{UInt8}(surface) + SDL_SURFACE_HEIGHT_OFFSET))
    unsafe_store!(out_size, width)
    unsafe_store!(out_size + 1, height)
    return
end

function static_set_texture_color(
    texture::Ptr{Cvoid},
    red::Int32,
    green::Int32,
    blue::Int32,
    alpha::Int32,
)
    if texture == C_NULL
        return
    end
    llvm_SDL_SetTextureColorMod(
        texture,
        clamp_to_u8(Int64(red)),
        clamp_to_u8(Int64(green)),
        clamp_to_u8(Int64(blue)),
    )
    llvm_SDL_SetTextureAlphaMod(texture, clamp_to_u8(Int64(alpha)))
    return
end

function static_sdl_clear_error()
    llvm_SDL_ClearError()
    return
end

# screen_rect: 4 Float64s (x, y, w, h) for lastRendered*. Returns SDL render status.
function static_draw_sprite(
    sprite::Ptr{Cvoid},
    renderer::Ptr{Cvoid},
    camera::Ptr{Cvoid},
    texture::Ptr{Cvoid},
    transform::Ptr{Cvoid},
    scale_units_bits::Int64,
    default_pixels_per_unit::Int64,
    has_crop::Int32,
    crop_x::Int32,
    crop_y::Int32,
    crop_z::Int32,
    crop_t::Int32,
    size_x::Int32,
    size_y::Int32,
    pixels_per_unit::Int64,
    is_flipped::Int32,
    is_float_precision::Int32,
    anchor::Int32,
    screen_rect::Ptr{Float64},
)::Int32
    if sprite == C_NULL || renderer == C_NULL || texture == C_NULL || transform == C_NULL
        return Int32(0)
    end

    this = Ptr{SpriteLayout}(sprite)
    sprite_color = this.color
    color_bytes::Ptr{UInt8} = Ptr{UInt8}(wasm_malloc(UInt32(4)))
    llvm_SDL_GetTextureColorMod(texture, color_bytes, color_bytes + 1, color_bytes + 2)
    llvm_SDL_GetTextureAlphaMod(texture, color_bytes + 3)
    current_r::UInt8 = unsafe_load(color_bytes)
    current_g::UInt8 = unsafe_load(color_bytes + 1)
    current_b::UInt8 = unsafe_load(color_bytes + 2)
    current_a::UInt8 = unsafe_load(color_bytes + 3)
    wasm_free(Ptr{Cvoid}(color_bytes))
    wanted_r::UInt8 = clamp_to_u8(sprite_color.r)
    wanted_g::UInt8 = clamp_to_u8(sprite_color.g)
    wanted_b::UInt8 = clamp_to_u8(sprite_color.b)
    wanted_a::UInt8 = clamp_to_u8(sprite_color.a)
    if current_r != wanted_r || current_g != wanted_g || current_b != wanted_b || current_a != wanted_a
        llvm_SDL_SetTextureColorMod(texture, wanted_r, wanted_g, wanted_b)
        llvm_SDL_SetTextureAlphaMod(texture, wanted_a)
    end

    scale_units::Float64 = reinterpret(Float64, scale_units_bits)
    pixels_per_world_unit::Float64 = scale_units
    camera_diff_x::Float64 = Float64(0.0)
    camera_diff_y::Float64 = Float64(0.0)
    if camera != C_NULL
        if !ptr_is_julia_nothing(camera)
            cam = Ptr{CameraLayout}(camera)
            pixels_per_world_unit = scale_units * cam.zoom
            cam_pos::Vector3f = cam.position
            cam_off::Vector2f = cam.offset
            camera_diff_x = (cam_pos.x + cam_off.x) * pixels_per_world_unit
            camera_diff_y = (cam_pos.y + cam_off.y) * pixels_per_world_unit
        end
    end

    parent_transform = Ptr{TransformLayout}(transform)
    world_position::Vector3f = parent_transform.position
    world_scale::Vector3f = parent_transform.scale
    sprite_offset::Vector2f = this.offset
    adjusted_x::Float64 = (world_position.x + sprite_offset.x) * pixels_per_world_unit - camera_diff_x
    adjusted_y::Float64 = (world_position.y + sprite_offset.y) * pixels_per_world_unit - camera_diff_y

    crop_width::Float64 = Float64(size_x)
    crop_height::Float64 = Float64(size_y)
    source_rect_ptr::Ptr{Cvoid} = C_NULL
    source_rect_mem::Ptr{Cvoid} = C_NULL
    if has_crop != Int32(0)
        crop_width = Float64(crop_z)
        crop_height = Float64(crop_t)
        source_rect_mem = wasm_malloc(UInt32(16))
        unsafe_store!(
            Ptr{SDL_Rect}(source_rect_mem),
            SDL_Rect(crop_x, crop_y, crop_z, crop_t),
        )
        source_rect_ptr = source_rect_mem
    end

    scaled_width::Float64 = Float64(0.0)
    scaled_height::Float64 = Float64(0.0)
    if pixels_per_unit == Int64(0)
        scaled_width = crop_width * world_scale.x * pixels_per_world_unit / Float64(64.0)
        scaled_height = crop_height * world_scale.y * pixels_per_world_unit / Float64(64.0)
    else
        ppu::Float64 = Float64(pixels_per_unit)
        if pixels_per_unit < Int64(0)
            ppu = Float64(default_pixels_per_unit)
        end
        scale_factor::Float64 = pixels_per_world_unit / ppu
        scaled_width = crop_width * scale_factor * world_scale.x
        scaled_height = crop_height * scale_factor * world_scale.y
    end

    half::Float64 = Float64(0.5)
    scale_units_x::Float64 = pixels_per_world_unit * world_scale.x
    scale_units_y::Float64 = pixels_per_world_unit * world_scale.y
    centered_x::Float64 = adjusted_x
    centered_y::Float64 = adjusted_y
    if anchor == SPRITE_ANCHOR_CENTER
        centered_x -= (scaled_width - scale_units_x) * half
        centered_y -= (scaled_height - scale_units_y) * half
    elseif anchor == SPRITE_ANCHOR_TOP
        centered_x -= (scaled_width - scale_units_x) * half
    elseif anchor == SPRITE_ANCHOR_BOTTOM
        centered_x -= (scaled_width - scale_units_x) * half
        centered_y -= (scaled_height - scale_units_y)
    elseif anchor == SPRITE_ANCHOR_LEFT
        centered_y -= (scaled_height - scale_units_y) * half
    elseif anchor == SPRITE_ANCHOR_RIGHT
        centered_x -= (scaled_width - scale_units_x)
        centered_y -= (scaled_height - scale_units_y) * half
    elseif anchor == SPRITE_ANCHOR_TOPLEFT
    elseif anchor == SPRITE_ANCHOR_TOPRIGHT
        centered_x -= (scaled_width - scale_units_x)
    elseif anchor == SPRITE_ANCHOR_BOTTOMLEFT
        centered_y -= (scaled_height - scale_units_y)
    elseif anchor == SPRITE_ANCHOR_BOTTOMRIGHT
        centered_x -= (scaled_width - scale_units_x)
        centered_y -= (scaled_height - scale_units_y)
    else
        centered_x -= (scaled_width - scale_units_x) * half
        centered_y -= (scaled_height - scale_units_y) * half
    end

    sprite_center::Vector2f = this.center
    center_x::Float64 = scaled_width * unit_fraction(sprite_center.x)
    center_y::Float64 = scaled_height * unit_fraction(sprite_center.y)
    rotation_bits::Int64 = reinterpret(Int64, this.rotation)
    flip::Int32 = is_flipped != Int32(0) ? SDL_FLIP_HORIZONTAL : SDL_FLIP_NONE

    dest_mem::Ptr{Cvoid} = wasm_malloc(UInt32(16))
    center_mem::Ptr{Cvoid} = wasm_malloc(UInt32(8))
    render_status::Int32 = Int32(0)
    if is_float_precision != Int32(0)
        unsafe_store!(
            Ptr{SDL_FRect}(dest_mem),
            SDL_FRect(Float32(centered_x), Float32(centered_y), Float32(scaled_width), Float32(scaled_height)),
        )
        unsafe_store!(
            Ptr{SDL_FPoint}(center_mem),
            SDL_FPoint(Float32(center_x), Float32(center_y)),
        )
        render_status = llvm_SDL_RenderCopyExF(
            renderer, texture, source_rect_ptr, dest_mem, rotation_bits, center_mem, flip,
        )
    else
        dest_x::Int32 = round_to_int32(centered_x)
        dest_y::Int32 = round_to_int32(centered_y)
        dest_w::Int32 = round_to_int32(scaled_width)
        dest_h::Int32 = round_to_int32(scaled_height)
        unsafe_store!(Ptr{SDL_Rect}(dest_mem), SDL_Rect(dest_x, dest_y, dest_w, dest_h))
        unsafe_store!(
            Ptr{SDL_Point}(center_mem),
            SDL_Point(round_to_int32(center_x), round_to_int32(center_y)),
        )
        render_status = llvm_SDL_RenderCopyEx(
            renderer, texture, source_rect_ptr, dest_mem, rotation_bits, center_mem, flip,
        )
        centered_x = Float64(dest_x)
        centered_y = Float64(dest_y)
        scaled_width = Float64(dest_w)
        scaled_height = Float64(dest_h)
    end
    wasm_free(dest_mem)
    wasm_free(center_mem)
    if source_rect_mem != C_NULL
        wasm_free(source_rect_mem)
    end

    if screen_rect != C_NULL
        unsafe_store!(screen_rect, centered_x)
        unsafe_store!(screen_rect + 1, centered_y)
        unsafe_store!(screen_rect + 2, scaled_width)
        unsafe_store!(screen_rect + 3, scaled_height)
    end

    if render_status != Int32(0)
        error_message::Ptr{UInt8} = llvm_SDL_GetError()
        printf(c"Failed to render sprite: %s\n", error_message)
    end
    return render_status
end
