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

    function __init__()
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
    
    function load_and_prepare_scene(this::Scene, windowName::String = "Game", isUsingEditor = false, size::Vector2 = Vector2(800, 800), camSize::Vector2 = Vector2(800,800), isResizable::Bool = true, zoom::Float64 = 1.0, autoScaleZoom::Bool = true, targetFrameRate = 60.0, globals = []; isNewEditor = false)
        #file loading
        if autoScaleZoom 
            zoom = 1.0
        end
        
        MAIN.windowName = windowName
        MAIN.zoom = zoom
        MAIN.globals = globals
        MAIN.level = this
        MAIN.targetFrameRate = targetFrameRate
        scene = deserializeScene(joinpath(BasePath, "scenes", this.scene), isUsingEditor)
        MAIN.scene.entities = scene[1]
        MAIN.scene.uiElements = scene[2]
        if size.x < camSize.x && size.x > 0
            camSize = Vector2(size.x, camSize.y)
        end
        if size.y < camSize.y && size.y > 0
            camSize = Vector2(camSize.x, size.y)
        end
        MAIN.scene.camera = CameraModule.Camera(camSize, Vector2f(),Vector2f(), C_NULL)
        
        for uiElement in MAIN.scene.uiElements
            if "$(typeof(uiElement))" == "JulGame.UI.TextBoxModule.Textbox" && uiElement.isWorldEntity
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

            if !isUsingEditor
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
                                println(e)
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
                        println(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
                    end

                    entity.scripts[scriptCounter] = newScript
                    newScript.setParent(entity)
                    scriptCounter += 1
                end
            end
        end

        MAIN.assets = joinpath(BasePath, "assets")
        JulGame.MainLoop.prepare_window_scripts_and_start_loop(isUsingEditor, size, isResizable, autoScaleZoom, isNewEditor)
    end

    function change_scene(this::Scene, isUsingEditor::Bool = false)
        scene = deserializeScene(joinpath(BasePath, "scenes", this.scene), isUsingEditor)
        
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

            if !isUsingEditor
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
                                    println(e)
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
                        println(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
                    end

                    if newScript != C_NULL
                        entity.scripts[scriptCounter] = newScript
                        newScript.setParent(entity)
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
end
