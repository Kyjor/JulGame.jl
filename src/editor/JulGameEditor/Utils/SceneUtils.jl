function load_scene(scenePath)
    game = C_NULL
    try
        game = SceneLoaderModule.LoadSceneFromEditor(scenePath);
    catch e
        rethrow(e)
    end

    return game
end

function close_current_scene(game)
    try
        game
    catch e
        rethrow(e)
    end
end

function get_all_scenes_from_folder(projectPath)
    sceneFiles = []
    try
        # search through projectpath and it's subdirectories for a scenes folder. If it exists, return all of the json files from it
        for (root, dirs, files) in walkdir(projectPath)
            if "scenes" in dirs
                for (root, dirs, files) in walkdir(joinpath(root, "scenes"))
                    for file in files
                        # println(file)
                        if occursin(r".json$", file)
                            push!(sceneFiles, joinpath(root, file))
                        end
                    end
                end
            end
        end
    catch e
        rethrow(e)
    end

    return sceneFiles
end

function choose_folder_with_dialog()
    dir = pick_folder()
    # println("open_dialog returned $dir")
    return dir
end