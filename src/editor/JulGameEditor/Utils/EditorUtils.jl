using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using JulGame


function init_sdl_and_imgui(windowTitle::String)
    if SDL2.SDL_Init(SDL2.SDL_INIT_VIDEO | SDL2.SDL_INIT_TIMER | SDL2.SDL_INIT_GAMECONTROLLER) < 0
        println("failed to init: ", unsafe_string(SDL2.SDL_GetError()));
    end
    SDL2.SDL_SetHint(SDL2.SDL_HINT_IME_SHOW_UI, "1")

    window = SDL2.SDL_CreateWindow(
    windowTitle, SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, 1280, 720,
    SDL2.SDL_WINDOW_SHOWN | SDL2.SDL_WINDOW_RESIZABLE
    )
    if window == C_NULL 
        println("Failed to create window: ", unsafe_string(SDL2.SDL_GetError()))
        return -1
    end

    renderer = SDL2.SDL_CreateRenderer(window, -1, SDL2.SDL_RENDERER_ACCELERATED)
    global sdlRenderer = renderer
    if (renderer == C_NULL)
        @error "Failed to create renderer: $(unsafe_string(SDL2.SDL_GetError()))"
    end

    ver = pointer(SDL2.SDL_version[SDL2.SDL_version(0,0,0)])
    SDL2.SDL_GetVersion(ver)
    global sdlVersion = string(unsafe_load(ver).major, ".", unsafe_load(ver).minor, ".", unsafe_load(ver).patch)
    @debug "SDL version: $(sdlVersion)"
    sdlVersion = parse(Int32, replace(sdlVersion, "." => ""))

    ctx = CImGui.CreateContext()

    io = CImGui.GetIO()
    io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_DockingEnable #| CImGui.ImGuiConfigFlags_NavEnableKeyboard | CImGui.ImGuiConfigFlags_NavEnableGamepad
    imguiDir = pkgdir(CImGui)
    fonts_dir = joinpath(imguiDir, "fonts")
    fonts = unsafe_load(io.Fonts)

    default_font = CImGui.AddFontDefault(fonts)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Cousine-Regular.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "DroidSans.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Karla-Regular.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "ProggyClean.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "ProggyTiny.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Recursive Mono Casual-Regular.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Recursive Mono Linear-Regular.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Recursive Sans Casual-Regular.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Recursive Sans Linear-Regular.ttf"), 16)
    CImGui.AddFontFromFileTTF(fonts, joinpath(fonts_dir, "Roboto-Medium.ttf"), 16)

    io.BackendPlatformUserData = C_NULL
    ImGui_ImplSDL2_InitForSDLRenderer(window, renderer)
    ImGui_ImplSDLRenderer2_Init(renderer)
    clear_color = Cfloat[0.196, 0.196, 0.196, 1.0]

    return [window, renderer, ctx, io, clear_color]
end

"""
    style_imGui()

Sets up the Dear ImGui style.

"""
function style_imGui() 
    # setup Dear ImGui style #Todo: Make this a setting
    CImGui.StyleColorsDark()
    # CImGui.StyleColorsClassic()
    # CImGui.StyleColorsLight()
end

"""
    poll_events()

Process the events in the SDL event queue and check for a quit event.

# Returns
- `quit::Bool`: Whether a quit event has occurred.

"""
function poll_events()
    event_ref = Ref{SDL2.SDL_Event}()
    quit = false
    while Bool(SDL2.SDL_PollEvent(event_ref))
        evt = event_ref[]
        ImGui_ImplSDL2_ProcessEvent(evt)
        evt_ty = evt.type
        if evt_ty == SDL2.SDL_QUIT
            quit = true
            break
        end
    end

    return quit
end

"""
    start_frame()

This function is responsible for starting a new frame in the editor.
It calls the necessary functions to prepare the ImGui library for rendering.
"""
function start_frame()
    ImGui_ImplSDLRenderer2_NewFrame()
    ImGui_ImplSDL2_NewFrame();
    CImGui.NewFrame()
end


"""
    save_scene_event(entities, uiElements, projectPath::String, sceneName::String)

Save the scene by serializing the entities and text boxes to a file.

# Arguments
- `entities`: The entities to be serialized.
- `uiElements`: The text boxes to be serialized.
- `projectPath`: The path of the project.
- `sceneName`: The name of the scene.

# Returns
- `event`: The event object representing the save scene event.
"""
function save_scene_event(entities, uiElements, camera, projectPath::String, sceneName::String)
    event = @event begin
        SceneWriterModule.serialize_entities(entities, uiElements, camera, projectPath, "$(sceneName)")
    end

    return event
end

"""
    select_project_event(currentSceneMain, scenesLoadedFromFolder)

This function creates an event that allows the user to select a project folder. If `currentSceneMain` is `nothing`, it prompts the user to choose a folder using a dialog box and updates `scenesLoadedFromFolder` with all the scenes found in the selected folder.

# Arguments
- `currentSceneMain`: The current main loop.
- `scenesLoadedFromFolder`: An array to store the scenes loaded from the selected folder.

# Returns
- `event`: The event that triggers the folder selection.

"""
function select_project_event(currentSceneMain, scenesLoadedFromFolder, dialog)
    event = @event begin
        if currentSceneMain === nothing 
            choose_project_filepath() |> (dir) -> (if dir == "" return end; scenesLoadedFromFolder[] = get_all_scenes_from_folder(dir))
        else
            dialog[] = "Select Project"
        end
    end

    return event
end

function select_recent_project_event(currentSceneMain, scenesLoadedFromFolder, dialog, currentSelectedProjectPath)
    event = @argevent (dir) begin
        if dir == "" 
            return 
        end 
        
        # Store the path in a global variable or somewhere it can be accessed in the dialog handler
        JulGame.TEMP_SELECTED_PATH = string(dir)
        
        # Use the dialog approach instead of trying to modify currentSceneMain directly
        if currentSceneMain !== nothing
            dialog[] = "Select Recent Project"
        else
            # If no scene is loaded, we can directly set the path and load scenes
            currentSelectedProjectPath[] = string(dir)
            scenesLoadedFromFolder[] = get_all_scenes_from_folder(string(dir))
            # Update BasePath when directly loading a project
            JulGame.BasePath = string(dir)
            @debug("Base path updated: $(JulGame.BasePath)")
        end
    end

    return event
end

function select_project_dialog(dialog, scenesLoadedFromFolder)
    CImGui.OpenPopup(dialog[])
    result = ""

    if CImGui.BeginPopupModal(dialog[], C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        CImGui.Text("Are you sure you would like to open another project?\nIf you currently have a project open, any unsaved changes will be lost.\n\n")
        CImGui.NewLine()
        if CImGui.Button("OK", (120, 0))
            CImGui.CloseCurrentPopup()
            dialog[] = ""

            result = choose_project_filepath() |> (dir) -> begin
                if dir != ""
                    scenesLoadedFromFolder[] = get_all_scenes_from_folder(dir)
                    # Update BasePath when selecting a project
                    JulGame.BasePath = dir
                    @debug("Base path updated: $(JulGame.BasePath)")
                end
                return dir
            end
        end
        CImGui.SetItemDefaultFocus()
        CImGui.SameLine()
        if CImGui.Button("Cancel",(120, 0))
            CImGui.CloseCurrentPopup()
            dialog[] = ""
        end
        CImGui.EndPopup()
    end
    return result
end

function create_project_event(dialog)
    event = @event begin
        dialog[] = "New Project"
    end

    return event
end

function create_project_dialog(dialog, scenesLoadedFromFolder, selectedProjectPath, newProjectText)

    CImGui.OpenPopup(dialog[])

    if CImGui.BeginPopupModal(dialog[], C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        CImGui.Text("Are you sure you would like to open another project?\nIf you currently have a project open, any unsaved changes will be lost.\n\n")
        CImGui.NewLine()
        text = text_input_single_line("Project Name", newProjectText) 
        newProjectText[] = strip(newProjectText[])
        newProjectText[] = replace(newProjectText[], " " => "-")
        newProjectText[] = replace(newProjectText[], "." => "-")
        CImGui.NewLine()

        if CImGui.Button("Select directory", (120, 0))
            selectedProjectPath[] = choose_folder_with_dialog()
        end
        
        CImGui.SameLine()

        newProjectPath = joinpath(selectedProjectPath[], newProjectText[])
        CImGui.Text("Full Path: $(newProjectPath)")
        CImGui.NewLine()

        pathAlreadyExists = isdir(newProjectPath)
        if !pathAlreadyExists && selectedProjectPath[] != "" &&  newProjectText[] != "" && CImGui.Button("Confirm", (120, 0))
            CImGui.CloseCurrentPopup()
            dialog[] = ""

            create_new_project(newProjectPath, newProjectText[])
            scenesLoadedFromFolder[] = get_all_scenes_from_base_folder(joinpath(newProjectPath, newProjectText[]))
            # Update BasePath when creating a new project
            JulGame.BasePath = newProjectPath
            @debug("Base path updated: $(JulGame.BasePath)")
        end

        if pathAlreadyExists
            CImGui.Text("The path already exists. Please choose a different name.")
        end

        CImGui.SetItemDefaultFocus()
        CImGui.SameLine()
        if CImGui.Button("Cancel",(120, 0))
            CImGui.CloseCurrentPopup()
            dialog[] = ""
        end
        CImGui.EndPopup()
    end
    return ""
end

function create_new_project(newProjectPath, newProjectName)
    # create the project folder
    if !isdir(newProjectPath)
        mkdir(newProjectPath)
    end

    # add the julia .gitignore file
    gitignore = joinpath(newProjectPath, ".gitignore")
    touch(gitignore)
    file = open(gitignore, "w")
        println(file, gitIgnoreFileContent)
    close(file)

    # create a readme file
    readme = joinpath(newProjectPath, "README.md")
    touch(readme)
    file = open(readme, "w")
        println(file, readMeFileContent(newProjectName))
    close(file)

    # create the inner project folder (same name as the project)
    projectFolder = joinpath(newProjectPath, newProjectName)
    mkdir(projectFolder)
    if !isdir(projectFolder)
        mkdir(projectFolder)
    end

    # create assets folder. Inside of the assets folder, we also create folders for fonts, images, and sounds
    mkdir(joinpath(projectFolder, "assets"))
    mkdir(joinpath(projectFolder, "assets", "fonts"))
    mkdir(joinpath(projectFolder, "assets", "images"))
    mkdir(joinpath(projectFolder, "assets", "sounds"))

    # Insert the default font into the fonts folder
    cp(joinpath(pwd(), "..", "fonts", "FiraCode-Regular.ttf"), joinpath(projectFolder, "assets", "fonts", "FiraCode-Regular.ttf"))

    # Insert the button up and button down images into the images folder
    cp(joinpath(pwd(), "..", "images", "ButtonUp.png"), joinpath(projectFolder, "assets", "images", "ButtonUp.png"))
    cp(joinpath(pwd(), "..", "images", "ButtonDown.png"), joinpath(projectFolder, "assets", "images", "ButtonDown.png"))

    # create the scenes folder
    scenesFolder = joinpath(projectFolder, "scenes")
    mkdir(scenesFolder)

    #create default scene
    defaultScene = joinpath(scenesFolder, "scene.json")
    touch(defaultScene)
    file = open(defaultScene, "w")
        println(file, sceneJsonContents)
    close(file)

    # create the scripts folder
    scriptsFolder = joinpath(projectFolder, "scripts")
    mkdir(scriptsFolder)

    # create the src folder
    srcFolder = joinpath(projectFolder, "src")
    mkdir(srcFolder)

    # create the src files, one named after the project, and one named Run.jl
    srcFile = joinpath(srcFolder, "$(newProjectName).jl")
    touch(srcFile)
    file = open(srcFile, "w")
        println(file, mainFileContent(newProjectName))
    close(file)

    runFile = joinpath(srcFolder, "Run.jl")
    touch(runFile)
    file = open(runFile, "w")
        println(file, runFileContent(newProjectName))
    close(file)

    # create precompile_app.jl
    precompileFile = joinpath(srcFolder, "..", "precompile_app.jl")
    touch(precompileFile)
    file = open(precompileFile, "w")
        println(file, precompileFileContent(newProjectName))
    close(file)

    # create the project.toml file
    projectToml = joinpath(projectFolder, "Project.toml")
    touch(projectToml)
    file = open(projectToml, "w")
        println(file, projectTomlContent(newProjectName))
    close(file)

    #create the config.julgame file
    configJulgame = joinpath(projectFolder, "config.julgame")
    touch(configJulgame)
    file = open(configJulgame, "w")
        println(file, config_file_content(newProjectName))
    close(file)
end

function move_entities(entities, origin, destination)
    if indexin([destination], origin) != [nothing]
        return
    end

    destinationEntities = entities[destination]
    originEntities = []
    # sort the origin indices in descending order so that we can remove them from the entities list without affecting the destination index
    sort!(origin, rev=true)
    for index in origin
        push!(originEntities, splice!(entities, index))
    end
    # reverse the origin entities so that they are in the correct order
    reverse!(originEntities)
    # must be done after the origin entities are removed because the destination index is based on the original list of entities
    destinationIndex = indexin([destinationEntities], entities)[1]

    for originEntity in originEntities
        originEntity.parent = C_NULL
    end
    updatedEntities = [entities[destinationIndex], originEntities...]
    
    splice!(entities, destinationIndex : destinationIndex, updatedEntities)
end

function log_exceptions(error_type, latest_exceptions, e, top_backtrace, is_test_mode)
    #Threads.@spawn begin
        err_str = string(e)
        formatted_err = format_method_error(err_str)  # Format MethodError
        truncated_err = length(formatted_err) > 1500 ? formatted_err[1:1500] * "..." : formatted_err
        
        @error "Error occurred" exception=truncated_err
        Base.show_backtrace(stderr, catch_backtrace())

        push!(latest_exceptions[], [e, String("$(Dates.now())"), top_backtrace])
        if length(latest_exceptions[]) > 20
            deleteat!(latest_exceptions[], 1)
        end
        if is_test_mode
            @warn "Error in renderloop!" exception=formatted_err
        end
   # end
end

function format_method_error(error_msg::String)
    # Match "MethodError(FUNCTION_NAME, (ARGUMENTS))"
    if occursin(r"MethodError\((.+?), \((.+)\)\)", error_msg)
        m = match(r"MethodError\((.+?), \((.+)\)\)", error_msg)
        func_name = m[1]
        args = m[2]

        # Replace long argument details with "..."
        args = replace(args, r"\(.+?\)" => "(...)")
        args = replace(args, r"\[.+?\]" => "[...]")

        return "MethodError($func_name, ($args))"
    end
    return error_msg  # Return original if it doesn't match
end

function handle_drag_and_drop(filteredEntities, n, currentSceneMain, hierarchyEntitySelections, hasParent = false)
    selections = []
    for index in eachindex(hierarchyEntitySelections)
        if hierarchyEntitySelections[index][2]
            push!(selections, index)
        end
    end

    # our entities are both drag sources and drag targets here!
    if CImGui.BeginDragDropSource(CImGui.ImGuiDragDropFlags_None)
        @c CImGui.SetDragDropPayload("Entity", &n, sizeof(Cint)) # set payload to carry the index of our item (could be anything)
        if length(selections) > 1
            CImGui.Text("Move $(length(selections)) entities")
        else
            CImGui.Text("Move $(filteredEntities[n].name)")
        end
        CImGui.EndDragDropSource()
    end
    # Parent entities by dragging one on top of the other
    if CImGui.BeginDragDropTarget()
        payload = CImGui.AcceptDragDropPayload("Entity")
        if payload != C_NULL
            payload = unsafe_load(payload)
            origin = length(selections) > 1 ? selections : [unsafe_load(Ptr{Cint}(payload.Data))]
            destination = n

            for origin in origin
                if !hasDropConflict(filteredEntities, origin, destination) && filteredEntities[origin].parent != filteredEntities[destination] && filteredEntities[origin] != filteredEntities[destination]
                    @debug "Moving entity $(filteredEntities[origin].name) to $(filteredEntities[destination].name)"
                    filteredEntities[origin].parent = filteredEntities[destination]
                end
            end
            @assert payload.DataSize == sizeof(Cint)
        end
        CImGui.EndDragDropTarget()
    end

    # Reorder entities: We can only reorder entities if the entities are not being filtered
    if length(filteredEntities) == length(currentSceneMain.scene.entities) && !hasParent
        CImGui.InvisibleButton("str_id: $(n)", ImVec2(500,3)) #Todo: Make this dynamic based on window size
        if CImGui.BeginDragDropTarget()
            payload = CImGui.AcceptDragDropPayload("Entity") 
            if payload != C_NULL
                payload = unsafe_load(payload)
                @assert payload.DataSize == sizeof(Cint)
                origin = length(selections) > 1 ? selections : [unsafe_load(Ptr{Cint}(payload.Data))]
                
                destination = n
                # Move the entity(origin) to the position after the entity at the destination index and adust the other entities accordingly. Use splicing to do this.
                move_entities(currentSceneMain.scene.entities, origin, destination)
            end
            CImGui.EndDragDropTarget()
        end
    end
end

function hasDropConflict(filteredEntities, origin, destination)
    # If the entity we are dragging's target is it's own child, we can't move it
    if filteredEntities[destination].parent == filteredEntities[origin]
        @warn "Cannot move entity $(filteredEntities[origin].name) because it the parent of $(filteredEntities[destination].name)"
        return true
    end
    # if it is a grandchild, great grandchild, etc, we need to move all the way up the chain to check if we can move it 
    parent = filteredEntities[destination].parent
    while parent != C_NULL
        if parent == filteredEntities[origin]
            @warn "Cannot move entity $(filteredEntities[origin].name) because it is a forefather of $(filteredEntities[destination].name)"
            return true
        end
        parent = parent.parent
    end

    return false
end

function handle_childless_entity_selection(entity, hierarchyEntitySelections, entityIndex, currentSceneMain, delete_confirmation_modal, filteredEntities = nothing, hasParent = false)
    CImGui.PushID(entity.id)
    if CImGui.Selectable(entity.name, hierarchyEntitySelections[entityIndex][2])
        # clear selection when CTRL is not held
        (!unsafe_load(CImGui.GetIO().KeyCtrl) && !unsafe_load(CImGui.GetIO().KeyShift)) && deselect_all_entities(hierarchyEntitySelections)
        hierarchyEntitySelections[entityIndex] = (hierarchyEntitySelections[entityIndex][1], true)
        unsafe_load(CImGui.GetIO().KeyShift) && select_all_elements_in_between(hierarchyEntitySelections, entityIndex)
        currentSceneMain.selectedEntity = entity
    end
    
    # Handle right-click context menu
    if hierarchyEntitySelections[entityIndex][2]
        show_entity_context_menu(currentSceneMain, hierarchyEntitySelections, delete_confirmation_modal)
    end
    
    if filteredEntities !== nothing 
        # Use the provided entityIndex directly since we now calculate it correctly
        handle_drag_and_drop(filteredEntities, entityIndex, currentSceneMain, hierarchyEntitySelections, hasParent)
    end 

    CImGui.PopID()
end

function handle_parent_entity_selection(entity, children, hierarchyEntitySelections, n, currentSceneMain, filteredEntities, delete_confirmation_modal, ui_delete_confirmation_modal)
    # First create the tree node
    treeNodeOpen = CImGui.TreeNodeEx(entity.name, CImGui.ImGuiTreeNodeFlags_None)
    
    # Handle selection similar to childless entities
    if CImGui.IsItemClicked() && !CImGui.IsItemToggledOpen()
        # clear selection when CTRL is not held
        (!unsafe_load(CImGui.GetIO().KeyCtrl) && !unsafe_load(CImGui.GetIO().KeyShift)) && deselect_all_entities(hierarchyEntitySelections)
        hierarchyEntitySelections[n] = (hierarchyEntitySelections[n][1], true)
        unsafe_load(CImGui.GetIO().KeyShift) && select_all_elements_in_between(hierarchyEntitySelections, n)
        currentSceneMain.selectedEntity = entity
    end
    
    # Handle right-click context menu
    if hierarchyEntitySelections[n][2]
        show_entity_context_menu(currentSceneMain, hierarchyEntitySelections, delete_confirmation_modal)
    end
    
    # Make it a drag source
    if CImGui.BeginDragDropSource(CImGui.ImGuiDragDropFlags_None)
        @c CImGui.SetDragDropPayload("Entity", &n, sizeof(Cint))
        CImGui.Text("Move $(entity.name)")
        CImGui.EndDragDropSource()
    end
    
    # Make it a drop target
    
    if CImGui.BeginDragDropTarget()
        payload = CImGui.AcceptDragDropPayload("Entity")
        if payload != C_NULL
            payload = unsafe_load(payload)
            @assert payload.DataSize == sizeof(Cint)
            
            origin = unsafe_load(Ptr{Cint}(payload.Data))
            if !hasDropConflict(filteredEntities, origin, n) && filteredEntities[origin].parent != entity && filteredEntities[origin] != entity
                @debug "Moving entity $(filteredEntities[origin].name) to $(entity.name)"
                # Set the parent of the dragged entity to this entity
                filteredEntities[origin].parent = entity
            end
            CImGui.EndDragDropTarget()
        end
    end
    
    # If the tree node is open, show its children
    if treeNodeOpen
        for child in children
            # Find the correct index for this child in the filteredEntities list
            childIndex = findfirst(e -> e === child, filteredEntities)
            if childIndex !== nothing
                # Check if this child has its own children
                childChildren = filter(e -> e.parent === child, filteredEntities)
                
                if isempty(childChildren)
                    # Regular child with no children of its own
                    handle_childless_entity_selection(child, hierarchyEntitySelections, childIndex, currentSceneMain, delete_confirmation_modal, filteredEntities, true)
                else
                    # Child has its own children - recursively handle it as a parent
                    handle_parent_entity_selection(child, childChildren, hierarchyEntitySelections, childIndex, currentSceneMain, filteredEntities, delete_confirmation_modal, ui_delete_confirmation_modal)
                end
            end
        end
        CImGui.TreePop()
    end
end

function deselect_all_entities(hierarchyEntitySelections)
    for index in eachindex(hierarchyEntitySelections)
        hierarchyEntitySelections[index] = (hierarchyEntitySelections[index][1], false)
    end
end

function select_all_elements_in_between(hierarchyEntitySelections, lastSelectedIndex)
    start = 0
    for i in 1:lastSelectedIndex
        if hierarchyEntitySelections[i][2] == true && i != lastSelectedIndex
            start = i
            break
        end
    end
    if start != 0
        for i in start:lastSelectedIndex
            hierarchyEntitySelections[i] = (hierarchyEntitySelections[i][1], true)
            if i == lastSelectedIndex
                return
            end
        end
    end

    for i in length(hierarchyEntitySelections):-1:lastSelectedIndex
        if hierarchyEntitySelections[i][2] == true && i != lastSelectedIndex
            start = i
            break
        end
    end

    if start != 0
        for i in start:-1:lastSelectedIndex
            hierarchyEntitySelections[i] = (hierarchyEntitySelections[i][1], true)
        end
    end
end

function regenerate_ids_event(main)
    event = @event begin
        for index in eachindex(main.scene.entities)
            main.scene.entities[index].id = JulGame.generate_uuid()
        end
        for index in eachindex(main.scene.uiElements)
            main.scene.uiElements[index].id = JulGame.generate_uuid()
        end
    end

    return event
end

"""
    duplicate_entity(entity)

Creates a duplicate of an entity with a new UUID.

# Arguments
- `entity`: The entity to duplicate

# Returns
- The duplicate entity with a new UUID
"""
function duplicate_entity(entity)
    copy = deepcopy(entity)
    copy.id = JulGame.generate_uuid()
    return copy
end

function reset_camera_event(main)
    event = @event begin
        if main.scene.camera === nothing
            @debug "No camera found in scene when resetting camera"
            return
        end
        main.scene.camera.position = JulGame.Math.Vector3f(0.0, 0.0, 0.0)
    end

    return event
end

function confirmation_dialog(dialog)
    CImGui.OpenPopup(dialog[])

    result = "continue"  # Default return value
    if CImGui.BeginPopupModal(dialog[], C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        CImGui.Text("Are you sure you would like to open this scene?\nIf you currently have a scene open, any unsaved changes will be lost.\n\n")
        #CImGui.Separator()
        CImGui.NewLine()

        # @cstatic dont_ask_me_next_time=false begin
        #     CImGui.PushStyleVar(CImGui.ImGuiStyleVar_FramePadding, (0, 0))
        #     @c CImGui.Checkbox("Don't ask me next time", &dont_ask_me_next_time)
        #     CImGui.PopStyleVar()
        # end

        if CImGui.Button("OK", (120, 0))
            CImGui.CloseCurrentPopup()
            dialog[] = ""

            result = "ok"
        end
        CImGui.SetItemDefaultFocus()
        CImGui.SameLine()
        if CImGui.Button("Cancel",(120, 0))
            CImGui.CloseCurrentPopup()
            dialog[] = ""

            result = "cancel"
        end
        CImGui.EndPopup()

        return result    
    end
end

"""
    show_window_with_error_handling(window_name, content_function, latest_exceptions, is_test_mode)

Shows a window with error handling.

# Arguments
- `window_name`: The name of the window
- `content_function`: The function to call to display the content of the window
- `latest_exceptions`: A reference to a list of latest exceptions
- `is_test_mode`: Whether the function is being called in test mode

# Returns
- `Bool`: Whether the window should be shown again
"""
function show_window_with_error_handling(window_name, content_function, latest_exceptions, is_test_mode)
    # Implementation of the function
    # This is a placeholder and should be replaced with the actual implementation
    return true  # Placeholder return, actual implementation needed
end

"""
    bulk_delete_entities(main, entities_to_delete)

Helper function to safely delete multiple entities at once.

# Arguments
- `main`: The main scene object
- `entities_to_delete`: Array of entities to delete

# Returns
- nothing
"""
function bulk_delete_entities(main, entities_to_delete)
    # Delete entities in reverse order to avoid index issues
    for entity in reverse(entities_to_delete)
        JulGame.destroy_entity(main, entity)
    end
end

"""
    bulk_delete_ui_elements(main, ui_indices_to_delete)

Helper function to safely delete multiple UI elements at once.

# Arguments
- `main`: The main scene object
- `ui_indices_to_delete`: Array of indices of UI elements to delete

# Returns
- nothing
"""
function bulk_delete_ui_elements(main, ui_indices_to_delete)
    # Delete UI elements in reverse order to avoid index issues
    for idx in reverse(ui_indices_to_delete)
        JulGame.destroy_ui_element(main, main.scene.uiElements[idx])
    end
end

"""
    show_entity_context_menu(main, hierarchyEntitySelections, delete_confirmation_modal)

Shows a context menu for one or more selected entities when right-clicked.

# Arguments
- `main`: The main scene object
- `hierarchyEntitySelections`: Array of entity selection tuples (entity, isSelected)
- `delete_confirmation_modal`: Confirmation modal for delete operations

# Returns
- `Bool`: Whether any action was triggered
"""
function show_entity_context_menu(main, hierarchyEntitySelections, delete_confirmation_modal)
    action_taken = false
    
    if CImGui.BeginPopupContextItem("entity_context_menu")
        selected_count = count(es -> es[2], hierarchyEntitySelections)
        
        # Get selected entities
        selected_entities = [entity[1] for entity in hierarchyEntitySelections if entity[2]]
        
        if selected_count > 1
            if CImGui.MenuItem("Delete Selected ($(selected_count))")
                delete_confirmation_modal.open = true
                action_taken = true
            end
            
            if CImGui.MenuItem("Duplicate Selected ($(selected_count))")
                for entity in selected_entities
                    copy = duplicate_entity(entity)
                    push!(main.scene.entities, copy)
                end
                action_taken = true
            end
        else
            entity = main.selectedEntity
            
            if entity !== nothing
                if CImGui.MenuItem("Delete \"$(entity.name)\"")
                    CImGui.OpenPopup("Delete Single Entity")
                    action_taken = true
                end
                
                if CImGui.MenuItem("Duplicate \"$(entity.name)\"")
                    copy = duplicate_entity(entity)
                    push!(main.scene.entities, copy)
                    main.selectedEntity = copy
                    action_taken = true
                end
                
                CImGui.Separator()
                
                if CImGui.MenuItem("Add Component")
                    CImGui.OpenPopup("Add Component")
                    action_taken = true
                end
            end
        end
        
        CImGui.EndPopup()
    end
    
    # Handle the single entity delete confirmation
    if CImGui.BeginPopupModal("Delete Single Entity", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        entity = main.selectedEntity
        if entity !== nothing
            CImGui.Text("Are you sure you want to delete \"$(entity.name)\"?\nThis cannot be undone.\n\n")
            CImGui.NewLine()
            if CImGui.Button("Delete", (120, 0))
                JulGame.destroy_entity(main, entity)
                main.selectedEntity = nothing
                CImGui.CloseCurrentPopup()
            end
            CImGui.SetItemDefaultFocus()
            CImGui.SameLine()
            if CImGui.Button("Cancel",(120, 0))
                CImGui.CloseCurrentPopup()
            end
        end
        CImGui.EndPopup()
    end
    
    return action_taken
end

"""
    show_ui_element_context_menu(main, ui_element_index, ui_delete_confirmation_modal, hierarchyUISelections)

Shows a context menu for one or more selected UI elements when right-clicked.

# Arguments
- `main`: The main scene object
- `ui_element_index`: Index of the current UI element
- `ui_delete_confirmation_modal`: Confirmation modal for delete operations
- `hierarchyUISelections`: Array of booleans for UI element selection status

# Returns
- `Bool`: Whether any action was triggered
"""
function show_ui_element_context_menu(main, ui_element_index, ui_delete_confirmation_modal, hierarchyUISelections)
    action_taken = false
    
    if CImGui.BeginPopupContextItem("ui_element_context_menu")
        selected_count = count(hierarchyUISelections)
        
        if selected_count > 1
            if CImGui.MenuItem("Delete Selected ($(selected_count))")
                ui_delete_confirmation_modal.open = true
                action_taken = true
            end
        else
            # Single UI element selected
            ui_element = main.scene.uiElements[ui_element_index]
            
            if CImGui.MenuItem("Delete \"$(ui_element.name)\"")
                CImGui.OpenPopup("Delete Single UI Element")
                action_taken = true
            end
            
            # Add more UI element-specific actions here
            if contains("$(typeof(ui_element))", "TextBox")
                CImGui.Separator()
                if CImGui.MenuItem("Edit Text")
                    # Add text editing functionality here if needed
                    action_taken = true
                end
            elseif contains("$(typeof(ui_element))", "ScreenButton")
                CImGui.Separator()
                if CImGui.MenuItem("Edit Button Properties")
                    # Add button property editing here if needed
                    action_taken = true
                end
            end
        end
        
        CImGui.EndPopup()
    end
    
    # Handle the single UI element delete confirmation
    if CImGui.BeginPopupModal("Delete Single UI Element", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        ui_element = main.scene.uiElements[ui_element_index]
        CImGui.Text("Are you sure you want to delete \"$(ui_element.name)\"?\nThis cannot be undone.\n\n")
        CImGui.NewLine()
        if CImGui.Button("Delete", (120, 0))
            JulGame.destroy_ui_element(main, ui_element)
            hierarchyUISelections[ui_element_index] = false
            CImGui.CloseCurrentPopup()
        end
        CImGui.SetItemDefaultFocus()
        CImGui.SameLine()
        if CImGui.Button("Cancel",(120, 0))
            CImGui.CloseCurrentPopup()
        end
        CImGui.EndPopup()
    end
    
    return action_taken
end

"""
    show_component_context_menu(entity, component_name)

Shows a context menu for a component when right-clicked.

# Arguments
- `entity`: The entity that owns the component
- `component_name`: The name of the component

# Returns
- `Bool`: Whether any action was triggered
"""
function show_component_context_menu(entity, component_name)
    action_taken = false
    
    if CImGui.BeginPopupContextItem("component_context_menu_$(component_name)")
        if component_name != "Transform" # Transform is required and can't be removed
            if CImGui.MenuItem("Remove Component")
                setfield!(entity, Symbol(lowercase(component_name)), C_NULL)
                action_taken = true
            end
        end
        
        if CImGui.MenuItem("Reset Component")
            # This would reset the component to default values
            # Implementation depends on component type
            action_taken = true
        end
        
        CImGui.EndPopup()
    end
    
    return action_taken
end