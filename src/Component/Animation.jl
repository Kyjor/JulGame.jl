module AnimationModule 
    using ..Component.JulGame

    export Animation
    mutable struct Animation
        animatedFPS::Integer # public
        frames::Array{Math.Vector4} # public
        parent::Any # public
        sprite::Any # public
        test # private

        function Animation(frames, animatedFPS)
            this = new()
            
            this.animatedFPS = animatedFPS
            this.frames = frames
            this.parent = C_NULL
            this.sprite = C_NULL
            this.test = "test"

            return this
        end
    end

    function Base.getproperty(this::Animation, s::Symbol, caller::Symbol)
        try
            if caller == Symbol(":$(@__MODULE__)")
                getfield(this, s)
            else
                throw(UndefVarError(s))
            end
        catch e
            println(e)
        end
    end

    function Base.getproperty(this::Animation, s::Symbol)
        public_props = (:animatedFPS, :frames, :parent, :sprite)

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
                if s in public_props
                    getfield(this, s)
                else
                    throw(UndefVarError(s))
               end
            catch e
                println(e)
            end
        end
    end
    
    export GetAnimationTest
    """
        GetAnimationTest(anim)
        Gets the value of test 
    """
    function GetAnimationTest(anim::Animation)
        @atomic Symbol(":$(@__MODULE__)") anim.test
    end
end