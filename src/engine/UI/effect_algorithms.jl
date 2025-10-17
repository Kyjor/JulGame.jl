module EffectAlgorithmsModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    using ..UI.TextEffectsModule
    export create_outer_glow_surface, offset_blit!, stroke_expand_surface!, apply_bevel_effect, apply_gradient_effect

    function offset_blit!(dst::Ptr{SDL2.SDL_Surface}, src::Ptr{SDL2.SDL_Surface}, dx::Int, dy::Int)
        rect = SDL2.SDL_Rect(dx, dy, 0, 0)
        CallSDLFunction(SDL2.SDL_BlitSurface, src, C_NULL, dst, Ref(rect))
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
        glow_surface = CallSDLFunction(SDL2.SDL_CreateRGBSurfaceWithFormat, 0, glow_w, glow_h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if glow_surface == C_NULL
            return base
        end
        
        # Fill with transparent
        CallSDLFunction(SDL2.SDL_FillRect, glow_surface, C_NULL, 0x00000000)
        CallSDLFunction(SDL2.SDL_SetSurfaceBlendMode, glow_surface, SDL2.SDL_BLENDMODE_BLEND)
        
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
            colored = CallSDLFunction(SDL2.SDL_ConvertSurfaceFormat, base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
            if colored != C_NULL
                # Modulate to glow color
                CallSDLFunction(SDL2.SDL_SetSurfaceColorMod, colored, Math.TypeConversions.safe_int32_convert(color[1]), Math.TypeConversions.safe_int32_convert(color[2]), Math.TypeConversions.safe_int32_convert(color[3]))
                CallSDLFunction(SDL2.SDL_SetSurfaceAlphaMod, colored, alpha)
                CallSDLFunction(SDL2.SDL_SetSurfaceBlendMode, colored, SDL2.SDL_BLENDMODE_BLEND)
                
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
        stroke_surface = CallSDLFunction(SDL2.SDL_CreateRGBSurfaceWithFormat, 0, stroke_w, stroke_h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if stroke_surface == C_NULL
            return base
        end
        
        # Fill with transparent
        CallSDLFunction(SDL2.SDL_FillRect, stroke_surface, C_NULL, 0x00000000)
        CallSDLFunction(SDL2.SDL_SetSurfaceBlendMode, stroke_surface, SDL2.SDL_BLENDMODE_BLEND)
        
        # Create colored version for stroke
        colored = CallSDLFunction(SDL2.SDL_ConvertSurfaceFormat, base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if colored != C_NULL
            CallSDLFunction(SDL2.SDL_SetSurfaceColorMod, colored, Math.TypeConversions.safe_int32_convert(color[1]), Math.TypeConversions.safe_int32_convert(color[2]), Math.TypeConversions.safe_int32_convert(color[3]))
            CallSDLFunction(SDL2.SDL_SetSurfaceBlendMode, colored, SDL2.SDL_BLENDMODE_BLEND)
            
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

    function bevel_shade!(surface::Ptr{SDL2.SDL_Surface}, angle::Float64, depth::Int)
        # Placeholder: real normal map shading would go here; we leave hook for future optimization.
        return surface
    end
end


