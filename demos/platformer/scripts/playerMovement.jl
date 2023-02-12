include("../../../src/Math/Vector2f.jl")

mutable struct PlayerMovement
    input
    parent

    function PlayerMovement()
        this = new()
        
        this.input = C_NULL
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
            if Button_Left::Button in buttons
                println("Left Pressed")
                x = -speed
#                 if isFacingRight
#                     isFacingRight = false
#                     flipPlayer = true
#                 end
            elseif Button_Right::Button in buttons
                x = speed
#                 if !isFacingRight
#                     isFacingRight = true
#                     flipPlayer = true
#                 end
            end
            if Button_Jump::Button in buttons
                println("Jump Pressed")
                this.parent.getRigidbody().setVelocity(Vector2f(this.parent.getRigidbody().getVelocity().x, -5.0))
            end

            this.parent.getRigidbody().setVelocity(Vector2f(x, this.parent.getRigidbody().getVelocity().y))
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