module SoundSourceModule
    using ..JulGame
    
    export SoundSource
    mutable struct SoundSource
        channel::Integer
        isMusic::Bool
        parent::Any
        path::String
        sound::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2._Mix_Music}, Ptr{SDL2.LibSDL2.Mix_Chunk}}
        volume::Integer

        # Music
        function CreateSoundSource(path::String, channel::Integer, volume::Integer, isMusic::Bool)
            this = new()

            SDL2.SDL_ClearError()
            fullPath = joinpath(BasePath, "assets", "sounds", path)
            sound = isMusic ? SDL2.Mix_LoadMUS(fullPath) : SDL2.Mix_LoadWAV(fullPath)
            error = unsafe_string(SDL2.SDL_GetError())

            if sound == C_NULL || !isempty(error)
                println(fullPath)
                error("Error loading file at $path. SDL Error: $(error)")
                SDL2.SDL_ClearError()
            end
            
            isMusic ? SDL2.Mix_VolumeMusic(Integer(volume)) : SDL2.Mix_Volume(Integer(channel), Int32(volume))

            this.channel = channel
            this.isMusic = isMusic
            this.parent = C_NULL
            this.path = path
            this.sound = sound
            this.volume = volume

            return this
        end
        
        # Constructor for editor
        function SoundSource()
            this = new()

            this.channel = -1
            this.isMusic = false
            this.parent = C_NULL
            this.path = ""
            this.sound = C_NULL
            this.volume = 100

            return this
        end

        # Constructor for music
        function SoundSource(path::String, volume::Integer)
            return CreateSoundSource(path, -1, volume, true)
        end
        
        # Constructor for sound effect
        function SoundSource(path::String, channel::Integer, volume::Integer)
            return CreateSoundSource(path, channel, volume, false)
        end
        
        # Constructor for editor with specified properties
        function SoundSource(channel::Integer, volume::Integer, isMusic::Bool)
            return CreateSoundSource("", channel, volume, isMusic)
        end
        
        function SoundSource(path::String, channel::Integer, volume::Integer, isMusic::Bool)
            return CreateSoundSource(path, channel, volume, isMusic)
        end
    end
    
    function Base.getproperty(this::SoundSource, s::Symbol)
        if s == :toggleSound
            function(loops = 0)
                if this.isMusic
                    if SDL2.Mix_PlayingMusic() == 0
                        SDL2.Mix_PlayMusic( this.sound, Integer(-1) )
                    else
                        if SDL2.Mix_PausedMusic() == 1 
                            SDL2.Mix_ResumeMusic()
                        else
                            SDL2.Mix_PauseMusic()
                        end
                    end
                else
                    SDL2.Mix_PlayChannel( Integer(this.channel), this.sound, Integer(loops) )
                end
            end
        elseif s == :stopMusic
            function()
                SDL2.Mix_HaltMusic()
            end
        elseif s == :loadSound
            function(soundPath::String, isMusic::Bool)
                this.isMusic = isMusic
                this.sound =  this.isMusic ? SDL2.Mix_LoadMUS(joinpath(BasePath, "assets", "sounds", soundPath)) : SDL2.Mix_LoadWAV(joinpath(BasePath, "assets", "sounds", soundPath))
                error = unsafe_string(SDL2.SDL_GetError())
                if !isempty(error)
                    println(string("Couldn't open sound! SDL Error: ", error))
                    SDL2.SDL_ClearError()
                    this.sound = C_NULL
                    return
                end
                this.path = soundPath
            end
        elseif s == :setParent
            function(parent::Any)
                this.parent = parent
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
            end
        end
    end
end