module SceneReaderModule
    using JSON3
    using ..SceneManagement.JulGame.AnimatorModule
    using ..SceneManagement.JulGame.AnimationModule
    using ..SceneManagement.JulGame.ColliderModule
    using ..SceneManagement.JulGame.CircleColliderModule
    using ..SceneManagement.JulGame.EntityModule
    using ..SceneManagement.JulGame.Math
    using ..SceneManagement.JulGame.RigidbodyModule
    using ..SceneManagement.JulGame.SoundSourceModule
    using ..SceneManagement.JulGame.SpriteModule
    using ..SceneManagement.JulGame.UI.TextBoxModule
    using ..SceneManagement.JulGame.TransformModule


    function scriptObj(name::String, parameters::Array)
        () -> (name; parameters)
    end

    export deserializeScene
    function deserializeScene(filePath, isEditor)
        try
            entitiesJson = read(filePath, String)

            json = JSON3.read(entitiesJson)
            entities =[]
            textBoxes = []
            res = []
    
            for entity in json.Entities
                components = []
                scripts = []
    
                for component in entity.components
                    push!(components, deserializeComponent(component, isEditor))
                end
                
                for script in entity.scripts
                    scriptParameters = []
                    for scriptParameter in script.parameters
                        push!(scriptParameters, scriptParameter)
                    end
                    scriptObject = scriptObj(script.name, scriptParameters)
                    push!(scripts, scriptObject)
                end
                
                newEntity = Entity(entity.name)
                newEntity.id = entity.id
                newEntity.removeComponent(Transform)
                newEntity.isActive = entity.isActive
                newEntity.scripts = scripts
                for component in components
                    newEntity.addComponent(component)
                end
                
                push!(entities, newEntity)
            end
            textBoxes = deserializeTextBoxes(json.TextBoxes, isEditor)
    
            push!(res, entities)
            push!(res, textBoxes)
            return res
        catch e 
            println(e)
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end

    function deserializeTextBoxes(jsonTextBoxes, isEditor = false)
        res = []

        for textBox in jsonTextBoxes
            try
                newTextBox = TextBox(textBox.name, textBox.fontPath, textBox.fontSize, Vector2(textBox.position.x, textBox.position.y), textBox.text, textBox.isCenteredX, textBox.isCenteredY, textBox.isDefaultFont, isEditor)        
                push!(res, newTextBox)
            catch e 
                println(e)
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end

        return res
    end

    export deserializeComponent
    function deserializeComponent(component, isEditor)
        try
            if component.type == "Transform"
                newComponent = Transform(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y), Float64(component.rotation))
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
                newComponent = Collider(Vector2f(component.size.x, component.size.y), Vector2f(), component.tag)
                newComponent.isTrigger = !haskey(component, "isTrigger") ? false : component.isTrigger
                newComponent.offset = !haskey(component, "offset") ? Vector2f() : Vector2f(component.offset.x, component.offset.y)
            elseif component.type == "CircleCollider"
                newComponent = CircleCollider(convert(Float64, component.diameter), Vector2f(component.offset.x, component.offset.y), component.tag)
            elseif component.type == "Rigidbody"
                newComponent = Rigidbody(convert(Float64, component.mass))
            elseif component.type == "SoundSource"
                if isEditor
                    newComponent = SoundSource(component.path, component.channel, component.volume, component.isMusic)
                else
                    newComponent = component.isMusic ? SoundSource(component.path, component.volume) : SoundSource(component.path, component.channel, component.volume)
                end
            elseif component.type == "Sprite"
                crop = !haskey(component, "crop") || isempty(component.crop) ? Vector4() : Vector4(component.crop.x, component.crop.y, component.crop.w, component.crop.h)
                newComponent = Sprite(component.imagePath, crop, component.isFlipped)
            end
            
            return newComponent
        catch e
            println(e)
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
end