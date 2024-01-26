module TransformModule
    using ..Component.JulGame 
    import ..Component.JulGame: deprecated_get_property  
    export Transform
    mutable struct Transform
        rotation::Float64
        position::Math.Vector2f
        scale::Math.Vector2f
            
        function Transform(position::Math.Vector2f = Math.Vector2f(0.0, 0.0), scale::Math.Vector2f = Math.Vector2f(1.0, 1.0), rotation::Float64 = 0.0)
            this = new()
            
            this.position = position
            this.scale = scale
            this.rotation = rotation
            
            return this
        end   
    end     

    function Base.getproperty(this::Transform, s::Symbol)
        method_props = (
            getPosition = get_position,
            setPosition = set_position,
            getScale = get_scale,
            setScale = set_scale,
            getRotation = get_rotation,
            setRotation = set_rotation,
            update = update,
            setVector2fValue = set_vector2f_value
        )
        deprecated_get_property(method_props, this, s)
    end


    function get_position(this::Transform)
        return this.position
    end

    function set_position(this::Transform, position::Math.Vector2f)
        this.position = position
    end

    function get_scale(this::Transform)
        return this.scale
    end

    function set_scale(this::Transform, scale::Math.Vector2f)
        this.scale = scale
    end

    function get_rotation(this::Transform)
        return this.rotation
    end

    function set_rotation(this::Transform, rotation::Float64)
        this.rotation = rotation
    end

    function update(this::Transform)
        #println(this.position)
    end

    function set_vector2f_value(this::Transform, field, x, y)
        setfield!(this, field, Math.Vector2f(x,y))
    end
end
