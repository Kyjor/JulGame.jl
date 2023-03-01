include("../../../src/Main.jl")
include("../scripts/playerMovement.jl")

function level_0()
    # Prepare scene
    screenButtons = [
        ScreenButton(Vector2f(256.0, 64.0), Vector2f(), C_NULL)
        ]
    SceneInstance.screenButtons = screenButtons
    
    colliders = [
        Collider(Vector2f(1, 1), Vector2f(), "player")
        Collider(Vector2f(1, 1), Vector2f(), "ground")
    ]

    sprites = [
        Sprite(joinpath(@__DIR__, "..", "assets", "images", "SkeletonWalk.png"), 16)
        Sprite(joinpath(@__DIR__, "..", "assets", "images", "ground_grass_1.png"), 32)
        ]

    rigidbodies = [
        Rigidbody(1.0, 0),
    ]

    entities = [
        Entity("player", Transform(Vector2f(0, 2)), [Animator(7, 12.0), sprites[1], colliders[1], rigidbodies[1]], [PlayerMovement()]),
        Entity(string("tile", 1), Transform(Vector2f(1, 9)), [sprites[2], colliders[2]]),
        ]

    for i in 1:30
        newCollider = Collider(Vector2f(1, 1), Vector2f(), "ground")
        newEntity = Entity(string("tile", i), Transform(Vector2f(i-1, 10)), [Sprite(joinpath(@__DIR__, "..", "assets", "images", "ground_grass_1.png"), 32), newCollider])
        push!(colliders, newCollider)
        push!(entities, newEntity)
    end

    camera = Camera(Vector2f(1000, 1000), Vector2f(),Vector2f(0.64, 0.64), entities[1].getTransform())

    #Start game
    SceneInstance.colliders = colliders
    SceneInstance.entities = entities
    SceneInstance.rigidbodies = rigidbodies
    SceneInstance.camera = camera

    mainLoop = MainLoop(SceneInstance)
    mainLoop.start()
end