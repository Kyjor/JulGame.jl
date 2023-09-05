module SoundSourceModule
    using ..JulGame
    
    export SoundSource
    mutable struct SoundSource
        basePath
        channel
        isMusic
        parent
        path
        sound
        volume

        # Music
        function SoundSource(basePath, path, volume::Integer)
            this = new()

            this.basePath = basePath
            this.channel = C_NULL
            this.isMusic = true
            this.parent = C_NULL
            this.path = path
            this.sound = SDL2.Mix_LoadMUS(joinpath(basePath, "assets", "sounds", path))
            this.volume = volume

            fullPath = joinpath(basePath, "assets", "sounds", path)
            if (this.sound == C_NULL)
                println(fullPath)

                error("error loading file at $(path) SDL Error: $(unsafe_string(SDL2.SDL_GetError()))")
            end

            SDL2.Mix_VolumeMusic(Int32(volume))

            return this
        end

        # Sound effect
        function SoundSource(basePath, path, channel::Integer, volume::Integer)
            this = new()

            this.isMusic = false
            this.basePath = basePath
            this.parent = C_NULL
            this.path = path
            this.sound = SDL2.Mix_LoadWAV(joinpath(basePath, "assets", "sounds", path))
            this.volume = volume

            fullPath = joinpath(basePath, "assets", "sounds", path)
            if (this.sound == C_NULL)
                println(fullPath)
                error("$(path). SDL Error: $(unsafe_string(SDL2.SDL_GetError()))")
            end

            SDL2.Mix_Volume(Int32(channel), Int32(volume))
            this.channel = channel

            return this
        end

        # Sound creation for editor
        function SoundSource(basePath, path, channel, volume, isMusic)
            this = new()
            
            this.basePath = basePath
            this.channel = channel
            this.isMusic = isMusic
            this.parent = C_NULL
            this.path = path
            this.volume = volume
            
            return this
        end

        # Sound creation for editor
        function SoundSource(basePath)
            this = new()
            
            this.basePath = basePath
            this.channel = -1
            this.isMusic = false
            this.parent = C_NULL
            this.path = ""
            this.volume = 100
            
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
        elseif s == :loadSound
            function(soundPath, isMusic)
                this.isMusic = isMusic
                this.sound =  this.isMusic ? SDL2.Mix_LoadMUS(joinpath(this.basePath, "assets", "sounds", soundPath)) : SDL2.Mix_LoadWAV(joinpath(this.basePath, "assets", "sounds", soundPath))
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
            function(parent)
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