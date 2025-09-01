module TransformModule
    using ..Component.JulGame 
    import ..Component
    
    export Transform
    mutable struct Transform
        position::Math.Vector3f
        scale::Math.Vector3f
        rotation::Math.Vector3f
        screenPosition::Math.Vector2
        screenRotation::Math.Vector2
        screenSize::Math.Vector2
            
        function Transform(position::Union{Math.Vector3f, Math.Vector2f} = Math.Vector3f(0.0, 0.0, 0.0), scale::Union{Math.Vector3f, Math.Vector2f} = Math.Vector3f(1.0, 1.0, 1.0), rotation::Union{Math.Vector3f, Math.Vector2f} = Math.Vector3f(0.0, 0.0, 0.0))
            this = new()
            
            this.position = position
            this.scale = scale
            this.rotation = rotation
            this.screenPosition = Math.Vector2(0.0, 0.0)
            this.screenRotation = Math.Vector2(0.0, 0.0)
            this.screenSize = Math.Vector2(0.0, 0.0)
            
            return this
        end   
    end     

    function Component.set_position(this::Transform, position::Union{Math.Vector3f, Math.Vector2f})
        this.position = position
    end

    function Component.is_mouse_hovering(this::Transform)
        mousePosition = JulGame.InputModule.get_mouse_position_in_world_space()
        if mousePosition.x >= this.position.x && mousePosition.x <= this.position.x + this.scale.x && mousePosition.y >= this.position.y && mousePosition.y <= this.position.y + this.scale.y
            return true
        end
        
        return false
    end
end
