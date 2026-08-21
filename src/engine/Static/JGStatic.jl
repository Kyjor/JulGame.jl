# Shared access to the JulGame StaticCompiler native library (lib_desktop).
module JGStaticModule

const LIB_EXT = Sys.iswindows() ? "dll" : Sys.isapple() ? "dylib" : "so"
const LIB_DIR = normpath(joinpath(@__DIR__, "lib_desktop"))
# Built artifact name from compile_library.jl / build_host.sh
const LIB_PATH = joinpath(LIB_DIR, "libjg_static.$LIB_EXT")
const LIB_AVAILABLE = isfile(LIB_PATH)

# Match Libdl.jl: bare StaticCompiler ccalls use RTLD_DEFAULT, which only sees
# libraries opened with RTLD_GLOBAL.
const _RTLD_LAZY = Cint(0x00001)
const _RTLD_GLOBAL = Sys.isapple() ? Cint(0x8) : Cint(0x00100)

const _NOTHING_SENTINEL_SET = Ref(false)

# Same bit pattern Julia uses for Union{Mutable,Nothing} === nothing (not address 0).
mutable struct _NothingProbeMut end
mutable struct _NothingProbe
    x::Union{_NothingProbeMut, Nothing}
end

# Union{Mutable,Ptr{Nothing}}(C_NULL) boxes a new Ptr{Nothing}; capture its type tag.
mutable struct _CnullProbeMut end
mutable struct _CnullProbe
    x::Union{_CnullProbeMut, Ptr{Nothing}}
end

function lib_path()::String
    LIB_PATH
end

function lib_available()::Bool
    LIB_AVAILABLE
end

"""Promote libsdl2 into the global symbol table so llvmcall SDL_* externs resolve."""
function ensure_sdl_global!()
    if Sys.iswindows()
        return
    end
    lib = _sdl2_lib()
    ccall(:dlopen, Ptr{Cvoid}, (Cstring, Cint), lib, _RTLD_LAZY | _RTLD_GLOBAL)
    return
end

"""Open libjg_static with RTLD_GLOBAL before any ccall."""
function ensure_lib_opened!()
    LIB_AVAILABLE || return
    if Sys.iswindows()
        # LoadLibrary is process-global; Julia's ccall path is enough.
        return
    end
    ensure_sdl_global!()
    ccall(:dlopen, Ptr{Cvoid}, (Cstring, Cint), LIB_PATH, _RTLD_LAZY | _RTLD_GLOBAL)
    return
end

function _sdl2_lib()
    lib = parentmodule(@__MODULE__).SDL2.LibSDL2.libsdl2
    if isa(lib, Function)
        return lib()
    end
    return lib
end

"""Capture Julia's nothing sentinel once so the static lib can null-check Union fields."""
function ensure_julia_nothing_sentinel!()
    LIB_AVAILABLE || return
    _NOTHING_SENTINEL_SET[] && return
    ensure_lib_opened!()
    probe = _NothingProbe(nothing)
    bits = unsafe_load(Ptr{Ptr{Cvoid}}(Ptr{UInt8}(pointer_from_objref(probe)) + fieldoffset(_NothingProbe, 1)))
    ccall((:static_set_julia_nothing, LIB_PATH), Cvoid, (Ptr{Cvoid},), bits)
    cprobe = _CnullProbe(C_NULL)
    boxed = unsafe_load(Ptr{Ptr{Cvoid}}(Ptr{UInt8}(pointer_from_objref(cprobe)) + fieldoffset(_CnullProbe, 1)))
    ty = unsafe_load(Ptr{Ptr{Cvoid}}(Ptr{UInt8}(boxed) - sizeof(Ptr{Cvoid})))
    ccall((:static_set_julia_ptr_nothing_type, LIB_PATH), Cvoid, (Ptr{Cvoid},), ty)
    _NOTHING_SENTINEL_SET[] = true
    return
end

function __init__()
    # Must run at runtime: top-level during precompile sets the Ref but the dylib global resets.
    _NOTHING_SENTINEL_SET[] = false
    ensure_lib_opened!()
    ensure_julia_nothing_sentinel!()
end

@info "JGStatic" path=LIB_PATH available=LIB_AVAILABLE

export LIB_EXT,
       LIB_DIR,
       LIB_PATH,
       LIB_AVAILABLE,
       lib_path,
       lib_available,
       ensure_julia_nothing_sentinel!

end
