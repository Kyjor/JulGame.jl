module RectangleModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    
    export Rectangle
    mutable struct Rectangle
        alpha::Int32
        color::Tuple{Int32, Int32, Int32, Int32}
        fillMode::Bool
        id::String
        isActive::Bool
        isWorldEntity::Bool
        name::String
        persistentBetweenScenes::Bool
        position::Math.Vector2
        size::Math.Vector2
        borderRadius::Int32
        borderWidth::Int32
        borderColor::Tuple{Int32, Int32, Int32, Int32}
        isHovered::Bool
        clickEvents::Vector{Function}
        function Rectangle(name::String, position::Math.Vector2, size::Math.Vector2, color::Tuple{Int32, Int32, Int32, Int32}=(Int32(255), Int32(255), Int32(255), Int32(255)), 
                           fillMode::Bool=true; id::String=JulGame.generate_uuid(), isWorldEntity::Bool=false, 
                           borderRadius::Int32=Int32(0), borderWidth::Int32=Int32(0), borderColor::Tuple{Int32, Int32, Int32, Int32}=(Int32(0), Int32(0), Int32(0), Int32(255)))
            this = new()
            
            this.alpha = Int32(color[4])
            this.color = color
            this.fillMode = fillMode
            this.id = id
            this.isActive = true
            this.isWorldEntity = isWorldEntity
            this.name = name
            this.persistentBetweenScenes = false
            this.position = position
            this.size = size
            this.borderRadius = borderRadius
            this.borderWidth = borderWidth
            this.borderColor = borderColor
            this.isHovered = false
            this.clickEvents = []

            return this
        end
    end
    
    """
    Draw a filled arc (quarter circle) with center, radius, and start/end angles
    """
    function draw_filled_arc(renderer, x, y, radius, start_angle, end_angle, color, alpha)
        # Save the current renderer color and blend mode
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
            UInt8(alpha)
        )
        
        # Draw the filled arc by drawing lines from the center to points on the arc
        steps = max(10, radius ÷ 2)  # Number of steps based on radius size
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
    
    """
    Draw a rounded rectangle with the specified border radius
    """
    function draw_rounded_rectangle(renderer, rect, radius, color, alpha, fill_mode)
        # Ensure the radius isn't too large for the rectangle
        radius = min(radius, min(rect.w, rect.h) ÷ 2)
        
        if radius <= 0
            # If radius is 0 or negative, draw a regular rectangle
            SDL2.SDL_SetRenderDrawColor(
                renderer,
                UInt8(color[1]),
                UInt8(color[2]),
                UInt8(color[3]),
                UInt8(alpha)
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
                UInt8(alpha)
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
            draw_filled_arc(renderer, top_left_center_x, top_left_center_y, 
                            radius, π, 3π/2, color, alpha)
            
            # Top-right corner (3π/2 to 2π)
            draw_filled_arc(renderer, top_right_center_x, top_right_center_y, 
                            radius, 3π/2, 2π, color, alpha)
            
            # Bottom-left corner (π/2 to π)
            draw_filled_arc(renderer, bottom_left_center_x, bottom_left_center_y, 
                            radius, π/2, π, color, alpha)
            
            # Bottom-right corner (0 to π/2)
            draw_filled_arc(renderer, bottom_right_center_x, bottom_right_center_y, 
                            radius, 0, π/2, color, alpha)
        else
            # Draw the outline of a rounded rectangle
            SDL2.SDL_SetRenderDrawColor(
                renderer,
                UInt8(color[1]),
                UInt8(color[2]),
                UInt8(color[3]),
                UInt8(alpha)
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
            
            # Draw corner arcs
            # Draw corner arcs using approx. line segments
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
    
    """
    Draw a border around a rounded rectangle
    """
    function draw_rounded_border(renderer, rect, radius, border_width, color, alpha)
        # Draw multiple concentric borders
        for i in 0:border_width-1
            border_rect = SDL2.SDL_FRect(
                rect.x - Float32(i),
                rect.y - Float32(i),
                rect.w + Float32(i * 2),
                rect.h + Float32(i * 2)
            )
            
            draw_rounded_rectangle(
                renderer, 
                border_rect, 
                radius + i, 
                color, 
                alpha, 
                false
            )
        end
    end
    
    function UI.render(this::Rectangle)
        if !this.isActive
            return
        end
        
        camera = MAIN.scene.camera
        
        # Calculate drawing coordinates based on world or screen position
        if this.isWorldEntity && camera !== nothing
            # Calculate position in screen space
            posX = (this.position.x - (camera.position.x + camera.offset.x)) * SCALE_UNITS
            posY = (this.position.y - (camera.position.y + camera.offset.y)) * SCALE_UNITS
            
            # For world entities, size needs to be scaled by SCALE_UNITS
            width = this.size.x * SCALE_UNITS
            height = this.size.y * SCALE_UNITS
            
            rect = SDL2.SDL_FRect(
                Float32(posX),
                Float32(posY),
                Float32(width),
                Float32(height)
            )
        else
            rect = SDL2.SDL_FRect(
                Float32(this.position.x),
                Float32(this.position.y),
                Float32(this.size.x),
                Float32(this.size.y)
            )
        end
        
        # Save current render draw color
        r = Ref(UInt8(0))
        g = Ref(UInt8(0))
        b = Ref(UInt8(0))
        a = Ref(UInt8(0))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r, g, b, a)
        
        SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
        
        # Draw the rectangle with or without rounded corners
        if this.borderRadius > 0
            # Draw with rounded corners
            draw_rounded_rectangle(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                rect,
                this.borderRadius,
                this.color,
                this.alpha,
                this.fillMode
            )
            
            # Draw border if borderWidth > 0
            if this.borderWidth > 0
                draw_rounded_border(
                    JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                    rect,
                    this.borderRadius,
                    this.borderWidth,
                    this.borderColor,
                    this.borderColor[4]
                )
            end
        else
            # Regular rectangle (no rounded corners)
            # Set new color
            SDL2.SDL_SetRenderDrawColor(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                UInt8(this.color[1]), 
                UInt8(this.color[2]), 
                UInt8(this.color[3]), 
                UInt8(this.alpha)
            )
            
            # Draw rectangle
            if this.fillMode
                SDL2.SDL_RenderFillRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(rect))
            else
                SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(rect))
            end
            
            # Draw border if borderWidth > 0
            if this.borderWidth > 0
                # Set border color
                SDL2.SDL_SetRenderDrawColor(
                    JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                    UInt8(this.borderColor[1]), 
                    UInt8(this.borderColor[2]), 
                    UInt8(this.borderColor[3]), 
                    UInt8(this.borderColor[4])
                )
                
                # Draw border
                for i in 0:this.borderWidth-1
                    border_rect = SDL2.SDL_FRect(
                        rect.x - Float32(i),
                        rect.y - Float32(i),
                        rect.w + Float32(i * 2),
                        rect.h + Float32(i * 2)
                    )
                    SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(border_rect))
                end
            end
        end
        
        # Restore original color
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r[], g[], b[], a[])
    end
    
    function UI.initialize(this::Rectangle)
        # Nothing needed for initialization
    end

    function UI.add_click_event(this::Rectangle, event)
        push!(this.clickEvents, event)
    end

    function UI.handle_event(this::Rectangle, evt, x, y)    
        if evt.type == evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
            for eventToCall in this.clickEvents
                Base.invokelatest(eventToCall,(evt = evt, x = x, y = y))
            end
        end
    end

    function UI.destroy(this::Rectangle)
        # Nothing needed for cleanup
    end
end 