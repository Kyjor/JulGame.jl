mutable struct Fish
    animator
    endingY::Int32
    isFire::Bool
    isMovingUp::Bool
    parent::JulGame.EntityModule.Entity
    sound::SoundSourceModule.SoundSource
    speed::Number
    startingY::Int32

    function Fish(speed::Number = 5, startingY::Int32 = Int32(0), endingY::Int32 = Int32(0), isFire::Bool = false)
        this = new()

        this.endingY = endingY
        this.isFire = isFire
        this.isMovingUp = false
        this.speed = speed
        this.startingY = startingY

        return this
    end
end

function Base.getproperty(this::Fish, s::Symbol)
    if s == :initialize
        function()
            this.animator = this.parent.animator
            this.parent.sprite.rotation = 90
        end
    elseif s == :update
        function(deltaTime)
            if this.parent.transform.position.y >= this.startingY && !this.isMovingUp
                this.parent.sprite.rotation = this.isFire ? 0 : 90
                this.isMovingUp = true
            elseif this.parent.transform.position.y <= this.endingY && this.isMovingUp
                this.parent.sprite.rotation = this.isFire ? 180 : 270
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