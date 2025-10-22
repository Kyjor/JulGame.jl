module EffectRendererModule
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    import ...JulGame
    const Math = JulGame.Math
    using ..EffectsModule
    using ..EffectAlgorithmsModule
    
    # Helper function to get original color from target
    function get_original_color(target::EffectsModule.EffectTarget)::NTuple{4, Int}
        if target isa EffectsModule.SurfaceTarget
            # Use the stored original color
            return target.original_color
        elseif target isa EffectsModule.SpriteTarget
            return target.sprite.color
        elseif target isa EffectsModule.RectangleTarget
            return target.rectangle.color
        elseif target isa EffectsModule.LineTarget
            return target.line.color
        elseif target isa EffectsModule.ImageTarget
            return (255, 255, 255, 255)  # Images don't have a color property
        elseif target isa EffectsModule.Mesh3DTarget
            return (255, 255, 255, 255)  # 3D meshes don't have a simple color property
        else
            return (255, 255, 255, 255)
        end
    end
    
    # Helper function to resolve color (use original if INHERIT_COLOR)
    function resolve_color(effect_color::NTuple{4, Int}, target::EffectsModule.EffectTarget)::NTuple{4, Int}
        if effect_color == EffectsModule.INHERIT_COLOR
            return get_original_color(target)
        else
            return effect_color
        end
    end

    export apply_effects!, to_surface, from_surface, apply_effects_chain!

    # Heuristic: determine if a surface's non-transparent pixels are nearly white
    function is_surface_nearly_white(surface::Ptr{SDL2.SDL_Surface})::Bool
        if surface == C_NULL
            return false
        end
        if SDL2.SDL_LockSurface(surface) != 0
            return false
        end
        arr = unsafe_wrap(Array, surface, 10; own=false)
        pixels = Ptr{UInt32}(arr[1].pixels)
        w = arr[1].w
        h = arr[1].h
        pitch = arr[1].pitch ÷ 4
        is_white = true
        # Sample a grid to avoid scanning everything
        step_x = max(1, w ÷ 16)
        step_y = max(1, h ÷ 16)
        for y in 0:step_y:(h-1)
            for x in 0:step_x:(w-1)
                idx = y * pitch + x + 1
                px = unsafe_load(pixels, idx)
                a = (px >> 24) & 0xFF
                if a > 0
                    r = px & 0xFF
                    g = (px >> 8) & 0xFF
                    b = (px >> 16) & 0xFF
                    # treat nearly white as >= 245 each
                    if r < 245 || g < 245 || b < 245
                        is_white = false
                        break
                    end
                end
            end
            if !is_white
                break
            end
        end
        SDL2.SDL_UnlockSurface(surface)
        return is_white
    end

    # If the base surface is nearly white, tint it to the target's original color
    function maybe_tint_to_original_color(surface::Ptr{SDL2.SDL_Surface}, target::EffectsModule.EffectTarget)::Ptr{SDL2.SDL_Surface}
        if surface == C_NULL || !(target isa EffectsModule.SurfaceTarget)
            return surface
        end
        desired = (target::EffectsModule.SurfaceTarget).original_color
        # Skip if desired is white (no-op)
        if desired[1] == 255 && desired[2] == 255 && desired[3] == 255
            return surface
        end
        # Only tint when the glyph appears white (common with some TTF paths)
        if !is_surface_nearly_white(surface)
            return surface
        end
        tinted = SDL2.SDL_ConvertSurfaceFormat(surface, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if tinted == C_NULL
            return surface
        end
        if SDL2.SDL_LockSurface(tinted) != 0
            SDL2.SDL_FreeSurface(tinted)
            return surface
        end
        arr = unsafe_wrap(Array, tinted, 10; own=false)
        pixels = Ptr{UInt32}(arr[1].pixels)
        w = arr[1].w
        h = arr[1].h
        pitch = arr[1].pitch ÷ 4
        r = Math.TypeConversions.safe_int32_convert(desired[1])
        g = Math.TypeConversions.safe_int32_convert(desired[2])
        b = Math.TypeConversions.safe_int32_convert(desired[3])
        for y in 0:(h-1)
            base = y * pitch + 1
            for x in 0:(w-1)
                idx = base + x
                px = unsafe_load(pixels, idx)
                a = (px >> 24) & 0xFF
                if a > 0
                    new_px = (UInt32(a) << 24) | (UInt32(b) << 16) | (UInt32(g) << 8) | UInt32(r)
                    unsafe_store!(pixels, new_px, idx)
                end
            end
        end
        SDL2.SDL_UnlockSurface(tinted)
        return tinted
    end

    # Convert any target to surface for effect processing
    function to_surface(target::EffectsModule.EffectTarget)::Ptr{SDL2.SDL_Surface}
        if target isa EffectsModule.SurfaceTarget
            return target.surface
        elseif target isa EffectsModule.TextureTarget
            return texture_to_surface(target.texture)
        elseif target isa EffectsModule.SpriteTarget
            return target.sprite.image
        elseif target isa EffectsModule.RectangleTarget
            return render_rectangle_to_surface(target.rectangle)
        elseif target isa EffectsModule.LineTarget
            return render_line_to_surface(target.line)
        elseif target isa EffectsModule.ImageTarget
            # UIImage might not have a surface, so create one from texture if needed
            if target.image.surface != C_NULL
                return target.image.surface
            elseif target.image.texture != C_NULL
                # Create surface from texture for effects processing
                return texture_to_surface(target.image.texture)
            else
                @error("UIImage has no surface or texture for effects processing")
                return C_NULL
            end
        elseif target isa EffectsModule.Mesh3DTarget
            return render_mesh3d_to_surface(target.mesh)
        else
            @error("Unknown target type: $(typeof(target))")
            return C_NULL
        end
    end

    # Convert processed surface back to target type
    function from_surface(surface::Ptr{SDL2.SDL_Surface}, target::EffectsModule.EffectTarget)
        if target isa EffectsModule.SurfaceTarget
            return EffectsModule.SurfaceTarget(surface)
        elseif target isa EffectsModule.TextureTarget
            # TODO: Need to get renderer reference
            texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            return EffectsModule.TextureTarget(texture)
        elseif target isa EffectsModule.SpriteTarget
            # Update sprite's surface and regenerate texture
            target.sprite.image = surface
            if target.sprite.texture != C_NULL
                SDL2.SDL_DestroyTexture(target.sprite.texture)
            end
            target.sprite.texture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            return target
        elseif target isa EffectsModule.RectangleTarget
            # Update rectangle's effect texture
            if target.rectangle.effectTexture != C_NULL
                SDL2.SDL_DestroyTexture(target.rectangle.effectTexture)
            end
            target.rectangle.effectTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            return target
        elseif target isa EffectsModule.LineTarget
            # Update line's effect texture
            if target.line.effectTexture != C_NULL
                SDL2.SDL_DestroyTexture(target.line.effectTexture)
            end
            target.line.effectTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            return target
        elseif target isa EffectsModule.ImageTarget
            # Update image's effect texture
            if target.image.effectTexture != C_NULL
                SDL2.SDL_DestroyTexture(target.image.effectTexture)
            end
            target.image.effectTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            return target
        elseif target isa EffectsModule.Mesh3DTarget
            # Update mesh's effect texture
            if target.mesh.effectTexture != C_NULL
                SDL2.SDL_DestroyTexture(target.mesh.effectTexture)
            end
            target.mesh.effectTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            return target
        else
            @error("Unknown target type: $(typeof(target))")
            return target
        end
    end

    # Convert texture to surface (for effect processing)
    function texture_to_surface(texture::Ptr{SDL2.SDL_Texture})::Ptr{SDL2.SDL_Surface}
        if texture == C_NULL
            return C_NULL
        end
        
        # Get texture dimensions
        w = Ref{Cint}(0); h = Ref{Cint}(0)
        SDL2.SDL_QueryTexture(texture, C_NULL, C_NULL, w, h)
        
        # Create surface with same dimensions
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w[], h[], 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface == C_NULL
            return C_NULL
        end
        
        # Set as render target and copy texture to surface
        old_target = SDL2.SDL_GetRenderTarget(C_NULL)
        SDL2.SDL_SetRenderTarget(C_NULL, surface) # TODO: Need to get renderer reference
        
        # Clear surface
        SDL2.SDL_SetRenderDrawColor(C_NULL, 0, 0, 0, 0) # TODO: Need to get renderer reference
        SDL2.SDL_RenderClear(C_NULL) # TODO: Need to get renderer reference
        
        # Copy texture to surface
        SDL2.SDL_RenderCopy(C_NULL, texture, C_NULL, C_NULL) # TODO: Need to get renderer reference
        
        # Restore render target
        SDL2.SDL_SetRenderTarget(C_NULL, old_target) # TODO: Need to get renderer reference
        
        return surface
    end

    # Render rectangle to surface
    function render_rectangle_to_surface(rect::Any)::Ptr{SDL2.SDL_Surface}
        if rect == nothing
            return C_NULL
        end
        
        # Create surface with rectangle dimensions
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, Int32(rect.size.x), Int32(rect.size.y), 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface == C_NULL
            return C_NULL
        end
        
        # Set as render target
        old_target = SDL2.SDL_GetRenderTarget(C_NULL)
        SDL2.SDL_SetRenderTarget(C_NULL, surface) # TODO: Need to get renderer reference
        
        # Clear with transparent background
        SDL2.SDL_SetRenderDrawColor(C_NULL, 0, 0, 0, 0) # TODO: Need to get renderer reference
        SDL2.SDL_RenderClear(C_NULL) # TODO: Need to get renderer reference
        
        # Draw rectangle to surface
        rect_rect = SDL2.SDL_FRect(0, 0, rect.size.x, rect.size.y)
        
        if rect.borderRadius > 0
            # Use existing rounded rectangle drawing
            RectangleModule.draw_rounded_rectangle(C_NULL) # TODO: Need to get renderer reference
            SDL2.SDL_CreateTextureFromSurface(C_NULL, rect_rect, rect.borderRadius, rect.color, rect.fillMode)
        else
            # Regular rectangle
            SDL2.SDL_SetRenderDrawColor(C_NULL, rect.color...) # TODO: Need to get renderer reference
            if rect.fillMode
                SDL2.SDL_RenderFillRectF(C_NULL, Ref(rect_rect)) # TODO: Need to get renderer reference
            else
                SDL2.SDL_RenderDrawRectF(C_NULL, Ref(rect_rect)) # TODO: Need to get renderer reference
            end
        end
        
        # Restore render target
        SDL2.SDL_SetRenderTarget(C_NULL, old_target) # TODO: Need to get renderer reference
        
        return surface
    end

    # Render line to surface
    function render_line_to_surface(line::Any)::Ptr{SDL2.SDL_Surface}
        if line == nothing
            return C_NULL
        end
        
        # Calculate line bounds
        min_x = min(line.startPoint.x, line.endPoint.x)
        min_y = min(line.startPoint.y, line.endPoint.y)
        max_x = max(line.startPoint.x, line.endPoint.x)
        max_y = max(line.startPoint.y, line.endPoint.y)
        
        width = Int(ceil(max_x - min_x)) + line.thickness * 2
        height = Int(ceil(max_y - min_y)) + line.thickness * 2
        
        # Create surface
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface == C_NULL
            return C_NULL
        end
        
        # Set as render target
        old_target = SDL2.SDL_GetRenderTarget(C_NULL)
        SDL2.SDL_SetRenderTarget(C_NULL, surface) # TODO: Need to get renderer reference
        
        # Clear with transparent background
        SDL2.SDL_SetRenderDrawColor(C_NULL, 0, 0, 0, 0) # TODO: Need to get renderer reference
        SDL2.SDL_RenderClear(C_NULL) # TODO: Need to get renderer reference
        
        # Draw line
        SDL2.SDL_SetRenderDrawColor(C_NULL, line.color...) # TODO: Need to get renderer reference
        SDL2.SDL_SetRenderDrawBlendMode(C_NULL, SDL2.SDL_BLENDMODE_BLEND) # TODO: Need to get renderer reference
        
        # Adjust coordinates to surface origin
        start_x = line.startPoint.x - min_x + line.thickness
        start_y = line.startPoint.y - min_y + line.thickness
        end_x = line.endPoint.x - min_x + line.thickness
        end_y = line.endPoint.y - min_y + line.thickness
        
        if line.thickness == 1
            SDL2.SDL_RenderDrawLineF(C_NULL, Float32(start_x), Float32(start_y), Float32(end_x), Float32(end_y)) # TODO: Need to get renderer reference
        else
            # Draw thick line by drawing multiple lines
            for i in 0:(line.thickness-1)
                offset_x = cos(atan2(end_y - start_y, end_x - start_x) + π/2) * i
                offset_y = sin(atan2(end_y - start_y, end_x - start_x) + π/2) * i
                SDL2.SDL_RenderDrawLineF(C_NULL, 
                    Float32(start_x + offset_x), Float32(start_y + offset_y), 
                    Float32(end_x + offset_x), Float32(end_y + offset_y)) # TODO: Need to get renderer reference
            end
        end
        
        # Restore render target
        SDL2.SDL_SetRenderTarget(C_NULL, old_target) # TODO: Need to get renderer reference
        
        return surface
    end

    # Render Mesh3D to surface (simplified)
    function render_mesh3d_to_surface(mesh::Any)::Ptr{SDL2.SDL_Surface}
        if mesh == nothing
            return C_NULL
        end
        
        # For now, create a simple colored surface
        # In a full implementation, this would render the 3D mesh to a 2D surface
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, 100, 100, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface == C_NULL
            return C_NULL
        end
        
        # Set as render target
        old_target = SDL2.SDL_GetRenderTarget(C_NULL)
        SDL2.SDL_SetRenderTarget(C_NULL, surface) # TODO: Need to get renderer reference
        
        # Clear with transparent background
        SDL2.SDL_SetRenderDrawColor(C_NULL, 0, 0, 0, 0) # TODO: Need to get renderer reference
        SDL2.SDL_RenderClear(C_NULL) # TODO: Need to get renderer reference
        
        # Draw a simple placeholder (in real implementation, render the 3D mesh)
        SDL2.SDL_SetRenderDrawColor(C_NULL, 255, 255, 255, 255) # TODO: Need to get renderer reference
        SDL2.SDL_RenderFillRectF(C_NULL, Ref(SDL2.SDL_FRect(10, 10, 80, 80))) # TODO: Need to get renderer reference
        
        # Restore render target
        SDL2.SDL_SetRenderTarget(C_NULL, old_target) # TODO: Need to get renderer reference
        
        return surface
    end

    # Apply effects chain to surface
    function apply_effects_chain!(baseSurface::Ptr{SDL2.SDL_Surface}, effects::Vector{Any}, target::EffectsModule.EffectTarget)
        if baseSurface == C_NULL || isempty(effects)
            return baseSurface
        end
        
        @info "Applying effects chain to surface"
        work = SDL2.SDL_ConvertSurfaceFormat(baseSurface, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if work == C_NULL
            @debug("Failed to convert surface format")
            return baseSurface
        end
        
        SDL2.SDL_SetSurfaceBlendMode(work, SDL2.SDL_BLENDMODE_BLEND)

        # Unconditionally tint glyphs to original color when no color-override effects are present
        local has_override = false
        for eff in effects
            if eff isa EffectsModule.GradientEffect || eff isa EffectsModule.TextureFillEffect
                has_override = true
                break
            end
        end
        if !has_override
            tinted = maybe_tint_to_original_color(work, target)
            if tinted != work
                SDL2.SDL_FreeSurface(work)
                work = tinted
            end
        end

        for eff in effects
            if eff isa EffectsModule.TextureFillEffect
                textured = apply_texture_fill(work, eff.texturePath, eff.tile, eff.blendMode, eff.opacity)
                if textured == C_NULL
                    @debug("Failed to create texture fill surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if textured != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = textured
            elseif eff isa EffectsModule.GradientEffect
                gradient_result = apply_gradient_effect(work, eff.gradientType, eff.stops, eff.angle)
                if gradient_result == C_NULL
                    @debug("Failed to create gradient surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if gradient_result != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = gradient_result
            elseif eff isa EffectsModule.BevelEffect
                resolved_highlight = resolve_color(eff.highlight_color, target)
                resolved_shadow = resolve_color(eff.shadow_color, target)
                beveled = apply_bevel_effect(work, eff.depth, eff.angle, resolved_highlight, resolved_shadow)
                if beveled == C_NULL
                    @debug("Failed to create bevel surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if beveled != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = beveled
            elseif eff isa EffectsModule.InnerGlowEffect
                resolved_color = resolve_color(eff.color, target)
                inner_glowed = create_inner_glow_surface(work, eff.radius, resolved_color)
                if inner_glowed == C_NULL
                    @debug("Failed to create inner glow surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if inner_glowed != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = inner_glowed
            elseif eff isa EffectsModule.StrokeEffect
                resolved_color = resolve_color(eff.color, target)
                stroked = stroke_expand_surface!(work, eff.width, resolved_color)
                if stroked == C_NULL
                    @debug("Failed to create stroke surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if stroked != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = stroked
            elseif eff isa EffectsModule.OuterGlowEffect
                resolved_color = resolve_color(eff.color, target)
                glowed = create_outer_glow_surface(work, eff.radius, resolved_color)
                if glowed == C_NULL
                    @debug("Failed to create glow surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if glowed != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = glowed
            elseif eff isa EffectsModule.RoughEdgeEffect
                roughed = apply_rough_edge(work, eff.amount, eff.seed, eff.erosion)
                if roughed == C_NULL
                    @debug("Failed to create rough edge surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if roughed != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = roughed
            elseif eff isa EffectsModule.InvertEffect
                inverted = apply_invert_effect(work, eff)
                if inverted == C_NULL
                    @debug("Failed to create invert surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if inverted != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = inverted
            elseif eff isa EffectsModule.DropShadowEffect
                # Shadow is composed during final pass; skip here.
                continue
            end
        end
        return work
    end

    # Main API function
    function apply_effects!(target::EffectsModule.EffectTarget, effects::Vector{Any})
        @info "Applying effects to target" target=target effects=effects
        if isempty(effects)
            return target
        end
        
        # Convert to surface
        base_surface = to_surface(target)
        if base_surface == C_NULL
            @error("Failed to convert target to surface")
            return target
        end
        
        # Apply effects
        processed_surface = apply_effects_chain!(base_surface, effects, target)
        if processed_surface == C_NULL
            @error("Failed to apply effects")
            SDL2.SDL_FreeSurface(base_surface)
            return target
        end
        
        # Handle drop shadows (final pass)
        for eff in effects
            if eff isa EffectsModule.DropShadowEffect
                # Resolve shadow color
                resolved_color = resolve_color(eff.color, target)
                # Create modified effect with resolved color
                resolved_effect = EffectsModule.DropShadowEffect(
                    distance=eff.distance, 
                    angle=eff.angle, 
                    blur_radius=eff.blur_radius, 
                    color=resolved_color, 
                    opacity=eff.opacity
                )
                # Create shadow surface
                shadow_surface = create_drop_shadow_surface(processed_surface, resolved_effect)
                if shadow_surface != C_NULL
                    # Composite shadow and main surface
                    final_surface = composite_shadow_surface(shadow_surface, processed_surface, resolved_effect)
                    if final_surface != C_NULL
                        SDL2.SDL_FreeSurface(processed_surface)
                        SDL2.SDL_FreeSurface(shadow_surface)
                        processed_surface = final_surface
                    end
                end
            end
        end
        
        # Convert back to target type
        result = from_surface(processed_surface, target)

        # Clean up
        # Do not free base surfaces that are owned by higher-level objects (UI images, sprites)
        if target isa EffectsModule.SurfaceTarget
            # Caller owns both base_surface and processed_surface; do not free here
        elseif target isa EffectsModule.ImageTarget || target isa EffectsModule.SpriteTarget
            # The UI/Sprite instances manage their own base surfaces. Only free the temporary processed surface
            if processed_surface != base_surface
                SDL2.SDL_FreeSurface(processed_surface)
            end
        else
            if processed_surface != base_surface
                SDL2.SDL_FreeSurface(processed_surface)
            end
            SDL2.SDL_FreeSurface(base_surface)
        end

        return result
    end

    # Create drop shadow surface
    function create_drop_shadow_surface(base::Ptr{SDL2.SDL_Surface}, effect::EffectsModule.DropShadowEffect)::Ptr{SDL2.SDL_Surface}
        if base == C_NULL
            return C_NULL
        end
        
        # Get base dimensions
        base_arr = unsafe_wrap(Array, base, 10; own=false)
        w = base_arr[1].w
        h = base_arr[1].h
        
        # Calculate shadow offset
        angle_rad = effect.angle * π / 180.0
        offset_x = round(Int, cos(angle_rad) * effect.distance)
        offset_y = round(Int, sin(angle_rad) * effect.distance)
        
        # Create expanded surface for shadow
        shadow_w = w + effect.blur_radius * 2 + abs(offset_x)
        shadow_h = h + effect.blur_radius * 2 + abs(offset_y)
        shadow_surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, shadow_w, shadow_h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if shadow_surface == C_NULL
            return C_NULL
        end
        
        # Fill with transparent
        SDL2.SDL_FillRect(shadow_surface, C_NULL, 0x00000000)
        SDL2.SDL_SetSurfaceBlendMode(shadow_surface, SDL2.SDL_BLENDMODE_BLEND)
        
        # Create colored shadow
        colored = SDL2.SDL_ConvertSurfaceFormat(base, SDL2.SDL_PIXELFORMAT_RGBA32, 0)
        if colored != C_NULL
            SDL2.SDL_SetSurfaceColorMod(colored, Math.TypeConversions.safe_int32_convert(effect.color[1]), Math.TypeConversions.safe_int32_convert(effect.color[2]), Math.TypeConversions.safe_int32_convert(effect.color[3]))
            SDL2.SDL_SetSurfaceAlphaMod(colored, Math.TypeConversions.safe_int32_convert(effect.color[4]))
            
            # Blit shadow with offset and blur simulation
            for i in 1:effect.blur_radius
                alpha = Math.TypeConversions.safe_int32_convert(effect.color[4] ÷ (i + 1))
                SDL2.SDL_SetSurfaceAlphaMod(colored, alpha)
                
                for dx in -i:i
                    for dy in -i:i
                        if dx*dx + dy*dy <= i*i
                            offset_blit!(shadow_surface, colored, 
                                effect.blur_radius + offset_x + dx, 
                                effect.blur_radius + offset_y + dy)
                        end
                    end
                end
            end
            
            SDL2.SDL_FreeSurface(colored)
        end
        
        return shadow_surface
    end

    # Composite shadow and main surface
    function composite_shadow_surface(shadow::Ptr{SDL2.SDL_Surface}, main::Ptr{SDL2.SDL_Surface}, effect::EffectsModule.DropShadowEffect)::Ptr{SDL2.SDL_Surface}
        if shadow == C_NULL || main == C_NULL
            return main
        end
        
        # Get dimensions
        shadow_arr = unsafe_wrap(Array, shadow, 10; own=false)
        main_arr = unsafe_wrap(Array, main, 10; own=false)
        
        shadow_w = shadow_arr[1].w
        shadow_h = shadow_arr[1].h
        main_w = main_arr[1].w
        main_h = main_arr[1].h
        
        # Create result surface
        result = SDL2.SDL_CreateRGBSurfaceWithFormat(0, shadow_w, shadow_h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if result == C_NULL
            return main
        end
        
        # Fill with transparent
        SDL2.SDL_FillRect(result, C_NULL, 0x00000000)
        SDL2.SDL_SetSurfaceBlendMode(result, SDL2.SDL_BLENDMODE_BLEND)
        
        # Blit shadow first
        offset_blit!(result, shadow, 0, 0)
        
        # Calculate main surface position (centered)
        main_x = (shadow_w - main_w) ÷ 2
        main_y = (shadow_h - main_h) ÷ 2
        
        # Blit main surface on top
        offset_blit!(result, main, main_x, main_y)
        
        return result
    end
end
