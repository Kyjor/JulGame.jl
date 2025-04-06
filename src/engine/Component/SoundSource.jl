module SoundSourceModule
    using ..JulGame
    import ..Component
    
    export SoundSource
    struct SoundSource
        channel::Int
        isMusic::Bool
        path::String
        playOnStart::Bool
        volume::Int
    end

    export InternalSoundSource
    mutable struct InternalSoundSource
        channel::Int
        isMusic::Bool
        isPlaying::Bool
        parent::Any
        path::String
        playOnStart::Bool
        sound::Union{Ptr{Nothing}, Ptr{SDL2.LibSDL2._Mix_Music}, Ptr{SDL2.LibSDL2.Mix_Chunk}}
        volume::Int

        # Music
        function InternalSoundSource(parent::Any, path::String, channel::Int = -1, volume::Int = -1, isMusic::Bool = false, playOnStart::Bool = false)
            this = new()

            SDL2.SDL_ClearError()
            fullPath = joinpath(BasePath, "assets", "sounds", path)
            if length(path) < 1
                sound = C_NULL    
            else
                sound = load_sound_sdl(path, isMusic)
            end
            error = unsafe_string(SDL2.SDL_GetError())

            if (sound == C_NULL || !isempty(error)) && length(path) > 0
                println(fullPath)
                error("Error loading file at $path. SDL Error: $(error)")
                SDL2.SDL_ClearError()
            end
            
            # Convert channel and volume to Int32
            isMusic ? SDL2.Mix_VolumeMusic(Math.TypeConversions.safe_int32_convert(clamp(volume, 0, 128))) : SDL2.Mix_Volume(channel, Math.TypeConversions.safe_int32_convert(clamp(volume, 0, 128)))

            this.channel = channel
            this.isMusic = isMusic
            this.parent = parent
            this.path = path
            this.sound = sound
            this.volume = volume
            this.isPlaying = false
            this.playOnStart = playOnStart

            return this
        end
    end

    function Component.toggle_sound(this::InternalSoundSource, loops = 0)
        if this.isMusic
            if SDL2.Mix_PlayingMusic() == 0
                SDL2.Mix_PlayMusic( this.sound, Math.TypeConversions.safe_int32_convert(-1) )
            else
                if SDL2.Mix_PausedMusic() == 1 
                    SDL2.Mix_ResumeMusic()
                else
                    SDL2.Mix_PauseMusic()
                end
            end
        else
            SDL2.Mix_PlayChannel( Math.TypeConversions.safe_int32_convert(this.channel), this.sound, Math.TypeConversions.safe_int32_convert(loops) )
        end
    end
    
    function Component.stop_music(this::InternalSoundSource)
        SDL2.Mix_HaltMusic()
    end
    
    function Component.load_sound(this::InternalSoundSource, soundPath::String, isMusic::Bool)
        this.isMusic = isMusic
        SDL2.SDL_ClearError()
        this.sound = load_sound_sdl(soundPath, isMusic)
        error = unsafe_string(SDL2.SDL_GetError())
        if !isempty(error)
            println(string("Couldn't open sound! SDL Error: ", error))
            SDL2.SDL_ClearError()
            this.sound = C_NULL
            return
        end
        this.path = soundPath
    end

    function load_sound_sdl(soundPath::String, isMusic::Bool)
        if haskey(JulGame.AUDIO_CACHE, get_comma_separated_path(soundPath))
            raw_data = JulGame.AUDIO_CACHE[get_comma_separated_path(soundPath)]
            rw = SDL2.SDL_RWFromConstMem(pointer(raw_data), length(raw_data))
            if rw != C_NULL
                @debug("loading sound from cache")
                @debug("comma separated path: ", get_comma_separated_path(soundPath))
                return isMusic ? SDL2.Mix_LoadMUS_RW(rw, 1) : SDL2.Mix_LoadWAV_RW(rw, 1)
            end
        end
        @debug "Loading sound from disk, there are $(length(JulGame.AUDIO_CACHE)) sounds in cache"

        fullPath = joinpath(BasePath, "assets", "sounds", soundPath)
        return isMusic ? SDL2.Mix_LoadMUS(fullPath) : SDL2.Mix_LoadWAV(fullPath)
    end

    function get_comma_separated_path(path::String)
        # Normalize the path to use forward slashes
        normalized_path = replace(path, '\\' => '/')
        
        # Split the path into components
        parts = split(normalized_path, '/')
        
        result = join(parts[1:end], ",")
    
        return result  
    end

    function Component.unload_sound(this::InternalSoundSource)
        if this.isMusic
            SDL2.Mix_FreeMusic(this.sound)
        else
            SDL2.Mix_FreeChunk(this.sound)
        end
        this.sound = C_NULL
    end

    function Component.set_volume(this::InternalSoundSource, volume::Int = 100, channel::Int = -1)
        # Convert volume to Int32 for SDL
        this.volume = clamp(volume, 0, 128)
        this.channel = clamp(channel, -1, 128)
        
        this.isMusic ? SDL2.Mix_VolumeMusic(Math.TypeConversions.safe_int32_convert(this.volume)) : SDL2.Mix_Volume(this.channel, Math.TypeConversions.safe_int32_convert(this.volume))
    end

    function Component.play(this::InternalSoundSource, loops::Int = 0)
        # Convert loops to Int32
        loops = Math.TypeConversions.safe_int32_convert(loops)
        
        if this.isMusic
            SDL2.Mix_PlayMusic(this.sound, -1)
        else
            SDL2.Mix_PlayChannel(this.channel, this.sound, loops)
        end
    end
end
