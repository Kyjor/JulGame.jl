module AnimationModule 
    using ..Component.JulGame

    export Animation
    mutable struct Animation
        animatedFPS::Int32
        frames::Vector{Math.Vector4}

        function Animation(frames::Vector{Math.Vector4}, animatedFPS::Int32)
            this = new()
            
            this.animatedFPS = animatedFPS
            this.frames = frames

            return this
        end
    end

    function Base.getproperty(this::Animation, s::Symbol)
        if s == :updateArrayValue
            function(value, field, index::Int32)
                fieldToUpdate = getfield(this, field)
                if this.getType(value) == "_Vector4"
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
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end
    end
end