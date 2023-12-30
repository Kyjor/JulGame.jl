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

            if MAIN.input.getButtonPressed("RETURN")
                JulGame.SoundSourceModule.SoundSource("confirm-ui.wav", -1, 50).toggleSound()
                ChangeScene("level_1.json")
            end

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