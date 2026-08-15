export {}
import { clamp, haskey, joinpath, mixVolume, pointer, unsafe_string } from "../../../../src/engine/core/juliaHelpers";


    // using ..Component.JulGame
    // import ..Component
    // include(joinpath(@__DIR__, "SoundSource", "constants.jl"))
    
    
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
        sound: null | any | any
        volume: number

        // Music
        constructor(parent: any, path: string, channel: number = -1, volume: number = -1, isMusic: boolean = false, playOnStart: boolean = false) {
            

            let sound = null

            // Convert channel and volume to Int32
            isMusic ? (globalThis as any).JulGameSdl.glue_Mix_VolumeMusic(mixVolume(volume)) : (globalThis as any).JulGameSdl.glue_Mix_Volume(channel, mixVolume(volume))

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

    function Component_toggle_sound(self: InternalSoundSource | null, loops = 0) {
        if (self === null) {
            console.warn("toggle_sound: SoundSource is null")
            return
        }
        console.debug(`toggle_sound: Toggling sound from ${self.path}, isMusic: ${self.isMusic}, loops: ${loops}`)
        try {
            if (self.isMusic) {
                if ((globalThis as any).JulGameSdl.glue_Mix_PlayingMusic() == 0) {
                    (globalThis as any).JulGameSdl.glue_Mix_VolumeMusic(mixVolume(self.volume));
                    (globalThis as any).JulGameSdl.glue_Mix_PlayMusic( self.sound, -1 )
                    self.isPlaying = true
                } else {
                    if ((globalThis as any).JulGameSdl.glue_Mix_PausedMusic() == 1) {
                        (globalThis as any).JulGameSdl.glue_Mix_ResumeMusic()
                        self.isPlaying = true
                    } else {
                        (globalThis as any).JulGameSdl.glue_Mix_PauseMusic()
                        self.isPlaying = false
                    }
                }
            } else {
                (globalThis as any).JulGameSdl.glue_Mix_Volume(self.channel, mixVolume(self.volume));
                if ((globalThis as any).JulGameSdl.glue_Mix_PlayChannel(self.channel, self.sound, loops) == -1) {
                    console.error(`toggle_sound: Error playing channel ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)

                }
            }
        } catch (e) {
            console.error("toggle_sound: Error in toggle_sound")
        }
    }
    
    function Component_stop_music(self: InternalSoundSource) {
        console.debug(`stop_music: Stopping music from ${self.path}`);
        (globalThis as any).JulGameSdl.glue_Mix_HaltMusic()
    }

    function Component_load_sound(self: InternalSoundSource, soundPath: string, isMusic: boolean) {
        console.debug(`load_sound: Loading sound from ${soundPath}, isMusic: ${isMusic}`)
        self.isMusic = isMusic;
        (globalThis as any).JulGameSdl.glue_SDL_ClearError()
        self.sound = load_sound_sdl(soundPath, isMusic)
        let error = unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())
        if (error.length > 0) {
            console.log(["Couldn't open sound! SDL Error: ", error].join(""));
            (globalThis as any).JulGameSdl.glue_SDL_ClearError()
            self.sound = null
            return
        }
        self.path = soundPath
    }

    function load_sound_sdl(soundPath: string, isMusic: boolean) {
        if (!(globalThis as any).__julgameAudioOpen) {
            return null
        }
        console.debug(`load_sound_sdl: Loading sound from ${soundPath}, isMusic: ${isMusic}`)
        if (haskey((globalThis as any).JulGame.AUDIO_CACHE, get_comma_separated_path(soundPath))) {
            let raw_data = (globalThis as any).JulGame.AUDIO_CACHE[get_comma_separated_path(soundPath)]
            let rw = (globalThis as any).JulGameSdl.glue_SDL_RWFromConstMem(pointer(raw_data), raw_data.length)
            if (rw != null) {
                console.debug("loading sound from cache")
                console.debug("comma separated path: ", get_comma_separated_path(soundPath))
                return isMusic ? (globalThis as any).JulGameSdl.glue_Mix_LoadMUS_RW(rw, 1) : (globalThis as any).JulGameSdl.glue_Mix_LoadWAV_RW(rw, 1)
            }
        }
        console.debug(`load_sound_sdl: Loading sound from disk, there are ${(globalThis as any).JulGame.AUDIO_CACHE.length} sounds in cache`)

        let fullPath = joinpath((globalThis as any).JulGame.BasePath, "assets", "sounds", soundPath)
        return isMusic ? (globalThis as any).JulGameSdl.glue_Mix_LoadMUS(fullPath) : (globalThis as any).JulGameSdl.glue_Mix_LoadWAV(fullPath)
    }

    function get_comma_separated_path(path: string) {
        // Normalize the path to use forward slashes
        let normalized_path = path.replace(/\\/g, '/')
        
        // Split the path into components
        let parts = normalized_path.split('/')
        
        let result = parts.join(",")
    
        return result  
    }

    function Component_unload_sound(self: InternalSoundSource) {
        console.debug(`unload_sound: Unloading sound from ${self.path}, isMusic: ${self.isMusic}`)
        if (self.isMusic) {
            (globalThis as any).JulGameSdl.glue_Mix_FreeMusic(self.sound)
        } else {
            (globalThis as any).JulGameSdl.glue_Mix_FreeChunk(self.sound)
        }
        self.sound = null
    }

    function Component_set_volume(self: InternalSoundSource, volume: number = 128, channel: number = -1) {
        console.debug(`set_volume: Setting volume for ${self.path}, isMusic: ${self.isMusic}, volume: ${volume}, channel: ${channel}`)
        // Convert volume to Int32 for SDL
        self.volume = mixVolume(volume)
        self.channel = clamp(channel, -1, 128)
        console.debug(`set_volume: Setting volume for ${self.path}, isMusic: ${self.isMusic}, volume: ${self.volume}, channel: ${self.channel}`)
        self.isMusic ? (globalThis as any).JulGameSdl.glue_Mix_VolumeMusic(mixVolume(self.volume)) : (globalThis as any).JulGameSdl.glue_Mix_Volume(self.channel, mixVolume(self.volume))
    }

    function Component_play(self: InternalSoundSource, loops: number = 0) {
        // Convert loops to Int32
        loops = loops
        
        console.debug(`play: Playing sound from ${self.path}, isMusic: ${self.isMusic}, channel: ${self.channel}, loops: ${loops}`)
        if (self.isMusic) {
            (globalThis as any).JulGameSdl.glue_Mix_VolumeMusic(mixVolume(self.volume));
            (globalThis as any).JulGameSdl.glue_Mix_PlayMusic(self.sound, -1)
        } else {
            (globalThis as any).JulGameSdl.glue_Mix_Volume(self.channel, mixVolume(self.volume));
            (globalThis as any).JulGameSdl.glue_Mix_PlayChannel(self.channel, self.sound, loops)
        }
    }

    function set_master_volume(volume: number) {
        // Convert volume to Int32 and clamp between 0 and 128
        console.debug(`set_master_volume: Setting master volume to ${volume}`)
        volume = mixVolume(volume);
        (globalThis as any).JulGameSdl.glue_Mix_MasterVolume(volume)
    }

    function Component_duplicate(self: InternalSoundSource, parent: any) {
        console.debug(`duplicate: Duplicating sound from ${self.path}, isMusic: ${self.isMusic}, channel: ${self.channel}, volume: ${self.volume}, playOnStart: ${self.playOnStart}`)
        let newSoundSource = new InternalSoundSource(parent, self.path, self.channel, self.volume, self.isMusic, self.playOnStart)
        newSoundSource.isPlaying = self.isPlaying
        return newSoundSource
    }
export { Component_duplicate, Component_load_sound, Component_play, Component_set_volume, Component_stop_music, Component_toggle_sound, Component_unload_sound, InternalSoundSource, SoundSource, get_comma_separated_path, load_sound_sdl, set_master_volume }
