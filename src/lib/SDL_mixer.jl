# Julia wrapper for header: /Users/daly/.julia/v0.6/Homebrew/deps/usr/Cellar/sdl2_mixer/2.0.2_3/include/SDL2/SDL_mixer.h
# Automatically generated using Clang.jl wrap_c, version 0.0.0

include("SDL_mixer_h.jl")

function Mix_Linked_Version()
    ccall((:Mix_Linked_Version, libsdl2_mixer), Ptr{SDL_version}, ())
end

function Mix_Init(flags::Cint)
    ccall((:Mix_Init, libsdl2_mixer), Cint, (Cint,), flags)
end

function Mix_Quit()
    ccall((:Mix_Quit, libsdl2_mixer), Cvoid, ())
end

function Mix_OpenAudio(frequency::Cint, format::Uint16, channels::Cint, chunksize::Cint)
    ccall((:Mix_OpenAudio, libsdl2_mixer), Cint, (Cint, Uint16, Cint, Cint), frequency, format, channels, chunksize)
end

function Mix_OpenAudioDevice(frequency::Cint, format::Uint16, channels::Cint, chunksize::Cint, device, allowed_changes::Cint)
    ccall((:Mix_OpenAudioDevice, libsdl2_mixer), Cint, (Cint, Uint16, Cint, Cint, Cstring, Cint), frequency, format, channels, chunksize, device, allowed_changes)
end

function Mix_AllocateChannels(numchans::Cint)
    ccall((:Mix_AllocateChannels, libsdl2_mixer), Cint, (Cint,), numchans)
end

function Mix_QuerySpec(frequency, format, channels)
    ccall((:Mix_QuerySpec, libsdl2_mixer), Cint, (Ptr{Cint}, Ptr{Uint16}, Ptr{Cint}), frequency, format, channels)
end

function Mix_LoadWAV_RW(src, freesrc::Cint)
    ccall((:Mix_LoadWAV_RW, libsdl2_mixer), Ptr{Mix_Chunk}, (Ptr{RWops}, Cint), src, freesrc)
end

function Mix_LoadMUS(file)
    ccall((:Mix_LoadMUS, libsdl2_mixer), Ptr{Mix_Music}, (Cstring,), file)
end

function Mix_LoadMUS_RW(src, freesrc::Cint)
    ccall((:Mix_LoadMUS_RW, libsdl2_mixer), Ptr{Mix_Music}, (Ptr{RWops}, Cint), src, freesrc)
end

function Mix_LoadMUSType_RW(src, _type::Mix_MusicType, freesrc::Cint)
    ccall((:Mix_LoadMUSType_RW, libsdl2_mixer), Ptr{Mix_Music}, (Ptr{RWops}, Mix_MusicType, Cint), src, _type, freesrc)
end

function Mix_QuickLoad_WAV(mem)
    ccall((:Mix_QuickLoad_WAV, libsdl2_mixer), Ptr{Mix_Chunk}, (Ptr{Uint8},), mem)
end

function Mix_QuickLoad_RAW(mem, len::Uint32)
    ccall((:Mix_QuickLoad_RAW, libsdl2_mixer), Ptr{Mix_Chunk}, (Ptr{Uint8}, Uint32), mem, len)
end

function Mix_FreeChunk(chunk)
    ccall((:Mix_FreeChunk, libsdl2_mixer), Cvoid, (Ptr{Mix_Chunk},), chunk)
end

function Mix_FreeMusic(music)
    ccall((:Mix_FreeMusic, libsdl2_mixer), Cvoid, (Ptr{Mix_Music},), music)
end

function Mix_GetNumChunkDecoders()
    ccall((:Mix_GetNumChunkDecoders, libsdl2_mixer), Cint, ())
end

function Mix_GetChunkDecoder(index::Cint)
    ccall((:Mix_GetChunkDecoder, libsdl2_mixer), Cstring, (Cint,), index)
end

function Mix_HasChunkDecoder(name)
    ccall((:Mix_HasChunkDecoder, libsdl2_mixer), bool, (Cstring,), name)
end

function Mix_GetNumMusicDecoders()
    ccall((:Mix_GetNumMusicDecoders, libsdl2_mixer), Cint, ())
end

function Mix_GetMusicDecoder(index::Cint)
    ccall((:Mix_GetMusicDecoder, libsdl2_mixer), Cstring, (Cint,), index)
end

function Mix_HasMusicDecoder(name)
    ccall((:Mix_HasMusicDecoder, libsdl2_mixer), bool, (Cstring,), name)
end

function Mix_GetMusicType(music)
    ccall((:Mix_GetMusicType, libsdl2_mixer), Mix_MusicType, (Ptr{Mix_Music},), music)
end

function Mix_SetPostMix(mix_func, arg)
    ccall((:Mix_SetPostMix, libsdl2_mixer), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), mix_func, arg)
end

function Mix_HookMusic(mix_func, arg)
    ccall((:Mix_HookMusic, libsdl2_mixer), Cvoid, (Ptr{Cvoid}, Ptr{Cvoid}), mix_func, arg)
end

function Mix_HookMusicFinished(music_finished)
    ccall((:Mix_HookMusicFinished, libsdl2_mixer), Cvoid, (Ptr{Cvoid},), music_finished)
end

function Mix_GetMusicHookData()
    ccall((:Mix_GetMusicHookData, libsdl2_mixer), Ptr{Cvoid}, ())
end

function Mix_ChannelFinished(channel_finished)
    ccall((:Mix_ChannelFinished, libsdl2_mixer), Cvoid, (Ptr{Cvoid},), channel_finished)
end

function Mix_RegisterEffect(chan::Cint, f::Mix_EffectFunc_t, d::Mix_EffectDone_t, arg)
    ccall((:Mix_RegisterEffect, libsdl2_mixer), Cint, (Cint, Mix_EffectFunc_t, Mix_EffectDone_t, Ptr{Cvoid}), chan, f, d, arg)
end

function Mix_UnregisterEffect(channel::Cint, f::Mix_EffectFunc_t)
    ccall((:Mix_UnregisterEffect, libsdl2_mixer), Cint, (Cint, Mix_EffectFunc_t), channel, f)
end

function Mix_UnregisterAllEffects(channel::Cint)
    ccall((:Mix_UnregisterAllEffects, libsdl2_mixer), Cint, (Cint,), channel)
end

function Mix_SetPanning(channel::Cint, left::Uint8, right::Uint8)
    ccall((:Mix_SetPanning, libsdl2_mixer), Cint, (Cint, Uint8, Uint8), channel, left, right)
end

function Mix_SetPosition(channel::Cint, angle::Sint16, distance::Uint8)
    ccall((:Mix_SetPosition, libsdl2_mixer), Cint, (Cint, Sint16, Uint8), channel, angle, distance)
end

function Mix_SetDistance(channel::Cint, distance::Uint8)
    ccall((:Mix_SetDistance, libsdl2_mixer), Cint, (Cint, Uint8), channel, distance)
end

function Mix_SetReverseStereo(channel::Cint, flip::Cint)
    ccall((:Mix_SetReverseStereo, libsdl2_mixer), Cint, (Cint, Cint), channel, flip)
end

function Mix_ReserveChannels(num::Cint)
    ccall((:Mix_ReserveChannels, libsdl2_mixer), Cint, (Cint,), num)
end

function Mix_GroupChannel(which::Cint, tag::Cint)
    ccall((:Mix_GroupChannel, libsdl2_mixer), Cint, (Cint, Cint), which, tag)
end

function Mix_GroupChannels(from::Cint, to::Cint, tag::Cint)
    ccall((:Mix_GroupChannels, libsdl2_mixer), Cint, (Cint, Cint, Cint), from, to, tag)
end

function Mix_GroupAvailable(tag::Cint)
    ccall((:Mix_GroupAvailable, libsdl2_mixer), Cint, (Cint,), tag)
end

function Mix_GroupCount(tag::Cint)
    ccall((:Mix_GroupCount, libsdl2_mixer), Cint, (Cint,), tag)
end

function Mix_GroupOldest(tag::Cint)
    ccall((:Mix_GroupOldest, libsdl2_mixer), Cint, (Cint,), tag)
end

function Mix_GroupNewer(tag::Cint)
    ccall((:Mix_GroupNewer, libsdl2_mixer), Cint, (Cint,), tag)
end

function Mix_PlayChannelTimed(channel::Cint, chunk, loops::Cint, ticks::Cint)
    ccall((:Mix_PlayChannelTimed, libsdl2_mixer), Cint, (Cint, Ptr{Mix_Chunk}, Cint, Cint), channel, chunk, loops, ticks)
end

function Mix_PlayMusic(music, loops::Cint)
    ccall((:Mix_PlayMusic, libsdl2_mixer), Cint, (Ptr{Mix_Music}, Cint), music, loops)
end

function Mix_FadeInMusic(music, loops::Cint, ms::Cint)
    ccall((:Mix_FadeInMusic, libsdl2_mixer), Cint, (Ptr{Mix_Music}, Cint, Cint), music, loops, ms)
end

function Mix_FadeInMusicPos(music, loops::Cint, ms::Cint, position::Cdouble)
    ccall((:Mix_FadeInMusicPos, libsdl2_mixer), Cint, (Ptr{Mix_Music}, Cint, Cint, Cdouble), music, loops, ms, position)
end

function Mix_FadeInChannelTimed(channel::Cint, chunk, loops::Cint, ms::Cint, ticks::Cint)
    ccall((:Mix_FadeInChannelTimed, libsdl2_mixer), Cint, (Cint, Ptr{Mix_Chunk}, Cint, Cint, Cint), channel, chunk, loops, ms, ticks)
end

function Mix_Volume(channel::Cint, volume::Cint)
    ccall((:Mix_Volume, libsdl2_mixer), Cint, (Cint, Cint), channel, volume)
end

function Mix_VolumeChunk(chunk, volume::Cint)
    ccall((:Mix_VolumeChunk, libsdl2_mixer), Cint, (Ptr{Mix_Chunk}, Cint), chunk, volume)
end

function Mix_VolumeMusic(volume::Cint)
    ccall((:Mix_VolumeMusic, libsdl2_mixer), Cint, (Cint,), volume)
end

function Mix_HaltChannel(channel::Cint)
    ccall((:Mix_HaltChannel, libsdl2_mixer), Cint, (Cint,), channel)
end

function Mix_HaltGroup(tag::Cint)
    ccall((:Mix_HaltGroup, libsdl2_mixer), Cint, (Cint,), tag)
end

function Mix_HaltMusic()
    ccall((:Mix_HaltMusic, libsdl2_mixer), Cint, ())
end

function Mix_ExpireChannel(channel::Cint, ticks::Cint)
    ccall((:Mix_ExpireChannel, libsdl2_mixer), Cint, (Cint, Cint), channel, ticks)
end

function Mix_FadeOutChannel(which::Cint, ms::Cint)
    ccall((:Mix_FadeOutChannel, libsdl2_mixer), Cint, (Cint, Cint), which, ms)
end

function Mix_FadeOutGroup(tag::Cint, ms::Cint)
    ccall((:Mix_FadeOutGroup, libsdl2_mixer), Cint, (Cint, Cint), tag, ms)
end

function Mix_FadeOutMusic(ms::Cint)
    ccall((:Mix_FadeOutMusic, libsdl2_mixer), Cint, (Cint,), ms)
end

function Mix_FadingMusic()
    ccall((:Mix_FadingMusic, libsdl2_mixer), Mix_Fading, ())
end

function Mix_FadingChannel(which::Cint)
    ccall((:Mix_FadingChannel, libsdl2_mixer), Mix_Fading, (Cint,), which)
end

function Mix_Pause(channel::Cint)
    ccall((:Mix_Pause, libsdl2_mixer), Cvoid, (Cint,), channel)
end

function Mix_Resume(channel::Cint)
    ccall((:Mix_Resume, libsdl2_mixer), Cvoid, (Cint,), channel)
end

function Mix_Paused(channel::Cint)
    ccall((:Mix_Paused, libsdl2_mixer), Cint, (Cint,), channel)
end

function Mix_PauseMusic()
    ccall((:Mix_PauseMusic, libsdl2_mixer), Cvoid, ())
end

function Mix_ResumeMusic()
    ccall((:Mix_ResumeMusic, libsdl2_mixer), Cvoid, ())
end

function Mix_RewindMusic()
    ccall((:Mix_RewindMusic, libsdl2_mixer), Cvoid, ())
end

function Mix_PausedMusic()
    ccall((:Mix_PausedMusic, libsdl2_mixer), Cint, ())
end

function Mix_SetMusicPosition(position::Cdouble)
    ccall((:Mix_SetMusicPosition, libsdl2_mixer), Cint, (Cdouble,), position)
end

function Mix_Playing(channel::Cint)
    ccall((:Mix_Playing, libsdl2_mixer), Cint, (Cint,), channel)
end

function Mix_PlayingMusic()
    ccall((:Mix_PlayingMusic, libsdl2_mixer), Cint, ())
end

function Mix_SetMusicCMD(command)
    ccall((:Mix_SetMusicCMD, libsdl2_mixer), Cint, (Cstring,), command)
end

function Mix_SetSynchroValue(value::Cint)
    ccall((:Mix_SetSynchroValue, libsdl2_mixer), Cint, (Cint,), value)
end

function Mix_GetSynchroValue()
    ccall((:Mix_GetSynchroValue, libsdl2_mixer), Cint, ())
end

function Mix_SetSoundFonts(paths)
    ccall((:Mix_SetSoundFonts, libsdl2_mixer), Cint, (Cstring,), paths)
end

function Mix_GetSoundFonts()
    ccall((:Mix_GetSoundFonts, libsdl2_mixer), Cstring, ())
end

function Mix_EachSoundFont(_function, data)
    ccall((:Mix_EachSoundFont, libsdl2_mixer), Cint, (Ptr{Cvoid}, Ptr{Cvoid}), _function, data)
end

function Mix_GetChunk(channel::Cint)
    ccall((:Mix_GetChunk, libsdl2_mixer), Ptr{Mix_Chunk}, (Cint,), channel)
end

function Mix_CloseAudio()
    ccall((:Mix_CloseAudio, libsdl2_mixer), Cvoid, ())
end
