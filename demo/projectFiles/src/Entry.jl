module Entry
    using JulGame.SceneBuilderModule
    #include("../scenes/level_1.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 

    function run(projectPath, scene, isUsingEditor = false)
        SDL2.init()
        if isUsingEditor
            dir = @__DIR__
        else
            dir = pwd()
        end
        main = Scene(projectPath, scene)
        return main.init(isUsingEditor)
    end

    julia_main() = run()
end