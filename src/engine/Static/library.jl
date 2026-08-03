# Entry point for compile_library.jl (same pattern as sc-game/library.jl).
using StaticTools

include("static_constants.jl")
include("static_structs.jl")
include("static_helpers.jl")
include("StaticLib.jl")
