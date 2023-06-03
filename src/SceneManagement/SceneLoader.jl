module SceneLoaderModule
    using ..SceneManagement.SceneSceneBuilderModule
    #include("../scenes/level_1.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 

    export loadScene
    function loadScene(projectPath, sceneFileName, isUsingEditor = false)
        SDL2.init()
        if isUsingEditor
            dir = @__DIR__
        else
            dir = pwd()
        end
        main = Scene(projectPath, sceneFileName)
        return main.init(isUsingEditor)
    end
end