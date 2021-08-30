# Automatically generated using Clang.jl wrap_c, version 0.0.0

const OBJC_NEW_PROPERTIES = 1
const SDL_TTF_MAJOR_VERSION = 2
const SDL_TTF_MINOR_VERSION = 0
const SDL_TTF_PATCHLEVEL = 14

# Skipping MacroDefinition: SDL_TTF_VERSION ( X ) \
#{ ( X ) -> major = SDL_TTF_MAJOR_VERSION ; ( X ) -> minor = SDL_TTF_MINOR_VERSION ; ( X ) -> patch = SDL_TTF_PATCHLEVEL ; \
#}

const TTF_MAJOR_VERSION = SDL_TTF_MAJOR_VERSION
const TTF_MINOR_VERSION = SDL_TTF_MINOR_VERSION
const TTF_PATCHLEVEL = SDL_TTF_PATCHLEVEL

# Skipping MacroDefinition: TTF_VERSION ( X ) SDL_TTF_VERSION ( X )

const UNICODE_BOM_NATIVE = Float32(0x0fef)
const UNICODE_BOM_SWAPPED = 0xfffe
const TTF_STYLE_NORMAL = 0x00
const TTF_STYLE_BOLD = 0x01
const TTF_STYLE_ITALIC = 0x02
const TTF_STYLE_UNDERLINE = 0x04
const TTF_STYLE_STRIKETHROUGH = 0x08
const TTF_HINTING_NORMAL = 0
const TTF_HINTING_LIGHT = 1
const TTF_HINTING_MONO = 2
const TTF_HINTING_NONE = 3

# Skipping MacroDefinition: TTF_RenderText ( font , text , fg , bg ) TTF_RenderText_Shaded ( font , text , fg , bg )
# Skipping MacroDefinition: TTF_RenderUTF8 ( font , text , fg , bg ) TTF_RenderUTF8_Shaded ( font , text , fg , bg )
# Skipping MacroDefinition: TTF_RenderUNICODE ( font , text , fg , bg ) TTF_RenderUNICODE_Shaded ( font , text , fg , bg )

#const TTF_SetError = SDL_SetError
#const TTF_GetError = SDL_GetError

mutable struct _TTF_Font
end

const TTF_Font = _TTF_Font
