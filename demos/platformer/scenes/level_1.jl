using .julgame
using .julgame.Math

include("../../../src/Camera.jl")
include("../../../src/Main.jl")
include("../src/sceneReader.jl")

function level_1(isUsingEditor = false)
    #file loading
    ASSETS = joinpath(@__DIR__, "..", "assets")
    main = MAIN

    # main.scene.entities = getEntities()
    # println(main.scene.entities[1].getSprite())
    main.scene.entities = deserializeEntities(joinpath(@__DIR__, "scene.json"))
    main.scene.camera = Camera(Vector2f(975, 750), Vector2f(),Vector2f(0.64, 0.64), main.scene.entities[31].getTransform())

    main.assets = ASSETS
    main.loadScene(main.scene)
    main.init(isUsingEditor)
    return main
end