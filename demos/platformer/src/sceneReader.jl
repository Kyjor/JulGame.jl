using JSON3
include("../../../src/Main.jl")


function getEntities(filePath)
    entitiesJson = read(filePath, String)

    entities = JSON3.read(entitiesJson)
    res = []

    for entity in entities.Entities
        components = []

        for component in entity.components
            push!(components, createComponent(component))
        end

        newEntity = Entity(entity.name)
        newEntity.removeComponent(Transform)
        newEntity.isActive = entity.isActive
        for component in components
            newEntity.addComponent(component)
        end

        push!(res, newEntity)
    end

    return res
end

function createComponent(component)
    if component.type == "Transform"
        return Transform(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y), component.rotation)
    end
end