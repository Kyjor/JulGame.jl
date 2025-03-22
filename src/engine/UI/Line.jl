module LineModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    
    export Line
    mutable struct Line
        alpha::Int32
        color::Tuple{Int32, Int32, Int32, Int32}
        id::String
        isActive::Bool
        isWorldEntity::Bool
        name::String
        persistentBetweenScenes::Bool
        startPoint::Math.Vector2
        endPoint::Math.Vector2
        thickness::Int32
        
        function Line(name::String, startPoint::Math.Vector2, endPoint::Math.Vector2, color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255), 
                     thickness::Int32=1; id::String=JulGame.generate_uuid(), isWorldEntity::Bool=false)
            this = new()
            
            this.alpha = Int32(color[4])
            this.color = color
            this.id = id
            this.isActive = true
            this.isWorldEntity = isWorldEntity
            this.name = name
            this.persistentBetweenScenes = false
            this.startPoint = startPoint
            this.endPoint = endPoint
            this.thickness = thickness
            
            return this
        end
    end
    
    function UI.render(this::Line)
        if !this.isActive
            return
        end
        
        camera = MAIN.scene.camera
        
        # Calculate drawing coordinates based on world or screen position
        if this.isWorldEntity && camera !== nothing
            # Calculate position in screen space
            startX = (this.startPoint.x - (camera.position.x + camera.offset.x)) * SCALE_UNITS
            startY = (this.startPoint.y - (camera.position.y + camera.offset.y)) * SCALE_UNITS
            endX = (this.endPoint.x - (camera.position.x + camera.offset.x)) * SCALE_UNITS
            endY = (this.endPoint.y - (camera.position.y + camera.offset.y)) * SCALE_UNITS
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
            UInt8(this.alpha)
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
        # Nothing needed for cleanup
    end
end 