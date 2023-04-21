using .julgame
include("../../../src/UI/TextBox.jl")
include("../../../src/Component/Animation.jl")
include("../../../src/Entity.jl")
include("../../../src/Camera.jl")
include("../../../src/Component/Animator.jl")
include("../../../src/Component/Rigidbody.jl")
include("../../../src/Component/SoundSource.jl")
include("../../../src/Component/Sprite.jl")
include("../../../src/Component/Transform.jl")
include("../../../src/Main.jl")

include("../scripts/dialogue.jl")
include("../scripts/fullGameDialogue.jl")
include("../scripts/gameManager.jl")
include("../scripts/playerMovement.jl")

function level_0(isUsingEditor = false)
    #file loading
    ASSETS = joinpath(@__DIR__, "..", "assets")

    fontPath = joinpath(ASSETS, "fonts", "VT323", "VT323-Regular.ttf")

    #images
    blockImage = joinpath(ASSETS, "images", "MoneyBlocks.png")
    goldPot = joinpath(ASSETS, "images", "Gold.png")
    curtain = joinpath(ASSETS, "images", "curtain.png")
    curtainTop = joinpath(ASSETS, "images", "curtaintop.png")
    floor = joinpath(ASSETS, "images", "Floor.png")
    playerImage = joinpath(ASSETS, "images", "Player.png")
    speakerImage = joinpath(ASSETS, "images", "Speaker.png")
    #audio
    aww = joinpath(ASSETS, "sounds", "aww.wav")
    boo = joinpath(ASSETS, "sounds", "boo.wav")
    crowd = joinpath(ASSETS, "sounds", "crowd.mp3")
    falling = joinpath(ASSETS, "sounds", "falling.mp3")
    gasp = joinpath(ASSETS, "sounds", "gasp.wav")
    hittingground = joinpath(ASSETS, "sounds", "hittingground.mp3")
    jump = joinpath(ASSETS, "sounds", "Jump.wav")
    laughing = joinpath(ASSETS, "sounds", "laughing.wav")
    poof = joinpath(ASSETS, "sounds", "poof.mp3")
    speech = joinpath(ASSETS, "sounds", "speech.wav")
    smallApplause = joinpath(ASSETS, "sounds", "small-applause.mp3")

    
    main = MAIN

    gameManager = GameManager()

    playerMovement = PlayerMovement(false)
    playerMovement.gameManager = gameManager
    
    gameDialogue = Dialogue(narratorScript, 0.05, 1.5, gameManager, playerMovement)
    gameDialogue.isPaused = true
    
    secretDialogue = Dialogue(secretManScript, 0.05, 1.5, gameManager, playerMovement)
    secretDialogue.isNormalDialogue = false
    secretDialogue.isPaused = true

    gameManager.playerMovement = playerMovement
    gameManager.dialogue = gameDialogue
    gameManager.secretDialogue = secretDialogue

    textBoxes = [
        TextBox(fontPath, 40, Vector2(0, 200), Vector2(1000, 100), Vector2(0, 0), "Press space to begin...", true),
        TextBox(fontPath, 20, Vector2(75, 375), Vector2(1000, 100), Vector2(0, 0), " ", false),
    ]

    gameManager.textBox = textBoxes[1]

    main.scene.textBoxes = textBoxes
    
    colliders = [
        Collider(Vector2f(1, 1), Vector2f(), "player")
    ]

    sprites = [
        Sprite(playerImage),
        Sprite(floor),
    ]

    idleFrames = []
    for x in 1:4
        frames = []
        for i in 1:2
            push!(frames, Vector4((i) * 8, (x - 1) * 9, 8, 8))
        end
        push!(idleFrames, frames)
    end

    walkFrames = []
    for x in 1:4
        frames = []
        for i in 1:4
            push!(frames, Vector4((i + 1) * 8, (x - 1) * 9, 8, 8))
        end
        push!(walkFrames, frames)
    end

    playerAnimations = [
        # form 0
        Animation(idleFrames[1], 3.0),
        Animation(walkFrames[1], 4.0),
        Animation([Vector4(6 * 8, 0, 8, 8)], 0.0),
        Animation([Vector4(7 * 8, 0, 8, 8)], 0.0),
        # form 1
        Animation(idleFrames[2], 3.0),
        Animation(walkFrames[2], 4.0),
        Animation([Vector4(6 * 8, 9, 8, 8)], 0.0),
        Animation([Vector4(7 * 8, 9, 8, 8)], 0.0),
        # form 2
        Animation(idleFrames[3], 3.0),
        Animation(walkFrames[3], 4.0),
        Animation([Vector4(6 * 8, 2 * 9, 8, 8)], 0.0),
        Animation([Vector4(7 * 8, 2 * 9, 8, 8)], 0.0),
        # form 3
        Animation(idleFrames[4], 3.0),
        Animation(walkFrames[4], 4.0),
        Animation([Vector4(6 * 8, 3 * 9, 8, 8)], 0.0),
        Animation([Vector4(7 * 8, 3 * 9, 8, 8)], 0.0),
    ]

    rigidbodies = [
        Rigidbody(1.0, 0),
    ]

    curtLCol = Collider(Vector2f(0.5, 8), Vector2f(), "curtLCol")
    curtRCol = Collider(Vector2f(0.5, 8), Vector2f(), "curtRCol")
    push!(colliders, curtLCol)
    push!(colliders, curtRCol)

    #Player and scene
    entities = []

    for i in 1:30
        newEntity = Entity(string("tile", i), Transform(Vector2f(i-10, 10)), [Sprite(floor), Collider(Vector2f(1, 1), Vector2f(), "ground")])
        push!(colliders, newEntity.getCollider())
        push!(entities, newEntity)
    end

    push!(entities, Entity("player", Transform(Vector2f(10, 9)),  [Animator(playerAnimations), sprites[1], colliders[1], rigidbodies[1]], [playerMovement]))
    push!(entities, Entity("camera target", Transform(Vector2f(0, 7.75))))
    push!(entities, Entity("curtain left", Transform(Vector2f(-7, 2), Vector2f(2, 8)),  [Sprite(curtain), curtLCol]))
    push!(entities, Entity("curtain right", Transform(Vector2f(6, 2), Vector2f(2, 8)),  [Sprite(curtain, true)]))
    push!(entities, Entity("curtain right col", Transform(Vector2f(7.5, 2), Vector2f(1, 8)),  [curtRCol]))
    push!(entities, Entity("curtain top", Transform(Vector2f(-5, 1.75), Vector2f(11, 2)),  [Sprite(curtainTop)]))
    push!(entities, Entity("dialogue", Transform(Vector2f())))
    entities[37].addScript(gameDialogue)

    #Platforms 
    platforms = [
        Entity(string("tile"), Transform(Vector2f(2, 9)), [Sprite(floor), Collider(Vector2f(1, 1), Vector2f(), "ground")]),
        Entity(string("tile"), Transform(Vector2f(0, 6)), [Sprite(floor), Collider(Vector2f(1, 1), Vector2f(), "ground")]),
        Entity(string("tile"), Transform(Vector2f(4, 8)), [Sprite(floor), Collider(Vector2f(1, 1), Vector2f(), "ground")]),
        Entity(string("tile"), Transform(Vector2f(5, 7)), [Sprite(floor), Collider(Vector2f(1, 1), Vector2f(), "ground")]),
    ]

    for platform in platforms
        push!(entities, platform)
        push!(colliders, platform.getCollider())
        platform.isActive = false
    end

    gameManager.platforms = platforms

    #Gold Pot
    gold = Entity(string("tile"), Transform(Vector2f(2, 6)), [Sprite(goldPot), Collider(Vector2f(1, 1), Vector2f(), "gold")])
    push!(entities, gold)
    push!(colliders, gold.getCollider())
    gameManager.goldPot = gold
    gold.isActive = false
  
    #Money Blocks
    block1Frames = []
    block2Frames = []
    block3Frames = []
    for i in 1:4
        push!(block1Frames, Vector4((i - 1) * 8, 0, 8, 8))
        push!(block2Frames, Vector4((i + 3) * 8, 0, 8, 8))
        push!(block3Frames, Vector4((i + 7) * 8, 0, 8, 8))
    end

    blockAnims = [
        Animation(block1Frames, 2.0),
        Animation(block2Frames, 2.0),
        Animation(block3Frames, 2.0),
    ]

    moneyBlocks = [
        Entity(string("tile"), Transform(Vector2f(-2, 7)), [Animator([blockAnims[2]]), Sprite(blockImage), Collider(Vector2f(1, 1), Vector2f(), "block")]),
        Entity(string("tile"), Transform(Vector2f(0, 7)), [Animator([blockAnims[1]]), Sprite(blockImage), Collider(Vector2f(1, 1), Vector2f(), "block")]),
        Entity(string("tile"), Transform(Vector2f(2, 7)), [Animator([blockAnims[3]]), Sprite(blockImage), Collider(Vector2f(1, 1), Vector2f(), "block")]),
    ]

    for moneyBlock in moneyBlocks
        push!(entities, moneyBlock)
        push!(colliders, moneyBlock.getCollider())

        moneyBlock.isActive = false
    end
    gameManager.moneyBlocks = moneyBlocks

    camera = Camera(Vector2f(975, 750), Vector2f(),Vector2f(0.64, 0.64), entities[32].getTransform())

    sounds = [
        SoundSource(jump, 0, 7),
        SoundSource(speech, 1, 2),
        SoundSource(poof, 2, 20),
        SoundSource(smallApplause, 3, 10),
        SoundSource(laughing, 3, 10),
        SoundSource(aww, 3, 10),
        SoundSource(gasp, 3, 10),
        SoundSource(boo, 3, 10),
        SoundSource(falling, 4, 10),
        SoundSource(hittingground, 4, 10),
    ]

    # crowdSound = SoundSource(crowd, 8)
    # crowdSound.toggleSound()

    push!(entities, Entity("game manager", Transform(), [], [gameManager]))
    for i in -15:-10
        newEntity = Entity(string("tile", i), Transform(Vector2f(i, 10)), [Sprite(floor), Collider(Vector2f(1, 1), Vector2f(), "ground")])
        push!(colliders, newEntity.getCollider())
        push!(entities, newEntity)
    end

    speaker = Entity(string("speaker"), Transform(Vector2f(-14, 9), Vector2f(2,1)), [Sprite(speakerImage)])
    push!(entities, speaker)
    push!(entities, Entity("dialogue", Transform(Vector2f())))
    entities[length(entities)].addScript(secretDialogue)

    #Start game
    main.scene.camera = camera
    main.scene.colliders = colliders
    main.scene.entities = entities
    main.scene.rigidbodies = rigidbodies
    main.scene.screenButtons = []
    main.scene.sounds = sounds

    main.assets = ASSETS
    main.loadScene(main.scene)
    main.init(isUsingEditor)
    return main
end