using JSON3
using StructTypes
using Serialization
using .julgame.TransformModule
using .julgame.SpriteModule

function deserializeEntities(filePath)
    entitiesJson = read(filePath, String)

    entities = JSON3.read(entitiesJson)
    res = []

    for entity in entities.Entities
        components = []

        for component in entity.components
            push!(components, deserializeComponent(component))
        end
        
        newEntity = Entity(entity.name)
        newEntity.id = entity.id
        newEntity.removeComponent(Transform)
        newEntity.isActive = entity.isActive
        for component in components
            newEntity.addComponent(component)
        end
        ASSETS = joinpath(@__DIR__, "..", "assets")

        newEntity.addComponent(Sprite(joinpath(ASSETS, "images", "Floor.png")))
        
        push!(res, newEntity)
    end

    return res
end

function deserializeComponent(component)
    ASSETS = joinpath(@__DIR__, "..", "assets")
    if component.type == "Transform"
        component = StructTypes.constructfrom(Transform, component)
        return component
    elseif component.type == "Animation"
        #return Transform(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y), component.rotation)
    elseif component.type == "Animator"
        #return Transform(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y), component.rotation)
    elseif component.type == "Collider"
        return Collider(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y), component.rotation)
    elseif component.type == "Rigidbody"
        return Transform(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y), component.rotation)
    elseif component.type == "SoundSource"
        #return Transform(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y), component.rotation)
    elseif component.type == "Sprite"
        return Sprite(joinpath(ASSETS, "images", "Floor.png"))
    end
end