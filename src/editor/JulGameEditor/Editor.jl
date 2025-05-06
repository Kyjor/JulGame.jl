# Reference: https://github.com/ocornut/imgui/tree/master/examples/example_sdl2_sdlrenderer2

module Editor
    using CImGui
    using CImGui.CSyntax
    using CImGui.CSyntax.CStatic
    using CImGui: ImVec2, ImVec4, IM_COL32, ImS32, ImU32, ImS64, ImU64
    using CImGui.CImGui
    using Dates
    using JulGame: Component, MainLoopModule, Math, SceneLoaderModule, SDL2, UI
    using NativeFileDialog
    
    # Editor configuration
    const AUTO_LOAD_LAST_PROJECT = true  # Set to false to disable auto-loading the last project
    
    global sdlVersion = "2.0.0"
    global sdlRenderer = C_NULL
    global const BackendPlatformUserData = Ref{Any}(C_NULL)

    include(joinpath("..","..","utils","Macros.jl"))

    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "ImGuiSDLBackend"); join=true)))
    
    # Components includes (contains the ConfirmationModal used for all confirmation dialogs)
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Components"); join=true)))
    
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Utils"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Windows"); join=true)))
    
    # Include editor scripts
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "EditorScripts"); join=true)))
    
    if get(ENV, "PRECOMPILE", "false") == "true"
        include("src/additional_precompile.jl")
    end
    
    # Import modules we need
    using .CodeEditorModule

    function run(is_test_mode::Bool=false)
        isPackageCompiled = ccall(:jl_generating_output, Cint, ()) == 1
        windowTitle = "JulGame Editor v0.1.0"

        info = init_sdl_and_imgui(windowTitle)
        window, renderer, ctx, io, clear_color = info[1], info[2], info[3], info[4], info[5]
        startingSize = ImVec2(1920, 1080)
        sceneTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, startingSize.x, startingSize.y)# SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
        gameTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, 200, 200)# SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
        sceneTextureSize = ImVec2(startingSize.x, startingSize.y)
        gameTextureSize = ImVec2(200, 200)

        ##coroutine
        watch_task = nothing
        condition = nothing 
        filesToReload = Ref([])
        
        style_imGui()
        showDemoWindow = false
        ##############################
        # Project variables
        currentSceneMain = nothing
        currentSceneName = ""
        currentScenePath = ""
        currentSelectedProjectPath = Ref("")
        gameInfo = []
        ##############################
        # Hierarchy variables
        filteredEntities = Entity[]
        hierarchyFilterText = Ref("")
        hierarchyEntitySelections = []
        hierarchyUISelections = Bool[]
        ##############################
        scenesLoadedFromFolder = Ref(String[])
        latest_exceptions = Ref([])

        sceneWindowPos = ImVec2(0, 0)
        sceneWindowSize = ImVec2(startingSize.x, startingSize.y)
        gameWindowSize = ImVec2(startingSize.x, startingSize.y)
        testFrameCount = 0
        testFrameLimit = 100
        quit = false

        scrolling = Ref(ImVec2(0.0, 0.0))
        zoom_level = Ref(1.0)

        animation_window_dict = Ref(Dict())
        animator_preview_dict = Ref(Dict())

        save_file_timer = 0

        duplicationMode = false

        # Engine Timing
        startTime = Ref(UInt64(0))
        lastPhysicsTime = Ref(UInt64(SDL2.SDL_GetTicks()))

        # Dialogs
        currentDialog::Base.RefValue{String} = Ref("")
        newSceneText = Ref("")
        newProjectText = Ref("")
        newScriptText = Ref("")

        panOffset = Math.Vector2(0, 0)
        camera = JulGame.CameraModule.Camera(Vector2(500,500), Vector3f(),Vector2f(), C_NULL)
        gameCamera = JulGame.CameraModule.Camera(Vector2(500,500), Vector3f(),Vector2f(), C_NULL)
        confirmation_modal = ConfirmationModal("Start/Stop Game"; message="Are you sure you want to start/stop the game? Any unsaved progress will be lost.", confirmText="Yes", cancelText="No", open=false, type="Warning")
        delete_confirmation_modal = ConfirmationModal("Delete Entities"; message="Are you sure you want to delete the selected entities? This cannot be undone.", confirmText="Delete", cancelText="Cancel", open=false, type="Warning")
        ui_delete_confirmation_modal = ConfirmationModal("Delete UI Elements"; message="Are you sure you want to delete the selected UI elements? This cannot be undone.", confirmText="Delete", cancelText="Cancel", open=false, type="Warning")
        cameraWindow = CameraWindow(true, gameCamera)
        currentProjectConfig = (
            Width=Ref(Math.TypeConversions.safe_int32_convert(800)), 
            Height=Ref(Math.TypeConversions.safe_int32_convert(600)), 
            FrameRate=Ref(Math.TypeConversions.safe_int32_convert(30)), 
            IsResizable=Ref(Bool(0)), 
            Fullscreen=Ref(Bool(0))
        )

        recent_projects = parse_recents()
        
        auto_load_notification = false
        auto_load_notification_time = 0.0
        
        # Variable to track if we want to show backup scenes
        show_backup_scenes = Ref(false)
        
        # Variable to track if file explorer window is open
        show_file_explorer = Ref(true)
        
        # Auto-load the most recent project if there is one
        if !is_test_mode && AUTO_LOAD_LAST_PROJECT
            most_recent_project = get_most_recent_project()
            if most_recent_project != "" && isdir(most_recent_project)
                currentSelectedProjectPath[] = most_recent_project
                scenesLoadedFromFolder[] = get_all_scenes_from_folder(string(most_recent_project))
                JulGame.BasePath = most_recent_project
                @debug("Base path: $(JulGame.BasePath)")
                # Update window title
                SDL2.SDL_SetWindowTitle(window, "$(windowTitle) - $(most_recent_project)")
                # Show notification
                auto_load_notification = true
                auto_load_notification_time = 5.0  # Show for 5 seconds
                condition, watch_task = start_file_watcher(string(most_recent_project), filesToReload)
            end
        end

        try
            while !quit                   
                current_path = currentSelectedProjectPath[] 
                try
                    if currentSceneMain === nothing
                        quit = poll_events()
                    else 
                        if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LEFT")
                            panOffset = Math.Vector2(panOffset.x + 1, panOffset.y)
                        elseif JulGame.InputModule.get_button_held_down(currentSceneMain.input, "RIGHT")
                            panOffset = Math.Vector2(panOffset.x - 1, panOffset.y)
                        elseif JulGame.InputModule.get_button_held_down(currentSceneMain.input, "UP")
                            panOffset = Math.Vector2(panOffset.x, panOffset.y + 1)
                        elseif JulGame.InputModule.get_button_held_down(currentSceneMain.input, "DOWN")
                            panOffset = Math.Vector2(panOffset.x, panOffset.y - 1)
                        end
                    end   
                    start_frame()
                    
                    # When in play mode, apply a slight reddish tint to the menu bar
                    if JulGame.IS_EDITOR_PLAY_MODE
                        CImGui.PushStyleColor(CImGui.ImGuiCol_MenuBarBg, (0.5, 0.1, 0.1, 1.0))
                    end
                    
                    CImGui.igDockSpaceOverViewport(C_NULL, C_NULL, CImGui.ImGuiDockNodeFlags_PassthruCentralNode, C_NULL) # Creating the "dockspace" that covers the whole window. This allows the child windows to automatically resize.
                    
                    ################################## RENDER HERE
                    
                    ################################# MAIN MENU BAR
                    events = Dict{String, Function}()
                    if currentSceneMain !== nothing
                        events["Save"] = save_scene_event(currentSceneMain.scene.entities, currentSceneMain.scene.uiElements, gameCamera, currentSelectedProjectPath[], String(currentSceneName))
                    end
                    events["New-project"] = create_project_event(currentDialog)
                    events["Select-project"] = select_project_event(currentSceneMain, scenesLoadedFromFolder, currentDialog)
                    events["Select-recent-project"] = select_recent_project_event(currentSceneMain, scenesLoadedFromFolder, currentDialog, currentSelectedProjectPath)
                    events["Reset-camera"] = reset_camera_event(currentSceneMain)
                    events["Regenerate-ids"] = regenerate_ids_event(currentSceneMain)
                    events["New-Scene"] = @event begin
                        currentDialog[] = "New Scene"
                    end
                    events["Play-Mode"] = @event begin confirmation_modal.open = true; end
                    
                    # Code editor events
                    events["Open-code-editor"] = @event begin
                        CodeEditorModule.open_file_dialog()
                    end
                    
                    events["Open-script"] = @event begin
                        CodeEditorModule.open_file_dialog()
                    end
                    
                    events["Toggle-File-Explorer"] = @event begin
                        show_file_explorer[] = !show_file_explorer[]
                    end
                    
                    show_main_menu_bar(events, currentSceneMain, recent_projects)
                    ################################# END MAIN MENU BAR
                    if !isPackageCompiled
                        #@c CImGui.ShowDemoWindow(Ref{Bool}(showDemoWindow)) # Uncomment this line to show the demo window and see available widgets
                    end

                    # Show the code editor window if it's open
                    CodeEditorModule.show_code_editor()

                    # Show the file explorer window if it's open
                    FileExplorerWindow.show_window(show_file_explorer)

                    try 
                        @cstatic begin
                            #region Scene List
                            CImGui.Begin("Scene List") 
                            show_help_marker("This is where we will display our scenes. Scenes are where the gameplay happens.")

                            # Add a "New Scene" button at the top of the Scene List
                            if currentSelectedProjectPath[] != ""
                                CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.6, 0.2, 1.0))
                                CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.7, 0.3, 1.0))
                                CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.8, 0.4, 1.0))
                                
                                if CImGui.Button("+ Create New Scene")
                                    currentDialog[] = "New Scene"
                                end
                                
                                CImGui.PopStyleColor(3)
                                CImGui.Separator()
                                
                                # Add checkbox to toggle showing backup scenes
                                CImGui.Checkbox("Show Backups", show_backup_scenes)
                                if CImGui.IsItemHovered()
                                    CImGui.SetTooltip("Toggle to show/hide scenes with '-backup' in the name")
                                end
                                CImGui.Separator()
                            end

                            for scene in scenesLoadedFromFolder[]
                                name = SceneLoaderModule.get_scene_file_name_from_full_scene_path(scene)
                                
                                # Skip backup scenes unless show_backup_scenes is true
                                if !show_backup_scenes[] && occursin("-backup", name)
                                    continue
                                end
                                
                                # Add visual indicator for backup scenes
                                if occursin("-backup", name)
                                    CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.6, 0.4, 0.1, 1.0))  # Amber color for backups
                                    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.7, 0.5, 0.2, 1.0))
                                    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.8, 0.6, 0.3, 1.0))
                                end
                                
                                # Prepare button text with optional backup indicator
                                buttonText = occursin("-backup", name) ? 
                                    "[BACKUP] $(SubString(split(split(scene, "scenes")[2], ".")[1], 2))" : 
                                    "$(SubString(split(split(scene, "scenes")[2], ".")[1], 2))"
                                
                                if CImGui.Button(buttonText)
                                    currentSceneName = name
                                    currentScenePath = scene
                                    if currentSceneMain === nothing
                                        JulGame.IS_EDITOR = true
                                        JulGame.PIXELS_PER_UNIT = 16
                                        currentDialog[] = "Open Scene"
                                        currentSelectedProjectPath[] = SceneLoaderModule.get_project_path_from_full_scene_path(scene) 
                                        currentProjectConfig = load_project_config(currentSelectedProjectPath)
                                    else
                                        currentDialog[] = "Open Scene"
                                    end
                                end
                                
                                # Pop colors if this was a backup scene
                                if occursin("-backup", name)
                                    CImGui.PopStyleColor(3)
                                end
                                
                                CImGui.NewLine()
                            end

                            CImGui.End()
                        end
                    catch e
                        handle_editor_exceptions("Scene list:", latest_exceptions, e, is_test_mode)
                    end
                    
                    try 
                        if !JulGame.IS_EDITOR_PLAY_MODE && currentSelectedProjectPath[] != "" && unsafe_string(SDL2.SDL_GetWindowTitle(window)) != "$(windowTitle) - $(currentSelectedProjectPath[])"
                            newWindowTitle = "$(windowTitle) - $(currentSelectedProjectPath[])"
                            SDL2.SDL_SetWindowTitle(window, newWindowTitle)
                        end
                    catch e
                        handle_editor_exceptions("Window renaming:", latest_exceptions, e, is_test_mode)
                    end
                    
                    try
                        if currentDialog[] == "Open Scene"
                            #println("Opening scene: $(currentDialog[][2])")
                            if confirmation_dialog(currentDialog) == "ok" && currentSceneName != ""
                                if currentSceneMain === nothing
                                    try
                                        currentSceneMain = load_scene(currentScenePath, renderer)
                                    catch e
                                        @error "Error loading scene: $(e)"
                                    end
                                else
                                    try
                                        JulGame.change_scene(String(currentSceneName))
                                    catch e
                                        @error "Error changing scene: $(e)"
                                    end
                                end
                                if currentSceneMain !== nothing && !(currentSceneMain isa Ptr)
                                    gameCamera = currentSceneMain.scene.camera
                                    cameraWindow.camera = gameCamera
                                else 
                                    currentSceneMain = nothing
                                    @error "Main not loaded properly"
                                end
                            end
                        elseif currentDialog[] == "New Scene"
                            newSceneName = new_scene_dialog(currentDialog, newSceneText)
                            if newSceneName != ""
                                currentSceneName = newSceneName
                                
                                # Ensure scenes folder exists
                                scenesDir = joinpath(currentSelectedProjectPath[], "scenes")
                                isdir(scenesDir) || mkdir(scenesDir)
                                
                                currentScenePath = joinpath(scenesDir, "$(newSceneName).json")
                                touch(currentScenePath)
                                file = open(currentScenePath, "w")
                                    println(file, sceneJsonContents)
                                close(file)
                                
                                # Check if we need to load the scene or just create it
                                if currentSceneMain === nothing
                                    JulGame.IS_EDITOR = true
                                    JulGame.PIXELS_PER_UNIT = 16
                                    currentSceneMain = load_scene(currentScenePath, renderer)
                                    
                                    if currentSceneMain !== nothing && !(currentSceneMain isa Ptr)
                                        gameCamera = currentSceneMain.scene.camera
                                        cameraWindow.camera = gameCamera
                                    else 
                                        currentSceneMain = nothing
                                        @error "Main not loaded properly"
                                    end
                                else
                                    JulGame.change_scene("$(String(currentSceneName)).json")
                                end
                                
                                scenesLoadedFromFolder[] = get_all_scenes_from_folder(currentSelectedProjectPath[])
                            end
                        elseif currentDialog[] == "Select Project"
                            selectedProjectPath = select_project_dialog(currentDialog, scenesLoadedFromFolder)
                            if selectedProjectPath != ""
                                currentSceneMain = nothing
                            end
                        elseif currentDialog[] == "Select Recent Project"
                            # Dialog for handling recent project selection when a scene is already loaded
                            CImGui.OpenPopup(currentDialog[])
                            if CImGui.BeginPopupModal(currentDialog[], C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                                CImGui.Text("Are you sure you would like to open another project?\nIf you currently have a project open, any unsaved changes will be lost.\n\n")
                                CImGui.NewLine()
                                if CImGui.Button("OK", (120, 0))
                                    CImGui.CloseCurrentPopup()
                                    currentDialog[] = ""
                                    
                                    # Reset the current scene before loading the new project
                                    currentSceneMain = nothing
                                    currentSelectedProjectPath[] = JulGame.TEMP_SELECTED_PATH
                                    scenesLoadedFromFolder[] = get_all_scenes_from_folder(currentSelectedProjectPath[])
                                    # Update BasePath when selecting a recent project
                                    JulGame.BasePath = currentSelectedProjectPath[]
                                    @debug("Base path updated: $(JulGame.BasePath)")
                                end
                                CImGui.SetItemDefaultFocus()
                                CImGui.SameLine()
                                if CImGui.Button("Cancel",(120, 0))
                                    CImGui.CloseCurrentPopup()
                                    currentDialog[] = ""
                                end
                                CImGui.EndPopup()
                            end
                        elseif currentDialog[] == "New Project"
                            selectedProjectPath = create_project_dialog(currentDialog, scenesLoadedFromFolder, currentSelectedProjectPath, newProjectText)
                            if selectedProjectPath != ""
                                println("Selected project path: $(selectedProjectPath)")
                            end
                        end
                    catch e
                        handle_editor_exceptions("Dialogs handler:", latest_exceptions, e, is_test_mode)
                    end
                    uiSelected = false
                
                    try
                        if sceneWindowSize !== nothing && sceneTextureSize !== nothing && sceneWindowSize.x != sceneTextureSize.x || sceneWindowSize.y != sceneTextureSize.y
                            SDL2.SDL_DestroyTexture(sceneTexture)
                            sceneTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, sceneWindowSize.x, sceneWindowSize.y)
                            sceneTextureSize = ImVec2(sceneWindowSize.x, sceneWindowSize.y)
                        end
                    catch e
                        handle_editor_exceptions("Scene window resizing:", latest_exceptions, e, is_test_mode)
                    end
                    
                    try
                        if gameCamera !== nothing && gameTextureSize !== nothing && gameCamera.size.x != gameTextureSize.x || gameCamera.size.y != gameTextureSize.y
                            SDL2.SDL_DestroyTexture(gameTexture)
                            gameTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, gameCamera.size.x, gameCamera.size.y)
                            gameTextureSize = ImVec2(gameCamera.size.x, gameCamera.size.y)
                        end
                    catch e
                        handle_editor_exceptions("Game window resizing:", latest_exceptions, e, is_test_mode)
                    end
                    
                    try
                        prevSceneWindowSize = sceneWindowSize
                        
                        wasPlaying = JulGame.IS_EDITOR_PLAY_MODE
                        if show_modal(confirmation_modal)
                            JulGame.IS_EDITOR_PLAY_MODE = !JulGame.IS_EDITOR_PLAY_MODE
                            if JulGame.IS_EDITOR_PLAY_MODE
                                startTime[] = SDL2.SDL_GetTicks()
                                 
                                # Animate the text in the window title
                                SDL2.SDL_SetWindowTitle(window, "PLAYING $(windowTitle) - $(currentSelectedProjectPath[])")
                            else
                                # Reset the window title when exiting play mode
                                SDL2.SDL_SetWindowTitle(window, "$(windowTitle) - $(currentSelectedProjectPath[])")
                            end
                        end
                        
                        # Handle bulk delete confirmation
                        if show_modal(delete_confirmation_modal)
                            # Get all selected entities
                            entities_to_delete = [entity[1] for entity in hierarchyEntitySelections if entity[2]]
                            
                            # Delete entities using our helper function
                            bulk_delete_entities(currentSceneMain, entities_to_delete)
                            
                            # Reset selections
                            hierarchyEntitySelections = []
                            currentSceneMain.selectedEntity = nothing
                        end
                        
                        # Handle UI elements bulk delete confirmation
                        if show_modal(ui_delete_confirmation_modal)
                            # Get all selected UI element indices
                            ui_indices_to_delete = findall(hierarchyUISelections)
                            
                            # Delete UI elements using our helper function
                            bulk_delete_ui_elements(currentSceneMain, ui_indices_to_delete)
                            
                            # Reset selections
                            hierarchyUISelections = fill(false, length(currentSceneMain.scene.uiElements))
                        end
                        
                        sceneWindowSize = show_scene_window(currentSceneMain, sceneTexture, scrolling, zoom_level, duplicationMode, camera)
                        if JulGame.IS_EDITOR_PLAY_MODE != wasPlaying && currentSceneMain !== nothing
                            if JulGame.IS_EDITOR_PLAY_MODE
                                JulGame.MainLoopModule.start_game_in_editor(currentSceneMain, currentSelectedProjectPath[])
                                currentSceneMain.scene.camera = gameCamera 
                            elseif !JulGame.IS_EDITOR_PLAY_MODE
                                JulGame.MainLoopModule.stop_game_in_editor(currentSceneMain)
                                JulGame.change_scene(String(currentSceneName))
                            end
                        end
                        
                        prevGameWindowSize = gameWindowSize
                        gameWindowSize, gameWindowTopLeftCornerPosition = show_game_window(gameTexture)

                        if gameWindowSize === nothing
                            gameWindowSize = prevGameWindowSize
                        end
                        if sceneWindowSize === nothing
                            sceneWindowSize = prevSceneWindowSize
                        end
                        if gameWindowTopLeftCornerPosition !== nothing && currentSceneMain !== nothing
                            currentSceneMain.input.mousePositionEditorGameWindowOffset = Math.Vector2(gameWindowTopLeftCornerPosition.x, gameWindowTopLeftCornerPosition.y)
                        end
                    catch e
                        handle_editor_exceptions("Show modal/scene window:", latest_exceptions, e, is_test_mode)
                    end
                    
                    try
                        #region Hierarchy
                        CImGui.Begin("Hierarchy") 
                        
                        show_help_marker("This is where we will display a list of entities and textboxes for the scene")
                        currentSceneMain === nothing && CImGui.Text("No scene loaded.")
                        if currentSceneMain !== nothing && CImGui.TreeNode("Entities")
                            # remove other entities from hierarchyEntitySelections if currentSceneMain.selectedEntity is not in hierarchyEntitySelections
                            # this happens if we select an entity in the scene view
                            if currentSceneMain.selectedEntity !== nothing && any(entity -> (entity[1] == currentSceneMain.selectedEntity && entity[2] == false), hierarchyEntitySelections)
                                for index in eachindex(hierarchyEntitySelections)
                                    hierarchyEntitySelections[index] = (hierarchyEntitySelections[index][1], currentSceneMain.selectedEntity == hierarchyEntitySelections[index][1])
                                end
                            end 
                             
                            CImGui.SameLine()
                            show_help_marker("This is a list of all entities in the scene. Click on an entity to select it.")
                            CImGui.SameLine()
                            if CImGui.BeginMenu("Add") # TODO: Move to own file as a function
                                CImGui.MenuItem("Add", C_NULL, false, false)
                                if CImGui.BeginMenu("New")
                                    if CImGui.MenuItem("Entity")
                                        JulGame.MainLoopModule.create_new_entity(currentSceneMain)
                                    end
                                    
                                    CImGui.EndMenu()
                                end
                                CImGui.EndMenu()
                            end
                            
                           
                            CImGui.Unindent(CImGui.GetTreeNodeToLabelSpacing())

                            currentHierarchyFilterText = hierarchyFilterText[]
                            text_input_single_line("get_scene_file_name_from_full_scene_path", hierarchyFilterText) 
                            updateSelectionsBasedOnFilter = hierarchyFilterText[] != currentHierarchyFilterText
                            filteredEntities = filter(entity -> (isempty(hierarchyFilterText[]) || contains(lowercase(entity.name), lowercase(hierarchyFilterText[]))), currentSceneMain.scene.entities)
                            entitiesWithParents = filter(entity -> entity.parent != C_NULL, currentSceneMain.scene.entities)

                            show_help_marker("Hold CTRL and click to select multiple items.")
                            if length(hierarchyEntitySelections) == 0 || length(hierarchyEntitySelections) != length(filteredEntities) || updateSelectionsBasedOnFilter
                                hierarchyEntitySelections= []
                                for entity in filteredEntities
                                    push!(hierarchyEntitySelections, (entity, false))
                                end
                            end

                            # Add bulk delete button
                            selected_count = count(es -> es[2], hierarchyEntitySelections)
                            if selected_count > 0 && CImGui.Button("Delete Selected ($(selected_count))")
                                delete_confirmation_modal.open = true
                            end
                            CImGui.NewLine()

                            for n = eachindex(filteredEntities)
                                if filteredEntities[n].parent != C_NULL
                                    continue
                                end

                                children = filter(entity -> entity.parent == filteredEntities[n], entitiesWithParents)
                                if length(children) == 0
                                    handle_childless_entity_selection(filteredEntities[n], hierarchyEntitySelections, n, currentSceneMain, delete_confirmation_modal)
                                else
                                    handle_parent_entity_selection(filteredEntities[n], children, hierarchyEntitySelections, n, currentSceneMain, filteredEntities, delete_confirmation_modal, ui_delete_confirmation_modal)
                                end
                                handle_drag_and_drop(filteredEntities, n, currentSceneMain, hierarchyEntitySelections)
                            end

                            #CImGui.PopStyleVar()
                            CImGui.Indent(CImGui.GetTreeNodeToLabelSpacing())
                            CImGui.TreePop()
                        end

                        CImGui.NewLine()
                         
                        #region UI Elements
                        if currentSceneMain !== nothing && CImGui.TreeNode("UI Elements")
                            CImGui.NewLine()

                            if CImGui.BeginMenu("Add") # TODO: Move to own file as a function
                                CImGui.MenuItem("Add", C_NULL, false, false)
                                if CImGui.BeginMenu("New")
                                    if CImGui.MenuItem("TextBox")
                                        JulGame.MainLoopModule.create_new_text_box(currentSceneMain) 
                                    end
                                    if CImGui.MenuItem("Screen Button")
                                        JulGame.MainLoopModule.create_new_screen_button(currentSceneMain)
                                    end
                                    
                                    CImGui.EndMenu()
                                end
                                CImGui.EndMenu()
                            end
                            
                            # Add bulk delete button for UI elements
                            selected_ui_count = count(hierarchyUISelections)
                            if selected_ui_count > 0 && CImGui.Button("Delete Selected ($(selected_ui_count))")
                                CImGui.SameLine()
                                ui_delete_confirmation_modal.open = true
                            end
                            
                            CImGui.Unindent(CImGui.GetTreeNodeToLabelSpacing())

                            if length(hierarchyUISelections) == 0 || length(hierarchyUISelections) != length(currentSceneMain.scene.uiElements) # || updateUISelectionsBasedOnFilter
                                hierarchyUISelections=fill(false, length(currentSceneMain.scene.uiElements))
                            end

                            for n = eachindex(currentSceneMain.scene.uiElements)
                                CImGui.PushID(n)
                                buf = "$(n): $(currentSceneMain.scene.uiElements[n].name)"
                                if CImGui.Selectable(buf, hierarchyUISelections[n])
                                    # clear selection when CTRL is not held
                                    !unsafe_load(CImGui.GetIO().KeyCtrl) && fill!(hierarchyUISelections, false)
                                    hierarchyUISelections[n] ⊻= 1
                                    uiSelected = true
                                    # currentSceneMain.selectedEntity = currentSceneMain.scene.uiElements[n]
                                end
                                
                                # Add right-click context menu for UI elements
                                if hierarchyUISelections[n]
                                    show_ui_element_context_menu(currentSceneMain, n, ui_delete_confirmation_modal, hierarchyUISelections)
                                end
                                
                                CImGui.PopID()
                            end

                            CImGui.TreePop()
                        end
                    CImGui.End()
                catch e
                    handle_editor_exceptions("Hierarchy window:", latest_exceptions, e, is_test_mode)
                end

                try 
                    show_debug_window(latest_exceptions[])
                catch e
                    @error "Debug window error"
                end
                    
                    try
                        #region Entity Inspector
                        CImGui.Begin("Entity Inspector") 
                        
                        show_help_marker("This is where we will display editable properties of entities")
                        if currentSceneMain !== nothing && currentSceneMain.selectedEntity !== nothing 
                            CImGui.PushID("AddMenu")
                            if CImGui.BeginMenu("Add")
                                ShowEntityContextMenu(currentSceneMain.selectedEntity)
                                CImGui.EndMenu()
                            end
                            CImGui.PopID()
                            CImGui.Separator()
                            for entityField in fieldnames(Entity)
                                show_field_editor(currentSceneMain.selectedEntity, entityField, animation_window_dict, animator_preview_dict, newScriptText)
                            end
        
                            CImGui.Separator()
                            if CImGui.Button("Duplicate") 
                                copy = duplicate_entity(currentSceneMain.selectedEntity)
                                push!(currentSceneMain.scene.entities, copy)
                                currentSceneMain.selectedEntity = copy
                            end
                        end
                        CImGui.End()
                    catch e
                        handle_editor_exceptions("Entity inspector window:", latest_exceptions, e, is_test_mode)
                    end

                    try
                        
                        #region UI Inspector
                        CImGui.Begin("UI Inspector") 
                            show_help_marker("This is where we will display editable properties of textboxes and screen buttons")
                            for uiElementIndex = eachindex(hierarchyUISelections)
                                if hierarchyUISelections[uiElementIndex] # || currentSceneMain.selectedEntity == filteredEntities[entityIndex]
                                    if length(currentSceneMain.scene.uiElements) < uiElementIndex
                                        break
                                    end
                                    
                                    if contains("$(typeof(currentSceneMain.scene.uiElements[uiElementIndex]))", "TextBox")
                                        show_textbox_fields(currentSceneMain.scene.uiElements[uiElementIndex])
                                    else
                                        show_screenbutton_fields1(currentSceneMain.scene.uiElements[uiElementIndex])
                                    end

                                    CImGui.Separator()
                                    CImGui.Text("Delete UI Element")
                                    if CImGui.Button("Delete")
                                        CImGui.OpenPopup("Delete UI Element Confirmation")
                                    end
                                    
                                    if CImGui.BeginPopupModal("Delete UI Element Confirmation", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
                                        CImGui.Text("Are you sure you want to delete this UI element?\nThis cannot be undone.\n\n")
                                        CImGui.NewLine()
                                        if CImGui.Button("Delete", (120, 0))
                                            JulGame.destroy_ui_element(currentSceneMain, currentSceneMain.scene.uiElements[uiElementIndex])
                                            CImGui.CloseCurrentPopup()
                                            break
                                        end
                                        CImGui.SetItemDefaultFocus()
                                        CImGui.SameLine()
                                        if CImGui.Button("Cancel",(120, 0))
                                            CImGui.CloseCurrentPopup()
                                        end
                                        CImGui.EndPopup()
                                    end
                                    
                                    break # TODO: Remove this when we can select multiple entities and edit them all at once
                                end
                            end
                        CImGui.End()
                    catch e
                        handle_editor_exceptions("UI inspector window:", latest_exceptions, e, is_test_mode)
                    end

                    try
                        show_camera_window(cameraWindow)
                    catch e
                        handle_editor_exceptions("Camera window:", latest_exceptions, e, is_test_mode)
                    end

                    #region Config Window
                    try 
                        CImGui.Begin("Project Config") 
                        show_help_marker("This tab contains configuration fields for the game when it is launched separately (command line or executable)")
                        if currentSelectedProjectPath[] !== ""
                            show_config_fields(currentProjectConfig, currentSelectedProjectPath)
                        end
                        CImGui.End()
                    catch e
                        handle_editor_exceptions("Config window:", latest_exceptions, e, is_test_mode)
                    end

                    SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
                    SDL2.SDL_RenderClear(renderer)
                    try
                        if currentSceneMain !== nothing
                            # Store the current camera scale value
                            original_scale_units = JulGame.SCALE_UNITS
                            # Apply zoom to rendering by temporarily modifying scale units
                            JulGame.SCALE_UNITS = original_scale_units * zoom_level[]
                            JulGame.MainLoopModule.render_scene_sprites_and_shapes(currentSceneMain, camera)
                            # Restore the original scale value
                            JulGame.SCALE_UNITS = original_scale_units
                        end
                    catch e
                        handle_editor_exceptions("Scene window:", latest_exceptions, e, is_test_mode)
                    end

                    SDL2.SDL_SetRenderTarget(renderer, gameTexture)
                    SDL2.SDL_RenderClear(renderer)
                    try 
                        if currentSceneMain !== nothing
                            JulGame.CameraModule.update(gameCamera)
                            JulGame.MainLoopModule.render_scene_sprites_and_shapes(currentSceneMain, gameCamera)
                        end
                    catch e
                        handle_editor_exceptions("Game window:", latest_exceptions, e, is_test_mode)
                    end

                    try
                        gameInfo = currentSceneMain === nothing ? [] : JulGame.MainLoopModule.game_loop(currentSceneMain, startTime, lastPhysicsTime, Math.Vector2(sceneWindowPos.x + 8, sceneWindowPos.y + 25), Math.Vector2(sceneWindowSize.x, sceneWindowSize.y)) # Magic numbers for the border of the imgui window. TODO: Make this dynamic if possible
                    catch e
                        handle_editor_exceptions("Game loop:", latest_exceptions, e, is_test_mode)
                    end
                    
                    SDL2.SDL_SetRenderTarget(renderer, C_NULL)
                    SDL2.SDL_RenderClear(renderer)
                    
                    show_game_controls()

                    # Add a floating project/scene info display at the top center
                    # Calculate the current project name (last part of the path)
                    currentProjectName = currentSelectedProjectPath[] != "" ? basename(currentSelectedProjectPath[]) : "No Project"
                    currentSceneDisplayName = currentSceneName != "" ? replace(currentSceneName, ".json" => "") : "No Scene"
                    
                    # Create a floating window in the top center
                    CImGui.SetNextWindowBgAlpha(0.7)
                    # Position in top center of the screen
                    display_width = unsafe_load(CImGui.GetIO().DisplaySize).x
                    CImGui.SetNextWindowPos(
                        ImVec2(
                            Math.TypeConversions.safe_int32_convert(round(display_width / 2.0)), 
                            0
                        ), 
                        CImGui.ImGuiCond_Always, 
                        ImVec2(0.5, 0.0)
                    )
                    
                    project_window_flags = CImGui.ImGuiWindowFlags_NoDecoration | 
                                  CImGui.ImGuiWindowFlags_AlwaysAutoResize | 
                                  CImGui.ImGuiWindowFlags_NoSavedSettings |
                                  CImGui.ImGuiWindowFlags_NoFocusOnAppearing |
                                  CImGui.ImGuiWindowFlags_NoNav
                    
                    # Apply custom styling for the project/scene info window              
                    CImGui.PushStyleColor(CImGui.ImGuiCol_WindowBg, (0.15, 0.15, 0.2, 0.8))  # Darker blue background
                    CImGui.PushStyleVar(CImGui.ImGuiStyleVar_WindowBorderSize, 1.0)
                    CImGui.PushStyleColor(CImGui.ImGuiCol_Border, (0.3, 0.3, 0.6, 0.6))
                    
                    CImGui.Begin("ProjectSceneInfo", C_NULL, project_window_flags)
                    
                    # Use a vibrant text color with a slight glow effect
                    CImGui.PushStyleColor(CImGui.ImGuiCol_Text, (0.85, 0.85, 1.0, 0.95))
                    
                    # Display with some padding for visual comfort
                    CImGui.SetCursorPosX(CImGui.GetCursorPosX() + 8)
                    CImGui.Text("$(currentProjectName) - $(currentSceneDisplayName)")
                    
                    CImGui.PopStyleColor()  # Text color
                    CImGui.End()
                    
                    CImGui.PopStyleColor(2)  # Window background and border
                    CImGui.PopStyleVar()     # Border size

                    # Add a floating play mode indicator when in play mode
                    if JulGame.IS_EDITOR_PLAY_MODE
                        # Calculate pulsing alpha for the text
                        pulsing_alpha = 0.6 + 0.4 * sin(Float64(SDL2.SDL_GetTicks()) / 300.0)
                        
                        # Create a floating window in the corner
                        CImGui.SetNextWindowBgAlpha(0.7)
                        # Position below the project info
                        CImGui.SetNextWindowPos(
                            ImVec2(
                                Math.TypeConversions.safe_int32_convert(round(display_width / 2.0)), 
                                40
                            ), 
                            CImGui.ImGuiCond_Always, 
                            ImVec2(0.5, 0.0)
                        )
                        
                        window_flags = CImGui.ImGuiWindowFlags_NoDecoration | 
                                      CImGui.ImGuiWindowFlags_AlwaysAutoResize | 
                                      CImGui.ImGuiWindowFlags_NoSavedSettings |
                                      CImGui.ImGuiWindowFlags_NoFocusOnAppearing |
                                      CImGui.ImGuiWindowFlags_NoNav
                                      
                        CImGui.Begin("PlayModeIndicator", C_NULL, window_flags)
                        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, (1.0, 0.3, 0.3, pulsing_alpha))
                        CImGui.TextColored((1.0, 0.3, 0.3, pulsing_alpha), "PLAY MODE ACTIVE")
                        CImGui.PopStyleColor()
                        CImGui.End()
                    end

                    # Add a floating auto-load notification if needed
                    if auto_load_notification && auto_load_notification_time > 0
                        # Calculate pulsing alpha for the text
                        pulsing_alpha = 0.7 + 0.3 * sin(Float64(SDL2.SDL_GetTicks()) / 300.0)
                        
                        # Create a floating notification
                        CImGui.SetNextWindowBgAlpha(0.8)
                        # Position in bottom right of the screen
                        display_width = unsafe_load(CImGui.GetIO().DisplaySize).x
                        display_height = unsafe_load(CImGui.GetIO().DisplaySize).y
                        CImGui.SetNextWindowPos(ImVec2(display_width - 10, display_height - 10), CImGui.ImGuiCond_Always, ImVec2(1.0, 1.0))
                        
                        window_flags = CImGui.ImGuiWindowFlags_NoDecoration | 
                                      CImGui.ImGuiWindowFlags_AlwaysAutoResize | 
                                      CImGui.ImGuiWindowFlags_NoSavedSettings |
                                      CImGui.ImGuiWindowFlags_NoFocusOnAppearing |
                                      CImGui.ImGuiWindowFlags_NoNav
                                      
                        CImGui.Begin("AutoLoadNotification", C_NULL, window_flags)
                        CImGui.PushStyleColor(CImGui.ImGuiCol_Text, (0.3, 0.8, 0.3, pulsing_alpha))
                        CImGui.Text("Auto-loaded project: $(basename(currentSelectedProjectPath[]))")
                        CImGui.PopStyleColor()
                        
                        # Decrease the timer
                        auto_load_notification_time -= DELTA_TIME > 0 ? DELTA_TIME : 0.016
                        CImGui.End()
                    end

                    #region Input
                    try
                        if currentSceneMain !== nothing
                            if currentSceneMain.scene.camera != gameCamera
                                gameCamera = currentSceneMain.scene.camera
                                cameraWindow.camera = gameCamera
                            end
                            if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LCTRL") && JulGame.InputModule.get_button_pressed(currentSceneMain.input, "S")
                                @debug string("Saving scene")
                                events["Save"]()
                            end
                            # delete selected entity
                            if JulGame.InputModule.get_button_pressed(currentSceneMain.input, "DELETE")
                                if currentSceneMain.selectedEntity !== nothing
                                    JulGame.destroy_entity(currentSceneMain, currentSceneMain.selectedEntity)
                                end
                            end
                            # duplicate selected entity with ctrl+d
                            if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LCTRL") && JulGame.InputModule.get_button_pressed(currentSceneMain.input, "D") && currentSceneMain.selectedEntity !== nothing
                                copy = duplicate_entity(currentSceneMain.selectedEntity)
                                push!(currentSceneMain.scene.entities, copy)
                                currentSceneMain.selectedEntity = copy
                            end
                            # turn on duplication mode with ctrl+shift+d
                            if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LCTRL") && JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LSHIFT") && JulGame.InputModule.get_button_pressed(currentSceneMain.input, "D") && currentSceneMain.selectedEntity !== nothing
                                duplicationMode = !duplicationMode
                                if duplicationMode
                                    @debug "Duplication mode on"
                                    copy = deepcopy(currentSceneMain.selectedEntity)
                                    copy.id = JulGame.generate_uuid()
                                    push!(currentSceneMain.scene.entities, copy)
                                    currentSceneMain.selectedEntity = copy
                                else
                                    @debug "Duplication mode off"
                                    JulGame.destroy_entity(currentSceneMain, currentSceneMain.selectedEntity)
                                end
                            end
                            
                            # Play/stop scene with LCTRL+R (with confirmation)
                            if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LCTRL") && !JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LSHIFT") && JulGame.InputModule.get_button_pressed(currentSceneMain.input, "R")
                                @debug "Play/Stop shortcut (with confirmation)"
                                confirmation_modal.open = true
                            end
                            
                            # Play/stop scene with LCTRL+LSHIFT+R (without confirmation)
                            if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LCTRL") && JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LSHIFT") && JulGame.InputModule.get_button_pressed(currentSceneMain.input, "R")
                                @debug "Play/Stop shortcut (without confirmation)"
                                # Toggle play mode directly
                                JulGame.IS_EDITOR_PLAY_MODE = !JulGame.IS_EDITOR_PLAY_MODE
                                if JulGame.IS_EDITOR_PLAY_MODE
                                    startTime[] = SDL2.SDL_GetTicks()
                                    # Animate the text in the window title
                                    SDL2.SDL_SetWindowTitle(window, "PLAYING $(windowTitle) - $(currentSelectedProjectPath[])")
                                    JulGame.MainLoopModule.start_game_in_editor(currentSceneMain, currentSelectedProjectPath[])
                                    currentSceneMain.scene.camera = gameCamera
                                else
                                    # Reset the window title when exiting play mode
                                    SDL2.SDL_SetWindowTitle(window, "$(windowTitle) - $(currentSelectedProjectPath[])")
                                    JulGame.MainLoopModule.stop_game_in_editor(currentSceneMain)
                                    JulGame.change_scene(String(currentSceneName))
                                end
                            end
                            
                            # TODO: Replace the deepcopy+generate_uuid pattern with duplicate_entity utility function
                        end
                    catch e
                        handle_editor_exceptions("Inputs:", latest_exceptions, e, is_test_mode)
                    end
                    
                    # Pop the MenuBar style color if we're in play mode
                    if JulGame.IS_EDITOR_PLAY_MODE
                        CImGui.PopStyleColor()
                    end
                    
                    ################################# STOP RENDERING HERE
                    CImGui.Render()
                    SDL2.SDL_RenderSetScale(renderer, unsafe_load(io.DisplayFramebufferScale.x), unsafe_load(io.DisplayFramebufferScale.y));
                    SDL2.SDL_SetRenderDrawColor(renderer, (UInt8)(round(clear_color[1] * 255)), (UInt8)(round(clear_color[2] * 255)), (UInt8)(round(clear_color[3] * 255)), (UInt8)(round(clear_color[4] * 255)));
                    SDL2.SDL_RenderClear(renderer);
                    ImGui_ImplSDLRenderer2_RenderDrawData(CImGui.GetDrawData())
                    
                    screenA = Ref(SDL2.SDL_Rect(round(sceneWindowPos.x), sceneWindowPos.y + 20, sceneWindowSize.x, sceneWindowSize.y - 20))
                    SDL2.SDL_RenderSetViewport(renderer, screenA)
                    
                    ################################################# Injecting game loop into editor
                    if currentSceneMain !== nothing
                        if currentSceneMain.input.editorCallback === nothing
                            currentSceneMain.input.editorCallback = ImGui_ImplSDL2_ProcessEvent
                        end
                        JulGame.InputModule.poll_input(currentSceneMain.input)
                        quit = currentSceneMain.input.quit
                    end
                    #################################################

                    SDL2.SDL_RenderPresent(renderer);
                    if is_test_mode && testFrameCount < testFrameLimit
                        testFrameCount += 1
                    elseif is_test_mode
                        quit = true
                    end
                catch e 
                    @error "Error in renderloop!" exception=e
                    Base.show_backtrace(stderr, catch_backtrace())
                end

                if current_path != currentSelectedProjectPath[]
                    recent_projects = add_path_to_recents(currentSelectedProjectPath[])
                    current_path = currentSelectedProjectPath[]
                    #starting the file watcher
                    condition, watch_task = start_file_watcher(string(currentSelectedProjectPath[]), filesToReload)
                    # Update BasePath when project changes
                    JulGame.BasePath = currentSelectedProjectPath[]
                    @debug("Base path updated: $(JulGame.BasePath)")
                    
                elseif current_path !== nothing && current_path != "" && condition !== nothing && !istaskdone(watch_task)
                    notify(condition)
                    yield()
                end

                if length(filesToReload[]) > 0
                    for file in filesToReload[]
                        classname = split(file, ".")[begin]
                        try
                            Base.include(JulGame.ScriptModule, joinpath(JulGame.BasePath, "scripts", file))
                        catch e
                            @error "Error reloading file: $(file)"
                            @error "Error: $(e)"
                            Base.show_backtrace(stderr, catch_backtrace())
                            continue
                        end
                        
                        # Only attempt to reload scripts if currentSceneMain exists and is loaded
                        if currentSceneMain !== nothing
                            for entity in currentSceneMain.scene.entities
                                i = 1
                                for script in entity.scripts
                                    script_name = split("$(typeof(script))", ".")[end]
                                    if script_name == classname
                                        try 
                                            @debug("reloading script: $(script_name)")
                                            module_name = getfield(JulGame.ScriptModule, Symbol("$(classname)Module"))
                                            constructor = Base.invokelatest(getfield, module_name, Symbol(script_name)) 
                                            new_script = Base.invokelatest(constructor)

                                            # Copy all fields from old_script to the new script
                                            for fieldname in fieldnames(typeof(entity.scripts[i]))
                                                if fieldname != :parent  # Skip the `parent` field to avoid overwriting it
                                                    try
                                                        if isdefined(entity.scripts[i], Symbol(fieldname))
                                                            setfield!(new_script, fieldname, getfield(entity.scripts[i], fieldname))
                                                        end
                                                    catch e
                                                        @error("issue with field: $(fieldname): $e")
                                                    end
                                                end
                                            end

                                            entity.scripts[i] = new_script
                                            entity.scripts[i].parent = entity

                                            @debug "script reloaded successfully"
                                        catch e
                                            @error "Error reloading script: $(script_name): $(first(string(e), 1000))"
                                            Base.show_backtrace(stderr, catch_backtrace())
                                        end
                                    end

                                    i += 1
                                end
                            end
                        else
                            @debug "Skipping script reload as no scene is currently loaded"
                        end

                    end

                    filesToReload[] = []
                end
                #println("loop")
            end
        catch e
            backup_file_name = backup_file_name = "$(replace(currentSceneName, ".json" => ""))-backup-$(replace(Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS"), ":" => "-")).json"
            @debug string("Backup file name: ", backup_file_name)
            SceneWriterModule.serialize_entities(currentSceneMain.scene.entities, currentSceneMain.scene.uiElements, gameCamera, currentSelectedProjectPath[], backup_file_name)
            @error "Error in renderloop!" exception=e
            Base.show_backtrace(stderr, catch_backtrace())
        finally
            #TODO: fix these: ImGui_ImplSDLRenderer2_Shutdown();
            # ImGui_ImplSDL2_Shutdown();

            CImGui.DestroyContext(ctx)
            SDL2.SDL_DestroyTexture(sceneTexture)
            SDL2.SDL_DestroyTexture(gameTexture)
            SDL2.SDL_DestroyRenderer(renderer);
            SDL2.SDL_DestroyWindow(window);
            SDL2.SDL_Quit()
            return 0
        end
    end

    function poll_files(condition, path, filesToReload)
        index = false
        while !index
            try
                watched = FileWatching.watch_folder(joinpath(path, "scripts"), 0.01) 
                if watched.first != ""
                    @debug "Updated $(watched.first), renamed: $(watched.second.renamed), changed: $(watched.second.changed), timedout: $(watched.second.timedout)"
                    if watched.second.changed
                        @debug "pushing to files to reload"
                        push!(filesToReload[], watched.first)
                        @debug "pushed to files to reload"
                    end
                end
            catch e
                wait(condition)
                @error "Error: ", e
            end
            wait(condition)
        end
    end

    function handle_editor_exceptions(error_location, latest_exceptions, e, is_test_mode)
        # Get the stack trace
        bt = stacktrace(catch_backtrace())
                        
        file = ""
        line = ""
        if !isempty(bt)
            top_frame = bt[1]
            file = top_frame.file
            line = top_frame.line
        else
            @debug("Stack trace is empty.")
        end

        log_exceptions(error_location, latest_exceptions, e, "$(file):$(line)", is_test_mode)
    end

    function show_config_fields(currentProjectConfig, currentSelectedProjectPath)
            CImGui.Text("Config")
            CImGui.NewLine()
            CImGui.Text("Width")
            CImGui.SameLine()
            CImGui.InputInt("##Width", currentProjectConfig.Width)
            CImGui.NewLine()
            CImGui.Text("Height")
            CImGui.SameLine()
            CImGui.InputInt("##Height", currentProjectConfig.Height)
            CImGui.NewLine()
            CImGui.Text("Frame Rate")
            CImGui.SameLine()
            CImGui.InputInt("##FrameRate", currentProjectConfig.FrameRate)
            CImGui.NewLine()
            CImGui.Text("Is Resizable")
            CImGui.SameLine()
            CImGui.Checkbox("##IsResizable", currentProjectConfig.IsResizable)
            CImGui.NewLine()
            CImGui.Text("Fullscreen")
            CImGui.SameLine()
            CImGui.Checkbox("##Fullscreen", currentProjectConfig.Fullscreen)
            CImGui.NewLine()

        if CImGui.Button("Save Config")
            save_config_editor(currentProjectConfig, currentSelectedProjectPath)
        end
    end

    function save_config_editor(currentProjectConfig, currentSelectedProjectPath)
        filename = joinpath(currentSelectedProjectPath[], "config.julgame")
        config = Dict{String, String}()
        
        config["Width"] = string(currentProjectConfig.Width[])
        config["Height"] = string(currentProjectConfig.Height[])
        config["Fullscreen"] = string(Int(currentProjectConfig.Fullscreen[]))
        config["IsResizable"] = string(Int(currentProjectConfig.IsResizable[]))
        config["FrameRate"] = string(currentProjectConfig.FrameRate[])
        
        open(filename, "w") do file
            for (key, value) in config
                println(file, "$key=$value")
            end
        end

        @debug "Saved config file to $(filename)"
    end

    function load_project_config(currentSelectedProjectPath)
        filename = joinpath(currentSelectedProjectPath[], "config.julgame")
        config = Dict{String, String}()
        if isfile(filename)
            open(filename, "r") do file
                try
                    for line in eachline(file)
                        key, value = split(line, "=")
                        config[key] = value
                    end
                catch e
                    @warn e
                end
            end
        end

        Width = Ref(Math.TypeConversions.safe_int32_convert(parse(Int, config["Width"])))
        Height = Ref(Math.TypeConversions.safe_int32_convert(parse(Int, config["Height"])))
        FrameRate = Ref(Math.TypeConversions.safe_int32_convert(parse(Int, config["FrameRate"])))
        IsResizable = Ref(parse(Bool, config["IsResizable"]))
        Fullscreen = Ref(parse(Bool, config["Fullscreen"]))

        return (Width=Width, Height=Height, FrameRate=FrameRate, IsResizable=IsResizable, Fullscreen=Fullscreen)
    end

    # Function to read and parse the recents file with timestamps
    function get_raw_recents()
        try
            filename = joinpath(JulGame.PrefHandlerModule.get_pref_path("kyjor", "julgame"), "recents.txt")
            projects = []
            
            if isfile(filename)
                # Open the file for reading
                open(filename, "r") do file
                    for line in eachline(file)
                        line = strip(line)
                        if !isempty(line)
                            # Check if the line contains a timestamp (format: "path|timestamp")
                            parts = split(line, "|")
                            if length(parts) == 2
                                # Has timestamp format
                                path = strip(parts[1])
                                timestamp = strip(parts[2])
                                # Only add if the path exists
                                if isdir(path)
                                    push!(projects, (path=path, timestamp=timestamp))
                                end
                            else
                                # Old format without timestamp - if valid directory
                                if isdir(line)
                                    # Use current time as timestamp for old entries
                                    push!(projects, (path=line, timestamp=string(Dates.now())))
                                end
                            end
                        end
                    end
                end
            else 
                touch(filename)
            end
    
            # Sort by timestamp, most recent first
            sort!(projects, by = x -> x.timestamp, rev=true)
            
            return projects
        catch e
            @error "Error parsing recents file" exception=e
            return []
        end
    end

    # Function to get the most recent project path
    function get_most_recent_project()
        raw_recents = get_raw_recents()
        if !isempty(raw_recents)
            return raw_recents[1].path
        end
        return ""
    end

    # Function to read and parse the recents file
    function parse_recents()
        try
            filename = joinpath(JulGame.PrefHandlerModule.get_pref_path("kyjor", "julgame"), "recents.txt")
            projects = []
            
            if isfile(filename)
                # Open the file for reading
                open(filename, "r") do file
                    for line in eachline(file)
                        line = strip(line)
                        if !isempty(line)
                            # Check if the line contains a timestamp (format: "path|timestamp")
                            parts = split(line, "|")
                            if length(parts) == 2
                                # Has timestamp format
                                path = strip(parts[1])
                                timestamp = strip(parts[2])
                                # Only add if the path exists
                                if isdir(path)
                                    push!(projects, (path=path, timestamp=timestamp))
                                end
                            else
                                # Old format without timestamp - if valid directory
                                if isdir(line)
                                    # Use current time as timestamp for old entries
                                    push!(projects, (path=line, timestamp=string(Dates.now())))
                                end
                            end
                        end
                    end
                end
            else 
                touch(filename)
            end
    
            # Sort by timestamp, most recent first
            sort!(projects, by = x -> x.timestamp, rev=true)
            
            # Return just the paths for backward compatibility
            return [p.path for p in projects]
        catch e
            @error "Error parsing recents file" exception=e
            filename = joinpath(JulGame.PrefHandlerModule.get_pref_path("kyjor", "julgame"), "recents.txt")
            isfile(filename) && rm(filename; force=true)
            touch(filename)
            return []
        end
    end

    # Function to write a path to the recents file with timestamp
    function add_path_to_recents(path::String)
        filename = joinpath(JulGame.PrefHandlerModule.get_pref_path("kyjor", "julgame"), "recents.txt")
        try 
            if !isfile(filename)
                touch(filename)
            end

            # Get current timestamp
            current_time = Dates.now()
            
            # Read existing entries with their timestamps
            entries = []
            if isfile(filename)
                open(filename, "r") do file
                    for line in eachline(file)
                        line = strip(line)
                        if !isempty(line)
                            parts = split(line, "|")
                            existing_path = length(parts) > 1 ? strip(parts[1]) : line
                            existing_timestamp = length(parts) > 1 ? strip(parts[2]) : string(current_time)
                            
                            # Only keep entries that are different from the new path
                            if existing_path != path && isdir(existing_path)
                                push!(entries, (path=existing_path, timestamp=existing_timestamp))
                            end
                        end
                    end
                end
            end
            
            # Add the new path with current timestamp at the beginning
            pushfirst!(entries, (path=path, timestamp=string(current_time)))
            
            # Write all entries back to the file
            open(filename, "w") do file
                for entry in entries
                    println(file, "$(entry.path)|$(entry.timestamp)")
                end
            end

            # Return paths only for backward compatibility
            return [e.path for e in entries]
        catch e
            @error "Error adding path to recents" exception=e
            rm(filename; force=true)
            touch(filename)
            open(filename, "a") do file
                println(file, "$(path)|$(Dates.now())")
            end
            return [path]
        end
    end

    function start_file_watcher(path::String, filesToReload)
        try
            @debug "Starting file watcher"
            condition = Condition()
            watch_task = @task poll_files(condition, path, filesToReload) # FileWatching.watch_folder(joinpath(currentSelectedProjectPath[], "scripts"), 0.1)
            schedule(watch_task)
            return condition, watch_task
        catch e
            @error "Error starting file watcher" exception=e
        end
    end
end # module
