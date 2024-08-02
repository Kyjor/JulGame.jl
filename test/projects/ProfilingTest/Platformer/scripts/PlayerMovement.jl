using JulGame.AnimationModule
using JulGame.AnimatorModule
using JulGame.Component
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
            this.gameManager = JulGame.SceneModule.get_entity_by_name(MAIN.scene, "Game Manager").scripts[1]
            this.deathsThisLevel = 0
            this.coinSound = JulGame.create_sound_source(this.parent, SoundSource(Int32(-1), false, "coin.wav", Int32(50)))
            this.hurtSound = JulGame.create_sound_source(this.parent, SoundSource(Int32(-1), false, "hit.wav", Int32(50)))
            this.starSound = JulGame.create_sound_source(this.parent, SoundSource(Int32(-1), false, "power-up.wav", Int32(50)))
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
                Component.toggle_sound(this.jumpSound)

                SetVelocity(this.parent.rigidbody, Vector2f(Component.get_velocity(this.parent.rigidbody).x, 0))
                AddVelocity(this.parent.rigidbody, Vector2f(0, this.jumpVelocity))
                this.animator.currentAnimation = this.animator.animations[3]
            end
            if this.parent.rigidbody.grounded
                this.animator.currentAnimation = this.animator.animations[2]
            end
            x = speed
            if !this.isFacingRight
                this.isFacingRight = true
                Component.flip(this.parent.sprite)
            end
            
            SetVelocity(this.parent.rigidbody, Vector2f(x, Component.get_velocity(this.parent.rigidbody).y))
            x = 0
            this.isJump = false
            if this.parent.transform.position.y > 8
                this.respawn()
                if this.gameManager.currentLevel == 1
                    if this.deathsThisLevel == 0
                        this.gameManager.starCount = this.gameManager.starCount + 1
                    end
                    this.gameManager.currentLevel = 2
                    MainLoop.change_scene("level_2.json")
                elseif this.gameManager.currentLevel == 2
                    if this.deathsThisLevel == 0
                        this.gameManager.starCount = this.gameManager.starCount + 1
                    end
                    this.gameManager.currentLevel = 3
                    MainLoop.change_scene("level_3.json")
                else 
                    # you win text
                    MAIN.scene.uiElements[1].isCenteredX, MAIN.scene.uiElements[1].isCenteredY = true, true
                    JulGame.UI.update_text(MAIN.scene.uiElements[1], "You Win!")
                    JulGame.UI.set_color(MAIN.scene.uiElements[1], 0, 0, 0)
                    if this.deathsThisLevel == 0
                        this.gameManager.starCount = this.gameManager.starCount + 1
                        JulGame.UI.update_text(MAIN.scene.uiElements[2], string(this.gameManager.starCount))
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
            Component.add_collision_event(this.parent.collider, collisionEvent)
        end
    elseif s == :handleCollisions
        function(otherCollider)
            if otherCollider.tag == "Coin"
                destroy_entity(MAIN, otherCollider.parent)
                Component.toggle_sound(this.coinSound)
                JulGame.UI.update_text(MAIN.scene.uiElements[1], string(parse(Int32, split(MAIN.scene.uiElements[1].text, "/")[1]) + 1, "/", parse(Int32, split(MAIN.scene.uiElements[1].text, "/")[2])))
            elseif otherCollider.tag == "Star"
                Component.toggle_sound(this.starSound)
                destroy_entity(MAIN, otherCollider.parent)
                this.gameManager.starCount = this.gameManager.starCount + 1
                JulGame.UI.update_text(MAIN.scene.uiElements[2], string(this.gameManager.starCount))
            end
        end
    elseif s == :respawn
        function()
            Component.toggle_sound(this.hurtSound)
            this.parent.transform.position = Vector2f(1, 4)
            this.gameManager.starCount = max(this.gameManager.starCount - 1, 0)
            JulGame.UI.update_text(MAIN.scene.uiElements[2], string(this.gameManager.starCount))
            this.deathsThisLevel += 1
        end
    else
        getfield(this, s)
    end
end