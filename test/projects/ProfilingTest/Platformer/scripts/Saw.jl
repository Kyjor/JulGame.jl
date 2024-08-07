mutable struct Saw
    animator::AnimatorModule.Animator
    endingY::Int32
    isMovingUp::Bool
    rotation::Int32
    parent::JulGame.EntityModule.Entity
    sound::SoundSourceModule.SoundSource
    speed::Number
    startingY::Int32

    function Saw(speed::Number = 5, startingY::Int32 = Int32(0), endingY::Int32 = Int32(0))
        this = new()

        this.endingY = endingY
        this.isMovingUp = false
        this.rotation = 0
        this.speed = speed
        this.startingY = startingY

        return this
    end
end

function Base.getproperty(this::Saw, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function(deltaTime)
            this.rotation += 5
            this.parent.sprite.rotation =  this.rotation % 360

            if this.parent.transform.position.y >= this.startingY && !this.isMovingUp
                this.isMovingUp = true
            elseif this.parent.transform.position.y <= this.endingY && this.isMovingUp
                this.isMovingUp = false
            end

            if this.isMovingUp
                this.parent.transform.position = Vector2f(this.parent.transform.position.x, this.parent.transform.position.y - this.speed*deltaTime)
            else
                this.parent.transform.position = Vector2f(this.parent.transform.position.x, this.parent.transform.position.y + this.speed*deltaTime)
            end
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :handleCollisions
        function()
        end
    elseif s == :onShutDown
        function()
        end
    else
        getfield(this, s)
    end
end