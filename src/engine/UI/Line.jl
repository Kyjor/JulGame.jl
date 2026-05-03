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

    @inline function _line_scene_camera()::Union{Nothing, JulGame.Camera}
        main = JulGame.current_main()
        sc = getfield(main, :scene)
        return getfield(sc, :camera)::Union{Nothing, JulGame.Camera}
    end

    """World or screen endpoints in pixel space as `Float64` (JuliaC `--trim` friendly)."""
    @inline function _line_screen_endpoints(this::Line, camera::Union{Nothing, JulGame.Camera})::NTuple{4, Float64}
        sp = getfield(this, :startPoint)::Math._Vector2{Int32}
        ep = getfield(this, :endPoint)::Math._Vector2{Int32}
        sx0 = Float64(getfield(sp, :x))
        sy0 = Float64(getfield(sp, :y))
        ex0 = Float64(getfield(ep, :x))
        ey0 = Float64(getfield(ep, :y))
        if this.isWorldEntity && camera !== nothing
            S = Float64(JulGame.pixels_per_world_unit(camera))
            cpos = getfield(camera, :position)::Math._Vector3{Float64}
            coff = getfield(camera, :offset)::Math._Vector2{Float64}
            cx = Float64(cpos.x) + Float64(coff.x)
            cy = Float64(cpos.y) + Float64(coff.y)
            return (
                (sx0 - cx) * S,
                (sy0 - cy) * S,
                (ex0 - cx) * S,
                (ey0 - cy) * S,
            )
        end
        return (sx0, sy0, ex0, ey0)
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
        
        camera = _line_scene_camera()
        startX, startY, endX, endY = _line_screen_endpoints(this, camera)
        
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
            dx::Float64 = endX - startX
            dy::Float64 = endY - startY
            len::Float64 = sqrt(dx * dx + dy * dy)
            
            if len > 0
                # Normalized perpendicular vector
                perpX::Float64 = -dy / len
                perpY::Float64 = dx / len
                
                # Draw multiple parallel lines to create thickness
                half = this.thickness ÷ 2
                for i in -half:half
                    offsetX::Float64 = perpX * i
                    offsetY::Float64 = perpY * i
                    
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
        camera = _line_scene_camera()
        startX, startY, endX, endY = _line_screen_endpoints(this, camera)
        
        min_x = Base.min(startX, endX)
        min_y = Base.min(startY, endY)
        max_x = Base.max(startX, endX)
        max_y = Base.max(startY, endY)
        
        width::Float64 = max_x - min_x
        height::Float64 = max_y - min_y
        
        # Render effect texture
        SDL2.SDL_RenderCopyF(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
            this.effectTexture,
            C_NULL,
            Ref(SDL2.SDL_FRect(Float32(min_x), Float32(min_y), Float32(width), Float32(height)))
        )
    end
end 