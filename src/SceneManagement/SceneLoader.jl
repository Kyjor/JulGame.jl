module SceneLoaderModule
    using ..SceneManagement.JulGame
    using ..SceneManagement.SceneBuilderModule

    export loadScene
    function loadScene(projectPath, sceneFileName, isUsingEditor = false) 
        JulGame.BasePath = projectPath
        main = Scene(sceneFileName, projectPath)
        
        return main.init("Editor", isUsingEditor)
    end
end