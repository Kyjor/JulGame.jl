module SceneReaderModule
    using ...AnimatorModule
    using ...AnimationModule
    using ...CameraModule
    using ...ColliderModule
    using ...EntityModule
    using ...Math
    using ...RigidbodyModule
    using ...ShapeModule
    using ...SoundSourceModule
    using ...SpriteModule
    using ...UI.TextBoxModule
    using ...UI.ScreenButtonModule
    using ...UI.UIImageModule
    using ...UI.CanvasModule
    using ...TransformModule
    using ...JulGame
    using ...JulGame.SceneJSON

    export SceneData
    "Everything a scene file describes."
    struct SceneData
        entities::Vector{Entity}
        uiElements::Vector{JulGame.IUIElement}
        camera::Camera
    end

    const PRELOADED_SCENES = Dict{String, SceneData}()

    export preload_scene
    """
        preload_scene(filePath::String)

    Preloads a scene from the specified file path and stores it in the PRELOADED_SCENES cache.
    This allows for faster scene switching as the scene is already loaded in memory.

    # Arguments
    - `filePath::String`: The path to the scene file to preload
    """
    function preload_scene(filePath::String)
        sceneName = basename(filePath)
        haskey(PRELOADED_SCENES, sceneName) && return

        scene = deserialize_scene(filePath)
        if scene !== nothing
            PRELOADED_SCENES[sceneName] = scene
            @debug("Preloaded scene: $sceneName")
        end
    end

    # JSON helpers

    json_id(value::JSONValue)::String = begin
        id = json_get(value, "id")
        id.kind == SceneJSON.JString ? id.string : id.kind == SceneJSON.JNumber ? string(round(Int, id.number)) : JulGame.generate_uuid()
    end

    has_content(value::JSONValue) = !isnull(value) && !isempty(value)

    read_vector2(value::JSONValue, default::Vector2 = Vector2(0, 0))::Vector2 =
        isnull(value) ? default : Vector2(json_float(value, "x", 0.0), json_float(value, "y", 0.0))

    read_vector2f(value::JSONValue, default::Vector2f = Vector2f(0, 0))::Vector2f =
        isnull(value) ? default : Vector2f(json_float(value, "x", 0.0), json_float(value, "y", 0.0))

    read_vector3f(value::JSONValue, defaultZ::Float64)::Vector3f =
        Vector3f(json_float(value, "x", 0.0), json_float(value, "y", 0.0), json_float(value, "z", defaultZ))

    read_vector4(value::JSONValue)::Vector4 =
        Vector4(json_float(value, "x", 0.0), json_float(value, "y", 0.0), json_float(value, "z", 0.0), json_float(value, "t", 0.0))

    function read_color(value::JSONValue, channels::NTuple{4, String}, default::NTuple{4, Int})::NTuple{4, Int}
        return (
            json_int(value, channels[1], default[1]),
            json_int(value, channels[2], default[2]),
            json_int(value, channels[3], default[3]),
            json_int(value, channels[4], default[4]),
        )
    end

    const RGBA_CHANNELS = ("r", "g", "b", "a")
    const NUMBERED_CHANNELS = ("1", "2", "3", "4")

    # Scenes

    export deserialize_scene
    function deserialize_scene(filePath::String)::Union{SceneData, Nothing}
        try
            sceneName = basename(filePath)
            if haskey(PRELOADED_SCENES, sceneName)
                @debug "deserialize_scene: Using preloaded scene: $sceneName"
                return PRELOADED_SCENES[sceneName]
            end

            json = JSON_NULL
            if haskey(JulGame.SCENE_CACHE, sceneName)
                json = JulGame.SCENE_CACHE[sceneName]
                @debug("using cached scene")
            else
                json = parse_json(read(filePath, String))
                @debug("using scene from scene file")
            end

            entityIdsInCurrentScene = Set{String}(e.id for e in JulGame.main_loop().scene.entities)
            entities = Entity[]
            childParentDict = Dict{String, String}()

            for entityJson in json_get(json, "Entities")
                id = json_id(entityJson)
                if id in entityIdsInCurrentScene
                    @debug "Entity with id $id already exists in current scene"
                    continue
                end

                parentId = json_string(entityJson, "parent", "")
                if parentId != ""
                    childParentDict[id] = parentId
                end

                entity = Entity(json_string(entityJson, "name", "New entity"), id)
                entity.isActive = json_bool(entityJson, "isActive", true)
                entity.persistentBetweenScenes = json_bool(entityJson, "persistentBetweenScenes", false)
                for script in json_get(entityJson, "scripts")
                    push!(entity.pendingScripts, ScriptSpec(json_string(script, "name", ""), json_get(script, "fields")))
                end

                for component in json_get(entityJson, "components")
                    add_component!(entity, component)
                end
                push!(entities, entity)
            end

            for entity in entities
                parentId = get(childParentDict, entity.id, "")
                parentId == "" && continue
                for candidate in entities
                    if candidate.id == parentId
                        entity.parent = candidate
                    end
                end
            end

            uiElements = deserialize_ui_elements(json_get(json, "UIElements"), entities)
            return SceneData(entities, uiElements, deserialize_camera(json_get(json, "Camera")))
        catch e
            JulGame.log_exception("Failed to deserialize scene $filePath", e)
            return nothing
        end
    end

    function deserialize_camera(json::JSONValue)::Camera
        isnull(json) && return Camera(Vector2(500, 500), Vector3f(), Vector2f(), C_NULL)

        position = json_get(json, "position")
        camera = Camera(
            read_vector2(json_get(json, "size")),
            Vector3f(json_float(position, "x", 0.0), json_float(position, "y", 0.0), 0.0),
            read_vector2f(json_get(json, "offset")),
            C_NULL,
        )
        camera.backgroundColor = read_color(json_get(json, "backgroundColor"), RGBA_CHANNELS, (0, 0, 0, 255))
        camera.zoom = json_float(json, "zoom", camera.zoom)
        return camera
    end

    # Components

    """
        add_component!(entity::Entity, component::JSONValue)

    Builds the component described by `component` and attaches it to `entity`.
    """
    function add_component!(entity::Entity, component::JSONValue)
        type = json_string(component, "type", "")
        @debug "Adding $type to entity: $(entity.name)"
        try
            if type == "Transform"
                entity.transform = Transform(read_vector3f(json_get(component, "position"), 0.0), read_vector3f(json_get(component, "scale"), 1.0))
                entity.transform.parent = entity
            elseif type == "Animator"
                JulGame.add_animator(entity, read_animator(component))
            elseif type == "Collider"
                JulGame.add_collider(entity, read_collider(component))
            elseif type == "Rigidbody"
                JulGame.add_rigidbody(entity, Rigidbody(json_float(component, "mass", 1.0), json_bool(component, "useGravity", true)))
            elseif type == "SoundSource"
                JulGame.add_sound_source(entity, read_sound_source(component))
            elseif type == "Sprite"
                JulGame.add_sprite(entity, false, read_sprite(component))
            elseif type == "Shape"
                JulGame.add_shape(entity, read_shape(component))
            end
        catch e
            JulGame.log_exception("Failed to add $type to entity: $(entity.name)", e)
        end
    end

    function read_animator(component::JSONValue)::Animator
        animations = Animation[]
        for animation in json_get(component, "animations")
            frames = Vector4[read_vector4(frame) for frame in json_get(animation, "frames")]
            framePaths = String[json_string(path, "") for path in json_get(animation, "framePaths")]
            push!(animations, Animation(frames, json_int(animation, "animatedFPS", 60), framePaths))
        end
        return Animator(animations)
    end

    function read_collider(component::JSONValue)::Collider
        return Collider(
            json_bool(component, "enabled", true),
            json_bool(component, "isPlatformerCollider", false),
            json_bool(component, "isTrigger", false),
            read_vector2f(json_get(component, "offset")),
            read_vector2f(json_get(component, "size")),
            json_string(component, "tag", "Default"),
        )
    end

    function read_sound_source(component::JSONValue)::SoundSource
        return SoundSource(
            json_int(component, "channel", -1),
            json_bool(component, "isMusic", false),
            json_string(component, "path", ""),
            json_bool(component, "playOnStart", false),
            json_int(component, "volume", -1),
        )
    end

    function read_sprite(component::JSONValue)::Sprite
        color = json_get(component, "color")
        crop = json_get(component, "crop")
        return Sprite(
            has_content(color) ? read_color(color, ("x", "y", "z", "t"), (255, 255, 255, 255)) : (255, 255, 255, 255),
            has_content(crop) ? read_vector4(crop) : Vector4(0, 0, 0, 0),
            json_bool(component, "isFlipped", false),
            json_string(component, "imagePath", ""),
            json_int(component, "layer", 0),
            read_vector2f(json_get(component, "offset"), Vector2f()),
            read_vector2f(json_get(component, "position"), Vector2f()),
            json_float(component, "rotation", 0.0),
            json_int(component, "pixelsPerUnit", -1),
            read_vector2f(json_get(component, "center"), Vector2f(0.5, 0.5)),
            Symbol(json_string(component, "anchor", "center")),
        )
    end

    function read_shape(component::JSONValue)::Shape
        color = json_get(component, "color")
        size = json_get(component, "size")
        return Shape(
            has_content(color) ? Vector3(json_float(color, "x", 0.0), json_float(color, "y", 0.0), json_float(color, "z", 0.0)) : Vector3(255, 255, 255),
            json_bool(component, "isFilled", true),
            json_bool(component, "isWorldEntity", true),
            json_int(component, "layer", 0),
            read_vector2f(json_get(component, "offset"), Vector2f()),
            read_vector2f(json_get(component, "position"), Vector2f()),
            has_content(size) ? read_vector2f(size) : Vector2f(1, 1),
            json_int(component, "alpha", 255),
        )
    end

    # UI elements

    function set_parent!(uiElement, parent)
        uiElement.parent = parent
        return nothing
    end

    # Both are only known as `IUIElement`: dispatch on the parent first so `set_parent!` gets a concrete argument.
    struct ParentAssigner
        uiElement::JulGame.IUIElement
    end

    (assigner::ParentAssigner)(parent) = JulGame.dispatch(set_parent!, assigner.uiElement, parent)

    @inline set_ui_parent!(uiElement::JulGame.IUIElement, parent::JulGame.IUIElement) = JulGame.dispatch(ParentAssigner(uiElement), parent)

    function deserialize_ui_elements(jsonUIElements::JSONValue, entities::Vector{Entity})::Vector{JulGame.IUIElement}
        res = JulGame.IUIElement[]
        childParentDict = Dict{String, String}()
        for uiElement in jsonUIElements
            try
                newUIElement = build_ui_element(uiElement, nothing, "ScreenButton")
                parent = json_string(uiElement, "parent", "")
                if parent != ""
                    childParentDict[newUIElement.id] = parent
                end
                push!(res, newUIElement)
            catch e
                JulGame.log_exception("Failed to deserialize UI element $(json_string(uiElement, "name", ""))", e)
            end
        end

        for uiElement in res
            parentRef = get(childParentDict, uiElement.id, "")
            parentRef == "" && continue
            parts = split(parentRef, "::")
            length(parts) == 2 || continue
            parentId, parentType = parts
            if parentType == "Entity"
                for e in entities
                    if e.id == parentId
                        JulGame.dispatch(set_parent!, uiElement, e)
                    end
                end
            else
                for e in res
                    if e.id == parentId
                        set_ui_parent!(uiElement, e)
                    end
                end
            end
        end

        return res
    end

    """
        build_ui_element(json, parent, fallbackType)

    Builds the UI element described by `json`. Elements with an unrecognized `type` become `fallbackType`.
    """
    function build_ui_element(json::JSONValue, parent::Union{JulGame.IUIElement, Nothing}, fallbackType::String)::JulGame.IUIElement
        type = json_string(json, "type", fallbackType)
        if type != "Canvas" && type != "TextBox" && type != "UIImage" && type != "Rectangle" && type != "ScreenButton"
            type = fallbackType
        end

        id = json_id(json)
        anchor = Symbol(json_string(json, "anchor", "none"))
        anchorOffset = read_vector2(json_get(json, "anchorOffset"))
        position = read_vector2(json_get(json, "position"))
        size = read_vector2(json_get(json, "size"))
        layer = json_int(json, "layer", 0)
        isActive = json_bool(json, "isActive", true)
        isWorldEntity = json_bool(json, "isWorldEntity", false)
        persistentBetweenScenes = json_bool(json, "persistentBetweenScenes", false)
        rotation = json_float(json, "rotation", 0.0)
        name = json_string(json, "name", type)

        newUIElement::JulGame.IUIElement = if type == "Canvas"
            canvas = Canvas(
                id = id,
                name = name,
                anchor = anchor,
                anchorOffset = anchorOffset,
                isWorldEntity = isWorldEntity,
                layer = layer,
                position = position,
                size = size,
                isActive = isActive,
                persistentBetweenScenes = persistentBetweenScenes,
                color = read_color(json_get(json, "color"), RGBA_CHANNELS, (255, 255, 255, 100)),
                isVisible = json_bool(json, "isVisible", true),
                clipChildren = json_bool(json, "clipChildren", false),
                rotation = rotation,
                parent = parent,
            )
            for child in json_get(json, "children")
                add_child(canvas, build_ui_element(child, canvas, "TextBox"))
            end
            canvas
        elseif type == "UIImage"
            UIImage(
                json_string(json, "path", "Default");
                id = id,
                name = name,
                anchor = anchor,
                anchorOffset = anchorOffset,
                layer = layer,
                position = position,
                isActive = isActive,
                persistentBetweenScenes = persistentBetweenScenes,
                color = read_color(json_get(json, "color"), NUMBERED_CHANNELS, (255, 255, 255, 255)),
                size = size,
                parent = parent,
                rotation = rotation,
            )
        elseif type == "Rectangle"
            JulGame.UI.RectangleModule.Rectangle(;
                id = id,
                name = name,
                anchor = anchor,
                anchorOffset = anchorOffset,
                isWorldEntity = isWorldEntity,
                layer = layer,
                position = position,
                isActive = isActive,
                persistentBetweenScenes = persistentBetweenScenes,
                color = read_color(json_get(json, "color"), NUMBERED_CHANNELS, (255, 255, 255, 255)),
                fillMode = json_bool(json, "fillMode", true),
                borderRadius = json_int(json, "borderRadius", 0),
                borderWidth = json_int(json, "borderWidth", 0),
                borderColor = read_color(json_get(json, "borderColor"), NUMBERED_CHANNELS, (255, 255, 255, 255)),
                size = size,
                parent = parent,
                forceClickCheck = json_bool(json, "forceClickCheck", false),
            )
        elseif type == "ScreenButton"
            # A missing or all-zero text offset means the text is centered, which the button encodes as (-1, -1)
            textOffset = read_vector2(json_get(json, "textOffset"))
            if textOffset.x == 0 && textOffset.y == 0
                textOffset = Vector2(-1, -1)
            end
            fontPath = json_get(json, "fontPath")
            ScreenButton(
                nothing; # clickEvent - Assuming none from scene file directly
                id = id,
                name = name,
                anchor = anchor,
                anchorOffset = anchorOffset,
                isWorldEntity = isWorldEntity,
                layer = layer,
                position = position,
                buttonUpSpritePath = json_string(json, "buttonUpSpritePath", "Default"),
                buttonDownSpritePath = json_string(json, "buttonDownSpritePath", "Default"),
                isActive = isActive,
                persistentBetweenScenes = persistentBetweenScenes,
                fontPath = fontPath.kind == SceneJSON.JString ? fontPath.string : C_NULL,
                fontSize = json_int(json, "fontSize", 24),
                size = size,
                text = json_string(json, "text", ""),
                textOffset = textOffset,
                parent = parent,
            )
        else
            TextBox(
                json_string(json, "text", " ");
                id = id,
                name = name,
                anchor = anchor,
                anchorOffset = anchorOffset,
                isWorldEntity = isWorldEntity,
                layer = layer,
                position = position,
                isActive = isActive,
                persistentBetweenScenes = persistentBetweenScenes,
                color = read_color(json_get(json, "color"), RGBA_CHANNELS, (255, 255, 255, 255)),
                fontPath = json_string(json, "fontPath", "Default"),
                fontSize = json_int(json, "fontSize", 20),
                maxLineWidth = json_int(json, "maxLineWidth", 0),
                wrapWords = json_bool(json, "wrapWords", true),
                parent = parent,
            )
        end

        newUIElement.persistentBetweenScenes = persistentBetweenScenes
        return newUIElement
    end
end
