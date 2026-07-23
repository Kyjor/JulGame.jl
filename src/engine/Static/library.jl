# Entry point for compile_library.jl (same pattern as sc-game/library.jl).
using StaticTools

include("static_constants.jl")
include("static_structs.jl")
include("static_helpers.jl")
include("llvm_sdl_min.jl")
include("shell_sdl.jl")
include("world.jl")
include("StaticLib.jl")
