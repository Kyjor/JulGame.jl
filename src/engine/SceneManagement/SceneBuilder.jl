module SceneBuilderModule
    using ...JulGame
    using ...CameraModule
    using ...ColliderModule
    using ...EntityModule
    using ...Math
    using ...RigidbodyModule
    using ...TextBoxModule
    using ...ScreenButtonModule
    using ..SceneReaderModule

    function init()
        # if end of path is "test", then we are running tests
        if endswith(pwd(), "test")
            println("Loading scripts in test folder...")
            include.(filter(contains(r".jl$"), readdir(joinpath(pwd(), "projects", "ProfilingTest", "Platformer", "scripts"); join=true)))
            include.(filter(contains(r".jl$"), readdir(joinpath(pwd(), "projects", "SmokeTest", "scripts"); join=true)))
        end

        if isdir(joinpath(pwd(), "..", "scripts")) #dev builds
            # println("Loading scripts...")
            include.(filter(contains(r".jl$"), readdir(joinpath(pwd(), "..", "scripts"); join=true)))
        else
            script_folder_name = "scripts"
            current_dir = pwd()
            
            # Find all folders in the current directory
            folders = filter(isdir, readdir(current_dir))
            
            # Check each folder for the "scripts" subfolder
            for folder in folders
                scripts_path = joinpath(current_dir, folder, script_folder_name)
                if isdir(scripts_path)
                    println("Loading scripts in $scripts_path...")
                    include.(filter(contains(r".jl$"), readdir(scripts_path; join=true)))
                    break  # Exit loop if "scripts" folder is found in any parent folder
                end
            end
        end
    end

   function __init__()
    # if not using PackageCompiler, then we need to call init() here
        if ccall(:jl_generating_output, Cint, ()) != 1
            init()
        end
    end

    # if using PackageCompiler, then we need to call init here
    if ccall(:jl_generating_output, Cint, ()) == 1
        init()
    end
        
    export Scene
    mutable struct Scene
        scene
        srcPath::String
        function Scene(sceneFileName::String, srcPath::String = joinpath(pwd(), ".."))
            this = new()  

            this.scene = sceneFileName
            this.srcPath = srcPath
            JulGame.BasePath = srcPath

            return this
        end    
    end
    
    function load_and_prepare_scene(;this::Scene, config=parse_config(), globals = [])
        config = fill_in_config(config)
        windowName::String = get(config, "WindowName", DEFAULT_CONFIG["WindowName"])
        size::Vector2 = Vector2(parse(Int32, get(config, "Width", DEFAULT_CONFIG["Width"])), parse(Int32, get(config, "Height", DEFAULT_CONFIG["Height"])))
        camSize::Vector2 = Vector2(parse(Int32, get(config, "CameraWidth", DEFAULT_CONFIG["CameraWidth"])), parse(Int32, get(config, "CameraHeight", DEFAULT_CONFIG["CameraHeight"])))
        isResizable::Bool = parse(Bool, get(config, "IsResizable", DEFAULT_CONFIG["IsResizable"]))
        zoom::Float64 = parse(Float64, get(config, "Zoom", DEFAULT_CONFIG["Zoom"]))
        autoScaleZoom::Bool = parse(Bool, get(config, "AutoScaleZoom", DEFAULT_CONFIG["AutoScaleZoom"]))
        targetFrameRate::Int32 = parse(Int32, get(config, "FrameRate", DEFAULT_CONFIG["FrameRate"]))

        if autoScaleZoom 
             zoom = 1.0
        end

        MAIN.windowName = windowName
        MAIN.zoom = zoom
        MAIN.globals = globals
        MAIN.level = this
        MAIN.targetFrameRate = targetFrameRate

        if size == Math.Vector2()
			displayMode = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
			SDL2.SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			size = Math.Vector2(displayMode[1].w, displayMode[1].h)
		end

        if size.x < camSize.x && size.x > 0
            camSize = Vector2(size.x, camSize.y)
        end
        if size.y < camSize.y && size.y > 0
            camSize = Vector2(camSize.x, size.y)
        end
        #MAIN.scene.camera = CameraModule.Camera(camSize, Vector2f(),Vector2f(), C_NULL)

        flags = SDL2.SDL_RENDERER_ACCELERATED |
		(JulGame.IS_EDITOR ? (SDL2.SDL_WINDOW_POPUP_MENU | SDL2.SDL_WINDOW_ALWAYS_ON_TOP | SDL2.SDL_WINDOW_BORDERLESS) : 0) |
		(isResizable || JulGame.IS_EDITOR ? SDL2.SDL_WINDOW_RESIZABLE : 0) |
		(size == Math.Vector2() ? SDL2.SDL_WINDOW_FULLSCREEN_DESKTOP : 0)

        MAIN.screenSize = size
        if !JulGame.IS_EDITOR
            MAIN.window = SDL2.SDL_CreateWindow(MAIN.windowName, SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, MAIN.screenSize.x, MAIN.screenSize.y, flags)
            JulGame.Renderer::Ptr{SDL2.SDL_Renderer} = SDL2.SDL_CreateRenderer(MAIN.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
        end

        scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
        MAIN.scene.entities = scene[1]
        MAIN.scene.uiElements = scene[2]
        
        for uiElement in MAIN.scene.uiElements
            if "$(typeof(uiElement))" == "JulGame.UI.TextBoxModule.Textbox" && !uiElement.isWorldEntity
                UI.center_text(uiElement)
            end
        end

        MAIN.scene.rigidbodies = InternalRigidbody[]
        MAIN.scene.colliders = InternalCollider[]
        for entity in MAIN.scene.entities
            if entity.rigidbody != C_NULL
                push!(MAIN.scene.rigidbodies, entity.rigidbody)
            end
            if entity.collider != C_NULL
                push!(MAIN.scene.colliders, entity.collider)
            end

            if !JulGame.IS_EDITOR
                scriptCounter = 1
                for script in entity.scripts
                    params = []
                    for param in script.parameters
                        if lowercase(param) == "true"
                            param = true
                        elseif lowercase(param) == "false"
                            param = false
                        else
                            try
                                param = occursin(".", param) == true ? parse(Float64, param) : parse(Int32, param)
                            catch e
                                @error string(e)
						        Base.show_backtrace(stdout, catch_backtrace())
						        rethrow(e)
                            end
                        end
                        push!(params, param)
                    end

                    newScript = C_NULL
                    try
                        newScript = eval(Symbol(script.name))(params...)
                    catch e
                        @error string(e) 
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
                    end

                    entity.scripts[scriptCounter] = newScript
                    newScript.parent = entity
                    scriptCounter += 1
                end
            end
        end

        MAIN.assets = joinpath(BasePath, "assets")
        JulGame.MainLoop.prepare_window_scripts_and_start_loop(size, isResizable, autoScaleZoom)
    end

    function deserialize_and_build_scene(this::Scene)
        scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
        
        # println("Changing scene to $this.scene")
        # println("Entities in main scene: ", length(MAIN.scene.entities))

        for entity in scene[1]
            push!(MAIN.scene.entities, entity)
        end

        MAIN.scene.uiElements = scene[2]

        for uiElement in MAIN.scene.uiElements
            if "$(typeof(uiElement))" == "JulGame.UI.TextBoxModule.Textbox" && uiElement.isWorldEntity
                UI.center_text(uiElement)
            end
        end

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

            if !JulGame.IS_EDITOR
                scriptCounter = 1
                for script in entity.scripts
                    params = []
                        for param in script.parameters
                            if lowercase(param) == "true"
                                param = true
                            elseif lowercase(param) == "false"
                                param = false
                            else
                                try
                                    param = occursin(".", param) == true ? parse(Float64, param) : parse(Int32, param)
                                catch e
                                    @error string(e)
                                    Base.show_backtrace(stdout, catch_backtrace())
                                    rethrow(e)
                                end
                            end
                            push!(params, param)
                        end

                    newScript = C_NULL
                    try
                        newScript = eval(Symbol(script.name))(params...)
                    catch e
                        @error string(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
                    end

                    if newScript != C_NULL
                        entity.scripts[scriptCounter] = newScript
                        newScript.parent = entity
                    end
                    scriptCounter += 1
                end
            end
        end 
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
        textBox = TextBox("TextBox", "", 40, Vector2(0, 200), "TextBox", true, true)
        JulGame.initialize(textBox)
        push!(MAIN.scene.uiElements, textBox)
    end
    
    function create_new_screen_button(this::Scene)
        screenButton = ScreenButton("name", "ButtonUp.png", "ButtonDown.png", Vector2(256, 64), Vector2(0, 0), joinpath("FiraCode", "ttf", "FiraCode-Regular.ttf"), "test")
        JulGame.initialize(screenButton)
        push!(MAIN.scene.screenButtons, screenButton)
        push!(MAIN.scene.uiElements, screenButton)
    end

    function add_scripts_to_entities(path::String)
        @info string("Adding scripts to entities")
        @info string("Entities: ", length(MAIN.scene.entities))
		include.(filter(contains(r".jl$"), readdir(joinpath(path, "scripts"); join=true)))
        for entity in MAIN.scene.entities
            scriptCounter = 1
            for script in entity.scripts
                params = []
                    for param in script.parameters
                        if lowercase(param) == "true"
                            param = true
                        elseif lowercase(param) == "false"
                            param = false
                        else
                            try
                                param = occursin(".", param) == true ? parse(Float64, param) : parse(Int32, param)
                            catch e
                                @error string(e)
                                Base.show_backtrace(stdout, catch_backtrace())
                                rethrow(e)
                            end
                        end
                        push!(params, param)
                    end
                newScript = C_NULL
                try
                    # TODO: only call latest if in editor and in game mode
                    newScript = Base.invokelatest(eval, Symbol(script.name))
                    newScript = Base.invokelatest(newScript, params...)
                catch e
                    @error string(e)
                    Base.show_backtrace(stdout, catch_backtrace())
                    rethrow(e)
                end
                if newScript != C_NULL
                    entity.scripts[scriptCounter] = newScript
                    newScript.parent = entity
                end
                scriptCounter += 1
            end
        end
    end

    # Define default configuration values
const DEFAULT_CONFIG = Dict(
    "WindowName" => "Default Game",
    "Width" => "800",
    "Height" => "600",
    "CameraWidth" => "800",
    "CameraHeight" => "600",
    "IsResizable" => "0",
    "Zoom" => "1.0",
    "AutoScaleZoom" => "0",
    "FrameRate" => "30"
)

# Function to read and parse the config file
function parse_config()
    filename = joinpath(JulGame.BasePath, "..", "config.julgame")
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
    else
        write_config(filename, config)
    end
    
    
    return config
end

function fill_in_config(config)
    for (key, value) in DEFAULT_CONFIG
        if !haskey(config, key)
            config[key] = value
        end
    end

    return config
end

# Function to write values to the config file
function write_config(filename::String, config::Dict{String, String})
    # Open the file for writing
    open(filename, "w") do file
        for (key, value) in config
            # Write each key-value pair to the file
            println(file, "$key=$value")
        end
    end
end

# # Example usage
# config_file = "config.txt"

# # Read the configuration
# config = parse_config(config_file)
# println("Parsed Configuration:")
# println(config)

# # Modify some values (example)
# config["Width"] = "800"
# config["Height"] = "600"

# # Write the updated configuration back to the file
# write_config(config_file, config)
# println("Updated Configuration Written to File.")

end
