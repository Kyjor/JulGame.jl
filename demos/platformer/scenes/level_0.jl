include("../../../src/Main.jl")
include("../scripts/playerMovement.jl")

using RelocatableFolders
using SimpleDirectMediaLayer

const ASSETS = @path joinpath(@__DIR__, "..", "assets")

function level_0()
    mainLoop = MainLoop(2.0)

    # Prepare scene
    screenButtons = [
        #ScreenButton(Vector2(256, 64), Vector2(500, 800), C_NULL, C_NULL, "Button"),
    ]

    SceneInstance.screenButtons = screenButtons

    fontPath = @path joinpath(ASSETS, "fonts", "VT323", "VT323-Regular.ttf")
    textBoxes = [
        TextBox(fontPath, 50, Vector2(0, 200), Vector2(1000, 100), Vector2(0, 0), "This is a test message", true),
    ]

    SceneInstance.textBoxes = textBoxes
    
    colliders = [
        Collider(Vector2f(1, 1), Vector2f(), "player")
    ]

    bg = @path joinpath(ASSETS, "images", "parallax-mountain-bg.png")
    curtain = @path joinpath(ASSETS, "images", "curtain.png")
    curtainTop = @path joinpath(ASSETS, "images", "curtaintop.png")
    skeletonWalk = @path joinpath(ASSETS, "images", "Player.png")
    floor = @path joinpath(ASSETS, "images", "Floor.png")
    sprites = [
        Sprite(skeletonWalk),
        Sprite(floor),
    ]

    idleFrames = []
    for i in 1:2
        push!(idleFrames, Vector4((i) * 8, 8, 8, 8))
        println("hi")
    end

    walkFrames = []
    for i in 1:4
        push!(walkFrames, Vector4((i + 1) * 8, 8, 8, 8))
    end

    jumpFrames = []
    push!(jumpFrames, Vector4(6 * 8, 8, 8, 8))

    animations = [
        Animation(idleFrames, 3.0),
        Animation(walkFrames, 4.0),
        Animation(jumpFrames, 0.0)
    ]

    rigidbodies = [
        Rigidbody(1.0, 0),
    ]

    curtLCol = Collider(Vector2f(0.5, 8), Vector2f(), "curtLCol")
    curtRCol = Collider(Vector2f(0.5, 8), Vector2f(), "curtRCol")
    push!(colliders, curtLCol)
    push!(colliders, curtRCol)

    entities = []

    for i in 1:30
        newCollider = Collider(Vector2f(1, 1), Vector2f(), "ground")
        newEntity = Entity(string("tile", i), Transform(Vector2f(i-10, 10)), [Sprite(floor), newCollider])
        push!(colliders, newCollider)
        push!(entities, newEntity)
    end

        #Entity("bg", Transform(Vector2f(-10, -10), Vector2f(54, 32)), [Sprite(bg)]),
    push!(entities, Entity("player", Transform(Vector2f(0, 9)),  [Animator(animations), sprites[1], colliders[1], rigidbodies[1]], [PlayerMovement()]))
    push!(entities, Entity("camera target", Transform(Vector2f(0, 7.75))))
    push!(entities, Entity("curtain left", Transform(Vector2f(-7, 2), Vector2f(2, 8)),  [Sprite(curtain), curtLCol]))
    push!(entities, Entity("curtain right", Transform(Vector2f(6, 2), Vector2f(2, 8)),  [Sprite(curtain, true)]))
    push!(entities, Entity("curtain right col", Transform(Vector2f(7.5, 2), Vector2f(1, 8)),  [curtRCol]))
    push!(entities, Entity("curtain top", Transform(Vector2f(-5, 1.75), Vector2f(11, 2)),  [Sprite(curtainTop)]))


    camera = Camera(Vector2f(975, 750), Vector2f(),Vector2f(0.64, 0.64), entities[32].getTransform())
    jump = @path joinpath(ASSETS, "sounds", "Jump.wav")
    sounds = [
        SoundSource(jump, false, 2),
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