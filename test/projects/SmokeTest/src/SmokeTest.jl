module SmokeTest
    using JulGame
    using JulGame.Math
    using JulGame.SceneBuilderModule
    
    function run(SMOKETESTDIR)
        JulGame.MAIN = JulGame.Main(Float64(1.0))
        MAIN.testMode = true
        MAIN.testLength = 10.0
        MAIN.currentTestTime = 0.0
        JulGame.PIXELS_PER_UNIT = 16
        
        scene = SceneBuilderModule.Scene("scene.json", SMOKETESTDIR)
        try
            SceneBuilderModule.init(scene, "JulGame Example", false, Math.Vector2(1920, 1080), Math.Vector2(576, 576), false, 1.0, true)
        catch e
            @error e
            Base.show_backtrace(stderr, catch_backtrace())
            return -1
        end

        println("Running")
        return 0
    end

    julia_main() = run()
end
