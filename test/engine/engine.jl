using JulGame
using Test

ROOTDIR = joinpath(@__DIR__, "..", "..")



@testset "Example" begin
    @test 1 == 2
    scene = SceneBuilderModule.Scene(joinpath(ROOTDIR , "examples", "Testing", "Testing"), "scene.json")
    main = scene.init("JulGame Example", false, Math.Vector2(1920, 1080),Math.Vector2(576, 576), false, 1.0, true)
end