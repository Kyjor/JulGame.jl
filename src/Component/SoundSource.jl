module SoundSourceModule
    using ..JulGame
    
    export SoundSource
    mutable struct SoundSource
        basePath::String
        channel::Integer
        isMusic::Bool
        parent::Any
        path::String
        sound
        volume::Integer

        # Music
        function CreateSoundSource(basePath::String, path::String, channel::Integer, volume::Integer, isMusic::Bool)
            this = new()

            SDL2.SDL_ClearError()
            fullPath = joinpath(basePath, "assets", "sounds", path)
            sound = isMusic ? SDL2.Mix_LoadMUS(fullPath) : SDL2.Mix_LoadWAV(fullPath)
            error = unsafe_string(SDL2.SDL_GetError())

            if sound == C_NULL || !isempty(error)
                println(fullPath)
                error("Error loading file at $path. SDL Error: $(error)")
                SDL2.SDL_ClearError()
            end
            
            isMusic ? SDL2.Mix_VolumeMusic(Int32(volume)) : SDL2.Mix_Volume(Int32(channel), Int32(volume))

            this.basePath = basePath
            this.channel = channel
            this.isMusic = isMusic
            this.parent = C_NULL
            this.path = path
            this.sound = sound
            this.volume = volume

            return this
        end
        
        # Constructor for editor
        function SoundSource(basePath::String)
            return CreateSoundSource(basePath, "", -1, 100, false)
        end

        # Constructor for music
        function SoundSource(basePath::String, path::String, volume::Integer)
            return CreateSoundSource(basePath, path, -1, volume, true)
        end
        
        # Constructor for sound effect
        function SoundSource(basePath::String, path::String, channel::Integer, volume::Integer)
            return CreateSoundSource(basePath, path, channel, volume, false)
        end
        
        # Constructor for editor with specified properties
        function SoundSource(basePath::String, channel::Integer, volume::Integer, isMusic::Bool)
            return CreateSoundSource(basePath, "", channel, volume, isMusic)
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
                this.sound =  this.isMusic ? SDL2.Mix_LoadMUS(joinpath(this.basePath, "assets", "sounds", soundPath)) : SDL2.Mix_LoadWAV(joinpath(this.basePath, "assets", "sounds", soundPath))
                error = unsafe_string(SDL2.SDL_GetError())
                if !isempty(error)
                    println(string("Couldn't open sound! SDL Error: ", error))
                    SDL2.SDL2.SDL_ClearError()
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