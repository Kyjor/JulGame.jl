"""
    load_scene(scenePath::String)

Load a scene from the specified `scenePath` using the SceneLoaderModule.
Returns the loaded game.

# Arguments
- `scenePath`: The path to the scene file.

"""
function load_scene(scenePath::String)
    game = C_NULL
    try
        game = SceneLoaderModule.load_scene_from_editor(scenePath);
    catch e
        @error "Error loading scene: $(e)"
        Base.show_backtrace(stderr, catch_backtrace())
    end

    return game
end


"""
    get_all_scenes_from_folder(projectPath::String)

Searches through the specified `projectPath` and its subdirectories for a "scenes" folder. If found, it returns a list of all JSON files within that folder.

# Arguments
- `projectPath`: The path to the project directory.

# Returns
An array of file paths to the JSON files found in the "scenes" folder.
"""
function get_all_scenes_from_folder(projectPath::String)
    sceneFiles = []
    try
        # get all files in the scenes folder joinpath(projectPath, "scenes")
        if !isdir(joinpath(projectPath, "scenes"))
            @error "No scenes folder found in project directory: $projectPath"
        else
            for (root, dirs, files) in walkdir(joinpath(projectPath, "scenes"))
                for file in files
                    if occursin(r".json$", file)
                        push!(sceneFiles, joinpath(root, file))
                    end
                end
            end
        end
    catch e
    end

    return sceneFiles
end

function get_all_scenes_from_base_folder(projectPath::String)
    sceneFiles = []
    try
        # search through projectpath and it's subdirectories for a scenes folder. If it exists, return all of the json files from it
        if !isdir(joinpath(projectPath, "scenes"))
            @error "No scenes folder found in project directory: $projectPath"
        else
            for (root, dirs, files) in walkdir(joinpath(projectPath, "scenes"))
                for file in files
                    if occursin(r".json$", file)
                        push!(sceneFiles, joinpath(root, file))
                    end
                end
            end
        end
    catch e
    end

    return sceneFiles
end

"""
    choose_project_filepath()

Opens a dialog box to choose a config.julgame file.
"""
function choose_project_filepath()
    return dirname(pick_file(; filterlist="julgame"))
end

function choose_folder_with_dialog()
    dir = pick_folder()
    # println("open_dialog returned $dir")
    return dir
end

"""
    load_scene(scenePath::String, renderer)

Load a scene from the specified `scenePath` using the given `renderer`.

# Arguments
- `scenePath`: The path to the scene file.
- `renderer`: The renderer to use for loading the scene.

# Returns
The loaded main struct.
"""
function load_scene(scenePath::String, renderer)
    println("Loading scene from $scenePath")
    game = C_NULL
    try
        game = SceneLoaderModule.load_scene_from_editor(scenePath, renderer);
    catch e
        @error "Failed to load scene from $scenePath: $e"
        rethrow(e)
    end

    return game
end

"""
    initialize_project(projectPath::String)

Initialize a project by including its main .jl file and setting up the base path.

# Arguments
- `projectPath`: The path to the project directory.

# Returns
True if successful, false otherwise.
"""
function initialize_project(projectPath::String)
    if projectPath == "" || !isdir(projectPath)
        @error "Invalid project path: $projectPath"
        return false
    end
    
    try
        # Set the base path
        JulGame.BasePath = projectPath
        @debug("Base path set to: $(JulGame.BasePath)")
        
        # Include the project's main .jl file
        project_name = basename(projectPath)
        project_main_file = joinpath(projectPath, "src", "$(project_name).jl")
        
        if isfile(project_main_file)
            println("Including project file: $project_main_file")
            include(project_main_file)
            return true
        else
            @warn "Project main file not found: $project_main_file"
            return false
        end
    catch e
        @error "Error initializing project: $e"
        Base.show_backtrace(stderr, catch_backtrace())
        return false
    end
end

"""
    load_scene_with_project(scenePath::String, renderer, currentSelectedProjectPath, save_last_scene::Bool=true)

Load a scene and ensure its project is initialized. This is the centralized function for loading scenes.

# Arguments
- `scenePath`: The path to the scene file.
- `renderer`: The renderer to use for loading the scene.
- `currentSelectedProjectPath`: Reference to the current project path.
- `save_last_scene`: Whether to save this scene as the last opened scene for the project.

# Returns
A tuple of (currentSceneMain, gameCamera, sceneName) or (nothing, nothing, "") on error.
"""
function load_scene_with_project(scenePath::String, renderer, currentSelectedProjectPath, save_last_scene::Bool=true)
    try
        # Get project path from scene path
        projectPath = SceneLoaderModule.get_project_path_from_full_scene_path(scenePath)
        
        # Initialize project if not already initialized or if project changed
        if currentSelectedProjectPath[] != projectPath
            currentSelectedProjectPath[] = projectPath
            if !initialize_project(projectPath)
                @error "Failed to initialize project: $projectPath"
                return (nothing, nothing, "")
            end
        end
        
        # Ensure project is initialized even if it's the same path (in case it wasn't loaded yet)
        if JulGame.BasePath == "" || JulGame.BasePath != projectPath
            initialize_project(projectPath)
        end
        
        # Set editor mode
        JulGame.IS_EDITOR = true
        
        # Load the scene
        currentSceneMain = load_scene(scenePath, renderer)
        
        if currentSceneMain === nothing || currentSceneMain isa Ptr
            @error "Failed to load scene: $scenePath"
            return (nothing, nothing, "")
        end
        
        # Get the camera
        gameCamera = currentSceneMain.scene.camera
        
        # Get scene name
        sceneName = SceneLoaderModule.get_scene_file_name_from_full_scene_path(scenePath)
        
        # Save last scene if requested
        if save_last_scene && projectPath != ""
            save_last_scene_for_project(projectPath, sceneName)
        end
        
        println("✓ Successfully loaded scene: $sceneName")
        JulGame.engine_states.current_state = :game_mode
        return (currentSceneMain, gameCamera, sceneName)
        
    catch e
        @error "Error in load_scene_with_project: $e"
        Base.show_backtrace(stderr, catch_backtrace())
        return (nothing, nothing, "")
    end
end