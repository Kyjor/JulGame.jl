# SDL_mixer calls. InternalSoundSource.sound is a Union of three Ptr types
# (inline union + type tag), so the Mix handle is still passed as a plain
# pointer. isPlaying is a Bool at a known offset — write it here.

function static_toggle_sound(
    sound_source::Ptr{Cvoid},
    sound::Ptr{Cvoid},
    loops::Int32,
)
    if sound_source == C_NULL
        return
    end

    source = Ptr{SoundSourceLayout}(sound_source)
    mixer_channel::Int32 = unsafe_trunc(Int32, source.channel)
    if source.isMusic
        if llvm_Mix_PlayingMusic() == Int32(0)
            llvm_Mix_PlayMusic(sound, Int32(-1))
            source.isPlaying = true
            return
        end
        if llvm_Mix_PausedMusic() == Int32(1)
            llvm_Mix_ResumeMusic()
            source.isPlaying = true
            return
        end
        llvm_Mix_PauseMusic()
        source.isPlaying = false
        return
    end

    if llvm_Mix_PlayChannel(mixer_channel, sound, loops) == Int32(-1)
        error_message::Ptr{UInt8} = llvm_SDL_GetError()
        printf(c"toggle_sound: Error playing channel: %s\n", error_message)
    end
    return
end

function static_stop_music()::Int32
    return llvm_Mix_HaltMusic()
end

# Caller sets this.sound = C_NULL afterward (union field write stays in Julia).
function static_unload_sound(is_music::Int32, sound::Ptr{Cvoid})
    if is_music != Int32(0)
        llvm_Mix_FreeMusic(sound)
    else
        llvm_Mix_FreeChunk(sound)
    end
    return
end

# volume/channel arrive already clamped by the Julia caller.
function static_set_volume(is_music::Int32, channel::Int32, volume::Int32)::Int32
    if is_music != Int32(0)
        return llvm_Mix_VolumeMusic(volume)
    end
    return llvm_Mix_Volume(channel, volume)
end

function static_play_sound(
    is_music::Int32,
    sound::Ptr{Cvoid},
    channel::Int32,
    loops::Int32,
)::Int32
    if is_music != Int32(0)
        return llvm_Mix_PlayMusic(sound, Int32(-1))
    end
    return llvm_Mix_PlayChannel(channel, sound, loops)
end

# volume arrives already clamped by the Julia caller.
function static_set_master_volume(volume::Int32)::Int32
    return llvm_Mix_MasterVolume(volume)
end

# Disk load only — no AUDIO_CACHE.
# Builds "<base>/assets/sounds/<sound>" with malloc (no joinpath).
function static_load_sound(
    is_music::Int32,
    base_path::Ptr{UInt8},
    sound_path::Ptr{UInt8},
)::Ptr{Cvoid}
    full_path::Ptr{UInt8} = malloc_joined_path(base_path, sound_path, ASSETS_SOUNDS_INFIX)
    if full_path == C_NULL
        return C_NULL
    end
    loaded::Ptr{Cvoid} = C_NULL
    if is_music != Int32(0)
        loaded = llvm_Mix_LoadMUS(full_path)
    else
        loaded = llvm_Mix_LoadWAV(full_path)
    end
    wasm_free(Ptr{Cvoid}(full_path))
    return loaded
end

# Component.load_sound: set isMusic, clear error, disk-load, report SDL error.
# Caller writes this.sound (union) and this.path (Julia String).
function static_load_sound_source(
    sound_source::Ptr{Cvoid},
    is_music::Int32,
    base_path::Ptr{UInt8},
    sound_path::Ptr{UInt8},
)::Ptr{Cvoid}
    if sound_source != C_NULL
        source = Ptr{SoundSourceLayout}(sound_source)
        source.isMusic = is_music != Int32(0)
    end
    llvm_SDL_ClearError()
    loaded::Ptr{Cvoid} = static_load_sound(is_music, base_path, sound_path)
    error_message::Ptr{UInt8} = llvm_SDL_GetError()
    if error_message != C_NULL
        if unsafe_load(error_message) != 0x00
            printf(c"Couldn't open sound! SDL Error: %s\n", error_message)
            llvm_SDL_ClearError()
            return C_NULL
        end
    end
    return loaded
end
