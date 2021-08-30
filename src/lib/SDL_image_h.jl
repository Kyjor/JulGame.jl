# Automatically generated using Clang.jl wrap_c, version 0.0.0

const SDL_IMAGE_MAJOR_VERSION = 2
const SDL_IMAGE_MINOR_VERSION = 0
const SDL_IMAGE_PATCHLEVEL = 4

# Skipping MacroDefinition: SDL_IMAGE_VERSION ( X ) \
#{ ( X ) -> major = SDL_IMAGE_MAJOR_VERSION ; ( X ) -> minor = SDL_IMAGE_MINOR_VERSION ; ( X ) -> patch = SDL_IMAGE_PATCHLEVEL ; \
#}
# Skipping MacroDefinition: SDL_IMAGE_COMPILEDVERSION SDL_VERSIONNUM ( SDL_IMAGE_MAJOR_VERSION , SDL_IMAGE_MINOR_VERSION , SDL_IMAGE_PATCHLEVEL )
# Skipping MacroDefinition: SDL_IMAGE_VERSION_ATLEAST ( X , Y , Z ) ( SDL_IMAGE_COMPILEDVERSION >= SDL_VERSIONNUM ( X , Y , Z ) )

#const IMG_SetError = SDL_SetError
#const IMG_GetError = SDL_GetError

# begin enum ANONYMOUS_1
const ANONYMOUS_1 = UInt32
const SDL_FALSE = (UInt32)(0)
const SDL_TRUE = (UInt32)(1)
const SDL_bool = Bool

# end enum ANONYMOUS_1

# begin enum ANONYMOUS_49
const ANONYMOUS_49 = UInt32
const IMG_INIT_JPG = (UInt32)(1)
const IMG_INIT_PNG = (UInt32)(2)
const IMG_INIT_TIF = (UInt32)(4)
const IMG_INIT_WEBP = (UInt32)(8)
# end enum ANONYMOUS_49

#$(Expr(:typealias, :IMG_InitFlags, :Void))
