module LineModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    using JulGame.EffectsModule
    using JulGame.EffectRendererModule
    using JulGame.EffectCacheModule
    
    export Line
    mutable struct Line
        color::NTuple{4, Int}
        id::String
        isActive::Bool
        isWorldEntity::Bool
        name::String
        persistentBetweenScenes::Bool
        startPoint::Math.Vector2
        endPoint::Math.Vector2
        thickness::Int
        layer::Int
        #  effects support
        effects::Vector{Any}  # Will hold Effect objects
        effectTexture::Union{Ptr{SDL2.SDL_Texture}, Ptr{Nothing}}
        needsEffectUpdate::Bool
        
        function Line(name::String, startPoint::Math.Vector2, endPoint::Math.Vector2, color::NTuple{4, Int}=(255, 255, 255, 255), 
                     thickness::Int=1; id::String=JulGame.generate_uuid(), isWorldEntity::Bool=false, layer::Int=0)
            this = new()
            
            this.color = color
            this.id = id
            this.isActive = true
            this.isWorldEntity = isWorldEntity
            this.name = name
            this.persistentBetweenScenes = false
            this.startPoint = startPoint
            this.endPoint = endPoint
            this.thickness = thickness
            this.layer = layer
            
            # Initialize effects
            this.effects = Any[]
            this.effectTexture = C_NULL
            this.needsEffectUpdate = false
            
            return this
        end
    end
    
    function UI.render(this::Line)
        if !this.isActive
            return
        end
        
        # Use effect texture if available, otherwise use direct rendering
        if !isempty(this.effects) && this.effectTexture != C_NULL
            render_line_with_effects(this)
            return
        end
        
        camera = MAIN.scene.camera
        
        # Calculate drawing coordinates based on world or screen position
        if this.isWorldEntity && camera !== nothing
            S = JulGame.pixels_per_world_unit(camera)
            startX = (this.startPoint.x - (camera.position.x + camera.offset.x)) * S
            startY = (this.startPoint.y - (camera.position.y + camera.offset.y)) * S
            endX = (this.endPoint.x - (camera.position.x + camera.offset.x)) * S
            endY = (this.endPoint.y - (camera.position.y + camera.offset.y)) * S
        else
            startX = this.startPoint.x
            startY = this.startPoint.y
            endX = this.endPoint.x
            endY = this.endPoint.y
        end
        
        # Save current render draw color
        r = Ref(UInt8(0))
        g = Ref(UInt8(0))
        b = Ref(UInt8(0))
        a = Ref(UInt8(0))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r, g, b, a)
        
        # Set new color
        SDL2.SDL_SetRenderDrawColor(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
            UInt8(this.color[1]), 
            UInt8(this.color[2]), 
            UInt8(this.color[3]), 
            UInt8(this.color[4])
        )
        SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
        
        # Draw line with thickness
        if this.thickness == 1
            # Simple single-pixel line
            SDL2.SDL_RenderDrawLineF(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                Float32(startX),
                Float32(startY),
                Float32(endX),
                Float32(endY)
            )
        else
            # For thicker lines, we need to draw multiple lines
            dx = endX - startX
            dy = endY - startY
            length = sqrt(dx*dx + dy*dy)
            
            if length > 0
                # Normalized perpendicular vector
                perpX = -dy / length
                perpY = dx / length
                
                # Draw multiple parallel lines to create thickness
                for i in -(this.thickness÷2):(this.thickness÷2)
                    offsetX = perpX * i
                    offsetY = perpY * i
                    
                    SDL2.SDL_RenderDrawLineF(
                        JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                        Float32(startX + offsetX),
                        Float32(startY + offsetY),
                        Float32(endX + offsetX),
                        Float32(endY + offsetY)
                    )
                end
            end
        end
        
        # Restore original color
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r[], g[], b[], a[])
    end
    
    function UI.initialize(this::Line)
        # Nothing needed for initialization
    end
    
    function UI.destroy(this::Line)
        # Clean up effect texture
        if this.effectTexture != C_NULL
            SDL2.SDL_DestroyTexture(this.effectTexture)
            this.effectTexture = C_NULL
        end
    end
    
    #  effects API
    function UI.apply_effects!(this::Line, effects::Vector)
        this.effects = effects
        this.needsEffectUpdate = true
        update_effects(this)
        return this
    end
    
    function apply_style!(this::Line, style)
        return apply_effects!(this, style.effects)
    end
    
    function update_effects(this::Line)
        if isempty(this.effects) || !this.needsEffectUpdate
            return
        end
        
        # Create target for effects
        target = EffectsModule.LineTarget(this)
        
        # Apply effects
        try
            result = EffectRendererModule.apply_effects!(target, this.effects)
            if result isa EffectsModule.LineTarget
                # Effect texture should be updated by the renderer
                this.needsEffectUpdate = false
            end
        catch e
            @error("Failed to apply effects to $(this.name): $e")
        end
    end
    
    function render_line_with_effects(this::Line)
        camera = MAIN.scene.camera
        
        # Calculate position
        if this.isWorldEntity && camera !== nothing
            S = JulGame.pixels_per_world_unit(camera)
            startX = (this.startPoint.x - (camera.position.x + camera.offset.x)) * S
            startY = (this.startPoint.y - (camera.position.y + camera.offset.y)) * S
            endX = (this.endPoint.x - (camera.position.x + camera.offset.x)) * S
            endY = (this.endPoint.y - (camera.position.y + camera.offset.y)) * S
        else
            startX = this.startPoint.x
            startY = this.startPoint.y
            endX = this.endPoint.x
            endY = this.endPoint.y
        end
        
        # Calculate bounds for texture positioning
        min_x = min(startX, endX)
        min_y = min(startY, endY)
        max_x = max(startX, endX)
        max_y = max(startY, endY)
        
        width = max_x - min_x
        height = max_y - min_y
        
        # Render effect texture
        SDL2.SDL_RenderCopyF(
            JulGame.Renderer,
            this.effectTexture,
            C_NULL,
            Ref(SDL2.SDL_FRect(Float32(min_x), Float32(min_y), Float32(width), Float32(height)))
        )
    end
end 