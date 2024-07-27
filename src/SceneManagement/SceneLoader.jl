module SceneLoaderModule
    using ...JulGame
    using ..SceneBuilderModule

    export load_scene
    """
        load_scene(projectPath::String, sceneFileName::String, isUsingEditor::Bool = false)

    Load a scene from the specified project path and scene file name.

    # Arguments
    - `projectPath`: The path to the project.
    - `sceneFileName`: The name of the scene file.
    - `isUsingEditor`: (optional) A boolean indicating whether the scene is being loaded in the editor.

    # Returns
    The initialized main scene.

    """
    function load_scene(projectPath::String, sceneFileName::String, isUsingEditor::Bool = false) 
        JulGame.BasePath = JulGame.BasePath == "" ? projectPath : JulGame.BasePath
        #println("Loading scene $sceneFileName from $projectPath")
        main = Scene(sceneFileName, projectPath)
        return MAIN.init("Editor", isUsingEditor)
    end
    
    export load_scene_from_editor
    """
        load_scene_from_editor(scenePath::String, renderer = nothing, isNewEditor::Bool=false)

    Load a scene from the editor.

    # Arguments
    - `scenePath`: The path of the scene to load.
    - `renderer`: Optional renderer to use for the scene.
    - `isNewEditor`: Boolean indicating whether we are using the new editor.

    # Returns
    - The initialized main scene.

    """
    function load_scene_from_editor(scenePath::String, renderer = nothing, isNewEditor::Bool=false) 

        projectPath = get_project_path_from_full_scene_path(scenePath)
        sceneFileName = get_scene_file_name_from_full_scene_path(scenePath)

        JulGame.BasePath = JulGame.BasePath == "" ? projectPath : JulGame.BasePath
        if renderer !== nothing
            JulGame.Renderer = renderer
        end
        JulGame.MAIN = JulGame.Main(Float64(1.0))
        #println("Loading scene $sceneFileName from $projectPath")
        scene = Scene("$sceneFileName", "$projectPath")

        return scene.init("Editor", true; isNewEditor=isNewEditor)
    end

    export get_project_path_from_full_scene_path
    """
        get_project_path_from_full_scene_path(scenePath::String)

    Get the project path from the full scene path.

    # Arguments
    - `scenePath`: The full path of the scene.

    # Returns
    - `projectPath`: The project path extracted from the scene path.

    """
    function get_project_path_from_full_scene_path(scenePath::String)
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

        if startswith(projectPath, "\\/")
            projectPath = projectPath[2:end]
        end

        return projectPath
    end

    export get_scene_file_name_from_full_scene_path
    """
        get_scene_file_name_from_full_scene_path(scenePath::String)

    Extracts the file name from the given full scene path.

    # Arguments
    - `scenePath`: The full path of the scene.

    # Returns
    - `sceneFileName`: The file name extracted from the scene path.
    """
    function get_scene_file_name_from_full_scene_path(scenePath::String)
        sceneFileName = split(scenePath, "/")[end]
        sceneFileName = split(sceneFileName, "\\")[end]

        return sceneFileName
    end
end
