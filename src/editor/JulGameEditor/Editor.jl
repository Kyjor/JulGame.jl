# Reference: https://github.com/ocornut/imgui/tree/master/examples/example_sdl2_sdlrenderer2

module Editor
    using CImGui
    using CImGui.CSyntax
    using CImGui.CSyntax.CStatic
    using CImGui: ImVec2, ImVec4, IM_COL32, ImS32, ImU32, ImS64, ImU64
    using CImGui.CImGui
    using JulGame: MainLoop, Math, SceneLoaderModule, SDL2, UI
    using NativeFileDialog

    global sdlVersion = "2.0.0"
    global sdlRenderer = C_NULL
    global const BackendPlatformUserData = Ref{Any}(C_NULL)

    include(joinpath("..","..","Macros.jl"))

    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "ImGuiSDLBackend"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Components"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Utils"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Windows"); join=true)))

    function run()
        info = initSDLAndImGui()
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
        hierarchyEntitySelections = Bool[]
        hierarchyUISelections = Bool[]
        ##############################
        scenesLoadedFromFolder = Ref(String[])

        sceneWindowPos = ImVec2(0, 0)
        sceneWindowSize = ImVec2(startingSize.x, startingSize.y)
        quit = false
            try
                while !quit
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
                        CImGui.Begin("Scene List") 
                        txt = currentSceneMain === nothing ? "Load Scene" : "Change Scene"
                        CImGui.Text(txt)

                        for scene in scenesLoadedFromFolder[]
                            if CImGui.Button("$(scene)")
                                currentSceneName = SceneLoaderModule.get_scene_file_name_from_full_scene_path(scene)
                                if currentSceneMain === nothing
                                    currentSceneMain = load_scene(scene, renderer) 
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

                    @cstatic begin
                        CImGui.Begin("Scene")  
                            sceneWindowPos = CImGui.GetWindowPos()
                            sceneWindowSize = CImGui.GetWindowSize()
                            sceneWindowSize = ImVec2(sceneWindowSize.x - 30, sceneWindowSize.y - 35) # Magic numbers for the border of the imgui window. TODO: Make this dynamic if possible

                            CImGui.SameLine()
                            if sceneWindowSize.x != sceneTextureSize.x || sceneWindowSize.y != sceneTextureSize.y
                                SDL2.SDL_DestroyTexture(sceneTexture)
                                sceneTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, sceneWindowSize.x, sceneWindowSize.y)
                                sceneTextureSize = ImVec2(sceneWindowSize.x, sceneWindowSize.y)
                            end

                            CImGui.Image(sceneTexture, sceneTextureSize)
                            if CImGui.BeginDragDropTarget()
                                payload = CImGui.AcceptDragDropPayload("Scene")
                                if payload != C_NULL
                                    payload = unsafe_load(payload)
                                    println("payload: ", payload)
                                    @assert payload.DataSize == sizeof(Cint)
                                end
                                CImGui.EndDragDropTarget()
                            end
                        CImGui.End()
                    end
                    itemSelected = false
                    uiSelected = false

                        CImGui.Begin("Hierarchy") 
                        if CImGui.TreeNode("Entities") &&  currentSceneMain !== nothing
                            CImGui.SameLine()
                            ShowHelpMarker("This is a list of all entities in the scene. Click on an entity to select it.")
                            CImGui.SameLine()
                            if CImGui.BeginMenu("Add") # TODO: Move to own file as a function
                                CImGui.MenuItem("Add", C_NULL, false, false)
                                if CImGui.BeginMenu("New")
                                    if CImGui.MenuItem("Entity")
                                        currentSceneMain.createNewEntity()
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
                            ShowHelpMarker("Hold CTRL and click to select multiple items.")
                            if length(hierarchyEntitySelections) == 0 || length(hierarchyEntitySelections) != length(filteredEntities) || updateSelectionsBasedOnFilter
                                hierarchyEntitySelections=fill(false, length(filteredEntities))
                            end
                            
                            for n = eachindex(filteredEntities)
                                CImGui.PushID(n)

                                buf = "$(n): $(filteredEntities[n].name)"
                                if CImGui.Selectable(buf, hierarchyEntitySelections[n])
                                    # clear selection when CTRL is not held
                                    !unsafe_load(CImGui.GetIO().KeyCtrl) && fill!(hierarchyEntitySelections, false)
                                    hierarchyEntitySelections[n] ⊻= 1
                                    itemSelected = true
                                    currentSceneMain.selectedEntity = filteredEntities[n]
                                end
                                
                                # our entities are both drag sources and drag targets here!
                                if CImGui.BeginDragDropSource(CImGui.ImGuiDragDropFlags_None)
                                    @c CImGui.SetDragDropPayload("Entity", &n, sizeof(Cint)) # set payload to carry the index of our item (could be anything)
                                    CImGui.Text("Move $(filteredEntities[n].name)")
                                    CImGui.EndDragDropSource()
                                end
                                if CImGui.BeginDragDropTarget()
                                    payload = CImGui.AcceptDragDropPayload("Entity")
                                    if payload != C_NULL
                                        payload = unsafe_load(payload)
                                        println("payload: ", payload)
                                        @assert payload.DataSize == sizeof(Cint)
                                    end
                                    CImGui.EndDragDropTarget()
                                end

                                # Reorder entities: We can only reorder entities if the entiities are not being filtered
                                if length(filteredEntities) == length(currentSceneMain.scene.entities)
                                    CImGui.InvisibleButton("str_id: $(n)", ImVec2(500,3)) #Todo: Make this dynamic based on window size
                                    if CImGui.BeginDragDropTarget()
                                        payload = CImGui.AcceptDragDropPayload("Entity") 
                                        if payload != C_NULL
                                            payload = unsafe_load(payload)
                                            @assert payload.DataSize == sizeof(Cint)
                                            origin = unsafe_load(Ptr{Cint}(payload.Data))
                                            destination = n
                                            # Move the entity(origin) to the position after the entity at the destination index and adust the other entities accordingly. Use splicing to do this.
                                            move_entity(currentSceneMain.scene.entities, origin, destination)
                                        end
                                        CImGui.EndDragDropTarget()
                                    end
                                end


                                CImGui.PopID()
                            end

                            CImGui.PopStyleVar()
                            CImGui.Indent(CImGui.GetTreeNodeToLabelSpacing())
                            CImGui.TreePop()
                        end

                        CImGui.NewLine()
                        if CImGui.TreeNode("UI Elements") &&  currentSceneMain !== nothing
                            CImGui.SameLine()
                            if CImGui.BeginMenu("Add") # TODO: Move to own file as a function
                                CImGui.MenuItem("Add", C_NULL, false, false)
                                if CImGui.BeginMenu("New")
                                    if CImGui.MenuItem("TextBox")
                                        currentSceneMain.createNewTextBox() 
                                    end
                                    if CImGui.MenuItem("Screen Button")
                                        currentSceneMain.createNewScreenButton()
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

                    show_debug_window(String[])
                    
                    CImGui.Begin("Entity Inspector") 
                        # TODO: Fix this. I know this is bad. I'm sorry. I'll fix it later.
                        if currentSceneMain !== nothing && currentSceneMain.selectedEntity !== nothing && filteredEntities !== nothing && hierarchyEntitySelections !== nothing && indexin([currentSceneMain.selectedEntity], filteredEntities)[1] !== nothing && hierarchyEntitySelections[indexin([currentSceneMain.selectedEntity], filteredEntities)[begin]] == false
                            fill!(hierarchyEntitySelections, false)
                            hierarchyEntitySelections[indexin([currentSceneMain.selectedEntity], filteredEntities)[1]] = true
                        elseif itemSelected
                            currentSceneMain.selectedEntity = filteredEntities[indexin([true], hierarchyEntitySelections)[1]]
                        end
                        for entityIndex = eachindex(hierarchyEntitySelections)
                            if hierarchyEntitySelections[entityIndex] || currentSceneMain.selectedEntity == filteredEntities[entityIndex]
                                CImGui.PushID("AddMenu")
                                if CImGui.BeginMenu("Add")
                                    ShowEntityContextMenu(filteredEntities[entityIndex])
                                    CImGui.EndMenu()
                                end
                                CImGui.PopID()
                                CImGui.Separator()
                                for entityField in fieldnames(Entity)
                                    if length(filteredEntities) < entityIndex
                                        break
                                    end
                                    show_field_editor(filteredEntities[entityIndex], entityField)
                                end
              
                                CImGui.Separator()
                                if CImGui.Button("Duplicate") 
                                    push!(currentSceneMain.scene.entities, deepcopy(currentSceneMain.scene.entities[entityIndex]))
                                    # TODO: switch to duplicated entity
                                end

                                CImGui.Separator()
                                CImGui.Text("Delete Entity: NO CONFIRMATION")
                                if CImGui.Button("Delete")
                                    MainLoop.destroy_entity(currentSceneMain, currentSceneMain.scene.entities[entityIndex])
                                    break
                                end
                                
                                break # TODO: Remove this when we can select multiple entities and edit them all at once
                            end
                        end

                    CImGui.End()

                    CImGui.Begin("UI Inspector") 
                        # TODO: Fix this. I know this is bad. I'm sorry. I'll fix it later.
                        #if currentSceneMain !== nothing && currentSceneMain.selectedEntity !== nothing && filteredEntities !== nothing && hierarchyUISelections !== nothing && indexin([currentSceneMain.selectedEntity], filteredEntities)[1] !== nothing
                            # fill!(hierarchyUISelections, false)
                            #hierarchyUISelections[indexin([currentSceneMain.selectedEntity], filteredEntities)[1]] = true
                        #elseif uiSelected
                            # currentSceneMain.selectedEntity = filteredEntities[indexin([true], hierarchyUISelections)[1]]
                        #end
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
                                    MainLoop.DestroyUIElement(currentSceneMain.scene.uiElements[uiElementIndex])
                                    break
                                end
                                
                                break # TODO: Remove this when we can select multiple entities and edit them all at once
                            end
                        end
                    CImGui.End()


                    SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
                    SDL2.SDL_RenderClear(renderer)
                    #SDL2.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
                    gameInfo = currentSceneMain === nothing ? [] : currentSceneMain.gameLoop(Ref(UInt64(0)), Ref(UInt64(0)), true, Math.Vector2(sceneWindowPos.x + 8, sceneWindowPos.y + 25), Math.Vector2(sceneWindowSize.x, sceneWindowSize.y)) # Magic numbers for the border of the imgui window. TODO: Make this dynamic if possible
                    SDL2.SDL_SetRenderTarget(renderer, C_NULL)
                    SDL2.SDL_RenderClear(renderer)
                    
                    ShowGameControls()
                    
                    
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
                        currentSceneMain.input.pollInput()
                        quit = currentSceneMain.input.quit
                    end
                    #################################################

                    SDL2.SDL_RenderPresent(renderer);
                end
            catch e
                @warn "Error in renderloop!" exception=e
                Base.show_backtrace(stderr, catch_backtrace())
            finally
                ImGui_ImplSDLRenderer2_Shutdown();
                ImGui_ImplSDL2_Shutdown();

                CImGui.DestroyContext(ctx)
                SDL2.SDL_DestroyTexture(sceneTexture)
                SDL_DestroyRenderer(renderer);
                SDL2.SDL_DestroyWindow(window);
                SDL2.SDL_Quit()
        end
        # ================ CUT OFF
        SDL2.SDL_Quit()
        # ================ CUT OFF
    end

    function initSDLAndImGui()
        if SDL2.SDL_Init(SDL2.SDL_INIT_VIDEO | SDL2.SDL_INIT_TIMER | SDL2.SDL_INIT_GAMECONTROLLER) < 0
            println("failed to init: ", unsafe_string(SDL2.SDL_GetError()));
        end
        SDL2.SDL_SetHint(SDL2.SDL_HINT_IME_SHOW_UI, "1")

        window = SDL2.SDL_CreateWindow(
        "JulGame Editor v0.1.0", SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, 1920, 1080,
        SDL2.SDL_WINDOW_SHOWN | SDL2.SDL_WINDOW_RESIZABLE | SDL2.SDL_WINDOW_ALLOW_HIGHDPI
        )
        if window == C_NULL 
            println("Failed to create window: ", unsafe_string(SDL2.SDL_GetError()))
            return -1
        end

        renderer = SDL2.SDL_CreateRenderer(window, -1, SDL2.SDL_RENDERER_ACCELERATED)
        global sdlRenderer = renderer
        if (renderer == C_NULL)
            println("Failed to create renderer: ", unsafe_string(SDL2.SDL_GetError()))
        end

        ver = pointer(SDL2.SDL_version[SDL2.SDL_version(0,0,0)])
        SDL2.SDL_GetVersion(ver)
        global sdlVersion = string(unsafe_load(ver).major, ".", unsafe_load(ver).minor, ".", unsafe_load(ver).patch)
        println("SDL version: ", sdlVersion)
        sdlVersion = parse(Int32, replace(sdlVersion, "." => ""))

        ctx = CImGui.CreateContext()

        io = CImGui.GetIO()
        io.ConfigFlags = unsafe_load(io.ConfigFlags) | CImGui.ImGuiConfigFlags_DockingEnable #| CImGui.ImGuiConfigFlags_NavEnableKeyboard | CImGui.ImGuiConfigFlags_NavEnableGamepad
        io.BackendPlatformUserData = C_NULL
        ImGui_ImplSDL2_InitForSDLRenderer(window, renderer)
        ImGui_ImplSDLRenderer2_Init(renderer)
        clear_color = Cfloat[0.45, 0.55, 0.60, 0.01]

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
    function save_scene_event(entities, uiElements, projectPath::String, sceneName::String)
        event = @event begin
            SceneWriterModule.serialize_entities(entities, uiElements, projectPath, "$(sceneName)")
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
    function select_project_event(currentSceneMain, scenesLoadedFromFolder)
        event = @event begin
            if currentSceneMain === nothing 
                choose_folder_with_dialog() |> (dir) -> (scenesLoadedFromFolder[] = get_all_scenes_from_folder(dir))
            end
        end

        return event
    end

    function move_entity(entities, origin, destination)
        if origin == destination
            return
        end

        originEntity = splice!(entities, origin)
        if origin < destination
            # We need to adjust the destination index because we removed the origin entity
            # We only need to do this in the case where the origin index is less than the destination index, because the other way around, the destination index is already "adjusted" because the items before it are not shifted
            destination -= 1 
        end
        updatedEntities = [entities[destination], originEntity]
        
        splice!(entities, destination : destination, updatedEntities)
    end
end
Editor.run()