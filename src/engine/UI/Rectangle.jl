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
        
        # Set new color
        SDL2.SDL_SetRenderDrawColor(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
            UInt8(this.color[1]), 
            UInt8(this.color[2]), 
            UInt8(this.color[3]), 
            UInt8(this.alpha)
        )
        SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
        
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