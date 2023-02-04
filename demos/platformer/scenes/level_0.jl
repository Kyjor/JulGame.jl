include("../../../src/Main0.jl")

# Prepare scene
colliders = [
	Collider(Vector2f(1, 1), Vector2f(), "none")
	Collider(Vector2f(1, 1), Vector2f(), "none")
]
sprites = [
    Sprite(7, joinpath(@__DIR__, "..", "assets", "images", "SkeletonWalk.png"), 16)
    Sprite(1, joinpath(@__DIR__, "..", "assets", "images", "ground_grass_1.png"), 32)
    ]
rigidbodies = [
	Rigidbody(1, 0)
]

entities = [
    Entity("player", Transform(Vector2f(0, 2))),
    Entity(string("tile", 1), Transform(Vector2f(1, 9)))
    ]
test = Entity("player", Transform(Vector2f(0, 2))),
entities[1].addComponent(sprites[1])
entities[1].addComponent(colliders[1])
entities[1].addComponent(rigidbodies[1])

entities[2].addComponent(sprites[2])
entities[2].addComponent(colliders[2])

for i in 1:30
    newCollider = Collider(Vector2f(1, 1), Vector2f(), "none")
    newSprite = Sprite(1, joinpath(@__DIR__, "..", "assets", "images", "ground_grass_1.png"), 32)
    newEntity = Entity(string("tile", i), Transform(Vector2f(i-1, 10)))
	newEntity.addComponent(newSprite)
	newEntity.addComponent(newCollider)
    push!(entities, newEntity)
    push!(colliders, newCollider)
    push!(sprites, newSprite)
end

#Initialize scene
scene = Scene(colliders, entities, rigidbodies, sprites)
mainLoop  = MainLoop(scene)
mainLoop.start()