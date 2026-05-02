# Mouse/input dispatch for UI. Loaded after `ScreenButton.jl` so `ScreenButtonModule` resolves
# and JuliaC `--trim` can use concrete `isa` branches.

@inline function _ui_run_click_event_callbacks!(inst::UIElementInstance, evt, x, y)::Nothing
    evs = getfield(inst, :clickEvents)::Vector{Function}
    for eventToCall in evs
        try
            Base.invokelatest(eventToCall, (evt = evt, x = x, y = y))
        catch
            Base.invokelatest(eventToCall)
        end
    end
    return nothing
end

@inline function _ui_motion_set_hovered!(this::JulGame.IUIElement)::Nothing
    inst = relationship_instance(this)
    getfield(inst, :isHovered)::Bool && return nothing
    prof = _latency_profiler_active()
    t_rw = time_ns()
    prev = getfield(inst, :isHovered)::Bool
    setfield!(inst, :isHovered, true)
    _latency_ui_hit_ms!(prof, t_rw, :hover_set_isHovered_field_rw)
    prev == true && return nothing
    t0 = time_ns()
    events = getfield(inst, :hoverEnterEvents)::Vector{Function}
    for event in events
        try Base.invokelatest(event)
        catch e
            @error "Error calling hover event: $(e)"
        end
    end
    _latency_ui_hit_ms!(prof, t0, :hover_dispatch_enter_invocations)
    return nothing
end

function UI.handle_event(this::JulGame.IUIElement, evt, x, y)
    prof = _latency_profiler_active()
    t = time_ns()
    inst = relationship_instance(this)
    isScreenButton = this isa ScreenButtonModule.ScreenButton
    _latency_ui_hit_ms!(prof, t, :ui_handle_evt_preamble_typecheck)
    t = time_ns()
    if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        if isScreenButton
            sb = this::ScreenButtonModule.ScreenButton
            setfield!(sb, :currentTexture, getfield(sb, :buttonDownTexture))
        end
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_button_down)
    elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
        @debug "Mouse button up at $(x), $(y)"
        if isScreenButton
            sb = this::ScreenButtonModule.ScreenButton
            setfield!(sb, :currentTexture, getfield(sb, :buttonUpTexture))
        end
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_button_up_setup)
        t_cb = time_ns()
        _ui_run_click_event_callbacks!(inst, evt, x, y)
        _latency_ui_hit_ms!(prof, t_cb, :ui_handle_evt_mouse_button_up_click_callbacks)
    elseif evt.type == SDL2.SDL_MOUSEMOTION
        _ui_motion_set_hovered!(this)
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_motion)
    end
    return nothing
end

function UI.handle_event(this::JulGame.IEntity, evt, x, y)
    prof = _latency_profiler_active()
    t = time_ns()
    _latency_ui_hit_ms!(prof, t, :ui_handle_evt_preamble_typecheck)
    t = time_ns()
    if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_button_down)
    elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
        @debug "Mouse button up at $(x), $(y)"
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_button_up_setup)
        t_cb = time_ns()
        _latency_ui_hit_ms!(prof, t_cb, :ui_handle_evt_mouse_button_up_click_callbacks)
    elseif evt.type == SDL2.SDL_MOUSEMOTION
        if this.isHovered == false
            this.isHovered = true
        end
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_motion)
    end
    return nothing
end
