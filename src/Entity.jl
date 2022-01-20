__precompile__()
include("Math/Vector2f.jl")
include("Transform.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Entity
    transform::Transform
    sprite
    collider
    rigidbody

    function Entity(transform::Transform = Transform(), sprite = C_NULL, collider = C_NULL, rigidbody = C_NULL)
        this = new()

        this.transform = transform
        this.sprite = sprite
        if this.sprite != C_NULL
            this.sprite.setParent(this)
        end
            
        this.collider = collider
        this.rigidbody = rigidbody
        if this.rigidbody != C_NULL
            this.rigidbody.setParent(this)
        end
        

        return this
    end
end

function Base.getproperty(this::Entity, s::Symbol)
    if s == :getTransform
        function()
            return this.transform
        end
    elseif s == :getSprite
        function()
            return this.sprite
        end
    elseif s == :getCollider
        function()
            return this.collider
        end
    elseif s == :getRigidbody
        function()
           return this.rigidbody
        end
    elseif s == :update
        function()
           if this.transform != C_NULL
               this.transform.update()
           end
           if this.sprite != C_NULL
               this.sprite.update()
           end
           if this.collider != C_NULL
               this.collider.update()
           end
           if this.rigidbody != C_NULL
               this.rigidbody.update()
           end
        end
    else
        getfield(this, s)
    end
end