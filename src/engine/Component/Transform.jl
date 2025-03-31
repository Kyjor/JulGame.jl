module TransformModule
    using ..Component.JulGame 
    import ..Component
    
    export Transform
    mutable struct Transform
        position::Math.Vector3f
        scale::Math.Vector3f
        rotation::Math.Vector3f
            
        function Transform(position::Union{Math.Vector3f, Math.Vector2f} = Math.Vector3f(0.0, 0.0, 0.0), scale::Union{Math.Vector3f, Math.Vector2f} = Math.Vector3f(1.0, 1.0, 1.0), rotation::Union{Math.Vector3f, Math.Vector2f} = Math.Vector3f(0.0, 0.0, 0.0))
            this = new()
            
            this.position = position
            this.scale = scale
            this.rotation = rotation

            return this
        end   
    end     

    function Component.set_position(this::Transform, position::Union{Math.Vector3f, Math.Vector2f})
        this.position = position
    end
end
