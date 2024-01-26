module Platformer
    using JulGame
    using JulGame.Math
    using JulGame.SceneBuilderModule
    
    function run()
        JulGame.MAIN.testMode = true
        JulGame.MAIN.testLength = 30.0
        JulGame.MAIN.currentTestTime = 0.0
        JulGame.PIXELS_PER_UNIT = 16
        scene = Scene("level_0.json")
        try
            scene.init("JulGame Example", false, Vector2(1280, 720),Vector2(1280, 720), true, 1.0, true, 144)
        catch e
            @error e
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