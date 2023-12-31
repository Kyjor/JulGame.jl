module AnimationModule 
    using ..Component.JulGame

    export Animation
    mutable struct Animation
        animatedFPS::Int
        frames::Vector{Math.Vector4}

        function Animation(frames::Vector{Math.Vector4}, animatedFPS::Int)
            this = new()
            
            this.animatedFPS = animatedFPS
            this.frames = frames

            return this
        end
    end

    function Base.getproperty(this::Animation, s::Symbol)
        if s == :updateArrayValue
            function(value, field, index::Int)
                fieldToUpdate = getfield(this, field)
                if this.getType(value) == "Vector4"
                    fieldToUpdate[index] = Math.Vector4(value.x, value.y, value.z, value.t)
                end
            end
        elseif s == :appendArray
            function()
                push!(this.frames, Math.Vector4(0,0,0,0))
            end
        elseif s == :getType
            function(item)
                componentFieldType = "$(typeof(item).name.wrapper)"
                return String(split(componentFieldType, '.')[length(split(componentFieldType, '.'))])
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