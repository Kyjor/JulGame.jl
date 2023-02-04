__precompile__()
include("Math/Vector2f.jl")
include("Constants.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct Sprite
    isFlipped
    frameCount
    image
    lastFrame
    lastUpdate
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
    function Sprite(frameCount, image, renderer, pixelsPerUnit)
        this = new()
        
        this.isFlipped = false
        this.frameCount = frameCount
        this.image = IMG_Load(image)
        this.lastFrame = 0
        this.lastUpdate = SDL_GetTicks()
        this.parent = parent
        this.pixelsPerUnit = pixelsPerUnit
        this.position = Vector2f(0.0, 0.0)
        this.renderer = renderer
        this.texture = SDL_CreateTextureFromSurface(this.renderer, this.image)
        this.widthX = 1.0 
        this.widthY = 1.0

        return this
    end
    
    function Sprite(frameCount, image, pixelsPerUnit)
        this = new()
        
        this.isFlipped = false
        this.frameCount = frameCount
        this.image = IMG_Load(image)
        this.lastFrame = 0
        this.lastUpdate = SDL_GetTicks()
        this.parent = parent
        this.pixelsPerUnit = pixelsPerUnit
        this.position = Vector2f(0.0, 0.0)
        this.widthX = 1.0 
        this.widthY = 1.0

        return this
    end
end

function Base.getproperty(this::Sprite, s::Symbol)
    if s == :draw
        function(src)
            parentTransform = this.parent.getTransform()
            parentTransform.setPosition(Vector2f(parentTransform.getPosition().x, round(parentTransform.getPosition().y; digits=3))) 
            
            # println("x: ", parentTransform.getPosition().x * SCALE_UNITS)
            # println("y: ", parentTransform.getPosition().y * SCALE_UNITS)
            # println("w: ", 1 * parentTransform.getScale().x * SCALE_UNITS)
            # println("h: ", 1 * parentTransform.getScale().y * SCALE_UNITS)
            flip = SDL_FLIP_NONE
            # println(this.flip == false)
            # if this.flip
            #     flip = SDL_FLIP_HORIZONTAL
            # end
            
            SDL_RenderCopyEx(this.renderer, this.texture, src, Ref(SDL_Rect(convert(Int32,round(parentTransform.getPosition().x * SCALE_UNITS)), convert(Int32,round(parentTransform.getPosition().y * SCALE_UNITS)),convert(Int32,round(1 * parentTransform.getScale().x * SCALE_UNITS)), convert(Int32,round(1 * parentTransform.getScale().y * SCALE_UNITS)))), 0.0, C_NULL, this.isFlipped ? SDL_FLIP_HORIZONTAL : SDL_FLIP_NONE)
            #SDL_RenderCopy(this.renderer, this.texture, src, Ref(SDL_Rect(this.parent.getTransform().getPosition().x,this.parent.getTransform().getPosition().y,64,64)))
        end
    elseif s == :injectRenderer
        function(renderer)
            this.renderer = renderer
            this.texture = SDL_CreateTextureFromSurface(this.renderer, this.image)
        end
    elseif s == :getLastFrame
        function()
            return this.lastFrame
        end
    elseif s == :setLastFrame
        function(value)
            this.lastFrame = value
        end
    elseif s == :getLastUpdate
        function()
            return this.lastUpdate
        end
    elseif s == :setLastUpdate
        function(value)
            this.lastUpdate = value
        end
    elseif s == :getFrameCount
        function()
            return this.frameCount
        end
    elseif s == :flip
        function()
            this.isFlipped = !this.isFlipped
        end
    elseif s == :update
        function()
            this.draw(Ref(SDL_Rect(this.getLastFrame() * 16,0,16,16)))
        end
   elseif s == :setParent
        function(parent)
            println("set parent")
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end