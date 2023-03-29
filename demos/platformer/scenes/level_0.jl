include("../../../src/Main.jl")

include("../scripts/dialogue.jl")
include("../scripts/fullGameDialogue.jl")
include("../scripts/gameManager.jl")
include("../scripts/playerMovement.jl")

using RelocatableFolders
using SimpleDirectMediaLayer

const ASSETS = @path joinpath(@__DIR__, "..", "assets")

function level_0()
    mainLoop = MainLoop(2.0)

    gameManager = GameManager()

    playerMovement = PlayerMovement(false)
    gameDialogue = Dialogue(narratorScript, 0.05, 1.5, gameManager, playerMovement)
    secretDialogue = Dialogue(secretManScript, 0.05, 1.5, gameManager, playerMovement)
    secretDialogue.isNormalDialogue = false
    secretDialogue.isPaused = true

    gameManager.playerMovement = playerMovement
    playerMovement.gameManager = gameManager
    gameManager.dialogue = gameDialogue
    gameManager.secretDialogue = secretDialogue

    # Prepare scene
    screenButtons = [
        #ScreenButton(Vector2(256, 64), Vector2(500, 800), C_NULL, C_NULL, "Button"),
    ]

    SceneInstance.screenButtons = screenButtons

    fontPath = @path joinpath(ASSETS, "fonts", "VT323", "VT323-Regular.ttf")
    textBoxes = [
        TextBox(fontPath, 40, Vector2(0, 200), Vector2(1000, 100), Vector2(0, 0), " ", true),
        TextBox(fontPath, 20, Vector2(75, 375), Vector2(1000, 100), Vector2(0, 0), " ", false),
    ]

    SceneInstance.textBoxes = textBoxes
    
    colliders = [
        Collider(Vector2f(1, 1), Vector2f(), "player")
    ]

    blockImage = @path joinpath(ASSETS, "images", "MoneyBlocks.png")
    goldPot = @path joinpath(ASSETS, "images", "Gold.png")
    curtain = @path joinpath(ASSETS, "images", "curtain.png")
    curtainTop = @path joinpath(ASSETS, "images", "curtaintop.png")
    playerImage = @path joinpath(ASSETS, "images", "Player.png")
    speakerImage = @path joinpath(ASSETS, "images", "Speaker.png")
    floor = @path joinpath(ASSETS, "images", "Floor.png")
    sprites = [
        Sprite(playerImage),
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

    playerAnimations = [
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

    #Player and scene
    entities = []

    for i in 1:30
        newCollider = Collider(Vector2f(1, 1), Vector2f(), "ground")
        newEntity = Entity(string("tile", i), Transform(Vector2f(i-10, 10)), [Sprite(floor), newCollider])
        push!(colliders, newCollider)
        push!(entities, newEntity)
    end

    push!(entities, Entity("player", Transform(Vector2f(0, 9)),  [Animator(playerAnimations), sprites[1], colliders[1], rigidbodies[1]], [playerMovement]))
    push!(entities, Entity("camera target", Transform(Vector2f(0, 7.75))))
    push!(entities, Entity("curtain left", Transform(Vector2f(-7, 2), Vector2f(2, 8)),  [Sprite(curtain), curtLCol]))
    push!(entities, Entity("curtain right", Transform(Vector2f(6, 2), Vector2f(2, 8)),  [Sprite(curtain, true)]))
    push!(entities, Entity("curtain right col", Transform(Vector2f(7.5, 2), Vector2f(1, 8)),  [curtRCol]))
    push!(entities, Entity("curtain top", Transform(Vector2f(-5, 1.75), Vector2f(11, 2)),  [Sprite(curtainTop)]))
    push!(entities, Entity("dialogue", Transform(Vector2f())))
    entities[37].addScript(gameDialogue)

    #Platforms 
    platforms = []
    newCollider = Collider(Vector2f(1, 1), Vector2f(), "ground")
    platform = Entity(string("tile"), Transform(Vector2f(2, 9)), [Sprite(floor), newCollider])
    push!(entities, platform)
    push!(platforms, platform)
    push!(colliders, newCollider)
    newCollider = Collider(Vector2f(1, 1), Vector2f(), "ground")
    platform = Entity(string("tile"), Transform(Vector2f(0, 6)), [Sprite(floor), newCollider])
    push!(entities, platform)
    push!(platforms, platform)
    push!(colliders, newCollider)
    newCollider = Collider(Vector2f(1, 1), Vector2f(), "ground")
    platform = Entity(string("tile"), Transform(Vector2f(4, 8)), [Sprite(floor), newCollider])
    push!(entities, platform)
    push!(platforms, platform)
    push!(colliders, newCollider)
    newCollider = Collider(Vector2f(1, 1), Vector2f(), "ground")
    platform = Entity(string("tile"), Transform(Vector2f(5, 7)), [Sprite(floor), newCollider])
    push!(entities, platform)
    push!(platforms, platform)
    push!(colliders, newCollider)
    for plat in platforms
       plat.isActive = false
    end
    gameManager.platforms = platforms

      #Gold Pot
      newCollider = Collider(Vector2f(1, 1), Vector2f(), "gold")
      gold = Entity(string("tile"), Transform(Vector2f(2, 6)), [Sprite(goldPot), newCollider])
      push!(entities, gold)
      push!(colliders, newCollider)
      gameManager.goldPot = gold
      gold.isActive = false
  
    #Money Blocks
    block1Frames = []
    block2Frames = []
    block3Frames = []
    for i in 1:4
        push!(block1Frames, Vector4((i - 1) * 8, 8, 8, 8))
        push!(block2Frames, Vector4((i + 3) * 8, 8, 8, 8))
        push!(block3Frames, Vector4((i + 7) * 8, 8, 8, 8))
    end

    blockAnims = [
        Animation(block1Frames, 2.0),
        Animation(block2Frames, 2.0),
        Animation(block3Frames, 2.0),
    ]

    moneyBlocks = []
    newCollider = Collider(Vector2f(1, 1), Vector2f(), "block")
    block = Entity(string("tile"), Transform(Vector2f(-2, 7)), [Animator([blockAnims[2]]), Sprite(blockImage), newCollider])
    push!(entities, block)
    push!(moneyBlocks, block)
    push!(colliders, newCollider)
    newCollider = Collider(Vector2f(1, 1), Vector2f(), "block")
    block = Entity(string("tile"), Transform(Vector2f(0, 7)), [Animator([blockAnims[1]]), Sprite(blockImage), newCollider])
    push!(entities, block)
    push!(moneyBlocks, block)
    push!(colliders, newCollider)
    newCollider = Collider(Vector2f(1, 1), Vector2f(), "block")
    block = Entity(string("tile"), Transform(Vector2f(2, 7)), [Animator([blockAnims[3]]), Sprite(blockImage), newCollider])
    push!(entities, block)
    push!(moneyBlocks, block)
    push!(colliders, newCollider)
    for moneyBlock in moneyBlocks
        moneyBlock.isActive = false
    end
    gameManager.moneyBlocks = moneyBlocks

    camera = Camera(Vector2f(975, 750), Vector2f(),Vector2f(0.64, 0.64), entities[32].getTransform())
    jump = @path joinpath(ASSETS, "sounds", "Jump.wav")
    speech = @path joinpath(ASSETS, "sounds", "speech.wav")
    sounds = [
        SoundSource(jump, false, 2),
        SoundSource(speech, false, 2),
    ]

    push!(entities, Entity("game manager", Transform(), [], [gameManager]))
    for i in -15:-10
        println(i)
        newCollider = Collider(Vector2f(1, 1), Vector2f(), "ground")
        newEntity = Entity(string("tile", i), Transform(Vector2f(i, 10)), [Sprite(floor), newCollider])
        push!(colliders, newCollider)
        push!(entities, newEntity)
    end

    speaker = Entity(string("speaker"), Transform(Vector2f(-14, 9), Vector2f(2,1)), [Sprite(speakerImage)])
    push!(entities, speaker)
    push!(entities, Entity("dialogue", Transform(Vector2f())))
    entities[length(entities)].addScript(secretDialogue)

    #Start game
    SceneInstance.colliders = colliders
    SceneInstance.entities = entities
    SceneInstance.rigidbodies = rigidbodies
    SceneInstance.camera = camera
    SceneInstance.sounds = sounds

    mainLoop.loadScene(SceneInstance)
    mainLoop.start()
end