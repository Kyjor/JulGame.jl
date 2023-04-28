using JSON3
using StructTypes
using Serialization
using .julgame.TransformModule
using .julgame.SpriteModule
# StructTypes.StructType(::Type{Entities}) = StructTypes.ArrayType()
# StructTypes.StructType(::Type{Entity}) = StructTypes.CustomStruct()
# StructTypes.lower(x::Entity) = x.isActive
# StructTypes.lowertype(::Type{Entity}) = Bool

# StructTypes.StructType(::Type{Component}) = StructTypes.AbstractType()

# StructTypes.StructType(::Type{Animation}) = StructTypes.Struct()
# StructTypes.StructType(::Type{Animator}) = StructTypes.Struct()
# StructTypes.StructType(::Type{Collider}) = StructTypes.Struct()
# StructTypes.StructType(::Type{Rigidbody}) = StructTypes.Struct()
# StructTypes.StructType(::Type{SoundSource}) = StructTypes.Struct()
# StructTypes.StructType(::Type{Sprite}) = StructTypes.Struct()
# StructTypes.StructType(::Type{Transform}) = StructTypes.Struct()

# StructTypes.subtypekey(::Type{Component}) = :type
# StructTypes.subtypes(::Type{Component}) = (animation=Animation, animator=Animator, collider=Collider, rigidbody=Rigidbody, soundSource=SoundSource, sprite=Sprite, transform=Transform)

function getEntities()
    file = open(joinpath(@__DIR__, "..", "scenes", "scene.jg"), "r")
    data = read(file)
    M = open(deserialize, joinpath(@__DIR__, "..", "scenes", "scene.jls"));
    io = IOBuffer()
    io.writable = true
    io.data = M
    println(deserialize(io))
    return C_NULL
    return deserialize(IOBuffer(M))
    file = open(joinpath(@__DIR__, "..", "scenes", "scene.jg"), "r")
    data = read(file)
    fileEntities = deserialize(IOBuffer(data))
    entities = []
    for fileEntity in fileEntities
        newEntity = Entity(fileEntity.name)
        newEntity.isActive = fileEntity.isActive
        #deserializeComponents(Ref{Entity}(newEntity)[1])
        push!(entities, newEntity)
    end
    return entities
end

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

function serializeComponent(component)
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