module SceneLoaderModule
    using ..SceneManagement.JulGame
    using ..SceneManagement.SceneBuilderModule

    export loadScene
    function loadScene(projectPath, sceneFileName, isUsingEditor = false) 
        JulGame.BasePath = JulGame.BasePath == "" ? projectPath : JulGame.BasePath
        main = Scene(sceneFileName, projectPath)
        
        return main.init("Editor", isUsingEditor)
    end
    
    export LoadSceneFromEditor
    function LoadSceneFromEditor(scenePath) 
        projectPath = GetProjectPathFromFullScenePath(scenePath)
        sceneFileName = GetSceneFileNameFromFullScenePath(scenePath)

        JulGame.BasePath = JulGame.BasePath == "" ? projectPath : JulGame.BasePath
        main = Scene("$sceneFileName", "$projectPath")
        
        return main.init("Editor", true)
    end

    export GetProjectPathFromFullScenePath
    function GetProjectPathFromFullScenePath(scenePath)
        projectPath = ""
        dirArray = length(split(scenePath, "/")) > 1 ? split(scenePath, "/") : split(scenePath, "\\")
        counter = 1
        for dir in dirArray
            if counter >= length(dirArray)-1
                continue
            elseif counter == 1
                projectPath = "$dir\\"
            else
                projectPath = joinpath(projectPath, dir)
            end
            counter += 1
        end

        return projectPath
    end

    export GetSceneFileNameFromFullScenePath
    function GetSceneFileNameFromFullScenePath(scenePath)
        sceneFileName = split(scenePath, "/")[end]
        sceneFileName = split(scenePath, "\\")[end]
        return sceneFileName
    end
end