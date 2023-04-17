include("../../../src/Main.jl")
include("../src/sceneReader.jl")

function level_1(isUsingEditor = false)
    #file loading
    ASSETS = joinpath(@__DIR__, "..", "assets")


    mainLoop = MainLoop(2.0)

    SceneInstance.entities = getEntities("ExampleScene.json")
    #Start game
    SceneInstance.camera = camera
    SceneInstance.colliders = colliders
    SceneInstance.entities = entities
    SceneInstance.rigidbodies = rigidbodies
    SceneInstance.screenButtons = []
    SceneInstance.sounds = sounds

    mainLoop.assets = ASSETS
    mainLoop.loadScene(SceneInstance)
    mainLoop.init(isUsingEditor)
    return mainLoop
end