mutable struct Scene
    camera
    colliders
    entities
    rigidbodies
    screenButtons
    textBoxes

    function Scene()
        this = new()

        this.camera = C_NULL
        this.colliders = []
        this.entities = []
        this.rigidbodies = []
        this.screenButtons = []
        this.textBoxes = []

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
    elseif s == :getEntityByName
        function(name)
            for entity in this.entities
                if entity.name == name
                    return entity
                end
            end

            @warn "No entity with name $name found"
            return C_NULL
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end