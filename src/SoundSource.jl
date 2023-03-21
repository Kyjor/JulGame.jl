include("Constants.jl")

using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer 

const ENGINE_ASSETS = @path joinpath(@__DIR__, "kryogen_assets")

mutable struct SoundSource
    isMusic
    sound

    function SoundSource(path, isMusic, volume)
        this = new()

        this.sound = isMusic ? SDL2.Mix_LoadMUS(path) : SDL2.Mix_LoadWAV(path)

        if (this.sound == C_NULL)
            error("$(path) not found. SDL Error: $(unsafe_string(SDL2.SDL_GetError()))")
        end

        this.isMusic = isMusic
        SDL2.Mix_Volume(Int32(0), Int32(volume))

        return this
    end
end

function Base.getproperty(this::SoundSource, s::Symbol)
    if s == :toggleSound
        function()
            if this.isMusic
                if SDL2.Mix_PlayingMusic() == 0
                    println("play music")
                    SDL2.Mix_PlayMusic( this.sound, Int32(-1) )
                else
                    if SDL2.Mix_PausedMusic() == 1 
                        println("resume music")
                        SDL2.Mix_ResumeMusic()
                    else
                        println("pause music")
                        SDL2.Mix_PauseMusic()
                    end
                end
            else
                SDL2.Mix_PlayChannel( Int32(0), this.sound, Int32(0) )
            end
        end
    elseif s == :stopMusic
        function()
            SDL2.Mix_HaltMusic()
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end