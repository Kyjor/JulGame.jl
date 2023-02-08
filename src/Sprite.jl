__precompile__()
include("Math/Vector2f.jl")
include("Constants.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct Sprite
    isFlipped
    image
    frameToDraw
    offset
    parent
    pixelsPerUnit
    position
    renderer
    texture
    widthX
    widthY
    
    #frames: number of frames in an animation
    #width: width of each frame
    function Sprite(image, renderer, pixelsPerUnit)
        this = new()
        
        this.isFlipped = false
        this.image = IMG_Load(image)
        this.frameToDraw = 0
        this.renderer = renderer
        this.pixelsPerUnit = pixelsPerUnit
        this.position = Vector2f(0.0, 0.0)
        this.widthX = 1.0 
        this.widthY = 1.0
        
        this.texture = SDL_CreateTextureFromSurface(this.renderer, this.image)

        return this
    end
    
    function Sprite(image, pixelsPerUnit)
        this = new()
        
        this.isFlipped = false
        this.image = IMG_Load(image)
        this.frameToDraw = 0
        this.pixelsPerUnit = pixelsPerUnit
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
            
            SDL_RenderCopyEx(
                this.renderer, 
                this.texture, 
                Ref(SDL_Rect(this.frameToDraw * 16,0,16,16)), 
                Ref(SDL_Rect(convert(Int32,round(parentTransform.getPosition().x * SCALE_UNITS)), 
                convert(Int32,round(parentTransform.getPosition().y * SCALE_UNITS)),
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
        getfield(this, s)
    end
end