# Automatically generated using Clang.jl wrap_c, version 0.0.0


const SDL_MIX_MAXVOLUME = 128
const SDL_MAJOR_VERSION = 2
const SDL_MINOR_VERSION = 0
const SDL_PATCHLEVEL = 7

# Skipping MacroDefinition: SDL_VERSION ( x ) \
#{ ( x ) -> major = SDL_MAJOR_VERSION ; ( x ) -> minor = SDL_MINOR_VERSION ; ( x ) -> patch = SDL_PATCHLEVEL ; \
#}
# Skipping MacroDefinition: SDL_VERSIONNUM ( X , Y , Z ) ( ( X ) * 1000 + ( Y ) * 100 + ( Z ) )
# Skipping MacroDefinition: SDL_COMPILEDVERSION SDL_VERSIONNUM ( SDL_MAJOR_VERSION , SDL_MINOR_VERSION , SDL_PATCHLEVEL )
# Skipping MacroDefinition: SDL_VERSION_ATLEAST ( X , Y , Z ) ( SDL_COMPILEDVERSION >= SDL_VERSIONNUM ( X , Y , Z ) )

const SDL_MIXER_MAJOR_VERSION = 2
const SDL_MIXER_MINOR_VERSION = 0
const SDL_MIXER_PATCHLEVEL = 2

# Skipping MacroDefinition: SDL_MIXER_VERSION ( X ) \
#{ ( X ) -> major = SDL_MIXER_MAJOR_VERSION ; ( X ) -> minor = SDL_MIXER_MINOR_VERSION ; ( X ) -> patch = SDL_MIXER_PATCHLEVEL ; \
#}

const MIX_MAJOR_VERSION = SDL_MIXER_MAJOR_VERSION
const MIX_MINOR_VERSION = SDL_MIXER_MINOR_VERSION
const MIX_PATCHLEVEL = SDL_MIXER_PATCHLEVEL

# Skipping MacroDefinition: MIX_VERSION ( X ) SDL_MIXER_VERSION ( X )
# Skipping MacroDefinition: SDL_MIXER_COMPILEDVERSION SDL_VERSIONNUM ( SDL_MIXER_MAJOR_VERSION , SDL_MIXER_MINOR_VERSION , SDL_MIXER_PATCHLEVEL )
# Skipping MacroDefinition: SDL_MIXER_VERSION_ATLEAST ( X , Y , Z ) ( SDL_MIXER_COMPILEDVERSION >= SDL_VERSIONNUM ( X , Y , Z ) )

const MIX_CHANNELS = 8
const MIX_DEFAULT_FREQUENCY = 22050
const MIX_DEFAULT_FORMAT = AUDIO_S16LSB
const MIX_DEFAULT_CHANNELS = 2
const MIX_MAX_VOLUME = SDL_MIX_MAXVOLUME

# Skipping MacroDefinition: Mix_LoadWAV ( file ) Mix_LoadWAV_RW ( SDL_RWFromFile ( file , "rb" ) , 1 )
Mix_LoadWAV(file::String) = Mix_LoadWAV_RW(RWFromFile( file , "rb" ),Int32(1))

const MIX_CHANNEL_POST = -2
const MIX_EFFECTSMAXSPEED = "MIX_EFFECTSMAXSPEED"

# Skipping MacroDefinition: Mix_PlayChannel ( channel , chunk , loops ) Mix_PlayChannelTimed ( channel , chunk , loops , - 1 )
# Skipping MacroDefinition: Mix_FadeInChannel ( channel , chunk , loops , ms ) Mix_FadeInChannelTimed ( channel , chunk , loops , ms , - 1 )
Mix_PlayChannel(channel , chunk , loops) = Mix_PlayChannelTimed( channel , chunk , loops , Int32(-1) )
Mix_FadeInChannel(channel , chunk , loops , ms) = Mix_FadeInChannelTimed( channel , chunk , loops , ms , Int32(-1) )

# const Mix_SetError = SDL_SetError
# const Mix_GetError = SDL_GetError
# const Mix_ClearError = SDL_ClearError


mutable struct Mix_Chunk
    allocated::Cint
    abuf::Ptr{Uint8}
    alen::Uint32
    volume::Uint8
end

# begin enum ANONYMOUS_9
const ANONYMOUS_9 = UInt32
const MIX_NO_FADING = (UInt32)(0)
const MIX_FADING_OUT = (UInt32)(1)
const MIX_FADING_IN = (UInt32)(2)
# end enum ANONYMOUS_9

Mix_Fading = UInt32

# begin enum ANONYMOUS_10
const ANONYMOUS_10 = UInt32
const MUS_NONE = (UInt32)(0)
const MUS_CMD = (UInt32)(1)
const MUS_WAV = (UInt32)(2)
const MUS_MOD = (UInt32)(3)
const MUS_MID = (UInt32)(4)
const MUS_OGG = (UInt32)(5)
const MUS_MP3 = (UInt32)(6)
const MUS_MP3_MAD_UNUSED = (UInt32)(7)
const MUS_FLAC = (UInt32)(8)
const MUS_MODPLUG_UNUSED = (UInt32)(9)
# end enum ANONYMOUS_10

Mix_MusicType = UInt32

mutable struct _Mix_Music
end

Mix_Music = _Mix_Music
Mix_EffectFunc_t = Ptr{Cvoid}
Mix_EffectDone_t = Ptr{Cvoid}

# begin enum ANONYMOUS_8
const ANONYMOUS_8 = UInt32
const MIX_INIT_FLAC = (UInt32)(1)
const MIX_INIT_MOD = (UInt32)(2)
const MIX_INIT_MP3 = (UInt32)(8)
const MIX_INIT_OGG = (UInt32)(16)
const MIX_INIT_MID = (UInt32)(32)
# end enum ANONYMOUS_8

MIX_InitFlags = UInt32
