using JulGame
using Test

ROOTDIR = joinpath(@__DIR__, "..")

@testset "All tests" begin
    include("engine/enginetests.jl")
    include("math/mathtests.jl")
end