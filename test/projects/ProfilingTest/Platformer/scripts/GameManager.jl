using JulGame 

mutable struct GameManager
    currentLevel::Int32
    currentMusic
    main
    soundBank
    starCount::Int32
    parent

    function GameManager()
        this = new()

        this.currentLevel = 1
        this.parent = C_NULL
        this.soundBank = [
            "water-ambience.mp3",
            "lava.wav",
            "strong-wind.wav",
        ]
        this.starCount = 3

        return this
    end
end

function Base.getproperty(this::GameManager, s::Symbol)
    if s == :initialize
        function(main)
            this.main = main
            this.main.scene.camera.offset = JulGame.Math.Vector2f(0, -2.75)
            this.main.cameraBackgroundColor = (30, 111, 80)
            this.main.optimizeSpriteRendering = true

            this.parent.addShape(ShapeModule.Shape(Math.Vector3(0,0,0), Math.Vector2f(10,5),  true, false, Math.Vector2f(0,0), Math.Vector2f(1.2175,0.5)))
            coinUI = this.main.scene.getEntityByName("CoinUI")
            livesUI = this.main.scene.getEntityByName("LivesUI")

            coinUI.persistentBetweenScenes = true
            coinUI.sprite.isWorldEntity = false
            coinUI.sprite.position = JulGame.Math.Vector2f(-.1, 1)

            livesUI.persistentBetweenScenes = true
            livesUI.sprite.isWorldEntity = false
            livesUI.sprite.position = JulGame.Math.Vector2f(-.1, .25)
            
            this.parent.persistentBetweenScenes = true
            if this.currentLevel > 1
                this.currentMusic.unloadSound()
            end

            this.currentMusic = this.parent.createSoundSource(SoundSource(Int32(-1), true, this.soundBank[this.currentLevel], Int32(25)))
            this.currentMusic.toggleSound()

            JulGame.UI.update_text(this.main.scene.uiElements[2], string(this.starCount), this.main)
        end
    elseif s == :update
        function(deltaTime)
        end
    elseif s == :setParent 
        function(parent)
            this.parent = parent
        end
    elseif s == :onShutDown
        function ()
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
end
