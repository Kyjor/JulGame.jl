module SpriteModule
using ..ComponentjulGame
using SimpleDirectMediaLayer.LibSDL2
const SCALE_UNITS = Ref{Float64}(64.0)[]

export Sprite
mutable struct Sprite
    crop
    isFlipped::Bool
    image
    imagePath
    offset
    parent
    position
    renderer
    texture
    
    function Sprite(imagePath, crop::Math.Vector4)
        this = new()
        
        this.isFlipped = false
        this.imagePath = imagePath
        this.image = IMG_Load(this.imagePath)
        this.crop = crop
        this.position = Math.Vector2f(0.0, 0.0)

        return this
    end

    function Sprite(imagePath, isFlipped)
        this = new()
        
        this.isFlipped = isFlipped
        this.imagePath = imagePath
        this.image = IMG_Load(this.imagePath)
        this.crop = C_NULL
        this.position = Math.Vector2f(0.0, 0.0)

        return this
    end

    function Sprite(imagePath)
        this = new()
        
        this.isFlipped = false
        this.imagePath = imagePath
        this.image = IMG_Load(this.imagePath)
        this.crop = C_NULL
        this.position = Math.Vector2f(0.0, 0.0)

        return this
    end
end

function Base.getproperty(this::Sprite, s::Symbol)
    if s == :draw
        function()
            parentTransform = this.parent.getTransform()
            parentTransform.setPosition(Math.Vector2f(parentTransform.getPosition().x, round(parentTransform.getPosition().y; digits=3))) 
            flip = SDL_FLIP_NONE
            
            srcRect = this.crop == C_NULL ? C_NULL : Ref(SDL_Rect(this.crop.x,this.crop.y,this.crop.w,this.crop.h))
            SDL_RenderCopyEx(
                this.renderer, 
                this.texture, 
                srcRect, 
                Ref(SDL_Rect(convert(Int32,round((parentTransform.getPosition().x - MAIN.scene.camera.position.x) * SCALE_UNITS)), 
                convert(Int32,round((parentTransform.getPosition().y - MAIN.scene.camera.position.y) * SCALE_UNITS)),
                convert(Int32,round(1 * parentTransform.getScale().x * SCALE_UNITS)), 
                convert(Int32,round(1 * parentTransform.getScale().y * SCALE_UNITS)))), 
                0.0, 
                C_NULL, 
                this.isFlipped ? SDL_FLIP_HORIZONTAL : SDL_FLIP_NONE)
        end
    elseif s == :injectRenderer
        function(renderer)
            this.renderer = renderer
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
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end
end
