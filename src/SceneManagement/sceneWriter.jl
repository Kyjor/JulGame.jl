module SceneWriterModule
    using JSON3

    export serializeEntities
    function serializeEntities(entities::Array, projectPath, sceneName)
        
        entitiesDict = []

        count = 1
        for entity in entities
        push!(entitiesDict, Dict("id" => count, "isActive" => entity.isActive, "name" => entity.name, "components" => serializeEntityComponents(entity.components), "scripts" => serializeEntityScripts(entity.scripts)))
        count += 1
        end
        entitiesJson = Dict( "Entities" => entitiesDict)
        try
            println("writing to $(joinpath(projectPath, "projectFiles", "scenes", "$(sceneName)"))")
            open(joinpath(projectPath, "projectFiles", "scenes", "$(sceneName)"), "w") do io
                JSON3.pretty(io, entitiesJson)
            end
        catch e
            println(e)
        end
    end

    export serializeEntityComponents
    function serializeEntityComponents(components)

        componentsDict = []
        for component in components
            componentType = "$(typeof(component).name.wrapper)"
            componentType = String(split(componentType, '.')[length(split(componentType, '.'))])
            #Dict("b" => 1, "c" => 2)
            ASSETS = joinpath(@__DIR__, "..", "assets")
            if componentType == "Transform"
                serializedComponent = Dict("type" => componentType, "rotation" => component.rotation, "position" => Dict("x" => component.position.x, "y" => component.position.y), "scale" => Dict("x" => component.scale.x, "y" => component.scale.y))
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
                    )
                push!(componentsDict, serializedComponent)
            elseif componentType == "Rigidbody"
                serializedComponent = Dict(
                    "type" => componentType, 
                    "mass" => component.mass, 
                    )
                push!(componentsDict, serializedComponent)
            elseif componentType == "SoundSource"
                serializedComponent = Dict(
                    "type" => componentType, 
                    "channel" => component.channel, 
                    "isMusic" => component.isMusic, 
                    "path" => component.path, 
                    "sound" => component.sound, 
                    "volume" => component.volume, 
                    )
                push!(componentsDict, serializedComponent)
            elseif componentType == "Sprite"
                serializedComponent = Dict(
                    "type" => componentType, 
                    "crop" => component.crop == C_NULL ? C_NULL : Dict("x" => component.crop.x, "y" => component.crop.y, "w" => component.crop.w, "h" => component.crop.h), 
                    "isFlipped" => component.isFlipped, 
                    "imagePath" => component.imagePath
                    )
                push!(componentsDict, serializedComponent)
            end
        end
        return componentsDict
    end

    export serializeEntityScripts
    function serializeEntityScripts(scripts)
        scriptsDict = []

        for script in scripts
            # scriptName = "$(split("$(typeof(script))", '.')[length(split("$(typeof(script))", '.'))])"
            push!(scriptsDict, Dict("name" => script))
        end

        return scriptsDict
    end
end