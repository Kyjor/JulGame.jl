module ProgressBarModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    using ..UI.RectangleModule: draw_rounded_rectangle, draw_rounded_border
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
        borderRadius::Int32
        vertical::Bool
        showBackground::Bool
        layer::Int32
        
        function ProgressBar(name::String, position::Math.Vector2, size::Math.Vector2, progress::Float32=1.0,
                           fillColor::Tuple{Int32, Int32, Int32, Int32}=(0, 255, 0, 255),
                           backgroundColor::Tuple{Int32, Int32, Int32, Int32}=(100, 100, 100, 200),
                           borderColor::Tuple{Int32, Int32, Int32, Int32}=(0, 0, 0, 255);
                           id::String=JulGame.generate_uuid(), isWorldEntity::Bool=false,
                           borderWidth::Int32=1, borderRadius::Int32=0, vertical::Bool=false, showBackground::Bool=true,
                           layer::Int32=Int32(0))
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
            this.borderRadius = borderRadius
            this.vertical = vertical
            this.showBackground = showBackground
            this.layer = layer
            
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
        
        # Apply blend mode
        SDL2.SDL_SetRenderDrawBlendMode(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, SDL2.SDL_BLENDMODE_BLEND)
        
        # Draw background if enabled
        if this.showBackground
            if this.borderRadius > 0
                # Draw with rounded corners
                draw_rounded_rectangle(
                    JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                    barRect,
                    this.borderRadius,
                    this.backgroundColor,
                    this.backgroundColor[4],
                    true
                )
            else
                # Draw regular rectangle
                SDL2.SDL_SetRenderDrawColor(
                    JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                    UInt8(this.backgroundColor[1]), 
                    UInt8(this.backgroundColor[2]), 
                    UInt8(this.backgroundColor[3]), 
                    UInt8(this.backgroundColor[4])
                )
                SDL2.SDL_RenderFillRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(barRect))
            end
        end
        
        # Calculate the progress fill rectangle
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
        
        # Draw the progress fill
        if this.borderRadius > 0 && this.progress > 0
            # For rounded progress bars, we need to handle the fill differently
            # Create a clipping rectangle to show only the filled portion
            if this.vertical
                # Vertical progress bar
                clipRect = SDL2.SDL_Rect(
                    Int32(posX),
                    Int32(posY + height - fillHeight),
                    Int32(width),
                    Int32(fillHeight)
                )
            else
                # Horizontal progress bar
                clipRect = SDL2.SDL_Rect(
                    Int32(posX),
                    Int32(posY),
                    Int32(fillWidth),
                    Int32(height)
                )
            end
            
            # Set the clip rectangle
            SDL2.SDL_RenderSetClipRect(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(clipRect))
            
            # Draw the filled area with the same rounded corners
            draw_rounded_rectangle(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                barRect,
                this.borderRadius,
                this.fillColor,
                this.alpha,
                true
            )
            
            # Reset clipping
            SDL2.SDL_RenderSetClipRect(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, C_NULL)
        else
            # Regular fill without rounded corners
            SDL2.SDL_SetRenderDrawColor(
                JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                UInt8(this.fillColor[1]), 
                UInt8(this.fillColor[2]), 
                UInt8(this.fillColor[3]), 
                UInt8(this.alpha)
            )
            
            SDL2.SDL_RenderFillRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(fillRect))
        end
        
        # Draw border if borderWidth > 0
        if this.borderWidth > 0
            if this.borderRadius > 0
                # Draw rounded border
                draw_rounded_border(
                    JulGame.Renderer::Ptr{SDL2.SDL_Renderer},
                    barRect,
                    this.borderRadius,
                    this.borderWidth,
                    this.borderColor,
                    this.borderColor[4]
                )
            else
                # Draw regular border
                SDL2.SDL_SetRenderDrawColor(
                    JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
                    UInt8(this.borderColor[1]), 
                    UInt8(this.borderColor[2]), 
                    UInt8(this.borderColor[3]), 
                    UInt8(this.borderColor[4])
                )
                
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