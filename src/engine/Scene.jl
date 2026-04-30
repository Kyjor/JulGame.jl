module SceneModule
    using ..JulGame
    
    export Scene
    mutable struct Scene
        camera::Union{Nothing, JulGame.CameraModule.Camera}
        colliders::Vector{Any}
        entities::Vector{Any}
        rigidbodies::Vector{Any}
        uiElements::Vector{Any}
        name::String
        batchedLayers::Dict{Int, Any}  # Static sprite batching: layer => BatchedLayer

        function Scene()
            this = new()

            this.camera = nothing
            this.colliders = []
            this.entities = []
            this.rigidbodies = []
            this.uiElements = []
            this.batchedLayers = Dict{Int, Any}()

            return this
        end
    end

    function get_entity_by_name(this::Scene, name)
        for entity in this.entities
            if entity.name == name
                return entity
            end
        end

        @debug "No entity with name $name found"
        return nothing
    end

    function get_entity_by_name(name)
        return get_entity_by_name(MAIN.scene, name)
    end

    function get_entities_by_name(this::Scene, name)
        entities = []
        for entity in this.entities
            if entity.name == name
                push!(entities, entity)
            end
        end

        if length(entities) == 0
            @debug "No entity with name $name found"
        end
        return entities
    end

    function get_entities_by_name(name)
        return get_entities_by_name(MAIN.scene, name)
    end

    function get_entity_by_id(this::Scene, id)
        for entity in this.entities
            if entity.id == id
                return entity
            end
        end

        @debug "No entity with id $id found"
        return nothing
    end

    function get_entity_by_id(id::String)
        return get_entity_by_id(MAIN.scene, id)
    end

    function get_ui_element_by_name(this::Scene, name)
        for entity in this.uiElements
            if entity.name == name
                return entity
            end
        end

        @debug "No entity with name $name found"
        return nothing
    end

    function get_ui_element_by_name(name)
        return get_ui_element_by_name(MAIN.scene, name)
    end

    function get_ui_element_by_id(this::Scene, id)
        for element in this.uiElements
            if element.id == id
                return element
            end
        end

        @debug "No ui element with id $id found"
        return nothing
    end

    function get_ui_element_by_id(id::String)
        return get_ui_element_by_id(MAIN.scene, id)
    end
end

