mutable struct Scene
    camera::Union{Nothing, JulGame.SceneManagement.SceneBuilderModule.Camera}
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
    method_props = (
        update = update,
        getCollidersInRange = get_colliders_in_range,
        getEntityByName = get_entity_by_name
    )
    deprecated_get_property(method_props, this, s)
end

function update(this::Scene)
    # update here
end

function get_colliders_in_range(this::Scene, originCollider)
    # search for colliders in colliders that could possibly touch origin collider and return as array
end

function get_entity_by_name(this::Scene, name)
    for entity in this.entities
        if entity.name == name
            return entity
        end
    end

    @warn "No entity with name $name found"
    return C_NULL
end
