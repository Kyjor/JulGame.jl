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
    @test SmokeTest.run(SMOKETESTDIR, Test) == 0
    include("math/mathtests.jl")

    cd(joinpath(@__DIR__, "projects", "ProfilingTest", "Platformer", "src"))
    @testset "Platformer" begin
        @test Platformer.run() == 0
    end

    cd(joinpath(ROOTDIR, "src", "editor", "JulGameEditor", "src"))
    include(joinpath(ROOTDIR, "src", "editor", "JulGameEditor", "src", "../Editor.jl"))
    @testset "Editor" begin
        @test Editor.run(true) == 0
    end
end