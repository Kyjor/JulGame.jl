module AnimationModule 
using SimpleDirectMediaLayer.LibSDL2
using ..Component.julGame

export Animation
mutable struct Animation
    animatedFPS::Int64
    frames::Array{Math.Vector4}
    parent
    sprite

    function Animation(frames, animatedFPS)
        this = new()
        
        this.animatedFPS = animatedFPS
        this.frames = frames
        this.parent = C_NULL
        this.sprite = C_NULL

        return this
    end
end

function Base.getproperty(this::Animation, s::Symbol)
    if s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :updateArrayValue
        function(value, field, index)
            fieldToUpdate = getfield(this, field)
            if this.getType(value) == "Vector4"
                fieldToUpdate[index] = Math.Vector4(value.x, value.y, value.w, value.h)
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