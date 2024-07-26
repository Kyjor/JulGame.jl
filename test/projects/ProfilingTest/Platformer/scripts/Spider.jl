using JulGame.AnimationModule
using JulGame.AnimatorModule
using JulGame.RigidbodyModule
using JulGame.Macros
using JulGame.Math
using JulGame.MainLoop
using JulGame.SoundSourceModule
using JulGame.TransformModule

mutable struct Spider
    animator
    endingX::Int32
    isMovingRight::Bool
    parent::JulGame.EntityModule.Entity
    sound::SoundSourceModule.SoundSource
    speed::Number
    startingX::Int32

    function Spider(speed::Number = 5, startingX::Int32 = Int32(0), endingX::Int32 = Int32(0))
        this = new()

        this.endingX = endingX
        this.isMovingRight = false
        this.speed = speed
        this.startingX = startingX

        return this
    end
end

function Base.getproperty(this::Spider, s::Symbol)
    if s == :initialize
        function(main)
            this.animator = this.parent.animator
        end
    elseif s == :update
        function(deltaTime)
            if this.parent.transform.position.x <= this.startingX && !this.isMovingRight
                this.parent.sprite.flip()
                this.isMovingRight = true
            elseif this.parent.transform.position.x >= this.endingX && this.isMovingRight
                this.parent.sprite.flip()
                this.isMovingRight = false
            end

            if this.isMovingRight
                this.parent.transform.position = Vector2f(this.parent.transform.position.x + this.speed*deltaTime, this.parent.transform.position.y)
            else
                this.parent.transform.position = Vector2f(this.parent.transform.position.x - this.speed*deltaTime, this.parent.transform.position.y)
            end
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :handleCollisions
        function()
        end
    else
        getfield(this, s)
    end
end