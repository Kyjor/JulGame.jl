module SpriteModule
    using ..Component.JulGame

    const SCALE_UNITS = Ref{Float64}(64.0)[]

    export Sprite
    mutable struct Sprite
        basePath
        crop::Union{Ptr{Nothing}, Math.Vector4}
        isFlipped::Bool
        image
        imagePath
        offset
        parent
        position
        renderer
        texture
        
        function Sprite(basePath::String, imagePath::String, crop::Union{Ptr{Nothing}, Math.Vector4}=C_NULL, isFlipped::Bool=false, isCreatedInEditor::Bool=false)
            this = new()
            
            this.offset = Math.Vector2f()
            this.basePath = basePath
            this.isFlipped = isFlipped
            this.imagePath = imagePath
            this.crop = crop
            this.position = Math.Vector2f(0.0, 0.0)
            this.image = C_NULL
            
            if isCreatedInEditor
                return this
            end
        
            SDL2.SDL_ClearError()
            fullPath = joinpath(basePath, "assets", "images", imagePath)
            this.image = SDL2.IMG_Load(fullPath)
            error = unsafe_string(SDL2.SDL_GetError())
            if !isempty(error)
                SDL2.SDL_ClearError()
        
                println(fullPath)
                println(string("Couldn't open image! SDL Error: ", error))
            end
        
            return this
        end
    end

    function Base.getproperty(this::Sprite, s::Symbol)
        if s == :draw
            function()
                if this.image == C_NULL
                    return
                end

                parentTransform = this.parent.getTransform()
                parentTransform.setPosition(Math.Vector2f(parentTransform.getPosition().x, round(parentTransform.getPosition().y; digits=3))) 
                flip = SDL2.SDL_FLIP_NONE
                
                srcRect = this.crop == C_NULL ? C_NULL : Ref(SDL2.SDL_Rect(this.crop.x,this.crop.y,this.crop.w,this.crop.h))

                SDL2.SDL_RenderCopyEx(
                    this.renderer, 
                    this.texture, 
                    srcRect, 
                    Ref(SDL2.SDL_Rect(convert(Int32,round((parentTransform.getPosition().x + this.offset.x - MAIN.scene.camera.position.x) * SCALE_UNITS)), 
                    convert(Int32,round((parentTransform.getPosition().y + this.offset.y - MAIN.scene.camera.position.y) * SCALE_UNITS)),
                    convert(Int32,round(1 * parentTransform.getScale().x * SCALE_UNITS)), 
                    convert(Int32,round(1 * parentTransform.getScale().y * SCALE_UNITS)))), 
                    0.0, 
                    C_NULL, 
                    this.isFlipped ? SDL2.SDL_FLIP_HORIZONTAL : SDL2.SDL_FLIP_NONE)
                
            end
        elseif s == :injectRenderer
            function(renderer)
                this.renderer = renderer
                if this.image == C_NULL
                    return
                end

                this.texture = SDL2.SDL_CreateTextureFromSurface(this.renderer, this.image)
            end
        elseif s == :flip
            function()
                this.isFlipped = !this.isFlipped
            end
    elseif s == :setParent
            function(parent)
                this.parent = parent
            end
        elseif s == :loadImage
            function(imagePath)
                SDL2.SDL_ClearError()
                this.image = SDL2.IMG_Load(joinpath(this.basePath, "assets", "images", imagePath))
                error = unsafe_string(SDL2.SDL_GetError())
                if !isempty(error)
                    println(string("Couldn't open image! SDL Error: ", error))
                    SDL2.SDL_ClearError()
                    this.image = C_NULL
                    return
                end
                
                this.imagePath = imagePath
                this.texture = SDL2.SDL_CreateTextureFromSurface(this.renderer, this.image)
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
            end
        end
    end
end
