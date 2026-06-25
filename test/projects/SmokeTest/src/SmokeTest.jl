module SmokeTest
    using JulGame
    function run(SMOKETESTDIR, Test)
        JulGame.MAIN = JulGame.MainLoop()
        MAIN.testMode = true
        MAIN.testLength = 10.0
        MAIN.currentTestTime = 0.0
        
        try
            ENV["TEST_MODE"] = "true"
            ENV["TEST_LENGTH"] = "10.0"
            SceneBuilderModule.load_and_prepare_scene(SceneBuilderModule.Scene("scene.json", SMOKETESTDIR), JulGame.MAIN)
        catch e
            @error e
            Base.show_backtrace(stderr, catch_backtrace())
            return -1
        end

        return 0
    end
end # module