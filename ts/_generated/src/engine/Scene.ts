export {}

    // using ..JulGame
    
    
    class Scene {
        camera: null | any
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
            this.name = ""

        }
    }

    /* Julia multiple-dispatch → TS overloads (one implementation; no duplicate identifiers). */
    function get_entity_by_name(self: Scene, name: string): any;
    function get_entity_by_name(name: string): any;
    function get_entity_by_name(selfOrName: Scene | string, name?: string): any {
        if (typeof selfOrName === "string") {
            return get_entity_by_name((globalThis as any).MAIN.scene, selfOrName);
        }
        const self = selfOrName;
        const n = name as string;
        for (const entity of self.entities) {
            if (entity.name == n) {
                return entity;
            }
        }
        console.debug(`No entity with name ${n} found`);
        return null;
    }

    function get_entities_by_name(self: Scene, name: string): any[];
    function get_entities_by_name(name: string): any[];
    function get_entities_by_name(selfOrName: Scene | string, name?: string): any[] {
        if (typeof selfOrName === "string") {
            return get_entities_by_name((globalThis as any).MAIN.scene, selfOrName);
        }
        const self = selfOrName;
        const n = name as string;
        let entities = [];
        for (const entity of self.entities) {
            if (entity.name == n) {
                entities.push(entity);
            }
        }
        if (entities.length == 0) {
            console.debug(`No entity with name ${n} found`);
        }
        return entities;
    }

    function get_entity_by_id(self: Scene, id: string): any;
    function get_entity_by_id(id: string): any;
    function get_entity_by_id(selfOrId: Scene | string, id?: string): any {
        if (typeof selfOrId === "string") {
            return get_entity_by_id((globalThis as any).MAIN.scene, selfOrId);
        }
        const self = selfOrId;
        const i = id as string;
        for (const entity of self.entities) {
            if (entity.id == i) {
                return entity;
            }
        }
        console.debug(`No entity with id ${i} found`);
        return null;
    }

    function get_ui_element_by_name(self: Scene, name: string): any;
    function get_ui_element_by_name(name: string): any;
    function get_ui_element_by_name(selfOrName: Scene | string, name?: string): any {
        if (typeof selfOrName === "string") {
            return get_ui_element_by_name((globalThis as any).MAIN.scene, selfOrName);
        }
        const self = selfOrName;
        const n = name as string;
        for (const entity of self.uiElements) {
            if (entity.name == n) {
                return entity;
            }
        }
        console.debug(`No entity with name ${n} found`);
        return null;
    }

    function get_ui_element_by_id(self: Scene, id: string): any;
    function get_ui_element_by_id(id: string): any;
    function get_ui_element_by_id(selfOrId: Scene | string, id?: string): any {
        if (typeof selfOrId === "string") {
            return get_ui_element_by_id((globalThis as any).MAIN.scene, selfOrId);
        }
        const self = selfOrId;
        const i = id as string;
        for (const element of self.uiElements) {
            if (element.id == i) {
                return element;
            }
        }
        console.debug(`No ui element with id ${i} found`);
        return null;
    }

export { Scene }
