module Platformer
    using JulGame
    using JulGame.Math
    using JulGame.SceneBuilderModule
    
    function run()
        JulGame.MAIN = JulGame.Main(Float64(1.0))
        MAIN.testMode = true
        MAIN.testLength = 30.0
        MAIN.currentTestTime = 0.0
        JulGame.PIXELS_PER_UNIT = 16
        scene = Scene("level_0.json")
        try
            SceneBuilderModule.init(scene, "JulGame Example", false, Vector2(1920, 1080),Vector2(1280, 720), true, 1.0, true, 120)
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
# comment when building
#Platformer.run()
# using Profile

# @profile Platformer.run()

# Profile.print(format=:flat)

#@profview_allocs Platformer.run() sample_rate = 1
#using Cthulhu
#@profview Platformer.run()
# Click somewhere in the profile
#Cthulhu.descend_clicked()