__precompile__()

using SimpleDirectMediaLayer.LibSDL2

mutable struct Scene
    camera
    colliders
    entities
    rigidbodies

    function Scene()
        this = new()

        this.camera = C_NULL
        this.colliders = C_NULL
        this.entities = C_NULL
        this.rigidbodies = C_NULL

        return this
    end

    function Scene(colliders, entities, rigidbodies)
        this = new()
        
        this.colliders = colliders
        this.entities = entities
        this.rigidbodies = rigidbodies
        
        return this
    end
end

function Base.getproperty(this::Scene, s::Symbol)
    if s == :update
        function()
            # update here
        end
    elseif s == :getCollidersInRange
        function(originCollider)
            # search for colliders in colliders that could possibly touch origin collider and return as array
        end
    else
        getfield(this, s)
    end
end