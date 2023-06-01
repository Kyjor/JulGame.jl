module platformer
    using julGame.SceneBuilder
    #include("../scenes/level_1.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 

    function run(isUsingEditor = false)
        SDL2.init()
        scene = scene(pwd(), "scene.json")
        return scene.init(isUsingEditor)
    end

    julia_main() = run()
end