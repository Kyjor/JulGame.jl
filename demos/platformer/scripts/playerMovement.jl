include("../../../src/SceneInstance.jl")
include("../../../src/Macros.jl")
include("../../../src/Math/Vector2f.jl")

mutable struct PlayerMovement
    canMove
    gameManager
    input
    isFacingRight
    isJump 
    parent

    function PlayerMovement(canMove)
        this = new()
        
        this.canMove = canMove
        this.gameManager = C_NULL
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
            # event = @event begin
            #     this.jump()
            # end
            #SceneInstance.screenButtons[1].addClickEvent(event)
        end
    elseif s == :update
        function(deltaTime)
            if this.parent.getTransform().position.x < -7 
                dialogue = this.gameManager.dialogue
                secretDialogue = this.gameManager.secretDialogue
                SceneInstance.camera.target = Transform(Vector2f(-8, 7.75))
                secretDialogue.isPaused = false
                SceneInstance.textBoxes[1].updateText(" ")
                if this.parent.getTransform().position.y > 10
                    # Reset game
                    dialogue.currentMessageIndex = 1
                    dialogue.currentPositionInMessage = 1
                    dialogue.currentMessage = dialogue.messages[1]
                    dialogue.isPaused = false
                    dialogue.isReadingMessage = false
                    dialogue.isQueueingNextMessage = true

                    secretDialogue.currentMessageIndex = 1
                    secretDialogue.currentPositionInMessage = 1
                    secretDialogue.currentMessage = secretDialogue.messages[1]
                    secretDialogue.isPaused = true
                    secretDialogue.isReadingMessage = false
                    secretDialogue.isQueueingNextMessage = true
                    SceneInstance.textBoxes[2].updateText(" ")

                    SceneInstance.camera.target = Transform(Vector2f(0, 7.75))
                    this.canMove = false
                    this.parent.getTransform().position = Vector2f(0.0, -1.0)
                    this.gameManager.potGoingDown = true
                    this.gameManager.goldPot.getTransform().position = Vector2f(2,6)
                    this.gameManager.currentAct = 1
                    SceneInstance.colliders[2].enabled = true
                end
            elseif this.parent.getTransform().position.y > 10 
                this.parent.getTransform().position = Vector2f(0.0, -1.0)
                SceneInstance.entities[15].isActive = true
                SceneInstance.entities[16].isActive = true
                this.gameManager.dialogue.isPaused = false
            end
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
            collisionEvent = @event begin
                this.handleCollisions()
            end
            this.parent.getComponent(Collider).addCollisionEvent(collisionEvent)
        end
    elseif s == :handleCollisions
        function()
            gm = this.gameManager
            collider = this.parent.getComponent(Collider)
            for collision in collider.currentCollisions
                if collision.tag == "block"
                    # remove all blocks, reveal money
                    for moneyBlock in gm.moneyBlocks
                        moneyBlock.isActive = false
                    end
                    hit = collision.parent.getComponent(Transform)

                    pot = gm.goldPot.getComponent(Transform)
                    if hit.position.x == -2.0
                        pot.position = Vector2f(0.0, 7.0)
                    elseif hit.position.x == 0.0
                        pot.position = Vector2f(2.0, 7.0)
                    elseif hit.position.x == 2.0
                        pot.position = Vector2f(-2.0, 7.0)
                    end
                    gm.goldPot.isActive = true
                    this.canMove = false
                elseif collision.tag == "gold"
                    gm.goldPot.isActive = false
                    gm.dialogue.isPaused = false
                    for platform in gm.platforms
                        platform.isActive = false
                    end
                    this.canMove = false
                end
            end
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end