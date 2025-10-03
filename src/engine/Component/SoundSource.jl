module SoundSourceModule
    using ..Component.JulGame
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
        path::String
        isMusic::Bool
        channel::Int
        isPlaying::Bool
        playOnStart::Bool
        parent::Any
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
        @debug("Toggling sound from $(this.path), isMusic: $(this.isMusic), loops: $(loops)")
        try
            if this.isMusic
                if SDL2.Mix_PlayingMusic() == 0
                    SDL2.Mix_PlayMusic( this.sound, Math.TypeConversions.safe_int32_convert(-1) )
                    this.isPlaying = true
                else
                    if SDL2.Mix_PausedMusic() == 1 
                        SDL2.Mix_ResumeMusic()
                        this.isPlaying = true
                    else
                        SDL2.Mix_PauseMusic()
                        this.isPlaying = false
                    end
                end
            else
                if SDL2.Mix_PlayChannel(Math.TypeConversions.safe_int32_convert(this.channel), this.sound, Math.TypeConversions.safe_int32_convert(loops)) == -1
                    @error "Error playing channel $(unsafe_string(SDL2.SDL_GetError()))"
                    throw(e)
                end
            end
        catch e
            @error "Error in toggle_sound" exception=(e, catch_backtrace())
        end
    end
    
    function Component.stop_music(this::InternalSoundSource)
        @debug("Stopping music from $(this.path)")
        SDL2.Mix_HaltMusic()
    end

    function Component.load_sound(this::InternalSoundSource, soundPath::String, isMusic::Bool)
        @debug("Loading sound from $(soundPath), isMusic: $(isMusic)")
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
        @debug("Loading sound from $(soundPath), isMusic: $(isMusic)")
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
        @debug("Unloading sound from $(this.path), isMusic: $(this.isMusic)")
        if this.isMusic
            SDL2.Mix_FreeMusic(this.sound)
        else
            SDL2.Mix_FreeChunk(this.sound)
        end
        this.sound = C_NULL
    end

    function Component.set_volume(this::InternalSoundSource, volume::Int = 128, channel::Int = -1)
        @debug("Setting volume for $(this.path), isMusic: $(this.isMusic), volume: $(volume), channel: $(channel)")
        # Convert volume to Int32 for SDL
        this.volume = clamp(volume, 0, 128)
        this.channel = clamp(channel, -1, 128)
        @info "Setting volume for $(this.path), isMusic: $(this.isMusic), volume: $(this.volume), channel: $(this.channel)"
        this.isMusic ? SDL2.Mix_VolumeMusic(Math.TypeConversions.safe_int32_convert(this.volume)) : SDL2.Mix_Volume(this.channel, Math.TypeConversions.safe_int32_convert(this.volume))
    end

    function Component.play(this::InternalSoundSource, loops::Int = 0)
        # Convert loops to Int32
        loops = Math.TypeConversions.safe_int32_convert(loops)
        
        @debug("Playing sound from $(this.path), isMusic: $(this.isMusic), channel: $(this.channel), loops: $(loops)")
        if this.isMusic
            SDL2.Mix_PlayMusic(this.sound, -1)
        else
            SDL2.Mix_PlayChannel(this.channel, this.sound, loops)
        end
    end

    function set_master_volume(volume::Int)
        # Convert volume to Int32 and clamp between 0 and 128
        @info("Setting master volume to $(volume)")
        volume = Math.TypeConversions.safe_int32_convert(clamp(volume, 0, 128))
        SDL2.Mix_MasterVolume(volume)
    end

    function Component.duplicate(this::InternalSoundSource, parent::Any)
        @debug("Duplicating sound from $(this.path), isMusic: $(this.isMusic), channel: $(this.channel), volume: $(this.volume), playOnStart: $(this.playOnStart)")
        newSoundSource = InternalSoundSource(parent, this.path, this.channel, this.volume, this.isMusic, this.playOnStart)
        newSoundSource.isPlaying = this.isPlaying
        return newSoundSource
    end
end
