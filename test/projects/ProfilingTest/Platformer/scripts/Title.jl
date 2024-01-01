using JulGame 

mutable struct Title
    fade
    parent
    textBox

    function Title()
        this = new()

        this.fade = true
        this.parent = C_NULL
        this.textBox = C_NULL

        return this
    end
end

function Base.getproperty(this::Title, s::Symbol)
    if s == :initialize
        function()
            this.textBox = MAIN.scene.textBoxes[1]
        end
    elseif s == :update
        function(deltaTime)

            if this.fade 
                this.textBox.alpha -= 1
                this.textBox.updateText(this.textBox.text)
                if this.textBox.alpha <= 25
                    this.fade = false
                end
            else
                this.textBox.alpha += 1
                this.textBox.updateText(this.textBox.text)
                if this.textBox.alpha >= 250
                    this.fade = true
                end
            end

            sound = this.parent.createSoundSource(JulGame.SoundSourceModule.SoundSource(-1, false, "confirm-ui.wav", 50))
            sound.toggleSound()
            ChangeScene("level_1.json")

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
        end
    end
end