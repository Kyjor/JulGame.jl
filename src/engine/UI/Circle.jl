module CircleModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    
    export Circle
    mutable struct Circle <: UI.UIElement
        fillMode::Bool
        id::String
        center::Math.Vector2f
        radius::Float32
        borderWidth::Int
        borderColor::NTuple{4, Int}
        
        function Circle(center::Math.Vector2f;
            id::String=JulGame.generate_uuid(), 
            name::String="Circle", 
            radius::Float64 = 1.0, 
            color::NTuple{4, Int}=(255, 255, 255, 255), 
            fillMode::Bool=true, 
            isWorldEntity::Bool=false, 
            borderWidth::Int=0, 
            borderColor::NTuple{4, Int}=(0, 0, 0, 255),
            layer::Int=0
        )
            this = new()
            
            this.color = color
            this.fillMode = fillMode
            this.id = id
            this.isActive = true
            this.isWorldEntity = isWorldEntity
            this.name = name
            this.persistentBetweenScenes = false
            this.position = center
            this.radius = radius
            this.borderWidth = borderWidth
            this.borderColor = borderColor
            this.layer = layer
            
            return this
        end
    end

    @inline function _circle_scene_camera()::Union{Nothing, JulGame.Camera}
        main = JulGame.current_main()
        sc = getfield(main, :scene)
        return getfield(sc, :camera)::Union{Nothing, JulGame.Camera}
    end
    
    function UI.render(this::Circle)
        if !this.isActive
            return
        end
        
        camera = _circle_scene_camera()
        center_vec = getfield(this, :center)::Math.Vector2f
        rad = getfield(this, :radius)::Float32
        rend = JulGame.Renderer::Ptr{SDL2.LibSDL2.SDL_Renderer}

        # Calculate drawing coordinates based on world or screen position
        local centerX::Float64, centerY::Float64, scaledR::Float64
        if this.isWorldEntity && camera !== nothing
            S = Float64(JulGame.pixels_per_world_unit(camera))
            cpos = getfield(camera, :position)::Math._Vector3{Float64}
            coff = getfield(camera, :offset)::Math._Vector2{Float64}
            cx = Float64(center_vec.x)
            cy = Float64(center_vec.y)
            centerX = (cx - (Float64(cpos.x) + Float64(coff.x))) * S
            centerY = (cy - (Float64(cpos.y) + Float64(coff.y))) * S
            scaledR = Float64(rad) * S
        else
            centerX = Float64(center_vec.x)
            centerY = Float64(center_vec.y)
            scaledR = Float64(rad)
        end

        sx = round(Cint, centerX)
        sy = round(Cint, centerY)
        sr = round(Cint, scaledR)
        
        # Draw border if borderWidth > 0
        if this.borderWidth > 0
            bc = getfield(this, :borderColor)::NTuple{4, Int}
            SDL2.LibSDL2.aacircleRGBA(
                rend, sx, sy, sr,
                UInt8(bc[1]), UInt8(bc[2]), UInt8(bc[3]), UInt8(bc[4]),
            )
        end

        inst = UI.relationship_instance(this::JulGame.IUIElement)
        fc = getfield(inst, :color)::NTuple{4, Int}
        SDL2.LibSDL2.aacircleRGBA(
            rend, sx, sy, sr,
            UInt8(fc[1]), UInt8(fc[2]), UInt8(fc[3]), UInt8(fc[4]),
        )
    end
    
    function UI.initialize(this::Circle)
        # Nothing needed for initialization
    end
    
    function UI.destroy(this::Circle)
        # Nothing needed for cleanup
    end
end 