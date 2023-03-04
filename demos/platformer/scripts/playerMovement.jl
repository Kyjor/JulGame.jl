include("../../../src/SceneInstance.jl")
include("../../../src/Macros.jl")
include("../../../src/Math/Vector2f.jl")

mutable struct PlayerMovement
    input
    isFacingRight
    isJump 
    parent

    function PlayerMovement()
        this = new()
        
        this.input = C_NULL
        this.isFacingRight = true
        this.isJump = false
        this.parent = C_NULL
        this.initialize()

        return this
    end
end

function Base.getproperty(this::PlayerMovement, s::Symbol)
    if s == :initialize
        function()
            event = @event begin
                this.jump()
            end
            SceneInstance.screenButtons[1].addClickEvent(event)
        end
    elseif s == :update
        function()
            x = 0
            speed = 5

            buttons = InputInstance.buttons
            y = this.parent.getRigidbody().getVelocity().y
            if (Button_Jump::Button in buttons || this.isJump) && this.parent.getRigidbody().grounded
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
            this.isJump = false
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    elseif s == :jump
        function()
            this.isJump = true
            SceneInstance.sounds[1].toggleSound()
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end