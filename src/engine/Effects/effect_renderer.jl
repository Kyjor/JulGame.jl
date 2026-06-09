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

    export apply_effects!, to_surface, from_surface, apply_effects_chain!, process_effects_to_surface

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
            # Update sprite's effect texture (not base texture)
            if target.sprite.effectTexture != C_NULL
                SDL2.SDL_DestroyTexture(target.sprite.effectTexture)
            end
            target.sprite.effectTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            return target
        elseif target isa EffectsModule.RectangleTarget
            # Update rectangle's effect texture
            @debug("from_surface: Creating effect texture for rectangle")
            if target.rectangle.effectTexture != C_NULL
                @debug("from_surface: Destroying old effect texture")
                SDL2.SDL_DestroyTexture(target.rectangle.effectTexture)
            end
            target.rectangle.effectTexture = SDL2.SDL_CreateTextureFromSurface(JulGame.Renderer, surface)
            if target.rectangle.effectTexture == C_NULL
                @error("from_surface: Failed to create texture from surface: $(unsafe_string(SDL2.SDL_GetError()))")
            else
                SDL2.SDL_SetTextureBlendMode(target.rectangle.effectTexture, SDL2.SDL_BLENDMODE_BLEND)
                w = Ref{Cint}(0); h = Ref{Cint}(0)
                SDL2.SDL_QueryTexture(target.rectangle.effectTexture, C_NULL, C_NULL, w, h)
                @debug("from_surface: Created effect texture $(w[])x$(h[]) for rectangle")
            end
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
            # Note: UIImage now manages its own texture lifecycle, so we don't destroy here
            # The old texture cleanup is handled in UIImage.update_effects()
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
        
        # Get the renderer
        renderer = JulGame.Renderer
        if renderer == C_NULL
            @error("No renderer available for texture to surface conversion")
            return C_NULL
        end
        
        # Create a target texture and render the source texture into it
        target_tex = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_RGBA32, SDL2.SDL_TEXTUREACCESS_TARGET, w[], h[])
        if target_tex == C_NULL
            @error("Failed to create target texture for texture_to_surface")
            return C_NULL
        end
        old_target = SDL2.SDL_GetRenderTarget(renderer)
        SDL2.SDL_SetRenderTarget(renderer, target_tex)
        SDL2.SDL_SetRenderDrawBlendMode(renderer, SDL2.SDL_BLENDMODE_BLEND)
        SDL2.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0)
        SDL2.SDL_RenderClear(renderer)
        SDL2.SDL_RenderCopy(renderer, texture, C_NULL, C_NULL)
        
        # Read pixels back into a new surface
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w[], h[], 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface != C_NULL
            arr = unsafe_wrap(Array, surface, 10; own=false)
            SDL2.SDL_RenderReadPixels(renderer, C_NULL, SDL2.SDL_PIXELFORMAT_RGBA32, arr[1].pixels, arr[1].pitch)
        end
        
        # Restore and cleanup
        SDL2.SDL_SetRenderTarget(renderer, old_target)
        SDL2.SDL_DestroyTexture(target_tex)
        
        return surface
    end

    function render_rectangle_to_surface(rect::Any)::Ptr{SDL2.SDL_Surface}
        if rect === nothing
            @error("render_rectangle_to_surface: rect is nothing")
            return C_NULL
        end
    
        # Calculate surface dimensions including border
        border_padding = rect.borderWidth > 0 ? rect.borderWidth : 0
        w = Int32(rect.size.x + border_padding * 2)
        h = Int32(rect.size.y + border_padding * 2)
        
        renderer = JulGame.Renderer
        if renderer == C_NULL
            @error("No renderer available for rectangle effects")
            return C_NULL
        end
    
        # Create target texture
        target_tex = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_RGBA32,
                                            SDL2.SDL_TEXTUREACCESS_TARGET, w, h)
        if target_tex == C_NULL
            @error("Failed to create target texture: $(unsafe_string(SDL2.SDL_GetError()))")
            return C_NULL
        end
    
        # Save state
        old_target = SDL2.SDL_GetRenderTarget(renderer)
        # Set render target and ensure we start clean
        SDL2.SDL_SetRenderTarget(renderer, target_tex)

        # Disable blending so we write *exact* color values (including alpha)
        SDL2.SDL_SetRenderDrawBlendMode(renderer, SDL2.SDL_BLENDMODE_NONE)

        # Clear to transparent background
        SDL2.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0)
        SDL2.SDL_RenderClear(renderer)

        # Calculate rectangle position with border padding
        rect_x = Float32(border_padding)
        rect_y = Float32(border_padding)
        rect_w = Float32(rect.size.x)
        rect_h = Float32(rect.size.y)
        
        # Draw border first (if present)
        if rect.borderWidth > 0
            SDL2.SDL_SetRenderDrawColor(renderer, rect.borderColor[1], rect.borderColor[2], rect.borderColor[3], rect.borderColor[4])
            
            if rect.borderRadius > 0
                # Draw rounded border
                draw_rounded_border_to_surface(renderer, rect_x, rect_y, rect_w, rect_h, rect.borderRadius, rect.borderWidth, rect.borderColor)
            else
                # Draw regular border
                for i in 0:rect.borderWidth-1
                    border_rect = SDL2.SDL_FRect(
                        rect_x - Float32(i),
                        rect_y - Float32(i),
                        rect_w + Float32(i * 2),
                        rect_h + Float32(i * 2)
                    )
                    SDL2.SDL_RenderDrawRectF(renderer, Ref(border_rect))
                end
            end
        end

        # Draw the main rectangle
        SDL2.SDL_SetRenderDrawColor(renderer, rect.color[1], rect.color[2], rect.color[3], rect.color[4])
        
        main_rect = SDL2.SDL_FRect(rect_x, rect_y, rect_w, rect_h)
        
        if rect.borderRadius > 0
            # Draw rounded rectangle
            draw_rounded_rectangle_to_surface(renderer, main_rect, rect.borderRadius, rect.color, rect.fillMode)
        else
            # Draw regular rectangle
            if rect.fillMode
                SDL2.SDL_RenderFillRectF(renderer, Ref(main_rect))
            else
                SDL2.SDL_RenderDrawRectF(renderer, Ref(main_rect))
            end
        end
    
        # Create surface to read pixels into
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, w, h, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface == C_NULL
            @error("Failed to create RGB surface")
            SDL2.SDL_SetRenderTarget(renderer, old_target)
            SDL2.SDL_DestroyTexture(target_tex)
            return C_NULL
        end
    
        # Read pixels
        s = unsafe_load(Ptr{SDL2.SDL_Surface}(surface))
        SDL2.SDL_RenderFlush(renderer)
        rr = SDL2.SDL_RenderReadPixels(renderer, C_NULL, SDL2.SDL_PIXELFORMAT_RGBA32,
                                       s.pixels, s.pitch)
        if rr != 0
            @error("SDL_RenderReadPixels failed: $(unsafe_string(SDL2.SDL_GetError()))")
        else
            # Log pixel info
            @debug("Read pixels OK", pixels_ptr = s.pixels, pitch = s.pitch, w = w, h = h)
    
            # Save to BMP for verification
            # filename = joinpath(pwd(), "rectangle_debug.bmp")
            # save_surface_debug(surface, filename)
        end
    
        # Restore renderer state
        SDL2.SDL_SetRenderTarget(renderer, old_target)
        SDL2.SDL_DestroyTexture(target_tex)
    
        return surface
    end
    
    # Helper function to draw filled arc for rounded rectangles
    function draw_filled_arc_to_surface(renderer, x, y, radius, start_angle, end_angle, color)
        # Save the current renderer color
        r = Ref(UInt8(0))
        g = Ref(UInt8(0))
        b = Ref(UInt8(0))
        a = Ref(UInt8(0))
        SDL2.SDL_GetRenderDrawColor(renderer, r, g, b, a)
        
        # Set the color for the arc
        SDL2.SDL_SetRenderDrawColor(
            renderer, 
            UInt8(color[1]), 
            UInt8(color[2]), 
            UInt8(color[3]), 
            UInt8(color[4])
        )
        
        # Draw the filled arc by drawing lines from the center to points on the arc
        steps = max(10, radius ÷ 2)
        angle_step = (end_angle - start_angle) / steps
        
        for i in 0:steps
            angle = start_angle + i * angle_step
            end_x = x + radius * cos(angle)
            end_y = y + radius * sin(angle)
            
            SDL2.SDL_RenderDrawLineF(
                renderer,
                Float32(x),
                Float32(y),
                Float32(end_x),
                Float32(end_y)
            )
        end
        
        # Restore the original renderer color
        SDL2.SDL_SetRenderDrawColor(renderer, r[], g[], b[], a[])
    end
    
    # Helper function to draw rounded rectangle to surface
    function draw_rounded_rectangle_to_surface(renderer, rect, radius, color, fill_mode)
        # Ensure the radius isn't too large for the rectangle
        radius = min(radius, min(rect.w, rect.h) ÷ 2)
        
        if radius <= 0
            # If radius is 0 or negative, draw a regular rectangle
            SDL2.SDL_SetRenderDrawColor(
                renderer,
                UInt8(color[1]),
                UInt8(color[2]),
                UInt8(color[3]),
                UInt8(color[4])
            )
            
            if fill_mode
                SDL2.SDL_RenderFillRectF(renderer, Ref(rect))
            else
                SDL2.SDL_RenderDrawRectF(renderer, Ref(rect))
            end
            return
        end
        
        # Center points for the corner arcs
        top_left_center_x = rect.x + radius
        top_left_center_y = rect.y + radius
        
        top_right_center_x = rect.x + rect.w - radius
        top_right_center_y = rect.y + radius
        
        bottom_left_center_x = rect.x + radius
        bottom_left_center_y = rect.y + rect.h - radius
        
        bottom_right_center_x = rect.x + rect.w - radius
        bottom_right_center_y = rect.y + rect.h - radius
        
        if fill_mode
            # Draw the main rectangle (excluding corners)
            main_rect = SDL2.SDL_FRect(
                rect.x,
                rect.y + radius,
                rect.w,
                rect.h - 2 * radius
            )
            
            SDL2.SDL_SetRenderDrawColor(
                renderer,
                UInt8(color[1]),
                UInt8(color[2]),
                UInt8(color[3]),
                UInt8(color[4])
            )
            
            SDL2.SDL_RenderFillRectF(renderer, Ref(main_rect))
            
            # Draw the top and bottom rectangles (excluding corners)
            top_rect = SDL2.SDL_FRect(
                rect.x + radius,
                rect.y,
                rect.w - 2 * radius,
                radius
            )
            
            bottom_rect = SDL2.SDL_FRect(
                rect.x + radius,
                rect.y + rect.h - radius,
                rect.w - 2 * radius,
                radius
            )
            
            SDL2.SDL_RenderFillRectF(renderer, Ref(top_rect))
            SDL2.SDL_RenderFillRectF(renderer, Ref(bottom_rect))
            
            # Draw the four corner arcs
            # Top-left corner (π to 3π/2)
            draw_filled_arc_to_surface(renderer, top_left_center_x, top_left_center_y, 
                            radius, π, 3π/2, color)
            
            # Top-right corner (3π/2 to 2π)
            draw_filled_arc_to_surface(renderer, top_right_center_x, top_right_center_y, 
                            radius, 3π/2, 2π, color)
            
            # Bottom-left corner (π/2 to π)
            draw_filled_arc_to_surface(renderer, bottom_left_center_x, bottom_left_center_y, 
                            radius, π/2, π, color)
            
            # Bottom-right corner (0 to π/2)
            draw_filled_arc_to_surface(renderer, bottom_right_center_x, bottom_right_center_y, 
                            radius, 0, π/2, color)
        else
            # Draw the outline of a rounded rectangle
            SDL2.SDL_SetRenderDrawColor(
                renderer,
                UInt8(color[1]),
                UInt8(color[2]),
                UInt8(color[3]),
                UInt8(color[4])
            )
            
            # Draw the top line
            SDL2.SDL_RenderDrawLineF(
                renderer,
                Float32(rect.x + radius),
                Float32(rect.y),
                Float32(rect.x + rect.w - radius),
                Float32(rect.y)
            )
            
            # Draw the bottom line
            SDL2.SDL_RenderDrawLineF(
                renderer,
                Float32(rect.x + radius),
                Float32(rect.y + rect.h),
                Float32(rect.x + rect.w - radius),
                Float32(rect.y + rect.h)
            )
            
            # Draw the left line
            SDL2.SDL_RenderDrawLineF(
                renderer,
                Float32(rect.x),
                Float32(rect.y + radius),
                Float32(rect.x),
                Float32(rect.y + rect.h - radius)
            )
            
            # Draw the right line
            SDL2.SDL_RenderDrawLineF(
                renderer,
                Float32(rect.x + rect.w),
                Float32(rect.y + radius),
                Float32(rect.x + rect.w),
                Float32(rect.y + rect.h - radius)
            )
            
            # Draw corner arcs using line segments
            steps = max(10, radius ÷ 2)
            
            # Top-left corner
            for i in 0:steps
                angle1 = π + i * (π/2) / steps
                angle2 = π + (i + 1) * (π/2) / steps
                
                x1 = top_left_center_x + radius * cos(angle1)
                y1 = top_left_center_y + radius * sin(angle1)
                x2 = top_left_center_x + radius * cos(angle2)
                y2 = top_left_center_y + radius * sin(angle2)
                
                SDL2.SDL_RenderDrawLineF(renderer, Float32(x1), Float32(y1), Float32(x2), Float32(y2))
            end
            
            # Top-right corner
            for i in 0:steps
                angle1 = 3π/2 + i * (π/2) / steps
                angle2 = 3π/2 + (i + 1) * (π/2) / steps
                
                x1 = top_right_center_x + radius * cos(angle1)
                y1 = top_right_center_y + radius * sin(angle1)
                x2 = top_right_center_x + radius * cos(angle2)
                y2 = top_right_center_y + radius * sin(angle2)
                
                SDL2.SDL_RenderDrawLineF(renderer, Float32(x1), Float32(y1), Float32(x2), Float32(y2))
            end
            
            # Bottom-left corner
            for i in 0:steps
                angle1 = π/2 + i * (π/2) / steps
                angle2 = π/2 + (i + 1) * (π/2) / steps
                
                x1 = bottom_left_center_x + radius * cos(angle1)
                y1 = bottom_left_center_y + radius * sin(angle1)
                x2 = bottom_left_center_x + radius * cos(angle2)
                y2 = bottom_left_center_y + radius * sin(angle2)
                
                SDL2.SDL_RenderDrawLineF(renderer, Float32(x1), Float32(y1), Float32(x2), Float32(y2))
            end
            
            # Bottom-right corner
            for i in 0:steps
                angle1 = 0 + i * (π/2) / steps
                angle2 = 0 + (i + 1) * (π/2) / steps
                
                x1 = bottom_right_center_x + radius * cos(angle1)
                y1 = bottom_right_center_y + radius * sin(angle1)
                x2 = bottom_right_center_x + radius * cos(angle2)
                y2 = bottom_right_center_y + radius * sin(angle2)
                
                SDL2.SDL_RenderDrawLineF(renderer, Float32(x1), Float32(y1), Float32(x2), Float32(y2))
            end
        end
    end
    
    # Helper function to draw rounded border to surface
    function draw_rounded_border_to_surface(renderer, x, y, w, h, radius, border_width, color)
        # Draw multiple concentric borders
        for i in 0:border_width-1
            border_rect = SDL2.SDL_FRect(
                x - Float32(i),
                y - Float32(i),
                w + Float32(i * 2),
                h + Float32(i * 2)
            )
            
            draw_rounded_rectangle_to_surface(
                renderer, 
                border_rect, 
                radius + i, 
                color, 
                false
            )
        end
    end
    
    function save_surface_debug(surface::Ptr{SDL2.SDL_Surface}, path::String)
        if surface == C_NULL
            println("⚠️ Tried to save a null surface.")
            return
        end
    
        # Create an RWops stream for writing the BMP
        rw = SDL2.SDL_RWFromFile(path, "wb")
        if rw == C_NULL
            println("❌ SDL_RWFromFile failed: ", unsafe_string(SDL2.SDL_GetError()))
            return
        end
    
        # Save the surface
        result = SDL2.SDL_SaveBMP_RW(surface, rw, 1)  # 1 means "close stream after write"
    
        if result != 0
            println("❌ SDL_SaveBMP_RW failed: ", unsafe_string(SDL2.SDL_GetError()))
        else
            println("✅ Saved surface as BMP to: $path")
        end
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
        
        # Get the renderer
        renderer = JulGame.Renderer
        if renderer == C_NULL
            @error("No renderer available for line effects")
            return C_NULL
        end
        
        # Create a target texture and draw the line into it
        target_tex = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_RGBA32, SDL2.SDL_TEXTUREACCESS_TARGET, width, height)
        if target_tex == C_NULL
            @error("render_line_to_surface: Failed to create target texture")
            return C_NULL
        end
        old_target = SDL2.SDL_GetRenderTarget(renderer)
        SDL2.SDL_SetRenderTarget(renderer, target_tex)
        SDL2.SDL_SetRenderDrawBlendMode(renderer, SDL2.SDL_BLENDMODE_BLEND)
        SDL2.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0)
        SDL2.SDL_RenderClear(renderer)
        
        # Draw line
        SDL2.SDL_SetRenderDrawColor(renderer, line.color...)
        start_x = line.startPoint.x - min_x + line.thickness
        start_y = line.startPoint.y - min_y + line.thickness
        end_x = line.endPoint.x - min_x + line.thickness
        end_y = line.endPoint.y - min_y + line.thickness
        if line.thickness == 1
            SDL2.SDL_RenderDrawLineF(renderer, Float32(start_x), Float32(start_y), Float32(end_x), Float32(end_y))
        else
            for i in 0:(line.thickness-1)
                offset_x = cos(atan2(end_y - start_y, end_x - start_x) + π/2) * i
                offset_y = sin(atan2(end_y - start_y, end_x - start_x) + π/2) * i
                SDL2.SDL_RenderDrawLineF(renderer, 
                    Float32(start_x + offset_x), Float32(start_y + offset_y), 
                    Float32(end_x + offset_x), Float32(end_y + offset_y))
            end
        end
        
        # Read pixels back into a surface
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface != C_NULL
            arr = unsafe_wrap(Array, surface, 10; own=false)
            SDL2.SDL_RenderFlush(renderer)
            SDL2.SDL_RenderReadPixels(renderer, C_NULL, SDL2.SDL_PIXELFORMAT_RGBA32, arr[1].pixels, arr[1].pitch)
        end
        
        # Restore and cleanup
        SDL2.SDL_SetRenderTarget(renderer, old_target)
        SDL2.SDL_DestroyTexture(target_tex)
        return surface
    end

    # Render Mesh3D to surface (simplified)
    function render_mesh3d_to_surface(mesh::Any)::Ptr{SDL2.SDL_Surface}
        if mesh == nothing
            return C_NULL
        end
        
        # Get the renderer
        renderer = JulGame.Renderer
        if renderer == C_NULL
            @error("No renderer available for mesh3d effects")
            return C_NULL
        end
        
        local width = 100
        local height = 100
        target_tex = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_RGBA32, SDL2.SDL_TEXTUREACCESS_TARGET, width, height)
        if target_tex == C_NULL
            @error("render_mesh3d_to_surface: Failed to create target texture")
            return C_NULL
        end
        old_target = SDL2.SDL_GetRenderTarget(renderer)
        SDL2.SDL_SetRenderTarget(renderer, target_tex)
        SDL2.SDL_SetRenderDrawBlendMode(renderer, SDL2.SDL_BLENDMODE_BLEND)
        SDL2.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 0)
        SDL2.SDL_RenderClear(renderer)
        
        # Draw a simple placeholder (in real implementation, render the 3D mesh)
        SDL2.SDL_SetRenderDrawColor(renderer, 255, 255, 255, 255)
        SDL2.SDL_RenderFillRectF(renderer, Ref(SDL2.SDL_FRect(10, 10, 80, 80)))
        
        # Read pixels back into a surface
        surface = SDL2.SDL_CreateRGBSurfaceWithFormat(0, width, height, 32, SDL2.SDL_PIXELFORMAT_RGBA32)
        if surface != C_NULL
            arr = unsafe_wrap(Array, surface, 10; own=false)
            SDL2.SDL_RenderReadPixels(renderer, C_NULL, SDL2.SDL_PIXELFORMAT_RGBA32, arr[1].pixels, arr[1].pitch)
        end
        
        # Restore and cleanup
        SDL2.SDL_SetRenderTarget(renderer, old_target)
        SDL2.SDL_DestroyTexture(target_tex)
        return surface
    end

    # Apply effects chain to surface
    function apply_effects_chain!(baseSurface::Ptr{SDL2.SDL_Surface}, effects::Vector{Any}, target::EffectsModule.EffectTarget)
        if baseSurface == C_NULL || isempty(effects)
            return baseSurface
        end
        
        @debug "Applying effects chain to surface"
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
            elseif eff isa EffectsModule.BevelEmbossEffect
                emb = EffectsModule.BevelEmbossEffect(;
                    style = eff.style,
                    size_px = eff.size_px,
                    soften = eff.soften,
                    depth = eff.depth,
                    angle = eff.angle,
                    altitude = eff.altitude,
                    direction_up = eff.direction_up,
                    contour_enabled = eff.contour_enabled,
                    range_pct = eff.range_pct,
                    contour_lut = eff.contour_lut,
                    contour_antialiased = eff.contour_antialiased,
                    gloss_enabled = eff.gloss_enabled,
                    gloss_lut = eff.gloss_lut,
                    gloss_antialiased = eff.gloss_antialiased,
                    texture_enabled = eff.texture_enabled,
                    texture_path = eff.texture_path,
                    texture_tile = eff.texture_tile,
                    texture_scale = eff.texture_scale,
                    texture_phase_h_pct = eff.texture_phase_h_pct,
                    texture_phase_v_pct = eff.texture_phase_v_pct,
                    texture_align_with_layer = eff.texture_align_with_layer,
                    texture_depth = eff.texture_depth,
                    texture_invert = eff.texture_invert,
                    highlight_color = resolve_color(eff.highlight_color, target),
                    shadow_color = resolve_color(eff.shadow_color, target),
                    highlight_opacity = eff.highlight_opacity,
                    shadow_opacity = eff.shadow_opacity,
                    highlight_blend = eff.highlight_blend,
                    shadow_blend = eff.shadow_blend,
                    intensity = eff.intensity,
                )
                beveled = apply_bevel_emboss_psd(work, emb)
                if beveled == C_NULL
                    @debug("Failed to create bevel emboss surface")
                    SDL2.SDL_FreeSurface(work)
                    return baseSurface
                end
                if beveled != work
                    SDL2.SDL_FreeSurface(work)
                end
                work = beveled
            elseif eff isa EffectsModule.BevelEffect1
                beveled = apply_bevel_effect_1(work, eff)
                if beveled == C_NULL
                    @debug("Failed to create bevel1 surface")
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
                glowed = create_outer_glow_surface(work, eff.radius, resolved_color, eff.force_white, eff.fade_amount, eff.fade_curve)
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

    # CPU-only effect processing (chain + drop shadows). Does not touch the
    # renderer, so it is safe to run off the main thread for surface-based
    # effects (e.g. for async effect-texture prewarming).
    function process_effects_to_surface(base_surface::Ptr{SDL2.SDL_Surface}, effects::Vector{Any}, target::EffectsModule.EffectTarget)::Ptr{SDL2.SDL_Surface}
        # Apply effects
        processed_surface = apply_effects_chain!(base_surface, effects, target)
        if processed_surface == C_NULL
            return C_NULL
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
        
        return processed_surface
    end

    # Main API function
    function apply_effects!(target::EffectsModule.EffectTarget, effects::Vector{Any})
        @debug "Applying effects to target" target=target effects=effects
        if isempty(effects)
            return target
        end
        
        # Convert to surface
        base_surface = to_surface(target)
        if base_surface == C_NULL
            @error("Failed to convert target to surface")
            return target
        end
        
        processed_surface = process_effects_to_surface(base_surface, effects, target)
        if processed_surface == C_NULL
            @error("Failed to apply effects")
            # Same ownership rules as the cleanup below: surface/image/sprite
            # targets own their base surface (sprites may share a cached one).
            if !(target isa EffectsModule.SurfaceTarget || target isa EffectsModule.ImageTarget || target isa EffectsModule.SpriteTarget)
                SDL2.SDL_FreeSurface(base_surface)
            end
            return target
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
