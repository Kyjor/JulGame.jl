using JulGame
using Test

ROOTDIR = joinpath(@__DIR__, "..")

@testset "All tests" begin
    include("engine/engine.jl")
end