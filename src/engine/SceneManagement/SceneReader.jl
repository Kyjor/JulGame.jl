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
    const SceneJSONDictLike = Union{Dict{String,Any}, SceneJSONObject}

    # Parametric storage so `_scene_storage(::JsonObj{T})::T` and `_json_lookup(st, k)` dispatch to concrete methods (JuliaC `--trim`).
    struct JsonObj{T<:Union{SceneJSONDictLike,JSON3.Object}}
        d::T
    end
    @inline JsonObj(d::T) where {T<:Union{SceneJSONDictLike,JSON3.Object}} = JsonObj{T}(d)

    @Base.noinline function _json_lookup(d::Dict{String,Any}, k::AbstractString)::Any
        ks = string(k)
        return haskey(d, ks) ? d[ks] : nothing
    end

    @Base.noinline function _json_lookup(d::SceneJSONObject, k::AbstractString)::Any
        ks = string(k)
        return haskey(d, ks) ? d[ks] : nothing
    end

    @Base.noinline function _json_lookup(d::JSON3.Object, k::AbstractString)::Any
        ks = string(k)
        sym = Symbol(ks)
        return haskey(d, sym) ? d[sym] : nothing
    end

    @Base.noinline function _expose_vector_for_scene(v::AbstractVector)::Vector{Any}
        out = Any[]
        for i = 1:length(v)
            push!(out, _expose(v[i]))
        end
        return out
    end

    @inline _expose_dictlike_to_jsonobj(v::AbstractDict)::JsonObj =
        JsonObj(Dict{String,Any}(string(k) => x for (k, x) in pairs(v)))

    @Base.noinline _expose(v::Dict{String,Any}) = JsonObj(v)
    @Base.noinline _expose(v::SceneJSONObject) = JsonObj(v)
    @Base.noinline _expose(v::JSON3.Object) = JsonObj(v)
    @Base.noinline function _expose(v::AbstractDict)
        return _expose_dictlike_to_jsonobj(v)
    end
    @Base.noinline function _expose(v::AbstractVector)
        return _expose_vector_for_scene(v)
    end
    @Base.noinline _expose(v::Nothing) = nothing
    @Base.noinline _expose(v) = v

    @inline _scene_storage(o::JsonObj{T}) where {T} = getfield(o, :d)::T

    function _scene_obj(v)
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

    function _to_bool(v, default::Bool)::Bool
        v === nothing && return default
        v isa Bool && return v
        v isa Int && return v != 0
        v isa Int32 && return v != 0
        v isa Int16 && return v != 0
        v isa Int8 && return v != 0
        v isa UInt && return v != 0
        v isa UInt32 && return v != 0
        v isa UInt16 && return v != 0
        v isa UInt8 && return v != 0
        v isa Float64 && return v != 0.0
        v isa Float32 && return v != 0.0f0
        return default
    end

    function _json_string(o::JsonObj, key::String, default::String)::String
        v = _json_lookup(_scene_storage(o), key)
        v === nothing && return default
        v isa String && return v
        v isa Symbol && return String(v)
        v isa Bool && return v ? "true" : "false"
        v isa Int && return string(v)
        v isa Int32 && return string(v)
        v isa Int16 && return string(v)
        v isa Int8 && return string(v)
        v isa UInt && return string(v)
        v isa UInt32 && return string(v)
        v isa UInt16 && return string(v)
        v isa UInt8 && return string(v)
        v isa Float64 && return string(v)
        v isa Float32 && return string(v)
        return default
    end

    function _json_any_array(o::JsonObj, key::String)::Vector{Any}
        v = _json_lookup(_scene_storage(o), key)
        v === nothing && return Any[]
        if v isa Vector{Any}
            return v
        elseif v isa Vector
            out = Any[]
            for x in v
                push!(out, x)
            end
            return out
        elseif v isa JSON3.Array
            out = Any[]
            for x in v
                push!(out, x)
            end
            return out
        end
        return Any[]
    end

    """Read `parent.sub_key.leaf_key` as `Float64` without going through `getproperty(::JsonObj)::Any` chains."""
    function _scene_f64(parent::JsonObj, sub_key::String, leaf_key::String, default::Float64)::Float64
        sub = _json_lookup(_scene_storage(parent), sub_key)
        sub === nothing && return default
        inner = _scene_obj(sub)
        return _to_f64(_json_lookup(_scene_storage(inner), leaf_key), default)
    end

    """Read `parent.sub_key.leaf_key` as `Int` without going through `getproperty(::JsonObj)::Any` chains."""
    function _scene_int(parent::JsonObj, sub_key::String, leaf_key::String, default::Int)::Int
        sub = _json_lookup(_scene_storage(parent), sub_key)
        sub === nothing && return default
        inner = _scene_obj(sub)
        return _to_int(_json_lookup(_scene_storage(inner), leaf_key), default)
    end

    @Base.noinline function _vec2f_from_json(c::JsonObj, sub_key::String, def_x::Float64, def_y::Float64)::Math._Vector2{Float64}
        xf = _scene_f64(c, sub_key, "x", def_x)
        yf = _scene_f64(c, sub_key, "y", def_y)
        return Math._Vector2{Float64}(xf, yf)
    end

    """Integer `Vector2` from `sub_key.{x,y}` for UI scene JSON (JuliaC `--trim`, avoids `get(::Any,...)` and `Vector2::Any`)."""
    @inline function _ui_vec2i_from_json(o::JsonObj, sub_key::String, def::Math._Vector2{Int32})::Math._Vector2{Int32}
        Math._Vector2{Int32}(
            Int32(_scene_int(o, sub_key, "x", Int(def.x))),
            Int32(_scene_int(o, sub_key, "y", Int(def.y))),
        )
    end

    """RGBA tuple from UI JSON `color` / `borderColor` (keys `"1"`..`"4"`) or a plain `Dict` (JuliaC `--trim`)."""
    function _ui_rgba_tuple_from_color_field(c)::NTuple{4, Int}
        if c isa JsonObj
            st = _scene_storage(c)
            return (
                _to_int(_json_lookup(st, "1"), 255),
                _to_int(_json_lookup(st, "2"), 255),
                _to_int(_json_lookup(st, "3"), 255),
                _to_int(_json_lookup(st, "4"), 255),
            )
        end
        d = c::AbstractDict
        return (
            Int(get(d, "1", 255)),
            Int(get(d, "2", 255)),
            Int(get(d, "3", 255)),
            Int(get(d, "4", 255)),
        )
    end

    function Base.getproperty(o::JsonObj{T}, k::Symbol) where {T<:SceneJSONDictLike}
        k === :d && return getfield(o, :d)
        d = getfield(o, :d)::T
        raw = get(d, string(k), Base.nothing)
        raw === nothing && return nothing
        return _expose(raw)
    end

    function Base.getproperty(o::JsonObj{T}, k::Symbol) where {T<:JSON3.Object}
        k === :d && return getfield(o, :d)
        d = getfield(o, :d)::T
        raw = get(d, k, Base.nothing)
        raw === nothing && return nothing
        return _expose(raw)
    end

    function Base.haskey(o::JsonObj{T}, k::AbstractString) where {T<:SceneJSONDictLike}
        d = getfield(o, :d)::T
        ks = string(k)
        return haskey(d, ks)
    end

    function Base.haskey(o::JsonObj{T}, k::AbstractString) where {T<:JSON3.Object}
        d = getfield(o, :d)::T
        return haskey(d, Symbol(string(k)))
    end

    function Base.get(o::JsonObj{T}, k::AbstractString, default) where {T<:SceneJSONDictLike}
        @nospecialize default
        d = getfield(o, :d)::T
        ks = string(k)
        if !haskey(d, ks)
            return default
        end
        return _expose(get(d, ks, Base.nothing))
    end

    function Base.get(o::JsonObj{T}, k::AbstractString, default) where {T<:JSON3.Object}
        @nospecialize default
        d = getfield(o, :d)::T
        sym = Symbol(string(k))
        if !haskey(d, sym)
            return default
        end
        return _expose(get(d, sym, Base.nothing))
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
    function _as_scene_json_root(x)
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

            root::JsonObj = JsonObj(Dict{String, Any}())
            if Base.haskey(JulGame.SCENE_CACHE, basename(filePath))
                cached_json = JulGame.SCENE_CACHE[basename(filePath)]
                if cached_json isa JsonObj
                    root = cached_json
                elseif cached_json isa Dict{String, Any}
                    root = JsonObj(cached_json)
                elseif cached_json isa SceneJSONObject
                    root = JsonObj(cached_json)
                elseif cached_json isa JSON3.Object
                    root = JsonObj(cached_json)
                end
                @debug("using cached scene")
            else 
                entitiesJson = read(filePath, String)
                root = _scene_root_jsonobj_from_file(entitiesJson)
                @debug("using scene from scene file")
            end

            entities = Entity[]
            childParentDict = Dict{String, String}()
    
            entityIdsInCurrentScene = String[]
            try
                main_loop = JulGame.current_main()
                entityIdsInCurrentScene = [e.id for e in main_loop.scene.entities]
            catch e
                @error sprint(showerror, e)
            end
            entities_json = _json_any_array(root, "Entities")
            for entity_raw in entities_json
                entity = _scene_obj(entity_raw)
                entity_id = _json_string(entity, "id", "")
                if entity_id in entityIdsInCurrentScene
                    @debug "Entity with id $(entity_id) already exists in current scene"
                    continue
                end
                components = Any[]
    
                components_raw = _json_any_array(entity, "components")
                for component_raw in components_raw
                    component = _scene_obj(component_raw)
                    component_type = _json_string(component, "type", "")
                    @debug "Deserializing component: $(component_type)"
                    dc = deserialize_component(component)
                    if dc !== nothing
                        push!(components, dc)
                    end
                end
                
                entity_parent = _json_string(entity, "parent", "")
                if entity_parent != ""
                    childParentDict[entity_id] = entity_parent
                end
                entity_name = _json_string(entity, "name", "New entity")
                newEntity = Entity(entity_name, entity_id)
                newEntity.isActive = _to_bool(_json_lookup(_scene_storage(entity), "isActive"), true)
                # Keep raw JSON3.Object/Dict entries here; SceneBuilder reifies them via `isa(script, JSON3.Object)`.
                newEntity.scripts = _json_any_array(entity, "scripts")
                newEntity.persistentBetweenScenes = _to_bool(_json_lookup(_scene_storage(entity), "persistentBetweenScenes"), false)

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
            ui_raw = _json_any_array(root, "UIElements")
            uiElements = deserialize_ui_elements(ui_raw, entities)
            camera = Camera(
                Math._Vector2{Int32}(500, 500),
                Math._Vector3{Float64}(0.0, 0.0, 0.0),
                Math._Vector2{Float64}(0.0, 0.0),
                C_NULL)
            cam_raw = _json_lookup(_scene_storage(root), "Camera")
            if cam_raw !== nothing
                # JuliaC `--trim`: read camera fields via concrete `_scene_*` helpers instead of property
                # syntax (`cam.size.x`, `cam.backgroundColor.r`, ...) so the verifier doesn't walk a stack of
                # `getproperty(::JsonObj, ...)::Any` calls (was verifier #343–#380).
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
                zraw = _json_lookup(_scene_storage(cam), "zoom")
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
        res = JulGame.IUIElement[]
        childParentDict = Dict{String, Any}()
        uiElementsById = Dict{String, JulGame.IUIElement}()
        entitiesById = Dict{String, Entity}(string(e.id) => e for e in entities)
        default_Vector2 = Math._Vector2{Int32}(0, 0)
        for ui_raw in jsonUIElements
            try
                uiElement = _scene_obj(ui_raw)::JsonObj
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
                        anchorOffset = _ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        isWorldEntity = get(uiElement, "isWorldEntity", false),
                        layer = Int(get(uiElement, "layer", 0)),
                        position = _ui_vec2i_from_json(uiElement, "position", default_Vector2),
                        size = _ui_vec2i_from_json(uiElement, "size", default_Vector2),
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
                        anchorOffset = _ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        isWorldEntity = get(uiElement, "isWorldEntity", false),
                        layer = Int(get(uiElement, "layer", 0)),
                        position = _ui_vec2i_from_json(uiElement, "position", default_Vector2), 
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
                    color_tuple = _ui_rgba_tuple_from_color_field(color)
                  
                    newUIElement = UIImage(
                        get(uiElement, "path", "Default");
                        id=string(get(uiElement, "id", JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Image"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset=_ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        layer=Int(get(uiElement, "layer", 0)),
                        position=_ui_vec2i_from_json(uiElement, "position", default_Vector2),
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false),
                        color=color_tuple,
                        size=_ui_vec2i_from_json(uiElement, "size", default_Vector2),
                        parent=nothing,
                        rotation=convert(Float64, get(uiElement, "rotation", 0.0)),
                        # clickEvents=get(uiElement, "clickEvents", Function[]),
                        # hoverEnterEvents=get(uiElement, "hoverEnterEvents", Function[]),
                        # hoverExitEvents=get(uiElement, "hoverExitEvents", Function[]),
                    )
                elseif uiElement.type == "Rectangle"
                    color = get(uiElement, "color", Dict("4" => 255, "1" => 255, "2" => 255, "3" => 255))
                    color_tuple = _ui_rgba_tuple_from_color_field(color)
                    borderColor = get(uiElement, "borderColor", Dict("4" => 255, "1" => 255, "2" => 255, "3" => 255))
                    borderColor_tuple = _ui_rgba_tuple_from_color_field(borderColor)
                    newUIElement = JulGame.UI.RectangleModule.Rectangle(;
                        id=string(get(uiElement, "id", JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Rectangle"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset=_ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        isWorldEntity=get(uiElement, "isWorldEntity", false),
                        layer=Int(get(uiElement, "layer", 0)),
                        position=_ui_vec2i_from_json(uiElement, "position", default_Vector2),
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false),
                        color=color_tuple,
                        fillMode=get(uiElement, "fillMode", true),
                        borderRadius=Int(get(uiElement, "borderRadius", 0)),
                        borderWidth=Int(get(uiElement, "borderWidth", 0)),
                        borderColor=borderColor_tuple,
                        size=_ui_vec2i_from_json(uiElement, "size", default_Vector2),
                        parent=nothing,
                        forceClickCheck=get(uiElement, "forceClickCheck", false),
                        # clickEvents=get(uiElement, "clickEvents", Function[]),
                        # hoverEnterEvents=get(uiElement, "hoverEnterEvents", Function[]),
                        # hoverExitEvents=get(uiElement, "hoverExitEvents", Function[]),
                    )
                else
                    # For text offset, check if it should be centered (if not specified or all zeros)
                    textOffset = _ui_vec2i_from_json(uiElement, "textOffset", default_Vector2)
                    if !haskey(uiElement, "textOffset") || (textOffset.x == Int32(0) && textOffset.y == Int32(0))
                        # Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = Math._Vector2{Int32}(Int32(-1), Int32(-1))
                    end
                    
                    newUIElement = ScreenButton(
                        nothing; # clickEvent - Assuming none from scene file directly
                        id=string(get(uiElement, "id", JulGame.generate_uuid())),
                        name=get(uiElement, "name", "Button"),
                        anchor=Symbol(get(uiElement, "anchor", "none")),
                        anchorOffset=_ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        isWorldEntity=get(uiElement, "isWorldEntity", false),
                        layer=Int(get(uiElement, "layer", 0)),
                        position=_ui_vec2i_from_json(uiElement, "position", default_Vector2),
                        buttonUpSpritePath=get(uiElement, "buttonUpSpritePath", "Default"),
                        buttonDownSpritePath=get(uiElement, "buttonDownSpritePath", "Default"),
                        # hoverEnterEvent=nothing, # Default
                        # hoverExitEvent=nothing, # Default
                        isActive=get(uiElement, "isActive", true),
                        persistentBetweenScenes=get(uiElement, "persistentBetweenScenes", false), # Keep the value from JSON if it exists
                        #color=color_tuple,
                        fontPath=get(uiElement, "fontPath", C_NULL),
                        fontSize=Int(get(uiElement, "fontSize", 24)),
                        size=_ui_vec2i_from_json(uiElement, "size", default_Vector2),
                        text=get(uiElement, "text", ""),
                        textOffset=textOffset,
                        # parent=nothing # Default
                    )
                    
                    # Make sure the button is initialized properly - Constructor likely handles this
                end
                currentUIId = string(get(uiElement, "id", ""))
                newUIElement.persistentBetweenScenes = get(uiElement, "persistentBetweenScenes", false)
                push!(res, newUIElement)
                if currentUIId != ""
                    uiElementsById[currentUIId] = newUIElement
                end
            catch e 
                @error sprint(showerror, e)
            end
        end

        for (childId, parentRef) in childParentDict
            parentRef === nothing && continue
            pref = string(parentRef)
            pref == "" && continue
            split_ref = split(pref, "::")
            length(split_ref) != 2 && continue
            parentId, parentType = split_ref
            child = get(uiElementsById, string(childId), Base.nothing)
            child === nothing && continue
            if parentType == "Entity"
                parentEntity = get(entitiesById, string(parentId), Base.nothing)
                parentEntity === nothing && continue
                JulGame.UI.add_relationship_if_not_exists(child)
                setfield!(JulGame.UI.relationship_instance(child), :parent, parentEntity)
            else
                parentUI = get(uiElementsById, string(parentId), Base.nothing)
                parentUI === nothing && continue
                JulGame.UI.add_relationship_if_not_exists(child)
                setfield!(JulGame.UI.relationship_instance(child), :parent, parentUI)
            end
        end

        return res
    end

    export deserialize_component
    function deserialize_component(component::JsonObj{T}) where {T}
        try
            ty = _json_string(component, "type", "")
            st = _scene_storage(component)
            local newComponent
            if ty == "Transform"
                newComponent = Transform(
                    _vec2f_from_json(component, "position", 0.0, 0.0),
                    _vec2f_from_json(component, "scale", 1.0, 1.0),
                )
            elseif ty == "Animator"
                newAnimations = Animation[]
                for anim_raw in _json_any_array(component, "animations")
                    anim = _scene_obj(anim_raw)
                    sta = _scene_storage(anim)
                    newAnimationFrames = Vector{Math._Vector4{Int32}}()
                    for frame_raw in _json_any_array(anim, "frames")
                        fr = _scene_obj(frame_raw)
                        stf = _scene_storage(fr)
                        push!(newAnimationFrames, Math._Vector4{Int32}(
                            Int32(_to_int(_json_lookup(stf, "x"), 0)),
                            Int32(_to_int(_json_lookup(stf, "y"), 0)),
                            Int32(_to_int(_json_lookup(stf, "z"), 0)),
                            Int32(_to_int(_json_lookup(stf, "t"), 0)),
                        ))
                    end
                    fps = _to_int(_json_lookup(sta, "animatedFPS"), 0)
                    push!(newAnimations, Animation(newAnimationFrames, fps))
                end
                newComponent = Animator(newAnimations)
            elseif ty == "Collider"
                isTrigger = _to_bool(_json_lookup(st, "isTrigger"), false)
                enabled = _to_bool(_json_lookup(st, "enabled"), true)
                isPlatformerCollider = _to_bool(_json_lookup(st, "isPlatformerCollider"), false)
                offset = _vec2f_from_json(component, "offset", 0.0, 0.0)
                sz = _vec2f_from_json(component, "size", 0.0, 0.0)
                tag = _json_string(component, "tag", "")
                newComponent = Collider(enabled, isPlatformerCollider, isTrigger, offset, sz, tag)
            elseif ty == "CircleCollider"
                newComponent = CircleCollider(
                    _to_f64(_json_lookup(st, "diameter"), 0.0),
                    _to_bool(_json_lookup(st, "enabled"), true),
                    _to_bool(_json_lookup(st, "isTrigger"), false),
                    _vec2f_from_json(component, "offset", 0.0, 0.0),
                    _json_string(component, "tag", "Default"),
                )
            elseif ty == "Rigidbody"
                newComponent = Rigidbody(;
                    mass = _to_f64(_json_lookup(st, "mass"), 0.0),
                    useGravity = _to_bool(_json_lookup(st, "useGravity"), true),
                )
            elseif ty == "SoundSource"
                newComponent = SoundSource(
                    _to_int(_json_lookup(st, "channel"), -1),
                    _to_bool(_json_lookup(st, "isMusic"), false),
                    _json_string(component, "path", ""),
                    _to_bool(_json_lookup(st, "playOnStart"), false),
                    _to_int(_json_lookup(st, "volume"), -1),
                )
            elseif ty == "Sprite"
                color_raw = _json_lookup(st, "color")
                local color_tup::NTuple{4, Int}
                if color_raw === nothing || color_raw === Base.nothing
                    color_tup = (255, 255, 255, 255)
                else
                    cj = _scene_obj(color_raw)
                    stc = _scene_storage(cj)
                    color_tup = (
                        _to_int(_json_lookup(stc, "x"), 255),
                        _to_int(_json_lookup(stc, "y"), 255),
                        _to_int(_json_lookup(stc, "z"), 255),
                        _to_int(_json_lookup(stc, "t"), 255),
                    )
                end
                crop_raw = _json_lookup(st, "crop")
                local crop_v::Math._Vector4{Int32}
                if crop_raw === nothing || crop_raw === Base.nothing
                    crop_v = Math._Vector4{Int32}(Int32(0), Int32(0), Int32(0), Int32(0))
                else
                    cj = _scene_obj(crop_raw)
                    stc = _scene_storage(cj)
                    crop_v = Math._Vector4{Int32}(
                        Int32(_to_int(_json_lookup(stc, "x"), 0)),
                        Int32(_to_int(_json_lookup(stc, "y"), 0)),
                        Int32(_to_int(_json_lookup(stc, "z"), 0)),
                        Int32(_to_int(_json_lookup(stc, "t"), 0)),
                    )
                end
                layer_i::Int = _to_int(_json_lookup(st, "layer"), 0)
                offset_v::Math._Vector2{Float64} = _vec2f_from_json(component, "offset", 0.0, 0.0)
                position_v::Math._Vector2{Float64} = _vec2f_from_json(component, "position", 0.0, 0.0)
                rotation_f::Float64 = _to_f64(_json_lookup(st, "rotation"), 0.0)
                pixels_i::Int = _to_int(_json_lookup(st, "pixelsPerUnit"), -1)
                center_v::Math._Vector2{Float64} = _vec2f_from_json(component, "center", 0.5, 0.5)
                anchor_sym::Symbol = Symbol(_json_string(component, "anchor", "center"))
                isStatic_b::Bool = _to_bool(_json_lookup(st, "isStatic"), false)
                isFlipped_b::Bool = _to_bool(_json_lookup(st, "isFlipped"), false)
                newComponent = Sprite(
                    color_tup,
                    crop_v,
                    isFlipped_b,
                    _json_string(component, "imagePath", ""),
                    layer_i,
                    offset_v,
                    position_v,
                    rotation_f,
                    pixels_i,
                    center_v,
                    anchor_sym,
                    isStatic_b,
                )
            elseif ty == "Shape"
                color_raw = _json_lookup(st, "color")
                local color_v::Math._Vector3{Int32}
                if color_raw === nothing || color_raw === Base.nothing
                    color_v = Math._Vector3{Int32}(Int32(255), Int32(255), Int32(255))
                else
                    cj = _scene_obj(color_raw)
                    stc = _scene_storage(cj)
                    color_v = Math._Vector3{Int32}(
                        Int32(_to_int(_json_lookup(stc, "x"), 255)),
                        Int32(_to_int(_json_lookup(stc, "y"), 255)),
                        Int32(_to_int(_json_lookup(stc, "z"), 255)),
                    )
                end
                shape_layer::Int = _to_int(_json_lookup(st, "layer"), 0)
                size_v::Math._Vector2{Float64} = _vec2f_from_json(component, "size", 1.0, 1.0)
                isFilled_b::Bool = _to_bool(_json_lookup(st, "isFilled"), true)
                isWorld_b::Bool = _to_bool(_json_lookup(st, "isWorldEntity"), true)
                shape_offset_v::Math._Vector2{Float64} = _vec2f_from_json(component, "offset", 0.0, 0.0)
                shape_position_v::Math._Vector2{Float64} = _vec2f_from_json(component, "position", 0.0, 0.0)
                alpha_i::Int = _to_int(_json_lookup(st, "alpha"), 255)
                newComponent = Shape(color_v, isFilled_b, isWorld_b, shape_layer, shape_offset_v, shape_position_v, size_v, alpha_i)
            elseif ty == "Mesh3D"
                # Omitted for JuliaC `--trim` (Mesh3D / JSON3 paths); scenes with 3D entities skip this component.
                newComponent = nothing
            else
                newComponent = nothing
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
        children = JulGame.IUIElement[]
        default_Vector2 = Math._Vector2{Int32}(Int32(0), Int32(0))
        
        for child_raw in jsonChildren
            try
                child = _scene_obj(child_raw)::JsonObj
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
                        anchorOffset = _ui_vec2i_from_json(child, "anchorOffset", default_Vector2),
                        isWorldEntity = get(child, "isWorldEntity", false),
                        layer = Int(get(child, "layer", 0)),
                        position = _ui_vec2i_from_json(child, "position", default_Vector2),
                        size = _ui_vec2i_from_json(child, "size", default_Vector2),
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
                    textOffset = _ui_vec2i_from_json(child, "textOffset", default_Vector2)
                    if !haskey(child, "textOffset") || (textOffset.x == Int32(0) && textOffset.y == Int32(0))
                        # Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = Math._Vector2{Int32}(Int32(-1), Int32(-1))
                    end
                    
                    newChild = ScreenButton(
                        nothing; # clickEvent - Assuming none from scene file directly
                        id=string(get(child, "id", JulGame.generate_uuid())),
                        name=get(child, "name", "Button"),
                        anchor=Symbol(get(child, "anchor", "none")),
                        anchorOffset=_ui_vec2i_from_json(child, "anchorOffset", default_Vector2),
                        isWorldEntity=get(child, "isWorldEntity", false),
                        layer=Int(get(child, "layer", 0)),
                        position=_ui_vec2i_from_json(child, "position", default_Vector2),
                        buttonUpSpritePath=get(child, "buttonUpSpritePath", "Default"),
                        buttonDownSpritePath=get(child, "buttonDownSpritePath", "Default"),
                        isActive=get(child, "isActive", true),
                        persistentBetweenScenes=get(child, "persistentBetweenScenes", false),
                        fontPath=get(child, "fontPath", C_NULL),
                        fontSize=Int(get(child, "fontSize", 24)),
                        size=_ui_vec2i_from_json(child, "size", default_Vector2),
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
                        anchorOffset = _ui_vec2i_from_json(child, "anchorOffset", default_Vector2),
                        isWorldEntity = get(child, "isWorldEntity", false),
                        layer = Int(get(child, "layer", 0)),
                        position = _ui_vec2i_from_json(child, "position", default_Vector2), 
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
