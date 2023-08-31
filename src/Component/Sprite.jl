module SpriteModule
using ..Component.JulGame
using SimpleDirectMediaLayer.LibSDL2
const SCALE_UNITS = Ref{Float64}(64.0)[]

export Sprite
mutable struct Sprite
    basePath
    crop
    isFlipped::Bool
    image
    imagePath
    offset
    parent
    position
    renderer
    texture
    
    function Sprite(basePath, imagePath, crop, isCreatedInEditor)
        this = new()
        
        this.offset = Math.Vector2f()
        this.basePath = basePath
        this.isFlipped = false
        this.imagePath = imagePath
        this.crop = crop
        this.position = Math.Vector2f(0.0, 0.0)
        this.image = C_NULL
        
        if isCreatedInEditor
            return this
        end

        this.image = IMG_Load(joinpath(basePath, "projectFiles", "assets", "images", imagePath))
        error = unsafe_string(SDL_GetError())
        if !isempty(error)
            SDL_ClearError()
            println(string("Couldn't open image! SDL Error: ", error))
        end

        return this
    end

    function Sprite(basePath, imagePath, isFlipped::Bool, isCreatedInEditor)
        this = new()
        
        this.offset = Math.Vector2f()
        this.basePath = basePath
        this.isFlipped = isFlipped
        this.imagePath = imagePath
        this.crop = C_NULL
        this.position = Math.Vector2f(0.0, 0.0)
        this.image = C_NULL
        
        if isCreatedInEditor
            return this
        end

        this.image = IMG_Load(joinpath(basePath, "projectFiles", "assets", "images", imagePath))
        error = unsafe_string(SDL_GetError())
        if !isempty(error)
            SDL_ClearError()
            println(string("Couldn't open image! SDL Error: ", error))
        end

        return this
    end

    function Sprite(basePath, imagePath, isCreatedInEditor)
        this = new()
        
        this.offset = Math.Vector2f()
        this.basePath = basePath
        this.isFlipped = false
        this.imagePath = imagePath
        this.crop = C_NULL
        this.position = Math.Vector2f(0.0, 0.0)
        this.image = C_NULL
        
        if isCreatedInEditor
            return this
        end

        SDL_ClearError()
        fullPath = joinpath(basePath, "projectFiles", "assets", "images", imagePath)
        this.image = IMG_Load(fullPath)
        error = unsafe_string(SDL_GetError())
        if !isempty(error)
            SDL_ClearError()

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
            flip = SDL_FLIP_NONE
            
            srcRect = this.crop == C_NULL ? C_NULL : Ref(SDL_Rect(this.crop.x,this.crop.y,this.crop.w,this.crop.h))

            SDL_RenderCopyEx(
                this.renderer, 
                this.texture, 
                srcRect, 
                Ref(SDL_Rect(convert(Int32,round((parentTransform.getPosition().x + this.offset.x - MAIN.scene.camera.position.x) * SCALE_UNITS)), 
                convert(Int32,round((parentTransform.getPosition().y + this.offset.y - MAIN.scene.camera.position.y) * SCALE_UNITS)),
                convert(Int32,round(1 * parentTransform.getScale().x * SCALE_UNITS)), 
                convert(Int32,round(1 * parentTransform.getScale().y * SCALE_UNITS)))), 
                0.0, 
                C_NULL, 
                this.isFlipped ? SDL_FLIP_HORIZONTAL : SDL_FLIP_NONE)
            
        end
    elseif s == :injectRenderer
        function(renderer)
            this.renderer = renderer
            if this.image == C_NULL
                return
            end

            this.texture = SDL_CreateTextureFromSurface(this.renderer, this.image)
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
            this.image = IMG_Load(joinpath(this.basePath, "projectFiles", "assets", "images", imagePath))
            error = unsafe_string(SDL_GetError())
            if !isempty(error)
                println(string("Couldn't open image! SDL Error: ", error))
                SDL_ClearError()
                this.image = C_NULL
                return
            end
            
            this.imagePath = imagePath
            this.texture = SDL_CreateTextureFromSurface(this.renderer, this.image)
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
