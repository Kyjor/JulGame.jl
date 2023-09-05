module TransformModule
    using ..Component.JulGame   
    export Transform
    mutable struct Transform
        rotation::Float64
        position::Math.Vector2f
        scale::Math.Vector2f
            
        function Transform()
            this = new()

            this.position = Math.Vector2f(0.0, 0.0)
            this.scale = Math.Vector2f(1.0, 1.0)
            this.rotation = 0.0

            return this
        end

        function Transform(position::Math.Vector2f)
            this = new()
    
            this.position = position
            this.scale = Math.Vector2f(1.0, 1.0)
            this.rotation = 0.0
    
            return this
        end

        function Transform(position::Math.Vector2f, scale::Math.Vector2f)
            this = new()
    
            this.position = position
            this.scale = scale
            this.rotation = 0.0
    
            return this
        end

        function Transform(position::Math.Vector2f, scale::Math.Vector2f, rotation = 0.0)
            this = new()
        
            this.position = position
            this.scale = scale
            this.rotation = rotation
        
            return this
        end

        function Transform(rotation::Float64, position::Math.Vector2f, scale::Math.Vector2f)
            this = new()
    
            this.position = position
            this.scale = scale
            this.rotation = rotation
    
            return this
        end
    end

    function Base.getproperty(this::Transform, s::Symbol)
        if s == :getPosition
            function()
                return this.position
            end
        elseif s == :setPosition
            function(position::Math.Vector2f)
                this.position = position
            end
        elseif s == :getScale
            function()
                return this.scale
            end
        elseif s == :setScale
            function(scale::Math.Vector2f)
                this.scale = scale
            end
        elseif s == :getRotation
            function()
                return this.rotation
            end
        elseif s == :setRotation
            function(rotation::Float64)
                this.rotation = rotation
            end
        elseif s == :update
            function()
                #println(this.position)
            end
        elseif s == :setVector2fValue
            function(field, x, y)
                setfield!(this, field, Math.Vector2f(x,y))
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
            end
        end
    end
end