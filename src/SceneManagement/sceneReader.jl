module SceneReaderModule
    using JSON3
    using ..SceneManagement.julGame.AnimatorModule
    using ..SceneManagement.julGame.AnimationModule
    using ..SceneManagement.julGame.ColliderModule
    using ..SceneManagement.julGame.EntityModule
    using ..SceneManagement.julGame.Math
    using ..SceneManagement.julGame.RigidbodyModule
    using ..SceneManagement.julGame.SoundSourceModule
    using ..SceneManagement.julGame.SpriteModule
    using ..SceneManagement.julGame.TransformModule

    export deserializeEntities
    function deserializeEntities(basePath, filePath, isEditor)
        entitiesJson = read(filePath, String)

        entities = JSON3.read(entitiesJson)
        res = []

        for entity in entities.Entities
            components = []
            scripts = []

            for component in entity.components
                push!(components, deserializeComponent(basePath, component, isEditor))
            end
            
            for script in entity.scripts
                push!(scripts, script.name)
            end
            
            newEntity = Entity(entity.name)
            newEntity.id = entity.id
            newEntity.removeComponent(Transform)
            newEntity.isActive = entity.isActive
            newEntity.scripts = scripts
            for component in components
                newEntity.addComponent(component)
            end
            
            push!(res, newEntity)
        end

        return res
    end

    export deserializeComponent
    function deserializeComponent(basePath, component, isEditor)
        if component.type == "Transform"
            newComponent = Transform(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y), component.rotation)
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
            if isEditor
                newComponent = SoundSource(basePath, component.path, component.channel, component.volume, component.isMusic)
            else
                newComponent = component.isMusic ? SoundSource(basePath, component.path, component.volume) : SoundSource(component.path, component.channel, component.volume)
            end
        elseif component.type == "Sprite"
            crop = isempty(component.crop) ? C_NULL : Vector4(component.crop.x, component.crop.y, component.crop.z)

            newComponent = Sprite(basePath, component.imagePath, crop, false)
            newComponent.isFlipped = component.isFlipped
        end
        return newComponent
    end
end