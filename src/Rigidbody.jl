__precompile__()
include("Math/Vector2f.jl")

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
        this.velocity = Vector2f(0.0, 250.0)
        return this
    end
end

function Base.getproperty(this::Rigidbody, s::Symbol)
    if s == :update
        function()
            #return this.frameCount
        end
    elseif s == :getVelocity
        function()
            return this.velocity
        end
    elseif s == :setVelocity
        function(velocity::Vector2f)
            this.velocity = velocity
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