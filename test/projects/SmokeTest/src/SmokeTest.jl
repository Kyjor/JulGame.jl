module SmokeTest
    using JulGame
    function run(SMOKETESTDIR, Test)
        JulGame.MAIN = JulGame.Main(Float64(1.0))
        MAIN.testMode = true
        MAIN.testLength = 10.0
        MAIN.currentTestTime = 0.0
        
        try
            SceneBuilderModule.load_and_prepare_scene(;this=SceneBuilderModule.Scene("scene.json", SMOKETESTDIR), globals=[Test])
        catch e
            @error e
            Base.show_backtrace(stderr, catch_backtrace())
            return -1
        end

        return 0
    end
end # module