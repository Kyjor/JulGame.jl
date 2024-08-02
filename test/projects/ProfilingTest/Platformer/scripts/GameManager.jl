mutable struct GameManager
    currentLevel::Int32
    currentMusic
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
        function()
            MAIN.scene.camera.offset = JulGame.Math.Vector2f(0, -2.75)
            MAIN.cameraBackgroundColor = (30, 111, 80)
            MAIN.optimizeSpriteRendering = true

            JulGame.add_shape(this.parent, JulGame.ShapeModule.Shape(Math.Vector3(0,0,0), Math.Vector2f(10,5),  true, false, Math.Vector2f(0,0), Math.Vector2f(1.2175,0.5)))
            coinUI = JulGame.SceneModule.get_entity_by_name(MAIN.scene, "CoinUI")
            livesUI = JulGame.SceneModule.get_entity_by_name(MAIN.scene, "LivesUI")

            coinUI.persistentBetweenScenes = true
            coinUI.sprite.isWorldEntity = false
            coinUI.sprite.position = JulGame.Math.Vector2f(-.1, 1)

            livesUI.persistentBetweenScenes = true
            livesUI.sprite.isWorldEntity = false
            livesUI.sprite.position = JulGame.Math.Vector2f(-.1, .25)
            
            this.parent.persistentBetweenScenes = true
            if this.currentLevel > 1
                JulGame.Component.unload_sound(this.currentMusic)
            end

            this.currentMusic = JulGame.create_sound_source(this.parent, JulGame.SoundSourceModule.SoundSource(Int32(-1), true, this.soundBank[this.currentLevel], Int32(25)))
            JulGame.Component.toggle_sound(this.currentMusic)
            
            JulGame.UI.update_text(MAIN.scene.uiElements[2], string(this.starCount))
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
