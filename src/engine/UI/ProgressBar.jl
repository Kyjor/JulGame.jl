module ProgressBarModule
    using ..UI.JulGame
    using ..UI.JulGame.Math
    using ..UI.RectangleModule: draw_rounded_rectangle, draw_rounded_border
    import ..UI
    
    export ProgressBar
    mutable struct ProgressBar
        backgroundColor::NTuple{4, Int}
        fillColor::NTuple{4, Int}
        borderColor::NTuple{4, Int}
        id::String
        isActive::Bool
        isWorldEntity::Bool
        name::String
        persistentBetweenScenes::Bool
        position::Math.Vector2
        size::Math.Vector2
        progress::Float32  # 0.0 to 1.0
        borderWidth::Int
        borderRadius::Int
        vertical::Bool
        showBackground::Bool
        layer::Int
        
        function ProgressBar(name::String, position::Math.Vector2, size::Math.Vector2, progress::Float32=1.0,
                           fillColor::NTuple{4, Int}=(0, 255, 0, 255),
                           backgroundColor::NTuple{4, Int}=(100, 100, 100, 200),
                           borderColor::NTuple{4, Int}=(0, 0, 0, 255);
                           id::String=JulGame.generate_uuid(), isWorldEntity::Bool=false,
                           borderWidth::Int=1, borderRadius::Int=0, vertical::Bool=false, showBackground::Bool=true,
                           layer::Int=0)
            this = new()
            
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

    @inline function _progressbar_scene_camera()::Union{Nothing, JulGame.Camera}
        main = JulGame.current_main()
        sc = getfield(main, :scene)
        return getfield(sc, :camera)::Union{Nothing, JulGame.Camera}
    end
    
    function UI.render(this::ProgressBar)
        if !this.isActive
            return
        end
        
        camera = _progressbar_scene_camera()
        pos = getfield(this, :position)::Math._Vector2{Int32}
        sz = getfield(this, :size)::Math._Vector2{Int32}
        px = Float64(getfield(pos, :x))
        py = Float64(getfield(pos, :y))
        sw = Float64(getfield(sz, :x))
        sh = Float64(getfield(sz, :y))
        prog = Float64(getfield(this, :progress)::Float32)

        local posX::Float64, posY::Float64, width::Float64, height::Float64
        if this.isWorldEntity && camera !== nothing
            S = Float64(JulGame.pixels_per_world_unit(camera))
            cpos = getfield(camera, :position)::Math._Vector3{Float64}
            coff = getfield(camera, :offset)::Math._Vector2{Float64}
            posX = (px - (Float64(cpos.x) + Float64(coff.x))) * S
            posY = (py - (Float64(cpos.y) + Float64(coff.y))) * S
            width = sw * S
            height = sh * S
        else
            posX = px
            posY = py
            width = sw
            height = sh
        end

        fillHeight = height * prog
        fillWidth = width * prog
        
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
            SDL2.SDL_FRect(
                Float32(posX),
                Float32(posY + height - fillHeight),
                Float32(width),
                Float32(fillHeight),
            )
        else
            SDL2.SDL_FRect(
                Float32(posX),
                Float32(posY),
                Float32(fillWidth),
                Float32(height),
            )
        end
        
        # Draw the progress fill
        if this.borderRadius > 0 && this.progress > 0
            # For rounded progress bars, we need to handle the fill differently
            # Create a clipping rectangle to show only the filled portion
            if this.vertical
                # Vertical progress bar
                clipRect = SDL2.SDL_Rect(
                    Math.TypeConversions.safe_int32_convert(posX::Float64),
                    Math.TypeConversions.safe_int32_convert((posY + height - fillHeight)::Float64),
                    Math.TypeConversions.safe_int32_convert(width::Float64),
                    Math.TypeConversions.safe_int32_convert(fillHeight::Float64),
                )
            else
                # Horizontal progress bar
                clipRect = SDL2.SDL_Rect(
                    Math.TypeConversions.safe_int32_convert(posX::Float64),
                    Math.TypeConversions.safe_int32_convert(posY::Float64),
                    Math.TypeConversions.safe_int32_convert(fillWidth::Float64),
                    Math.TypeConversions.safe_int32_convert(height::Float64),
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
                UInt8(this.fillColor[4])
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
                    this.borderColor
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