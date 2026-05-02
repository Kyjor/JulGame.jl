module SceneReaderModule
    using JSON
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
    using ...UI.CanvasModule
    using ...TransformModule
    using ...JulGame

    const SceneJSONObject = JSON.Object{String,Any}

    # Dict-shaped scene JSON wrapped for JSON3-like property/get/haskey access.
    struct JsonObj
        d::Union{Dict{String,Any}, SceneJSONObject, JSON3.Object}
    end

    function _expose(v)
        v isa Dict{String,Any} && return JsonObj(v)
        v isa SceneJSONObject && return JsonObj(v)
        v isa JSON3.Object && return JsonObj(v)
        v isa AbstractDict && return JsonObj(Dict{String,Any}(string(k) => x for (k, x) in pairs(v)))
        if v isa AbstractVector && !(v isa AbstractString)
            return [_expose(x) for x in v]
        end
        return v
    end

    function _json_value(d::Union{Dict{String,Any}, SceneJSONObject}, k::AbstractString, default = nothing)
        return get(d, string(k), default)
    end

    function _json_value(d::JSON3.Object, k::AbstractString, default = nothing)
        return get(d, Symbol(k), default)
    end

    # JuliaC `--trim`: a single Union-typed entry helps the verifier resolve `_json_value(::Union{...}, ::String, ::Nothing)` calls
    # made from `getproperty(::JsonObj)` / `haskey(::JsonObj)` against a concrete dispatch target.
    function _json_value(d::Union{Dict{String,Any}, SceneJSONObject, JSON3.Object}, k::String, default::Nothing)
        if d isa JSON3.Object
            return get(d, Symbol(k), default)
        else
            return get(d, k, default)
        end
    end

    @inline _scene_storage(o::JsonObj) = getfield(o, :d)::Union{Dict{String,Any}, SceneJSONObject, JSON3.Object}

    function _scene_obj(v)::JsonObj
        v isa JsonObj && return v
        v isa Dict{String,Any} && return JsonObj(v)
        v isa SceneJSONObject && return JsonObj(v)
        v isa JSON3.Object && return JsonObj(v)
        return JsonObj(Dict{String,Any}())
    end

    """Coerce a JSON scalar to `Float64` via concrete `isa` branches so the trim verifier can resolve every conversion."""
    function _to_f64(v, default::Float64)::Float64
        v === nothing && return default
        v isa Float64 && return v
        v isa Float32 && return Float64(v)
        v isa Int && return Float64(v)
        v isa Int32 && return Float64(v)
        v isa Int16 && return Float64(v)
        v isa Int8 && return Float64(v)
        v isa UInt && return Float64(v)
        v isa UInt32 && return Float64(v)
        v isa UInt16 && return Float64(v)
        v isa UInt8 && return Float64(v)
        v isa Bool && return v ? 1.0 : 0.0
        return default
    end

    """Coerce a JSON scalar to `Int` via concrete `isa` branches (mirrors `_to_f64`)."""
    function _to_int(v, default::Int)::Int
        v === nothing && return default
        v isa Int && return v
        v isa Int32 && return Int(v)
        v isa Int16 && return Int(v)
        v isa Int8 && return Int(v)
        v isa UInt && return Int(v)
        v isa UInt32 && return Int(v)
        v isa UInt16 && return Int(v)
        v isa UInt8 && return Int(v)
        v isa Bool && return v ? 1 : 0
        v isa Float64 && return Int(round(v))
        v isa Float32 && return Int(round(Float64(v)))
        return default
    end

    """Read `parent.sub_key.leaf_key` as `Float64` without going through `getproperty(::JsonObj)::Any` chains."""
    function _scene_f64(parent::JsonObj, sub_key::String, leaf_key::String, default::Float64)::Float64
        sub = _json_value(_scene_storage(parent), sub_key, nothing)
        sub === nothing && return default
        inner = _scene_obj(sub)
        return _to_f64(_json_value(_scene_storage(inner), leaf_key, nothing), default)
    end

    """Read `parent.sub_key.leaf_key` as `Int` without going through `getproperty(::JsonObj)::Any` chains."""
    function _scene_int(parent::JsonObj, sub_key::String, leaf_key::String, default::Int)::Int
        sub = _json_value(_scene_storage(parent), sub_key, nothing)
        sub === nothing && return default
        inner = _scene_obj(sub)
        return _to_int(_json_value(_scene_storage(inner), leaf_key, nothing), default)
    end

    function Base.getproperty(o::JsonObj, k::Symbol)
        k === :d && return getfield(o, :d)
        return _expose(_json_value(getfield(o, :d), String(k), nothing))
    end

    Base.haskey(o::JsonObj, k::AbstractString) = _json_value(getfield(o, :d), k, nothing) !== nothing

    function Base.get(o::JsonObj, k::AbstractString, default)
        ks = string(k)
        value = _json_value(getfield(o, :d), ks, default)
        value === default ? default : _expose(value)
    end

    Base.isempty(o::JsonObj) = isempty(getfield(o, :d))

    _isempty_json_field(x::Nothing) = true
    _isempty_json_field(x::JsonObj) = isempty(x)
    _isempty_json_field(x::AbstractVector) = isempty(x)
    _isempty_json_field(_) = false

    # JuliaC `--trim`: avoid JSON.parse (-> jsonreadstyle -> repr -> Base.show) and avoid `pairs(parsed)` on
    # `Any`-typed SSA from `_parse`. Assert `JSON.Object{String,Any}` (== `DEFAULT_OBJECT_TYPE`, the path
    # `_parse(_, Any, DEFAULT_OBJECT_TYPE, _, _)` actually produces) so the `JsonObj(...)` ctor matches its
    # field union directly instead of going through `AbstractDict{String,Any}` (was verifier #384).
    function _scene_root_jsonobj_from_file(entitiesJson::String)::JsonObj
        lv = JSON.lazy(entitiesJson)
        root::SceneJSONObject = JSON._parse(
            lv,
            Any,
            JSON.DEFAULT_OBJECT_TYPE,
            nothing,
            StructUtils.DefaultStyle(),
        )::SceneJSONObject
        JsonObj(root)
    end

    """Normalize SCENE_CACHE entries (Dict, JSON3.Object, JsonObj) into `JsonObj` for stable typing under `--trim`."""
    function _as_scene_json_root(x)::JsonObj
        x isa JsonObj && return x
        x isa JSON3.Object && return JsonObj(x)
        x isa AbstractDict && !(x isa JsonObj) && return JsonObj(Dict{String,Any}(string(k) => v for (k, v) in pairs(x)))
        return JsonObj(Dict{String,Any}("_" => x))
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
            if Base.haskey(JulGame.PRELOADED_SCENES, basename(filePath))
                @debug("Scene already preloaded: $(basename(filePath))")
                return
            end

            scene = deserialize_scene(filePath)
            JulGame.PRELOADED_SCENES[basename(filePath)] = (entities = scene[1], uiElements = scene[2], camera = scene[3])
            @debug("Preloaded scene: $(basename(filePath))")
        catch e
            @error sprint(showerror, e)
        end
    end

    export deserialize_scene
    function deserialize_scene(filePath::String)::Union{Nothing, Tuple{Vector{Entity}, Vector{JulGame.UI.UIElement}, Camera}}
        try
            if Base.haskey(JulGame.PRELOADED_SCENES, basename(filePath))
                @debug "deserialize_scene: Using preloaded scene: $(basename(filePath))"
                cached = JulGame.PRELOADED_SCENES[basename(filePath)]
                return (cached.entities, cached.uiElements, cached.camera)
            end

            json = nothing
            if Base.haskey(JulGame.SCENE_CACHE, basename(filePath))
                json = JulGame.SCENE_CACHE[basename(filePath)]
                @debug("using cached scene")
            else 
                entitiesJson = read(filePath, String)
                json = _scene_root_jsonobj_from_file(entitiesJson)
                @debug("using scene from scene file")
            end

            root::JsonObj = _as_scene_json_root(json)

            entities = Entity[]
            childParentDict = Dict{String, String}()
    
            entityIdsInCurrentScene = []
            try
                entityIdsInCurrentScene = [e.id for e in MAIN.scene.entities]
            catch e
                @error sprint(showerror, e)
            end
            for entity in root.Entities
                if entity.id in entityIdsInCurrentScene
                    @debug "Entity with id $(entity.id) already exists in current scene"
                    continue
                end
                components = Any[]
    
                for component in entity.components
                    @debug "Deserializing component: $(component.type)"
                    push!(components, deserialize_component(component))
                end
                
                if haskey(entity, "parent") && entity.parent != ""
                    childParentDict[string(entity.id)] = string(entity.parent)
                end
                newEntity = Entity(get(entity, "name", "New entity"), string(entity.id))
                newEntity.isActive = get(entity, "isActive", true)
                # Keep raw JSON3.Object/Dict entries here; SceneBuilder reifies them via `isa(script, JSON3.Object)`.
                raw_scripts = _json_value(getfield(entity, :d), "scripts", Any[])
                newEntity.scripts = raw_scripts isa AbstractVector ? collect(raw_scripts) : Any[]
                newEntity.persistentBetweenScenes = get(entity, "persistentBetweenScenes", false)

                for component in components
                    if typeof(component) == Animator
                        @debug "Adding animator to entity: $(newEntity.name), path: $(component.path)"
                        try
                            JulGame.add_animator(newEntity, component::Animator)
                        catch e
                            @error "Failed to add animator to entity: $(newEntity.name), path: $(component.path), error: $(e)"
                        end
                        continue
                    elseif typeof(component) == Collider
                        @debug "Adding collider to entity: $(newEntity.name), path: $(component.path)"
                        try
                            JulGame.add_collider(newEntity, component::Collider)
                        catch e
                            @error "Failed to add collider to entity: $(newEntity.name), path: $(component.path), error: $(e)"

                        end
                        continue
                    elseif typeof(component) == CircleCollider
                        @debug "Adding circle collider to entity: $(newEntity.name), path: $(component.path)"
                        try
                            JulGame.add_circle_collider(newEntity, component::CircleCollider)
                        catch e
                            @error "Failed to add circle collider to entity: $(newEntity.name), path: $(component.path), error: $(e)"

                        end
                        continue
                    elseif typeof(component) == Rigidbody
                        @debug "Adding rigidbody to entity: $(newEntity.name), path: $(component.path)"
                        try
                            JulGame.add_rigidbody(newEntity, component::Rigidbody)
                        catch e
                            @error "Failed to add rigidbody to entity: $(newEntity.name), path: $(component.path), error: $(e)"

                        end
                        continue
                    elseif typeof(component) == Shape
                        @debug "Adding shape to entity: $(newEntity.name), path: $(component.path)"
                        JulGame.add_shape(newEntity, component::Shape)
                        continue
                    elseif typeof(component) == SoundSource
                        @debug "Adding sound source to entity: $(newEntity.name), path: $(component.path)"
                        try
                            JulGame.add_sound_source(newEntity, component::SoundSource)
                        catch e
                            @error "Failed to add sound source to entity: $(newEntity.name), path: $(component.path), error: $(e)"

                        end
                        continue
                    elseif typeof(component) == Sprite
                        @debug "Adding sprite to entity: $(newEntity.name), path: $(component.path)"
                        try
                            JulGame.add_sprite(newEntity, false, component::Sprite)
                        catch e
                            @error "Failed to add sprite to entity: $(newEntity.name), path: $(component.path), error: $(e)"

                        end
                        continue
                    elseif typeof(component) == Transform 
                        @debug "Adding transform to entity: $(newEntity.name), path: $(component.path)"
                        try
                            newEntity.transform = component::Transform 
                            newEntity.transform.parent = newEntity
                        catch e
                            @error "Failed to add transform to entity: $(newEntity.name), path: $(component.path), error: $(e)"

                        end
                        continue 
                    end
                end
                
                push!(entities, newEntity)
            end

            for entity in entities
                if haskey(childParentDict, string(entity.id))
                    parentId::String = childParentDict[string(entity.id)]
                    for e in entities
                        if string(e.id) == parentId
                            entity.parent = e
                        end
                    end
                end
            end
            uiElements = deserialize_ui_elements(root.UIElements, entities)
            camera = Camera(
                Math._Vector2{Int32}(500, 500),
                Math._Vector3{Float64}(0.0, 0.0, 0.0),
                Math._Vector2{Float64}(0.0, 0.0),
                C_NULL)
            if haskey(root, "Camera")
                # JuliaC `--trim`: read camera fields via concrete `_scene_*` helpers instead of property
                # syntax (`cam.size.x`, `cam.backgroundColor.r`, ...) so the verifier doesn't walk a stack of
                # `getproperty(::JsonObj, ...)::Any` calls (was verifier #343–#380).
                cam_raw = _json_value(_scene_storage(root), "Camera", nothing)
                cam = _scene_obj(cam_raw)
                sx_c = _scene_f64(cam, "size", "x", 0.0)
                sy_c = _scene_f64(cam, "size", "y", 0.0)
                camera = Camera(
                    Math._Vector2{Int32}(Int32(round(Int, sx_c)), Int32(round(Int, sy_c))),
                    Math._Vector3{Float64}(_scene_f64(cam, "position", "x", 0.0), _scene_f64(cam, "position", "y", 0.0), 0.0),
                    Math._Vector2{Float64}(_scene_f64(cam, "offset", "x", 0.0), _scene_f64(cam, "offset", "y", 0.0)),
                    C_NULL)
                camera.backgroundColor = (
                    _scene_int(cam, "backgroundColor", "r", 0),
                    _scene_int(cam, "backgroundColor", "g", 0),
                    _scene_int(cam, "backgroundColor", "b", 0),
                    _scene_int(cam, "backgroundColor", "a", 255),
                )
                zraw = _json_value(_scene_storage(cam), "zoom", nothing)
                if zraw !== nothing
                    camera.zoom = _to_f64(zraw, 1.0)
                end
            end

            return (entities, uiElements, camera)
        catch e 
            @error sprint(showerror, e)
            return nothing
        end
    end

    function deserialize_ui_elements(jsonUIElements, entities)
        res = JulGame.UI.UIElement[]
        childParentDict = Dict{String, Any}()
        default_Vector2 = Math.Vector2(0, 0)
        for uiElement in jsonUIElements
            try
                newUIElement = nothing
                if haskey(uiElement, "parent") && uiElement.parent != ""
                    childParentDict[string(uiElement.id)] = uiElement.parent
                end
                if uiElement.type == "Canvas"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 100)
                    if haskey(uiElement, "color") && haskey(uiElement.color, "r") && haskey(uiElement.color, "g") && haskey(uiElement.color, "b") && haskey(uiElement.color, "a")
                         color_tuple = (uiElement.color.r, uiElement.color.g, uiElement.color.b, uiElement.color.a)
                    end

                    newUIElement = Canvas(
                        id = string(get(uiElement, "id", JulGame.generate_uuid())),
                        name = get(uiElement, "name", "Canvas"), 
                        anchor = Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset = Math.Vector2(get(uiElement, "anchorOffset", default_Vector2).x, get(uiElement, "anchorOffset", default_Vector2).y),
                        isWorldEntity = get(uiElement, "isWorldEntity", false),
                        layer = Int(get(uiElement, "layer", 0)),
                        position = Math.Vector2(get(uiElement, "position", default_Vector2).x, get(uiElement, "position", default_Vector2).y),
                        size = Math.Vector2(get(uiElement, "size", default_Vector2).x, get(uiElement, "size", default_Vector2).y),
                        isActive = get(uiElement, "isActive", true),
                        persistentBetweenScenes = get(uiElement, "persistentBetweenScenes", false),
                        color = color_tuple,
                        isVisible = get(uiElement, "isVisible", true),
                        clipChildren = get(uiElement, "clipChildren", false),
                        rotation = convert(Float64, get(uiElement, "rotation", 0.0))
                    )
                    
                    # Deserialize children if they exist
                    if haskey(uiElement, "children") && length(uiElement.children) > 0
                        children = deserialize_canvas_children(uiElement.children, newUIElement)
                        for child in children
                            add_child(newUIElement, child)
                        end
                    end
                elseif uiElement.type == "TextBox"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 255)
                    if haskey(uiElement, "color")
                        @debug "color of $(uiElement.name): $(uiElement.color)"
                        color_tuple = (uiElement.color.r, uiElement.color.g, uiElement.color.b, uiElement.color.a)
                    end

                    newUIElement = TextBox(
                        get(uiElement, "text", " ");
                        id = string(get(uiElement, "id", JulGame.generate_uuid())),
                        name = get(uiElement, "name", "TextBox"), 
                        anchor = Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset = Math.Vector2(get(uiElement, "anchorOffset", default_Vector2).x, get(uiElement, "anchorOffset", default_Vector2).y),
                        isWorldEntity = get(uiElement, "isWorldEntity", false),
                        layer = Int(get(uiElement, "layer", 0)),
                        position = Math.Vector2(get(uiElement, "position", default_Vector2).x, get(uiElement, "position", default_Vector2).y), 
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
                elseif uiElement.type == "Rectangle"
                    color = get(uiElement, "color", Dict("4" => 255, "1" => 255, "2" => 255, "3" => 255))
                    color_tuple = (get(color, "1", 255), get(color, "2", 255), get(color, "3", 255), get(color, "4", 255))
                    borderColor = get(uiElement, "borderColor", Dict("4" => 255, "1" => 255, "2" => 255, "3" => 255))
                    borderColor_tuple = (get(borderColor, "1", 255), get(borderColor, "2", 255), get(borderColor, "3", 255), get(borderColor, "4", 255))
                    newUIElement = JulGame.UI.RectangleModule.Rectangle(;
                        id=string(get(uiElement, "id", JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Rectangle"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset=Math.Vector2(get(uiElement, "anchorOffset", default_Vector2).x, get(uiElement, "anchorOffset", default_Vector2).y),
                        isWorldEntity=get(uiElement, "isWorldEntity", false),
                        layer=Int(get(uiElement, "layer", 0)),
                        position=Math.Vector2(get(uiElement, "position", default_Vector2).x, get(uiElement, "position", default_Vector2).y),
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false),
                        color=color_tuple,
                        fillMode=get(uiElement, "fillMode", true),
                        borderRadius=Int(get(uiElement, "borderRadius", 0)),
                        borderWidth=Int(get(uiElement, "borderWidth", 0)),
                        borderColor=borderColor_tuple,
                        size=Math.Vector2(get(uiElement, "size", default_Vector2).x, get(uiElement, "size", default_Vector2).y),
                        parent=nothing,
                        forceClickCheck=get(uiElement, "forceClickCheck", false),
                        # clickEvents=get(uiElement, "clickEvents", Function[]),
                        # hoverEnterEvents=get(uiElement, "hoverEnterEvents", Function[]),
                        # hoverExitEvents=get(uiElement, "hoverExitEvents", Function[]),
                    )
                else
                    # For text offset, check if it should be centered (if not specified or all zeros)
                    textOffset = Math.Vector2(uiElement.textOffset.x, uiElement.textOffset.y)
                    if !haskey(uiElement, "textOffset") || (textOffset.x == 0 && textOffset.y == 0)
                        # Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = Math.Vector2(-1, -1)
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
                @error sprint(showerror, e)
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
                newComponent = Transform(Math.Vector2f(component.position.x, component.position.y), Math.Vector2f(component.scale.x, component.scale.y))
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
                offset::Math.Vector2f = !haskey(component, "offset") ? Math.Vector2f(0,0) : Math.Vector2f(component.offset.x, component.offset.y)
                newComponent = Collider(enabled::Bool, isPlatformerCollider, isTrigger, offset,  Math.Vector2f(component.size.x, component.size.y), component.tag::String)
            elseif component.type == "CircleCollider"
                newComponent = CircleCollider(convert(Float64, component.diameter), component.enabled, component.isTrigger, Math.Vector2f(component.offset.x, component.offset.y), component.tag)
            elseif component.type == "Rigidbody"
                newComponent = Rigidbody(; mass = convert(Float64, component.mass), useGravity = !haskey(component, "useGravity") ? true : component.useGravity)
            elseif component.type == "SoundSource"
                newComponent = SoundSource(component.channel, component.isMusic, component.path, get(component, "playOnStart", false), component.volume)
            elseif component.type == "Sprite"
                color = !haskey(component, "color") || _isempty_json_field(component.color) ? (255,255,255,255) : (get(component.color, "x", 255), get(component.color, "y", 255), get(component.color, "z", 255), get(component.color, "t", 255))
                crop = !haskey(component, "crop") || _isempty_json_field(component.crop) ? Vector4(0,0,0,0) : Vector4(component.crop.x, component.crop.y, component.crop.z, component.crop.t)
                layer = !haskey(component, "layer") ? 0 : component.layer
                offset = !haskey(component, "offset") ? Math.Vector2f() : Math.Vector2f(component.offset.x, component.offset.y)
                position = !haskey(component, "position") ? Math.Vector2f() : Math.Vector2f(component.position.x, component.position.y)
                rotation = !haskey(component, "rotation") ? 0.0 : convert(Float64, component.rotation)
                pixelsPerUnit = !haskey(component, "pixelsPerUnit") ? -1 : component.pixelsPerUnit
                center = !haskey(component, "center") ? Math.Vector2f(0.5,0.5) : Math.Vector2f(component.center.x, component.center.y)
                anchor = !haskey(component, "anchor") ? :center : Symbol(component.anchor)
                isStatic = !haskey(component, "isStatic") ? false : component.isStatic
                newComponent = Sprite(color::NTuple{4, Int}, crop::Union{Ptr{Nothing}, Math.Vector4}, component.isFlipped::Bool, component.imagePath::String, layer::Int, offset::Math.Vector2f, position::Math.Vector2f, rotation::Float64, pixelsPerUnit::Int, center::Math.Vector2f, anchor::Symbol, isStatic::Bool)
            elseif component.type == "Shape"
                color = !haskey(component, "color") || _isempty_json_field(component.color) ? Vector3(255,255,255) : Vector3(component.color.x, component.color.y, component.color.z)
                layer = !haskey(component, "layer") ? 0 : component.layer
                size = !haskey(component, "size") || _isempty_json_field(component.size) ? Math.Vector2f(1,1) : Math.Vector2f(component.size.x, component.size.y)
                isFilled = !haskey(component, "isFilled") ? true : component.isFilled
                isWorldEntity = !haskey(component, "isWorldEntity") ? true : component.isWorldEntity
                offset = !haskey(component, "offset") ? Math.Vector2f() : Math.Vector2f(component.offset.x, component.offset.y)
                position = !haskey(component, "position") ? Math.Vector2f() : Math.Vector2f(component.position.x, component.position.y)
                alpha = !haskey(component, "alpha") ? 255 : component.alpha
                newComponent = Shape(color::Vector3, isFilled::Bool, isWorldEntity::Bool, layer::Int, offset::Math.Vector2f, position::Math.Vector2f, size::Math.Vector2f, alpha::Int)
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
            @error sprint(showerror, e)
        end
    end

    """
    deserialize_canvas_children(jsonChildren, parentCanvas)
    
    Recursively deserializes Canvas children.
    """
    function deserialize_canvas_children(jsonChildren, parentCanvas)
        children = UI.UIElement[]
        default_Vector2 = Math.Vector2(0,0)
        
        for child in jsonChildren
            try
                newChild = nothing
                if child.type == "Canvas"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 100)
                    if haskey(child, "color") && haskey(child.color, "r") && haskey(child.color, "g") && haskey(child.color, "b") && haskey(child.color, "a")
                         color_tuple = (child.color.r, child.color.g, child.color.b, child.color.a)
                    end

                    newChild = Canvas(
                        id = string(get(child, "id", JulGame.generate_uuid())),
                        name = get(child, "name", "Canvas"), 
                        anchor = Symbol(get(child, "anchor", "none")),
                        anchorOffset = Math.Vector2(get(child, "anchorOffset", default_Vector2).x, get(child, "anchorOffset", default_Vector2).y),
                        isWorldEntity = get(child, "isWorldEntity", false),
                        layer = Int(get(child, "layer", 0)),
                        position = Math.Vector2(get(child, "position", default_Vector2).x, get(child, "position", default_Vector2).y),
                        size = Math.Vector2(get(child, "size", default_Vector2).x, get(child, "size", default_Vector2).y),
                        isActive = get(child, "isActive", true),
                        persistentBetweenScenes = get(child, "persistentBetweenScenes", false),
                        color = color_tuple,
                        isVisible = get(child, "isVisible", true),
                        clipChildren = get(child, "clipChildren", false),
                        rotation = convert(Float64, get(child, "rotation", 0.0)),
                        parent = parentCanvas
                    )
                    
                    # Recursively deserialize children if they exist
                    if haskey(child, "children") && length(child.children) > 0
                        grandChildren = deserialize_canvas_children(child.children, newChild)
                        for grandChild in grandChildren
                            add_child(newChild, grandChild)
                        end
                    end
                elseif child.type == "ScreenButton"
                    # For text offset, check if it should be centered (if not specified or all zeros)
                    textOffset = Math.Vector2(child.textOffset.x, child.textOffset.y)
                    if !haskey(child, "textOffset") || (textOffset.x == 0 && textOffset.y == 0)
                        # Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = Math.Vector2(-1, -1)
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
                    if haskey(child, "color") && haskey(child.color, "r") && haskey(child.color, "g") && haskey(child.color, "b") && haskey(child.color, "a")
                         color_tuple = (child.color.r, child.color.g, child.color.b, child.color.a)
                    end

                    newChild = TextBox(
                        get(child, "text", " ");
                        id = string(get(child, "id", JulGame.generate_uuid())),
                        name = get(child, "name", "TextBox"), 
                        anchor = Symbol(get(child, "anchor", "none")),
                        anchorOffset = Math.Vector2(get(child, "anchorOffset", default_Vector2).x, get(child, "anchorOffset", default_Vector2).y),
                        isWorldEntity = get(child, "isWorldEntity", false),
                        layer = Int(get(child, "layer", 0)),
                        position = Math.Vector2(get(child, "position", default_Vector2).x, get(child, "position", default_Vector2).y), 
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
                @error sprint(showerror, e)
            end
        end
        
        return children
    end
end
