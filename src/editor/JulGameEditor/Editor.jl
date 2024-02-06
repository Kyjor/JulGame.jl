# Reference: https://github.com/ocornut/imgui/tree/master/examples/example_sdl2_sdlrenderer2

module Editor
    using CImGui
    using CImGui.CSyntax
    using CImGui.CSyntax.CStatic
    using CImGui: ImVec2, ImVec4, IM_COL32, ImS32, ImU32, ImS64, ImU64, LibCImGui
    using CImGui.LibCImGui
    using JulGame: MainLoop, Math, SceneLoaderModule, SDL2
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

        styleImGui()
        showDemoWindow = true
        ##############################
        # Project variables
        currentSceneMain = nothing
        currentSceneName = ""
        currentSelectedProjectPath = ""
        gameInfo = []
        ##############################
        # Text Input variables
        hierarchyFilterText::String = ""
        ##############################
        scenesLoadedFromFolder = Ref(String[])

        sceneWindowPos = ImVec2(0, 0)
        scenewindowSize = ImVec2(startingSize.x, startingSize.y)
        quit = false
            try
                while !quit
                    if currentSceneMain === nothing
                        quit = PollEvents()
                    end
                        
                    StartFrame()
                    LibCImGui.igDockSpaceOverViewport(C_NULL, ImGuiDockNodeFlags_PassthruCentralNode, C_NULL) # Creating the "dockspace" that covers the whole window. This allows the child windows to automatically resize.
                    
                    ################################## RENDER HERE
                    
                    ################################# MAIN MENU BAR
                    events = [save_scene_event(), select_project_event(currentSceneMain, scenesLoadedFromFolder)]
                    @c show_main_menu_bar(events)
                    ################################# END MAIN MENU BAR

                    @c CImGui.ShowDemoWindow(Ref{Bool}(showDemoWindow))

                    @cstatic begin
                        CImGui.Begin("Project") 
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
                                    change_scene(String(currentSceneName))
                                end
                            end
                            CImGui.NewLine()
                        end

                        CImGui.End()
                    end

                    if currentSceneMain !== nothing
                        @cstatic begin
                            CImGui.Begin("ResetCamera")  
                                CImGui.Button("ResetCamera") && (currentSceneMain.resetCameraPosition())
                            CImGui.End()
                        end
                    end
                    @cstatic begin
                        CImGui.Begin("Scene")  
                        sceneWindowPos = CImGui.GetWindowPos()
                        scenewindowSize = CImGui.GetWindowSize()
                        if scenewindowSize.x != sceneTextureSize.x || scenewindowSize.y != sceneTextureSize.y
                            SDL2.SDL_DestroyTexture(sceneTexture)
                            sceneTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, scenewindowSize.x, scenewindowSize.y)
                            sceneTextureSize = ImVec2(scenewindowSize.x, scenewindowSize.y)
                        end

                        CImGui.Image(sceneTexture, sceneTextureSize)
                        CImGui.End()
                    end

                    CImGui.Begin("Hierarchy") 
                        ShowHelpMarker("This is a list of all entities in the scene. Click on an entity to select it.")
                        CImGui.SameLine()
                        if CImGui.TreeNode("Entities") &&  currentSceneMain !== nothing
                            CImGui.Unindent(CImGui.GetTreeNodeToLabelSpacing())
                
                            for i in 1:length(currentSceneMain.scene.entities)
                                node_flags = CImGui.ImGuiTreeNodeFlags_Leaf | CImGui.ImGuiTreeNodeFlags_NoTreePushOnOpen # CImGui.ImGuiTreeNodeFlags_Bullet
                                CImGui.TreeNodeEx(Ptr{Cvoid}(i), node_flags, "$(i): $(currentSceneMain.scene.entities[i].name)")
                                CImGui.IsItemClicked() && (node_clicked = i; currentEntitySelectedIndex = i; currentEntityUpdated = true; currentTextBoxSelectedIndex = -1)
                            end
                            CImGui.PopStyleVar()
                            CImGui.Indent(CImGui.GetTreeNodeToLabelSpacing())
                            CImGui.TreePop()
                        end
                    CImGui.End()

                    CImGui.Begin("Filter") 
                    if CImGui.CollapsingHeader("Filtering")
                        CImGui.Text("Filter usage:\n"*
                                    "  \"\"         display all lines\n"*
                                    "  \"xxx\"      display lines containing \"xxx\"\n"*
                                    "  \"xxx,yyy\"  display lines containing \"xxx\" or \"yyy\"\n"*
                                    "  \"-xxx\"     hide lines containing \"xxx\"")
                        hierarchyFilterText = text_input_single_line("filter") 
                        lines = ["aaa1.c", "bbb1.c", "ccc1.c", "aaa2.cpp", "bbb2.cpp", "ccc2.cpp", "abc.h", "hello, world"]
                        filtered_lines = filter(line -> (contains(line, hierarchyFilterText) || isempty(hierarchyFilterText)), lines)
                        
                        for line in filtered_lines
                            CImGui.BulletText(line)
                        end
                    end
                    CImGui.End()















                    SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
                    SDL2.SDL_RenderClear(renderer)
                    #SDL2.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
                    gameInfo = currentSceneMain === nothing ? [] : currentSceneMain.gameLoop(Ref(UInt64(0)), Ref(UInt64(0)), true, C_NULL, Math.Vector2(sceneWindowPos.x + 8, sceneWindowPos.y + 25), Math.Vector2(scenewindowSize.x, scenewindowSize.y)) # Magic numbers for the border of the imgui window. TODO: Make this dynamic if possible
                    SDL2.SDL_SetRenderTarget(renderer, C_NULL)
                    SDL2.SDL_RenderClear(renderer)
                    
                    ShowGameControls()
                    
                    
                    ################################# STOP RENDERING HERE
                    CImGui.Render()
                    SDL2.SDL_RenderSetScale(renderer, unsafe_load(io.DisplayFramebufferScale.x), unsafe_load(io.DisplayFramebufferScale.y));
                    SDL2.SDL_SetRenderDrawColor(renderer, (UInt8)(round(clear_color[1] * 255)), (UInt8)(round(clear_color[2] * 255)), (UInt8)(round(clear_color[3] * 255)), (UInt8)(round(clear_color[4] * 255)));
                    SDL2.SDL_RenderClear(renderer);
                    ImGui_ImplSDLRenderer2_RenderDrawData(CImGui.GetDrawData())
                    screenA = Ref(SDL2.SDL_Rect(round(sceneWindowPos.x), sceneWindowPos.y + 20, scenewindowSize.x, scenewindowSize.y - 20))
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
        "JulGame Editor v0.1.0", SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, 1024, 768,
        SDL2.SDL_WINDOW_SHOWN | SDL2.SDL_WINDOW_OPENGL | SDL2.SDL_WINDOW_RESIZABLE | SDL2.SDL_WINDOW_ALLOW_HIGHDPI
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

    function styleImGui() 
        # setup Dear ImGui style #Todo: Make this a setting
        CImGui.StyleColorsDark()
        # CImGui.StyleColorsClassic()
        # CImGui.StyleColorsLight()
    end

    function PollEvents()
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

    function StartFrame()
        ImGui_ImplSDLRenderer2_NewFrame()
        ImGui_ImplSDL2_NewFrame();
        CImGui.NewFrame()
    end

    function save_scene_event()
        event = @event begin
            serializeEntities(entities, textBoxes, projectPath, "$(sceneName)")
        end

        return event
    end
    
    function select_project_event(currentSceneMain, scenesLoadedFromFolder)
        event = @event begin
            if currentSceneMain === nothing 
                choose_folder_with_dialog() |> (dir) -> (scenesLoadedFromFolder[] = get_all_scenes_from_folder(dir))
            end
        end

        return event
    end
end
Editor.run()