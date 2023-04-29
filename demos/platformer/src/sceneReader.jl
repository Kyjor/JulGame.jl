using JSON3
using StructTypes
using Serialization
using .julgame.AnimatorModule
using .julgame.AnimationModule
using .julgame.Math
using .julgame.ColliderModule
using .julgame.RigidbodyModule
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
        
        push!(res, newEntity)
    end

    return res
end

function deserializeComponent(component)
    ASSETS = joinpath(@__DIR__, "..", "assets")
    if component.type == "Transform"
        newComponent = StructTypes.constructfrom(Transform, component)
    elseif component.type == "Animation"
        newComponent = Animation(component.frames, component.animatedFPS)
    elseif component.type == "Animator"
        newAnimations = []
        for animation in component.animations
           newAnimationFrames = []
           for animationFrame in animation.frames
              push!(newAnimationFrames, Vector4(animationFrame.x, animationFrame.y, animationFrame.w, animationFrame.h))
           end
           push!(newAnimations, Animation(newAnimationFrames, animation.animatedFPS))
        end
        newComponent = Animator(newAnimations)
    elseif component.type == "Collider"
        newComponent = Collider(Vector2f(component.size.x, component.size.y), component.tag)
    elseif component.type == "Rigidbody"
        newComponent = Rigidbody(convert(Float64, component.mass))
    elseif component.type == "SoundSource"
        newComponent = component.isMusic ? SoundSource(component.path, component.volume) : SoundSource(component.path, component.channel, component.volume)
    elseif component.type == "Sprite"
        crop = isempty(component.crop) ? C_NULL : Vector4(component.crop.x, component.crop.y, component.crop.z)
        newComponent = Sprite(component.imagePath, crop)
        newComponent.isFlipped = component.isFlipped
    end
    return newComponent
end