export {}
import { Camera } from "./Camera/Camera";


    // using ..JulGame
    
    
    class Scene {
        camera: null | Camera
        colliders: any[]
        entities: any[]
        rigidbodies: any[]
        uiElements: any[]
        name: string
        batchedLayers: Record<number, any>  // Static sprite batching: layer => BatchedLayer

        constructor() {
            

            this.camera = null
            this.colliders = []
            this.entities = []
            this.rigidbodies = []
            this.uiElements = []
            this.batchedLayers = {}

        }
    }

    function get_entity_by_name(selfOrName: Scene | string, name?: string) {
        if (typeof selfOrName === "string") {
            return get_entity_by_name(MAIN.scene, selfOrName)
        }
        const self = selfOrName
        for (const entity of self.entities) {
            if (entity.name == name) {
                return entity
            }
        }

        console.debug(`No entity with name ${name} found`)
        return null
    }

    function get_entities_by_name(selfOrName: Scene | string, name?: string) {
        if (typeof selfOrName === "string") {
            return get_entities_by_name(MAIN.scene, selfOrName)
        }
        const self = selfOrName
        let entities = []
        for (const entity of self.entities) {
            if (entity.name == name) {
                entities.push(entity)
            }
        }

        if (entities.length == 0) {
            console.debug(`No entity with name ${name} found`)
        }
        return entities
    }

    function get_entity_by_id(selfOrName: Scene | string, id?: string) {
        if (typeof selfOrName === "string") {
            return get_entity_by_id(MAIN.scene, selfOrName)
        }
        const self = selfOrName
        for (const entity of self.entities) {
            if (entity.id == id) {
                return entity
            }
        }

        console.debug(`No entity with id ${id} found`)
        return null
    }

    function get_ui_element_by_name(selfOrName: Scene | string, name?: string) {
        if (typeof selfOrName === "string") {
            return get_ui_element_by_name(MAIN.scene, selfOrName)
        }
        const self = selfOrName
        for (const entity of self.uiElements) {
            if (entity.name == name) {
                return entity
            }
        }

        console.debug(`No entity with name ${name} found`)
        return null
    }

    function get_ui_element_by_id(selfOrName: Scene | string, id?: string) {
        if (typeof selfOrName === "string") {
            return get_ui_element_by_id(MAIN.scene, selfOrName)
        }
        const self = selfOrName
        for (const element of self.uiElements) {
            if (element.id == id) {
                return element
            }
        }

        console.debug(`No ui element with id ${id} found`)
        return null
    }
export { Scene, get_entities_by_name, get_entity_by_id, get_entity_by_name, get_ui_element_by_id, get_ui_element_by_name }
