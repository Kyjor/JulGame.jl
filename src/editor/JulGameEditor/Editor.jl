# Reference: https://github.com/ocornut/imgui/tree/master/examples/example_sdl2_sdlrenderer2

module Editor
    using CImGui
    using CImGui.CSyntax
    using CImGui.CSyntax.CStatic
    using CImGui: ImVec2, ImVec4, IM_COL32, ImS32, ImU32, ImS64, ImU64, LibCImGui
    using CImGui.LibCImGui
    using JulGame: Math, SDL2

    global sdlVersion = "2.0.0"
    global sdlRenderer = C_NULL
    global const BackendPlatformUserData = Ref{Any}(C_NULL)

    include(joinpath("ImGuiSDLBackend", "imgui_impl_sdl2.jl"))
    include(joinpath("ImGuiSDLBackend", "imgui_impl_sdlrenderer2.jl"))
    include(joinpath("..","..","Macros.jl"))
    include("MainMenuBar.jl")
    include("EntityContextMenu.jl")
    include("ComponentInputs.jl")
    include("TextBoxFields.jl")
    include("Utils.jl")
    include(joinpath("Components", "TextInputs.jl"))

    # Windows
    include(joinpath("Windows", "GameControls.jl"))

    function run()
        info = initSDLAndImGui()
        window, renderer, ctx, io, clear_color = info[1], info[2], info[3], info[4], info[5]
        startingSize = ImVec2(1920, 1080)
        sceneTexture = SDL2.SDL_CreateTexture(renderer, SDL2.SDL_PIXELFORMAT_BGRA8888, SDL2.SDL_TEXTUREACCESS_TARGET, startingSize.x, startingSize.y)# SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
        sceneTextureSize = ImVec2(startingSize.x, startingSize.y)

        styleImGui()
        showDemoWindow = true
        game = nothing
        gameInfo = []
        ##############################
        # Text Input variables
        projectText::String = ""
        ##############################


        sceneWindowPos = ImVec2(0, 0)
        scenewindowSize = ImVec2(startingSize.x, startingSize.y)
        quit = false
            try
                while !quit
                    if game === nothing
                        quit = PollEvents()
                    end
                        
                    StartFrame()
                    LibCImGui.igDockSpaceOverViewport(C_NULL, ImGuiDockNodeFlags_PassthruCentralNode, C_NULL) # Creating the "dockspace" that covers the whole window. This allows the child windows to automatically resize.
                    
                    ################################## RENDER HERE
                    
                    ################################# MAIN MENU BAR
                    events = CreateEvents()
                    @c ShowMainMenuBar(Ref{Bool}(true), events)
                    ################################# END MAIN MENU BAR

                    @c CImGui.ShowDemoWindow(Ref{Bool}(showDemoWindow))

                    @cstatic begin
                        CImGui.Begin("Load Project") 
                        if true    
                            CImGui.Text("Enter full path to root project folder")
                            projectText = text_input_single_line("Project Root Folder", projectText)
                            
                            CImGui.Button("Load Project Using Folder Path") && (scenesLoadedFromFolder = GetAllScenesFromFolder(projectText))
                            CImGui.NewLine()
                            CImGui.Button("Load Project using Dialog") && (ChooseFolderWithDialog() |> (dir) -> (scenesLoadedFromFolder = GetAllScenesFromFolder(dir)))

                            CImGui.Text("Load Scene:")
                            # for scene in scenesLoadedFromFolder
                            #     CImGui.Button("$(scene)") && (game = LoadScene(scene); projectPath = SceneLoaderModule.GetProjectPathFromFullScenePath(scene); sceneName = GetSceneFileNameFromFullScenePath(scene);)
                            #     CImGui.NewLine()
                            # end
                        else 
                            CImGui.Text("Scene loaded. Click 'Play' to run the game.")
                            CImGui.NewLine()
                            CImGui.Text("Change Scene:")
                            for scene in scenesLoadedFromFolder
                                CImGui.Button("$(scene)") && (sceneName = GetSceneFileNameFromFullScenePath(scene); ChangeScene(String(sceneName)))
                                CImGui.NewLine()
                            end
                        end

                        CImGui.End()
                    end

                    @cstatic begin
                        CImGui.Begin("Open Scene")  
                            CImGui.Button("Open") &&  (game = LoadScene("F:\\Projects\\Julia\\JulGame-Example\\Platformer\\scenes\\scene.json", renderer); JulGame.PIXELS_PER_UNIT = 16; game.autoScaleZoom = true)
                        CImGui.End()
                    end
                    
                    if game !== nothing
                        @cstatic begin
                            CImGui.Begin("ResetCamera")  
                                CImGui.Button("ResetCamera") && (game.resetCameraPosition())
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
                    SDL2.SDL_SetRenderTarget(renderer, sceneTexture)
                    SDL2.SDL_RenderClear(renderer)
                    #SDL2.SDL_SetRenderDrawColor(renderer, 0, 0, 0, 255);
                    gameInfo = game === nothing ? [] : game.gameLoop(Ref(UInt64(0)), Ref(UInt64(0)), true, C_NULL, Math.Vector2(sceneWindowPos.x + 8, sceneWindowPos.y + 25), Math.Vector2(scenewindowSize.x, scenewindowSize.y)) # Magic numbers for the border of the imgui window. TODO: Make this dynamic if possible
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
                    if game !== nothing
                        if game.input.editorCallback === nothing
                            game.input.editorCallback = ImGui_ImplSDL2_ProcessEvent
                        end
                        game.input.pollInput()
                        quit = game.input.quit
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

    function CreateEvents()
        event = @event begin
            serializeEntities(entities, textBoxes, projectPath, "$(sceneName)")
        end

        return [event]
    end

    function Render(renderer, io, clear_color)
        
    end

    function OpenScene(renderer)
        @cstatic begin
            CImGui.GetWindowPos()
            CImGui.Begin("Open Scene")  
                CImGui.Button("Open") &&  return LoadScene("F:\\Projects\\Julia\\JulGame-Example\\Platformer\\scenes\\scene.json", renderer)
            CImGui.End()
        end

        return C_NULL
    end

    function RenderScene()
        
    end

end
Editor.run()