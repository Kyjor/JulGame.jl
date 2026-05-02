# Mouse/input dispatch for UI. Loaded after `ScreenButton.jl` so `ScreenButtonModule` resolves
# and JuliaC `--trim` can use concrete `isa` branches.

@Base.noinline function _ui_invoke_click_event_callbacks!(evs::Vector{Function}, evt, x, y)::Nothing
    JulGame.juliac_trim_active() && return nothing
    nt = (evt = evt, x = x, y = y)
    for eventToCall in evs
        try
            Base.invokelatest(eventToCall, nt)
        catch
            Base.invokelatest(eventToCall)
        end
    end
    return nothing
end

@inline function _ui_run_click_event_callbacks!(inst::UIElementInstance, evt, x, y)::Nothing
    evs = getfield(inst, :clickEvents)::Vector{Function}
    _ui_invoke_click_event_callbacks!(evs, evt, x, y)
    return nothing
end

@Base.noinline function _ui_invoke_simple_hover_callbacks!(events::Vector{Function})::Nothing
    JulGame.juliac_trim_active() && return nothing
    for event in events
        try
            Base.invokelatest(event)
        catch e
            @error "Error calling hover event: $(e)"
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
    _ui_invoke_simple_hover_callbacks!(events)
    _latency_ui_hit_ms!(prof, t0, :hover_dispatch_enter_invocations)
    return nothing
end

function _ui_handle_event_non_screen_button!(this::JulGame.IUIElement, evt, x, y)::Nothing
    prof = _latency_profiler_active()
    t = time_ns()
    inst = relationship_instance(this)
    _latency_ui_hit_ms!(prof, t, :ui_handle_evt_preamble_typecheck)
    t = time_ns()
    if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_button_down)
    elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
        @debug "Mouse button up at $(x), $(y)"
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

function UI.handle_event(this::ScreenButtonModule.ScreenButton, evt, x, y)::Nothing
    prof = _latency_profiler_active()
    t = time_ns()
    inst = relationship_instance(this)
    _latency_ui_hit_ms!(prof, t, :ui_handle_evt_preamble_typecheck)
    t = time_ns()
    if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        setfield!(this, :currentTexture, getfield(this, :buttonDownTexture))
        _latency_ui_hit_ms!(prof, t, :ui_handle_evt_mouse_button_down)
    elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
        @debug "Mouse button up at $(x), $(y)"
        setfield!(this, :currentTexture, getfield(this, :buttonUpTexture))
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

function UI.handle_event(this::TextBoxModule.TextBox, evt, x, y)::Nothing
    _ui_handle_event_non_screen_button!(this, evt, x, y)
end

function UI.handle_event(this::RectangleModule.Rectangle, evt, x, y)::Nothing
    _ui_handle_event_non_screen_button!(this, evt, x, y)
end

function UI.handle_event(this::CircleModule.Circle, evt, x, y)::Nothing
    _ui_handle_event_non_screen_button!(this, evt, x, y)
end

function UI.handle_event(this::CanvasModule.Canvas, evt, x, y)::Nothing
    _ui_handle_event_non_screen_button!(this, evt, x, y)
end

function UI.handle_event(this::UIImageModule.UIImage, evt, x, y)::Nothing
    _ui_handle_event_non_screen_button!(this, evt, x, y)
end

function UI.handle_event(this::JulGame.IUIElement, evt, x, y)::Nothing
    _ui_handle_event_non_screen_button!(this, evt, x, y)
end

function UI.input_ui_set_isHovered!(ui::TextBoxModule.TextBox, value::Bool)::Nothing
    _input_ui_set_isHovered_inner!(ui, value)
end
function UI.input_ui_set_isHovered!(ui::ScreenButtonModule.ScreenButton, value::Bool)::Nothing
    _input_ui_set_isHovered_inner!(ui, value)
end
function UI.input_ui_set_isHovered!(ui::RectangleModule.Rectangle, value::Bool)::Nothing
    _input_ui_set_isHovered_inner!(ui, value)
end
function UI.input_ui_set_isHovered!(ui::CircleModule.Circle, value::Bool)::Nothing
    _input_ui_set_isHovered_inner!(ui, value)
end
function UI.input_ui_set_isHovered!(ui::CanvasModule.Canvas, value::Bool)::Nothing
    _input_ui_set_isHovered_inner!(ui, value)
end
function UI.input_ui_set_isHovered!(ui::UIImageModule.UIImage, value::Bool)::Nothing
    _input_ui_set_isHovered_inner!(ui, value)
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
