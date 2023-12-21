module SceneLoaderModule
    using ..SceneManagement.JulGame
    using ..SceneManagement.SceneBuilderModule

    export loadScene
    function loadScene(projectPath, sceneFileName, isUsingEditor = false) 
        JulGame.BasePath = JulGame.BasePath == "" ? projectPath : JulGame.BasePath
        main = Scene(sceneFileName, projectPath)
        
        return main.init("Editor", isUsingEditor)
    end
end