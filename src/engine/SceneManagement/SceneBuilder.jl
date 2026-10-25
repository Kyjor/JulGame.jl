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
    using ...JulGame.SceneJSON

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
    
    function load_and_prepare_scene(this::Scene, main = JulGame.MainLoop(); 
        config::Union{Dict{String, String}, Nothing}=parse_config(), 
        windowName::String="Game", 
        isWindowResizable::Bool=false, 
        preloadAllScenes::Bool=false,
        scalingQuality::String="linear"
    )
        JulGame.engine_states.current_state = :scene_change
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
        JulGame.main_loop().testMode = get(ENV, "TEST_MODE", "false") == "true"
        JulGame.main_loop().testLength = parse(Float64, get(ENV, "TEST_LENGTH", "20.0"))
        JulGame.main_loop().currentTestTime = 0.0
        JulGame.main_loop().level = this
        JulGame.main_loop().scene.name = split(this.scene, ".")[1]

        if size == Math.Vector2()
			displayMode = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
			SDL2.SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			size = Math.Vector2(displayMode[1].w, displayMode[1].h)
		end
        
        
        scene::Union{SceneData, Nothing} = nothing
        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
            # Initialize window manager
            @timed_step "scene load: create window" windowCreated = JulGame.WindowManagerModule.create_window(windowName, size, isFullscreen, isResizable)
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
            JulGame.SCALE_QUALITY = scalingQuality
            # "0" or "nearest": Nearest pixel sampling
            # "1" or "linear": Linear filtering (supported by OpenGL and Direct3D)
            # "2" or "best": Currently this is the same as "linear"

            SDL2.SDL_SetHint(SDL2.SDL_HINT_RENDER_SCALE_QUALITY, scalingQuality)
            @timed_step "scene load: create renderer" createdRenderer = SDL2.SDL_CreateRenderer(JulGame.main_loop().windowManager.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer} = createdRenderer
            if JulGame.Renderer == C_NULL
                @error "Failed to create renderer with window $(JulGame.main_loop().windowManager.window), $(unsafe_string(SDL2.SDL_GetError()))"
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
            # deserialize_scene returns a preloaded scene if there is one
            @timed_step "scene load: deserialize scene" scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
            if scene === nothing
                @error "Failed to load scene $(this.scene)"
                return
            end
            camera = scene.camera
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
            scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
            if scene === nothing
                @error "Failed to load scene $(this.scene)"
                return
            end
        end
        
        JulGame.main_loop().scene.entities = scene.entities
        JulGame.main_loop().scene.uiElements = scene.uiElements
        JulGame.main_loop().scene.camera = scene.camera
        
        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
            @debug "Setting logical size to $(JulGame.main_loop().scene.camera.size.x)x$(JulGame.main_loop().scene.camera.size.y)"
            SDL2.SDL_RenderSetLogicalSize(JulGame.Renderer, JulGame.main_loop().scene.camera.size.x, JulGame.main_loop().scene.camera.size.y)
        end
        
        JulGame.main_loop().scene.rigidbodies = InternalRigidbody[]
        JulGame.main_loop().scene.colliders = InternalCollider[]
        @timed_step "scene load: add_scripts_to_entities" add_scripts_to_entities(BasePath)

        JulGame.engine_states.current_state = :game_mode
        JulGame.MainLoopModule.prepare_window_scripts_and_start_loop(size)
    end

    function any_id(elements, id::String)::Bool
        for element in elements
            element.id == id && return true
        end
        return false
    end

    function deserialize_and_build_scene(this::Scene)
        scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
        
        @debug String("Changing scene to $(this.scene)")
        @debug String("Entities in main scene: $(length(JulGame.main_loop().scene.entities))")

        if scene === nothing
            @error "Error deserialize_and_build_scene"
            return
        end

        for entity in scene.entities
            if !any_id(JulGame.main_loop().scene.entities, entity.id)
                push!(JulGame.main_loop().scene.entities, entity)
            else
                @debug("duplicate entity found (persistence)")
            end
        end
        
        for uiElement in scene.uiElements
            if !any_id(JulGame.main_loop().scene.uiElements, uiElement.id)
                push!(JulGame.main_loop().scene.uiElements, uiElement)
            else
                @debug("duplicate ui element found (persistence)")
            end
        end

        JulGame.main_loop().scene.camera = scene.camera

        for entity in JulGame.main_loop().scene.entities
            if entity.persistentBetweenScenes #TODO: Verify if the entity is in it's first scene. If it is, don't skip the scripts.
                continue
            end
            
            if entity.rigidbody != C_NULL
                push!(JulGame.main_loop().scene.rigidbodies, entity.rigidbody)
            end
            if entity.collider != C_NULL
                push!(JulGame.main_loop().scene.colliders, entity.collider)
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
        entity = Entity("New entity")
        push!(JulGame.main_loop().scene.entities, entity)
        return entity
    end

    function create_new_text_box(this::Scene)
        textBox = TextBox("TextBox")
        JulGame.UI.initialize(textBox)
        push!(JulGame.main_loop().scene.uiElements, textBox)
        return textBox
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
        push!(JulGame.main_loop().scene.uiElements, screenButton)
        return screenButton
    end

    function create_new_canvas(this::Scene)
        canvas = Canvas(
            name="New Canvas",
            size=Math.Vector2(400, 300),
            position=Math.Vector2(100, 100),
            color=(255, 255, 255, 100)  # Semi-transparent white
        )
        push!(JulGame.main_loop().scene.uiElements, canvas)
        return canvas
    end

    function create_new_image(this::Scene)
        image = JulGame.UI.UIImageModule.UIImage(;
            size=Math.Vector2(400, 300),
            position=Math.Vector2(0, 0),
            color=(255, 255, 255, 100)
        )
        push!(JulGame.main_loop().scene.uiElements, image)
        return image
    end

    function create_new_rectangle(this::Scene)
        rectangle = JulGame.UI.RectangleModule.Rectangle(;
            name="New Rectangle",
            size=Math.Vector2(400, 300),
            position=Math.Vector2(0, 0),
        )
        push!(JulGame.main_loop().scene.uiElements, rectangle)
        return rectangle
    end

    function add_scripts_to_entities(path::String)
        @debug string("Adding scripts to entities")
        @debug string("Path: ", path)
        @debug string("Entities: ", length(JulGame.main_loop().scene.entities))

        # A trimmed build has no way to load code at runtime; its scripts are compiled in and found by construct_script
        JulGame.unless_trimmed(load_project_scripts, path)

        for entity in JulGame.main_loop().scene.entities
            for spec in entity.pendingScripts
                @debug String("Adding script: $(spec.name) to entity: $(entity.name)")
                try
                    newScript = @timed_step "script construct: $(spec.name)" build_script(spec)
                    push!(entity.scripts, newScript)
                    newScript.parent = entity
                catch e
                    JulGame.log_exception("Failed to add script $(spec.name) to entity $(entity.name)", e)
                end
            end
            empty!(entity.pendingScripts)
        end
    end

    function build_script(spec::ScriptSpec)::JulGame.Script
        script = construct_script(spec.name)
        fields = spec.fields
        if fields.kind == SceneJSON.JObject
            for (key, value) in zip(fields.keys, fields.items)
                isnull(value) && continue
                try
                    JulGame.dispatch(set_script_field!, script, key, value)
                catch e
                    JulGame.log_exception("Failed to set field $key of script $(spec.name)", e)
                end
            end
        end
        return script
    end

    """
        construct_script(name::String)

    Creates the script named `name` using its zero-argument constructor. Under `juliac --trim` every `Script` subtype
    must have one, since the compiler has to see all the constructors.
    """
    @generated function construct_script(name::String)
        if !JulGame.TRIM_BUILD
            return :(construct_script_dynamic(name))
        end

        body = :(error("Unknown script: " * name))
        for scriptType in reverse(JulGame.concrete_subtypes(JulGame.Script))
            body = Expr(:if, :(name == $(String(nameof(scriptType)))), :(return $scriptType()), body)
        end
        return body
    end

    function construct_script_dynamic(name::String)::JulGame.Script
        scriptModule = Base.invokelatest(getfield, JulGame.ScriptModule, Symbol("$(name)Module"))
        constructor = Base.invokelatest(getfield, scriptModule, Symbol(name))
        return Base.invokelatest(constructor)
    end

    """
        set_script_field!(script, key::String, value::JSONValue)

    Overwrites the `EditorExport` field `key` of `script` with `value` from the scene file. Other fields are left alone.
    """
    @generated function set_script_field!(script::S, key::String, value::JSONValue) where {S <: JulGame.Script}
        body = Expr(:block)
        for (fieldName, fieldType) in zip(fieldnames(S), fieldtypes(S))
            if fieldType isa DataType && fieldType <: JulGame.EditorExport && !isempty(fieldType.parameters)
                valueType = fieldType.parameters[1]
                push!(body.args, :(key == $(String(fieldName)) && (setfield!(script, $(QuoteNode(fieldName)), JulGame.EditorExport(json_convert($valueType, value))); return nothing)))
            end
        end
        push!(body.args, :(return nothing))
        return body
    end

    json_convert(::Type{Bool}, value::JSONValue) = json_bool(value, false)
    json_convert(::Type{T}, value::JSONValue) where {T <: Integer} = convert(T, json_int(value, 0))
    json_convert(::Type{T}, value::JSONValue) where {T <: AbstractFloat} = convert(T, json_float(value, 0.0))
    json_convert(::Type{String}, value::JSONValue) = json_string(value, "")
    json_convert(::Type{Symbol}, value::JSONValue) = Symbol(json_string(value, ""))
    json_convert(::Type{Math._Vector2{T}}, value::JSONValue) where {T} = Math._Vector2{T}(json_float(value, "x", 0.0), json_float(value, "y", 0.0))
    json_convert(::Type{Math._Vector3{T}}, value::JSONValue) where {T} = Math._Vector3{T}(json_float(value, "x", 0.0), json_float(value, "y", 0.0), json_float(value, "z", 0.0))
    json_convert(::Type{Math._Vector4{T}}, value::JSONValue) where {T} = Math._Vector4{T}(json_float(value, "x", 0.0), json_float(value, "y", 0.0), json_float(value, "z", 0.0), json_float(value, "t", 0.0))
    json_convert(::Type{Vector{T}}, value::JSONValue) where {T} = T[json_convert(T, item) for item in value]
    json_convert(::Type{T}, value::JSONValue) where {T} = error("Cannot read a scene value as " * string(T))

    # Loads the project's scripts into JulGame.ScriptModule, so scripts can be defined without a precompiled project
    function load_project_scripts(path::String)
        project_scripts_found = false
        if JulGame.ProjectModule != ""
            @debug "Loading scripts from project module: $(JulGame.ProjectModule)"
            scripts_mod = filter(
                x -> occursin(r"\.Scripts$", string(x)),
                ccall(:jl_module_usings, Any, (Any,), getfield(Main, Symbol("$(JulGame.ProjectModule)")))
            )
            if scripts_mod !== nothing && length(scripts_mod) > 0
                JulGame.ScriptModule = scripts_mod[1]
                project_scripts_found = true
            end
        end

        # Only load scripts from the scene folder when we don't already have
        # the project's `Scripts` module available. This avoids re-including
        # the same files (which is wasted work in dev/non-compiled runs).
        if !JulGame.IS_PACKAGE_COMPILED && !project_scripts_found
            @debug "Package not compiled, loading scripts"
            @timed_step "load all scripts" begin
            foreach(file -> try
                if !(file in JulGame.LoadedScripts)
                    @debug("Loading $file")
                    @timed_step "include file $file" Base.include(JulGame.ScriptModule, file)
                    @debug("Finished loading $file")
                    push!(JulGame.LoadedScripts, file)
                end
            catch e
                JulGame.log_exception("Error including $file", e)
                end, filter(contains(r".jl$"), readdir(joinpath(path, "scripts"); join=true)))
            end
            @debug "Finished loading scripts"
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
            for line in eachline(filename)
                # Split the line at the '=' character
                parts = split(line, "=", limit=2)
                if length(parts) == 2
                    key, value = parts[1], parts[2]
                    # Strip any extra whitespace and add to dictionary
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
        # Open the file for writing
        file = open(filename; write = true)
        try
            for (key, value) in config
                # Write each key-value pair to the file
                println(file, "$key=$value")
            end
        finally
            close(file)
        end
    end
end # module

