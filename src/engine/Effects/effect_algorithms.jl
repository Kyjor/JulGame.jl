module EffectAlgorithmsModule
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    import ...JulGame
    const Math = JulGame.Math
    using ..EffectsModule

    export create_outer_glow_surface, create_inner_glow_surface, offset_blit!, stroke_expand_surface!, apply_bevel_effect, apply_gradient_effect, apply_texture_fill, apply_rough_edge

    function offset_blit!(dst::Ptr{SDL2.SDL_Surface}, src::Ptr{SDL2.SDL_Surface}, dx::Int, dy::Int)
        rect = SDL2.SDL_Rect(dx, dy, 0, 0)
        SDL2.SDL_BlitSurface(src, C_NULL, dst, Ref(rect))
    end

    """
        create_outer_glow_surface(base::Ptr{SDL2.SDL_Surface}, radius::Int, color::NTuple{4, Int})
    
    Creates an outer glow effect by expanding the text silhouette and colorizing it.
    Returns a new surface with the glow applied.
    """
    function create_outer_glow_surface(base::Ptr{SDL2.SDL_Surface}, radius::Int, color::NTuple{4, Int})
        if radius <= 0 || base == C_NULL
            return base
        end
        
        # Get base dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        # Create expanded surface for glow
        glow_w = w + radius * 4
        glow_h = h + radius * 4
        glow_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, glow_w, glow_h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if glow_surface == C_NULL
            return base
        end
        
        # Fill with transparent
        SDL2.SDL_FillRect(glow_surface, C_NULL, 0x00000000)
        SDL2.SDL_SetSurfaceBlendMode(glow_surface, SDL2.SDL_BLENDMODE_BLEND)
        
        # Create glow by blitting the base multiple times in a circle pattern
        glow_alpha = Math.TypeConversions.safe_int32_convert(min(color[4], 180))
        
        # Multiple passes for softer glow
        for pass in 1:3
            current_radius = radius - pass + 1
            if current_radius <= 0
                continue
            end
            
            alpha = Math.TypeConversions.safe_int32_convert(glow_alpha ÷ (pass + 1))
            
            # Create a colored version of base for this pass
            colored = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
            if colored != C_NULL
                # Modulate to glow color
                SDL2.SDL_SetSurfaceColorMod(colored, Math.TypeConversions.safe_int32_convert(color[1]), Math.TypeConversions.safe_int32_convert(color[2]), Math.TypeConversions.safe_int32_convert(color[3]))
                SDL2.SDL_SetSurfaceAlphaMod(colored, alpha)
                SDL2.SDL_SetSurfaceBlendMode(colored, SDL2.SDL_BLENDMODE_BLEND)
                
                # Blit in a circle pattern
                angles = range(0, 2π, length=max(8, current_radius * 4))
                for angle in angles
                    dx = round(Int, cos(angle) * current_radius) + radius * 2
                    dy = round(Int, sin(angle) * current_radius) + radius * 2
                    offset_blit!(glow_surface, colored, dx, dy)
                end
                
                SDL2.SDL_FreeSurface(colored)
            end
        end
        
        # Blit original text on top (centered)
        offset_blit!(glow_surface, base, radius * 2, radius * 2)
        
        return glow_surface
    end

    """
        create_inner_glow_surface(base::Ptr{SDL2.SDL_Surface}, radius::Int, color::NTuple{4, Int})
    
    Creates an inner glow effect by eroding the text and creating a glow from edges inward.
    """
    function create_inner_glow_surface(base::Ptr{SDL2.SDL_Surface}, radius::Int, color::NTuple{4, Int})
        if radius <= 0 || base == C_NULL
            return base
        end
        
        # Get base dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        # Create result surface
        result_surface = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if result_surface == C_NULL
            return base
        end
        
        SDL2.SDL_SetSurfaceBlendMode(result_surface, SDL2.SDL_BLENDMODE_BLEND)
        
        # Lock surfaces for pixel access
        if SDL2.SDL_LockSurface(base) != 0 || SDL2.SDL_LockSurface(result_surface) != 0
            SDL2.SDL_FreeSurface(result_surface)
            return base
        end
        
        base_arr_locked = unsafe_wrap(Array, base, 10; own=false)
        result_arr = unsafe_wrap(Array, result_surface, 10; own=false)
        
        base_pixels = Ptr{UInt32}(base_arr_locked[1].pixels)
        result_pixels = Ptr{UInt32}(result_arr[1].pixels)
        pitch = result_arr[1].pitch ÷ 4
        
        # Calculate distance from edge for each pixel
        glow_alpha = Math.TypeConversions.safe_int32_convert(min(color[4], 200))
        
        for y in 0:(h-1)
            for x in 0:(w-1)
                pixel_index = y * pitch + x + 1
                base_pixel = unsafe_load(base_pixels, pixel_index)
                base_alpha = (base_pixel >> 24) & 0xFF
                
                if base_alpha > 0
                    # Calculate distance to nearest edge (approximate)
                    min_dist_to_edge = radius + 1
                    
                    # Check surrounding pixels to find edge
                    for dy in -radius:radius
                        for dx in -radius:radius
                            check_x = x + dx
                            check_y = y + dy
                            
                            if check_x >= 0 && check_x < w && check_y >= 0 && check_y < h
                                check_index = check_y * pitch + check_x + 1
                                check_pixel = unsafe_load(base_pixels, check_index)
                                check_alpha = (check_pixel >> 24) & 0xFF
                                
                                # If we found a transparent pixel nearby, we're near an edge
                                if check_alpha == 0
                                    dist = sqrt(Float64(dx*dx + dy*dy))
                                    min_dist_to_edge = min(min_dist_to_edge, dist)
                                end
                            end
                        end
                    end
                    
                    # Apply glow based on distance from edge
                    if min_dist_to_edge <= radius
                        # Closer to edge = stronger glow
                        glow_strength = 1.0 - (min_dist_to_edge / radius)
                        glow_alpha_final = Math.TypeConversions.safe_int32_convert(round(glow_alpha * glow_strength))
                        
                        # Blend glow color with original
                        base_r = base_pixel & 0xFF
                        base_g = (base_pixel >> 8) & 0xFF
                        base_b = (base_pixel >> 16) & 0xFF
                        
                        glow_r = Math.TypeConversions.safe_int32_convert(color[1])
                        glow_g = Math.TypeConversions.safe_int32_convert(color[2])
                        glow_b = Math.TypeConversions.safe_int32_convert(color[3])
                        
                        # Blend based on glow strength
                        final_r = Math.TypeConversions.safe_int32_convert(round(base_r * (1 - glow_strength * 0.7) + glow_r * glow_strength * 0.7))
                        final_g = Math.TypeConversions.safe_int32_convert(round(base_g * (1 - glow_strength * 0.7) + glow_g * glow_strength * 0.7))
                        final_b = Math.TypeConversions.safe_int32_convert(round(base_b * (1 - glow_strength * 0.7) + glow_b * glow_strength * 0.7))
                        
                        result_pixel = UInt32(base_alpha) << 24 | UInt32(final_b) << 16 | UInt32(final_g) << 8 | UInt32(final_r)
                        unsafe_store!(result_pixels, result_pixel, pixel_index)
                    else
                        # Far from edge, keep original
                        unsafe_store!(result_pixels, base_pixel, pixel_index)
                    end
                else
                    # Transparent pixel
                    unsafe_store!(result_pixels, 0x00000000, pixel_index)
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(base)
        SDL2.SDL_UnlockSurface(result_surface)
        
        return result_surface
    end

    function stroke_expand_surface!(base::Ptr{SDL2.SDL_Surface}, width::Int, color::NTuple{4, Int})
        if width <= 0
            return base
        end
        
        # Get base dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        # Create expanded surface
        stroke_w = w + width * 2
        stroke_h = h + width * 2
        stroke_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, stroke_w, stroke_h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if stroke_surface == C_NULL
            return base
        end
        
        # Fill with transparent
        SDL2.SDL_FillRect(stroke_surface, C_NULL, 0x00000000)
        SDL2.SDL_SetSurfaceBlendMode(stroke_surface, SDL2.SDL_BLENDMODE_BLEND)
        
        # Create colored version for stroke
        colored = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if colored != C_NULL
            SDL2.SDL_SetSurfaceColorMod(colored, Math.TypeConversions.safe_int32_convert(color[1]), Math.TypeConversions.safe_int32_convert(color[2]), Math.TypeConversions.safe_int32_convert(color[3]))
            SDL2.SDL_SetSurfaceBlendMode(colored, SDL2.SDL_BLENDMODE_BLEND)
            
            # Render multiple offsets around base for stroke
            for x in -width:width
                for y in -width:width
                    if x == 0 && y == 0
                        continue
                    end
                    # Only render if within stroke radius (circular)
                    dist = sqrt(x*x + y*y)
                    if dist <= width
                        offset_blit!(stroke_surface, colored, x + width, y + width)
                    end
                end
            end
            
            SDL2.SDL_FreeSurface(colored)
        end
        
        # Blit original on top (centered)
        offset_blit!(stroke_surface, base, width, width)
        
        return stroke_surface
    end

    """
        apply_bevel_effect(base::Ptr{SDL2.SDL_Surface}, depth::Int, angle::Float64, highlight_color::NTuple{4,Int}, shadow_color::NTuple{4,Int})
    
    Applies a bevel/emboss effect by rendering offset highlights and shadows.
    """
    function apply_bevel_effect(base::Ptr{SDL2.SDL_Surface}, depth::Int, angle::Float64, highlight_color::NTuple{4,Int}, shadow_color::NTuple{4,Int})
        if depth <= 0 || base == C_NULL
            return base
        end
        
        # Get base dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        # Create surface for bevel
        bevel_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if bevel_surface == C_NULL
            return base
        end
        
        SDL2.SDL_FillRect(bevel_surface, C_NULL, 0x00000000)
        SDL2.SDL_SetSurfaceBlendMode(bevel_surface, SDL2.SDL_BLENDMODE_BLEND)
        
        # Calculate light direction
        angle_rad = angle * π / 180.0
        light_x = round(Int, cos(angle_rad) * depth)
        light_y = round(Int, sin(angle_rad) * depth)
        
        # Create highlight (lighter side)
        highlight = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if highlight != C_NULL
            SDL2.SDL_SetSurfaceColorMod(highlight, Math.TypeConversions.safe_int32_convert(highlight_color[1]), Math.TypeConversions.safe_int32_convert(highlight_color[2]), Math.TypeConversions.safe_int32_convert(highlight_color[3]))
            SDL2.SDL_SetSurfaceAlphaMod(highlight, Math.TypeConversions.safe_int32_convert(highlight_color[4]))
            SDL2.SDL_SetSurfaceBlendMode(highlight, SDL2.SDL_BLENDMODE_BLEND)
            offset_blit!(bevel_surface, highlight, -light_x, -light_y)
            SDL2.SDL_FreeSurface(highlight)
        end
        
        # Create shadow (darker side)
        shadow = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if shadow != C_NULL
            SDL2.SDL_SetSurfaceColorMod(shadow, Math.TypeConversions.safe_int32_convert(shadow_color[1]), Math.TypeConversions.safe_int32_convert(shadow_color[2]), Math.TypeConversions.safe_int32_convert(shadow_color[3]))
            SDL2.SDL_SetSurfaceAlphaMod(shadow, Math.TypeConversions.safe_int32_convert(shadow_color[4]))
            SDL2.SDL_SetSurfaceBlendMode(shadow, SDL2.SDL_BLENDMODE_BLEND)
            offset_blit!(bevel_surface, shadow, light_x, light_y)
            SDL2.SDL_FreeSurface(shadow)
        end
        
        # Blit original on top
        offset_blit!(bevel_surface, base, 0, 0)
        
        return bevel_surface
    end

    """
        apply_gradient_effect(base::Ptr{SDL2.SDL_Surface}, gradient_type, stops::Vector, angle::Float64)
    
    Applies a gradient fill to the text.
    """
    function apply_gradient_effect(base::Ptr{SDL2.SDL_Surface}, gradient_type, stops::Vector, angle::Float64)
        if isempty(stops) || base == C_NULL
            return base
        end
        
        # Get base dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        # Create gradient surface
        gradient_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if gradient_surface == C_NULL
            return base
        end
        
        SDL2.SDL_FillRect(gradient_surface, C_NULL, 0x00000000)
        
        # Lock surfaces for pixel access
        if SDL2.SDL_LockSurface(gradient_surface) != 0
            SDL2.SDL_FreeSurface(gradient_surface)
            return base
        end
        
        grad_arr = unsafe_wrap(Array, gradient_surface, 10; own=false)
        pixels = Ptr{UInt32}(grad_arr[1].pixels)
        pitch = grad_arr[1].pitch ÷ 4  # Convert bytes to pixels
        
        if string(gradient_type) == "LinearGradient"
            # Linear gradient based on angle
            angle_rad = angle * π / 180.0
            
            for y in 0:(h-1)
                for x in 0:(w-1)
                    # Calculate position along gradient (0.0 to 1.0)
                    t = if abs(cos(angle_rad)) > abs(sin(angle_rad))
                        (x * cos(angle_rad) + y * sin(angle_rad)) / (w * abs(cos(angle_rad)) + h * abs(sin(angle_rad)))
                    else
                        (x * cos(angle_rad) + y * sin(angle_rad)) / (w * abs(cos(angle_rad)) + h * abs(sin(angle_rad)))
                    end
                    t = clamp(t, 0.0, 1.0)
                    
                    # Find color at position t
                    color = interpolate_gradient_color(stops, t)
                    
                    # Write pixel
                    pixel_index = y * pitch + x + 1
                    unsafe_store!(pixels, color, pixel_index)
                end
            end
        elseif string(gradient_type) == "RadialGradient"
            cx = w / 2.0
            cy = h / 2.0
            max_radius = sqrt(cx*cx + cy*cy)
            
            for y in 0:(h-1)
                for x in 0:(w-1)
                    # Calculate distance from center
                    dx = x - cx
                    dy = y - cy
                    dist = sqrt(dx*dx + dy*dy)
                    t = clamp(dist / max_radius, 0.0, 1.0)
                    
                    # Find color at position t
                    color = interpolate_gradient_color(stops, t)
                    
                    # Write pixel
                    pixel_index = y * pitch + x + 1
                    unsafe_store!(pixels, color, pixel_index)
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(gradient_surface)
        
        # Use gradient as a mask with the text
        # Copy base text alpha channel to gradient
        result = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if result != C_NULL
            if SDL2.SDL_LockSurface(result) == 0 && SDL2.SDL_LockSurface(base) == 0
                result_arr = unsafe_wrap(Array, result, 10; own=false)
                base_arr_locked = unsafe_wrap(Array, base, 10; own=false)
                grad_arr_locked = unsafe_wrap(Array, gradient_surface, 10; own=false)
                
                result_pixels = Ptr{UInt32}(result_arr[1].pixels)
                base_pixels = Ptr{UInt32}(base_arr_locked[1].pixels)
                grad_pixels = Ptr{UInt32}(grad_arr_locked[1].pixels)
                
                # Apply gradient where text exists
                for i in 1:(w*h)
                    base_pixel = unsafe_load(base_pixels, i)
                    grad_pixel = unsafe_load(grad_pixels, i)
                    base_alpha = (base_pixel >> 24) & 0xFF
                    
                    if base_alpha > 0
                        # Use gradient color with text alpha
                        grad_rgb = grad_pixel & 0x00FFFFFF
                        result_pixel = grad_rgb | (UInt32(base_alpha) << 24)
                        unsafe_store!(result_pixels, result_pixel, i)
                    else
                        unsafe_store!(result_pixels, 0x00000000, i)
                    end
                end
                
                SDL2.SDL_UnlockSurface(base)
                SDL2.SDL_UnlockSurface(result)
            end
        end
        
        SDL2.SDL_FreeSurface(gradient_surface)
        
        return result !== C_NULL ? result : base
    end

    function interpolate_gradient_color(stops::Vector, t::Float64)::UInt32
        if isempty(stops)
            return 0xFFFFFFFF
        end
        
        if length(stops) == 1
            c = stops[1][2]  # stops[1] is (position, color), so [2] is color
            return UInt32(c[4]) << 24 | UInt32(c[3]) << 16 | UInt32(c[2]) << 8 | UInt32(c[1])
        end
        
        # Find surrounding stops
        for i in 1:(length(stops)-1)
            if t <= stops[i+1][1]  # stops[i+1][1] is position
                t1 = stops[i][1]    # stops[i][1] is position
                t2 = stops[i+1][1]  # stops[i+1][1] is position
                c1 = stops[i][2]    # stops[i][2] is color
                c2 = stops[i+1][2]  # stops[i+1][2] is color
                
                # Interpolate
                if t2 - t1 > 0.0001
                    ratio = (t - t1) / (t2 - t1)
                else
                    ratio = 0.0
                end
                
                r = round(UInt8, c1[1] * (1 - ratio) + c2[1] * ratio)
                g = round(UInt8, c1[2] * (1 - ratio) + c2[2] * ratio)
                b = round(UInt8, c1[3] * (1 - ratio) + c2[3] * ratio)
                a = round(UInt8, c1[4] * (1 - ratio) + c2[4] * ratio)
                
                return UInt32(a) << 24 | UInt32(b) << 16 | UInt32(g) << 8 | UInt32(r)
            end
        end
        
        # Past last stop
        c = stops[end][2]  # stops[end][2] is color
        return UInt32(c[4]) << 24 | UInt32(c[3]) << 16 | UInt32(c[2]) << 8 | UInt32(c[1])
    end

    """
        apply_texture_fill(base::Ptr{SDL2.SDL_Surface}, texture_path::String, tile::Bool, blend_mode, opacity::Int)
    
    Applies a texture pattern to fill the text.
    """
    function apply_texture_fill(base::Ptr{SDL2.SDL_Surface}, texture_path::String, tile::Bool, blend_mode, opacity::Int)
        if isempty(texture_path) || base == C_NULL
            return base
        end
        
        # Load texture image
        texture_surface = C_NULL
        try
            # Try to load from assets/textures directory
            full_path = joinpath(JulGame.BasePath, "assets", "textures", texture_path)
            if isfile(full_path)
                texture_surface = SDL2.IMG_Load(full_path)
            else
                @debug("Texture file not found: $full_path")
                return base
            end
        catch e
            @debug("Failed to load texture: $e")
            return base
        end
        
        if texture_surface == C_NULL
            @debug("Failed to load texture surface")
            return base
        end
        
        # Get dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        texture_arr = unsafe_wrap(Array, texture_surface, 10; own=false)
        
        base_w = base_arr[1].w
        base_h = base_arr[1].h
        tex_w = texture_arr[1].w
        tex_h = texture_arr[1].h
        
        # Convert texture to RGBA32 format
        texture_rgba = SDL2.SDL_ConvertSurfaceFormat(texture_surface, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        SDL2.SDL_FreeSurface(texture_surface)
        
        if texture_rgba == C_NULL
            return base
        end
        
        # Create result surface
        result = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if result == C_NULL
            SDL2.SDL_FreeSurface(texture_rgba)
            return base
        end
        
        # Lock all surfaces
        if SDL2.SDL_LockSurface(base) != 0 || 
           SDL2.SDL_LockSurface(texture_rgba) != 0 || 
           SDL2.SDL_LockSurface(result) != 0
            SDL2.SDL_FreeSurface(texture_rgba)
            SDL2.SDL_FreeSurface(result)
            return base
        end
        
        base_arr_locked = unsafe_wrap(Array, base, 10; own=false)
        texture_arr_locked = unsafe_wrap(Array, texture_rgba, 10; own=false)
        result_arr = unsafe_wrap(Array, result, 10; own=false)
        
        base_pixels = Ptr{UInt32}(base_arr_locked[1].pixels)
        texture_pixels = Ptr{UInt32}(texture_arr_locked[1].pixels)
        result_pixels = Ptr{UInt32}(result_arr[1].pixels)
        
        base_pitch = base_arr_locked[1].pitch ÷ 4
        tex_pitch = texture_arr_locked[1].pitch ÷ 4
        result_pitch = result_arr[1].pitch ÷ 4
        
        opacity_factor = opacity / 255.0
        
        # Apply texture where text exists
        for y in 0:(base_h-1)
            for x in 0:(base_w-1)
                base_index = y * base_pitch + x + 1
                base_pixel = unsafe_load(base_pixels, base_index)
                base_alpha = (base_pixel >> 24) & 0xFF
                
                if base_alpha > 0
                    # Calculate texture coordinates
                    tex_x = if tile
                        x % tex_w
                    else
                        Math.TypeConversions.safe_int32_convert(round((x / base_w) * tex_w))
                    end
                    
                    tex_y = if tile
                        y % tex_h
                    else
                        Math.TypeConversions.safe_int32_convert(round((y / base_h) * tex_h))
                    end
                    
                    tex_x = clamp(tex_x, 0, tex_w - 1)
                    tex_y = clamp(tex_y, 0, tex_h - 1)
                    
                    tex_index = tex_y * tex_pitch + tex_x + 1
                    tex_pixel = unsafe_load(texture_pixels, tex_index)
                    
                    # Extract colors
                    base_r = base_pixel & 0xFF
                    base_g = (base_pixel >> 8) & 0xFF
                    base_b = (base_pixel >> 16) & 0xFF
                    
                    tex_r = tex_pixel & 0xFF
                    tex_g = (tex_pixel >> 8) & 0xFF
                    tex_b = (tex_pixel >> 16) & 0xFF
                    
                    # Blend based on mode
                    final_r, final_g, final_b = if blend_mode == 1 || blend_mode == 2  # Mod or Mul
                        # Multiply blend
                        (
                            Math.TypeConversions.safe_int32_convert(round((base_r * tex_r / 255.0) * opacity_factor + base_r * (1 - opacity_factor))),
                            Math.TypeConversions.safe_int32_convert(round((base_g * tex_g / 255.0) * opacity_factor + base_g * (1 - opacity_factor))),
                            Math.TypeConversions.safe_int32_convert(round((base_b * tex_b / 255.0) * opacity_factor + base_b * (1 - opacity_factor)))
                        )
                    elseif blend_mode == 3  # Add
                        # Additive blend
                        (
                            Math.TypeConversions.safe_int32_convert(min(255, round(base_r + tex_r * opacity_factor))),
                            Math.TypeConversions.safe_int32_convert(min(255, round(base_g + tex_g * opacity_factor))),
                            Math.TypeConversions.safe_int32_convert(min(255, round(base_b + tex_b * opacity_factor)))
                        )
                    else
                        # Replace (default)
                        (
                            Math.TypeConversions.safe_int32_convert(round(tex_r * opacity_factor + base_r * (1 - opacity_factor))),
                            Math.TypeConversions.safe_int32_convert(round(tex_g * opacity_factor + base_g * (1 - opacity_factor))),
                            Math.TypeConversions.safe_int32_convert(round(tex_b * opacity_factor + base_b * (1 - opacity_factor)))
                        )
                    end
                    
                    result_pixel = UInt32(base_alpha) << 24 | UInt32(final_b) << 16 | UInt32(final_g) << 8 | UInt32(final_r)
                    result_index = y * result_pitch + x + 1
                    unsafe_store!(result_pixels, result_pixel, result_index)
                else
                    # Transparent
                    result_index = y * result_pitch + x + 1
                    unsafe_store!(result_pixels, 0x00000000, result_index)
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(base)
        SDL2.SDL_UnlockSurface(texture_rgba)
        SDL2.SDL_UnlockSurface(result)
        
        SDL2.SDL_FreeSurface(texture_rgba)
        
        return result
    end

    """
        apply_rough_edge(base::Ptr{SDL2.SDL_Surface}, amount::Int, seed::Int, erosion::Bool)
    
    Creates rough, jagged edges on text by randomly eroding/expanding the alpha channel.
    Perfect for grunge, stone, or weathered text effects.
    """
    function apply_rough_edge(base::Ptr{SDL2.SDL_Surface}, amount::Int, seed::Int, erosion::Bool)
        if amount <= 0 || base == C_NULL
            return base
        end
        
        # Get base dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        # Create result surface
        result = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if result == C_NULL
            return base
        end
        
        # Lock surfaces for pixel access
        if SDL2.SDL_LockSurface(base) != 0 || SDL2.SDL_LockSurface(result) != 0
            SDL2.SDL_FreeSurface(result)
            return base
        end
        
        base_arr_locked = unsafe_wrap(Array, base, 10; own=false)
        result_arr = unsafe_wrap(Array, result, 10; own=false)
        
        base_pixels = Ptr{UInt32}(base_arr_locked[1].pixels)
        result_pixels = Ptr{UInt32}(result_arr[1].pixels)
        pitch = result_arr[1].pitch ÷ 4
        
        # Simple pseudo-random number generator
        rng_state = Ref(UInt32(seed))
        function simple_rand()
            rng_state[] = (rng_state[] * 1103515245 + 12345) & 0x7FFFFFFF
            return rng_state[] % 100
        end
        
        # Apply rough edges by randomly modifying alpha at edges
        for y in 0:(h-1)
            for x in 0:(w-1)
                pixel_index = y * pitch + x + 1
                base_pixel = unsafe_load(base_pixels, pixel_index)
                base_alpha = (base_pixel >> 24) & 0xFF
                
                if base_alpha > 0
                    # Check if we're at an edge
                    is_edge = false
                    for dy in -1:1
                        for dx in -1:1
                            if dx == 0 && dy == 0
                                continue
                            end
                            check_x = x + dx
                            check_y = y + dy
                            
                            if check_x >= 0 && check_x < w && check_y >= 0 && check_y < h
                                check_index = check_y * pitch + check_x + 1
                                check_pixel = unsafe_load(base_pixels, check_index)
                                check_alpha = (check_pixel >> 24) & 0xFF
                                
                                if check_alpha == 0
                                    is_edge = true
                                    break
                                end
                            else
                                is_edge = true
                                break
                            end
                        end
                        if is_edge
                            break
                        end
                    end
                    
                    if is_edge
                        # At edge: randomly modify based on amount
                        rand_val = simple_rand()
                        threshold = 40 - (amount * 5)  # More amount = more roughness
                        
                        if erosion && rand_val < threshold
                            # Erode: make transparent
                            unsafe_store!(result_pixels, 0x00000000, pixel_index)
                        elseif !erosion && rand_val > (100 - threshold)
                            # Expand: keep but might reduce alpha
                            new_alpha = Math.TypeConversions.safe_int32_convert(max(0, base_alpha - (simple_rand() % 50)))
                            result_pixel = UInt32(new_alpha) << 24 | (base_pixel & 0x00FFFFFF)
                            unsafe_store!(result_pixels, result_pixel, pixel_index)
                        else
                            # Keep original
                            unsafe_store!(result_pixels, base_pixel, pixel_index)
                        end
                    else
                        # Not at edge, keep original
                        unsafe_store!(result_pixels, base_pixel, pixel_index)
                    end
                else
                    # Transparent pixel - maybe add some noise
                    if !erosion
                        # Check if near an edge
                        near_edge = false
                        for dy in -amount:amount
                            for dx in -amount:amount
                                check_x = x + dx
                                check_y = y + dy
                                
                                if check_x >= 0 && check_x < w && check_y >= 0 && check_y < h
                                    check_index = check_y * pitch + check_x + 1
                                    check_pixel = unsafe_load(base_pixels, check_index)
                                    check_alpha = (check_pixel >> 24) & 0xFF
                                    
                                    if check_alpha > 0
                                        near_edge = true
                                        break
                                    end
                                end
                            end
                            if near_edge
                                break
                            end
                        end
                        
                        if near_edge && simple_rand() < 15
                            # Add rough pixel
                            nearby_pixel = unsafe_load(base_pixels, pixel_index)
                            noise_alpha = Math.TypeConversions.safe_int32_convert(30 + simple_rand() % 60)
                            result_pixel = UInt32(noise_alpha) << 24 | (nearby_pixel & 0x00FFFFFF)
                            unsafe_store!(result_pixels, result_pixel, pixel_index)
                        else
                            unsafe_store!(result_pixels, 0x00000000, pixel_index)
                        end
                    else
                        unsafe_store!(result_pixels, 0x00000000, pixel_index)
                    end
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(base)
        SDL2.SDL_UnlockSurface(result)
        
        return result
    end
end
