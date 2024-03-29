module TransformModule
    using ..Component.JulGame 
    import ..Component.JulGame: deprecated_get_property  
    import ..Component
    
    export Transform
    mutable struct Transform
        position::Math.Vector2f
        scale::Math.Vector2f
            
        function Transform(position::Math.Vector2f = Math.Vector2f(0.0, 0.0), scale::Math.Vector2f = Math.Vector2f(1.0, 1.0))
            this = new()
            
            this.position = position
            this.scale = scale
            
            return this
        end   
    end     

    function Base.getproperty(this::Transform, s::Symbol)
        method_props = (
            setPosition = Component.set_position,
            update = Component.update,
            setVector2fValue = Component.set_vector2f_value
        )
        deprecated_get_property(method_props, this, s)
    end

    function Component.set_position(this::Transform, position::Math.Vector2f)
        this.position = position
    end

    function Component.update(this::Transform)
        #println(this.position)
    end

    function Component.set_vector2f_value(this::Transform, field, x, y)
        setfield!(this, field, Math.Vector2f(x,y))
    end
end
