include("../../../src/Main.jl")

function level_0()
    # Prepare scene
    colliders = [
        Collider(Vector2f(1, 1), Vector2f(), "none")
        Collider(Vector2f(1, 1), Vector2f(), "none")
    ]

    sprites = [
        Sprite(joinpath(@__DIR__, "..", "assets", "images", "SkeletonWalk.png"), 16)
        Sprite(joinpath(@__DIR__, "..", "assets", "images", "ground_grass_1.png"), 32)
        ]

    rigidbodies = [
        Rigidbody(1, 0),
    ]

    entities = [
        Entity("player", Transform(Vector2f(0, 2)), [Animator(7, 12.0), sprites[1], colliders[1], rigidbodies[1]]),
        Entity(string("tile", 1), Transform(Vector2f(1, 9)), [sprites[2], colliders[2]])
        ]

    for i in 1:30
        newCollider = Collider(Vector2f(1, 1), Vector2f(), "none")
        newSprite = Sprite(joinpath(@__DIR__, "..", "assets", "images", "ground_grass_1.png"), 32)
        newEntity = Entity(string("tile", i), Transform(Vector2f(i-1, 10)), [newSprite, newCollider])
        push!(entities, newEntity)
        push!(colliders, newCollider)
        push!(sprites, newSprite)
    end

    #Start game
    scene = Scene(colliders, entities, rigidbodies)
    mainLoop  = MainLoop(scene)
    mainLoop.start()
end