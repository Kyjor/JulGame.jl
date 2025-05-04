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
    
    function UI.render(this::Circle)
        if !this.isActive
            return
        end
        
        camera = MAIN.scene.camera
        
        # Calculate drawing coordinates based on world or screen position
        if this.isWorldEntity && camera !== nothing
            # Calculate position in screen space
            centerX = (this.center.x - (camera.position.x + camera.offset.x)) * SCALE_UNITS
            centerY = (this.center.y - (camera.position.y + camera.offset.y)) * SCALE_UNITS
            
            # For world entities, radius needs to be scaled by SCALE_UNITS
            scaledRadius = this.radius * SCALE_UNITS
        else
            centerX = this.center.x
            centerY = this.center.y
            scaledRadius = this.radius
        end
        
        # Draw border if borderWidth > 0
        if this.borderWidth > 0
            SDL2.aacircleRGBA(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, centerX, centerY, scaledRadius, UInt8(this.borderColor[1]), UInt8(this.borderColor[2]), UInt8(this.borderColor[3]), UInt8(this.borderColor[4]))
        end

        SDL2.aacircleRGBA(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, centerX, centerY, scaledRadius, UInt8(this.color[1]), UInt8(this.color[2]), UInt8(this.color[3]), UInt8(this.color[4]))
    end
    
    function UI.initialize(this::Circle)
        # Nothing needed for initialization
    end
    
    function UI.destroy(this::Circle)
        # Nothing needed for cleanup
    end
end 