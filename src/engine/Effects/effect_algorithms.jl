module EffectAlgorithmsModule
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    import ...JulGame
    const Math = JulGame.Math
    using ..EffectsModule

    export create_outer_glow_surface, create_inner_glow_surface, offset_blit!, stroke_expand_surface!, apply_bevel_effect, apply_bevel_effect_1, apply_gradient_effect, apply_texture_fill, apply_rough_edge, apply_invert_effect, apply_gaussian_blur

    function offset_blit!(dst::Ptr{SDL2.SDL_Surface}, src::Ptr{SDL2.SDL_Surface}, dx::Int, dy::Int)
        rect = SDL2.SDL_Rect(dx, dy, 0, 0)
        SDL2.SDL_BlitSurface(src, C_NULL, dst, Ref(rect))
    end

    """
        create_outer_glow_surface(base::Ptr{SDL2.SDL_Surface}, radius::Int, color::NTuple{4, Int})
    
    Creates an outer glow effect by expanding the text silhouette and colorizing it.
    Returns a new surface with the glow applied.
    """
    function create_outer_glow_surface(base::Ptr{SDL2.SDL_Surface}, radius::Int, color::NTuple{4, Int}, force_white::Bool=false, fade_amount::Float64=1.0, fade_curve::Float64=1.0)
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
        
        # Create glow using distance transform for smooth, contour-hugging effect
        glow_alpha = Math.TypeConversions.safe_int32_convert(min(color[4], 200))
        
        # Create a colored version of base for glow
        colored = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if colored != C_NULL
            # First, make the surface entirely white while preserving alpha
            if force_white && SDL2.SDL_LockSurface(colored) == 0
                colored_arr = unsafe_wrap(Array, colored, 10; own=false)
                pixels = Ptr{UInt32}(colored_arr[1].pixels)
                pitch = colored_arr[1].pitch ÷ 4
                
                for i in 1:(w * h)
                    pixel = unsafe_load(pixels, i)
                    pixel_alpha = (pixel >> 24) & 0xFF
                    # Keep only alpha, set RGB to white
                    white_pixel = UInt32(pixel_alpha) << 24 | 0x00FFFFFF
                    unsafe_store!(pixels, white_pixel, i)
                end
                
                SDL2.SDL_UnlockSurface(colored)
            end
            
            # Modulate to glow color
            SDL2.SDL_SetSurfaceColorMod(colored, Math.TypeConversions.safe_int32_convert(color[1]), Math.TypeConversions.safe_int32_convert(color[2]), Math.TypeConversions.safe_int32_convert(color[3]))
            SDL2.SDL_SetSurfaceBlendMode(colored, SDL2.SDL_BLENDMODE_BLEND)
            
            # Create distance-based glow using multiple passes
            # This creates a smooth, contour-hugging glow
            for pass in 1:max(3, radius ÷ 2)
                current_radius = pass
                if current_radius > radius
                    continue
                end
                
                # Calculate alpha for this pass (exponential decay)
                pass_alpha = Math.TypeConversions.safe_int32_convert(round(glow_alpha * exp(-current_radius / radius * 2.0)))
                SDL2.SDL_SetSurfaceAlphaMod(colored, pass_alpha)
                
                # Create a dense pattern that follows contours
                num_points = max(20, current_radius * 12)
                for i in 1:num_points
                    # Use more natural distribution
                    angle = (i - 1) * 2π / num_points
                    # Add slight variation for smoother coverage
                    radius_offset = current_radius * (0.9 + 0.2 * sin(i * 0.3))
                    
                    dx = round(Int, cos(angle) * radius_offset) + radius * 2
                    dy = round(Int, sin(angle) * radius_offset) + radius * 2
                    offset_blit!(glow_surface, colored, dx, dy)
                end
            end
            
            SDL2.SDL_FreeSurface(colored)
        end
        
        # Blit original text on top (centered)
        offset_blit!(glow_surface, base, radius * 2, radius * 2)
        
        # Apply distance transform-based fade for smooth, contour-hugging glow
        # This calculates distance from ACTUAL shape pixels, not bounding box
        if fade_amount > 0.0 && SDL2.SDL_LockSurface(glow_surface) == 0 && SDL2.SDL_LockSurface(base) == 0
            glow_arr = unsafe_wrap(Array, glow_surface, 10; own=false)
            base_arr_locked = unsafe_wrap(Array, base, 10; own=false)
            
            glow_pixels = Ptr{UInt32}(glow_arr[1].pixels)
            base_pixels = Ptr{UInt32}(base_arr_locked[1].pixels)
            glow_pitch = glow_arr[1].pitch ÷ 4
            base_pitch = base_arr_locked[1].pitch ÷ 4
            
            # The original content is centered at (radius*2, radius*2) with size (w, h)
            content_left = radius * 2
            content_top = radius * 2
            
            # For each pixel in glow surface, calculate distance to nearest opaque pixel in base
            for gy in 0:(glow_h-1)
                for gx in 0:(glow_w-1)
                    glow_index = gy * glow_pitch + gx + 1
                    glow_pixel = unsafe_load(glow_pixels, glow_index)
                    glow_alpha = (glow_pixel >> 24) & 0xFF
                    
                    if glow_alpha > 0
                        # Calculate this pixel's position relative to the base image
                        base_x = gx - content_left
                        base_y = gy - content_top
                        
                        # If this pixel is within the original shape, keep it unchanged
                        if base_x >= 0 && base_x < w && base_y >= 0 && base_y < h
                            base_index = base_y * base_pitch + base_x + 1
                            base_pixel = unsafe_load(base_pixels, base_index)
                            base_alpha = (base_pixel >> 24) & 0xFF
                            
                            if base_alpha > 128  # Inside the shape
                                continue
                            end
                        end
                        
                        # Calculate minimum distance to any opaque pixel in the base image
                        min_dist = Float64(radius * 2 + 1)
                        search_radius = min(radius * 2, 30)  # Limit search for performance
                        
                        for by in max(0, base_y - search_radius):min(h - 1, base_y + search_radius)
                            for bx in max(0, base_x - search_radius):min(w - 1, base_x + search_radius)
                                base_index = by * base_pitch + bx + 1
                                base_pixel = unsafe_load(base_pixels, base_index)
                                base_alpha = (base_pixel >> 24) & 0xFF
                                
                                if base_alpha > 128  # Found an opaque pixel
                                    dx = Float64(gx - (bx + content_left))
                                    dy = Float64(gy - (by + content_top))
                                    dist = sqrt(dx * dx + dy * dy)
                                    
                                    if dist < min_dist
                                        min_dist = dist
                                    end
                                end
                            end
                        end
                        
                        # Apply fade based on distance from actual shape
                        if min_dist < Float64(radius * 2 + 1)
                            max_dist = Float64(radius * 2)
                            t = clamp(min_dist / max_dist, 0.0, 1.0)
                            
                            # Apply exponential decay for smooth fade
                            fade = exp(-t * (2.5 + fade_curve * 0.5))
                            fade *= clamp(fade_amount, 0.0, 1.0)
                            
                            new_alpha = Math.TypeConversions.safe_int32_convert(round(glow_alpha * fade))
                            
                            if new_alpha > 0
                                new_pixel = UInt32(new_alpha) << 24 | (glow_pixel & 0x00FFFFFF)
                                unsafe_store!(glow_pixels, new_pixel, glow_index)
                            else
                                unsafe_store!(glow_pixels, 0x00000000, glow_index)
                            end
                        else
                            # Too far from shape, make transparent
                            unsafe_store!(glow_pixels, 0x00000000, glow_index)
                        end
                    end
                end
            end
            
            SDL2.SDL_UnlockSurface(base)
            SDL2.SDL_UnlockSurface(glow_surface)
        end
        
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

    # ============================================================================
    # COMPREHENSIVE BEVELED TEXT RENDERING SYSTEM
    # ============================================================================
    
    """
    Generate normal map from text alpha channel for realistic lighting
    """
    function generate_normal_map(texture::Ptr{SDL2.SDL_Texture}, width::Int, height::Int)::Ptr{SDL2.SDL_Surface}
        # Create surface to read texture data
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface == C_NULL
            return C_NULL
        end
        
        # Get renderer and render texture to surface
        renderer = JulGame.Renderer
        if renderer == C_NULL
            SDL2.SDL_FreeSurface(surface)
            return C_NULL
        end
        
        old_target = SDL2.SDL_GetRenderTarget(renderer)
        temp_tex = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_RGBA32, SDL2.SDL_TEXTUREACCESS_TARGET, width, height)
        if temp_tex == C_NULL
            SDL2.SDL_FreeSurface(surface)
            return C_NULL
        end
        
        SDL2.SDL_SetRenderTarget(renderer, temp_tex)
        SDL2.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0)
        SDL2.SDL_RenderClear(renderer)
        SDL2.SDL_RenderCopy(renderer, texture, C_NULL, C_NULL)
        
        # Read pixels back to surface
        arr = unsafe_wrap(Array, surface, 10; own=false)
        SDL2.SDL_RenderReadPixels(renderer, C_NULL, SDL2.SDL_PIXELFORMAT_RGBA32, arr[1].pixels, arr[1].pitch)
        
        SDL2.SDL_SetRenderTarget(renderer, old_target)
        SDL2.SDL_DestroyTexture(temp_tex)
        
        # Generate normal map from alpha channel
        if SDL2.SDL_LockSurface(surface) != 0
            SDL2.SDL_FreeSurface(surface)
            return C_NULL
        end
        
        pixels = Ptr{UInt32}(arr[1].pixels)
        pitch = arr[1].pitch ÷ 4
        
        # Calculate normals using Sobel operator for edge detection
        for y in 1:(height-2)
            for x in 1:(width-2)
                # Sample surrounding pixels for gradient calculation
                center_idx = y * pitch + x + 1
                center_alpha = (unsafe_load(pixels, center_idx) >> 24) & 0xFF
                
                if center_alpha > 0
                    # Calculate gradients using Sobel operator
                    gx = 0; gy = 0
                    
                    # Top row
                    top_left = (unsafe_load(pixels, (y-1) * pitch + (x-1) + 1) >> 24) & 0xFF
                    top_center = (unsafe_load(pixels, (y-1) * pitch + x + 1) >> 24) & 0xFF
                    top_right = (unsafe_load(pixels, (y-1) * pitch + (x+1) + 1) >> 24) & 0xFF
                    
                    # Middle row
                    mid_left = (unsafe_load(pixels, y * pitch + (x-1) + 1) >> 24) & 0xFF
                    mid_right = (unsafe_load(pixels, y * pitch + (x+1) + 1) >> 24) & 0xFF
                    
                    # Bottom row
                    bottom_left = (unsafe_load(pixels, (y+1) * pitch + (x-1) + 1) >> 24) & 0xFF
                    bottom_center = (unsafe_load(pixels, (y+1) * pitch + x + 1) >> 24) & 0xFF
                    bottom_right = (unsafe_load(pixels, (y+1) * pitch + (x+1) + 1) >> 24) & 0xFF
                    
                    # Sobel X gradient
                    gx = (-top_left + top_right - 2*mid_left + 2*mid_right - bottom_left + bottom_right)
                    
                    # Sobel Y gradient  
                    gy = (-top_left - 2*top_center - top_right + bottom_left + 2*bottom_center + bottom_right)
                    
                    # Normalize and convert to normal map
                    length = sqrt(gx*gx + gy*gy + 1)
                    if length > 0
                        nx = UInt8(round(clamp((gx / length + 1) * 127, 0, 255)))
                        ny = UInt8(round(clamp((gy / length + 1) * 127, 0, 255)))
                        nz = UInt8(round(clamp((1 / length + 1) * 127, 0, 255)))
                        
                        # Store as RGBA (normal map format)
                        normal_pixel = (UInt32(255) << 24) | (UInt32(nz) << 16) | (UInt32(ny) << 8) | UInt32(nx)
                        unsafe_store!(pixels, normal_pixel, center_idx)
                    end
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(surface)
        return surface
    end
    
    """
    Interpolate color between two gradient stops
    """
    function interpolate_gradient_color(stops::Vector{EffectsModule.GradientStop}, position::Float32)::NTuple{4, UInt8}
        if isempty(stops)
            return (255, 255, 255, 255)
        end
        
        # Clamp position to valid range
        position = clamp(position, 0.0f0, 1.0f0)
        
        # Find surrounding stops
        for i in 1:(length(stops)-1)
            if position >= stops[i].position && position <= stops[i+1].position
                # Linear interpolation between stops
                t = (position - stops[i].position) / (stops[i+1].position - stops[i].position)
                
                # Calculate interpolated values and clamp to valid range
                r_val = stops[i].color[1] + t * (stops[i+1].color[1] - stops[i].color[1])
                g_val = stops[i].color[2] + t * (stops[i+1].color[2] - stops[i].color[2])
                b_val = stops[i].color[3] + t * (stops[i+1].color[3] - stops[i].color[3])
                a_val = stops[i].color[4] + t * (stops[i+1].color[4] - stops[i].color[4])
                
                # Clamp to valid UInt8 range and convert
                r = UInt8(round(clamp(r_val, 0, 255)))
                g = UInt8(round(clamp(g_val, 0, 255)))
                b = UInt8(round(clamp(b_val, 0, 255)))
                a = UInt8(round(clamp(a_val, 0, 255)))
                
                return (r, g, b, a)
            end
        end
        
        # Return first or last stop if position is outside range
        if position <= stops[1].position
            return stops[1].color
        else
            return stops[end].color
        end
    end
    
    """
    Apply separable Gaussian blur for performance optimization
    """
    function apply_gaussian_blur_optimized(surface::Ptr{SDL2.SDL_Surface}, radius::Float32)::Ptr{SDL2.SDL_Surface}
        if radius <= 0 || surface == C_NULL
            return surface
        end
        
        # Get surface info
        arr = unsafe_wrap(Array, surface, 10; own=false)
        w = arr[1].w
        h = arr[1].h
        
        # Create temporary surface for horizontal pass
        temp_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if temp_surface == C_NULL
            return surface
        end
        
        # Lock surfaces
        if SDL2.SDL_LockSurface(surface) != 0 || SDL2.SDL_LockSurface(temp_surface) != 0
            SDL2.SDL_FreeSurface(temp_surface)
            return surface
        end
        
        src_pixels = Ptr{UInt32}(arr[1].pixels)
        src_pitch = arr[1].pitch ÷ 4
        
        temp_arr = unsafe_wrap(Array, temp_surface, 10; own=false)
        temp_pixels = Ptr{UInt32}(temp_arr[1].pixels)
        temp_pitch = temp_arr[1].pitch ÷ 4
        
        # Calculate kernel size and weights
        kernel_size = Int(ceil(radius * 2)) + 1
        kernel = Float32[]
        total_weight = 0.0f0
        
        for i in 0:(kernel_size-1)
            x = i - kernel_size ÷ 2
            weight = exp(-(x*x) / (2 * radius * radius))
            push!(kernel, weight)
            total_weight += weight
        end
        
        # Normalize kernel
        kernel ./= total_weight
        
        # Horizontal pass
        for y in 0:(h-1)
            for x in 0:(w-1)
                r = 0.0f0; g = 0.0f0; b = 0.0f0; a = 0.0f0
                
                for k in 1:kernel_size
                    sample_x = clamp(x + k - kernel_size ÷ 2 - 1, 0, w-1)
                    sample_idx = y * src_pitch + sample_x + 1
                    pixel = unsafe_load(src_pixels, sample_idx)
                    
                    weight = kernel[k]
                    r += weight * (pixel & 0xFF)
                    g += weight * ((pixel >> 8) & 0xFF)
                    b += weight * ((pixel >> 16) & 0xFF)
                    a += weight * ((pixel >> 24) & 0xFF)
                end
                
                result_pixel = (UInt32(round(clamp(a, 0, 255))) << 24) | (UInt32(round(clamp(b, 0, 255))) << 16) | (UInt32(round(clamp(g, 0, 255))) << 8) | UInt32(round(clamp(r, 0, 255)))
                temp_idx = y * temp_pitch + x + 1
                unsafe_store!(temp_pixels, result_pixel, temp_idx)
            end
        end
        
        # Vertical pass
        result_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if result_surface == C_NULL
            SDL2.SDL_UnlockSurface(surface)
            SDL2.SDL_UnlockSurface(temp_surface)
            SDL2.SDL_FreeSurface(temp_surface)
            return surface
        end
        
        if SDL2.SDL_LockSurface(result_surface) != 0
            SDL2.SDL_UnlockSurface(surface)
            SDL2.SDL_UnlockSurface(temp_surface)
            SDL2.SDL_FreeSurface(temp_surface)
            SDL2.SDL_FreeSurface(result_surface)
            return surface
        end
        
        result_arr = unsafe_wrap(Array, result_surface, 10; own=false)
        result_pixels = Ptr{UInt32}(result_arr[1].pixels)
        result_pitch = result_arr[1].pitch ÷ 4
        
        for y in 0:(h-1)
            for x in 0:(w-1)
                r = 0.0f0; g = 0.0f0; b = 0.0f0; a = 0.0f0
                
                for k in 1:kernel_size
                    sample_y = clamp(y + k - kernel_size ÷ 2 - 1, 0, h-1)
                    sample_idx = sample_y * temp_pitch + x + 1
                    pixel = unsafe_load(temp_pixels, sample_idx)
                    
                    weight = kernel[k]
                    r += weight * (pixel & 0xFF)
                    g += weight * ((pixel >> 8) & 0xFF)
                    b += weight * ((pixel >> 16) & 0xFF)
                    a += weight * ((pixel >> 24) & 0xFF)
                end
                
                result_pixel = (UInt32(round(clamp(a, 0, 255))) << 24) | (UInt32(round(clamp(b, 0, 255))) << 16) | (UInt32(round(clamp(g, 0, 255))) << 8) | UInt32(round(clamp(r, 0, 255)))
                result_idx = y * result_pitch + x + 1
                unsafe_store!(result_pixels, result_pixel, result_idx)
            end
        end
        
        # Unlock and cleanup
        SDL2.SDL_UnlockSurface(surface)
        SDL2.SDL_UnlockSurface(temp_surface)
        SDL2.SDL_UnlockSurface(result_surface)
        SDL2.SDL_FreeSurface(temp_surface)
        
        return result_surface
    end
    
    """
    Calculate lighting based on normal map and light position
    """
    function calculate_lighting(normal_map::Ptr{SDL2.SDL_Surface}, light_pos::Math.Vector2, width::Int, height::Int)::Ptr{SDL2.SDL_Surface}
        if normal_map == C_NULL
            return C_NULL
        end
        
        # Create lighting surface
        lighting_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if lighting_surface == C_NULL
            return C_NULL
        end
        
        if SDL2.SDL_LockSurface(normal_map) != 0 || SDL2.SDL_LockSurface(lighting_surface) != 0
            SDL2.SDL_FreeSurface(lighting_surface)
            return C_NULL
        end
        
        normal_arr = unsafe_wrap(Array, normal_map, 10; own=false)
        normal_pixels = Ptr{UInt32}(normal_arr[1].pixels)
        normal_pitch = normal_arr[1].pitch ÷ 4
        
        lighting_arr = unsafe_wrap(Array, lighting_surface, 10; own=false)
        lighting_pixels = Ptr{UInt32}(lighting_arr[1].pixels)
        lighting_pitch = lighting_arr[1].pitch ÷ 4
        
        # Normalize light position
        light_length = sqrt(light_pos.x^2 + light_pos.y^2 + 1.0)
        light_dir = Math.Vector2(light_pos.x / light_length, light_pos.y / light_length)
        
        for y in 0:(height-1)
            for x in 0:(width-1)
                idx = y * normal_pitch + x + 1
                normal_pixel = unsafe_load(normal_pixels, idx)
                
                # Extract normal from normal map
                nx = (normal_pixel & 0xFF) / 127.0f0 - 1.0f0
                ny = ((normal_pixel >> 8) & 0xFF) / 127.0f0 - 1.0f0
                nz = ((normal_pixel >> 16) & 0xFF) / 127.0f0 - 1.0f0
                
                # Calculate dot product for lighting
                dot_product = nx * light_dir.x + ny * light_dir.y + nz * 0.5f0
                dot_product = clamp(dot_product, 0.0f0, 1.0f0)
                
                # Convert to grayscale lighting value
                lighting_value = UInt8(round(clamp(dot_product * 255, 0, 255)))
                lighting_pixel = (UInt32(255) << 24) | (UInt32(lighting_value) << 16) | (UInt32(lighting_value) << 8) | UInt32(lighting_value)
                
                lighting_idx = y * lighting_pitch + x + 1
                unsafe_store!(lighting_pixels, lighting_pixel, lighting_idx)
            end
        end
        
        SDL2.SDL_UnlockSurface(normal_map)
        SDL2.SDL_UnlockSurface(lighting_surface)
        
        return lighting_surface
    end
    
    """
    Main beveled text rendering function with comprehensive customization
    """
    function apply_bevel_effect_1(
        base::Ptr{SDL2.SDL_Surface}, 
        bevel_effect::EffectsModule.BevelEffect1
    )::Ptr{SDL2.SDL_Surface}
        
        if base == C_NULL
            return C_NULL
        end
        
        # Get base dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        # Create result surface
        result_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if result_surface == C_NULL
            return base
        end
        
        SDL2.SDL_FillRect(result_surface, C_NULL, 0x00000000)
        SDL2.SDL_SetSurfaceBlendMode(result_surface, SDL2.SDL_BLENDMODE_BLEND)
        
        # Composite original text FIRST (as base)
        offset_blit!(result_surface, base, 0, 0)
        
        # Generate normal map from base surface
        normal_map = generate_normal_map_from_surface(base, convert(Int, w), convert(Int, h))
        if normal_map == C_NULL
            SDL2.SDL_FreeSurface(result_surface)
            return base
        end
        
        # Calculate lighting
        lighting_surface = calculate_lighting(normal_map, bevel_effect.light_position, convert(Int, w), convert(Int, h))
        if lighting_surface == C_NULL
            SDL2.SDL_FreeSurface(result_surface)
            SDL2.SDL_FreeSurface(normal_map)
            return base
        end
        
        # Apply blur to lighting for smooth gradients
        if bevel_effect.blur_radius > 0
            blurred_lighting = apply_gaussian_blur_optimized(lighting_surface, bevel_effect.blur_radius)
            if blurred_lighting != lighting_surface
                SDL2.SDL_FreeSurface(lighting_surface)
                lighting_surface = blurred_lighting
            end
        end
        
        # Apply bevel effects based on type
        if bevel_effect.bevel_type == EffectsModule.INNER_BEVEL || bevel_effect.bevel_type == EffectsModule.COMBINED_BEVEL
            # Inner bevel effect - use SDF-based approach for proper medial axis detection
            inner_bevel = apply_inner_bevel_effect(base,lighting_surface, bevel_effect)
            if inner_bevel != C_NULL
                offset_blit!(result_surface, inner_bevel, 0, 0)
                if inner_bevel != base
                    SDL2.SDL_FreeSurface(inner_bevel)
                end
            end
        end
        
        if bevel_effect.bevel_type == EffectsModule.OUTER_BEVEL || bevel_effect.bevel_type == EffectsModule.COMBINED_BEVEL
            # Outer bevel effect
            outer_bevel = apply_outer_bevel_effect(base, lighting_surface, bevel_effect)
            if outer_bevel != C_NULL
                offset_blit!(result_surface, outer_bevel, 0, 0)
                SDL2.SDL_FreeSurface(outer_bevel)
            end
        end
        
        # Apply shadow gradient
        shadow_effect = apply_shadow_effect(base, lighting_surface, bevel_effect)
        if shadow_effect != C_NULL
            offset_blit!(result_surface, shadow_effect, 0, 0)
            SDL2.SDL_FreeSurface(shadow_effect)
        end
        
        # Cleanup
        SDL2.SDL_FreeSurface(lighting_surface)
        SDL2.SDL_FreeSurface(normal_map)
        
        return result_surface
    end
    
    """
    Generate normal map from surface (alternative to texture-based version)
    """
    function generate_normal_map_from_surface(surface::Ptr{SDL2.SDL_Surface}, width::Int, height::Int)::Ptr{SDL2.SDL_Surface}
        normal_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if normal_surface == C_NULL
            return C_NULL
        end
        
        if SDL2.SDL_LockSurface(surface) != 0 || SDL2.SDL_LockSurface(normal_surface) != 0
            SDL2.SDL_FreeSurface(normal_surface)
            return C_NULL
        end
        
        src_arr = unsafe_wrap(Array, surface, 10; own=false)
        src_pixels = Ptr{UInt32}(src_arr[1].pixels)
        src_pitch = src_arr[1].pitch ÷ 4
        
        normal_arr = unsafe_wrap(Array, normal_surface, 10; own=false)
        normal_pixels = Ptr{UInt32}(normal_arr[1].pixels)
        normal_pitch = normal_arr[1].pitch ÷ 4
        
        # Generate normal map using Sobel operator
        for y in 1:(height-2)
            for x in 1:(width-2)
                # Sample surrounding pixels
                center_idx = y * src_pitch + x + 1
                center_alpha = (unsafe_load(src_pixels, center_idx) >> 24) & 0xFF
                
                if center_alpha > 0
                    # Calculate gradients
                    gx = 0; gy = 0
                    
                    # Sobel X kernel
                    gx = (-((unsafe_load(src_pixels, (y-1) * src_pitch + (x-1) + 1) >> 24) & 0xFF) +
                          ((unsafe_load(src_pixels, (y-1) * src_pitch + (x+1) + 1) >> 24) & 0xFF) -
                          2 * ((unsafe_load(src_pixels, y * src_pitch + (x-1) + 1) >> 24) & 0xFF) +
                          2 * ((unsafe_load(src_pixels, y * src_pitch + (x+1) + 1) >> 24) & 0xFF) -
                          ((unsafe_load(src_pixels, (y+1) * src_pitch + (x-1) + 1) >> 24) & 0xFF) +
                          ((unsafe_load(src_pixels, (y+1) * src_pitch + (x+1) + 1) >> 24) & 0xFF))
                    
                    # Sobel Y kernel
                    gy = (-((unsafe_load(src_pixels, (y-1) * src_pitch + (x-1) + 1) >> 24) & 0xFF) -
                          2 * ((unsafe_load(src_pixels, (y-1) * src_pitch + x + 1) >> 24) & 0xFF) -
                          ((unsafe_load(src_pixels, (y-1) * src_pitch + (x+1) + 1) >> 24) & 0xFF) +
                          ((unsafe_load(src_pixels, (y+1) * src_pitch + (x-1) + 1) >> 24) & 0xFF) +
                          2 * ((unsafe_load(src_pixels, (y+1) * src_pitch + x + 1) >> 24) & 0xFF) +
                          ((unsafe_load(src_pixels, (y+1) * src_pitch + (x+1) + 1) >> 24) & 0xFF))
                    
                    # Clamp gradient values to prevent extreme values that could cause sqrt issues
                    gx = clamp(gx, -255.0, 255.0)
                    gy = clamp(gy, -255.0, 255.0)
                    
                    # Normalize and convert to normal map
                    # Ensure we don't get negative values under the square root
                    gradient_magnitude = gx*gx + gy*gy
                    length_squared = gradient_magnitude + 1.0
                    
                    # Clamp to prevent negative values and ensure minimum length
                    length_squared = max(length_squared, 1.0)
                    length = sqrt(length_squared)
                    
                    if length > 0
                        nx = UInt8(round(clamp((gx / length + 1) * 127, 0, 255)))
                        ny = UInt8(round(clamp((gy / length + 1) * 127, 0, 255)))
                        nz = UInt8(round(clamp((1 / length + 1) * 127, 0, 255)))
                        
                        normal_pixel = (UInt32(255) << 24) | (UInt32(nz) << 16) | (UInt32(ny) << 8) | UInt32(nx)
                        normal_idx = y * normal_pitch + x + 1
                        unsafe_store!(normal_pixels, normal_pixel, normal_idx)
                    end
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(surface)
        SDL2.SDL_UnlockSurface(normal_surface)
        
        return normal_surface
    end
    
    function unpack_rgba(packed::UInt32)
        r = UInt8(packed & 0xFF)
        g = UInt8((packed >> 8) & 0xFF)
        b = UInt8((packed >> 16) & 0xFF)
        a = UInt8((packed >> 24) & 0xFF)
        return (r, g, b, a)
    end
    
    function apply_inner_bevel_effect(base::Ptr{SDL2.SDL_Surface}, lighting::Ptr{SDL2.SDL_Surface}, bevel_effect::EffectsModule.BevelEffect1)::Ptr{SDL2.SDL_Surface}
        if base == C_NULL
            return C_NULL
        end
    
        # get dims
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = Int(base_arr[1].w)
        h = Int(base_arr[1].h)
    
        # compute signed distance field from base alpha (use your function)
        sdf = compute_signed_distance_field(base, max(8, Int(round(bevel_effect.bevel_width))))
        if isempty(sdf)
            return base
        end
    
        # compute gradients / normals
        grad_x, grad_y = compute_sdf_gradient(sdf, w, h)
    
        # normalize light direction from bevel_effect.light_position (assumed has x,y)
        ld = bevel_effect.light_position
        lx = Float32(ld.x)   # accept NamedTuple or struct
        ly = Float32(ld.y)
        llen = sqrt(lx*lx + ly*ly)
        if llen > 1e-6
            lx /= llen; ly /= llen
        else
            lx = 0.70710678f0; ly = -0.70710678f0  # default diag
        end
    
        # create result
        inner_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if inner_surface == C_NULL
            return base
        end
    
        # lock surfaces
        if SDL2.SDL_LockSurface(base) != 0 || SDL2.SDL_LockSurface(inner_surface) != 0
            SDL2.SDL_FreeSurface(inner_surface)
            return base
        end
    
        # pointers/pitches
        base_s = unsafe_load(Ptr{SDL2.SDL_Surface}(base))
        base_pixels = Ptr{UInt32}(base_s.pixels)
        base_pitch = Int(base_s.pitch) ÷ 4
    
        inner_s = unsafe_load(Ptr{SDL2.SDL_Surface}(inner_surface))
        inner_pixels = Ptr{UInt32}(inner_s.pixels)
        inner_pitch = Int(inner_s.pitch) ÷ 4
    
        # gradient helper returns packed UInt32 - we will unpack per-pixel
        # intensity and width
        bevel_w = Float32(max(1.0, bevel_effect.bevel_width))
        intensity = Float32(clamp(bevel_effect.intensity, 0.0, 1.0))
    
        # Main loop
        @inbounds for y in 0:(h-1)
            row_base = y * base_pitch
            row_inner = y * inner_pitch
            row_idx = y * w
            for x in 0:(w-1)
                idx = row_idx + x + 1           # 1-based index into sdf/grad arrays
                base_idx = row_base + x + 1     # 1-based index into pixel arrays
    
                base_pixel = unsafe_load(base_pixels, base_idx)
                base_alpha = Int((base_pixel >> 24) & 0xFF)
    
                if base_alpha == 0
                    # transparent: write transparent
                    unsafe_store!(inner_pixels, 0x00000000, row_inner + x + 1)
                    continue
                end
    
                # original RGB (R low byte)
                base_r = Float32(base_pixel & 0xFF)
                base_g = Float32((base_pixel >> 8) & 0xFF)
                base_b = Float32((base_pixel >> 16) & 0xFF)
    
                # sdf & gradient
                distance = sdf[idx]
                gx = grad_x[idx]
                gy = grad_y[idx]
    
                # normalize gradient to a 2D normal (avoid zero)
                g_len = sqrt(max(1e-8, gx*gx + gy*gy))
                nx = gx / g_len
                ny = gy / g_len
    
                # lighting dot (range -1..1)
                dotv = clamp(nx * lx + ny * ly, -1.0, 1.0)
    
                # choose edge emphasis factor (strong at edges)
                # edge_factor decreases with distance from boundary; tweak the falloff constant (here 0.6)
                edge_factor = exp(-abs(distance) * (1.0f0 / max(0.5f0, bevel_w * 0.35f0)))
                edge_factor = clamp(edge_factor, 0.0f0, 1.0f0)
    
                # compute highlight vs shadow factor (0..1)
                light_strength = 0.5f0 + 0.5f0 * dotv    # raised look
                # for inset: light_strength = 0.5f0 - 0.5f0 * dotv
    
                # evaluate gradient color at light_strength (interpolate_gradient_color returns packed UInt32)
                packed_grad = interpolate_gradient_color(bevel_effect.inner_gradient, convert(Float32, light_strength))
                grad_r, grad_g, grad_b, grad_a = unpack_rgba(UInt32(packed_grad))
    
                # convert to 0..1 multipliers
                gr = Float32(grad_r) / 255.0f0
                gg = Float32(grad_g) / 255.0f0
                gb = Float32(grad_b) / 255.0f0
    
                # final modulation amount (how strongly gradient modifies base)
                mod_amount = intensity * edge_factor
    
                # apply modulation: mix base color with base * gradient_color (keeps hue, tints)
                nr = clamp(round(Int, base_r * (1.0f0 - mod_amount) + base_r * gr * mod_amount), 0, 255)
                ng = clamp(round(Int, base_g * (1.0f0 - mod_amount) + base_g * gg * mod_amount), 0, 255)
                nb = clamp(round(Int, base_b * (1.0f0 - mod_amount) + base_b * gb * mod_amount), 0, 255)
    
                # pack back: alpha<<24 | B<<16 | G<<8 | R
                packed = (UInt32(base_alpha) << 24) | (UInt32(nb) << 16) | (UInt32(ng) << 8) | UInt32(nr)
                unsafe_store!(inner_pixels, packed, row_inner + x + 1)
            end
        end
    
        # unlock
        SDL2.SDL_UnlockSurface(base)
        SDL2.SDL_UnlockSurface(inner_surface)
    
        return inner_surface
    end
    
    
    """
    Apply outer bevel effect with gradient colors
    """
    function apply_outer_bevel_effect(base::Ptr{SDL2.SDL_Surface}, lighting::Ptr{SDL2.SDL_Surface}, bevel_effect::EffectsModule.BevelEffect1)::Ptr{SDL2.SDL_Surface}
        if base == C_NULL || lighting == C_NULL
            return C_NULL
        end
        
        # Get dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        outer_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if outer_surface == C_NULL
            return C_NULL
        end
        
        if SDL2.SDL_LockSurface(base) != 0 || SDL2.SDL_LockSurface(lighting) != 0 || SDL2.SDL_LockSurface(outer_surface) != 0
            SDL2.SDL_FreeSurface(outer_surface)
            return C_NULL
        end
        
        base_pixels = Ptr{UInt32}(base_arr[1].pixels)
        base_pitch = base_arr[1].pitch ÷ 4
        
        lighting_arr = unsafe_wrap(Array, lighting, 10; own=false)
        lighting_pixels = Ptr{UInt32}(lighting_arr[1].pixels)
        lighting_pitch = lighting_arr[1].pitch ÷ 4
        
        outer_arr = unsafe_wrap(Array, outer_surface, 10; own=false)
        outer_pixels = Ptr{UInt32}(outer_arr[1].pixels)
        outer_pitch = outer_arr[1].pitch ÷ 4
        
        for y in 0:(h-1)
            for x in 0:(w-1)
                base_idx = y * base_pitch + x + 1
                lighting_idx = y * lighting_pitch + x + 1
                outer_idx = y * outer_pitch + x + 1
                
                base_pixel = unsafe_load(base_pixels, base_idx)
                lighting_pixel = unsafe_load(lighting_pixels, lighting_idx)
                
                base_alpha = (base_pixel >> 24) & 0xFF
                if base_alpha > 0
                    # Invert lighting for outer bevel
                    lighting_intensity = 1.0f0 - ((lighting_pixel & 0xFF) / 255.0f0)
                    
                    # Interpolate gradient color based on inverted lighting
                    gradient_color = interpolate_gradient_color(bevel_effect.outer_gradient, lighting_intensity)
                    
                    # Apply intensity multiplier
                    final_alpha = UInt8(round(clamp(gradient_color[4] * bevel_effect.intensity, 0, 255)))
                    
                    if final_alpha > 0
                        outer_pixel = (UInt32(final_alpha) << 24) | 
                                     (UInt32(gradient_color[3]) << 16) | 
                                     (UInt32(gradient_color[2]) << 8) | 
                                     UInt32(gradient_color[1])
                        unsafe_store!(outer_pixels, outer_pixel, outer_idx)
                    end
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(base)
        SDL2.SDL_UnlockSurface(lighting)
        SDL2.SDL_UnlockSurface(outer_surface)
        
        return outer_surface
    end
    
    """
    Apply shadow effect with gradient colors
    """
    function apply_shadow_effect(base::Ptr{SDL2.SDL_Surface}, lighting::Ptr{SDL2.SDL_Surface}, bevel_effect::EffectsModule.BevelEffect1)::Ptr{SDL2.SDL_Surface}
        if base == C_NULL || lighting == C_NULL
            return C_NULL
        end
        
        # Get dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        shadow_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if shadow_surface == C_NULL
            return C_NULL
        end
        
        if SDL2.SDL_LockSurface(base) != 0 || SDL2.SDL_LockSurface(lighting) != 0 || SDL2.SDL_LockSurface(shadow_surface) != 0
            SDL2.SDL_FreeSurface(shadow_surface)
            return C_NULL
        end
        
        base_pixels = Ptr{UInt32}(base_arr[1].pixels)
        base_pitch = base_arr[1].pitch ÷ 4
        
        lighting_arr = unsafe_wrap(Array, lighting, 10; own=false)
        lighting_pixels = Ptr{UInt32}(lighting_arr[1].pixels)
        lighting_pitch = lighting_arr[1].pitch ÷ 4
        
        shadow_arr = unsafe_wrap(Array, shadow_surface, 10; own=false)
        shadow_pixels = Ptr{UInt32}(shadow_arr[1].pixels)
        shadow_pitch = shadow_arr[1].pitch ÷ 4
        
        for y in 0:(h-1)
            for x in 0:(w-1)
                base_idx = y * base_pitch + x + 1
                lighting_idx = y * lighting_pitch + x + 1
                shadow_idx = y * shadow_pitch + x + 1
                
                base_pixel = unsafe_load(base_pixels, base_idx)
                lighting_pixel = unsafe_load(lighting_pixels, lighting_idx)
                
                base_alpha = (base_pixel >> 24) & 0xFF
                if base_alpha > 0
                    # Use lighting intensity for shadow
                    lighting_intensity = (lighting_pixel & 0xFF) / 255.0f0
                    
                    # Interpolate shadow gradient color
                    gradient_color = interpolate_gradient_color(bevel_effect.shadow_gradient, lighting_intensity)
                    
                    # Apply intensity multiplier
                    final_alpha = UInt8(round(clamp(gradient_color[4] * bevel_effect.intensity * 0.5f0, 0, 255)))  # Shadows are typically more subtle
                    
                    if final_alpha > 0
                        shadow_pixel = (UInt32(final_alpha) << 24) | 
                                      (UInt32(gradient_color[3]) << 16) | 
                                      (UInt32(gradient_color[2]) << 8) | 
                                      UInt32(gradient_color[1])
                        unsafe_store!(shadow_pixels, shadow_pixel, shadow_idx)
                    end
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(base)
        SDL2.SDL_UnlockSurface(lighting)
        SDL2.SDL_UnlockSurface(shadow_surface)
        
        return shadow_surface
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

    function interpolate_gradient_color(stops::Vector{Tuple{Float64, NTuple{4, Int}}}, t::Float64)::UInt32
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
    
    """
        apply_invert_effect(base::Ptr{SDL2.SDL_Surface}, effect::EffectsModule.InvertEffect)
    
    Applies color inversion effect to a surface.
    """
    function apply_invert_effect(base::Ptr{SDL2.SDL_Surface}, effect::EffectsModule.InvertEffect)
        if base == C_NULL
            return base
        end
        
        # Get surface properties
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        pitch = base_arr[1].pitch
        format = base_arr[1].format
        
        # Create result surface
        result = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if result == C_NULL
            return base
        end
        
        # Lock surfaces for pixel access
        SDL2.SDL_LockSurface(base)
        SDL2.SDL_LockSurface(result)
        
        # Get pixel data
        base_pixels = unsafe_wrap(Array, Ptr{UInt32}(base_arr[1].pixels), (pitch ÷ 4 * h,); own=false)
        result_arr = unsafe_wrap(Array, result, 10; own=false)
        result_pixels = unsafe_wrap(Array, Ptr{UInt32}(result_arr[1].pixels), (pitch ÷ 4 * h,); own=false)
        
        # Process each pixel
        for i in 1:length(base_pixels)
            pixel = base_pixels[i]
            
            # Extract RGBA components
            r = Ref{UInt8}()
            g = Ref{UInt8}()
            b = Ref{UInt8}()
            a = Ref{UInt8}()
            SDL2.SDL_GetRGBA(pixel, format, r, g, b, a)
            
            # Invert components based on effect settings
            new_r = effect.invert_red ? (255 - r[]) : r[]
            new_g = effect.invert_green ? (255 - g[]) : g[]
            new_b = effect.invert_blue ? (255 - b[]) : b[]
            new_a = effect.invert_alpha ? (255 - a[]) : a[]
            
            # Map back to pixel format
            inverted_pixel = SDL2.SDL_MapRGBA(format, new_r, new_g, new_b, new_a)
            result_pixels[i] = inverted_pixel
        end
        
        SDL2.SDL_UnlockSurface(base)
        SDL2.SDL_UnlockSurface(result)
        
        return result
    end
    
    """
        apply_gaussian_blur(surface::Ptr{SDL2.SDL_Surface}, blur_radius::Int)
    
    Applies a simple Gaussian blur to smooth out the glow effect.
    """
    function apply_gaussian_blur(surface::Ptr{SDL2.SDL_Surface}, blur_radius::Int)
        if blur_radius <= 0 || surface == C_NULL
            return surface
        end
        
        # Get surface properties
        surface_arr = unsafe_wrap(Array, surface, 10; own=false)
        w = surface_arr[1].w
        h = surface_arr[1].h
        
        # Create result surface
        result = SDL2.SDL_ConvertSurfaceFormat(surface, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if result == C_NULL
            return surface
        end
        
        # Lock surfaces
        if SDL2.SDL_LockSurface(surface) != 0 || SDL2.SDL_LockSurface(result) != 0
            SDL2.SDL_FreeSurface(result)
            return surface
        end
        
        surface_arr_locked = unsafe_wrap(Array, surface, 10; own=false)
        result_arr = unsafe_wrap(Array, result, 10; own=false)
        
        surface_pixels = Ptr{UInt32}(surface_arr_locked[1].pixels)
        result_pixels = Ptr{UInt32}(result_arr[1].pixels)
        pitch = result_arr[1].pitch ÷ 4
        
        # Simple box blur (approximation of Gaussian)
        for y in 0:(h-1)
            for x in 0:(w-1)
                pixel_index = y * pitch + x + 1
                
                # Calculate blur for this pixel
                total_r = 0
                total_g = 0
                total_b = 0
                total_a = 0
                count = 0
                
                for dy in -blur_radius:blur_radius
                    for dx in -blur_radius:blur_radius
                        check_x = x + dx
                        check_y = y + dy
                        
                        if check_x >= 0 && check_x < w && check_y >= 0 && check_y < h
                            check_index = check_y * pitch + check_x + 1
                            pixel = unsafe_load(surface_pixels, check_index)
                            
                            r = pixel & 0xFF
                            g = (pixel >> 8) & 0xFF
                            b = (pixel >> 16) & 0xFF
                            a = (pixel >> 24) & 0xFF
                            
                            total_r += r
                            total_g += g
                            total_b += b
                            total_a += a
                            count += 1
                        end
                    end
                end
                
                if count > 0
                    avg_r = total_r ÷ count
                    avg_g = total_g ÷ count
                    avg_b = total_b ÷ count
                    avg_a = total_a ÷ count
                    
                    blurred_pixel = UInt32(avg_a) << 24 | UInt32(avg_b) << 16 | UInt32(avg_g) << 8 | UInt32(avg_r)
                    unsafe_store!(result_pixels, blurred_pixel, pixel_index)
                else
                    unsafe_store!(result_pixels, 0x00000000, pixel_index)
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(surface)
        SDL2.SDL_UnlockSurface(result)
        
        return result
    end

    """
    Compute a signed distance field from an alpha mask.
    Positive = distance to nearest transparent pixel (inside stroke).
    Negative = distance to nearest opaque pixel (outside stroke).
    Uses a fast two-pass approximation (not perfect but good enough for real-time).
    """
    function compute_signed_distance_field(surface::Ptr{SDL2.SDL_Surface}, max_distance::Int = 32)::Vector{Float32}
        if surface == C_NULL
            return Float32[]
        end
        
        surf_arr = unsafe_wrap(Array, surface, 10; own=false)
        w = surf_arr[1].w
        h = surf_arr[1].h
        
        if SDL2.SDL_LockSurface(surface) != 0
            return Float32[]
        end
        
        pixels = Ptr{UInt32}(surf_arr[1].pixels)
        pitch = surf_arr[1].pitch ÷ 4
        
        # Initialize distance field
        sdf = fill(Float32(max_distance), w * h)
        
        # First pass: forward (top-left to bottom-right)
        for y in 0:(h-1)
            for x in 0:(w-1)
                idx = y * w + x + 1
                pixel_idx = y * pitch + x + 1
                pixel = unsafe_load(pixels, pixel_idx)
                alpha = (pixel >> 24) & 0xFF
                is_opaque = alpha > 128
                
                if is_opaque
                    sdf[idx] = 0.0f0
                else
                    # Check neighbors
                    if x > 0
                        sdf[idx] = min(sdf[idx], sdf[y * w + x] + 1.0f0)
                    end
                    if y > 0
                        sdf[idx] = min(sdf[idx], sdf[(y-1) * w + x + 1] + 1.0f0)
                    end
                end
            end
        end
        
        # Second pass: backward (bottom-right to top-left)
        for y in (h-1):-1:0
            for x in (w-1):-1:0
                idx = y * w + x + 1
                pixel_idx = y * pitch + x + 1
                pixel = unsafe_load(pixels, pixel_idx)
                alpha = (pixel >> 24) & 0xFF
                is_opaque = alpha > 128
                
                if !is_opaque
                    # Check neighbors
                    if x < w - 1
                        sdf[idx] = min(sdf[idx], sdf[y * w + x + 2] + 1.0f0)
                    end
                    if y < h - 1
                        sdf[idx] = min(sdf[idx], sdf[(y+1) * w + x + 1] + 1.0f0)
                    end
                end
            end
        end
        
        # Make opaque pixels negative (inside stroke)
        for y in 0:(h-1)
            for x in 0:(w-1)
                idx = y * w + x + 1
                pixel_idx = y * pitch + x + 1
                pixel = unsafe_load(pixels, pixel_idx)
                alpha = (pixel >> 24) & 0xFF
                is_opaque = alpha > 128
                
                if is_opaque
                    sdf[idx] = -sdf[idx]
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(surface)
        
        return sdf
    end
    
    """
    Compute gradient of the SDF to get surface normals.
    Returns (gradient_x, gradient_y) for each pixel.
    """
    function compute_sdf_gradient(sdf::Vector{Float32}, width::Int, height::Int)::Tuple{Vector{Float32}, Vector{Float32}}
        grad_x = fill(0.0f0, width * height)
        grad_y = fill(0.0f0, width * height)
        
        for y in 0:(height-1)
            for x in 0:(width-1)
                idx = y * width + x + 1
                
                # Compute gradients using central differences
                left_idx = idx - 1
                right_idx = idx + 1
                top_idx = idx - width
                bottom_idx = idx + width
                
                # Handle boundaries
                if x > 0 && x < width - 1
                    grad_x[idx] = (sdf[right_idx] - sdf[left_idx]) / 2.0f0
                elseif x > 0
                    grad_x[idx] = sdf[idx] - sdf[left_idx]
                elseif x < width - 1
                    grad_x[idx] = sdf[right_idx] - sdf[idx]
                end
                
                if y > 0 && y < height - 1
                    grad_y[idx] = (sdf[bottom_idx] - sdf[top_idx]) / 2.0f0
                elseif y > 0
                    grad_y[idx] = sdf[idx] - sdf[top_idx]
                elseif y < height - 1
                    grad_y[idx] = sdf[bottom_idx] - sdf[idx]
                end
            end
        end
        
        return (grad_x, grad_y)
    end
    
    """
    Apply inner bevel using SDF-based medial axis detection.
    This creates a proper carved/inset effect by finding the stroke center.
    """
    function apply_inner_bevel_sdf(base::Ptr{SDL2.SDL_Surface}, bevel_effect::EffectsModule.BevelEffect1)::Ptr{SDL2.SDL_Surface}
        if base == C_NULL
            return C_NULL
        end
        
        surf_arr = unsafe_wrap(Array, base, 10; own=false)
        w = surf_arr[1].w
        h = surf_arr[1].h
        
        # Compute SDF
        sdf = compute_signed_distance_field(base, 64)
        if isempty(sdf)
            return base
        end
        
        # Compute SDF gradient (normal direction)
        grad_x, grad_y = compute_sdf_gradient(sdf, convert(Int, w), convert(Int, h))
        
        # Create result surface
        result_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if result_surface == C_NULL
            return base
        end
        
        if SDL2.SDL_LockSurface(base) != 0 || SDL2.SDL_LockSurface(result_surface) != 0
            SDL2.SDL_FreeSurface(result_surface)
            return base
        end
        
        base_pixels = Ptr{UInt32}(surf_arr[1].pixels)
        base_pitch = surf_arr[1].pitch ÷ 4
        
        result_arr = unsafe_wrap(Array, result_surface, 10; own=false)
        result_pixels = Ptr{UInt32}(result_arr[1].pixels)
        result_pitch = result_arr[1].pitch ÷ 4
        
        # Normalize light direction
        light_dir = bevel_effect.light_position
        light_len = sqrt(light_dir.x * light_dir.x + light_dir.y * light_dir.y)
        if light_len > 0.0f0
            light_dir_x = light_dir.x / light_len
            light_dir_y = light_dir.y / light_len
        else
            light_dir_x = 1.0f0
            light_dir_y = -1.0f0
        end
        
        # Process each pixel
        for y in 0:(h-1)
            for x in 0:(w-1)
                idx = y * w + x + 1
                base_idx = y * base_pitch + x + 1
                result_idx = y * result_pitch + x + 1
                
                base_pixel = unsafe_load(base_pixels, base_idx)
                base_alpha = (base_pixel >> 24) & 0xFF
                
                if base_alpha > 0
                    # Get SDF and gradient at this pixel
                    distance = sdf[idx]
                    gx = grad_x[idx]
                    gy = grad_y[idx]
                    
                    # For inner bevel, we want the effect at the EDGES of the stroke, not the center
                    # The effect should be strongest where we're close to the stroke boundary
                    # abs(distance) small = near edge (effect HIGH)
                    # abs(distance) large = near center (effect LOW)
                    edge_factor = 1.0f0 - clamp(abs(distance) / max(1.0f0, bevel_effect.bevel_width), 0.0f0, 1.0f0)
                    edge_factor = max(0.0f0, edge_factor)
                    
                    if edge_factor > 0.01f0
                        # Extract original pixel colors
                        base_r = base_pixel & 0xFF
                        base_g = (base_pixel >> 8) & 0xFF
                        base_b = (base_pixel >> 16) & 0xFF
                        
                        # For inner bevel, we need to INVERT the normal direction
                        # The SDF gradient points outward, but for inner bevel we want inward normals
                        # This creates the "carved into" effect
                        nx = -gx / sqrt(gx * gx + gy * gy + 0.001f0)  # Invert X
                        ny = -gy / sqrt(gx * gx + gy * gy + 0.001f0)  # Invert Y
                        
                        # Compute lighting with inverted normals
                        dot_prod = nx * light_dir_x + ny * light_dir_y
                        dot_prod = clamp(dot_prod, -1.0f0, 1.0f0)
                        
                        # Create strong directional contrast
                        # Positive dot = surface facing light (highlight)
                        # Negative dot = surface facing away (shadow)
                        light_strength = 0.3f0 + 0.7f0 * (dot_prod + 1.0f0) / 2.0f0  # Maps to [0.3, 1.0]
                        
                        # Get gradient color based on lighting
                        gradient_color = interpolate_gradient_color(bevel_effect.inner_gradient, convert(Float32, light_strength))
                        
                        # Apply strong bevel effect
                        bevel_strength = bevel_effect.intensity * edge_factor
                        
                        # Create the raised effect by modulating the base color
                        # Use the gradient color as a light multiplier
                        light_r = gradient_color[1] / 255.0f0
                        light_g = gradient_color[2] / 255.0f0
                        light_b = gradient_color[3] / 255.0f0
                        
                        # Strong modulation for visible effect
                        blended_r = UInt8(round(clamp(base_r * (1.0f0 - bevel_strength) + base_r * light_r * bevel_strength, 0, 255)))
                        blended_g = UInt8(round(clamp(base_g * (1.0f0 - bevel_strength) + base_g * light_g * bevel_strength, 0, 255)))
                        blended_b = UInt8(round(clamp(base_b * (1.0f0 - bevel_strength) + base_b * light_b * bevel_strength, 0, 255)))
                        
                        result_pixel = (UInt32(base_alpha) << 24) |
                                      (UInt32(blended_b) << 16) |
                                      (UInt32(blended_g) << 8) |
                                      UInt32(blended_r)
                        unsafe_store!(result_pixels, result_pixel, result_idx)
                    end
                end
            end
        end
        
        SDL2.SDL_UnlockSurface(base)
        SDL2.SDL_UnlockSurface(result_surface)
        
        return result_surface
    end
end
