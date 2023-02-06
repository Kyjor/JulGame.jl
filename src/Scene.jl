__precompile__()

using SimpleDirectMediaLayer.LibSDL2

mutable struct Scene
    colliders
    entities
    rigidbodies
    sprites
    
    function Scene(colliders, entities, rigidbodies, sprites)
        this = new()
        
        this.colliders = colliders
        this.entities = entities
        this.rigidbodies = rigidbodies
        this.sprites = sprites
        
        return this
    end
end

function Base.getproperty(this::Scene, s::Symbol)
    if s == :update
        function()
            # update here
        end
    else
        getfield(this, s)
    end
end