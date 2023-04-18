using SimpleDirectMediaLayer.LibSDL2

mutable struct Scene
    camera
    colliders
    entities
    rigidbodies
    screenButtons
    sounds
    textBoxes

    function Scene()
        this = new()

        this.camera = C_NULL
        this.colliders = []
        this.entities = []
        this.rigidbodies = []
        this.screenButtons = []
        this.sounds = []
        this.textBoxes = []

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
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end