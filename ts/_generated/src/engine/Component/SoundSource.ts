export {}

    // using ..Component.JulGame
    // import ..Component
    
    
    class SoundSource {
        channel: number
        isMusic: boolean
        path: string
        playOnStart: boolean
        volume: number
    }

    
    class InternalSoundSource {
        path: string
        isMusic: boolean
        channel: number
        isPlaying: boolean
        playOnStart: boolean
        parent: any
        sound: null | _Mix_Music} | Mix_Chunk}
        volume: number

        // Music
        constructor(parent: any,  path: string,  channel: number = -1,  volume: number = -1,  isMusic: boolean = false,  playOnStart: boolean = false) {
            

            (globalThis as any).JulGameSdl.glue_SDL_ClearError()
            let fullPath = joinpath(BasePath, "assets", "sounds", path)
            if (path.length < 1) {
                let sound = null    
            else
                sound = load_sound_sdl(path, isMusic)
            }
            let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())

            if ((sound == null || !isempty(error)) && path.length > 0) {
                console.log(fullPath)
                error("Error loading file at $path. SDL Error: $(error)")
                (globalThis as any).JulGameSdl.glue_SDL_ClearError()
            }
            
            // Convert channel and volume to Int32
            isMusic ? SDL2.Mix_VolumeMusic(Math.TypeConversions.safe_int32_convert(clamp(volume, 0, 128))) : SDL2.Mix_Volume(channel, Math.TypeConversions.safe_int32_convert(clamp(volume, 0, 128)))

            this.channel = channel
            this.isMusic = isMusic
            this.parent = parent
            this.path = path
            this.sound = sound
            this.volume = volume
            this.isPlaying = false
            this.playOnStart = playOnStart

        }
    }

    function Component_toggle_sound(this: InternalSoundSource | null,  loops = 0) {
        if (this === null) {
            console.warn("toggle_sound: SoundSource is null")
            return
        }
        console.debug("toggle_sound: Toggling sound from $(this.path), isMusic: $(this.isMusic), loops: $(loops)")
        try {
            if (this.isMusic) {
                if (SDL2.Mix_PlayingMusic() == 0) {
                    SDL2.Mix_PlayMusic( this.sound, -1 )
                    this.isPlaying = true
                else
                    if (SDL2.Mix_PausedMusic() == 1) {
                        SDL2.Mix_ResumeMusic()
                        this.isPlaying = true
                    else
                        SDL2.Mix_PauseMusic()
                        this.isPlaying = false
                    }
                }
            else
                if (SDL2.Mix_PlayChannel(this.channel, this.sound, loops) == -1) {
                    console.error("toggle_sound: Error playing channel $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
                    throw(e)
                }
            }
        } catch (e) {
            console.error("toggle_sound: Error in toggle_sound") exception=(e, catch_backtrace())
        }
    }
    
    function Component_stop_music(this: InternalSoundSource) {
        console.debug("stop_music: Stopping music from $(this.path)")
        SDL2.Mix_HaltMusic()
    }

    function Component_load_sound(this: InternalSoundSource,  soundPath: string,  isMusic: boolean) {
        console.debug("load_sound: Loading sound from $(soundPath), isMusic: $(isMusic)")
        this.isMusic = isMusic
        (globalThis as any).JulGameSdl.glue_SDL_ClearError()
        this.sound = load_sound_sdl(soundPath, isMusic)
        error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
        if (!isempty(error)) {
            console.log(string("Couldn't open sound! SDL Error: ", error))
            (globalThis as any).JulGameSdl.glue_SDL_ClearError()
            this.sound = null
            return
        }
        this.path = soundPath
    }

    function load_sound_sdl(soundPath: string,  isMusic: boolean) {
        console.debug("load_sound_sdl: Loading sound from $(soundPath), isMusic: $(isMusic)")
        if (haskey((globalThis as any).JulGame.AUDIO_CACHE, get_comma_separated_path(soundPath))) {
            let raw_data = (globalThis as any).JulGame.AUDIO_CACHE[get_comma_separated_path(soundPath)]
            let rw = (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer(raw_data), raw_data.length)
            if (rw != null) {
                console.debug("loading sound from cache")
                console.debug("comma separated path: ", get_comma_separated_path(soundPath))
                return isMusic ? SDL2.Mix_LoadMUS_RW(rw, 1) : SDL2.Mix_LoadWAV_RW(rw, 1)
            }
        }
        console.debug("load_sound_sdl: Loading sound from disk, there are $((globalThis as any).JulGame.AUDIO_CACHE.length) sounds in cache")

        fullPath = joinpath(BasePath, "assets", "sounds", soundPath)
        return isMusic ? SDL2.Mix_LoadMUS(fullPath) : SDL2.Mix_LoadWAV(fullPath)
    }

    function get_comma_separated_path(path: string) {
        // Normalize the path to use forward slashes
        let normalized_path = replace(path, '\\' => '/')
        
        // Split the path into components
        let parts = split(normalized_path, '/')
        
        let result = join(parts[1:}], ",")
    
        return result  
    }

    function Component_unload_sound(this: InternalSoundSource) {
        console.debug("unload_sound: Unloading sound from $(this.path), isMusic: $(this.isMusic)")
        if (this.isMusic) {
            SDL2.Mix_FreeMusic(this.sound)
        else
            SDL2.Mix_FreeChunk(this.sound)
        }
        this.sound = null
    }

    function Component_set_volume(this: InternalSoundSource,  volume: number = 128,  channel: number = -1) {
        console.debug("set_volume: Setting volume for $(this.path), isMusic: $(this.isMusic), volume: $(volume), channel: $(channel)")
        // Convert volume to Int32 for SDL
        this.volume = clamp(volume, 0, 128)
        this.channel = clamp(channel, -1, 128)
        console.debug("set_volume: Setting volume for $(this.path), isMusic: $(this.isMusic), volume: $(this.volume), channel: $(this.channel)")
        this.isMusic ? SDL2.Mix_VolumeMusic(this.volume) : SDL2.Mix_Volume(this.channel, this.volume)
    }

    function Component_play(this: InternalSoundSource,  loops: number = 0) {
        // Convert loops to Int32
        loops = loops
        
        console.debug("play: Playing sound from $(this.path), isMusic: $(this.isMusic), channel: $(this.channel), loops: $(loops)")
        if (this.isMusic) {
            SDL2.Mix_PlayMusic(this.sound, -1)
        else
            SDL2.Mix_PlayChannel(this.channel, this.sound, loops)
        }
    }

    function set_master_volume(volume: number) {
        // Convert volume to Int32 and clamp between 0 and 128
        console.debug("set_master_volume: Setting master volume to $(volume)")
        volume = Math.TypeConversions.safe_int32_convert(clamp(volume, 0, 128))
        SDL2.Mix_MasterVolume(volume)
    }

    function Component_duplicate(this: InternalSoundSource,  parent: any) {
        console.debug("duplicate: Duplicating sound from $(this.path), isMusic: $(this.isMusic), channel: $(this.channel), volume: $(this.volume), playOnStart: $(this.playOnStart)")
        let newSoundSource = InternalSoundSource(parent, this.path, this.channel, this.volume, this.isMusic, this.playOnStart)
        newSoundSource.isPlaying = this.isPlaying
        return newSoundSource
    }
