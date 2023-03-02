using SimpleDirectMediaLayer.LibSDL2

mutable struct SoundSource
    sound

    function SoundSource(path)
        this = new()

        test = Mix_LoadMUS(path)

        return this
    end
end

function Base.getproperty(this::SoundSource, s::Symbol)
    if s == :playSoundOnce
        function()
            if Mix_PlayingMusic() == 0
                println("play music")
                Mix_PlayMusic( this.sound, 1 );
            else
                if Mix_PausedMusic() == 1 
                    println("resume music")
                    Mix_ResumeMusic();
                else
                    println("pause music")
                    Mix_PauseMusic();
                end
            end
        end
    elseif s == :playSoundLoop
        function()
        end
    elseif s == :pauseSound
        function()
        end
    elseif s == :stopSound
        function()
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end