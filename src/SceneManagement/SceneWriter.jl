module SceneWriterModule
    using JSON3

    export serialize_entities
    """
        serialize_entities(entities::Array, textBoxes::Array, projectPath, sceneName)

    Serialize the entities and text boxes into a JSON file.

    # Arguments
    - `entities::Array`: An array of entities to be serialized.
    - `textBoxes::Array`: An array of text boxes to be serialized.
    - `projectPath`: The path to the project directory.
    - `sceneName`: The name of the scene.

    """
    function serialize_entities(entities::Array, textBoxes::Array, projectPath, sceneName)
        
        entitiesDict = []
        textBoxesDict = []

        count = 1
        for entity in entities
        push!(entitiesDict, Dict("id" => count, "isActive" => entity.isActive, "name" => entity.name, "components" => serialize_entity_components([entity.animator, entity.collider, entity.circleCollider, entity.rigidbody, entity.shape, entity.soundSource, entity.sprite, entity.transform]), "scripts" => serialize_entity_scripts(entity.scripts)))
        count += 1
        end
        count = 1
        for textBox in textBoxes
        push!(textBoxesDict, Dict(
            "id" => count, 
            "alpha" => textBox.alpha, 
            "fontPath" => normalize_path(textBox.fontPath), 
            "fontSize" => textBox.fontSize, 
            "isCenteredX" => textBox.isCenteredX,
            "isCenteredY" => textBox.isCenteredY,
            "isDefaultFont" => textBox.isDefaultFont,
            "isTextUpdated" => textBox.isTextUpdated,
            "isWorldEntity" => textBox.isWorldEntity,
            "name" => textBox.name,
            "persistentBetweenScenes" => textBox.persistentBetweenScenes,
            "position" => Dict("x" => textBox.position.x, "y" => textBox.position.y),
            "size" => Dict("x" => textBox.size.x, "y" => textBox.size.y),
            "text" => textBox.text
            ))
        count += 1
        end
        entitiesJson = Dict( 
            "Entities" => entitiesDict,
            "TextBoxes" => textBoxesDict
            )
        try
            println("writing to $(joinpath(projectPath, "scenes", "$(sceneName)"))")
            open(joinpath(projectPath, "scenes", "$(sceneName)"), "w") do io
                JSON3.pretty(io, entitiesJson)
            end
        catch e
            println(e)
			Base.show_backtrace(stdout, catch_backtrace())
            rethrow(e)
        end
    end

    export serialize_entity_components
    """
        serialize_entity_components(components)

    Serialize the given entity components into a dictionary representation.

    # Arguments
    - `components`: An array of entity components.

    # Returns
    - `componentsDict`: A dictionary representation of the serialized components.

    """
    function serialize_entity_components(components)

        componentsDict = []
        for component in components
            componentType = "$(typeof(component).name.wrapper)"
            componentType = String(split(componentType, '.')[length(split(componentType, '.'))])
            componentType = replace(componentType, "Internal" => "")
            if componentType == "Transform"
                serializedComponent = Dict("type" => componentType, "position" => Dict("x" => component.position.x, "y" => component.position.y), "scale" => Dict("x" => component.scale.x, "y" => component.scale.y))
                push!(componentsDict, serializedComponent)
            elseif componentType == "Animation"
                serializedComponent = Dict(
                    "type" => componentType, 
                    "frames" => component.frames, 
                    "animatedFPS" => component.animatedFPS            
                    )
                push!(componentsDict, serializedComponent)
            elseif componentType == "Animator"
                serializedAnimations = []
                for animation in component.animations
                    serializedAnimation = Dict(
                        "frames" => animation.frames, 
                        "animatedFPS" => animation.animatedFPS            
                        )
                push!(serializedAnimations, serializedAnimation)
                end
                push!(componentsDict, Dict("type" => componentType, "animations" => serializedAnimations))
            elseif componentType == "Collider"
                serializedComponent = Dict(
                    "type" => componentType, 
                    "size" => Dict("x" => component.size.x, "y" => component.size.y), 
                    "tag" => component.tag, 
                    "isTrigger" => component.isTrigger, 
                    "offset" => Dict("x" => component.offset.x, "y" => component.offset.y),
                    "enabled" => component.enabled,
                    "isPlatformerCollider" => component.isPlatformerCollider,
                    )
                push!(componentsDict, serializedComponent)
            elseif componentType == "Rigidbody"
                serializedComponent = Dict(
                    "type" => componentType, 
                    "mass" => component.mass, 
                    "drag" => component.drag,
                    "useGravity" => component.useGravity,
                    )
                push!(componentsDict, serializedComponent)
            elseif componentType == "SoundSource"
                serializedComponent = Dict(
                    "type" => componentType, 
                    "channel" => component.channel, 
                    "isMusic" => component.isMusic, 
                    "path" => normalize_path(component.path), 
                    "sound" => component.sound, 
                    "volume" => component.volume, 
                    )
                push!(componentsDict, serializedComponent)
            elseif componentType == "Sprite"
                serializedComponent = Dict(
                    "type" => componentType, 
                    "crop" => component.crop == C_NULL ? C_NULL : Dict("x" => component.crop.x, "y" => component.crop.y, "z" => component.crop.z, "t" => component.crop.t), 
                    "isFlipped" => component.isFlipped, 
                    "imagePath" => normalize_path(component.imagePath),
                    "layer" => component.layer,
                    "isWorldEntity" => component.isWorldEntity,
                    "pixelsPerUnit" => component.pixelsPerUnit,
                    "offset" => Dict("x" => component.offset.x, "y" => component.offset.y),
                    "position" => Dict("x" => component.position.x, "y" => component.position.y),
                    "rotation" => component.rotation,
                    "center" => Dict("x" => component.center.x, "y" => component.center.y),
                    "color" => Dict("x" => component.color.x, "y" => component.color.y, "z" => component.color.z),
                    "size" => Dict("x" => component.size.x, "y" => component.size.y),
                    )
                push!(componentsDict, serializedComponent)
            elseif "$componentType" != "Ptr"
                println("Component type $(componentType) not supported")
            end
        end
        return componentsDict
    end

    """
        normalize_path(path)

    Normalize the given path by replacing backslashes with forward slashes.

    # Arguments
    - `path`: The path to be normalized.

    # Returns
    The normalized path with forward slashes.

    """
    function normalize_path(path)
        return replace(joinpath(path), "\\" => "//")
    end

    export serialize_entity_scripts
    """
        serialize_entity_scripts(scripts)

    Serialize a list of scripts into a dictionary format.

    # Arguments
    - `scripts`: A list of scripts to be serialized.

    # Returns
    - `scriptsDict`: A dictionary containing the serialized scripts.

    """
    function serialize_entity_scripts(scripts)
        scriptsDict = []

        for script in scripts
            push!(scriptsDict, Dict("name" => script.name, "parameters" => script.parameters))
        end

        return scriptsDict
    end
end