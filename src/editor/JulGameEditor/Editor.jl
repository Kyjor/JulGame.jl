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
    using STBImage

    global sdlVersion = "2.0.0"
    global sdlRenderer = C_NULL
    global const BackendPlatformUserData = Ref{Any}(C_NULL)

    include(joinpath("..","..","Macros.jl"))

    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "ImGuiSDLBackend"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Components"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Utils"); join=true)))
    include.(filter(contains(r".jl$"), readdir(joinpath(@__DIR__, "Windows"); join=true)))

    mutable struct ImageHolder
        animator::AnimatorModule.Animator
        endingY::Int32
        isMovingUp::Bool
        rotation::Int32
        parent::JulGame.EntityModule.Entity
        sound::SoundSourceModule.SoundSource
        speed::Number
        startingY::Int32
    
        function Saw(speed::Number = 5, startingY::Int32 = Int32(0), endingY::Int32 = Int32(0))
            this = new()
    
            this.endingY = endingY
            this.isMovingUp = false
            this.rotation = 0
            this.speed = speed
            this.startingY = startingY
    
            return this
        end
    end

    function run(isTestMode::Bool=false)
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
        hierarchyEntitySelections = Bool[]
        hierarchyUISelections = Bool[]
        ##############################
        scenesLoadedFromFolder = Ref(String[])
        latest_exceptions = []

        sceneWindowPos = ImVec2(0, 0)
        sceneWindowSize = ImVec2(startingSize.x, startingSize.y)
        testFrameCount = 0
        testFrameLimit = 100
        quit = false



        my_image_width = Ref{Cint}()
        my_image_height = Ref{Cint}()
        my_texture = Ref{Ptr{SDL2.SDL_Texture}}()
        data = nothing
        ret, my_texture[], my_image_width[], my_image_height[], data = load_texture_from_file(joinpath("F:\\Projects\\Julia\\JulGame-Example\\Platformer\\assets\\images\\Bee.png"), renderer)
        println("data = ", data)
        # unwrap data into array
        data = unsafe_wrap(Array, data, 10000; own=false)
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

                    
                    
                    
                    if unsafe_load(io.KeyShift) # && unsafe_load(io.MouseDown)[1] && mouseUVCoord.x >= 0.0 && mouseUVCoord.y >= 0.0
                        try
                            CImGui.Begin("SDL2/SDL_Renderer Texture Test")
                            CImGui.Text(string("pointer = %p", my_texture))
                            CImGui.Text(string("size = %d x %d", my_image_width[], my_image_height[]))
                            CImGui.Image(my_texture[], ImVec2(my_image_width[], my_image_height[]))
                            # CImGui.ImageButton(pickerImage.textureID, ImVec2(pickerImage.mWidth, pickerImage.mHeight))
                            rc = CImGui.ImRect(CImGui.GetItemRectMin(), CImGui.GetItemRectMax())
                            mouseUVCoord = ImVec2(unsafe_load(io.MousePos).x - rc.Min.x / get_size(rc).x, unsafe_load(io.MousePos).y - rc.Min.y / get_size(rc).y) 
                            mouseUVCoord = ImVec2(mouseUVCoord.x, 1.0 - mouseUVCoord.y)
                            CImGui.Text("Mouse Position:")
                            CImGui.SameLine()
                            CImGui.Text(string("x = %d, y = %d", unsafe_load(io.MousePos).x, unsafe_load(io.MousePos).y))
                            # mouseUVCoord = ImVec2(unsafe_load(io.MousePos).x, unsafe_load(io.MousePos).y)
                            #mouseUVCoord = ImVec2(1, 1)
                            displayedTextureSize = ImVec2(unsafe_load(io.DisplaySize).x, unsafe_load(io.DisplaySize).y)
                            inspect(Int64(my_image_width[]), Int64(my_image_height[]), data, mouseUVCoord::ImVec2, displayedTextureSize::ImVec2)
                            println("test: ", my_texture[])
                        CImGui.End()
                    catch e 
                        @error "Error" exception=e
                        Base.show_backtrace(stderr, catch_backtrace())
                    end
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

                    try
                        CImGui.Begin("Hierarchy") 
                        if CImGui.TreeNode("Entities") &&  currentSceneMain !== nothing
                            CImGui.SameLine()
                            ShowHelpMarker("This is a list of all entities in the scene. Click on an entity to select it.")
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
                    catch e
                        log_exceptions("Entity Inspector Window Error:", latest_exceptions, e, is_test_mode)
                    end

                    try
                        
                   
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
                    catch e
                        log_exceptions("UI Inspector Window Error:", latest_exceptions, e, isTestMode)
                    end

                    SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
                    SDL2.SDL_RenderClear(renderer)
                    gameInfo = currentSceneMain === nothing ? [] : JulGame.MainLoop.game_loop(currentSceneMain, Ref(UInt64(0)), Ref(UInt64(0)), true, Math.Vector2(sceneWindowPos.x + 8, sceneWindowPos.y + 25), Math.Vector2(sceneWindowSize.x, sceneWindowSize.y)) # Magic numbers for the border of the imgui window. TODO: Make this dynamic if possible
                    SDL2.SDL_SetRenderTarget(renderer, C_NULL)
                    SDL2.SDL_RenderClear(renderer)
                    
                    show_game_controls()
                    
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
                    if isTestMode && testFrameCount < testFrameLimit
                        testFrameCount += 1
                    elseif isTestMode
                        quit = true
                    end
                catch e 
                    @error "Error in renderloop!" exception=e
                    Base.show_backtrace(stderr, catch_backtrace())
                end
            end
        catch e
            backup_file_name = backup_file_name = "$(replace(currentSceneName, ".json" => ""))-backup-$(replace(Dates.format(Dates.now(), "yyyy-mm-ddTHH:MM:SS"), ":" => "-")).json"
            println("Backup file name: ", backup_file_name)
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

    function init_sdl_and_imgui()
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

    function log_exceptions(error_type, latest_exceptions, e, is_test_mode)
        println("Error: $(is_test_mode): ", e)
        push!(latest_exceptions, [e, String("$(Dates.now())")])
        if length(latest_exceptions) > 10
            deleteat!(latest_exceptions, 1)
        end
        if is_test_mode
            @warn "Error in renderloop!" exception=e
        end
    end

    function load_texture_from_file(filename::String, renderer::Ptr{SDL2.SDL_Renderer})
        width = Ref{Cint}()
        height = Ref{Cint}()
        channels = Ref{Cint}()
        
        data = STBImage.stbi_load(filename, width, height, channels, 0)
        
        if data == C_NULL
            @error "Failed to load image: $(STBImage.stbi_failure_reason())"
            return false, C_NULL, 0, 0
        end
        
        surface = SDL2.SDL_CreateRGBSurfaceFrom(data, width[], height[], channels[] * 8, channels[] * width[],
                                           0x000000ff, 0x0000ff00, 0x00ff0000, 0xff000000)
        
        if surface == C_NULL
            @error "Failed to create SDL surface: $(unsafe_string(SDL2.SDL_GetError()))"
            STBImage.stbi_image_free(data)
            return false, C_NULL, 0, 0
        end
        
        texture_ptr = SDL2.SDL_CreateTextureFromSurface(renderer, surface)
        
        if texture_ptr == C_NULL
            @error "Failed to create SDL texture: $(unsafe_string(SDL2.SDL_GetError()))"
        end
        
        SDL2.SDL_FreeSurface(surface)
        STBImage.stbi_image_free(data)
        
        return true, texture_ptr, width[], height[], data
    end

    function histogram(width::Int, height::Int, bits::Vector{UInt8})
        count = fill(0, 4, 256)
    
        ptrCols = 1
        CImGui.InvisibleButton("histogram", ImVec2(512, 256))
        for l in 1:(height * width)
            count[1, bits[ptrCols] + 1] += 1
            ptrCols += 1
            count[2, bits[ptrCols] + 1] += 1
            ptrCols += 1
            count[3, bits[ptrCols] + 1] += 1
            ptrCols += 1
            count[4, bits[ptrCols] + 1] += 1
            ptrCols += 1
        end
    
        maxv = maximum(count[1, :])
    
        drawList = CImGui.GetWindowDrawList()
        rmin = CImGui.GetItemRectMin()
        rmax = CImGui.GetItemRectMax()
        size = CImGui.GetItemRectSize()
        hFactor = size.y / float(maxv)
    
        for i in 0:10
            ax = rmin.x + (size.x / 10.0) * float(i)
            ay = rmin.y + (size.y / 10.0) * float(i)
            CImGui.AddLine(drawList, ImVec2(rmin.x, ay), ImVec2(rmax.x, ay), 0x80808080)
            CImGui.AddLine(drawList, ImVec2(ax, rmin.y), ImVec2(ax, rmax.y), 0x80808080)
        end
    
        barWidth = size.x / 256.0
        for j in 1:256
            cols = [(count[1, j] << 2), (count[2, j] << 2) + 1, (count[3, j] << 2) + 2]
            sort!(cols)
            heights = [rmax.y - (cols[i] >> 2) * hFactor for i in 1:3]
            colors = [0xFFFFFFFF, 0xFFFFFFFF - 0xFF << ((cols[i] & 3) * 8) for i in 1:3]
    
            currentHeight = rmax.y
            left = rmin.x + barWidth * float(j)
            right = left + barWidth
            for i in 1:3
                if heights[i] >= currentHeight
                    continue
                end
                CImGui.AddRectFilled(drawList, ImVec2(left, currentHeight), ImVec2(right, heights[i]), colors[i])
                currentHeight = heights[i]
            end
        end
    end
    
    function drawNormal(draw_list, rc, x, y)
        center = get_center(rc)
        width = get_width(rc)

        CImGui.AddCircle(draw_list, center, width / 2.0, 0x20AAAAAA, 24, 1.0)
        CImGui.AddCircle(draw_list, center, width / 4.0, 0x20AAAAAA, 24, 1.0)
        CImGui.AddLine(draw_list, center, ImVec2(center.x + x * width / 2.0, center.y + y * width / 2.0), 0xFF0000FF, 2.0)
    end
    
    function inspect(width::Int, height::Int, bits::Vector{UInt8}, mouseUVCoord::ImVec2, displayedTextureSize::ImVec2)
        CImGui.BeginTooltip()
        CImGui.BeginGroup()
        draw_list = CImGui.GetWindowDrawList()
        zoomRectangleWidth = 160.0
    
        CImGui.InvisibleButton("AnotherInvisibleMan", ImVec2(zoomRectangleWidth, zoomRectangleWidth))
        pickRc = CImGui.ImRect(CImGui.GetItemRectMin(), CImGui.GetItemRectMax())
        CImGui.AddRectFilled(draw_list, pickRc.Min, pickRc.Max, 0xFF000000)
        zoomSize = 4
        quadWidth = zoomRectangleWidth / float(zoomSize * 2 + 1)
        quadSize = ImVec2(quadWidth, quadWidth)
        basex = clamp(Int(mouseUVCoord.x * width), zoomSize, width - zoomSize)
        basey = clamp(Int(mouseUVCoord.y * height), zoomSize, height - zoomSize)
        for y in -zoomSize:zoomSize
            for x in -zoomSize:zoomSize
                texel = Int32(bits[(basey - y) * width + x + basex])
                pos =  ImVec2(pickRc.Min.x + float(x + zoomSize) * quadSize.x, pickRc.Min.y + float(y + zoomSize) * quadSize.y)
                CImGui.AddRectFilled(draw_list, pos, ImVec2(pos.x + quadSize.x, pos.y + quadSize.y), texel)
            end
        end
        CImGui.SameLine()
    
        pos = ImVec2(pickRc.Min.x + float(zoomSize) * quadSize.x, pickRc.Min.y + float(zoomSize) * quadSize.y)
        CImGui.AddRect(draw_list, pos, ImVec2(pos.x + quadSize.x, pos.y + quadSize.y), 0xFF0000FF, 0.0, 15, 2.0)
    
        CImGui.InvisibleButton("AndOneMore", ImVec2(zoomRectangleWidth, zoomRectangleWidth))
        normRc = CImGui.ImRect(CImGui.GetItemRectMin(), CImGui.GetItemRectMax())
        for y in -zoomSize:zoomSize
            for x in -zoomSize:zoomSize
                texel = Int32(bits[(basey - y) * width + x + basex])
                posQuad = ImVec2(normRc.Min.x + float(x + zoomSize) * quadSize.x, normRc.Min.y + float(y + zoomSize) * quadSize.y) 
                nx = float(texel & 0xFF) / 128.0 - 1.0
                ny = float((texel & 0xFF00) >> 8) / 128.0 - 1.0
                rc = CImGui.ImRect(posQuad, ImVec2(posQuad.x + quadSize.x, posQuad.y + quadSize.y))
                drawNormal(draw_list, rc, nx, ny)
            end
        end
    
        CImGui.EndGroup()
        CImGui.SameLine()
        CImGui.BeginGroup()
        texel = UInt32(bits[(basey - zoomSize * 2 - 1) * width + basex])
        color = CImGui.ImColor(texel)
        colHSV = ImVec4(0,0,0,0)

        CImGui.ColorConvertRGBtoHSV(color.Value.x, color.Value.y, color.Value.z, Ref{Float32}(colHSV.x), Ref{Float32}(colHSV.y), Ref{Float32}(colHSV.z))
        CImGui.Text(string("U %1.3f V %1.3f", mouseUVCoord.x, mouseUVCoord.y))
        CImGui.Text(string("Coord %d %d", Int(mouseUVCoord.x * width), Int(mouseUVCoord.y * height)))
        CImGui.Separator()
        CImGui.Text(string("R 0x%02x  G 0x%02x  B 0x%02x", Int(color.Value.x * 255.0), Int(color.Value.y * 255.0), Int(color.Value.z * 255.0)))
        CImGui.Text(string("R %1.3f G %1.3f B %1.3f", color.Value.x, color.Value.y, color.Value.z))
        CImGui.Separator()
        CImGui.Text(string("H 0x%02x  S 0x%02x  V 0x%02x", Int(colHSV.x * 255.0), Int(colHSV.y * 255.0), Int(colHSV.z * 255.0)))
        CImGui.Text(string("H %1.3f S %1.3f V %1.3f", colHSV.x, colHSV.y, colHSV.z))
        CImGui.Separator()
        CImGui.Text(string("Alpha 0x%02x", Int(color.Value.w * 255.0)))
        CImGui.Text(string("Alpha %1.3f", color.Value.w))
        CImGui.Separator()
        CImGui.Text(string("Size %d, %d", Int(displayedTextureSize.x), Int(displayedTextureSize.y)))
        CImGui.EndGroup()
        histogram(width, height, bits)
        CImGui.EndTooltip()
    end

    function get_center(rc::CImGui.ImRect)
        return ImVec2((rc.Min.x + rc.Max.x) * 0.5, (rc.Min.y + rc.Max.y) * 0.5)
    end

    function get_width(rc::CImGui.ImRect)
        return rc.Max.x - rc.Min.x
    end

    function get_size(rc::CImGui.ImRect)
        return ImVec2(rc.Max.x - rc.Min.x, rc.Max.y - rc.Min.y)
    end
end
