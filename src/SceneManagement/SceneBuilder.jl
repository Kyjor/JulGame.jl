module SceneBuilderModule
    using ...JulGame
    using ...Math
    using ...ColliderModule
    using ...EntityModule
    using ...RigidbodyModule
    using ...TextBoxModule
    using ..SceneReaderModule
    import ...JulGame: deprecated_get_property

    function __init__()
        # if end of path is "test", then we are running tests
        if endswith(pwd(), "test")
            println("Loading scripts in test folder...")
            include.(filter(contains(r".jl$"), readdir(joinpath(pwd(), "projects", "ProfilingTest", "Platformer", "scripts"); join=true)))
        end

        if isdir(joinpath(pwd(), "..", "scripts")) #dev builds
            println("Loading scripts...")
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
        
    include("../Camera.jl")
    
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
    
    function Base.getproperty(this::Scene, s::Symbol)
        method_props = (
            init = init,
            changeScene = change_scene,
            createNewEntity = create_new_entity,
            createNewTextBox = create_new_text_box
        )
        deprecated_get_property(method_props, this, s)
    end

    

    function init(this::Scene, windowName::String = "Game", isUsingEditor = false, dimensions::Vector2 = Vector2(800, 800), camDimensions::Vector2 = Vector2(800,800), isResizable::Bool = true, zoom::Float64 = 1.0, autoScaleZoom::Bool = true, targetFrameRate = 60.0, globals = []; TestScript = C_NULL, isNewEditor = false)
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
        MAIN.scene.textBoxes = scene[2]
        if dimensions.x < camDimensions.x && dimensions.x > 0
            camDimensions = Vector2(dimensions.x, camDimensions.y)
        end
        if dimensions.y < camDimensions.y && dimensions.y > 0
            camDimensions = Vector2(camDimensions.x, dimensions.y)
        end
        MAIN.scene.camera = Camera(camDimensions, Vector2f(),Vector2f(), C_NULL)
        
        for textBox in MAIN.scene.textBoxes
            if textBox.isWorldEntity
                textBox.centerText()
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
                        newScript = TestScript == C_NULL ? eval(Symbol(script.name))(params...) : TestScript()
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
        MAIN.init(isUsingEditor, dimensions, isResizable, autoScaleZoom, isNewEditor)

        return MAIN
    end

    function change_scene(this::Scene, isUsingEditor::Bool = false)
        scene = deserializeScene(joinpath(BasePath, "scenes", this.scene), isUsingEditor)
        
        # println("Changing scene to $this.scene")
        # println("Entities in main scene: ", length(MAIN.scene.entities))

        for entity in scene[1]
            push!(MAIN.scene.entities, entity)
        end

        MAIN.scene.textBoxes = scene[2]

        for textBox in MAIN.scene.textBoxes
            if textBox.isWorldEntity
                textBox.centerText()
            end
        end

        for entity in MAIN.scene.entities
            if entity.persistentBetweenScenes
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
                        # TestScript == C_NULL ? eval(Symbol(script.name))(params...) : TestScript()
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
    end

    function create_new_entity(this::Scene)
        push!(MAIN.scene.entities, Entity("New entity"))
    end

    function create_new_text_box(this::Scene, fontPath)
        textBox = TextBox("TextBox", fontPath, 40, Vector2(0, 200), "TextBox", true, true, true, true)
        textBox.initialize()
        push!(MAIN.scene.textBoxes, textBox)
    end
end
