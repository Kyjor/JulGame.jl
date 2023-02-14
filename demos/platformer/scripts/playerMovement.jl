include("../../../src/Math/Vector2f.jl")

mutable struct PlayerMovement
    input
    isFacingRight
    parent

    function PlayerMovement()
        this = new()
        
        this.input = C_NULL
        this.isFacingRight = true
        this.parent = C_NULL
        this.initialize()

        return this
    end
end

function Base.getproperty(this::PlayerMovement, s::Symbol)
    if s == :initialize
        function()
        end
    elseif s == :update
        function()
        x = 0
        speed = 5

            buttons = InputInstance.buttons
            y = this.parent.getRigidbody().getVelocity().y
            if Button_Jump::Button in buttons && this.parent.getRigidbody().grounded
                println("Jump Pressed")
                this.parent.getRigidbody().grounded = false
                y = -5.0
            end
            if Button_Left::Button in buttons
                # println("Left Pressed")
                x = -speed
                if this.isFacingRight
                    this.isFacingRight = false
                    this.parent.getSprite().flip()
                end
            elseif Button_Right::Button in buttons
                x = speed
                if !this.isFacingRight
                    this.isFacingRight = true
                    this.parent.getSprite().flip()
                end
            end
            

            this.parent.getRigidbody().setVelocity(Vector2f(x, y))
            x = 0
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end