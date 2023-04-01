include("Constants.jl")

using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer 

mutable struct SoundSource
    channel
    isMusic
    sound

    # Music
    function SoundSource(path, volume::Integer)
        this = new()

        this.isMusic = true
        this.sound = SDL2.Mix_LoadMUS(path)

        if (this.sound == C_NULL)
            error("$(path) not found. SDL Error: $(unsafe_string(SDL2.SDL_GetError()))")
        end

        SDL2.Mix_VolumeMusic(Int32(volume))

        return this
    end

    # Sound effect
    function SoundSource(path, channel::Integer, volume::Integer)
        this = new()

        this.isMusic = false
        this.sound = SDL2.Mix_LoadWAV(path)

        if (this.sound == C_NULL)
            error("$(path) not found. SDL Error: $(unsafe_string(SDL2.SDL_GetError()))")
        end

        SDL2.Mix_Volume(Int32(channel), Int32(volume))
        this.channel = channel

        return this
    end
end

function Base.getproperty(this::SoundSource, s::Symbol)
    if s == :toggleSound
        function(loops = 0)
            if this.isMusic
                if SDL2.Mix_PlayingMusic() == 0
                    SDL2.Mix_PlayMusic( this.sound, Int32(-1) )
                else
                    if SDL2.Mix_PausedMusic() == 1 
                        SDL2.Mix_ResumeMusic()
                    else
                        SDL2.Mix_PauseMusic()
                    end
                end
            else
                SDL2.Mix_PlayChannel( Int32(this.channel), this.sound, Int32(loops) )
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