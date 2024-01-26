using JulGame
using Test

ROOTDIR = joinpath(@__DIR__, "..")
EXAMPLEGAMEDIR = joinpath(ROOTDIR, "examples")
SMOKETESTDIR = joinpath(@__DIR__, "projects", "SmokeTest")
PROFILINGTESTDIR = joinpath(@__DIR__, "projects", "ProfilingTest")
include(joinpath(SMOKETESTDIR, "scripts", "TestScript.jl"))
include(joinpath(PROFILINGTESTDIR, "Platformer", "src", "Platformer.jl"))

@testset "All tests" begin
    include("engine/enginetests.jl")
    include("math/mathtests.jl")
    cd(joinpath(@__DIR__, "projects", "ProfilingTest", "Platformer", "src"))
    @testset "Platformer" begin
        @test Platformer.run() == 0
    end
end