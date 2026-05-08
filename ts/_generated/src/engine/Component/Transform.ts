export {}

    // using ..Component.JulGame 
    // import ..Component
    
    
    class Transform {
        position: Vector3f
        scale: Vector3f
        rotation: Vector3f
        screenPosition: Vector2
        screenRotation: Vector2
        parent

        constructor(position: Vector3f | Vector2f = {x: 0.0, y: 0.0, z: 0.0}, scale: Vector3f | Vector2f = {x: 1.0, y: 1.0, z: 1.0}, rotation: Vector3f | Vector2f = {x: 0.0, y: 0.0, z: 0.0}, parent = null) {
            
            
            this.position = position
            this.scale = scale
            this.rotation = rotation
            this.screenPosition = {x: 0.0, y: 0.0}
            this.screenRotation = {x: 0.0, y: 0.0}
            this.parent = parent
            (globalThis as any).JulGame.EventsModule.ObserverModule.add_observer((event, data) -> on_notify(event, data))

        }   
    }     

    function Component_duplicate(this: ITransform,  parent: any) {
        let newTransform = Transform(this.position, this.scale, this.rotation, this.parent)
        return newTransform
    }

    function Component_set_position(this: ITransform,  position: Vector3f | Vector2f) {
        this.position = position
    }

    function Component_is_mouse_hovering(this: ITransform) {
        let mousePosition = (globalThis as any).JulGame.InputModule.get_mouse_position_in_world_space()
        if (mousePosition.x >= this.position.x && mousePosition.x <= this.position.x + this.scale.x && mousePosition.y >= this.position.y && mousePosition.y <= this.position.y + this.scale.y) {
            return true
        }
        
        return false
    }

    function Base_setproperty(this: ITransform,  property: symbol,  value: any) {
        // only log if the property is already defined
        if ((globalThis as any).JulGame.IS_EDITOR && (globalThis as any).JulGame.IS_EDITOR_PLAY_MODE && isdefined(this, property) && (globalThis as any).JulGame.engine_states.current_state == :game_mode && isdefined(this, :parent) && this.parent !== null) {
            //console.debug("setting transform property $(property) to: $(value)")
            (globalThis as any).JulGame.EventsModule.ObserverModule.notify_observer(:updated_transform, (id = this.parent.id, property = property, oldValue = getfield(this, property), newValue = value))
        }
        // Call the default setproperty! behavior
        invoke(setproperty!, Tuple{Any, Symbol, Any}, this, property, value)
    }

    function on_notify(event: symbol,  data: any) {
        if (event == :updated_transform) {
          //  console.debug("updated_transform oldValue: $(data.oldValue) newValue: $(data.newValue)")
        }
    }
