
    // using ..JulGame
    
    
    class Scene {
        camera: Nothing | Camera
        colliders: any[]
        entities: any[]
        rigidbodies: any[]
        uiElements: any[]
        name: string
        batchedLayers::Dict{Int, Any}  // Static sprite batching: layer => BatchedLayer

        constructor() {
            

            this.camera = nothing
            this.colliders = []
            this.entities = []
            this.rigidbodies = []
            this.uiElements = []
            this.batchedLayers = Dict{Int, Any}()

        }
    }

    function get_entity_by_name(this: Scene,  name) {
        for (const entity of this.entities) {
            if (entity.name == name) {
                return entity
            }
        }

        console.debug("No entity with name $name found")
        return nothing
    }

    function get_entity_by_name(name) {
        return get_entity_by_name(MAIN.scene, name)
    }

    function get_entities_by_name(this: Scene,  name) {
        let entities = []
        for (const entity of this.entities) {
            if (entity.name == name) {
                entities.push(entity)
            }
        }

        if (length(entities) == 0) {
            console.debug("No entity with name $name found")
        }
        return entities
    }

    function get_entities_by_name(name) {
        return get_entities_by_name(MAIN.scene, name)
    }

    function get_entity_by_id(this: Scene,  id) {
        for (const entity of this.entities) {
            if (entity.id == id) {
                return entity
            }
        }

        console.debug("No entity with id $id found")
        return nothing
    }

    function get_entity_by_id(id: string) {
        return get_entity_by_id(MAIN.scene, id)
    }

    function get_ui_element_by_name(this: Scene,  name) {
        for (const entity of this.uiElements) {
            if (entity.name == name) {
                return entity
            }
        }

        console.debug("No entity with name $name found")
        return nothing
    }

    function get_ui_element_by_name(name) {
        return get_ui_element_by_name(MAIN.scene, name)
    }

    function get_ui_element_by_id(this: Scene,  id) {
        for (const element of this.uiElements) {
            if (element.id == id) {
                return element
            }
        }

        console.debug("No ui element with id $id found")
        return nothing
    }

    function get_ui_element_by_id(id: string) {
        return get_ui_element_by_id(MAIN.scene, id)
    }
