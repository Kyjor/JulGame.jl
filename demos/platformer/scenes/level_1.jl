using .julgame
using .julgame.Math

include("../../../src/Camera.jl")
include("../../../src/Main.jl")
include("../src/sceneReader.jl")

include.(filter(contains(r".jl$"), readdir("../scripts/"; join=true)))


function level_1(isUsingEditor = false)
    #file loading
    ASSETS = joinpath(@__DIR__, "..", "assets")
    main = MAIN
    #gameManager = GameManager()

    playerMovement = PlayerMovement(true)
    # playerMovement.gameManager = gameManager
    
    # gameDialogue = Dialogue(narratorScript, 0.05, 1.5, gameManager, playerMovement)
    # gameDialogue.isPaused = true
    
    # secretDialogue = Dialogue(secretManScript, 0.05, 1.5, gameManager, playerMovement)
    # secretDialogue.isNormalDialogue = false
    # secretDialogue.isPaused = true

    # gameManager.playerMovement = playerMovement
    # gameManager.dialogue = gameDialogue
    # gameManager.secretDialogue = secretDialogue

    # gameManager.textBox = textBoxes[1]

    # main.scene.textBoxes = textBoxes
    # main.scene.entities = getEntities()
    # println(main.scene.entities[1].getSprite())
    main.scene.entities = deserializeEntities(joinpath(@__DIR__, "scene.json"))
    main.scene.camera = Camera(Vector2f(975, 750), Vector2f(),Vector2f(0.64, 0.64), main.scene.entities[31].getTransform())
    main.scene.entities[31].addScript(playerMovement)
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
    end
    #push!(main.scene.entities, Entity("game manager", Transform(), [], [gameManager]))

    main.assets = ASSETS
    main.loadScene(main.scene)
    main.init(isUsingEditor)
    return main
end