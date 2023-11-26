using JulGame
using Test



@testset "Example" begin
    @test 1 == 2
    scene = SceneBuilderModule.Scene(joinpath(pwd(), ".."), "scene.json")
    main = scene.init("JulGame Example", false, Math.Vector2(1920, 1080),Math.Vector2(576, 576), false, 1.0, true)
end