module ProgressBarModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    import ..UI
    
    export ProgressBar
    mutable struct ProgressBar
        alpha::Int32
        backgroundColor::Tuple{Int32, Int32, Int32, Int32}
        fillColor::Tuple{Int32, Int32, Int32, Int32}
        borderColor::Tuple{Int32, Int32, Int32, Int32}
        id::String
        isActive::Bool
        isWorldEntity::Bool
        name::String
        persistentBetweenScenes::Bool
        position::Math.Vector2
        size::Math.Vector2
        progress::Float32  # 0.0 to 1.0
        borderWidth::Int32
        vertical::Bool
        showBackground::Bool
        
        function ProgressBar(name::String, position::Math.Vector2, size::Math.Vector2, progress::Float32=1.0,
                           fillColor::Tuple{Int32, Int32, Int32, Int32}=(0, 255, 0, 255),
                           backgroundColor::Tuple{Int32, Int32, Int32, Int32}=(100, 100, 100, 200),
                           borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255);
                           id::String=JulGame.generate_uuid(), isWorldEntity::Bool=false,
                           borderWidth::Int32=1, vertical::Bool=false, showBackground::Bool=true)
            this = new()
            
            this.alpha = Int32(fillColor[4])
            this.backgroundColor = backgroundColor
            this.fillColor = fillColor
            this.borderColor = borderColor
            this.id = id
            this.isActive = true
            this.isWorldEntity = isWorldEntity
            this.name = name
            this.persistentBetweenScenes = false
            this.position = position
            this.size = size
            this.progress = clamp(progress, 0.0, 1.0)
            this.borderWidth = borderWidth
            this.vertical = vertical
            this.showBackground = showBackground
            
            return this
        end
    end
    
    function UI.render(this::ProgressBar)
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
        else
            posX = this.position.x
            posY = this.position.y
            width = this.size.x
            height = this.size.y
        end
        
        # Save current render draw color
        r = Ref(UInt8(0))
        g = Ref(UInt8(0))
        b = Ref(UInt8(0))
        a = Ref(UInt8(0))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r, g, b, a)
        
        # Create the bar rectangle
        barRect = SDL2.SDL_FRect(
            Float32(posX),
            Float32(posY),
            Float32(width),
            Float32(height)
        )
        
        # Draw background if enabled
        if this.showBackground
            SDL2.SDL_SetRenderDrawColor(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                UInt8(this.backgroundColor[1]), 
                UInt8(this.backgroundColor[2]), 
                UInt8(this.backgroundColor[3]), 
                UInt8(this.backgroundColor[4])
            )
            SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
            SDL2.SDL_RenderFillRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(barRect))
        end
        
        # Draw the progress fill
        SDL2.SDL_SetRenderDrawColor(
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
            UInt8(this.fillColor[1]), 
            UInt8(this.fillColor[2]), 
            UInt8(this.fillColor[3]), 
            UInt8(this.alpha)
        )
        
        fillRect = if this.vertical
            # Vertical bar (fills from bottom to top)
            fillHeight = height * this.progress
            SDL2.SDL_FRect(
                Float32(posX),
                Float32(posY + height - fillHeight),
                Float32(width),
                Float32(fillHeight)
            )
        else
            # Horizontal bar (fills from left to right)
            fillWidth = width * this.progress
            SDL2.SDL_FRect(
                Float32(posX),
                Float32(posY),
                Float32(fillWidth),
                Float32(height)
            )
        end
        
        SDL2.SDL_RenderFillRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(fillRect))
        
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
                borderRect = SDL2.SDL_FRect(
                    barRect.x - Float32(i),
                    barRect.y - Float32(i),
                    barRect.w + Float32(i * 2),
                    barRect.h + Float32(i * 2)
                )
                SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(borderRect))
            end
        end
        
        # Restore original color
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, r[], g[], b[], a[])
    end
    
    function UI.initialize(this::ProgressBar)
        # Nothing needed for initialization
    end
    
    function UI.destroy(this::ProgressBar)
        # Nothing needed for cleanup
    end
    
    """
    set_progress(progressBar::ProgressBar, value::Float32)
    
    Set the progress value (0.0 to 1.0) of the progress bar.
    """
    function set_progress(this::ProgressBar, value::Float32)
        this.progress = clamp(value, 0.0, 1.0)
    end
end 