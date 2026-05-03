module SceneBuilderModule
    using ...JulGame
    using ...UI
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

    const _JSON3_EMPTY_FIELDS = JSON3.read("{}")

    # JuliaC `--trim`: `uiElements` iteration stays `IUIElement`; narrow dispatch with concrete-parameter `@noinline` calls.
    @Base.noinline function _scenebuilder_align_to_anchor!(x::JulGame.UI.TextBoxModule.TextBox)::Nothing
        JulGame.align_to_anchor(x)
        return nothing
    end
    @Base.noinline function _scenebuilder_align_to_anchor!(x::JulGame.UI.ScreenButtonModule.ScreenButton)::Nothing
        JulGame.align_to_anchor(x)
        return nothing
    end
    @Base.noinline function _scenebuilder_align_to_anchor!(x::JulGame.UI.RectangleModule.Rectangle)::Nothing
        JulGame.align_to_anchor(x)
        return nothing
    end
    @Base.noinline function _scenebuilder_align_to_anchor!(x::JulGame.UI.LineModule.Line)::Nothing
        JulGame.align_to_anchor(x)
        return nothing
    end
    @Base.noinline function _scenebuilder_align_to_anchor!(x::JulGame.UI.CircleModule.Circle)::Nothing
        JulGame.align_to_anchor(x)
        return nothing
    end
    @Base.noinline function _scenebuilder_align_to_anchor!(x::JulGame.UI.ProgressBarModule.ProgressBar)::Nothing
        JulGame.align_to_anchor(x)
        return nothing
    end
    @Base.noinline function _scenebuilder_align_to_anchor!(x::JulGame.UI.CanvasModule.Canvas)::Nothing
        JulGame.align_to_anchor(x)
        return nothing
    end
    @Base.noinline function _scenebuilder_align_to_anchor!(x::JulGame.UI.UIImageModule.UIImage)::Nothing
        JulGame.align_to_anchor(x)
        return nothing
    end

    export Scene
    mutable struct Scene
        scene::String
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

    function _json3_string(obj::JSON3.Object, key::Symbol, default::String)::String
        v = get(obj, key, nothing)
        v === nothing && return default
        v isa String && return v
        v isa Symbol && return String(v)
        v isa Bool && return v ? "true" : "false"
        v isa Int && return string(v)
        v isa Int32 && return string(v)
        v isa Int16 && return string(v)
        v isa Int8 && return string(v)
        v isa UInt && return string(v)
        v isa UInt32 && return string(v)
        v isa UInt16 && return string(v)
        v isa UInt8 && return string(v)
        v isa Float64 && return string(v)
        v isa Float32 && return string(v)
        return default
    end

    function _json3_fields(obj::JSON3.Object)::JSON3.Object
        raw = get(obj, :fields, nothing)
        raw isa JSON3.Object && return raw
        return _JSON3_EMPTY_FIELDS
    end
    
    function load_and_prepare_scene(this::Scene, main = JulGame.MainLoop(); 
        config=parse_config(), 
        windowName::String="Game", 
        isWindowResizable::Bool=false, 
        preloadAllScenes::Bool=false,
        scalingQuality::String="linear"
    )
        JulGame.engine_states.current_state = :scene_change
        if config === nothing
            println(Core.stderr, "Config is nothing, parsing config")
            config = parse_config()
        else
            println(Core.stderr, "Config is not nothing, using provided config")
        end

        config = fill_in_config(config)

        windowName::String = windowName
        size = Math._Vector2{Int32}(
            Int32(parse(Int, string(get(config, "Width", DEFAULT_CONFIG["Width"])))),
            Int32(parse(Int, string(get(config, "Height", DEFAULT_CONFIG["Height"])))),
        )
        isResizable::Bool = isWindowResizable
        targetFrameRate::Int = parse(Int, string(get(config, "FrameRate", DEFAULT_CONFIG["FrameRate"])))
        isFullscreen::Bool = get(config, "Fullscreen", DEFAULT_CONFIG["Fullscreen"]) == "1"
        isVsyncEnabled::Bool = get(config, "Vsync", DEFAULT_CONFIG["Vsync"]) == "1"

        JulGame.MAIN = main
        main_loop = JulGame.current_main()
        main_loop.testMode = get(ENV, "TEST_MODE", "false") == "true"
        main_loop.testLength = parse(Float64, get(ENV, "TEST_LENGTH", "20.0"))
        main_loop.currentTestTime = 0.0
        main_loop.level = this
        main_loop.scene.name = split(this.scene, ".")[1]

        if size.x == 0 && size.y == 0
			displayMode = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
			SDL2.SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			size = Math._Vector2{Int32}(displayMode[1].w, displayMode[1].h)
		end
        
        
        scene = nothing
        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
            # Initialize window manager
            windowCreated = JulGame.WindowManagerModule.create_window(windowName, size, isFullscreen, isResizable)
            if !windowCreated
                println(Core.stderr, "Failed to create window")
                return
            end

            println(Core.stderr, "Window created")
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
            JulGame.SCALE_QUALITY = scalingQuality
            # "0" or "nearest": Nearest pixel sampling
            # "1" or "linear": Linear filtering (supported by OpenGL and Direct3D)
            # "2" or "best": Currently this is the same as "linear"

            SDL2.SDL_SetHint(SDL2.SDL_HINT_RENDER_SCALE_QUALITY, scalingQuality)
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer} = SDL2.SDL_CreateRenderer(main_loop.windowManager.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
            if JulGame.Renderer == C_NULL
                #println(Core.stderr, "Failed to create renderer with window $(main_loop.windowManager.window), $(unsafe_string(SDL2.SDL_GetError()))")
                @error "Failed to create renderer with window $(main_loop.windowManager.window), $(unsafe_string(SDL2.SDL_GetError()))"
            return
            end

            # Preload all scenes if requested
            if preloadAllScenes
                println(Core.stderr, "Preloading all scenes...")
                scenesDir = joinpath(BasePath, "scenes")
                if isdir(scenesDir)
                    for file in readdir(scenesDir)
                        if endswith(file, ".json")
                            scenePath = joinpath(scenesDir, file)
                            println(Core.stderr, "Preloading scene: $file")
                            SceneReaderModule.preload_scene(scenePath)
                        end
                    end
                    println(Core.stderr, "Finished preloading scenes")
                else
                    #println(Core.stderr, "Scenes directory not found: $scenesDir")
                    @error "Scenes directory not found: $scenesDir"
                end
            end
            
            # Set default texture scaling mode to linear
            SDL2.SDL_SetHint(SDL2.SDL_HINT_RENDER_SCALE_QUALITY, scalingQuality)
            
            # Apply additional window settings from config
            println(Core.stderr, "Setting frame rate to $(targetFrameRate)")
            JulGame.WindowManagerModule.set_frame_rate(targetFrameRate)
            println(Core.stderr, "Setting vsync to $(isVsyncEnabled)")
            JulGame.WindowManagerModule.set_vsync(isVsyncEnabled)
            
            println(Core.stderr, "Deserializing scene")
            # Use preloaded scene if available
            if preloadAllScenes && haskey(JulGame.PRELOADED_SCENES, this.scene)
                println(Core.stderr, "Using preloaded scene: $(this.scene)")
                scene = JulGame.PRELOADED_SCENES[this.scene]
            else
                scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
            end
            if scene === nothing
                @error "Failed to load scene \"$(this.scene)\" from $(joinpath(BasePath, "scenes", this.scene)) (file missing, unreadable, or invalid JSON)"
                println(Core.stderr, "Failed to load scene \"$(this.scene)\"  (file missing, unreadable, or invalid JSON)")
                return nothing
            end
            println(Core.stderr, "Scene loaded successfully")
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
        if scene === nothing
            @error "Failed to load scene \"$(this.scene)\" from $(joinpath(BasePath, "scenes", this.scene)) (file missing, unreadable, or invalid JSON)"
            return nothing
        end
        
        main_loop.scene.entities = scene[1]
        main_loop.scene.uiElements = scene[2]
        main_loop.scene.camera = scene[3]
        
        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
            @debug "Setting logical size to $(main_loop.scene.camera.size.x)x$(main_loop.scene.camera.size.y)"
            SDL2.SDL_RenderSetLogicalSize(JulGame.Renderer, main_loop.scene.camera.size.x, main_loop.scene.camera.size.y)
        end
        
        for uiElement in main_loop.scene.uiElements
            JulGame.UI.add_relationship_if_not_exists(uiElement)
            is_world_entity = getfield(JulGame.UI.relationship_instance(uiElement), :isWorldEntity)::Bool
            if !is_world_entity
                if uiElement isa TextBox
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.TextBoxModule.TextBox)
                elseif uiElement isa ScreenButton
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.ScreenButtonModule.ScreenButton)
                elseif uiElement isa Rectangle
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.RectangleModule.Rectangle)
                elseif uiElement isa Line
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.LineModule.Line)
                elseif uiElement isa Circle
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.CircleModule.Circle)
                elseif uiElement isa ProgressBar
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.ProgressBarModule.ProgressBar)
                elseif uiElement isa Canvas
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.CanvasModule.Canvas)
                elseif uiElement isa UIImage
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.UIImageModule.UIImage)
                end
            end
        end

        main_loop.scene.rigidbodies = InternalRigidbody[]
        main_loop.scene.colliders = InternalCollider[]
        JulGame.trim_call1(add_scripts_to_entities, BasePath)

        JulGame.engine_states.current_state = :game_mode
        JulGame.MainLoopModule.prepare_window_scripts_and_start_loop(size)
    end

    function deserialize_and_build_scene(this::Scene)
        main_loop = JulGame.current_main()
        scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
        
        @debug String("Changing scene to $(this.scene)")
        @debug String("Entities in main scene: $(length(main_loop.scene.entities))")

        if scene === nothing
            @error "Error deserialize_and_build_scene"
            return
        end

        for entity in scene[1]
            dup_entity = false
            for e in main_loop.scene.entities
                if (getfield(e, :id)::String == getfield(entity, :id)::String)
                    dup_entity = true
                    break
                end
            end
            if dup_entity
                @debug("duplicate entity found (persistence)")
            else
                push!(main_loop.scene.entities, entity)
            end
        end
        
        for uiElement in scene[2]
            dup_ui = false
            for e in main_loop.scene.uiElements
                if (getfield(e, :id)::String == getfield(uiElement, :id)::String)
                    dup_ui = true
                    break
                end
            end
            if dup_ui
                @debug("duplicate ui element found (persistence)")
            else
                push!(main_loop.scene.uiElements, uiElement)
            end
        end

        for uiElement in main_loop.scene.uiElements
            JulGame.UI.add_relationship_if_not_exists(uiElement)
            is_world_entity = getfield(JulGame.UI.relationship_instance(uiElement), :isWorldEntity)::Bool
            if is_world_entity
                if uiElement isa TextBox
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.TextBoxModule.TextBox)
                elseif uiElement isa ScreenButton
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.ScreenButtonModule.ScreenButton)
                elseif uiElement isa Rectangle
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.RectangleModule.Rectangle)
                elseif uiElement isa Line
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.LineModule.Line)
                elseif uiElement isa Circle
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.CircleModule.Circle)
                elseif uiElement isa ProgressBar
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.ProgressBarModule.ProgressBar)
                elseif uiElement isa Canvas
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.CanvasModule.Canvas)
                elseif uiElement isa UIImage
                    _scenebuilder_align_to_anchor!(uiElement::JulGame.UI.UIImageModule.UIImage)
                end
            end
        end

        main_loop.scene.camera = scene[3]

        for entity in main_loop.scene.entities
            if entity.persistentBetweenScenes #TODO: Verify if the entity is in it's first scene. If it is, don't skip the scripts.
                continue
            end
            
            if entity.rigidbody != C_NULL
                push!(main_loop.scene.rigidbodies, entity.rigidbody)
            end
            if entity.collider != C_NULL
                push!(main_loop.scene.colliders, entity.collider)
            end
        end 

        JulGame.trim_call1(add_scripts_to_entities, BasePath)
    end

    """
    create_new_entity(this::Scene)

    Create a new entity and add it to the scene.

    # Arguments
    - `this::Scene`: The scene object to which the entity will be added.

    """
    function create_new_entity(this::Scene)
        main_loop = JulGame.current_main()
        entity = Entity("New entity")
        push!(main_loop.scene.entities, entity)
        return entity
    end

    function create_new_text_box(this::Scene)
        main_loop = JulGame.current_main()
        textBox = TextBox("TextBox")
        JulGame.UI.initialize(textBox)
        push!(main_loop.scene.uiElements, textBox)
        return textBox
    end
    
    function create_new_screen_button(this::Scene)
        main_loop = JulGame.current_main()
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
        push!(main_loop.scene.uiElements, screenButton)
        return screenButton
    end

    function create_new_canvas(this::Scene)
        main_loop = JulGame.current_main()
        canvas = Canvas(
            name="New Canvas",
            size=Math.Vector2(400, 300),
            position=Math.Vector2(100, 100),
            color=(255, 255, 255, 100)  # Semi-transparent white
        )
        push!(main_loop.scene.uiElements, canvas)
        return canvas
    end

    function create_new_image(this::Scene)
        main_loop = JulGame.current_main()
        image = JulGame.UI.UIImageModule.UIImage(;
            size=Math.Vector2(400, 300),
            position=Math.Vector2(0, 0),
            color=(255, 255, 255, 100)
        )
        push!(main_loop.scene.uiElements, image)
        return image
    end

    function create_new_rectangle(this::Scene)
        main_loop = JulGame.current_main()
        rectangle = JulGame.UI.RectangleModule.Rectangle(;
            name="New Rectangle",
            size=Math.Vector2(400, 300),
            position=Math.Vector2(0, 0),
        )
        push!(main_loop.scene.uiElements, rectangle)
        return rectangle
    end

    if Base.JLOptions().trim != Int8(0)
        function add_scripts_to_entities(path::String)::Nothing
            return nothing
        end
    else
        include(joinpath(@__DIR__, "SceneBuilder_add_scripts_runtime.jl"))
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
            txt = read(filename, String)
            # Avoid readlines()/open-do (Julia Base): JuliaC trim verifiers choke on iterate(EachLine) + closure open.
            for raw in split(txt, '\n')
                isempty(strip(raw)) && continue
                line = strip(raw)
                parts = split(line, "=", limit = 2)
                if length(parts) == 2
                    key, value = parts[1], parts[2]
                    config[strip(key)] = strip(value)
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
        buf = IOBuffer()
        for (key, value) in config
            println(buf, "$(key)=$(value)")
        end
        data = take!(buf)
        # Avoid write(::String, ::AbstractVector): it uses open with a callable (JuliaC trim rejects _apply_iterate on open).
        io = Base.open(filename, "w")
        try
            write(io, data)
        finally
            close(io)
        end
        return nothing
    end
end # module

