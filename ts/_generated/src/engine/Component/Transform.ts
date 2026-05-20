export {}

    // using ..Component.JulGame 
    // import ..Component
    
    
    class Transform {
        position: Vector3f
        scale: Vector3f
        rotation: Vector3f
        screenPosition: Vector2
        screenRotation: Vector2
        parent: any

        constructor(position: Vector3f = {x: 0.0, y: 0.0, z: 0.0}, scale = {x: 1.0, y: 1.0, z: 1.0}, rotation = {x: 0.0, y: 0.0, z: 0.0}, parent = null) {
            
            
            this.position = position
            this.scale = scale
            this.rotation = rotation
            this.screenPosition = {x: 0.0, y: 0.0}
            this.screenRotation = {x: 0.0, y: 0.0}
            this.parent = parent


        }   
    }     

    function Component_duplicate(self: ITransform, parent: any) {
        let newTransform = new Transform(self.position, self.scale, self.rotation, self.parent)
        return newTransform
    }

    function Component_is_mouse_hovering(self: ITransform) {
        let mousePosition = (globalThis as any).JulGame.InputModule.get_mouse_position_in_world_space()
        if (mousePosition.x >= self.position.x && mousePosition.x <= self.position.x + self.scale.x && mousePosition.y >= self.position.y && mousePosition.y <= self.position.y + self.scale.y) {
            return true
        }
        
        return false
    }


export { Transform, Component_duplicate }
