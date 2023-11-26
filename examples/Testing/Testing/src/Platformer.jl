module Platformer 
    using JulGame
    using JulGame.Math
    using JulGame.SceneBuilderModule

    function run()
        scene = Scene(joinpath(pwd(), ".."), "scene.json")
        main = scene.init("JulGame Example", false, Vector2(1920, 1080),Vector2(576, 576), false, 1.0, true)
        return main
    end

    julia_main() = run()
end
# Uncommented to allow for direct execution of this file. If you want to build this project with PackageCompiler, comment the line below
Platformer.run()