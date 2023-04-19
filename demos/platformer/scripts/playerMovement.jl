include("../../../src/Macros.jl")
include("../../../src/Input/Button.jl")
using .julgame.MainLoop

mutable struct PlayerMovement
    canMove
    form
    gameManager
    input
    isFacingRight
    isFalling
    isJump 
    parent

    function PlayerMovement(canMove)
        this = new()
        
        this.canMove = canMove
        this.form = 1
        this.gameManager = C_NULL
        this.input = C_NULL
        this.isFalling = false
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
            #MAIN.scene.screenButtons[1].addClickEvent(event)
        end
    elseif s == :update
        function(deltaTime)
            if this.parent.getTransform().position.x < -7  && !this.gameManager.isEnd
                dialogue = this.gameManager.dialogue
                secretDialogue = this.gameManager.secretDialogue
                MAIN.scene.camera.target = Transform(Vector2f(-8, 7.75))
                #MAIN.scene.sounds[8].toggleSound()
                secretDialogue.isPaused = false
                MAIN.scene.textBoxes[1].updateText(" ")
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
                    MAIN.scene.textBoxes[2].updateText(" ")

                    MAIN.scene.camera.target = Transform(Vector2f(0, 7.75))
                    this.canMove = false
                    this.gameManager.potGoingDown = true
                    this.gameManager.goldPot.getTransform().position = Vector2f(2,6)
                    MAIN.scene.colliders[2].enabled = true
                    this.gameManager.resetPlayer()
                    MAIN.scene.colliders[3].enabled = false
                end
            elseif this.parent.getTransform().position.y > 10 && !this.gameManager.isEnd
                MAIN.scene.sounds[3].toggleSound()
                MAIN.scene.sounds[9].toggleSound()
                this.parent.getTransform().position = Vector2f(0.0, -1.0)
                this.isFalling = true
                this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[(this.form * 4) + 4]
                this.canMove = false
                this.form = 3
                MAIN.scene.entities[15].isActive = true
                MAIN.scene.entities[16].isActive = true
                this.gameManager.dialogue.isPaused = false
            elseif this.parent.getTransform().position.x > 7 && this.gameManager.currentAct != 0 && !this.gameManager.isEnd
                this.gameManager.isEnd = true
                MAIN.scene.camera.target = Transform(Vector2f(15, 7.75))
                dialogue = this.gameManager.dialogue
                winMessages = ["Congrats, you escaped :)", "Goodbye."]
                dialogue.messages = winMessages
                dialogue.currentMessageIndex = 1
                dialogue.currentPositionInMessage = 1
                dialogue.currentMessage = winMessages[1]
                dialogue.isPaused = false
                dialogue.isReadingMessage = false
                dialogue.isQueueingNextMessage = true
            end
            x = 0
            speed = 5
            buttons = MAIN.input.buttons
            y = this.parent.getRigidbody().getVelocity().y
            if ("Button_Jump" in buttons || this.isJump) && this.parent.getRigidbody().grounded && this.canMove
                this.parent.getRigidbody().grounded = false
                y = -5.0
                MAIN.scene.sounds[1].toggleSound()
                this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[(this.form * 4) + 3]
            end
            if "Button_Left" in buttons && this.canMove
                x = -speed
                if this.isFacingRight
                    this.isFacingRight = false
                    this.parent.getSprite().flip()
                end
                if this.parent.getRigidbody().grounded
                    this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[(this.form * 4) + 2]
                end
            elseif "Button_Right" in buttons && this.canMove
                x = speed
                if !this.isFacingRight
                    this.isFacingRight = true
                    this.parent.getSprite().flip()
                end
                if this.parent.getRigidbody().grounded
                    this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[(this.form * 4) + 2]
                end
            elseif this.parent.getRigidbody().grounded
                #set idle
                this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[(this.form * 4) + 1]
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
            if gm.isEnd 
                return
            end
            collider = this.parent.getComponent(Collider)
            for collision in collider.currentCollisions
                if collision.tag == "block"
                    MAIN.scene.sounds[3].toggleSound()
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
                    this.form = 1
                elseif collision.tag == "gold"
                    MAIN.scene.sounds[3].toggleSound()
                    gm.goldPot.isActive = false
                    gm.dialogue.isPaused = false
                    for platform in gm.platforms
                        platform.isActive = false
                    end
                    this.canMove = false
                    this.form = 2
                elseif collision.tag == "ground" && this.isFalling
                    this.isFalling = false
                    gm.dialogue.isPaused = false
                    MAIN.scene.sounds[10].toggleSound()
                    this.parent.getComponent(Animator).currentAnimation = this.parent.getComponent(Animator).animations[(this.form * 4) + 2]
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