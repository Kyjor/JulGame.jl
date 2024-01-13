using JulGame.AnimationModule
using JulGame.AnimatorModule
using JulGame.RigidbodyModule
using JulGame.Macros
using JulGame.Math
using JulGame.MainLoop
using JulGame.SoundSourceModule
using JulGame.TransformModule

mutable struct PlayerMovement
    animator
    cameraTarget
    canMove
    coinSound
    deathsThisLevel
    gameManager
    hurtSound
    input
    isFacingRight
    isJump 
    jumpVelocity
    jumpSound
    parent
    starSound

    xDir
    yDir

    function PlayerMovement(jumpVelocity = -10)
        this = new()

        this.canMove = false
        this.input = C_NULL
        this.isFacingRight = true
        this.isJump = false
        this.parent = C_NULL
        this.jumpSound = C_NULL 
        this.jumpVelocity = -5

        this.xDir = 0
        this.yDir = 0

        return this
    end
end

function Base.getproperty(this::PlayerMovement, s::Symbol)
    if s == :initialize
        function()
            this.animator = this.parent.animator
            this.animator.currentAnimation = this.animator.animations[1]
            this.jumpSound = this.parent.soundSource
            this.cameraTarget = Transform(Vector2f(this.parent.transform.position.x, 0))
            MAIN.scene.camera.target = this.cameraTarget
            this.gameManager = MAIN.scene.getEntityByName("Game Manager").scripts[1]
            this.deathsThisLevel = 0
            this.coinSound = this.parent.createSoundSource(SoundSource(Int32(-1), false, "coin.wav", Int32(50)))
            this.hurtSound = this.parent.createSoundSource(SoundSource(Int32(-1), false, "hit.wav", Int32(50)))
            this.starSound = this.parent.createSoundSource(SoundSource(Int32(-1), false, "power-up.wav", Int32(50)))
        end
    elseif s == :update
        function(deltaTime)
            this.canMove = true
            x = 0
            speed = 10
            input = MAIN.input

            # Inputs match SDL2 scancodes after "SDL_SCANCODE_"
            # https://wiki.libsdl.org/SDL2/SDL_Scancode
            # Spaces full scancode is "SDL_SCANCODE_SPACE" so we use "SPACE". Every other key is the same.
            if this.parent.rigidbody.grounded
                this.jumpSound.toggleSound()
                SetVelocity(this.parent.rigidbody, Vector2f(this.parent.rigidbody.getVelocity().x, 0))
                AddVelocity(this.parent.rigidbody, Vector2f(0, this.jumpVelocity))
                this.animator.currentAnimation = this.animator.animations[3]
            end
            if this.parent.rigidbody.grounded
                this.animator.currentAnimation = this.animator.animations[2]
            end
            x = speed
            if !this.isFacingRight
                this.isFacingRight = true
                this.parent.sprite.flip()
            end
            
            SetVelocity(this.parent.rigidbody, Vector2f(x, this.parent.rigidbody.getVelocity().y))
            x = 0
            this.isJump = false
            if this.parent.transform.position.y > 8
                this.respawn()
                if this.gameManager.currentLevel == 1
                    if this.deathsThisLevel == 0
                        this.gameManager.starCount = this.gameManager.starCount + 1
                    end
                    this.gameManager.currentLevel = 2
                    ChangeScene("level_2.json")
                elseif this.gameManager.currentLevel == 2
                    if this.deathsThisLevel == 0
                        this.gameManager.starCount = this.gameManager.starCount + 1
                    end
                    this.gameManager.currentLevel = 3
                    ChangeScene("level_3.json")
                else 
                    # you win text
                    MAIN.scene.textBoxes[1].isCenteredX, MAIN.scene.textBoxes[1].isCenteredY = true, true
                    MAIN.scene.textBoxes[1].updateText("You Win!")
                    MAIN.scene.textBoxes[1].setColor(0,0,0)
                    if this.deathsThisLevel == 0
                        this.gameManager.starCount = this.gameManager.starCount + 1
                        MAIN.scene.textBoxes[2].updateText(string(this.gameManager.starCount))
                    end
                end
            end

            speed = abs(5 * (1 - cos(this.parent.transform.position.x- this.cameraTarget.position.x)))
            speed = clamp(speed, 1, 5)
            if this.cameraTarget.position != Vector2f(this.parent.transform.position.x, 2.75)
                this.cameraTarget.position = Vector2f(this.cameraTarget.position.x + (this.parent.transform.position.x - this.cameraTarget.position.x) * deltaTime  * speed, 2.75)
            end
            
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
            collisionEvent = @argevent (col) this.handleCollisions(col)
            this.parent.collider.addCollisionEvent(collisionEvent)
        end
    elseif s == :handleCollisions
        function(otherCollider)
            if otherCollider.tag == "Coin"
                DestroyEntity(otherCollider.parent)
                this.coinSound.toggleSound()
                MAIN.scene.textBoxes[1].updateText(string(parse(Int32, split(MAIN.scene.textBoxes[1].text, "/")[1]) + 1, "/", parse(Int32, split(MAIN.scene.textBoxes[1].text, "/")[2])))
            elseif otherCollider.tag == "Star"
                this.starSound.toggleSound()
                DestroyEntity(otherCollider.parent)
                this.gameManager.starCount = this.gameManager.starCount + 1
                MAIN.scene.textBoxes[2].updateText(string(this.gameManager.starCount))
            end
        end
    elseif s == :respawn
        function()
            this.hurtSound.toggleSound()
            this.parent.transform.position = Vector2f(1, 4)
            this.gameManager.starCount = max(this.gameManager.starCount - 1, 0)
            MAIN.scene.textBoxes[2].updateText(string(this.gameManager.starCount))
            this.deathsThisLevel += 1
        end
    else
        getfield(this, s)
    end
end