# Shared access to the JulGame StaticCompiler native library (lib_desktop).
module JGStaticModule

const LIB_EXT = Sys.iswindows() ? "dll" : Sys.isapple() ? "dylib" : "so"
const LIB_DIR = normpath(joinpath(@__DIR__, "lib_desktop"))
# Built artifact name from compile_library.jl / build_host.sh
const LIB_PATH = joinpath(LIB_DIR, "libjg_static.$LIB_EXT")
const LIB_AVAILABLE = isfile(LIB_PATH)

const _NOTHING_SENTINEL_SET = Ref(false)

# Same bit pattern Julia uses for Union{Mutable,Nothing} === nothing (not address 0).
mutable struct _NothingProbeMut end
mutable struct _NothingProbe
    x::Union{_NothingProbeMut, Nothing}
end

function lib_path()::String
    LIB_PATH
end

function lib_available()::Bool
    LIB_AVAILABLE
end

"""Capture Julia's nothing sentinel once so the static lib can null-check Union fields."""
function ensure_julia_nothing_sentinel!()
    LIB_AVAILABLE || return
    _NOTHING_SENTINEL_SET[] && return
    probe = _NothingProbe(nothing)
    bits = unsafe_load(Ptr{Ptr{Cvoid}}(Ptr{UInt8}(pointer_from_objref(probe)) + fieldoffset(_NothingProbe, 1)))
    ccall((:static_set_julia_nothing, LIB_PATH), Cvoid, (Ptr{Cvoid},), bits)
    _NOTHING_SENTINEL_SET[] = true
    return
end

function __init__()
    # Must run at runtime: top-level during precompile sets the Ref but the dylib global resets.
    _NOTHING_SENTINEL_SET[] = false
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
