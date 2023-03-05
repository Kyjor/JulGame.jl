include("../../../src/Main.jl")
include("../scripts/playerMovement.jl")

using RelocatableFolders
using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer

const ASSETS = @path joinpath(@__DIR__, "..", "assets")

function level_0()
    mainLoop = MainLoop()

    # Prepare scene
    screenButtons = [
        ScreenButton(Vector2(256, 64), Vector2(500, 800), C_NULL, C_NULL, "Button"),
    ]

    SceneInstance.screenButtons = screenButtons
    
    colliders = [
        Collider(Vector2f(1, 1), Vector2f(), "player")
        Collider(Vector2f(1, 1), Vector2f(), "ground")
    ]

    skeletonWalk = @path joinpath(ASSETS, "images", "SkeletonWalk.png")
    grass = @path joinpath(ASSETS, "images", "ground_grass_1.png")
    sprites = [
        Sprite(skeletonWalk, 16),
        Sprite(grass, 32)
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
        newEntity = Entity(string("tile", i), Transform(Vector2f(i-1, 10)), [Sprite(grass, 32), newCollider])
        push!(colliders, newCollider)
        push!(entities, newEntity)
    end

    camera = Camera(Vector2f(1000, 1000), Vector2f(),Vector2f(0.64, 0.64), entities[1].getTransform())
    click = @path joinpath(ASSETS, "sounds", "click1.wav")
    sounds = [
        SoundSource(click, false),
    ]

    #Start game
    SceneInstance.colliders = colliders
    SceneInstance.entities = entities
    SceneInstance.rigidbodies = rigidbodies
    SceneInstance.camera = camera
    SceneInstance.sounds = sounds

    mainLoop.loadScene(SceneInstance)
    mainLoop.start()
end