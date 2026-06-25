abstract type UIElement <: JulGame.IUIElement end

@inline function _latency_profiler_active()
    m = JulGame.MAIN
    (m !== nothing && m.latencyProfiler !== nothing && m.latencyProfiler.enabled) || return nothing
    return m.latencyProfiler
end

@inline function _latency_ui_hit_ms!(prof, t0::UInt64, key::Symbol)
    prof === nothing && return
    dt = (time_ns() - t0) / 1e6
    JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_ms!(prof, key, dt)
end

@inline function _latency_ui_hit_count!(prof, key::Symbol, n::Int = 1)
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

relationships = Dict{JulGame.IUIElement, UIElementInstance}()

function Base.getproperty(script::JulGame.IUIElement, property::Symbol)
    # Check if the relationship exists
    add_relationship_if_not_exists(script)

    if hasfield(typeof(relationships[script]), property)
        #println("getproperty from parent: $(property) ")
        if property == :isHovered && getfield(relationships[script], :isActive) == false
            return false
        end
        return getfield(relationships[script], property)
    end

    #println("getproperty from child: $(property) ")
    try
        return getfield(script, property)
    catch e
        @warn "Error getting property $(property) for $(script): $(e)"
        Base.show_backtrace(stderr, catch_backtrace())
        return nothing
    end
end

function Base.setproperty!(script::JulGame.IUIElement, property::Symbol, value)
    add_relationship_if_not_exists(script)

    if hasfield(typeof(relationships[script]), property) # this is the child type TextBox, Rectangle, etc
        #println("setproperty! from parent: $(property) ")
        if property == :isHovered
            inst = relationships[script]
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
            setfield!(relationships[script], property, value)
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

function add_relationship_if_not_exists(script::JulGame.IUIElement)
    if !haskey(relationships, script)
        #println("Adding relationship for $(script)")
        relationships[script] = UIElementInstance()
        return
    end
    #println("Relationship already exists for $(script)")
end

function delete_relationship(script::JulGame.IUIElement)
    if haskey(relationships, script)
        delete!(relationships, script)
    end
end

function UI.set_color(this::JulGame.IUIElement; r::Int=255, g::Int=255, b::Int=255, a::Int=255)
    this.color = (r%256, g%256, b%256, a%256)
end

function UI.align_to_anchor(this::JulGame.IUIElement)
    if MAIN.scene.camera === nothing
        @debug "No camera found in scene"
        return
    end

    size = MAIN.scene.camera.size
    parent_pos = Math.Vector2(0, 0)
    if this.parent !== nothing 
        if isa(this.parent, JulGame.IUIElement)
            size = this.parent.size
            parent_pos = this.parent.position
        else 
            if this.parent.lastRenderedScreenSize === nothing || this.parent.lastRenderedScreenPosition === nothing
                @debug "No last rendered screen size or position found for parent of $(this.name)"
                return
            end
            size = this.parent.lastRenderedScreenSize
            parent_pos = this.parent.lastRenderedScreenPosition
        end
    end

    if this.anchor.current_state == :center
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )  
    elseif this.anchor.current_state == :top
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :bottom
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :left
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :right
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :topLeft
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :topRight
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :bottomLeft
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :bottomRight
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerLeft
        this.position = Math.Vector2(
            parent_pos.x + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerRight
        this.position = Math.Vector2(
            parent_pos.x + size.x - this.size.x + this.anchorOffset.x, 
            parent_pos.y + size.y/2 - this.size.y/2 + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerTop
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :centerBottom
        this.position = Math.Vector2(
            parent_pos.x + size.x/2 - this.size.x/2 + this.anchorOffset.x, 
            parent_pos.y + size.y - this.size.y + this.anchorOffset.y
        )
    elseif this.anchor.current_state == :none
        #@debug "No anchor set for textbox $(this.name)"
    else
        @error "Invalid anchor state: $(this.anchor.current_state)"
    end
end

function UI.add_hover_enter_event(this::JulGame.IUIElement, event)
    push!(this.hoverEnterEvents, event)
end

function UI.add_hover_exit_event(this::JulGame.IUIElement, event)
    push!(this.hoverExitEvents, event)
end

function UI.handle_event(this::Union{JulGame.IUIElement, JulGame.IEntity}, evt, x, y)
    prof = _latency_profiler_active()
    t = time_ns()
    isScreenButton = "$(split(string(typeof(this)), ".")[end])" == "ScreenButton"
    _latency_ui_hit_ms!(prof, t, :ui_handle_evt_preamble_typecheck)
    t = time_ns()
    if evt.type == evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        if isScreenButton
            this.currentTexture = this.buttonDownTexture
        end
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_button_down)
    elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
        @debug "Mouse button up at $(x), $(y)"
        if isScreenButton
            this.currentTexture = this.buttonUpTexture
        end
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_button_up_setup)
        t_cb = time_ns()
        for eventToCall in this.clickEvents
            try
                Base.invokelatest(eventToCall,(evt = evt, x = x, y = y))
            catch e
                Base.invokelatest(eventToCall)
            end
        end
        _latency_ui_hit_ms!(prof, t_cb, :ui_handle_evt_mouse_button_up_click_callbacks)
    elseif evt.type == SDL2.SDL_MOUSEMOTION
        if this.isHovered == false
            this.isHovered = true
        end
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_motion)
    end
end

function UI.handle_hover_event(this::JulGame.IUIElement, isEntering::Bool)
    prof = _latency_profiler_active()
    events = isEntering ? this.hoverEnterEvents : this.hoverExitEvents
    t0 = time_ns()
    for event in events
        try
            Base.invokelatest(event)
        catch e
            @error "Error calling hover event: $(e)"
            Base.show_backtrace(stdout, catch_backtrace())
        end
    end
    key = isEntering ? :hover_dispatch_enter_invocations : :hover_dispatch_exit_invocations
    _latency_ui_hit_ms!(prof, t0, key)
end