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
            this.textBox = MAIN.scene.uiElements[1]
        end
    elseif s == :update
        function(deltaTime)
            try
                if this.fade 
                    this.textBox.alpha -= 1
                    JulGame.UI.update_text(this.textBox, this.textBox.text)
                    if this.textBox.alpha <= 25
                        this.fade = false
                    end
                else
                    this.textBox.alpha += 1
                    JulGame.UI.update_text(this.textBox, this.textBox.text)
                    if this.textBox.alpha >= 250
                        this.fade = true
                    end
                end

                # sound = JulGame.create_sound_source(this.parent, JulGame.SoundSourceModule.SoundSource(Int32(-1), false, "confirm-ui.wav", Int32(50)))
                # JulGame.Component.toggle_sound(sound)

                JulGame.MainLoop.change_scene("level_1.json")
            catch e
                println(e)
				Base.show_backtrace(stdout, catch_backtrace())
				rethrow(e)
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
			Base.show_backtrace(stdout, catch_backtrace())
			rethrow(e)
        end
    end
end