module SceneModule

    export Scene
    mutable struct Scene
        camera::Union{Nothing, JulGame.CameraModule.Camera}
        colliders::Vector{Any}
        entities::Vector{Any}
        rigidbodies::Vector{Any}
        screenButtons::Vector{Any}
        uiElements::Vector{Any}

        function Scene()
            this = new()

            this.camera = nothing
            this.colliders = []
            this.entities = []
            this.rigidbodies = []
            this.screenButtons = []
            this.uiElements = []

            return this
        end
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
end

