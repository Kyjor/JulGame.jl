    function run(SMOKETESTDIR, Test)
        JulGame.MAIN = JulGame.Main(Float64(1.0))
        MAIN.testMode = true
        MAIN.testLength = 10.0
        MAIN.currentTestTime = 0.0
        JulGame.PIXELS_PER_UNIT = 16
        
        scene = SceneBuilderModule.Scene("scene.json", SMOKETESTDIR)
        try
            SceneBuilderModule.load_and_prepare_scene(scene, "JulGame Example", false, Math.Vector2(1920, 1080), Math.Vector2(576, 576), false, 1.0, true, 60.0, [Test])
        catch e
            @error e
            Base.show_backtrace(stderr, catch_backtrace())
            return -1
        end

        return 0
    end