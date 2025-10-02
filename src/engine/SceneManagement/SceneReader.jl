module SceneReaderModule
    using JSON3
    using ...AnimatorModule
    using ...AnimationModule
    using ...CameraModule
    using ...ColliderModule
    using ...CircleColliderModule
    using ...EntityModule
    using ...Math
    using ...RigidbodyModule
    using ...ShapeModule
    using ...SoundSourceModule
    using ...SpriteModule
    using ...UI.TextBoxModule
    using ...UI.ScreenButtonModule
    using ...UI.UIImageModule
    using ...TransformModule
    using ...JulGame


    function scriptObj(name::String, fields::Array)
        () -> (name; fields)
    end

    export preload_scene
    """
        preload_scene(filePath::String)

    Preloads a scene from the specified file path and stores it in the PRELOADED_SCENES cache.
    This allows for faster scene switching as the scene is already loaded in memory.

    # Arguments
    - `filePath::String`: The path to the scene file to preload
    """
    function preload_scene(filePath::String)
        try
            if haskey(JulGame.PRELOADED_SCENES, basename(filePath))
                @debug("Scene already preloaded: $(basename(filePath))")
                return
            end

            scene = deserialize_scene(filePath)
            JulGame.PRELOADED_SCENES[basename(filePath)] = (entities = scene[1], uiElements = scene[2], camera = scene[3])
            @debug("Preloaded scene: $(basename(filePath))")
        catch e
            @error string(e)
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end

    export deserialize_scene
    function deserialize_scene(filePath)
        try
            if haskey(JulGame.PRELOADED_SCENES, basename(filePath))
                @debug "deserialize_scene: Using preloaded scene: $(basename(filePath))"
                return JulGame.PRELOADED_SCENES[basename(filePath)]
            end

            json = nothing
            if haskey(JulGame.SCENE_CACHE, basename(filePath))
                json = JulGame.SCENE_CACHE[basename(filePath)]
                @debug("using cached scene")
            else 
                entitiesJson = read(filePath, String)
                json = JSON3.read(entitiesJson)
                @debug("using scene from scene file")
            end

            entities = []
            uiElements = []
            res = []
            childParentDict = Dict()
    
            for entity in json.Entities
                components = []
    
                for component in entity.components
                    push!(components, deserialize_component(component))
                end
                
                if haskey(entity, "parent") && entity.parent != ""
                    childParentDict[string(entity.id)] = entity.parent
                end
                newEntity = Entity(get(entity, "name", "New entity"), string(entity.id))
                newEntity.isActive = get(entity, "isActive", true)
                newEntity.scripts = get(entity, "scripts", [])
                newEntity.persistentBetweenScenes = get(entity, "persistentBetweenScenes", false)

                for component in components
                    if typeof(component) == Animator
                        JulGame.add_animator(newEntity, component::Animator)
                        continue
                    elseif typeof(component) == Collider
                        JulGame.add_collider(newEntity, component::Collider)
                        continue
                    elseif typeof(component) == CircleCollider
                        JulGame.add_circle_collider(newEntity, component::CircleCollider)
                        continue
                    elseif typeof(component) == Rigidbody
                        JulGame.add_rigidbody(newEntity, component::Rigidbody)
                        continue
                    elseif typeof(component) == Shape
                        JulGame.add_shape(newEntity, component::Shape)
                        continue
                    elseif typeof(component) == SoundSource
                        JulGame.add_sound_source(newEntity, component::SoundSource)
                        continue
                    elseif typeof(component) == Sprite
                        JulGame.add_sprite(newEntity, false, component::Sprite)
                        continue
                    elseif typeof(component) == Transform 
                        newEntity.transform = component::Transform 
                        continue 
                    end
                end
                
                push!(entities, newEntity)
            end

            for entity in entities
                if haskey(childParentDict, string(entity.id))
                    parentId = childParentDict[string(entity.id)]
                    for e in entities
                        if string(e.id) == string(parentId)
                            entity.parent = e
                        end
                    end
                end
            end
            uiElements = deserialize_ui_elements(json.UIElements, entities)
            camera = Camera(Vector2(500,500), Vector3f(),Vector2f(), C_NULL)
            if haskey(json, "Camera")
                camera = Camera(Vector2(json.Camera.size.x, json.Camera.size.y), Vector3f(json.Camera.position.x, json.Camera.position.y, 0.0), Vector2f(json.Camera.offset.x, json.Camera.offset.y), C_NULL)
                camera.backgroundColor = (json.Camera.backgroundColor.r, json.Camera.backgroundColor.g, json.Camera.backgroundColor.b, json.Camera.backgroundColor.a)
            end
             
            push!(res, entities)
            push!(res, uiElements)
            push!(res, camera)
            return res
        catch e 
            @error string(e)
			Base.show_backtrace(stdout, catch_backtrace())
            return nothing
        end
    end

    function deserialize_ui_elements(jsonUIElements, entities)
        res = []
        childParentDict = Dict()
        default_Vector2 = Vector2(0,0)
        for uiElement in jsonUIElements
            try
                newUIElement = nothing
                if haskey(uiElement, "parent") && uiElement.parent != ""
                    childParentDict[string(uiElement.id)] = uiElement.parent
                end
                if uiElement.type == "Canvas"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 100)
                    if haskey(uiElement, "color") && typeof(uiElement.color) <: Dict && haskey(uiElement.color, "r") && haskey(uiElement.color, "g") && haskey(uiElement.color, "b") && haskey(uiElement.color, "a")
                         color_tuple = (uiElement.color.r, uiElement.color.g, uiElement.color.b, uiElement.color.a)
                    end

                    newUIElement = Canvas(
                        id = string(get(uiElement, "id", JulGame.generate_uuid())),
                        name = get(uiElement, "name", "Canvas"), 
                        anchor = Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset = Vector2(get(uiElement, "anchorOffset", default_Vector2).x, get(uiElement, "anchorOffset", default_Vector2).y),
                        isWorldEntity = get(uiElement, "isWorldEntity", false),
                        layer = Int(get(uiElement, "layer", 0)),
                        position = Vector2(get(uiElement, "position", default_Vector2).x, get(uiElement, "position", default_Vector2).y),
                        size = Vector2(get(uiElement, "size", default_Vector2).x, get(uiElement, "size", default_Vector2).y),
                        isActive = get(uiElement, "isActive", true),
                        persistentBetweenScenes = get(uiElement, "persistentBetweenScenes", false),
                        color = color_tuple,
                        isVisible = get(uiElement, "isVisible", true),
                        clipChildren = get(uiElement, "clipChildren", false),
                        rotation = get(uiElement, "rotation", 0.0)
                    )
                    
                    # Deserialize children if they exist
                    if haskey(uiElement, "children") && length(uiElement.children) > 0
                        children = deserialize_canvas_children(uiElement.children, newUIElement)
                        for child in children
                            CanvasModule.add_child(newUIElement, child)
                        end
                    end
                elseif uiElement.type == "TextBox"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 255)
                    if haskey(uiElement, "color") && typeof(uiElement.color) <: Dict && haskey(uiElement.color, "r") && haskey(uiElement.color, "g") && haskey(uiElement.color, "b") && haskey(uiElement.color, "a")
                         color_tuple = (uiElement.color.r, uiElement.color.g, uiElement.color.b, uiElement.color.a)
                    end

                    newUIElement = TextBox(
                        get(uiElement, "text", " ");
                        id = string(get(uiElement, "id", JulGame.generate_uuid())),
                        name = get(uiElement, "name", "TextBox"), 
                        anchor = Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset = Vector2(get(uiElement, "anchorOffset", default_Vector2).x, get(uiElement, "anchorOffset", default_Vector2).y),
                        isWorldEntity = get(uiElement, "isWorldEntity", false),
                        layer = Int(get(uiElement, "layer", 0)),
                        position = Vector2(get(uiElement, "position", default_Vector2).x, get(uiElement, "position", default_Vector2).y), 
                        isActive = get(uiElement, "isActive", true),
                        persistentBetweenScenes = get(uiElement, "persistentBetweenScenes", false),
                        color = color_tuple,
                        fontPath = get(uiElement, "fontPath", "Default"), 
                        fontSize = Int(get(uiElement, "fontSize", 20)), # Use fontSize from JSON or default
                        maxLineWidth = Int(get(uiElement, "maxLineWidth", 0)),
                        wrapWords = get(uiElement, "wrapWords", true)
                    )
                elseif uiElement.type == "UIImage"
                    color = get(uiElement, "color", Dict("4" => 255, "1" => 255, "2" => 255, "3" => 255))
                    color_tuple = (get(color, "1", 255), get(color, "2", 255), get(color, "3", 255), get(color, "4", 255))
                  
                    newUIElement = UIImage(
                        get(uiElement, "path", "Default");
                        id=string(get(uiElement, "id", JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Image"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset=Math.Vector2(get(uiElement, "anchorOffset", default_Vector2).x, get(uiElement, "anchorOffset", default_Vector2).y),
                        layer=Int(get(uiElement, "layer", 0)),
                        position=Math.Vector2(get(uiElement, "position", default_Vector2).x, get(uiElement, "position", default_Vector2).y),
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false),
                        color=color_tuple,
                        size=Math.Vector2(get(uiElement, "size", default_Vector2).x, get(uiElement, "size", default_Vector2).y),
                        parent=nothing,
                        rotation=convert(Float64, get(uiElement, "rotation", 0.0)),
                        # clickEvents=get(uiElement, "clickEvents", Function[]),
                        # hoverEnterEvents=get(uiElement, "hoverEnterEvents", Function[]),
                        # hoverExitEvents=get(uiElement, "hoverExitEvents", Function[]),
                    )
                else
                    # For text offset, check if it should be centered (if not specified or all zeros)
                    textOffset = Vector2(uiElement.textOffset.x, uiElement.textOffset.y)
                    if !haskey(uiElement, "textOffset") || (textOffset.x == 0 && textOffset.y == 0)
                        # Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = Vector2(-1, -1)
                    end
                    
                    newUIElement = ScreenButton(
                        nothing; # clickEvent - Assuming none from scene file directly
                        id=string(get(uiElement, "id", JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Button"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset=Math.Vector2(get(uiElement, "anchorOffset", default_Vector2).x, get(uiElement, "anchorOffset", default_Vector2).y),
                        isWorldEntity=get(uiElement, "isWorldEntity", false),
                        layer=Int(get(uiElement, "layer", 0)),
                        position=Math.Vector2(get(uiElement, "position", default_Vector2).x, get(uiElement, "position", default_Vector2).y),
                        buttonUpSpritePath=get(uiElement, "buttonUpSpritePath", "Default"),
                        buttonDownSpritePath=get(uiElement, "buttonDownSpritePath", "Default"),
                        # hoverEnterEvent=nothing, # Default
                        # hoverExitEvent=nothing, # Default
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false), # Keep the value from JSON if it exists
                        #color=color_tuple,
                        fontPath=get(uiElement, "fontPath", C_NULL),
                        fontSize=Int(get(uiElement, "fontSize", 24)),
                        size=Math.Vector2(get(uiElement, "size", default_Vector2).x, get(uiElement, "size", default_Vector2).y),
                        text=get(uiElement, "text", ""),
                        textOffset=textOffset,
                        # parent=nothing # Default
                    )
                    
                    # Make sure the button is initialized properly - Constructor likely handles this
                end
                newUIElement.persistentBetweenScenes = get(uiElement, "persistentBetweenScenes", false)
                push!(res, newUIElement)
            catch e 
                @error string(e)
				Base.show_backtrace(stdout, catch_backtrace())
            end
        end

        for uiElement in res
            if haskey(childParentDict, string(uiElement.id)) && childParentDict[string(uiElement.id)] != "" && childParentDict[string(uiElement.id)] !== nothing
                parentId, parentType = split(childParentDict[string(uiElement.id)], "::")
                if parentType == "Entity"
                    for e in entities
                        if string(e.id) == string(parentId)
                            uiElement.parent = e
                        end
                    end
                else
                    for e in res
                        if string(e.id) == string(parentId)
                            uiElement.parent = e
                        end
                    end
                end
            end
        end

        return res
    end

    export deserialize_component
    function deserialize_component(component)
        try
            if component.type == "Transform"
                newComponent = Transform(Vector2f(component.position.x, component.position.y), Vector2f(component.scale.x, component.scale.y))
            elseif component.type == "Animator"
                newAnimations = Animation[]
                for animation in component.animations
                newAnimationFrames = Vector{Vector4}()
                for animationFrame in animation.frames
                    push!(newAnimationFrames, Vector4(animationFrame.x, animationFrame.y, animationFrame.z, animationFrame.t))
                    end
                    push!(newAnimations, Animation(newAnimationFrames, animation.animatedFPS))
                end
                newComponent = Animator(newAnimations)
            elseif component.type == "Collider"
                isTrigger::Bool = !haskey(component, "isTrigger") ? false : component.isTrigger
                enabled::Bool = !haskey(component, "enabled") ? true : component.enabled
                isPlatformerCollider::Bool = !haskey(component, "isPlatformerCollider") ? false : component.isPlatformerCollider
                offset::Vector2f = !haskey(component, "offset") ? Vector2f(0,0) : Vector2f(component.offset.x, component.offset.y)
                newComponent = Collider(enabled::Bool, isPlatformerCollider, isTrigger, offset,  Vector2f(component.size.x, component.size.y), component.tag::String)
            elseif component.type == "CircleCollider"
                newComponent = CircleCollider(convert(Float64, component.diameter), component.enabled, component.isTrigger, Vector2f(component.offset.x, component.offset.y), component.tag)
            elseif component.type == "Rigidbody"
                newComponent = Rigidbody(; mass = convert(Float64, component.mass), useGravity = !haskey(component, "useGravity") ? true : component.useGravity)
            elseif component.type == "SoundSource"
                newComponent = SoundSource(component.channel, component.isMusic, component.path, get(component, "playOnStart", false), component.volume)
            elseif component.type == "Sprite"
                color = !haskey(component, "color") || isempty(component.color) ? (255,255,255,255) : (get(component.color, "x", 255), get(component.color, "y", 255), get(component.color, "z", 255), get(component.color, "t", 255))
                crop = !haskey(component, "crop") || isempty(component.crop) ? Vector4(0,0,0,0) : Vector4(component.crop.x, component.crop.y, component.crop.z, component.crop.t)
                layer = !haskey(component, "layer") ? 0 : component.layer
                offset = !haskey(component, "offset") ? Vector2f() : Vector2f(component.offset.x, component.offset.y)
                position = !haskey(component, "position") ? Vector2f() : Vector2f(component.position.x, component.position.y)
                rotation = !haskey(component, "rotation") ? 0.0 : convert(Float64, component.rotation)
                pixelsPerUnit = !haskey(component, "pixelsPerUnit") ? -1 : component.pixelsPerUnit
                center = !haskey(component, "center") ? Vector2f(0.5,0.5) : Vector2f(component.center.x, component.center.y)
                anchor = !haskey(component, "anchor") ? :center : Symbol(component.anchor)
                
                newComponent = Sprite(color::NTuple{4, Int}, crop::Union{Ptr{Nothing}, Math.Vector4}, component.isFlipped::Bool, component.imagePath::String, layer::Int, offset::Vector2f, position::Vector2f, rotation::Float64, pixelsPerUnit::Int, center::Vector2f, anchor::Symbol)
            elseif component.type == "Shape"
                color = !haskey(component, "color") || isempty(component.color) ? Vector3(255,255,255) : Vector3(component.color.x, component.color.y, component.color.z)
                layer = !haskey(component, "layer") ? 0 : component.layer
                size = !haskey(component, "size") || isempty(component.size) ? Vector2f(1,1) : Vector2f(component.size.x, component.size.y)
                isFilled = !haskey(component, "isFilled") ? true : component.isFilled
                isWorldEntity = !haskey(component, "isWorldEntity") ? true : component.isWorldEntity
                offset = !haskey(component, "offset") ? Vector2f() : Vector2f(component.offset.x, component.offset.y)
                position = !haskey(component, "position") ? Vector2f() : Vector2f(component.position.x, component.position.y)
                alpha = !haskey(component, "alpha") ? 255 : component.alpha
                newComponent = Shape(color::Vector3, isFilled::Bool, isWorldEntity::Bool, layer::Int, offset::Vector2f, position::Vector2f, size::Vector2f, alpha::Int)
            elseif component.type == "Mesh3D"
                vCamera = vec3d(component.vCamera.x, component.vCamera.y, component.vCamera.z, component.vCamera.w)
                vLookDir = vec3d(component.vLookDir.x, component.vLookDir.y, component.vLookDir.z, component.vLookDir.w)
                newComponent = Mesh3D()
                newComponent.fNear = get(component, "fNear", 0.1)
                newComponent.fFar = get(component, "fFar", 1000.0)
                newComponent.fFov = get(component, "fFov", 90.0)
                newComponent.fYaw = get(component, "fYaw", 0.0)
                newComponent.fTheta = get(component, "fTheta", 0.0)
                newComponent.fAspectRatio = get(component, "fAspectRatio", 0.0)
                newComponent.vCamera = vCamera
                newComponent.vLookDir = vLookDir
            end
            
            return newComponent
        catch e
            @error string(e)
			Base.show_backtrace(stdout, catch_backtrace())
        end
    end

    """
    deserialize_canvas_children(jsonChildren, parentCanvas)
    
    Recursively deserializes Canvas children.
    """
    function deserialize_canvas_children(jsonChildren, parentCanvas)
        children = UI.UIElement[]
        default_Vector2 = Vector2(0,0)
        
        for child in jsonChildren
            try
                newChild = nothing
                if child.type == "Canvas"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 100)
                    if haskey(child, "color") && typeof(child.color) <: Dict && haskey(child.color, "r") && haskey(child.color, "g") && haskey(child.color, "b") && haskey(child.color, "a")
                         color_tuple = (child.color.r, child.color.g, child.color.b, child.color.a)
                    end

                    newChild = Canvas(
                        id = string(get(child, "id", JulGame.generate_uuid())),
                        name = get(child, "name", "Canvas"), 
                        anchor = Symbol(get(child, "anchor", "none")),
                        anchorOffset = Vector2(get(child, "anchorOffset", default_Vector2).x, get(child, "anchorOffset", default_Vector2).y),
                        isWorldEntity = get(child, "isWorldEntity", false),
                        layer = Int(get(child, "layer", 0)),
                        position = Vector2(get(child, "position", default_Vector2).x, get(child, "position", default_Vector2).y),
                        size = Vector2(get(child, "size", default_Vector2).x, get(child, "size", default_Vector2).y),
                        isActive = get(child, "isActive", true),
                        persistentBetweenScenes = get(child, "persistentBetweenScenes", false),
                        color = color_tuple,
                        isVisible = get(child, "isVisible", true),
                        clipChildren = get(child, "clipChildren", false),
                        rotation = get(child, "rotation", 0.0),
                        parent = parentCanvas
                    )
                    
                    # Recursively deserialize children if they exist
                    if haskey(child, "children") && length(child.children) > 0
                        grandChildren = deserialize_canvas_children(child.children, newChild)
                        for grandChild in grandChildren
                            CanvasModule.add_child(newChild, grandChild)
                        end
                    end
                elseif child.type == "ScreenButton"
                    # For text offset, check if it should be centered (if not specified or all zeros)
                    textOffset = Vector2(child.textOffset.x, child.textOffset.y)
                    if !haskey(child, "textOffset") || (textOffset.x == 0 && textOffset.y == 0)
                        # Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = Vector2(-1, -1)
                    end
                    
                    newChild = ScreenButton(
                        nothing; # clickEvent - Assuming none from scene file directly
                        id=string(get(child, "id", JulGame.generate_uuid())),
                        name=get(child, "name", "Button"),
                        anchor=Symbol(get(child, "anchor", "none")),
                        anchorOffset=Math.Vector2(get(child, "anchorOffset", default_Vector2).x, get(child, "anchorOffset", default_Vector2).y),
                        isWorldEntity=get(child, "isWorldEntity", false),
                        layer=Int(get(child, "layer", 0)),
                        position=Math.Vector2(get(child, "position", default_Vector2).x, get(child, "position", default_Vector2).y),
                        buttonUpSpritePath=get(child, "buttonUpSpritePath", "Default"),
                        buttonDownSpritePath=get(child, "buttonDownSpritePath", "Default"),
                        isActive=get(child, "isActive", true),
                        persistentBetweenScenes=get(child, "persistentBetweenScenes", false),
                        fontPath=get(child, "fontPath", C_NULL),
                        fontSize=Int(get(child, "fontSize", 24)),
                        size=Math.Vector2(get(child, "size", default_Vector2).x, get(child, "size", default_Vector2).y),
                        text=get(child, "text", ""),
                        textOffset=textOffset,
                        parent = parentCanvas
                    )
                else
                    # TextBox
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 255)
                    if haskey(child, "color") && typeof(child.color) <: Dict && haskey(child.color, "r") && haskey(child.color, "g") && haskey(child.color, "b") && haskey(child.color, "a")
                         color_tuple = (child.color.r, child.color.g, child.color.b, child.color.a)
                    end

                    newChild = TextBox(
                        get(child, "text", " ");
                        id = string(get(child, "id", JulGame.generate_uuid())),
                        name = get(child, "name", "TextBox"), 
                        anchor = Symbol(get(child, "anchor", "none")),
                        anchorOffset = Vector2(get(child, "anchorOffset", default_Vector2).x, get(child, "anchorOffset", default_Vector2).y),
                        isWorldEntity = get(child, "isWorldEntity", false),
                        layer = Int(get(child, "layer", 0)),
                        position = Vector2(get(child, "position", default_Vector2).x, get(child, "position", default_Vector2).y), 
                        isActive = get(child, "isActive", true),
                        persistentBetweenScenes = get(child, "persistentBetweenScenes", false),
                        color = color_tuple,
                        fontPath = get(child, "fontPath", "Default"), 
                        fontSize = Int(get(child, "fontSize", 20)),
                        maxLineWidth = Int(get(child, "maxLineWidth", 0)),
                        wrapWords = get(child, "wrapWords", true),
                        parent = parentCanvas
                    )
                end
                
                if newChild !== nothing
                    push!(children, newChild)
                end
            catch e 
                @error string(e)
                Base.show_backtrace(stdout, catch_backtrace())
            end
        end
        
        return children
    end
end
