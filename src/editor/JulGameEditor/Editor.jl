# Reference: https://github.com/ocornut/imgui/tree/master/examples/example_sdl2_sdlrenderer2

module Editor
    using CImGui
    using CImGui.CSyntax
    using CImGui.CSyntax.CStatic
    using CImGui: ImVec2, ImVec4, IM_COL32, ImS32, ImU32, ImS64, ImU64
    using CImGui.CImGui
    using Dates
    using JulGame: Component, MainLoop, Math, SceneLoaderModule, SDL2, UI
    using NativeFileDialog

    global sdlVersion = "2.0.0"
    global sdlRenderer = C_NULL
    global const BackendPlatformUserData = Ref{Any}(C_NULL)

    include(joinpath("..","..","Macros.jl"))

    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "ImGuiSDLBackend"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Components"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Utils"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Windows"); join=true)))

    function run(is_test_mode::Bool=false)
        info = init_sdl_and_imgui()
        window, renderer, ctx, io, clear_color = info[1], info[2], info[3], info[4], info[5]
        startingSize = ImVec2(1920, 1080)
        sceneTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, startingSize.x, startingSize.y)# SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
        sceneTextureSize = ImVec2(startingSize.x, startingSize.y)

        style_imGui()
        showDemoWindow = true
        ##############################
        # Project variables
        currentSceneMain = nothing
        currentSceneName = ""
        currentSelectedProjectPath = ""
        gameInfo = []
        ##############################
        # Hierarchy variables
        filteredEntities = Entity[]
        hierarchyFilterText::String = ""
        hierarchyEntitySelections = []
        hierarchyUISelections = Bool[]
        ##############################
        scenesLoadedFromFolder = Ref(String[])
        latest_exceptions = []

        sceneWindowPos = ImVec2(0, 0)
        sceneWindowSize = ImVec2(startingSize.x, startingSize.y)
        testFrameCount = 0
        testFrameLimit = 100
        quit = false

        scrolling = Ref(ImVec2(0.0, 0.0))
        zoom_level = Ref(1.0)

        animation_window_dict = Ref(Dict())

        save_file_timer = 0

        duplicationMode = false

        try
            while !quit                    
                try
                    if currentSceneMain === nothing
                        quit = poll_events()
                    end   
                    start_frame()
                    CImGui.igDockSpaceOverViewport(C_NULL, C_NULL, CImGui.ImGuiDockNodeFlags_PassthruCentralNode, C_NULL) # Creating the "dockspace" that covers the whole window. This allows the child windows to automatically resize.
                    
                    ################################## RENDER HERE
                    
                    ################################# MAIN MENU BAR
                    events = []
                    if currentSceneMain !== nothing
                        push!(events, save_scene_event(currentSceneMain.scene.entities, currentSceneMain.scene.uiElements, currentSelectedProjectPath, String(currentSceneName)))
                    end
                    push!(events, select_project_event(currentSceneMain, scenesLoadedFromFolder))
                    show_main_menu_bar(events)
                    ################################# END MAIN MENU BAR

                    @c CImGui.ShowDemoWindow(Ref{Bool}(showDemoWindow)) # Uncomment this line to show the demo window and see available widgets

                    @cstatic begin
                        #region Scene List
                        CImGui.Begin("Scene List") 
                        txt = currentSceneMain === nothing ? "Load Scene" : "Change Scene"
                        CImGui.Text(txt)

                        for scene in scenesLoadedFromFolder[]
                            if CImGui.Button("$(scene)")
                                currentSceneName = SceneLoaderModule.get_scene_file_name_from_full_scene_path(scene)
                                if currentSceneMain === nothing
                                    currentSceneMain = load_scene(scene, renderer) 
                                    currentSceneMain.cameraBackgroundColor = (50, 50, 50)
                                    JulGame.PIXELS_PER_UNIT = 16
                                    currentSceneMain.autoScaleZoom = true
                                    currentSelectedProjectPath = SceneLoaderModule.get_project_path_from_full_scene_path(scene) 
                                else
                                    MainLoop.change_scene(String(currentSceneName), true)
                                end
                            end
                            CImGui.NewLine()
                        end

                        CImGui.End()
                    end
                    
                    uiSelected = false
                    
                
                    if sceneWindowSize.x != sceneTextureSize.x || sceneWindowSize.y != sceneTextureSize.y
                        SDL2.SDL_DestroyTexture(sceneTexture)
                        sceneTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, sceneWindowSize.x, sceneWindowSize.y)
                        sceneTextureSize = ImVec2(sceneWindowSize.x, sceneWindowSize.y)
                    end
                    
                    try
                        prevSceneWindowSize = sceneWindowSize
                        sceneWindowSize = show_scene_window(currentSceneMain, sceneTexture, scrolling, zoom_level, duplicationMode)
                        if sceneWindowSize === nothing
                            sceneWindowSize = prevSceneWindowSize
                        end
                    catch e
                        @error "Error in scene window!" exception=e
                        Base.show_backtrace(stderr, catch_backtrace())
                    end

                    try
                        #region Hierarchy
                        CImGui.Begin("Hierarchy") 
                        if CImGui.TreeNode("Entities") &&  currentSceneMain !== nothing
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
                                        JulGame.MainLoop.create_new_entity(currentSceneMain)
                                    end
                                    
                                    CImGui.EndMenu()
                                end
                                CImGui.EndMenu()
                            end
                            CImGui.Unindent(CImGui.GetTreeNodeToLabelSpacing())

                            currentHierarchyFilterText = hierarchyFilterText
                            hierarchyFilterText = text_input_single_line("Hierarchy Filter") 
                            updateSelectionsBasedOnFilter = hierarchyFilterText != currentHierarchyFilterText
                            filteredEntities = filter(entity -> (isempty(hierarchyFilterText) || contains(lowercase(entity.name), lowercase(hierarchyFilterText))), currentSceneMain.scene.entities)
                            entitiesWithParents = filter(entity -> entity.parent != C_NULL, currentSceneMain.scene.entities)

                            show_help_marker("Hold CTRL and click to select multiple items.")
                            if length(hierarchyEntitySelections) == 0 || length(hierarchyEntitySelections) != length(filteredEntities) || updateSelectionsBasedOnFilter
                                hierarchyEntitySelections= []
                                for entity in filteredEntities
                                    push!(hierarchyEntitySelections, (entity, false))
                                end
                            end

                            for n = eachindex(filteredEntities)
                                if filteredEntities[n].parent != C_NULL
                                    continue
                                end

                                children = filter(entity -> entity.parent == filteredEntities[n], entitiesWithParents)
                                if length(children) == 0
                                    handle_childless_entity_selection(filteredEntities[n], hierarchyEntitySelections, n, currentSceneMain)
                                else
                                    handle_parent_entity_selection(filteredEntities[n], children, hierarchyEntitySelections, n, currentSceneMain, filteredEntities)
                                end
                                handle_drag_and_drop(filteredEntities, n, currentSceneMain, hierarchyEntitySelections)
                            end

                            CImGui.PopStyleVar()
                            CImGui.Indent(CImGui.GetTreeNodeToLabelSpacing())
                            CImGui.TreePop()
                        end

                        CImGui.NewLine()
                        #region UI Elements
                        if CImGui.TreeNode("UI Elements") &&  currentSceneMain !== nothing
                            CImGui.SameLine()
                            if CImGui.BeginMenu("Add") # TODO: Move to own file as a function
                                CImGui.MenuItem("Add", C_NULL, false, false)
                                if CImGui.BeginMenu("New")
                                    if CImGui.MenuItem("TextBox")
                                        JulGame.MainLoop.create_new_text_box(currentSceneMain) 
                                    end
                                    if CImGui.MenuItem("Screen Button")
                                        JulGame.MainLoop.create_new_screen_button(currentSceneMain)
                                    end
                                    
                                    CImGui.EndMenu()
                                end
                                CImGui.EndMenu()
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
                                CImGui.PopID()

                            end

                            CImGui.TreePop()
                        end
                    CImGui.End()
                catch e
                    log_exceptions("Hierarchy Window Error:", latest_exceptions, e, is_test_mode)
                end

                    show_debug_window(latest_exceptions)
                    
                    try
                        #region Entity Inspector
                        CImGui.Begin("Entity Inspector") 
                        if currentSceneMain !== nothing && currentSceneMain.selectedEntity !== nothing 
                            CImGui.PushID("AddMenu")
                            if CImGui.BeginMenu("Add")
                                ShowEntityContextMenu(currentSceneMain.selectedEntity)
                                CImGui.EndMenu()
                            end
                            CImGui.PopID()
                            CImGui.Separator()
                            for entityField in fieldnames(Entity)
                                show_field_editor(currentSceneMain.selectedEntity, entityField, animation_window_dict)
                            end
        
                            CImGui.Separator()
                            if CImGui.Button("Duplicate") 
                                copy = deepcopy(currentSceneMain.selectedEntity)
                                push!(currentSceneMain.scene.entities, copy)
                                currentSceneMain.selectedEntity = copy
                            end
                        end
                        CImGui.End()
                    catch e
                        log_exceptions("Entity Inspector Window Error:", latest_exceptions, e, is_test_mode)
                    end

                    try
                        
                        #region UI Inspector
                        CImGui.Begin("UI Inspector") 
                            for uiElementIndex = eachindex(hierarchyUISelections)
                                if hierarchyUISelections[uiElementIndex] # || currentSceneMain.selectedEntity == filteredEntities[entityIndex]
                                    CImGui.PushID("AddMenu")
                                    if CImGui.BeginMenu("Add")
                                        ShowEntityContextMenu(currentSceneMain.scene.uiElements[uiElementIndex])
                                        CImGui.EndMenu()
                                    end
                                    CImGui.PopID()
                                    CImGui.Separator()

                                    if length(currentSceneMain.scene.uiElements) < uiElementIndex
                                        break
                                    end
                                    
                                    if contains("$(typeof(currentSceneMain.scene.uiElements[uiElementIndex]))", "TextBox")
                                        show_textbox_fields(currentSceneMain.scene.uiElements[uiElementIndex])
                                    else
                                        show_screenbutton_fields(currentSceneMain.scene.uiElements[uiElementIndex])
                                    end

                                    # CImGui.Separator()
                                    # if CImGui.Button("Duplicate") 
                                    #     push!(currentSceneMain.scene.uiElements, deepcopy(currentSceneMain.scene.uiElements[uiElementIndex]))
                                    #     # TODO: switch to duplicated entity
                                    # end

                                    CImGui.Separator()
                                    CImGui.Text("Delete UI Element: NO CONFIRMATION")
                                    if CImGui.Button("Delete")
                                        MainLoop.destroy_ui_element(currentSceneMain.scene.uiElements[uiElementIndex])
                                        break
                                    end
                                    
                                    break # TODO: Remove this when we can select multiple entities and edit them all at once
                                end
                            end
                        CImGui.End()
                    catch e
                        log_exceptions("UI Inspector Window Error:", latest_exceptions, e, is_test_mode)
                    end

                    SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
                    SDL2.SDL_RenderClear(renderer)
                    gameInfo = currentSceneMain === nothing ? [] : JulGame.MainLoop.game_loop(currentSceneMain, Ref(UInt64(0)), Ref(UInt64(0)), true, Math.Vector2(sceneWindowPos.x + 8, sceneWindowPos.y + 25), Math.Vector2(sceneWindowSize.x, sceneWindowSize.y)) # Magic numbers for the border of the imgui window. TODO: Make this dynamic if possible
                    SDL2.SDL_SetRenderTarget(renderer, C_NULL)
                    SDL2.SDL_RenderClear(renderer)
                    
                    show_game_controls()

                    #region Input
                    if currentSceneMain !== nothing
                        if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LCTRL") && JulGame.InputModule.get_button_pressed(currentSceneMain.input, "S")
                            @info string("Saving scene")
                            events[1]()
                        end
                        # delete selected entity
                        if JulGame.InputModule.get_button_pressed(currentSceneMain.input, "DELETE")
                            if currentSceneMain.selectedEntity !== nothing
                                MainLoop.destroy_entity(currentSceneMain, currentSceneMain.selectedEntity)
                            end
                        end
                        # duplicate selected entity with ctrl+d
                        if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LCTRL") && JulGame.InputModule.get_button_pressed(currentSceneMain.input, "D") && currentSceneMain.selectedEntity !== nothing
                            copy = deepcopy(currentSceneMain.selectedEntity)
                            push!(currentSceneMain.scene.entities, copy)
                            currentSceneMain.selectedEntity = copy
                        end
                        # turn on duplication mode with ctrl+shift+d
                        if JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LCTRL") && JulGame.InputModule.get_button_held_down(currentSceneMain.input, "LSHIFT") && JulGame.InputModule.get_button_pressed(currentSceneMain.input, "D") && currentSceneMain.selectedEntity !== nothing
                            duplicationMode = !duplicationMode
                            if duplicationMode
                                @info "Duplication mode on"
                                copy = deepcopy(currentSceneMain.selectedEntity)
                                push!(currentSceneMain.scene.entities, copy)
                                currentSceneMain.selectedEntity = copy
                            else
                                @info "Duplication mode off"
                                MainLoop.destroy_entity(currentSceneMain, currentSceneMain.selectedEntity)
                            end
                        end
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
            end
        catch e
            backup_file_name = backup_file_name = "$(replace(currentSceneName, ".json" => ""))-backup-$(replace(Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS"), ":" => "-")).json"
            @info string("Backup file name: ", backup_file_name)
            SceneWriterModule.serialize_entities(currentSceneMain.scene.entities, currentSceneMain.scene.uiElements, currentSelectedProjectPath, backup_file_name)
            Base.show_backtrace(stderr, catch_backtrace())
            @warn "Error in renderloop!" exception=e
        finally
            #TODO: fix these: ImGui_ImplSDLRenderer2_Shutdown();
            # ImGui_ImplSDL2_Shutdown();

            CImGui.DestroyContext(ctx)
            SDL2.SDL_DestroyTexture(sceneTexture)
            SDL2.SDL_DestroyRenderer(renderer);
            SDL2.SDL_DestroyWindow(window);
            SDL2.SDL_Quit()
            return 0
        end
    end
end