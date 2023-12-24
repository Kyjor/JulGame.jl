module SceneBuilderModule
    using ..SceneManagement.JulGame
    using ..SceneManagement.JulGame.Math
    using ..SceneManagement.JulGame.ColliderModule
    using ..SceneManagement.JulGame.EntityModule
    using ..SceneManagement.JulGame.RigidbodyModule
    using ..SceneManagement.JulGame.TextBoxModule
    using ..SceneManagement.SceneReaderModule

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

        
    include("../Camera.jl")
    include("../Main.jl")
    
    export Scene
    mutable struct Scene
        main
        scene
        srcPath

        function Scene(sceneFileName::String, srcPath::String = joinpath(pwd(), ".."))
            this = new()  

            SDL2.init()
            this.scene = sceneFileName
            this.srcPath = srcPath
            JulGame.BasePath = srcPath

            return this
        end

        function Base.getproperty(this::Scene, s::Symbol)
            if s == :init 
                function(windowName::String = "Game", isUsingEditor = false, dimensions::Vector2 = Vector2(800, 800), camDimensions::Vector2 = Vector2(800,800), isResizable::Bool = true, zoom::Float64 = 1.0, autoScaleZoom::Bool = true, targetFrameRate = 60.0, globals = []; TestScript = C_NULL)
                    #file loading
                    if autoScaleZoom 
                        zoom = 1.0
                    end

                    main = MAIN
                    main.windowName = windowName
                    main.zoom = zoom
                    main.globals = globals
                    main.level = this
                    main.targetFrameRate = targetFrameRate
                    scene = deserializeScene(joinpath(BasePath, "scenes", this.scene), isUsingEditor)
                    main.scene.entities = scene[1]
                    main.scene.textBoxes = scene[2]
                    if dimensions.x < camDimensions.x && dimensions.x > 0
                        camDimensions = Vector2(dimensions.x, camDimensions.y)
                    end
                    if dimensions.y < camDimensions.y && dimensions.y > 0
                        camDimensions = Vector2(camDimensions.x, dimensions.y)
                    end
                    main.scene.camera = Camera(camDimensions, Vector2f(),Vector2f(), C_NULL)

                    for textBox in main.scene.textBoxes
                        if textBox.isWorldEntity
                            textBox.centerText()
                        end
                    end

                    main.scene.rigidbodies = []
                    main.scene.colliders = []
                    for entity in main.scene.entities
                        for component in entity.components
                            if typeof(component) == Rigidbody
                                push!(main.scene.rigidbodies, component)
                            elseif typeof(component) == Collider
                                push!(main.scene.colliders, component)
                            end
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
                                        newParam = parse(Float64, param)
                                        param = occursin(".", param) == true ? parse(Float64, param) : parse(Integer, param)
                                    catch 
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
                            end

                            entity.scripts[scriptCounter] = newScript
                            newScript.setParent(entity)
                            scriptCounter += 1
                        end
                    end

                    end

                    main.assets = joinpath(BasePath, "assets")
                    main.loadScene(main.scene)
                    main.init(isUsingEditor, dimensions, isResizable, autoScaleZoom)

                    this.main = main
                    return main
                end
            elseif s == :createNewEntity
                function ()
                    push!(this.main.scene.entities, Entity("New entity", C_NULL))
                end
            elseif s == :createNewTextBox
                function (fontPath)
                    textBox = TextBox("TextBox", fontPath, 40, Vector2(0, 200), "TextBox", true, true, true, true)
                    textBox.initialize()
                    push!(this.main.textBoxes, textBox)
                end
            else
                try
                    getfield(this, s)
                catch e
                    println(e)
                end
            end
        end
    end
end