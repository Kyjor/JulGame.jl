abstract type UIElement <: JulGame.IUIElement end

@inline function _latency_profiler_active()::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler}
    JulGame.MAIN === nothing && return nothing
    ml = JulGame.current_main()
    prof = ml.latencyProfiler
    (prof !== nothing && prof.enabled) || return nothing
    return prof
end

@inline function _latency_ui_hit_ms!(prof::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler}, t0::UInt64, key::Symbol)
    prof === nothing && return
    dt = (time_ns() - t0) / 1e6
    JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_ms!(prof, key, dt)
end

@inline function _latency_ui_hit_count!(prof::Union{Nothing, JulGame.Diagnostics.LatencyProfilerModule.LatencyProfiler}, key::Symbol, n::Int = 1)
    prof === nothing && return
    JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_count!(prof, key, n)
end

mutable struct UIElementInstance
    # identifiers
    id::String
    name::String

    # positioning
    anchor::Union{JulGame.Enum, Nothing}
    anchorOffset::Vector2
    isWorldEntity::Bool
    layer::Int
    parent::Union{JulGame.IUIElement, Nothing, JulGame.IEntity, JulGame.ISprite}
    position::Vector2
    rotation::Float64
    size::Vector2
    originalSize::Vector2

    # events
    clickEvents::Vector{Function}
    hoverEnterEvents::Vector{Function}
    hoverExitEvents::Vector{Function}
    forceClickCheck::Bool

    # state
    isActive::Bool
    isHovered::Bool
    persistentBetweenScenes::Bool
    
    # rendering
    color::NTuple{4, Int}
    
    
    function UIElementInstance()
        this = new()

        this.clickEvents = Function[]
        this.hoverEnterEvents = Function[]
        this.hoverExitEvents = Function[]
        this.forceClickCheck = false
        
        return this
    end
end

const _ui_relationships_by_objectid = Dict{UInt, UIElementInstance}()

"""Ensure and return the `UIElementInstance` for `ui` (JuliaC `--trim`: keys are `UInt` object ids)."""
@inline function relationship_instance(ui::JulGame.IUIElement)::UIElementInstance
    oid = Base.objectid(ui)::UInt
    return get!(_ui_relationships_by_objectid, oid) do
        UIElementInstance()
    end::UIElementInstance
end

# Input hit-test helpers: getfield/setfield paths for JuliaC --trim (avoid IUIElement getproperty in Input).
function input_ui_is_active(ui::JulGame.IUIElement)::Bool
    add_relationship_if_not_exists(ui)
    return getfield(relationship_instance(ui), :isActive)::Bool
end

"""Layer for immediate UI / render ordering (relationship dict; avoids `getproperty` on `IUIElement`)."""
@inline function input_ui_layer(ui::JulGame.IUIElement)::Int
    add_relationship_if_not_exists(ui)
    return getfield(relationship_instance(ui), :layer)::Int
end

"""Position for input hit-tests (`getfield` on relationship; JuliaC `--trim`)."""
@inline function input_ui_position(ui::JulGame.IUIElement)::JulGame.Math._Vector2{Int32}
    add_relationship_if_not_exists(ui)
    return getfield(relationship_instance(ui), :position)::JulGame.Math._Vector2{Int32}
end

"""Size for input hit-tests (`getfield` on relationship; JuliaC `--trim`)."""
@inline function input_ui_size(ui::JulGame.IUIElement)::JulGame.Math._Vector2{Int32}
    add_relationship_if_not_exists(ui)
    return getfield(relationship_instance(ui), :size)::JulGame.Math._Vector2{Int32}
end

function input_ui_force_click_check(ui::JulGame.IUIElement)::Bool
    add_relationship_if_not_exists(ui)
    return getfield(relationship_instance(ui), :forceClickCheck)::Bool
end

function input_ui_name(ui::JulGame.IUIElement)::String
    add_relationship_if_not_exists(ui)
    return getfield(relationship_instance(ui), :name)::String
end

function input_ui_is_hovered(ui::JulGame.IUIElement)::Bool
    add_relationship_if_not_exists(ui)
    inst = relationship_instance(ui)
    if getfield(inst, :isActive) == false
        return false
    end
    return getfield(inst, :isHovered)::Bool
end

function _input_ui_set_isHovered_inner!(ui::JulGame.IUIElement, value::Bool)::Nothing
    add_relationship_if_not_exists(ui)
    inst = relationship_instance(ui)
    prev = getfield(inst, :isHovered)
    setfield!(inst, :isHovered, value)
    if prev != value
        UI.handle_hover_event(ui, value)
    end
    return nothing
end

function input_ui_set_isHovered!(ui::JulGame.IUIElement, value::Bool)::Nothing
    _input_ui_set_isHovered_inner!(ui, value)
end

function sort_reversed_ui_by_layer_for_input(v::Vector{JulGame.IUIElement})::Vector{JulGame.IUIElement}
    n = length(v)
    n == 0 && return JulGame.IUIElement[]
    out = Vector{JulGame.IUIElement}(undef, n)
    @inbounds for k in 1:n
        out[k] = v[n - k + 1]
    end
    @inbounds for i in 2:n
        cur = out[i]
        add_relationship_if_not_exists(cur)
        cl = getfield(relationship_instance(cur), :layer)::Int
        j = i
        while j > 1
            prev = out[j - 1]
            add_relationship_if_not_exists(prev)
            pl = getfield(relationship_instance(prev), :layer)::Int
            pl < cl || break
            out[j] = out[j - 1]
            j -= 1
        end
        out[j] = cur
    end
    return out
end

function Base.getproperty(script::JulGame.IUIElement, property::Symbol)
    # Check if the relationship exists
    add_relationship_if_not_exists(script)
    rinst = relationship_instance(script)

    if hasfield(UIElementInstance, property)
        #println("getproperty from parent: $(property) ")
        if property == :isHovered && getfield(rinst, :isActive) == false
            return false
        end
        return getfield(rinst, property)
    end

    #println("getproperty from child: $(property) ")
    try
        return getfield(script, property)
    catch e
        @warn "Error getting property $(property) for $(script): $(e)"
        return nothing
    end
end

function Base.setproperty!(script::JulGame.IUIElement, property::Symbol, value)
    add_relationship_if_not_exists(script)
    rinst = relationship_instance(script)

    if hasfield(UIElementInstance, property) # this is the child type TextBox, Rectangle, etc
        #println("setproperty! from parent: $(property) ")
        if property == :isHovered
            inst = rinst
            prof = _latency_profiler_active()
            t_rw = time_ns()
            prev = getfield(inst, :isHovered)
            setfield!(inst, property, value)
            _latency_ui_hit_ms!(prof, t_rw, :hover_set_isHovered_field_rw)
            if prev != value
                UI.handle_hover_event(script, value)
                _latency_ui_hit_count!(prof, :hover_set_isHovered_dispatch_calls, 1)
            else
                _latency_ui_hit_count!(prof, :hover_set_isHovered_skip_dispatch_same_value, 1)
            end
        else
            setfield!(rinst, property, value)
        end
    else # this is the parent type UIElement
        #println("setproperty! from child: $(property) ")
        setfield!(script, property, value)
    end


    if contains("$(typeof(script))", "TextBox")
        @debug "rerendering text for $(script)"
        if property == :text || property == :isActive || property == :textColor || property == :maxLineWidth || property == :wrapWords || property == :fontSize || property == :color
            #= if s == :text && length(x) == 0
                setfield!(this, s, " ")# prevents segfault when text is empty
            end =#
            if script.isConstructed
                @debug("rerendering text for $(script.name) because of $(property) = $(value)")
                UI.rerender_text(script) # this line MUST stay inside the if for specific fields as we can't call this on fields that are used in this function
            end
        end
    end
end

@inline function add_relationship_if_not_exists(script::JulGame.IUIElement)::Nothing
    relationship_instance(script)
    return nothing
end

function delete_relationship(script::JulGame.IUIElement)
    delete!(_ui_relationships_by_objectid, Base.objectid(script)::UInt)
end

function UI.set_color(this::JulGame.IUIElement; r::Int=255, g::Int=255, b::Int=255, a::Int=255)
    this.color = (r%256, g%256, b%256, a%256)
end

@inline function _align_set_position_cells!(tinst::UIElementInstance, x::Float64, y::Float64)::Nothing
    nx = round(Int32, x)
    ny = round(Int32, y)
    setfield!(tinst, :position, JulGame.Math._Vector2{Int32}(nx, ny))
    return nothing
end

function UI.align_to_anchor(this::JulGame.IUIElement)::Nothing
    main = JulGame.current_main()
    sc = getfield(main, :scene)
    cam = getfield(sc, :camera)
    if cam === nothing
        @debug "No camera found in scene"
        return nothing
    end

    add_relationship_if_not_exists(this)
    tinst = relationship_instance(this)
    tw = getfield(tinst, :size)::JulGame.Math._Vector2{Int32}
    thx = getfield(tw, :x)::Int32
    thy = getfield(tw, :y)::Int32
    tao = getfield(tinst, :anchorOffset)::JulGame.Math._Vector2{Int32}
    t_aox = Float64(getfield(tao, :x)::Int32)
    t_aoy = Float64(getfield(tao, :y)::Int32)
    anch = getfield(tinst, :anchor)
    if anch === nothing
        try
            anch = getfield(this, :anchor)::JulGame.Enum{Any}
        catch
            @debug "align_to_anchor: missing anchor on $(getfield(tinst, :name)::String)"
            return nothing
        end
    end
    cur = getfield(anch::JulGame.Enum{Any}, :current_state)::Symbol

    sx::Float64
    sy::Float64
    ox::Float64
    oy::Float64
    par = getfield(tinst, :parent)
    if par === nothing
        cam_sz = getfield(cam, :size)::JulGame.Math._Vector2{Int32}
        sx = Float64(getfield(cam_sz, :x)::Int32)
        sy = Float64(getfield(cam_sz, :y)::Int32)
        ox = 0.0
        oy = 0.0
    elseif par isa JulGame.IUIElement
        add_relationship_if_not_exists(par)
        pinst = relationship_instance(par)
        p_sz = getfield(pinst, :size)::JulGame.Math._Vector2{Int32}
        p_pos = getfield(pinst, :position)::JulGame.Math._Vector2{Int32}
        sx = Float64(getfield(p_sz, :x)::Int32)
        sy = Float64(getfield(p_sz, :y)::Int32)
        ox = Float64(getfield(p_pos, :x)::Int32)
        oy = Float64(getfield(p_pos, :y)::Int32)
    elseif hasfield(typeof(par), :lastRenderedScreenSize) && hasfield(typeof(par), :lastRenderedScreenPosition)
        lrs = getfield(par, :lastRenderedScreenSize)
        lrp = getfield(par, :lastRenderedScreenPosition)
        if lrs === nothing || lrp === nothing
            @debug "No last rendered screen size or position found for parent of $(getfield(tinst, :name)::String)"
            return nothing
        end
        lrsf = lrs::JulGame.Math._Vector2{Float64}
        lrpf = lrp::JulGame.Math._Vector2{Float64}
        sx = getfield(lrsf, :x)::Float64
        sy = getfield(lrsf, :y)::Float64
        ox = getfield(lrpf, :x)::Float64
        oy = getfield(lrpf, :y)::Float64
    else
        @debug "align_to_anchor: parent type has no layout for $(getfield(tinst, :name)::String)"
        return nothing
    end

    fx = Float64(thx)
    fy = Float64(thy)

    if cur === :center
        _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
    elseif cur === :top
        _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + t_aoy)
    elseif cur === :bottom
        _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + sy - fy + t_aoy)
    elseif cur === :left
        _align_set_position_cells!(tinst, ox + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
    elseif cur === :right
        _align_set_position_cells!(tinst, ox + sx - fx + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
    elseif cur === :topLeft
        _align_set_position_cells!(tinst, ox + t_aox, oy + t_aoy)
    elseif cur === :topRight
        _align_set_position_cells!(tinst, ox + sx - fx + t_aox, oy + t_aoy)
    elseif cur === :bottomLeft
        _align_set_position_cells!(tinst, ox + t_aox, oy + sy - fy + t_aoy)
    elseif cur === :bottomRight
        _align_set_position_cells!(tinst, ox + sx - fx + t_aox, oy + sy - fy + t_aoy)
    elseif cur === :centerLeft
        _align_set_position_cells!(tinst, ox + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
    elseif cur === :centerRight
        _align_set_position_cells!(tinst, ox + sx - fx + t_aox, oy + sy / 2.0 - fy / 2.0 + t_aoy)
    elseif cur === :centerTop
        _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + t_aoy)
    elseif cur === :centerBottom
        _align_set_position_cells!(tinst, ox + sx / 2.0 - fx / 2.0 + t_aox, oy + sy - fy + t_aoy)
    elseif cur === :none
        @debug "No anchor set for textbox $(getfield(tinst, :name)::String)"
    else
        @error "Invalid anchor state: $(cur)"
    end
    return nothing
end

function UI.add_hover_enter_event(this::JulGame.IUIElement, event)
    push!(this.hoverEnterEvents, event)
end

function UI.add_hover_exit_event(this::JulGame.IUIElement, event)
    push!(this.hoverExitEvents, event)
end

# `handle_event` methods for `IUIElement` / `IEntity` live in `InputEventDispatch.jl` (included after `ScreenButton.jl`).

function UI.handle_hover_event(this::JulGame.IUIElement, isEntering::Bool)
    prof = _latency_profiler_active()
    add_relationship_if_not_exists(this)
    inst = relationship_instance(this)
    events = (isEntering ? getfield(inst, :hoverEnterEvents) : getfield(inst, :hoverExitEvents))::Vector{Function}
    t0 = time_ns()
    for event in events
        try Base.invokelatest(event)
        catch e
            @error "Error calling hover event: $(e)"
        end
    end
    key = isEntering ? :hover_dispatch_enter_invocations : :hover_dispatch_exit_invocations
    _latency_ui_hit_ms!(prof, t0, key)
end