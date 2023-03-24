include("Constants.jl")
include("SceneInstance.jl")
include("Math/Vector2.jl")
include("Math/Vector2f.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct Sprite
    crop
    isFlipped
    image
    frameToDraw
    offset
    parent
    position
    renderer
    texture
    widthX
    widthY
    
    function Sprite(image, crop::Vector2)
        this = new()
        
        this.isFlipped = false
        this.image = IMG_Load(image)
        this.frameToDraw = 0
        this.crop = crop
        this.position = Vector2f(0.0, 0.0)
        this.widthX = 1.0 
        this.widthY = 1.0

        return this
    end

    function Sprite(image)
        this = new()
        
        this.isFlipped = false
        this.image = IMG_Load(image)
        this.frameToDraw = 0
        this.crop = C_NULL
        this.position = Vector2f(0.0, 0.0)
        this.widthX = 1.0 
        this.widthY = 1.0

        return this
    end
end

function Base.getproperty(this::Sprite, s::Symbol)
    if s == :draw
        function()
            parentTransform = this.parent.getTransform()
            parentTransform.setPosition(Vector2f(parentTransform.getPosition().x, round(parentTransform.getPosition().y; digits=3))) 
            flip = SDL_FLIP_NONE
            srcRect = this.crop == C_NULL ? C_NULL : Ref(SDL_Rect(this.frameToDraw * this.crop.x,0,this.crop.x,this.crop.y))
            SDL_RenderCopyEx(
                this.renderer, 
                this.texture, 
                srcRect, 
                Ref(SDL_Rect(convert(Int32,round((parentTransform.getPosition().x - SceneInstance.camera.position.x) * SCALE_UNITS)), 
                convert(Int32,round((parentTransform.getPosition().y - SceneInstance.camera.position.y) * SCALE_UNITS)),
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
    elseif s == :update
        function()
            this.draw(Ref(SDL_Rect(this.frameToDraw * 16,0,16,16)))
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