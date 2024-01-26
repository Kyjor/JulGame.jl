mutable struct Scene
    # Need to work on import order so this can be concretely typed or at least parametricized
    camera::Union{Nothing, Any} #, JulGame.SceneManagement.SceneBuilderModule.Camera}
    colliders::Vector{Any}
    entities::Vector{Any}
    rigidbodies::Vector{Any}
    screenButtons::Vector{Any}
    textBoxes::Vector{Any}

    function Scene()
        this = new()

        this.camera = nothing
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
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
end
