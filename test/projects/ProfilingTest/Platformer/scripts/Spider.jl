using JulGame.AnimationModule
using JulGame.AnimatorModule
using JulGame.RigidbodyModule
using JulGame.Macros
using JulGame.Math
using JulGame.MainLoop
using JulGame.SoundSourceModule
using JulGame.TransformModule

mutable struct Spider
    animator::AnimatorModule.Animator
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
        function()
            this.animator = this.parent.getAnimator()
        end
    elseif s == :update
        function(deltaTime)
            if this.parent.getTransform().position.x <= this.startingX && !this.isMovingRight
                this.parent.getSprite().flip()
                this.isMovingRight = true
            elseif this.parent.getTransform().position.x >= this.endingX && this.isMovingRight
                this.parent.getSprite().flip()
                this.isMovingRight = false
            end

            if this.isMovingRight
                this.parent.getTransform().position = Vector2f(this.parent.getTransform().position.x + this.speed*deltaTime, this.parent.getTransform().position.y)
            else
                this.parent.getTransform().position = Vector2f(this.parent.getTransform().position.x - this.speed*deltaTime, this.parent.getTransform().position.y)
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