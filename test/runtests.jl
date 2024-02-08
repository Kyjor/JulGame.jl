using JulGame
using Test

ROOTDIR = joinpath(@__DIR__, "..")
EXAMPLEGAMEDIR = joinpath(ROOTDIR, "examples")
SMOKETESTDIR = joinpath(@__DIR__, "projects", "SmokeTest")
PROFILINGTESTDIR = joinpath(@__DIR__, "projects", "ProfilingTest")
include(joinpath(SMOKETESTDIR, "src", "SmokeTest.jl"))
include(joinpath(PROFILINGTESTDIR, "Platformer", "src", "Platformer.jl"))

@testset "All tests" begin
    cd(joinpath(SMOKETESTDIR, "src"))
    @test SmokeTest.run(SMOKETESTDIR) == 0
    cd(joinpath(@__DIR__, "projects", "ProfilingTest", "Platformer", "src"))
    include("math/mathtests.jl")
    @testset "Platformer" begin
        @test Platformer.run() == 0
    end
end