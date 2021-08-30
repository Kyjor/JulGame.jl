# Julia wrapper for header: /Users/bieler/Downloads/SDL2_ttf-2.0.14/libSDL2_ttf.h
# Automatically generated using Clang.jl wrap_c, version 0.0.0
include("SDL_ttf_h.jl")

function TTF_Linked_Version()
    ccall((:TTF_Linked_Version, libsdl2_ttf), Ptr{SDL_version}, ())
end

function TTF_ByteSwappedUNICODE(swapped::Cint)
    ccall((:TTF_ByteSwappedUNICODE, libsdl2_ttf), Cvoid, (Cint,), swapped)
end

function TTF_Init()
    ccall((:TTF_Init, libsdl2_ttf), Cint, ())
end

function TTF_OpenFont(file, ptsize)
    ccall((:TTF_OpenFont, libsdl2_ttf), Ptr{TTF_Font}, (Cstring, Cint), file, ptsize)
end

function TTF_OpenFontIndex(file, ptsize::Cint, index::Clong)
    ccall((:TTF_OpenFontIndex, libsdl2_ttf), Ptr{TTF_Font}, (Cstring, Cint, Clong), file, ptsize, index)
end

function TTF_OpenFontRW(src, freesrc::Cint, ptsize::Cint)
    ccall((:TTF_OpenFontRW, libsdl2_ttf), Ptr{TTF_Font}, (Ptr{RWops}, Cint, Cint), src, freesrc, ptsize)
end

function TTF_OpenFontIndexRW(src, freesrc::Cint, ptsize::Cint, index::Clong)
    ccall((:TTF_OpenFontIndexRW, libsdl2_ttf), Ptr{TTF_Font}, (Ptr{RWops}, Cint, Cint, Clong), src, freesrc, ptsize, index)
end

function TTF_GetFontStyle(font)
    ccall((:TTF_GetFontStyle, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_SetFontStyle(font, style::Cint)
    ccall((:TTF_SetFontStyle, libsdl2_ttf), Cvoid, (Ptr{TTF_Font}, Cint), font, style)
end

function TTF_GetFontOutline(font)
    ccall((:TTF_GetFontOutline, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_SetFontOutline(font, outline::Cint)
    ccall((:TTF_SetFontOutline, libsdl2_ttf), Cvoid, (Ptr{TTF_Font}, Cint), font, outline)
end

function TTF_GetFontHinting(font)
    ccall((:TTF_GetFontHinting, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_SetFontHinting(font, hinting::Cint)
    ccall((:TTF_SetFontHinting, libsdl2_ttf), Cvoid, (Ptr{TTF_Font}, Cint), font, hinting)
end

function TTF_FontHeight(font)
    ccall((:TTF_FontHeight, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_FontAscent(font)
    ccall((:TTF_FontAscent, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_FontDescent(font)
    ccall((:TTF_FontDescent, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_FontLineSkip(font)
    ccall((:TTF_FontLineSkip, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_GetFontKerning(font)
    ccall((:TTF_GetFontKerning, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_SetFontKerning(font, allowed::Cint)
    ccall((:TTF_SetFontKerning, libsdl2_ttf), Cvoid, (Ptr{TTF_Font}, Cint), font, allowed)
end

function TTF_FontFaces(font)
    ccall((:TTF_FontFaces, libsdl2_ttf), Clong, (Ptr{TTF_Font},), font)
end

function TTF_FontFaceIsFixedWidth(font)
    ccall((:TTF_FontFaceIsFixedWidth, libsdl2_ttf), Cint, (Ptr{TTF_Font},), font)
end

function TTF_FontFaceFamilyName(font)
    ccall((:TTF_FontFaceFamilyName, libsdl2_ttf), Cstring, (Ptr{TTF_Font},), font)
end

function TTF_FontFaceStyleName(font)
    ccall((:TTF_FontFaceStyleName, libsdl2_ttf), Cstring, (Ptr{TTF_Font},), font)
end

function TTF_GlyphIsProvided(font, ch::Uint16)
    ccall((:TTF_GlyphIsProvided, libsdl2_ttf), Cint, (Ptr{TTF_Font}, Uint16), font, ch)
end

function TTF_GlyphMetrics(font, ch::Uint16, minx, maxx, miny, maxy, advance)
    ccall((:TTF_GlyphMetrics, libsdl2_ttf), Cint, (Ptr{TTF_Font}, Uint16, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}, Ptr{Cint}), font, ch, minx, maxx, miny, maxy, advance)
end

function TTF_SizeText(font, text, w, h)
    ccall((:TTF_SizeText, libsdl2_ttf), Cint, (Ptr{TTF_Font}, Cstring, Ptr{Cint}, Ptr{Cint}), font, text, w, h)
end

function TTF_SizeUTF8(font, text, w, h)
    ccall((:TTF_SizeUTF8, libsdl2_ttf), Cint, (Ptr{TTF_Font}, Cstring, Ptr{Cint}, Ptr{Cint}), font, text, w, h)
end

function TTF_SizeUNICODE(font, text, w, h)
    ccall((:TTF_SizeUNICODE, libsdl2_ttf), Cint, (Ptr{TTF_Font}, Ptr{Uint16}, Ptr{Cint}, Ptr{Cint}), font, text, w, h)
end

function TTF_RenderText_Solid(font, text, fg::Color)
    ccall((:TTF_RenderText_Solid, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Cstring, Color), font, text, fg)
end

function TTF_RenderUTF8_Solid(font, text, fg::Color)
    ccall((:TTF_RenderUTF8_Solid, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Cstring, Color), font, text, fg)
end

function TTF_RenderUNICODE_Solid(font, text, fg::Color)
    ccall((:TTF_RenderUNICODE_Solid, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Ptr{Uint16}, Color), font, text, fg)
end

function TTF_RenderGlyph_Solid(font, ch::Uint16, fg::Color)
    ccall((:TTF_RenderGlyph_Solid, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Uint16, Color), font, ch, fg)
end

function TTF_RenderText_Shaded(font, text, fg::Color, bg::Color)
    ccall((:TTF_RenderText_Shaded, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Cstring, Color, Color), font, text, fg, bg)
end

function TTF_RenderUTF8_Shaded(font, text, fg::Color, bg::Color)
    ccall((:TTF_RenderUTF8_Shaded, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Cstring, Color, Color), font, text, fg, bg)
end

function TTF_RenderUNICODE_Shaded(font, text, fg::Color, bg::Color)
    ccall((:TTF_RenderUNICODE_Shaded, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Ptr{Uint16}, Color, Color), font, text, fg, bg)
end

function TTF_RenderGlyph_Shaded(font, ch::Uint16, fg::Color, bg::Color)
    ccall((:TTF_RenderGlyph_Shaded, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Uint16, Color, Color), font, ch, fg, bg)
end

function TTF_RenderText_Blended(font, text, fg::Color)
    ccall((:TTF_RenderText_Blended, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Cstring, Color), font, text, fg)
end

function TTF_RenderUTF8_Blended(font, text, fg::Color)
    ccall((:TTF_RenderUTF8_Blended, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Cstring, Color), font, text, fg)
end

function TTF_RenderUNICODE_Blended(font, text, fg::Color)
    ccall((:TTF_RenderUNICODE_Blended, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Ptr{Uint16}, Color), font, text, fg)
end

function TTF_RenderText_Blended_Wrapped(font, text, fg::Color, wrapLength::Uint32)
    ccall((:TTF_RenderText_Blended_Wrapped, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Cstring, Color, Uint32), font, text, fg, wrapLength)
end

function TTF_RenderUTF8_Blended_Wrapped(font, text, fg::Color, wrapLength::Uint32)
    ccall((:TTF_RenderUTF8_Blended_Wrapped, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Cstring, Color, Uint32), font, text, fg, wrapLength)
end

function TTF_RenderUNICODE_Blended_Wrapped(font, text, fg::Color, wrapLength::Uint32)
    ccall((:TTF_RenderUNICODE_Blended_Wrapped, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Ptr{Uint16}, Color, Uint32), font, text, fg, wrapLength)
end

function TTF_RenderGlyph_Blended(font, ch::Uint16, fg::Color)
    ccall((:TTF_RenderGlyph_Blended, libsdl2_ttf), Ptr{Surface}, (Ptr{TTF_Font}, Uint16, Color), font, ch, fg)
end

function TTF_CloseFont(font)
    ccall((:TTF_CloseFont, libsdl2_ttf), Cvoid, (Ptr{TTF_Font},), font)
end

function TTF_Quit()
    ccall((:TTF_Quit, libsdl2_ttf), Cvoid, ())
end

function TTF_WasInit()
    ccall((:TTF_WasInit, libsdl2_ttf), Cint, ())
end

function TTF_GetFontKerningSize(font, prev_index::Cint, index::Cint)
    ccall((:TTF_GetFontKerningSize, libsdl2_ttf), Cint, (Ptr{TTF_Font}, Cint, Cint), font, prev_index, index)
end

function TTF_GetFontKerningSizeGlyphs(font, previous_ch::Uint16, ch::Uint16)
    ccall((:TTF_GetFontKerningSizeGlyphs, libsdl2_ttf), Cint, (Ptr{TTF_Font}, Uint16, Uint16), font, previous_ch, ch)
end
