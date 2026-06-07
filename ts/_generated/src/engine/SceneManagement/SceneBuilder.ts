export {}
import { haskey, joinpath, pointer, unsafe_string } from "../../../../src/engine/core/juliaHelpers";


    // using ...JulGame
    // using ...CameraModule
    // using ...ColliderModule
    // using ...EntityModule
    // using ...Math
    // using ...RigidbodyModule
    // using ...TextBoxModule
    // using ...ScreenButtonModule
    // using ...CanvasModule
    // using ..SceneReaderModule
    // using JSON3

    
    class Scene {
        scene
        srcPath: string
        type: string

        constructor(sceneFileName: string, srcPath: string = joinpath(pwd(), ".."), type: string="SDLRenderer") {
              

            this.scene = sceneFileName
            this.srcPath = srcPath 
            this.type = type
            let path = Base.load_path()[1]
            (globalThis as any).JulGame.IS_PACKAGE_COMPILED = occursin("share", path) && occursin("Project.toml", path)
            if (Sys.isapple() && (globalThis as any).JulGame.IS_PACKAGE_COMPILED) {
                srcPath = joinpath(join(split(path, "/")[1:(() => { const a = split(path, "/"); const i = a.findIndex((x) => x === "Build"); return i < 0 ? null : i + 1; })()], "/"))
            }

            (globalThis as any).JulGame.BasePath = srcPath
            if (type == "Web") {
                (globalThis as any).JulGame.IS_WEB = true
            }

        }    
    }
    
    function load_and_prepare_scene(self: Scene, main = (globalThis as any).JulGame.MainLoop(); 
        let config = parse_config(), 
        windowName: string="Game", 
        isWindowResizable: boolean=false, 
        preloadAllScenes: boolean=false,
        scalingQuality: string="linear"
    )
        (globalThis as any).JulGame.engine_states.current_state = "scene_change"
        if (config === null) {
            console.debug("Config is null, parsing config")
            config = parse_config()
        } else {
            console.debug("Config is not null, // using provided config")
        }

        config = fill_in_config(config)

        windowName: string = windowName
        size = {x: parse(Int, String(get(config, "Width", DEFAULT_CONFIG["Width"]))), y: parse(Int, String(get(config, "Height", DEFAULT_CONFIG["Height"])))}
        isResizable: boolean = isWindowResizable
        targetFrameRate: number = parse(Int, String(get(config, "FrameRate", DEFAULT_CONFIG["FrameRate"])))
        isFullscreen: boolean = get(config, "Fullscreen", DEFAULT_CONFIG["Fullscreen"]) == "1"
        isVsyncEnabled: boolean = get(config, "Vsync", DEFAULT_CONFIG["Vsync"]) == "1"

        (globalThis as any).JulGame.MAIN = main
        (globalThis as any).MAIN.testMode = get(ENV, "TEST_MODE", "false") == "true"
        (globalThis as any).MAIN.testLength = parse(Float64, get(ENV, "TEST_LENGTH", "20.0"))
        (globalThis as any).MAIN.currentTestTime = 0.0
        (globalThis as any).MAIN.level = this
        (globalThis as any).MAIN.scene.name = split(this.scene, ".")[1]

        if (size == {x: 0, y: 0}) {
			let displayMode = (globalThis as any).JulGameSdl.glue_SDL_DisplayMode[(globalThis as any).JulGameSdl.glue_SDL_DisplayMode(0x12345678, 800, 600, 60, null)];
			(globalThis as any).JulGameSdl.glue_SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			let size = {x: displayMode[0].w, y: displayMode[0].h}
		}
        
        
        let scene = null
        if (!(globalThis as any).JulGame.IS_EDITOR && !(globalThis as any).JulGame.IS_WEB) {
            // Initialize window manager
            let windowCreated = (globalThis as any).JulGame.WindowManagerModule.create_window(windowName, size, isFullscreen, isResizable)
            if (!windowCreated) {
                console.error("Failed to create window")
                return
            }
            
            // Create renderer
            // todo move to window manager
            // Enable high-quality scaling
            if (scalingQuality == "nearest") {
                let scalingQuality = "0"
            } else if (scalingQuality == "linear") {
                scalingQuality = "1"
            } else if (scalingQuality == "best") {
                scalingQuality = "2"
            } else {
                scalingQuality = "2"
            }
            (globalThis as any).JulGame.SCALE_QUALITY = scalingQuality;
            // "0" or "nearest": Nearest pixel sampling
            // "1" or "linear": Linear filtering (supported by OpenGL and Direct3D)
            // "2" or "best": Currently this is the same as "linear"

            (globalThis as any).JulGameSdl.glue_SDL_SetHint((globalThis as any).JulGameSdl.glue_SDL_HINT_RENDER_SCALE_QUALITY, scalingQuality)
            (globalThis as any).JulGame.Renderer = (globalThis as any).JulGameSdl.glue_SDL_CreateRenderer((globalThis as any).MAIN.windowManager.window, -1, (globalThis as any).JulGameSdl.glue_SDL_RENDERER_ACCELERATED)
            if ((globalThis as any).JulGame.Renderer == null) {
                console.error(`Failed to create renderer with window ${(globalThis as any).MAIN.windowManager.window}, ${unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError())}`)
            return
            }

            // Preload all scenes if requested
            if (preloadAllScenes) {
                console.debug("Preloading all ...scenes")
                let scenesDir = joinpath(BasePath, "scenes")
                if (isdir(scenesDir)) {
                    for (const file of readdir(scenesDir)) {
                        if (endswith(file, ".json")) {
                            let scenePath = joinpath(scenesDir, file)
                            console.debug(`Preloading scene: ${file}`)
                            SceneReaderModule.preload_scene(scenePath)
                        }
                    }
                    console.debug("Finished preloading scenes")
                } else {
                    console.warn(`Scenes directory not found: ${scenesDir}`)
                }
            };
            
            // Set default texture scaling mode to linear
            (globalThis as any).JulGameSdl.glue_SDL_SetHint((globalThis as any).JulGameSdl.glue_SDL_HINT_RENDER_SCALE_QUALITY, scalingQuality)
            
            // Apply additional window settings from config
            console.debug(`Setting frame rate to ${targetFrameRate}`)
            (globalThis as any).JulGame.WindowManagerModule.set_frame_rate(targetFrameRate)
            console.debug(`Setting vsync to ${isVsyncEnabled}`)
            (globalThis as any).JulGame.WindowManagerModule.set_vsync(isVsyncEnabled)
            
            console.debug("Deserializing scene")
            // Use preloaded scene if available
            if (preloadAllScenes && haskey((globalThis as any).JulGame.PRELOADED_SCENES, this.scene)) {
                console.debug(`Using preloaded scene: ${this.scene}`)
                scene = (globalThis as any).JulGame.PRELOADED_SCENES[this.scene]
            } else {
                scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
            }
            let camera = scene[2]
            // Set logical rendering size based on camera
            console.debug(`Setting logical size to ${size.x}x${size.y}`)
            if (camera !== null && camera.size.x > 0 && camera.size.y > 0) {
                (globalThis as any).JulGame.WindowManagerModule.set_logical_size(camera.size.x, camera.size.y)
            }
            
            // Set window icon if available
            let iconPath = get(config, "Icon", "")
            if (iconPath != "") {
                (globalThis as any).JulGame.WindowManagerModule.set_window_icon(iconPath)
            }
        }

        if (scene === null) {
            // Use preloaded scene if available
            if (preloadAllScenes && haskey((globalThis as any).JulGame.PRELOADED_SCENES, this.scene)) {
                console.debug(`Using preloaded scene: ${this.scene}`)
                scene = (globalThis as any).JulGame.PRELOADED_SCENES[this.scene]
            } else {
                scene = deserialize_scene(joinpath(BasePath, "scenes", this.scene))
            }
        }
        
        (globalThis as any).MAIN.scene.entities = scene[0]
        (globalThis as any).MAIN.scene.uiElements = scene[1]
        (globalThis as any).MAIN.scene.camera = scene[2]
        
        if (!(globalThis as any).JulGame.IS_EDITOR && !(globalThis as any).JulGame.IS_WEB) {
            console.debug(`Setting logical size to ${(globalThis as any).MAIN.scene.camera.size.x}x${(globalThis as any).MAIN.scene.camera.size.y}`);
            (globalThis as any).JulGameSdl.glue_SDL_RenderSetLogicalSize((globalThis as any).JulGame.Renderer, (globalThis as any).MAIN.scene.camera.size.x, (globalThis as any).MAIN.scene.camera.size.y)
        }
        
        for (const uiElement of (globalThis as any).MAIN.scene.uiElements) {
            if ("$(typeof(uiElement))" == "(globalThis as any).JulGame.UI.TextBoxModule.Textbox" && !uiElement.isWorldEntity) {
                UI.align_to_anchor(uiElement)
            }
        }

        (globalThis as any).MAIN.scene.rigidbodies = []
        (globalThis as any).MAIN.scene.colliders = []
        add_scripts_to_entities(BasePath)

        (globalThis as any).JulGame.engine_states.current_state = "game_mode"
        (globalThis as any).JulGame.MainLoopModule.prepare_window_scripts_and_start_loop(size)
    }

    function deserialize_and_build_scene(self: Scene) {
        let scene = deserialize_scene(joinpath(BasePath, "scenes", self.scene))
        
        @debug String("Changing scene to $(self.scene)")
        @debug String("Entities in main scene: $((globalThis as any).MAIN.scene.entities.length)")

        if (scene === null) {
            console.error("Error deserialize_and_build_scene")
            return
        }

        for (const entity of scene[0]) {
            if (!any(e.id == entity.id for e in (globalThis as any).MAIN.scene.entities)) {
                (globalThis as any).MAIN.scene.entities.push(entity)
            } else {
                console.debug("duplicate entity found (persistence)")
            }
        }
        
        for (const uiElement of scene[1]) {
            if (!any(e.id == uiElement.id for e in (globalThis as any).MAIN.scene.uiElements)) {
                (globalThis as any).MAIN.scene.uiElements.push(uiElement)
            } else {
                console.debug("duplicate ui element found (persistence)")
            }
        }

        for (const uiElement of (globalThis as any).MAIN.scene.uiElements) {
            if ("$(typeof(uiElement))" == "(globalThis as any).JulGame.UI.TextBoxModule.Textbox" && uiElement.isWorldEntity) {
                UI.align_to_anchor(uiElement)
            }
        }

        (globalThis as any).MAIN.scene.camera = scene[2]

        for (const entity of (globalThis as any).MAIN.scene.entities) {
            if (entity.persistentBetweenScenes //TODO: Verify if the entity is in it's first scene. If it is, don't skip the scripts.) {
                continue
            }
            
            if (entity.rigidbody != null) {
                (globalThis as any).MAIN.scene.rigidbodies.push(entity.rigidbody)
            }
            if (entity.collider != null) {
                (globalThis as any).MAIN.scene.colliders.push(entity.collider)
            }
        } 

        add_scripts_to_entities(BasePath)
    }

    /*
    create_new_entity(this)

    Create a new entity and add it to the scene.

    // Arguments
    - `this`: The scene object to which the entity will be added.

    */
    function create_new_entity(self: Scene) {
        let entity = new Entity("New entity")
        (globalThis as any).MAIN.scene.entities.push(entity)
        return entity
    }

    function create_new_text_box(self: Scene) {
        let textBox = TextBox("TextBox")
        (globalThis as any).JulGame.UI.initialize(textBox)
        (globalThis as any).MAIN.scene.uiElements.push(textBox)
        return textBox
    }
    
    function create_new_screen_button(self: Scene) {
        let screenButton = ScreenButton(
            null; // No click event defined here by default
            let name = "New Button", 
            let buttonUpSpritePath = "ButtonUp.png", 
            let buttonDownSpritePath = "ButtonDown.png", 
            let size = {x: 256, y: 64}, 
            let position = {x: 0, y: 0}, 
            let fontPath = joinpath("FiraCode-Regular.ttf"),
            // text="", // Default
            // textOffset={x: 0, y: 0}, // Default
            // Other parameters use defaults (anchor, layer, color, fontSize, etc.)
        )
        if (!screenButton.isInitialized) {
            (globalThis as any).JulGame.initialize(screenButton)
        }
        (globalThis as any).MAIN.scene.uiElements.push(screenButton)
        return screenButton
    }

    function create_new_canvas(self: Scene) {
        let canvas = Canvas(
            let name = "New Canvas",
            let size = {x: 400, y: 300},
            let position = {x: 100, y: 100},
            let color = [255, 255, 255, 100]  // Semi-transparent white
        )
        (globalThis as any).MAIN.scene.uiElements.push(canvas)
        return canvas
    }

    function create_new_image(self: Scene) {
        let image = (globalThis as any).JulGame.UI.UIImageModule.UIImage(;
            let size = {x: 400, y: 300},
            let position = {x: 0, y: 0},
            let color = [255, 255, 255, 100]
        )
        (globalThis as any).MAIN.scene.uiElements.push(image)
        return image
    }

    function create_new_rectangle(self: Scene) {
        let rectangle = (globalThis as any).JulGame.UI.RectangleModule.Rectangle(;
            let name = "New Rectangle",
            let size = {x: 400, y: 300},
            let position = {x: 0, y: 0},
        )
        (globalThis as any).MAIN.scene.uiElements.push(rectangle)
        return rectangle
    }

    function add_scripts_to_entities(path: string) {
        @debug String("Adding scripts to entities")
        @debug ["Path: ", path].join("")
        @debug ["Entities: ", (globalThis as any).MAIN.scene.entities.length].join("")
        
        // Track which scripts we've already loaded
        
        // Only load scripts for non-persistent entities or if package is not compiled
        if (!(globalThis as any).JulGame.IS_PACKAGE_COMPILED) {
            console.debug("Package not compiled, loading scripts")
            @time begin
                let count = 0
            foreach(file => try
                if (!(file in (globalThis as any).JulGame.LoadedScripts)) {
                    console.debug(`Loading ${file}`)
                    @time Base.include((globalThis as any).JulGame.ScriptModule, file)
                    console.debug(`Finished loading ${file}`)
                    (globalThis as any).JulGame.LoadedScripts.push(file)
                }
            } catch (e) {
                console.error("Error including $file: ", e)
                }, filter(contains(r".jl$"), readdir(joinpath(path, "scripts"); join=true)))
            }
            console.debug("Finished loading scripts")
        }

        if ((globalThis as any).JulGame.ProjectModule != "") {
            console.debug(`Loading scripts from project module: ${(globalThis as any).JulGame.ProjectModule}`)
            let scripts_mod = filter(x => occursin(r"\.Scripts$", String(x)), ccall("jl_module_usings", Any, (Any,), getfield(Main, Symbol("$((globalThis as any).JulGame.ProjectModule)"))))
            if (scripts_mod !== null && scripts_mod.length > 0) {
                (globalThis as any).JulGame.ScriptModule = scripts_mod[0]
            }
        }

        for (const entity of (globalThis as any).MAIN.scene.entities) {
            let scriptCounter = 1
            for (const script of entity.scripts) {
                if (!isa(script, JSON3.Object)) {
                    // Skip script reloading for persistent entities
                    scriptCounter += 1
                    continue
                }
                @debug String("Adding script: $(script.name) to entity: $(entity.name)")

                let newScript = null
                try {
                    let module_name = getfield((globalThis as any).JulGame.ScriptModule, Symbol("$(script.name)Module"))
                    let constructor = getfield(module_name, Symbol(script.name)) 
                    newScript = constructor()
                    let scriptFields = get(script, "fields", Dict())
                    console.debug(`getting fields for: ${script}`)
                    for (key, value) in scriptFields
                        let ftype = null
                        try {
                            ftype = fieldtype(typeof(newScript), Symbol(key))
                            console.debug(`type: ${ftype}`)
                            if (ftype <: EditorExport) {
                                console.debug(`Overwriting ${key} to ${value} // using scene file`)
                                // Get the wrapped type from EditorExport{T}
                                let underlying_type = ftype.parameters[0]
                                setfield(newScript, key, EditorExport(convert(underlying_type, value)))
                                continue
                            } else if (value === null) {
                                console.debug("Value is null")
                                continue
                            }
                        } catch (e) {
                            @warn String(e)
                        }
                    }
                } catch (e) {
                    console.error(String(e))

                }
                if (newScript != null && newScript !== null) {
                    entity.scripts[scriptCounter] = newScript
                    newScript.parent = entity
                }
                scriptCounter += 1
            }
        }
    }

    // Define default configuration values
    const DEFAULT_CONFIG = Dict(
        "Width" => "800",
        "Height" => "600",
        "FrameRate" => "60",
        "Fullscreen" => "0",
        "Vsync" => "0"
    )

    // Function to read and parse the config file
    function parse_config() {
        console.debug(`Parsing config at ${(globalThis as any).JulGame.BasePath}`)
        let filename = joinpath((globalThis as any).JulGame.BasePath, "config.julgame")
        let config = copy(DEFAULT_CONFIG)
        
        if (isfile(filename)) {
            // Open the file for reading
            open(filename, "r") do file
                for (const line of eachline(file)) {
                    // Split the line at the '=' character
                    let parts = split(line, "=", limit=2)
                    if (parts.length == 2) {
                        key, value = parts[0], parts[1]
                        // Strip any extra whitespace and add to dictionary
                        config[strip(key)] = strip(value)
                    }
                }
            }
        }

        write_config(filename, config)
        
        return config
    }

    function fill_in_config(config) {
        console.debug("Filling in config")
        for (key, value) in DEFAULT_CONFIG
            if (!haskey(config, key)) {
                config[key] = value
            }
        }

        return config
    }

    // Function to write values to the config file
    function write_config(filename: string, config: Record<string, string>) {
        console.debug(`Writing config to ${filename}`)
        // Open the file for writing
        open(filename, "w") do file
            for (key, value) in config
                // Write each key-value pair to the file
                console.log(file, "$key=$value")
            }
        }
    }
export { Scene, add_scripts_to_entities, create_new_canvas, create_new_entity, create_new_image, create_new_rectangle, create_new_screen_button, create_new_text_box, deserialize_and_build_scene, fill_in_config, load_and_prepare_scene, parse_config, write_config }
