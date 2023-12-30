@testset "Open and close" begin
    JulGame.MAIN.testMode = true
    JulGame.MAIN.testLength = 0.0
    scene = SceneBuilderModule.Scene("scene.json", SMOKETESTDIR)
    try
        main = scene.init("JulGame Example", false, Math.Vector2(1920, 1080),Math.Vector2(576, 576), false, 1.0, true; TestScript = TestScript)
        
    catch e
        throw(e)
    end
end