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
        function CreateSoundSource(basePath, path, channel, volume::Integer, isMusic::Bool)
            this = new()

            fullPath = joinpath(basePath, "assets", "sounds", path)
            sound = isMusic ? SDL2.Mix_LoadMUS(fullPath) : SDL2.Mix_LoadWAV(fullPath)
            
            if sound == C_NULL
                println(fullPath)
                error("Error loading file at $path. SDL Error: $(unsafe_string(SDL2.SDL_GetError()))")
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
        
        # Constructor for music
        function SoundSource(basePath, path, volume::Integer)
            return CreateSoundSource(basePath, path, -1, volume, true)
        end
        
        # Constructor for sound effect
        function SoundSource(basePath, path, channel::Integer, volume::Integer)
            return CreateSoundSource(basePath, path, channel, volume, false)
        end
        
        # Constructor for editor
        function SoundSource(basePath)
            return CreateSoundSource(basePath, "", -1, 100, false)
        end
        
        # Constructor for editor with specified properties
        function SoundSource(basePath, channel, volume, isMusic)
            return CreateSoundSource(basePath, "", channel, volume, isMusic)
        end
    end
    
    function Base.getproperty(this::SoundSource, s::Symbol)
          # Check the call stack
          stack = stacktrace()
        
          # Get information about the caller
          caller_info = stack[2]  # Index 2 corresponds to the caller of my_function
          
          # Extract caller information
          caller_file = caller_info.file
          caller_line = caller_info.line
          
          println("my_function was called from $caller_file at line $caller_line.")
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