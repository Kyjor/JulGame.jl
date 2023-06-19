module SceneBuilderModule
    using ..SceneManagement.julGame
    using ..SceneManagement.julGame.Math
    using ..SceneManagement.julGame.ColliderModule
    using ..SceneManagement.julGame.EntityModule
    using ..SceneManagement.julGame.RigidbodyModule
    using ..SceneManagement.julGame.TextBoxModule
    using ..SceneManagement.SceneReaderModule
    if isdir(joinpath(pwd(), "..", "scripts"))
        println("Loading scripts...")
        include.(filter(contains(r".jl$"), readdir(joinpath(pwd(), "..", "scripts"); join=true)))
    end
        
    include("../Camera.jl")
    include("../Main.jl")

    export Scene
    mutable struct Scene
        main
        scene
        srcPath

        function Scene(srcPath, scene)
            this = new()    

            this.scene = scene
            this.srcPath = srcPath

            return this
        end

        function Base.getproperty(this::Scene, s::Symbol)
            if s == :init 
                function(isUsingEditor = false)
                    #file loading
                    ASSETS = joinpath(this.srcPath, "projectFiles", "assets")
                    main = MAIN
                    
                    # gameManager.textBox = textBoxes[1]
                    # main.scene.textBoxes = textBoxes

                    main.level = this
                    main.scene.entities = deserializeEntities(this.srcPath, joinpath(this.srcPath, "projectFiles", "scenes", this.scene), isUsingEditor)
                    main.scene.camera = Camera(Vector2f(975, 750), Vector2f(),Vector2f(0.64, 0.64), main.scene.entities[31].getTransform())
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
                                        param = occursin(".", param) == true ? parse(Float64, param) : parse(Int64, param)
                                    catch 
                                    end
                                end
                                push!(params, param)
                            end
                            newScript = eval(Symbol(script.name))(params...)

                            entity.scripts[scriptCounter] = newScript
                            newScript.setParent(entity)
                            scriptCounter += 1
                        end
                    end

                    end

                    main.assets = ASSETS
                    main.loadScene(main.scene)
                    main.init(isUsingEditor)

                    this.main = main
                    return main
                end
            elseif s == :createNewEntity
                function ()
                    push!(this.main.entities, Entity("New entity", C_NULL))
                end
            elseif s == :createNewTextBox
                function ()
                    textBox = TextBox("TextBox", joinpath(@__DIR__, "..", "Fonts", "VT323", "VT323-Regular.ttf"), 40, Vector2(0, 200), Vector2(1000, 100), Vector2(0, 0), "TextBox", true)
                    textBox.initialize(this.main.renderer, this.main.zoom)
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