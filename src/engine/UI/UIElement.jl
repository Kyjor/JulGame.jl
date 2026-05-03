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

    # positioning (JuliaC `--trim`: use `Math._Vector2{Int32}`; `Vector2` alias becomes `JulGame.UI.Vector2::Any` here.)
    anchor::Union{JulGame.Enum, Nothing}
    anchorOffset::JulGame.Math._Vector2{Int32}
    isWorldEntity::Bool
    layer::Int
    parent::Union{JulGame.IUIElement, Nothing, JulGame.IEntity, JulGame.ISprite}
    position::JulGame.Math._Vector2{Int32}
    rotation::Float64
    size::JulGame.Math._Vector2{Int32}
    originalSize::JulGame.Math._Vector2{Int32}

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

        this.id = ""
        this.name = ""
        this.anchor = nothing
        z = JulGame.Math._Vector2{Int32}(Int32(0), Int32(0))
        this.anchorOffset = z
        this.isWorldEntity = false
        this.layer = 0
        this.parent = nothing
        this.position = z
        this.rotation = 0.0
        this.size = z
        this.originalSize = z
        this.clickEvents = Function[]
        this.hoverEnterEvents = Function[]
        this.hoverExitEvents = Function[]
        this.forceClickCheck = false
        this.isActive = true
        this.isHovered = false
        this.persistentBetweenScenes = false
        this.color = (255, 255, 255, 255)

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

function UI.add_hover_enter_event(this::JulGame.IUIElement, event)
    push!(this.hoverEnterEvents, event)
end

function UI.add_hover_exit_event(this::JulGame.IUIElement, event)
    push!(this.hoverExitEvents, event)
end

# `handle_event` methods for `IUIElement` / `IEntity` live in `InputEventDispatch.jl` (included after `ScreenButton.jl`).

@Base.noinline function _ui_invoke_hover_exit_enter_callbacks!(events::Vector{Function})::Nothing
    for event in events
        try
            JulGame.trim_call0(event::Function)
        catch e
            @error "Error calling hover event: $(e)"
        end
    end
    return nothing
end

function UI.handle_hover_event(this::JulGame.IUIElement, isEntering::Bool)
    prof = _latency_profiler_active()
    add_relationship_if_not_exists(this)
    inst = relationship_instance(this)
    events = (isEntering ? getfield(inst, :hoverEnterEvents) : getfield(inst, :hoverExitEvents))::Vector{Function}
    t0 = time_ns()
    _ui_invoke_hover_exit_enter_callbacks!(events)
    key = isEntering ? :hover_dispatch_enter_invocations : :hover_dispatch_exit_invocations
    _latency_ui_hit_ms!(prof, t0, key)
end