module SceneBuilderModule
    using ...JulGame
    using ...CameraModule
    using ...ColliderModule
    using ...EntityModule
    using ...Math
    using ...RigidbodyModule
    using ...TextBoxModule
    using ...ScreenButtonModule
    using ...CanvasModule
    using ..SceneReaderModule
    using JSON3

    export Scene
    mutable struct Scene
        scene
        srcPath::String
        type::String

        function Scene(sceneFileName::String, srcPath::String = joinpath(pwd(), ".."), type::String="SDLRenderer")
            this = new()  

            this.scene = sceneFileName
            this.srcPath = srcPath 
            this.type = type
            path = Base.load_path()[1]
            JulGame.IS_PACKAGE_COMPILED = occursin("share", path) && occursin("Project.toml", path)
            if Sys.isapple() && JulGame.IS_PACKAGE_COMPILED
                srcPath = joinpath(join(split(path, "/")[1:findfirst(x -> x == "Build", split(path, "/"))], "/"))
            end

            JulGame.BasePath = srcPath
            if type == "Web"
                JulGame.IS_WEB = true
            end

            return this
        end    
    end
    
    function load_and_prepare_scene(this::Scene, main = JulGame.MainLoop(); 
        config=parse_config(), 
        windowName::String="Game", 
        isWindowResizable::Bool=false, 
        preloadAllScenes::Bool=false,
        scalingQuality::String="linear"
    )
        if config === nothing
            @debug("Config is nothing, parsing config")
            config = parse_config()
        else
            @debug("Config is not nothing, using provided config")
        end

        config = fill_in_config(config)

        windowName::String = windowName
        size::Vector2 = Vector2(parse(Int, string(get(config, "Width", DEFAULT_CONFIG["Width"]))), parse(Int, string(get(config, "Height", DEFAULT_CONFIG["Height"]))))
        isResizable::Bool = isWindowResizable
        targetFrameRate::Int = parse(Int, string(get(config, "FrameRate", DEFAULT_CONFIG["FrameRate"])))
        isFullscreen::Bool = get(config, "Fullscreen", DEFAULT_CONFIG["Fullscreen"]) == "1"
        isVsyncEnabled::Bool = get(config, "Vsync", DEFAULT_CONFIG["Vsync"]) == "1"

        JulGame.MAIN = main
        MAIN.testMode = get(ENV, "TEST_MODE", "false") == "true"
        MAIN.testLength = 20.0
        MAIN.currentTestTime = 0.0
        MAIN.level = this
        MAIN.scene.name = split(this.scene, ".")[1]

        if size == Math.Vector2()
			displayMode = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
			SDL2.SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			size = Math.Vector2(displayMode[1].w, displayMode[1].h)
		end
        
        
        scene = nothing
        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
            # Initialize window manager
            windowCreated = JulGame.WindowManagerModule.create_window(windowName, size, isFullscreen, isResizable)
            if !windowCreated
                @error "Failed to create window"
                return
            end
            
            # Create renderer
            # todo move to window manager
            # Enable high-quality scaling
            if scalingQuality == "nearest"
                scalingQuality = "0"
            elseif scalingQuality == "linear"
                scalingQuality = "1"
            elseif scalingQuality == "best"
                scalingQuality = "2"
            else
                scalingQuality = "2"
            end
            # "0" or "nearest": Nearest pixel sampling
            # "1" or "linear": Linear filtering (supported by OpenGL and Direct3D)
            # "2" or "best": Currently this is the same as "linear"

            SDL2.SDL_SetHint(SDL2.SDL_HINT_RENDER_SCALE_QUALITY, scalingQuality)
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer} = SDL2.SDL_CreateRenderer(MAIN.windowManager.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
            if JulGame.Renderer == C_NULL
                @error "Failed to create renderer with window $(MAIN.windowManager.window), $(unsafe_string(SDL2.SDL_GetError()))"
                return
            end

            # Preload all scenes if requested
            if preloadAllScenes
                @debug "Preloading all scenes..."
                scenesDir = joinpath(BasePath, "scenes")
                if isdir(scenesDir)
                    for file in readdir(scenesDir)
                        if endswith(file, ".json")
                            scenePath = joinpath(scenesDir, file)
                            @debug "Preloading scene: $file"
                            SceneReaderModule.preload_scene(scenePath)
                        end
                    end
                    @debug "Finished preloading scenes"
                else
                    @warn "Scenes directory not found: $scenesDir"
                end
            end
            
            # Set default texture scaling mode to linear
            SDL2.SDL_SetHint(SDL2.SDL_HINT_RENDER_SCALE_QUALITY, scalingQuality)
            
            # Apply additional window settings from config
            @debug "Setting frame rate to $(targetFrameRate)"
            JulGame.WindowManagerModule.set_frame_rate(targetFrameRate)
            @debug "Setting vsync to $(isVsyncEnabled)"
            JulGame.WindowManagerModule.set_vsync(isVsyncEnabled)
            
            @debug "Deserializing scene"
            # Use preloaded scene if available
            if preloadAllScenes && haskey(JulGame.PRELOADED_SCENES, this.scene)
                @debug "Using preloaded scene: $(this.scene)"
                scene = JulGame.PRELOADED_SCENES[this.scene]
            else
                scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
            end
            camera = scene[3]
            # Set logical rendering size based on camera
            @debug "Setting logical size to $(size.x)x$(size.y)"
            if camera !== nothing && camera.size.x > 0 && camera.size.y > 0
                JulGame.WindowManagerModule.set_logical_size(camera.size.x, camera.size.y)
            end
            
            # Set window icon if available
            iconPath = get(config, "Icon", "")
            if iconPath != ""
                JulGame.WindowManagerModule.set_window_icon(iconPath)
            end
        end

        if scene === nothing
            # Use preloaded scene if available
            if preloadAllScenes && haskey(JulGame.PRELOADED_SCENES, this.scene)
                @debug "Using preloaded scene: $(this.scene)"
                scene = JulGame.PRELOADED_SCENES[this.scene]
            else
                scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
            end
        end
        
        MAIN.scene.entities = scene[1]
        MAIN.scene.uiElements = scene[2]
        MAIN.scene.camera = scene[3]
        
        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
            @debug "Setting logical size to $(MAIN.scene.camera.size.x)x$(MAIN.scene.camera.size.y)"
            SDL2.SDL_RenderSetLogicalSize(JulGame.Renderer, MAIN.scene.camera.size.x, MAIN.scene.camera.size.y)
        end
        
        for uiElement in MAIN.scene.uiElements
            if "$(typeof(uiElement))" == "JulGame.UI.TextBoxModule.Textbox" && !uiElement.isWorldEntity
                UI.align_to_anchor(uiElement)
            end
        end

        MAIN.scene.rigidbodies = InternalRigidbody[]
        MAIN.scene.colliders = InternalCollider[]
        add_scripts_to_entities(BasePath)

        JulGame.MainLoopModule.prepare_window_scripts_and_start_loop(size)
    end

    function deserialize_and_build_scene(this::Scene)
        scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
        
        @debug String("Changing scene to $(this.scene)")
        @debug String("Entities in main scene: $(length(MAIN.scene.entities))")

        if scene === nothing
            @error "Error deserialize_and_build_scene"
            return
        end

        for entity in scene[1]
            if !any(e.id == entity.id for e in MAIN.scene.entities)
                push!(MAIN.scene.entities, entity)
            else
                @debug("duplicate entity found (persistence)")
            end
        end
        
        for uiElement in scene[2]
            if !any(e.id == uiElement.id for e in MAIN.scene.uiElements)
                push!(MAIN.scene.uiElements, uiElement)
            else
                @debug("duplicate ui element found (persistence)")
            end
        end

        for uiElement in MAIN.scene.uiElements
            if "$(typeof(uiElement))" == "JulGame.UI.TextBoxModule.Textbox" && uiElement.isWorldEntity
                UI.align_to_anchor(uiElement)
            end
        end

        MAIN.scene.camera = scene[3]

        for entity in MAIN.scene.entities
            if entity.persistentBetweenScenes #TODO: Verify if the entity is in it's first scene. If it is, don't skip the scripts.
                continue
            end
            
            if entity.rigidbody != C_NULL
                push!(MAIN.scene.rigidbodies, entity.rigidbody)
            end
            if entity.collider != C_NULL
                push!(MAIN.scene.colliders, entity.collider)
            end
        end 

        add_scripts_to_entities(BasePath)
    end

    """
    create_new_entity(this::Scene)

    Create a new entity and add it to the scene.

    # Arguments
    - `this::Scene`: The scene object to which the entity will be added.

    """
    function create_new_entity(this::Scene)
        push!(MAIN.scene.entities, Entity("New entity"))
    end

    function create_new_text_box(this::Scene)
        textBox = TextBox("TextBox")
        JulGame.UI.initialize(textBox)
        push!(MAIN.scene.uiElements, textBox)
    end
    
    function create_new_screen_button(this::Scene)
        screenButton = ScreenButton(
            nothing; # No click event defined here by default
            name="New Button", 
            buttonUpSpritePath="ButtonUp.png", 
            buttonDownSpritePath="ButtonDown.png", 
            size=Math.Vector2(256, 64), 
            position=Math.Vector2(0, 0), 
            fontPath=joinpath("FiraCode-Regular.ttf"),
            # text="", # Default
            # textOffset=Math.Vector2(0,0), # Default
            # Other parameters use defaults (anchor, layer, color, fontSize, etc.)
        )
        if !screenButton.isInitialized
            JulGame.initialize(screenButton)
        end
        push!(MAIN.scene.uiElements, screenButton)
    end

    function create_new_canvas(this::Scene)
        canvas = Canvas(
            name="New Canvas",
            size=Math.Vector2(400, 300),
            position=Math.Vector2(100, 100),
            color=(255, 255, 255, 100)  # Semi-transparent white
        )
        push!(MAIN.scene.uiElements, canvas)
    end

    function create_new_image(this::Scene)
        image = JulGame.UI.UIImageModule.UIImage(;
            size=Math.Vector2(400, 300),
            position=Math.Vector2(0, 0),
            color=(255, 255, 255, 100)
        )
        push!(MAIN.scene.uiElements, image)
    end

    function add_scripts_to_entities(path::String)
        @debug string("Adding scripts to entities")
        @debug string("Path: ", path)
        @debug string("Entities: ", length(MAIN.scene.entities))
        
        # Track which scripts we've already loaded
        
        # Only load scripts for non-persistent entities or if package is not compiled
        if !JulGame.IS_PACKAGE_COMPILED
            @info "Package not compiled, loading scripts"
            @time begin
                count = 0
            foreach(file -> try
                if !(file in JulGame.LoadedScripts)
                    @debug("Loading $file")
                    @time Base.include(JulGame.ScriptModule, file)
                    @debug("Finished loading $file")
                    push!(JulGame.LoadedScripts, file)
                end
            catch e
                @error("Error including $file: ", e)
                end, filter(contains(r".jl$"), readdir(joinpath(path, "scripts"); join=true)))
            end
            @info "Finished loading scripts"
        end

        if JulGame.ProjectModule != ""
            @debug "Loading scripts from project module: $(JulGame.ProjectModule)"
            scripts_mod = filter(x -> occursin(r"\.Scripts$", string(x)), ccall(:jl_module_usings, Any, (Any,), getfield(Main, Symbol("$(JulGame.ProjectModule)"))))
            if scripts_mod !== nothing && length(scripts_mod) > 0
                JulGame.ScriptModule = scripts_mod[1]
            end
        end

        for entity in MAIN.scene.entities
            scriptCounter = 1
            for script in entity.scripts
                if !isa(script, JSON3.Object)
                    # Skip script reloading for persistent entities
                    scriptCounter += 1
                    continue
                end
                @debug String("Adding script: $(script.name) to entity: $(entity.name)")

                newScript = nothing
                try
                    module_name = getfield(JulGame.ScriptModule, Symbol("$(script.name)Module"))
                    constructor = Base.invokelatest(getfield, module_name, Symbol(script.name)) 
                    newScript = Base.invokelatest(constructor)
                    scriptFields = get(script, "fields", Dict())
                    @debug("getting fields for: $(script)")
                    for (key, value) in scriptFields
                        ftype = nothing
                        try
                            ftype = fieldtype(typeof(newScript), Symbol(key))
                            @debug("type: $(ftype)")
                            if ftype <: EditorExport
                                @debug "Overwriting $(key) to $(value) using scene file"
                                # Get the wrapped type from EditorExport{T}
                                underlying_type = ftype.parameters[1]
                                Base.invokelatest(setfield!, newScript, key, EditorExport(convert(underlying_type, value)))
                                continue
                            elseif value === nothing
                                @debug "Value is nothing"
                                continue
                            end
                        catch e
                            @warn string(e)
                        end
                    end
                catch e
                    @error string(e)
                    Base.show_backtrace(stdout, catch_backtrace())
                end
                if newScript != C_NULL && newScript !== nothing
                    entity.scripts[scriptCounter] = newScript
                    newScript.parent = entity
                end
                scriptCounter += 1
            end
        end
    end

    # Define default configuration values
    const DEFAULT_CONFIG = Dict(
        "Width" => "800",
        "Height" => "600",
        "FrameRate" => "60",
        "Fullscreen" => "0",
        "Vsync" => "0"
    )

    # Function to read and parse the config file
    function parse_config()
        @debug "Parsing config at $(JulGame.BasePath)"
        filename = joinpath(JulGame.BasePath, "config.julgame")
        config = copy(DEFAULT_CONFIG)
        
        if isfile(filename)
            # Open the file for reading
            open(filename, "r") do file
                for line in eachline(file)
                    # Split the line at the '=' character
                    parts = split(line, "=", limit=2)
                    if length(parts) == 2
                        key, value = parts[1], parts[2]
                        # Strip any extra whitespace and add to dictionary
                        config[strip(key)] = strip(value)
                    end
                end
            end
        end

        write_config(filename, config)
        
        return config
    end

    function fill_in_config(config)
        @debug "Filling in config"
        for (key, value) in DEFAULT_CONFIG
            if !haskey(config, key)
                config[key] = value
            end
        end

        return config
    end

    # Function to write values to the config file
    function write_config(filename::String, config::Dict{String, String})
        @debug "Writing config to $(filename)"
        # Open the file for writing
        open(filename, "w") do file
            for (key, value) in config
                # Write each key-value pair to the file
                println(file, "$key=$value")
            end
        end
    end
end # module

