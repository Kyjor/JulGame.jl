include("../../../src/Main.jl")
include("../src/sceneReader.jl")

function level_1(isUsingEditor = false)
    #file loading
    ASSETS = joinpath(@__DIR__, "..", "assets")
    main = Main(2.0)

    SceneInstance.entities = getEntities(joinpath(@__DIR__, "ExampleScene.json"))
    SceneInstance.camera =Camera(Vector2f(975, 750), Vector2f(),Vector2f(0.64, 0.64), Transform())

    main.assets = ASSETS
    main.loadScene(SceneInstance)
    main.init(isUsingEditor)
    return main
end