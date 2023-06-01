module platformer
    using julGame.SceneBuilderModule
    #include("../scenes/level_1.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 

    function run(isUsingEditor = false)
        SDL2.init()
        scene = Scene(pwd(), "scene.json")
        return Scene.init(isUsingEditor)
    end

    julia_main() = run()
end