module CircleModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    
    export Circle
    mutable struct Circle
        alpha::Int32
        color::Tuple{Int32, Int32, Int32, Int32}
        fillMode::Bool
        id::String
        isActive::Bool
        isWorldEntity::Bool
        name::String
        persistentBetweenScenes::Bool
        center::Math.Vector2
        radius::Float32
        borderWidth::Int32
        borderColor::Tuple{Int32, Int32, Int32, Int32}
        layer::Int32
        
        function Circle(name::String, center::Math.Vector2, radius::Float32, color::Tuple{Int32, Int32, Int32, Int32}=(255, 255, 255, 255), 
                       fillMode::Bool=true; id::String=JulGame.generate_uuid(), isWorldEntity::Bool=false, 
                       borderWidth::Int32=0, borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255),
                       layer::Int32=Int32(0))
            this = new()
            
            this.alpha = Int32(color[4])
            this.color = color
            this.fillMode = fillMode
            this.id = id
            this.isActive = true
            this.isWorldEntity = isWorldEntity
            this.name = name
            this.persistentBetweenScenes = false
            this.center = center
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
        
        # Draw circle using the Midpoint Circle Algorithm
        if this.fillMode
            # Fill the circle
            for y in -scaledRadius:scaledRadius
                height = sqrt(scaledRadius^2 - y^2)
                for x in -height:height
                    SDL2.SDL_RenderDrawPointF(
                        JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                        Float32(centerX + x),
                        Float32(centerY + y)
                    )
                end
            end
        else
            # Draw just the outline
            x = 0
            y = Int32(scaledRadius)
            p = 3 - 2 * Int32(scaledRadius)
            
            while x <= y
                # These points complete the octants of the circle
                SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX + x), Float32(centerY - y))
                SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX + y), Float32(centerY - x))
                SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX + y), Float32(centerY + x))
                SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX + x), Float32(centerY + y))
                SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX - x), Float32(centerY + y))
                SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX - y), Float32(centerY + x))
                SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX - y), Float32(centerY - x))
                SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX - x), Float32(centerY - y))
                
                if p < 0
                    p += 4 * x + 6
                else
                    p += 4 * (x - y) + 10
                    y -= 1
                end
                x += 1
            end
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
            
            # Draw border (just the outline with increased radius)
            for i in 0:this.borderWidth-1
                x = 0
                y = Int32(scaledRadius + i)
                p = 3 - 2 * Int32(scaledRadius + i)
                
                while x <= y
                    # These points complete the octants of the circle
                    SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX + x), Float32(centerY - y))
                    SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX + y), Float32(centerY - x))
                    SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX + y), Float32(centerY + x))
                    SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX + x), Float32(centerY + y))
                    SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX - x), Float32(centerY + y))
                    SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX - y), Float32(centerY + x))
                    SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX - y), Float32(centerY - x))
                    SDL2.SDL_RenderDrawPointF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Float32(centerX - x), Float32(centerY - y))
                    
                    if p < 0
                        p += 4 * x + 6
                    else
                        p += 4 * (x - y) + 10
                        y -= 1
                    end
                    x += 1
                end
            end
        end
        
        # Restore original color
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r[], g[], b[], a[])
    end
    
    function UI.initialize(this::Circle)
        # Nothing needed for initialization
    end
    
    function UI.destroy(this::Circle)
        # Nothing needed for cleanup
    end
end 