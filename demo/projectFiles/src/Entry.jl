module Entry
    using julGame.SceneBuilderModule
    #include("../scenes/level_1.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 

    function run(scene, isUsingEditor = false)
        SDL2.init()
        if isUsingEditor
            dir = @__DIR__
        else
            dir = pwd()
        end
        main = Scene(dir, scene)
        return main.init(isUsingEditor)
    end

    julia_main() = run()
end