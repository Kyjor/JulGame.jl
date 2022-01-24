__precompile__()
include("Math/Vector2f.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Transform
   
   rotation::Float64
   position::Vector2f
   scale::Vector2f
    
    function Transform()
        this = new()

        this.position = Vector2f(0.0, 0.0)
        this.scale = Vector2f(1.0, 1.0)
        this.rotation = 0.0

        return this
    end
    function Transform(position::Vector2f)
        this = new()
   
        this.position = position
        this.scale = Vector2f()
        this.rotation = 0.0
   
        return this
    end
    function Transform(position::Vector2f, scale::Vector2f, rotation = 0.0)
         this = new()
    
         this.position = position
         this.scale = scale
         this.rotation = rotation
    
         return this
    end
end

function Base.getproperty(this::Transform, s::Symbol)
    if s == :getPosition
        function()
            return this.position
        end
    elseif s == :setPosition
        function(position::Vector2f)
            this.position = position
        end
    elseif s == :getScale
        function()
            return this.scale
        end
    elseif s == :setScale
        function(scale::Vector2f)
            this.scale = scale
        end
    elseif s == :getRotation
        function()
            return this.rotation
        end
    elseif s == :setRotation
        function(rotation::Float64)
            this.rotation = rotation
        end
     elseif s == :update
        function()
            #println(this.position)
        end
    else
        getfield(this, s)
    end
end