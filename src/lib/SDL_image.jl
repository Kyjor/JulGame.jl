# Julia wrapper for header: /Users/bieler/Desktop/tmp/SDL2-2.0.8/include/libsdl2_image.h
# Automatically generated using Clang.jl wrap_c, version 0.0.0
include("SDL_image_h.jl")

function IMG_Linked_Version()
    ccall((:IMG_Linked_Version, libsdl2_image), Ptr{SDL_version}, ())
end

function IMG_Init(flags::Cint)
    ccall((:IMG_Init, libsdl2_image), Cint, (Cint,), flags)
end

function IMG_Quit()
    ccall((:IMG_Quit, libsdl2_image), Cvoid, ())
end

function IMG_LoadTyped_RW(src, freesrc::Cint, _type)
    ccall((:IMG_LoadTyped_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops}, Cint, Cstring), src, freesrc, _type)
end

function IMG_Load(file)
    ccall((:IMG_Load, libsdl2_image), Ptr{Surface}, (Cstring,), file)
end

function IMG_Load_RW(src, freesrc::Cint)
    ccall((:IMG_Load_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops}, Cint), src, freesrc)
end

function IMG_LoadTexture(renderer, file)
    ccall((:IMG_LoadTexture, libsdl2_image), Ptr{Texture}, (Ptr{Renderer}, Cstring), renderer, file)
end

function IMG_LoadTexture_RW(renderer, src, freesrc::Cint)
    ccall((:IMG_LoadTexture_RW, libsdl2_image), Ptr{Texture}, (Ptr{Renderer}, Ptr{RWops}, Cint), renderer, src, freesrc)
end

function IMG_LoadTextureTyped_RW(renderer, src, freesrc::Cint, _type)
    ccall((:IMG_LoadTextureTyped_RW, libsdl2_image), Ptr{Texture}, (Ptr{Renderer}, Ptr{RWops}, Cint, Cstring), renderer, src, freesrc, _type)
end

function IMG_isICO(src)
    ccall((:IMG_isICO, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isCUR(src)
    ccall((:IMG_isCUR, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isBMP(src)
    ccall((:IMG_isBMP, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isGIF(src)
    ccall((:IMG_isGIF, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isJPG(src)
    ccall((:IMG_isJPG, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isLBM(src)
    ccall((:IMG_isLBM, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isPCX(src)
    ccall((:IMG_isPCX, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isPNG(src)
    ccall((:IMG_isPNG, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isPNM(src)
    ccall((:IMG_isPNM, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isSVG(src)
    ccall((:IMG_isSVG, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isTIF(src)
    ccall((:IMG_isTIF, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isXCF(src)
    ccall((:IMG_isXCF, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isXPM(src)
    ccall((:IMG_isXPM, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isXV(src)
    ccall((:IMG_isXV, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_isWEBP(src)
    ccall((:IMG_isWEBP, libsdl2_image), Cint, (Ptr{RWops},), src)
end

function IMG_LoadICO_RW(src)
    ccall((:IMG_LoadICO_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadCUR_RW(src)
    ccall((:IMG_LoadCUR_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadBMP_RW(src)
    ccall((:IMG_LoadBMP_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadGIF_RW(src)
    ccall((:IMG_LoadGIF_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadJPG_RW(src)
    ccall((:IMG_LoadJPG_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadLBM_RW(src)
    ccall((:IMG_LoadLBM_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadPCX_RW(src)
    ccall((:IMG_LoadPCX_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadPNG_RW(src)
    ccall((:IMG_LoadPNG_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadPNM_RW(src)
    ccall((:IMG_LoadPNM_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadSVG_RW(src)
    ccall((:IMG_LoadSVG_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadTGA_RW(src)
    ccall((:IMG_LoadTGA_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadTIF_RW(src)
    ccall((:IMG_LoadTIF_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadXCF_RW(src)
    ccall((:IMG_LoadXCF_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadXPM_RW(src)
    ccall((:IMG_LoadXPM_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadXV_RW(src)
    ccall((:IMG_LoadXV_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_LoadWEBP_RW(src)
    ccall((:IMG_LoadWEBP_RW, libsdl2_image), Ptr{Surface}, (Ptr{RWops},), src)
end

function IMG_ReadXPMFromArray(xpm)
    ccall((:IMG_ReadXPMFromArray, libsdl2_image), Ptr{Surface}, (Ptr{Cstring},), xpm)
end

function IMG_SavePNG(surface, file)
    ccall((:IMG_SavePNG, libsdl2_image), Cint, (Ptr{Surface}, Cstring), surface, file)
end

function IMG_SavePNG_RW(surface, dst, freedst::Cint)
    ccall((:IMG_SavePNG_RW, libsdl2_image), Cint, (Ptr{Surface}, Ptr{RWops}, Cint), surface, dst, freedst)
end

function IMG_SaveJPG(surface, file, quality::Cint)
    ccall((:IMG_SaveJPG, libsdl2_image), Cint, (Ptr{Surface}, Cstring, Cint), surface, file, quality)
end

function IMG_SaveJPG_RW(surface, dst, freedst::Cint, quality::Cint)
    ccall((:IMG_SaveJPG_RW, libsdl2_image), Cint, (Ptr{Surface}, Ptr{RWops}, Cint, Cint), surface, dst, freedst, quality)
end
