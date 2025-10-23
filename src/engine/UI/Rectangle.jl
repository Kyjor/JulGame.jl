module RectangleModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    using JulGame.EffectsModule
    using JulGame.EffectRendererModule
    using JulGame.EffectCacheModule
    
    export Rectangle
    mutable struct Rectangle <: UI.UIElement
        color::NTuple{4, Int}
        fillMode::Bool
        id::String
        isActive::Bool
        isWorldEntity::Bool
        name::String
        persistentBetweenScenes::Bool
        position::Math.Vector2
        size::Math.Vector2
        borderRadius::Int
        borderWidth::Int
        borderColor::NTuple{4, Int}
        isHovered::Bool
        layer::Int
        #  effects support
        effects::Vector{Any}  # Will hold Effect objects
        effectTexture::Union{Ptr{SDL2.SDL_Texture}, Ptr{Nothing}}
        needsEffectUpdate::Bool
        effectCacheKey::String
        
        function Rectangle(;
            id::String=JulGame.generate_uuid(), 
            name::String = "TextBox", 
            anchor::Symbol = :none,
            anchorOffset::Math.Vector2 = Math.Vector2(0,0), 
            isWorldEntity::Bool=false, 
            layer::Int=0,
            position::Math.Vector2 = Math.Vector2(0,0), 
            clickEvents::Vector{Function} = Function[],
            hoverEnterEvents::Vector{Function} = Function[],
            hoverExitEvents::Vector{Function} = Function[],
            isActive::Bool=true,
            persistentBetweenScenes::Bool=false,
            color::NTuple{4, Int}=(255, 255, 255, 255), 
            parent::Union{UI.UIElement, Nothing, Any}=nothing,
            fillMode::Bool=true,
            borderRadius::Int=0, 
            borderWidth::Int=0, 
            borderColor::NTuple{4, Int}=(0, 0, 0, 255), 
            size::Math.Vector2 = Math.Vector2(0, 0)
        )                  
            this = new()
            
            # Set fields that are part of the Rectangle struct
            this.color = color
            this.fillMode = fillMode
            this.id = id
            this.isActive = isActive
            this.isWorldEntity = isWorldEntity
            this.name = name
            this.persistentBetweenScenes = persistentBetweenScenes
            this.position = position
            this.size = size
            this.borderRadius = borderRadius
            this.borderWidth = borderWidth
            this.borderColor = borderColor
            this.isHovered = false
            this.layer = layer
            
            # Initialize effects
            this.effects = Any[]
            this.effectTexture = C_NULL
            this.needsEffectUpdate = false
            this.effectCacheKey = ""
            
            # Now set fields that are part of UIElementInstance through the relationship system
            # These need to be set after the Rectangle is constructed
            this.anchor = JulGame.Enum{Any}(
                :center,
                :top,
                :bottom,
                :left,
                :right,
                :topLeft,
                :topRight,
                :bottomLeft,
                :bottomRight,
                :centerLeft,
                :centerRight,
                :centerTop,
                :centerBottom,
                :none
            )
            this.anchor.current_state = anchor
            this.anchorOffset = anchorOffset
            this.clickEvents = clickEvents
            this.hoverEnterEvents = hoverEnterEvents
            this.hoverExitEvents = hoverExitEvents
            this.parent = parent
            
            return this
        end
    end
    
    """
    Draw a filled arc (quarter circle) with center, radius, and start/end angles
    """
    function draw_filled_arc(renderer, x, y, radius, start_angle, end_angle, color)
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
            UInt8(color[4])
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
    function draw_rounded_rectangle(renderer, rect, radius, color, fill_mode)
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
            draw_filled_arc(renderer, top_left_center_x, top_left_center_y, 
                            radius, π, 3π/2, color)
            
            # Top-right corner (3π/2 to 2π)
            draw_filled_arc(renderer, top_right_center_x, top_right_center_y, 
                            radius, 3π/2, 2π, color)
            
            # Bottom-left corner (π/2 to π)
            draw_filled_arc(renderer, bottom_left_center_x, bottom_left_center_y, 
                            radius, π/2, π, color)
            
            # Bottom-right corner (0 to π/2)
            draw_filled_arc(renderer, bottom_right_center_x, bottom_right_center_y, 
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
    function draw_rounded_border(renderer, rect, radius, border_width, color)
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
                false
            )
        end
    end
    
    function UI.render(this::Rectangle)
        if !this.isActive
            return
        end
        
        # Apply anchor positioning
        UI.align_to_anchor(this)
        
        # Update effects if needed
        if this.needsEffectUpdate && !isempty(this.effects)
            @debug "Updating effects for rectangle: $(this.name)"
            update_effects(this)
        end
        
        # Use effect texture if available, otherwise use direct rendering
        if !isempty(this.effects) && this.effectTexture != C_NULL
            render_rectangle_with_effects(this)
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
                this.fillMode
            )
            
            # Draw border if borderWidth > 0
            if this.borderWidth > 0
                draw_rounded_border(
                    JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                    rect,
                    this.borderRadius,
                    this.borderWidth,
                    this.borderColor
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
                UInt8(this.color[4])
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

    #= function UI.add_hover_event(this::Rectangle, event)
        push!(this.hoverEvents, event)
    end =#

    function UI.destroy(this::Rectangle)
        # Effect textures may be cached and reused elsewhere. Just clear the reference.
        if this.effectTexture != C_NULL
            this.effectTexture = C_NULL
        end
        
        MAIN.scene.uiElements = filter(x -> x !== this, MAIN.scene.uiElements)
    end
    
    #  effects API
    function apply_effects!(this::Rectangle, effects::Vector)
        this.effects = Any[effect for effect in effects]
        # compute cache key and flag update only when changed
        newKey = generate_effect_cache_key(this)
        if this.effectCacheKey != newKey
            this.effectCacheKey = newKey
            this.needsEffectUpdate = true
        else
            @debug "Rectangle.apply_effects!: cache key unchanged; skipping recompute" name=this.name
        end
        return this
    end
    
    function apply_style!(this::Rectangle, style)
        return apply_effects!(this, style.effects)
    end
    
    function update_effects(this::Rectangle)
        @info("update_effects: Starting for rectangle $(this.name)")
        @info("update_effects: Rectangle state - size=$(this.size), position=$(this.position), color=$(this.color)")
        
        if isempty(this.effects)
            @info("update_effects: No effects to apply")
            return
        end
        # Use cached texture if available
        if haskey(EFFECT_CACHE, this.effectCacheKey)
            @info("Rectangle using cached effect texture", name=this.name, key=this.effectCacheKey)
            this.effectTexture = EFFECT_CACHE[this.effectCacheKey]
            this.needsEffectUpdate = false
            return
        end

        if JulGame.Renderer == C_NULL
            @error("update_effects: Renderer is NULL")
            return
        end
        @info("update_effects: Creating RectangleTarget")
        # Create target for effects and apply
        target = EffectsModule.RectangleTarget(this)
        try
            @info("update_effects: Applying effects")
            result = EffectRendererModule.apply_effects!(target, this.effects)
            if result isa EffectsModule.RectangleTarget
                # effectTexture should be set by renderer
                @info("update_effects: Effect application succeeded, effectTexture=$(this.effectTexture)")
                if this.effectTexture != C_NULL
                    # Cache it
                    @info("update_effects: Caching effect texture")
                    cache_effect_texture(this.effectCacheKey, this.effectTexture)
                else
                    @error("update_effects: effectTexture is NULL after applying effects")
                end
                this.needsEffectUpdate = false
            else
                @error("update_effects: Result is not a RectangleTarget")
            end
        catch e
            @error "Failed to apply effects to Rectangle" exception=(e, catch_backtrace())
            this.needsEffectUpdate = false
        end
    end
    
    function render_rectangle_with_effects(this::Rectangle)
        # @info("render_rectangle_with_effects: Starting for rectangle $(this.name)")
        # @info("render_rectangle_with_effects: effectTexture=$(this.effectTexture)")
        
        camera = MAIN.scene.camera
        
        # Calculate position
        if this.isWorldEntity && camera !== nothing
            posX = (this.position.x - (camera.position.x + camera.offset.x)) * SCALE_UNITS
            posY = (this.position.y - (camera.position.y + camera.offset.y)) * SCALE_UNITS
            width = this.size.x * SCALE_UNITS
            height = this.size.y * SCALE_UNITS
        else
            posX = this.position.x
            posY = this.position.y
            width = this.size.x
            height = this.size.y
        end
        
     #   @info("render_rectangle_with_effects: Rendering at ($posX, $posY) with size $(width)x$(height)")
        
        # Render effect texture
        result = SDL2.SDL_RenderCopyF(
            JulGame.Renderer,
            this.effectTexture,
            C_NULL,
            Ref(SDL2.SDL_FRect(Float32(posX), Float32(posY), Float32(width), Float32(height)))
        )
        
        if result != 0
            @error("render_rectangle_with_effects: SDL_RenderCopyF failed: $(unsafe_string(SDL2.SDL_GetError()))")
        else
         #   @info("render_rectangle_with_effects: Successfully rendered effect texture")
        end
    end

    # Helpers to serialize effects and generate cache keys (mirrors UIImage)
    function serialize_effects(effects::Vector{Any})::String
        if isempty(effects)
            return "[]"
        end
        parts = String[]
        for eff in effects
            T = typeof(eff)
            fnames = fieldnames(T)
            vals = String[]
            for f in fnames
                v = getfield(eff, f)
                if v isa Ptr
                    push!(vals, string(f, "=Ptr"))
                else
                    push!(vals, string(f, "=", v))
                end
            end
            push!(parts, string(nameof(T), "(", join(vals, ","), ")"))
        end
        return "[" * join(parts, ";") * "]"
    end

    function generate_effect_cache_key(this::Rectangle)::String
        # Cache key excludes position/rotation (and other transform-only changes)
        # Effects depend on size, color, border properties, and effect params
        content = string(
            this.size, "|",
            this.color, "|",
            this.borderRadius, "|",
            this.borderWidth, "|",
            this.borderColor, "|",
            this.fillMode, "|",
            serialize_effects(this.effects)
        )
        return string(hash(content))
    end

    # Local effects cache for Rectangle
    const EFFECT_CACHE = Dict{String, Ptr{SDL2.SDL_Texture}}()
    const MAX_CACHE_SIZE = 100

    function cache_effect_texture(key::String, texture::Ptr{SDL2.SDL_Texture})
        EFFECT_CACHE[key] = texture
        @debug("Cached Rectangle effect texture for key: $key")
    end

    function clear_effects_cache()
        for (key, texture) in EFFECT_CACHE
            if texture != C_NULL
                SDL2.SDL_DestroyTexture(texture)
            end
        end
        empty!(EFFECT_CACHE)
    end
end 