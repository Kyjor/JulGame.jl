module TextEffectRendererModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    using ..UI.TextEffectsModule
    using ..UI.TextStyleModule
    using ..UI.EffectAlgorithmsModule
    using ..UI.EffectTextureCacheModule
    export render_styled_text!

    const CACHE = Ref{EffectTextureCache}(EffectTextureCache())

    function sdl_color(c::NTuple{4, Int})
        return SDL2.SDL_Color(Math.TypeConversions.safe_int32_convert(c[1]), Math.TypeConversions.safe_int32_convert(c[2]), Math.TypeConversions.safe_int32_convert(c[3]), Math.TypeConversions.safe_int32_convert(c[4]))
    end

    function ensure_same_format(surface::Ptr{SDL2.SDL_Surface})
        return SDL2.SDL_ConvertSurfaceFormat(surface, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
    end

    function make_key(text::String, style::TextStyle, fontPath::String, fontSize::Int)
        parts = UInt64[
            hash(text),
            hash(fontPath),
            UInt64(fontSize),
            hash(style.baseColor),
            UInt64(length(style.effects))
        ]
        return compute_key(parts)
    end

    function apply_effects_chain!(baseSurface::Ptr{SDL2.SDL_Surface}, style::TextStyle)
        work = CallSDLFunction(SDL2.SDL_ConvertSurfaceFormat, baseSurface, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if work == C_NULL
            @debug("Failed to convert surface format")
            return C_NULL
        end
        
        CallSDLFunction(SDL2.SDL_SetSurfaceBlendMode, work, SDL2.SDL_BLENDMODE_BLEND)

        for eff in style.effects
            if eff isa TextureFillEffect
                textured = apply_texture_fill(work, eff.texturePath, eff.tile, eff.blendMode, eff.opacity)
                if textured == C_NULL
                    @debug("Failed to create texture fill surface")
                    SDL2.SDL_FreeSurface(work)
                    return C_NULL
                end
                if textured != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = textured
            elseif eff isa GradientEffect
                gradient_result = apply_gradient_effect(work, eff.gradientType, eff.stops, eff.angle)
                if gradient_result == C_NULL
                    @debug("Failed to create gradient surface")
                    SDL2.SDL_FreeSurface(work)
                    return C_NULL
                end
                if gradient_result != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = gradient_result
            elseif eff isa BevelEffect
                beveled = apply_bevel_effect(work, eff.depth, eff.angle, eff.highlight_color, eff.shadow_color)
                if beveled == C_NULL
                    @debug("Failed to create bevel surface")
                    SDL2.SDL_FreeSurface(work)
                    return C_NULL
                end
                if beveled != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = beveled
            elseif eff isa InnerGlowEffect
                inner_glowed = create_inner_glow_surface(work, eff.radius, eff.color)
                if inner_glowed == C_NULL
                    @debug("Failed to create inner glow surface")
                    SDL2.SDL_FreeSurface(work)
                    return C_NULL
                end
                if inner_glowed != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = inner_glowed
            elseif eff isa StrokeEffect
                stroked = stroke_expand_surface!(work, eff.width, eff.color)
                if stroked == C_NULL
                    @debug("Failed to create stroke surface")
                    SDL2.SDL_FreeSurface(work)
                    return C_NULL
                end
                if stroked != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = stroked
            elseif eff isa OuterGlowEffect
                glowed = create_outer_glow_surface(work, eff.radius, eff.color)
                if glowed == C_NULL
                    @debug("Failed to create glow surface")
                    SDL2.SDL_FreeSurface(work)
                    return C_NULL
                end
                if glowed != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = glowed
            elseif eff isa DropShadowEffect
                # Shadow is composed during final pass; skip here.
                continue
            end
        end
        return work
    end

    function render_styled_text!(renderer::Ptr{SDL2.SDL_Renderer}, text::String, font::Ptr{SDL2.TTF_Font}, color::NTuple{4, Int}, style::TextStyle, fontPath::String, fontSize::Int)
        if font == C_NULL || isempty(text)
            return C_NULL
        end
        key = make_key(text, style, fontPath, fontSize)
        return get_or_create_texture!(CACHE[], key, () -> begin
            baseSurface = CallSDLFunction(SDL2.TTF_RenderUTF8_Blended, font, text, sdl_color(color))
            if baseSurface == C_NULL
                @debug("Failed to render base text surface")
                return (C_NULL, 0, 0)
            end
            
            composited = apply_effects_chain!(baseSurface, style)
            if composited == C_NULL
                @debug("Failed to apply effects chain")
                SDL2.SDL_FreeSurface(baseSurface)
                return (C_NULL, 0, 0)
            end
            
            # Drop shadow final pass if present
            for eff in style.effects
                if eff isa DropShadowEffect
                    arr = unsafe_wrap(Array, composited, 10; own=false)
                    w = arr[1].w
                    h = arr[1].h
                    angle_rad = eff.angle * π / 180.0  # Convert to radians
                    outW = w + eff.blur_radius*2 + Math.TypeConversions.safe_int32_convert(abs(round(Int, cos(angle_rad)*eff.distance)))
                    outH = h + eff.blur_radius*2 + Math.TypeConversions.safe_int32_convert(abs(round(Int, sin(angle_rad)*eff.distance)))
                    
                    out = CallSDLFunction(SDL2.SDL_CreateRGBSurfaceWithFormat, 0, outW, outH, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
                    if out == C_NULL
                        @debug("Failed to create shadow surface")
                        SDL2.SDL_FreeSurface(composited)
                        return (C_NULL, 0, 0)
                    end
                    
                    CallSDLFunction(SDL2.SDL_FillRect, out, C_NULL, 0x00000000)
                    CallSDLFunction(SDL2.SDL_SetSurfaceBlendMode, out, SDL2.SDL_BLENDMODE_BLEND)
                    
                    # Create shadow by copying and colorizing
                    shadow = CallSDLFunction(SDL2.SDL_ConvertSurfaceFormat, composited, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
                    if shadow == C_NULL
                        @debug("Failed to create shadow copy")
                        SDL2.SDL_FreeSurface(out)
                        SDL2.SDL_FreeSurface(composited)
                        return (C_NULL, 0, 0)
                    end
                    
                    # Apply shadow color and alpha
                    CallSDLFunction(SDL2.SDL_SetSurfaceColorMod, shadow, Math.TypeConversions.safe_int32_convert(eff.color[1]), Math.TypeConversions.safe_int32_convert(eff.color[2]), Math.TypeConversions.safe_int32_convert(eff.color[3]))
                    CallSDLFunction(SDL2.SDL_SetSurfaceAlphaMod, shadow, Math.TypeConversions.safe_int32_convert(eff.opacity))
                    CallSDLFunction(SDL2.SDL_SetSurfaceBlendMode, shadow, SDL2.SDL_BLENDMODE_BLEND)
                    
                    # Simulate blur by rendering shadow multiple times with slight offsets
                    dx = Math.TypeConversions.safe_int32_convert(round(Int, cos(angle_rad)*eff.distance))
                    dy = Math.TypeConversions.safe_int32_convert(round(Int, sin(angle_rad)*eff.distance))
                    base_x = dx + eff.blur_radius
                    base_y = dy + eff.blur_radius
                    
                    blur_samples = max(1, eff.blur_radius ÷ 2)
                    for bx in -blur_samples:blur_samples
                        for by in -blur_samples:blur_samples
                            offset_blit!(out, shadow, base_x + bx, base_y + by)
                        end
                    end
                    
                    SDL2.SDL_FreeSurface(shadow)
                    
                    # blit original on top
                    offset_blit!(out, composited, eff.blur_radius, eff.blur_radius)
                    SDL2.SDL_FreeSurface(composited)
                    composited = out
                end
            end

            tex = CallSDLFunction(SDL2.SDL_CreateTextureFromSurface, renderer, composited)
            if tex == C_NULL
                @debug("Failed to create texture from surface: $(unsafe_string(SDL2.SDL_GetError()))")
                SDL2.SDL_FreeSurface(composited)
                return (C_NULL, 0, 0)
            end
            
            arr = unsafe_wrap(Array, composited, 10; own=false)
            w = arr[1].w
            h = arr[1].h
            SDL2.SDL_FreeSurface(composited)
            return (tex, w, h)
        end, style.isDynamic)
    end
end


