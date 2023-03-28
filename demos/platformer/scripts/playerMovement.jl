include("../../../src/SceneInstance.jl")
include("../../../src/Macros.jl")
include("../../../src/Math/Vector2f.jl")

mutable struct PlayerMovement
    canMove
    input
    isFacingRight
    isJump 
    parent

    function PlayerMovement(canMove)
        this = new()
        
        this.canMove = canMove
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
            #SceneInstance.screenButtons[1].addClickEvent(event)
        end
    elseif s == :update
        function(deltaTime)
            x = 0
            speed = 5
            #println(this.parent.getComponent(Transform).position)
            buttons = InputInstance.buttons
            y = this.parent.getRigidbody().getVelocity().y
            if (Button_Jump::Button in buttons || this.isJump) && this.parent.getRigidbody().grounded && this.canMove
                this.parent.getRigidbody().grounded = false
                y = -5.0
                SceneInstance.sounds[1].toggleSound()
                this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[3]
            end
            if Button_Left::Button in buttons && this.canMove
                # println("Left Pressed")
                x = -speed
                if this.isFacingRight
                    this.isFacingRight = false
                    this.parent.getSprite().flip()
                end
                if this.parent.getRigidbody().grounded
                    this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[2]
                end
            elseif Button_Right::Button in buttons && this.canMove
                x = speed
                if !this.isFacingRight
                    this.isFacingRight = true
                    this.parent.getSprite().flip()
                end
                if this.parent.getRigidbody().grounded
                    this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[2]
                end
            elseif this.parent.getRigidbody().grounded
                #set idle
                this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[1]
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