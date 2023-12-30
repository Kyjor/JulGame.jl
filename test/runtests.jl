using JulGame
using Test

ROOTDIR = joinpath(@__DIR__, "..")
EXAMPLEGAMEDIR = joinpath(ROOTDIR, "examples")
SMOKETESTDIR = joinpath(@__DIR__, "projects", "SmokeTest")
include(joinpath(@__DIR__, "projects", "SmokeTest", "scripts", "TestScript.jl"))

@testset "All tests" begin
    include("engine/enginetests.jl")
    include("math/mathtests.jl")
end