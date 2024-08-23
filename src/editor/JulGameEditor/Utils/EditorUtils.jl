function init_sdl_and_imgui()
    if SDL2.SDL_Init(SDL2.SDL_INIT_VIDEO | SDL2.SDL_INIT_TIMER | SDL2.SDL_INIT_GAMECONTROLLER) < 0
        println("failed to init: ", unsafe_string(SDL2.SDL_GetError()));
    end
    SDL2.SDL_SetHint(SDL2.SDL_HINT_IME_SHOW_UI, "1")

    window = SDL2.SDL_CreateWindow(
    "JulGame Editor v0.1.0", SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, 1280, 720,
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

function log_exceptions(error_type, latest_exceptions, e, is_test_mode)
    println("Error: ", e)
    Base.show_backtrace(stderr, catch_backtrace())
    push!(latest_exceptions, [e, String("$(Dates.now())")])
    if length(latest_exceptions) > 10
        deleteat!(latest_exceptions, 1)
    end
    if is_test_mode
        @warn "Error in renderloop!" exception=e
    end
end

function handle_drag_and_drop(filteredEntities, n, currentSceneMain, hierarchyEntitySelections)
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
                filteredEntities[origin].parent = filteredEntities[destination]
            end
            @assert payload.DataSize == sizeof(Cint)
        end
        CImGui.EndDragDropTarget()
    end

    # Reorder entities: We can only reorder entities if the entities are not being filtered
    if length(filteredEntities) == length(currentSceneMain.scene.entities)
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

function handle_childless_entity_selection(entity, hierarchyEntitySelections, entityIndex, currentSceneMain, filteredEntities = nothing)
    CImGui.PushID(entity.id)
    if CImGui.Selectable(entity.name, hierarchyEntitySelections[entityIndex][2])
        # clear selection when CTRL is not held
        (!unsafe_load(CImGui.GetIO().KeyCtrl) && !unsafe_load(CImGui.GetIO().KeyShift)) && deselect_all_entities(hierarchyEntitySelections)
        hierarchyEntitySelections[entityIndex] = (hierarchyEntitySelections[entityIndex][1], true)
        unsafe_load(CImGui.GetIO().KeyShift) && select_all_elements_in_between(hierarchyEntitySelections, entityIndex)
        currentSceneMain.selectedEntity = entity
    end
    if filteredEntities !== nothing
        # get the index of the selected entity in the filtered entities list
        itemSelected = indexin([entity], filteredEntities)[1]
        handle_drag_and_drop(filteredEntities, itemSelected, currentSceneMain, hierarchyEntitySelections)
    end 

    CImGui.PopID()
end

function handle_parent_entity_selection(entity, children, hierarchyEntitySelections, n, currentSceneMain, filteredEntities)
    if CImGui.TreeNodeEx(entity.name, CImGui.ImGuiTreeNodeFlags_None)
        for child in children
            handle_childless_entity_selection(child, hierarchyEntitySelections, n, currentSceneMain, filteredEntities)
        end
            if CImGui.BeginDragDropSource(CImGui.ImGuiDragDropFlags_None)
                @c CImGui.SetDragDropPayload("Entity", &n, sizeof(Cint)) # set payload to carry the index of our item (could be anything)
                CImGui.Text("Move $(entity.name)")
                CImGui.EndDragDropSource()
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
    end

    return event
end

function reset_camera_event(main)
    event = @event begin
        main.scene.camera.position = JulGame.Math.Vector2f(0, 0)
    end

    return event
end