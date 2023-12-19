using JulGame
using Test

ROOTDIR = joinpath(@__DIR__, "..")
TESTGAMEDIR = joinpath(ROOTDIR, "examples", "Testing", "Testing")
include(joinpath(TESTGAMEDIR, "scripts", "TestScript.jl"))

@testset "All tests" begin
    include("engine/enginetests.jl")
    include("math/mathtests.jl")
end