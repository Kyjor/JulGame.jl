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

    """Shallow copy of `JSON3.Object` into `Dict{String,Any}` via `pairs` (no `Generator` dict ctor)."""
    # JuliaC `--trim`: dict iteration yields `Any`; macro-expanded branches still emitted `invoke` to
    # `_json3_array_to_vector_any` / `_scene_json_tree_vector`. Route all cell work through `jl_call1` + runtime body.
    macro _scene_json_tree_cell(ex)
        :(ccall(:jl_call1, Any, (Any, Any), $(GlobalRef(SceneReaderModule, :_scene_json_tree_cell_runtime)), $(esc(ex)))::Any)
    end

    """Some JSON parse paths leave `#undef` holes in `Vector{Any}`; reading `v[i]` throws `UndefRefError`."""
    @Base.noinline function _json_safe_vector_get(v::AbstractVector, i::Integer)::Any
        if v isa Vector{Any}
            Base.isassigned(v, i) || return nothing
        end
        return @inbounds v[i]
    end

    """`for x in v` can throw on `#undef` slots in `Array`; use before indexed read in hot loops."""
    @inline function _scene_vector_slot_assigned(v::AbstractVector, i::Integer)::Bool
        v isa Array || return true
        return Base.isassigned(v, i)
    end

    @Base.noinline function _scene_json_tree_vector(v::AbstractVector)::Vector{Any}
        a = firstindex(v)
        b = lastindex(v)
        n = b - a + 1
        out = Vector{Any}(undef, n)
        j = 1
        @inbounds for i in a:b
            out[j] = @_scene_json_tree_cell _json_safe_vector_get(v, i)
            j += 1
        end
        return out
    end

    """JuliaC `--trim`: avoid `JSON.parse`/`JSON3.write` and `Base.copy(::JSON3.Object)` (often unresolved)."""
    @Base.noinline function _json3_array_to_vector_any(a::JSON3.Array)::Vector{Any}
        n = length(a)
        out = Vector{Any}(undef, n)
        @inbounds for i in 1:n
            out[i] = @_scene_json_tree_cell a[i]
        end
        return out
    end

    """Normalize a value read from `JSON3.Object` / `JSON3.Array` tape (JuliaC `--trim`; no `Base.copy(::JSON3.Object)`)."""
    @Base.noinline function _json3_field_value_to_tree(v)::Any
        v === nothing && return nothing
        if v isa JSON3.Object
            return ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_json3_object_to_string_dict_body), v::JSON3.Object)::Dict{String,Any}
        elseif v isa JSON3.Array
            return ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_json3_array_to_vector_any), v::JSON3.Array)::Vector{Any}
        elseif v isa Dict{Symbol,Any}
            return _symbol_dict_to_stringkey_tree(v::Dict{Symbol,Any})
        elseif v isa AbstractVector
            return ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_scene_json_tree_vector), v::AbstractVector)::Vector{Any}
        else
            return v
        end
    end

    """Walk `JSON3.Object` via `populateinds!` + `getinds` + `get`; call sites use `ccall(:jl_call1, …, _json3_object_to_string_dict_body, …)` for JuliaC `--trim`."""
    @Base.noinline function _json3_object_to_string_dict_body(o::JSON3.Object)::Dict{String,Any}
        JSON3.populateinds!(o)
        inds = JSON3.getinds(o)::Dict{Symbol,Int}
        out = Dict{String,Any}()
        sizehint!(out, length(inds))
        for (ksym, _) in inds
            ks = Base.string(ksym)::String
            val = JSON3.get(o, ksym)::Any
            out[ks] = ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_json3_field_value_to_tree), val)::Any
        end
        return out
    end

    @Base.noinline function _symbol_dict_to_stringkey_tree(d::Dict{Symbol,Any})::Dict{String,Any}
        out = Dict{String,Any}()
        for k in keys(d)
            ks = Base.string(k)::String
            xv = try
                d[k]
            catch err
                err isa UndefRefError && continue
                rethrow()
            end
            out[ks] = ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_json3_field_value_to_tree), xv)::Any
        end
        return out
    end

    @Base.noinline function _deep_normalize_json_dict(d::Dict{String,Any})::Dict{String,Any}
        out = Dict{String,Any}()
        for k in keys(d)
            ks = Base.string(k)::String
            xv = try
                d[k]
            catch err
                err isa UndefRefError && continue
                rethrow()
            end
            out[ks] = @_scene_json_tree_cell xv
        end
        return out
    end

    # JuliaC `--trim`: do not use `JSON.json` / `JSON.parse` on `SceneJSONObject` (pulls in StructUtils + `repr`/`show`).
    @Base.noinline function _scene_jsonobject_to_plain_dict(o::SceneJSONObject)::Dict{String,Any}
        d = Dict{String,Any}()
        for k in keys(o)
            ks = Base.string(k)::String
            v = try
                o[k]
            catch err
                err isa UndefRefError && continue
                rethrow()
            end
            d[ks] = @_scene_json_tree_cell v
        end
        return d
    end

    @Base.noinline function _scene_json_tree_cell_runtime(v::Any)::Any
        if v === nothing
            return nothing
        elseif v isa Bool || v isa Int || v isa Int32 || v isa Int64 || v isa UInt8 || v isa UInt16 || v isa UInt32 || v isa UInt64 || v isa Float64 || v isa Float32 || v isa String || v isa Symbol || v isa SubString{String}
            return v
        elseif v isa SceneJSONObject
            return _scene_jsonobject_to_plain_dict(v::SceneJSONObject)
        elseif v isa JSON3.Object
            return ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_json3_object_to_string_dict_body), v::JSON3.Object)::Dict{String,Any}
        elseif v isa Dict{String,Any}
            return _deep_normalize_json_dict(v::Dict{String,Any})
        elseif v isa Dict{Symbol,Any}
            return _deep_normalize_json_dict(_symbol_dict_to_stringkey_tree(v::Dict{Symbol,Any}))
        elseif v isa AbstractDict
            ad = v::AbstractDict
            if ad isa JSON3.Object
                return ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_json3_object_to_string_dict_body), ad::JSON3.Object)::Dict{String,Any}
            elseif ad isa Dict{String,Any}
                return _deep_normalize_json_dict(ad::Dict{String,Any})
            elseif ad isa Dict{Symbol,Any}
                return _deep_normalize_json_dict(_symbol_dict_to_stringkey_tree(ad::Dict{Symbol,Any}))
            else
                return Dict{String,Any}()
            end
        elseif v isa JSON3.Array
            return ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_json3_array_to_vector_any), v::JSON3.Array)::Vector{Any}
        elseif v isa AbstractVector
            return ccall(:jl_call1, Any, (Any, Any), GlobalRef(SceneReaderModule, :_scene_json_tree_vector), v::AbstractVector)::Vector{Any}
        else
            return v
        end
    end

    # `JsonObj` stores only `Dict{String,Any}` so JuliaC `--trim` never resolves `get`/`haskey`/`iterate` on
    # `JSON3.Object` from `getfield(::JsonObj, :d)`. JSON3 / JSON.Object roots are normalized in `JsonObj` ctors.
    struct JsonObj
        d::Dict{String,Any}
        function JsonObj(d::Dict{String,Any})
            new(_deep_normalize_json_dict(d))
        end
    end

    function JsonObj(o::SceneJSONObject)
        JsonObj(_scene_jsonobject_to_plain_dict(o))
    end

    # JuliaC `--trim`: do not define `JsonObj(::JSON3.Object)`; use `ccall(:jl_call1, …, _json3_object_to_string_dict_body, …)` at use sites.

    @Base.noinline function _unwrap_json3_array_runtime_body(a::JSON3.Array)::Vector{Any}
        n = length(a)
        out = Vector{Any}(undef, n)
        @inbounds for i in 1:n
            out[i] = _unwrap_scene_field_value_runtime(a[i])
        end
        return out
    end
    @Base.noinline function _unwrap_abstract_vector_runtime_body(vv::AbstractVector)::Vector{Any}
        fa = firstindex(vv)
        fb = lastindex(vv)
        out = Vector{Any}(undef, fb - fa + 1)
        j = 1
        for i in fa:fb
            out[j] = _unwrap_scene_field_value_runtime(_json_safe_vector_get(vv, i))
            j += 1
        end
        return out
    end

    @Base.noinline function _unwrap_scene_field_value_runtime(v)
        if v === nothing
            return nothing
        elseif v isa JsonObj
            return v::JsonObj
        elseif v isa Dict{String,Any}
            return JsonObj(v::Dict{String,Any})
        elseif v isa SceneJSONObject
            return JsonObj(v::SceneJSONObject)
        elseif v isa JSON3.Object
            return JsonObj(ccall(:jl_call1, Any, (Any, Any), _json3_object_to_string_dict_body, v::JSON3.Object)::Dict{String,Any})
        elseif v isa Dict{Symbol,Any}
            return JsonObj(_symbol_dict_to_stringkey_tree(v::Dict{Symbol,Any}))
        elseif v isa AbstractDict
            let ad = v::AbstractDict
                if ad isa JSON3.Object
                    return JsonObj(ccall(:jl_call1, Any, (Any, Any), _json3_object_to_string_dict_body, ad::JSON3.Object)::Dict{String,Any})
                elseif ad isa Dict{String,Any}
                    return JsonObj(ad::Dict{String,Any})
                elseif ad isa Dict{Symbol,Any}
                    return JsonObj(_symbol_dict_to_stringkey_tree(ad::Dict{Symbol,Any}))
                else
                    return JsonObj(Dict{String,Any}())
                end
            end
        elseif v isa JSON3.Array
            return ccall(:jl_call1, Any, (Any, Any), _unwrap_json3_array_runtime_body, v::JSON3.Array)::Vector{Any}
        elseif v isa AbstractVector
            return ccall(:jl_call1, Any, (Any, Any), _unwrap_abstract_vector_runtime_body, v::AbstractVector)::Vector{Any}
        else
            return v
        end
    end

    # Inline non-array branches so `_scene_json_get` / `getproperty` avoid `_unwrap_scene_field_value_runtime(::Any)` at top level.
    macro _unwrap_scene_field_value(ex)
        quote
            let v = $(esc(ex))
                if v === nothing
                    nothing
                elseif v isa $(esc(:JsonObj))
                    v::$(esc(:JsonObj))
                elseif v isa Dict{String,Any}
                    JsonObj(v::Dict{String,Any})
                elseif v isa $(esc(:SceneJSONObject))
                    JsonObj(v::$(esc(:SceneJSONObject)))
                elseif v isa JSON3.Object
                    JsonObj(ccall(:jl_call1, Any, (Any, Any), $(GlobalRef(SceneReaderModule, :_json3_object_to_string_dict_body)), v)::Dict{String,Any})
                elseif v isa Dict{Symbol,Any}
                    JsonObj(_symbol_dict_to_stringkey_tree(v::Dict{Symbol,Any}))
                elseif v isa AbstractDict
                    let ad = v::AbstractDict
                        if ad isa JSON3.Object
                            JsonObj(ccall(:jl_call1, Any, (Any, Any), $(GlobalRef(SceneReaderModule, :_json3_object_to_string_dict_body)), ad)::Dict{String,Any})
                        elseif ad isa Dict{String,Any}
                            JsonObj(ad::Dict{String,Any})
                        elseif ad isa Dict{Symbol,Any}
                            JsonObj(_symbol_dict_to_stringkey_tree(ad::Dict{Symbol,Any}))
                        else
                            JsonObj(Dict{String,Any}())
                        end
                    end
                elseif v isa JSON3.Array
                    ccall(:jl_call1, Any, (Any, Any), $(GlobalRef(SceneReaderModule, :_unwrap_json3_array_runtime_body)), v)::Vector{Any}
                elseif v isa AbstractVector
                    ccall(:jl_call1, Any, (Any, Any), $(GlobalRef(SceneReaderModule, :_unwrap_abstract_vector_runtime_body)), v)::Vector{Any}
                else
                    v
                end
            end
        end
    end

    macro _coerce_jsonobj_row(ex)
        rv = gensym(:row_v)
        tmp = gensym(:row_tmp)
        quote
            let $rv = $(esc(ex))
                if $rv isa JsonObj
                    $rv::JsonObj
                elseif $rv isa Dict{String,Any}
                    JsonObj($rv::Dict{String,Any})
                elseif $rv isa SceneJSONObject
                    JsonObj($rv::SceneJSONObject)
                elseif $rv isa JSON3.Object
                    JsonObj(ccall(:jl_call1, Any, (Any, Any), $(GlobalRef(SceneReaderModule, :_json3_object_to_string_dict_body)), $rv)::Dict{String,Any})
                elseif $rv isa Dict{Symbol,Any}
                    JsonObj(_symbol_dict_to_stringkey_tree($rv::Dict{Symbol,Any}))
                elseif $rv isa AbstractDict
                    let ad = $rv::AbstractDict
                        ad isa JSON3.Object ? JsonObj(ccall(:jl_call1, Any, (Any, Any), $(GlobalRef(SceneReaderModule, :_json3_object_to_string_dict_body)), ad)::Dict{String,Any}) :
                        ad isa Dict{String,Any} ? JsonObj(ad::Dict{String,Any}) :
                        ad isa Dict{Symbol,Any} ? JsonObj(_symbol_dict_to_stringkey_tree(ad::Dict{Symbol,Any})) :
                        JsonObj(Dict{String,Any}())
                    end
                else
                    JsonObj(Dict{String,Any}())
                end
            end
        end
    end

    """JuliaC `--trim`: `setproperty!(::IUIElement, :parent, ...)` is unresolved; overload on concrete child types only."""
    @Base.noinline function _attach_ui_to_canvas!(canvas::JulGame.UI.CanvasModule.Canvas, ch::JulGame.UI.CanvasModule.Canvas)::Nothing
        push!(canvas.children, ch)
        ch.parent = canvas
        return nothing
    end
    @Base.noinline function _attach_ui_to_canvas!(canvas::JulGame.UI.CanvasModule.Canvas, sb::ScreenButton)::Nothing
        push!(canvas.children, sb)
        sb.parent = canvas
        return nothing
    end
    @Base.noinline function _attach_ui_to_canvas!(canvas::JulGame.UI.CanvasModule.Canvas, tb::TextBox)::Nothing
        push!(canvas.children, tb)
        tb.parent = canvas
        return nothing
    end

    @Base.noinline function _json_obj_array(o::JsonObj, key::String)::Vector{JsonObj}
        v = _json_field(o, key)
        v === nothing && return JsonObj[]
        u = @_unwrap_scene_field_value v
        u isa Vector{Any} || return JsonObj[]
        vec = u::Vector{Any}
        out = Vector{JsonObj}(undef, length(vec))
        @inbounds for i in eachindex(vec)
            out[i] = @_coerce_jsonobj_row _json_safe_vector_get(vec, i)
        end
        return out
    end

    @Base.noinline function _json_lookup_dict(d::Dict{String,Any}, k::AbstractString)::Any
        ks = string(k)
        return Base.haskey(d, ks) ? d[ks] : nothing
    end

    """Read key `k` from scene JSON wrapped in `JsonObj` (storage is always `Dict{String,Any}`)."""
    @Base.noinline function _json_field(o::JsonObj, k::AbstractString)::Any
        return _json_lookup_dict(getfield(o, :d)::Dict{String,Any}, k)
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
        v = _json_field(o, key)
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
        v = _json_field(o, key)
        v === nothing && return Any[]
        u = @_unwrap_scene_field_value v
        u isa Vector{Any} || return Any[]
        vec = u::Vector{Any}
        # Some JSON stacks leave `#undef` in `Vector{Any}`; `convert` to `Vector{Union{…}}` (e.g. `Entity.scripts`)
        # reads every slot and throws `UndefRefError`. Always return a dense copy.
        out = Vector{Any}(undef, length(vec))
        @inbounds for i in eachindex(vec)
            out[i] = _json_safe_vector_get(vec, i)
        end
        return out
    end

    """Read `parent.sub_key.leaf_key` as `Float64` without going through `getproperty(::JsonObj)::Any` chains."""
    function _scene_f64(parent::JsonObj, sub_key::String, leaf_key::String, default::Float64)::Float64
        sub = _json_field(parent, sub_key)
        sub === nothing && return default
        inner = @_coerce_jsonobj_row sub
        return _to_f64(_json_field(inner, leaf_key), default)
    end

    """Read `parent.sub_key.leaf_key` as `Int` without going through `getproperty(::JsonObj)::Any` chains."""
    function _scene_int(parent::JsonObj, sub_key::String, leaf_key::String, default::Int)::Int
        sub = _json_field(parent, sub_key)
        sub === nothing && return default
        inner = @_coerce_jsonobj_row sub
        return _to_int(_json_field(inner, leaf_key), default)
    end

    @Base.noinline function _vec2f_from_json(c::JsonObj, sub_key::String, def_x::Float64, def_y::Float64)::Math._Vector2{Float64}
        xf = _scene_f64(c, sub_key, "x", def_x)
        yf = _scene_f64(c, sub_key, "y", def_y)
        return Math._Vector2{Float64}(xf, yf)
    end

    """Integer `Vector2` from `sub_key.{x,y}` for UI scene JSON (JuliaC `--trim`, avoids `get(::Any,...)` and `Vector2::Any`)."""
    @Base.noinline function _ui_vec2i_from_json(o::JsonObj, sub_key::String, def::Math._Vector2{Int32})::Math._Vector2{Int32}
        Math._Vector2{Int32}(
            Int32(_scene_int(o, sub_key, "x", Int(def.x))),
            Int32(_scene_int(o, sub_key, "y", Int(def.y))),
        )
    end

    @Base.noinline function _ui_screen_button_font_path(o::JsonObj)::Union{String, Ptr{Nothing}}
        v = _json_field(o, "fontPath")
        v === nothing && return C_NULL
        v === C_NULL && return C_NULL
        v isa String && return v
        v isa Ptr{Nothing} && return v
        v isa Symbol && return String(v)
        v isa AbstractString && return v === "" ? "" : String(copy(v))  # avoid `Base.string(::AbstractString)` under trim
        return C_NULL
    end

    @Base.noinline function _ui_named_color_rgba_tuple(color_o::JsonObj)::NTuple{4, Int}
        (
            _to_int(_json_field(color_o, "r"), 255),
            _to_int(_json_field(color_o, "g"), 255),
            _to_int(_json_field(color_o, "b"), 255),
            _to_int(_json_field(color_o, "a"), 255),
        )
    end

    """RGBA from UI JSON `color` / `borderColor` with keys `"1"`..`"4"` or a dict; unknown `c` returns white/opaque."""
    function _ui_rgba_tuple_from_color_field(c)::NTuple{4, Int}
        if c isa JsonObj
            return (
                _to_int(_json_field(c, "1"), 255),
                _to_int(_json_field(c, "2"), 255),
                _to_int(_json_field(c, "3"), 255),
                _to_int(_json_field(c, "4"), 255),
            )
        end
        if c isa AbstractDict
            d = c
            return (
                Int(_to_int(Base.get(d, "1", 255), 255)),
                Int(_to_int(Base.get(d, "2", 255), 255)),
                Int(_to_int(Base.get(d, "3", 255), 255)),
                Int(_to_int(Base.get(d, "4", 255), 255)),
            )
        end
        return (255, 255, 255, 255)
    end

    # JuliaC `--trim` often cannot resolve `Base.get` / `Base.haskey` on `JsonObj` when added via extension in this module.
    @Base.noinline function _scene_json_haskey(o::JsonObj, k::AbstractString)::Bool
        ks = string(k)
        return Base.haskey(getfield(o, :d)::Dict{String,Any}, ks)
    end

    @Base.noinline function _scene_json_get(o::JsonObj, k::AbstractString, default)
        ks = string(k)
        d = getfield(o, :d)::Dict{String,Any}
        if !Base.haskey(d, ks)
            return default
        end
        return @_unwrap_scene_field_value d[ks]
    end

    function Base.getproperty(o::JsonObj, k::Symbol)
        k === :d && return getfield(o, :d)
        d = getfield(o, :d)::Dict{String,Any}
        ks = string(k)
        raw = Base.haskey(d, ks) ? d[ks] : nothing
        raw === nothing && return nothing
        return @_unwrap_scene_field_value raw
    end

    Base.haskey(o::JsonObj, k::AbstractString) = _scene_json_haskey(o, k)

    function Base.get(o::JsonObj, k::AbstractString, default)
        return _scene_json_get(o, k, default)
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
    @Base.noinline function _as_scene_json_root(x)
        x isa JsonObj && return x
        x isa JSON3.Object && return JsonObj(ccall(:jl_call1, Any, (Any, Any), _json3_object_to_string_dict_body, x::JSON3.Object)::Dict{String,Any})
        x isa Dict{String,Any} && return JsonObj(x::Dict{String,Any})
        x isa Dict{Symbol,Any} && return JsonObj(_symbol_dict_to_stringkey_tree(x::Dict{Symbol,Any}))
        if x isa AbstractDict && !(x isa JsonObj)
            ad = x::AbstractDict
            ad isa Dict{String,Any} && return JsonObj(ad::Dict{String,Any})
            ad isa Dict{Symbol,Any} && return JsonObj(_symbol_dict_to_stringkey_tree(ad::Dict{Symbol,Any}))
            ad isa JSON3.Object && return JsonObj(ccall(:jl_call1, Any, (Any, Any), _json3_object_to_string_dict_body, ad::JSON3.Object)::Dict{String,Any})
            return JsonObj(Dict{String,Any}())
        end
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
                    root = JsonObj(ccall(:jl_call1, Any, (Any, Any), _json3_object_to_string_dict_body, cached_json::JSON3.Object)::Dict{String,Any})
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
            entities_json = _json_obj_array(root, "Entities")
            for ie in eachindex(entities_json)
                _scene_vector_slot_assigned(entities_json, ie) || continue
                entity = entities_json[ie]
                entity_id = _json_string(entity, "id", "")
                if entity_id in entityIdsInCurrentScene
                    @debug "Entity with id $(entity_id) already exists in current scene"
                    continue
                end
                components = Any[]
    
                components_raw = _json_obj_array(entity, "components")
                for ic in eachindex(components_raw)
                    _scene_vector_slot_assigned(components_raw, ic) || continue
                    component = components_raw[ic]
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
                newEntity.isActive = _to_bool(_json_field(entity, "isActive"), true)
                # Script entries are plain `Dict`/`Vector` after `JsonObj` normalization (see `SceneReaderModule.JsonObj`).
                newEntity.scripts = _json_any_array(entity, "scripts")
                newEntity.persistentBetweenScenes = _to_bool(_json_field(entity, "persistentBetweenScenes"), false)

                for icp in eachindex(components)
                    _scene_vector_slot_assigned(components, icp) || continue
                    component = components[icp]
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

            for ient in eachindex(entities)
                _scene_vector_slot_assigned(entities, ient) || continue
                entity = entities[ient]
                if Base.haskey(childParentDict, string(entity.id))
                    parentId::String = childParentDict[string(entity.id)]
                    for je in eachindex(entities)
                        _scene_vector_slot_assigned(entities, je) || continue
                        e = entities[je]
                        if string(e.id) == parentId
                            entity.parent = e
                        end
                    end
                end
            end
            ui_raw = _json_obj_array(root, "UIElements")
            uiElements = deserialize_ui_elements(ui_raw, entities)
            camera = Camera(
                Math._Vector2{Int32}(500, 500),
                Math._Vector3{Float64}(0.0, 0.0, 0.0),
                Math._Vector2{Float64}(0.0, 0.0),
                C_NULL)
            cam_raw = _json_field(root, "Camera")
            if cam_raw !== nothing
                # JuliaC `--trim`: read camera fields via concrete `_scene_*` helpers instead of property
                # syntax (`cam.size.x`, `cam.backgroundColor.r`, ...) so the verifier doesn't walk a stack of
                # `getproperty(::JsonObj, ...)::Any` calls (was verifier #343–#380).
                cam = @_coerce_jsonobj_row cam_raw
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
                zraw = _json_field(cam, "zoom")
                if zraw !== nothing
                    camera.zoom = _to_f64(zraw, 1.0)
                end
            end

            return (entities, uiElements, camera)
        catch e 
            #Base.show_backtrace(Core.stderr, catch_backtrace())
            @error sprint(showerror, e)
            return nothing
        end
    end

    function deserialize_ui_elements(jsonUIElements::Vector{JsonObj}, entities)
        res = JulGame.IUIElement[]
        childParentDict = Dict{String,String}()
        uiElementsById = Dict{String, JulGame.IUIElement}()
        entitiesById = Dict{String, Entity}()
        for ie in eachindex(entities)
            _scene_vector_slot_assigned(entities, ie) || continue
            e = entities[ie]
            entitiesById[string(e.id)] = e
        end
        default_Vector2 = Math._Vector2{Int32}(0, 0)
        for iu in eachindex(jsonUIElements)
            _scene_vector_slot_assigned(jsonUIElements, iu) || continue
            uiElement = jsonUIElements[iu]
            try
                ty = _json_string(uiElement, "type", "")
                newUIElement = nothing
                if _scene_json_haskey(uiElement, "parent") && _json_string(uiElement, "parent", "") != ""
                    childParentDict[_json_string(uiElement, "id", "")] = _json_string(uiElement, "parent", "")
                end
                if ty == "Canvas"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 100)
                    if _scene_json_haskey(uiElement, "color")
                        color_o = @_coerce_jsonobj_row(_json_field(uiElement, "color"))
                        if _scene_json_haskey(color_o, "r") && _scene_json_haskey(color_o, "g") && _scene_json_haskey(color_o, "b") && _scene_json_haskey(color_o, "a")
                            color_tuple = _ui_named_color_rgba_tuple(color_o)
                        end
                    end

                    newUIElement = JulGame.UI.CanvasModule.Canvas(
                        id = _json_string(uiElement, "id", string(JulGame.generate_uuid())),
                        name = _json_string(uiElement, "name", "Canvas"),
                        anchor = Symbol(_json_string(uiElement, "anchor", "none")),
                        anchorOffset = _ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        isWorldEntity = _to_bool(_scene_json_get(uiElement, "isWorldEntity", false), false),
                        layer = _to_int(_scene_json_get(uiElement, "layer", 0), 0),
                        position = _ui_vec2i_from_json(uiElement, "position", default_Vector2),
                        size = _ui_vec2i_from_json(uiElement, "size", default_Vector2),
                        isActive = _to_bool(_scene_json_get(uiElement, "isActive", true), true),
                        persistentBetweenScenes = _to_bool(_scene_json_get(uiElement, "persistentBetweenScenes", false), false),
                        color = color_tuple,
                        isVisible = _to_bool(_scene_json_get(uiElement, "isVisible", true), true),
                        clipChildren = _to_bool(_scene_json_get(uiElement, "clipChildren", false), false),
                        rotation = _to_f64(_scene_json_get(uiElement, "rotation", 0.0), 0.0)
                    )
                    
                    ch = _json_obj_array(uiElement, "children")
                    if !isempty(ch)
                        for c in deserialize_canvas_children(ch, newUIElement)
                            el = c::JulGame.IUIElement
                            if el isa JulGame.UI.CanvasModule.Canvas
                                _attach_ui_to_canvas!(newUIElement, el::JulGame.UI.CanvasModule.Canvas)
                            elseif el isa ScreenButton
                                _attach_ui_to_canvas!(newUIElement, el::ScreenButton)
                            elseif el isa TextBox
                                _attach_ui_to_canvas!(newUIElement, el::TextBox)
                            end
                        end
                    end
                elseif ty == "TextBox"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 255)
                    if _scene_json_haskey(uiElement, "color")
                        color_o = @_coerce_jsonobj_row(_json_field(uiElement, "color"))
                        @debug "TextBox color" _json_string(uiElement, "name", "TextBox")
                        color_tuple = _ui_named_color_rgba_tuple(color_o)
                    end

                    newUIElement = TextBox(
                        _json_string(uiElement, "text", " ");
                        id = _json_string(uiElement, "id", string(JulGame.generate_uuid())),
                        name = _json_string(uiElement, "name", "TextBox"),
                        anchor = Symbol(_json_string(uiElement, "anchor", "none")),
                        anchorOffset = _ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        isWorldEntity = _to_bool(_scene_json_get(uiElement, "isWorldEntity", false), false),
                        layer = _to_int(_scene_json_get(uiElement, "layer", 0), 0),
                        position = _ui_vec2i_from_json(uiElement, "position", default_Vector2), 
                        isActive = _to_bool(_scene_json_get(uiElement, "isActive", true), true),
                        persistentBetweenScenes = _to_bool(_scene_json_get(uiElement, "persistentBetweenScenes", false), false),
                        color = color_tuple,
                        fontPath = _json_string(uiElement, "fontPath", "Default"),
                        fontSize = _to_int(_scene_json_get(uiElement, "fontSize", 20), 20),
                        maxLineWidth = _to_int(_scene_json_get(uiElement, "maxLineWidth", 0), 0),
                        wrapWords = _to_bool(_scene_json_get(uiElement, "wrapWords", true), true)
                    )
                elseif ty == "UIImage"
                    color_tuple = (255, 255, 255, 255)
                    if _scene_json_haskey(uiElement, "color")
                        color_tuple = _ui_rgba_tuple_from_color_field(@_coerce_jsonobj_row(_json_field(uiElement, "color")))
                    end
                  
                    newUIElement = UIImage(
                        _json_string(uiElement, "path", "Default");
                        id=_json_string(uiElement, "id", string(JulGame.generate_uuid())),
                        name=_json_string(uiElement, "name", "Image"),
                        anchor=Symbol(_json_string(uiElement, "anchor", "none")),
                        anchorOffset=_ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        layer=_to_int(_scene_json_get(uiElement, "layer", 0), 0),
                        position=_ui_vec2i_from_json(uiElement, "position", default_Vector2),
                        isActive=_to_bool(_scene_json_get(uiElement, "isActive", true), true),
                        persistentBetweenScenes=_to_bool(_scene_json_get(uiElement, "persistentBetweenScenes", false), false),
                        color=color_tuple,
                        size=_ui_vec2i_from_json(uiElement, "size", default_Vector2),
                        parent=nothing,
                        rotation=_to_f64(_scene_json_get(uiElement, "rotation", 0.0), 0.0),
                        # clickEvents=_scene_json_get(uiElement, "clickEvents", Function[]),
                        # hoverEnterEvents=_scene_json_get(uiElement, "hoverEnterEvents", Function[]),
                        # hoverExitEvents=_scene_json_get(uiElement, "hoverExitEvents", Function[]),
                    )
                elseif ty == "Rectangle"
                    color_tuple = (255, 255, 255, 255)
                    if _scene_json_haskey(uiElement, "color")
                        color_tuple = _ui_rgba_tuple_from_color_field(@_coerce_jsonobj_row(_json_field(uiElement, "color")))
                    end
                    borderColor_tuple = (255, 255, 255, 255)
                    if _scene_json_haskey(uiElement, "borderColor")
                        borderColor_tuple = _ui_rgba_tuple_from_color_field(@_coerce_jsonobj_row(_json_field(uiElement, "borderColor")))
                    end
                    newUIElement = JulGame.UI.RectangleModule.Rectangle(;
                        id=_json_string(uiElement, "id", string(JulGame.generate_uuid())),
                        name=_json_string(uiElement, "name", "Rectangle"),
                        anchor=Symbol(_json_string(uiElement, "anchor", "none")),
                        anchorOffset=_ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        isWorldEntity=_to_bool(_scene_json_get(uiElement, "isWorldEntity", false), false),
                        layer=_to_int(_scene_json_get(uiElement, "layer", 0), 0),
                        position=_ui_vec2i_from_json(uiElement, "position", default_Vector2),
                        isActive=_to_bool(_scene_json_get(uiElement, "isActive", true), true),
                        persistentBetweenScenes=_to_bool(_scene_json_get(uiElement, "persistentBetweenScenes", false), false),
                        color=color_tuple,
                        fillMode=_to_bool(_scene_json_get(uiElement, "fillMode", true), true),
                        borderRadius=_to_int(_scene_json_get(uiElement, "borderRadius", 0), 0),
                        borderWidth=_to_int(_scene_json_get(uiElement, "borderWidth", 0), 0),
                        borderColor=borderColor_tuple,
                        size=_ui_vec2i_from_json(uiElement, "size", default_Vector2),
                        parent=nothing,
                        forceClickCheck=_to_bool(_scene_json_get(uiElement, "forceClickCheck", false), false),
                        # clickEvents=_scene_json_get(uiElement, "clickEvents", Function[]),
                        # hoverEnterEvents=_scene_json_get(uiElement, "hoverEnterEvents", Function[]),
                        # hoverExitEvents=_scene_json_get(uiElement, "hoverExitEvents", Function[]),
                    )
                else
                    # For text offset, check if it should be centered (if not specified or all zeros)
                    textOffset = _ui_vec2i_from_json(uiElement, "textOffset", default_Vector2)
                    if !_scene_json_haskey(uiElement, "textOffset") || (textOffset.x == Int32(0) && textOffset.y == Int32(0))
                        # Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = Math._Vector2{Int32}(Int32(-1), Int32(-1))
                    end
                    
                    newUIElement = ScreenButton(
                        nothing; # clickEvent - Assuming none from scene file directly
                        id=_json_string(uiElement, "id", string(JulGame.generate_uuid())),
                        name=_json_string(uiElement, "name", "Button"),
                        anchor=Symbol(_json_string(uiElement, "anchor", "none")),
                        anchorOffset=_ui_vec2i_from_json(uiElement, "anchorOffset", default_Vector2),
                        isWorldEntity=_to_bool(_scene_json_get(uiElement, "isWorldEntity", false), false),
                        layer=_to_int(_scene_json_get(uiElement, "layer", 0), 0),
                        position=_ui_vec2i_from_json(uiElement, "position", default_Vector2),
                        buttonUpSpritePath=_json_string(uiElement, "buttonUpSpritePath", "Default"),
                        buttonDownSpritePath=_json_string(uiElement, "buttonDownSpritePath", "Default"),
                        # hoverEnterEvent=nothing, # Default
                        # hoverExitEvent=nothing, # Default
                        isActive=_to_bool(_scene_json_get(uiElement, "isActive", true), true),
                        persistentBetweenScenes=_to_bool(_scene_json_get(uiElement, "persistentBetweenScenes", false), false),
                        #color=color_tuple,
                        fontPath=_ui_screen_button_font_path(uiElement),
                        fontSize=_to_int(_scene_json_get(uiElement, "fontSize", 24), 24),
                        size=_ui_vec2i_from_json(uiElement, "size", default_Vector2),
                        text=_json_string(uiElement, "text", ""),
                        textOffset=textOffset,
                        # parent=nothing # Default
                    )
                    
                    # Make sure the button is initialized properly - Constructor likely handles this
                end
                currentUIId = _json_string(uiElement, "id", "")
                newUIElement.persistentBetweenScenes = _to_bool(_scene_json_get(uiElement, "persistentBetweenScenes", false), false)
                push!(res, newUIElement)
                if currentUIId != ""
                    uiElementsById[currentUIId] = newUIElement
                end
            catch e 
                @error sprint(showerror, e)
            end
        end

        for (childId, parentRef) in childParentDict
            pref = string(parentRef)
            pref == "" && continue
            split_ref = split(pref, "::")
            length(split_ref) != 2 && continue
            parentKey = String(split_ref[1])
            ptype = String(split_ref[2])
            child = Base.get(uiElementsById, string(childId), Base.nothing)
            child === nothing && continue
            if ptype == "Entity"
                parentEntity = Base.get(entitiesById, parentKey, Base.nothing)
                parentEntity === nothing && continue
                JulGame.UI.add_relationship_if_not_exists(child)
                setfield!(JulGame.UI.relationship_instance(child), :parent, parentEntity)
            else
                parentUI = Base.get(uiElementsById, parentKey, Base.nothing)
                parentUI === nothing && continue
                JulGame.UI.add_relationship_if_not_exists(child)
                setfield!(JulGame.UI.relationship_instance(child), :parent, parentUI)
            end
        end

        return res
    end

    export deserialize_component
    function deserialize_component(component::JsonObj)
        try
            ty = _json_string(component, "type", "")
            local newComponent
            if ty == "Transform"
                newComponent = Transform(
                    _vec2f_from_json(component, "position", 0.0, 0.0),
                    _vec2f_from_json(component, "scale", 1.0, 1.0),
                )
            elseif ty == "Animator"
                newAnimations = Animation[]
                for anim in _json_obj_array(component, "animations")
                    newAnimationFrames = Vector{Math._Vector4{Int32}}()
                    for fr in _json_obj_array(anim, "frames")
                        push!(newAnimationFrames, Math._Vector4{Int32}(
                            Int32(_to_int(_json_field(fr, "x"), 0)),
                            Int32(_to_int(_json_field(fr, "y"), 0)),
                            Int32(_to_int(_json_field(fr, "z"), 0)),
                            Int32(_to_int(_json_field(fr, "t"), 0)),
                        ))
                    end
                    fps = _to_int(_json_field(anim, "animatedFPS"), 0)
                    push!(newAnimations, Animation(newAnimationFrames, fps))
                end
                newComponent = Animator(newAnimations)
            elseif ty == "Collider"
                isTrigger = _to_bool(_json_field(component, "isTrigger"), false)
                enabled = _to_bool(_json_field(component, "enabled"), true)
                isPlatformerCollider = _to_bool(_json_field(component, "isPlatformerCollider"), false)
                offset = _vec2f_from_json(component, "offset", 0.0, 0.0)
                sz = _vec2f_from_json(component, "size", 0.0, 0.0)
                tag = _json_string(component, "tag", "")
                newComponent = Collider(enabled, isPlatformerCollider, isTrigger, offset, sz, tag)
            elseif ty == "CircleCollider"
                newComponent = CircleCollider(
                    _to_f64(_json_field(component, "diameter"), 0.0),
                    _to_bool(_json_field(component, "enabled"), true),
                    _to_bool(_json_field(component, "isTrigger"), false),
                    _vec2f_from_json(component, "offset", 0.0, 0.0),
                    _json_string(component, "tag", "Default"),
                )
            elseif ty == "Rigidbody"
                newComponent = Rigidbody(;
                    mass = _to_f64(_json_field(component, "mass"), 0.0),
                    useGravity = _to_bool(_json_field(component, "useGravity"), true),
                )
            elseif ty == "SoundSource"
                newComponent = SoundSource(
                    _to_int(_json_field(component, "channel"), -1),
                    _to_bool(_json_field(component, "isMusic"), false),
                    _json_string(component, "path", ""),
                    _to_bool(_json_field(component, "playOnStart"), false),
                    _to_int(_json_field(component, "volume"), -1),
                )
            elseif ty == "Sprite"
                color_raw = _json_field(component, "color")
                local color_tup::NTuple{4, Int}
                if color_raw === nothing || color_raw === Base.nothing
                    color_tup = (255, 255, 255, 255)
                else
                    cj = @_coerce_jsonobj_row(color_raw)
                    color_tup = (
                        _to_int(_json_field(cj, "x"), 255),
                        _to_int(_json_field(cj, "y"), 255),
                        _to_int(_json_field(cj, "z"), 255),
                        _to_int(_json_field(cj, "t"), 255),
                    )
                end
                crop_raw = _json_field(component, "crop")
                local crop_v::Math._Vector4{Int32}
                if crop_raw === nothing || crop_raw === Base.nothing
                    crop_v = Math._Vector4{Int32}(Int32(0), Int32(0), Int32(0), Int32(0))
                else
                    cj = @_coerce_jsonobj_row(crop_raw)
                    crop_v = Math._Vector4{Int32}(
                        Int32(_to_int(_json_field(cj, "x"), 0)),
                        Int32(_to_int(_json_field(cj, "y"), 0)),
                        Int32(_to_int(_json_field(cj, "z"), 0)),
                        Int32(_to_int(_json_field(cj, "t"), 0)),
                    )
                end
                layer_i::Int = _to_int(_json_field(component, "layer"), 0)
                offset_v::Math._Vector2{Float64} = _vec2f_from_json(component, "offset", 0.0, 0.0)
                position_v::Math._Vector2{Float64} = _vec2f_from_json(component, "position", 0.0, 0.0)
                rotation_f::Float64 = _to_f64(_json_field(component, "rotation"), 0.0)
                pixels_i::Int = _to_int(_json_field(component, "pixelsPerUnit"), -1)
                center_v::Math._Vector2{Float64} = _vec2f_from_json(component, "center", 0.5, 0.5)
                anchor_sym::Symbol = Symbol(_json_string(component, "anchor", "center"))
                isStatic_b::Bool = _to_bool(_json_field(component, "isStatic"), false)
                isFlipped_b::Bool = _to_bool(_json_field(component, "isFlipped"), false)
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
                color_raw = _json_field(component, "color")
                local color_v::Math._Vector3{Int32}
                if color_raw === nothing || color_raw === Base.nothing
                    color_v = Math._Vector3{Int32}(Int32(255), Int32(255), Int32(255))
                else
                    cj = @_coerce_jsonobj_row(color_raw)
                    color_v = Math._Vector3{Int32}(
                        Int32(_to_int(_json_field(cj, "x"), 255)),
                        Int32(_to_int(_json_field(cj, "y"), 255)),
                        Int32(_to_int(_json_field(cj, "z"), 255)),
                    )
                end
                shape_layer::Int = _to_int(_json_field(component, "layer"), 0)
                size_v::Math._Vector2{Float64} = _vec2f_from_json(component, "size", 1.0, 1.0)
                isFilled_b::Bool = _to_bool(_json_field(component, "isFilled"), true)
                isWorld_b::Bool = _to_bool(_json_field(component, "isWorldEntity"), true)
                shape_offset_v::Math._Vector2{Float64} = _vec2f_from_json(component, "offset", 0.0, 0.0)
                shape_position_v::Math._Vector2{Float64} = _vec2f_from_json(component, "position", 0.0, 0.0)
                alpha_i::Int = _to_int(_json_field(component, "alpha"), 255)
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
    function deserialize_canvas_children(jsonChildren::Vector{JsonObj}, parentCanvas)
        children = JulGame.IUIElement[]
        default_Vector2 = Math._Vector2{Int32}(Int32(0), Int32(0))
        
        for ic in eachindex(jsonChildren)
            _scene_vector_slot_assigned(jsonChildren, ic) || continue
            child = jsonChildren[ic]
            try
                cty = _json_string(child, "type", "")
                newChild = nothing
                if cty == "Canvas"
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 100)
                    if _scene_json_haskey(child, "color")
                        color_o = @_coerce_jsonobj_row(_json_field(child, "color"))
                        if _scene_json_haskey(color_o, "r") && _scene_json_haskey(color_o, "g") && _scene_json_haskey(color_o, "b") && _scene_json_haskey(color_o, "a")
                            color_tuple = _ui_named_color_rgba_tuple(color_o)
                        end
                    end

                    newChild = JulGame.UI.CanvasModule.Canvas(
                        id = _json_string(child, "id", string(JulGame.generate_uuid())),
                        name = _json_string(child, "name", "Canvas"),
                        anchor = Symbol(_json_string(child, "anchor", "none")),
                        anchorOffset = _ui_vec2i_from_json(child, "anchorOffset", default_Vector2),
                        isWorldEntity = _to_bool(_scene_json_get(child, "isWorldEntity", false), false),
                        layer = _to_int(_scene_json_get(child, "layer", 0), 0),
                        position = _ui_vec2i_from_json(child, "position", default_Vector2),
                        size = _ui_vec2i_from_json(child, "size", default_Vector2),
                        isActive = _to_bool(_scene_json_get(child, "isActive", true), true),
                        persistentBetweenScenes = _to_bool(_scene_json_get(child, "persistentBetweenScenes", false), false),
                        color = color_tuple,
                        isVisible = _to_bool(_scene_json_get(child, "isVisible", true), true),
                        clipChildren = _to_bool(_scene_json_get(child, "clipChildren", false), false),
                        rotation = _to_f64(_scene_json_get(child, "rotation", 0.0), 0.0),
                        parent = parentCanvas
                    )
                    
                    gch = _json_obj_array(child, "children")
                    if !isempty(gch)
                        for grandChild in deserialize_canvas_children(gch, newChild)
                            el = grandChild::JulGame.IUIElement
                            if el isa JulGame.UI.CanvasModule.Canvas
                                _attach_ui_to_canvas!(newChild, el::JulGame.UI.CanvasModule.Canvas)
                            elseif el isa ScreenButton
                                _attach_ui_to_canvas!(newChild, el::ScreenButton)
                            elseif el isa TextBox
                                _attach_ui_to_canvas!(newChild, el::TextBox)
                            end
                        end
                    end
                elseif cty == "ScreenButton"
                    # For text offset, check if it should be centered (if not specified or all zeros)
                    textOffset = _ui_vec2i_from_json(child, "textOffset", default_Vector2)
                    if !_scene_json_haskey(child, "textOffset") || (textOffset.x == Int32(0) && textOffset.y == Int32(0))
                        # Use (-1,-1) as a special value to indicate the text should be centered
                        textOffset = Math._Vector2{Int32}(Int32(-1), Int32(-1))
                    end
                    
                    newChild = ScreenButton(
                        nothing; # clickEvent - Assuming none from scene file directly
                        id=_json_string(child, "id", string(JulGame.generate_uuid())),
                        name=_json_string(child, "name", "Button"),
                        anchor=Symbol(_json_string(child, "anchor", "none")),
                        anchorOffset=_ui_vec2i_from_json(child, "anchorOffset", default_Vector2),
                        isWorldEntity=_to_bool(_scene_json_get(child, "isWorldEntity", false), false),
                        layer=_to_int(_scene_json_get(child, "layer", 0), 0),
                        position=_ui_vec2i_from_json(child, "position", default_Vector2),
                        buttonUpSpritePath=_json_string(child, "buttonUpSpritePath", "Default"),
                        buttonDownSpritePath=_json_string(child, "buttonDownSpritePath", "Default"),
                        isActive=_to_bool(_scene_json_get(child, "isActive", true), true),
                        persistentBetweenScenes=_to_bool(_scene_json_get(child, "persistentBetweenScenes", false), false),
                        fontPath=_ui_screen_button_font_path(child),
                        fontSize=_to_int(_scene_json_get(child, "fontSize", 24), 24),
                        size=_ui_vec2i_from_json(child, "size", default_Vector2),
                        text=_json_string(child, "text", ""),
                        textOffset=textOffset,
                        parent = parentCanvas
                    )
                else
                    # TextBox
                    # Parse color, default to white if not present or malformed
                    color_tuple = (255, 255, 255, 255)
                    if _scene_json_haskey(child, "color")
                        color_o = @_coerce_jsonobj_row(_json_field(child, "color"))
                        if _scene_json_haskey(color_o, "r") && _scene_json_haskey(color_o, "g") && _scene_json_haskey(color_o, "b") && _scene_json_haskey(color_o, "a")
                            color_tuple = _ui_named_color_rgba_tuple(color_o)
                        end
                    end

                    newChild = TextBox(
                        _json_string(child, "text", " ");
                        id = _json_string(child, "id", string(JulGame.generate_uuid())),
                        name = _json_string(child, "name", "TextBox"),
                        anchor = Symbol(_json_string(child, "anchor", "none")),
                        anchorOffset = _ui_vec2i_from_json(child, "anchorOffset", default_Vector2),
                        isWorldEntity = _to_bool(_scene_json_get(child, "isWorldEntity", false), false),
                        layer = _to_int(_scene_json_get(child, "layer", 0), 0),
                        position = _ui_vec2i_from_json(child, "position", default_Vector2), 
                        isActive = _to_bool(_scene_json_get(child, "isActive", true), true),
                        persistentBetweenScenes = _to_bool(_scene_json_get(child, "persistentBetweenScenes", false), false),
                        color = color_tuple,
                        fontPath = _json_string(child, "fontPath", "Default"),
                        fontSize = _to_int(_scene_json_get(child, "fontSize", 20), 20),
                        maxLineWidth = _to_int(_scene_json_get(child, "maxLineWidth", 0), 0),
                        wrapWords = _to_bool(_scene_json_get(child, "wrapWords", true), true),
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
