__precompile__()
include("Math/Vector2f.jl")
include("Entity.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct Rigidbody
    mass
    offset
    parent
    velocity::Vector2f
    
    #frames: number of frames in an animation
    #width: width of each frame
    function Rigidbody(mass, offset)
        this = new()
        
        this.mass = mass
        this.offset = offset
        this.velocity = Vector2f(0.0, 1.0)
        return this
    end
end

function Base.getproperty(this::Rigidbody, s::Symbol)
    if s == :draw
        function(src, dest)
            SDL_RenderCopy(this.renderer, this.texture, src, Ref(SDL_Rect(this.parent.getTransform().getPosition().x,this.parent.getTransform().getPosition().y,64,64)))
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
    elseif s == :update
        function()
            #return this.frameCount
        end
   elseif s == :getParent
        function()
            return this.parent
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end