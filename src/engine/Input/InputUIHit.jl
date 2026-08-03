# UI hit-test loop helpers (included from Input.jl).

function _should_skip_ui_hit_element(element, canvases)::Bool
    if !element.isActive
        return true
    end
    for canvas in canvases
        if element in canvas.children && !canvas.isActive
            return true
        end
    end
    if isa(element, JulGame.IEntity) && element.ignoreInputEvents
        return true
    end
    return false
end

function _mouse_inside_ui_rect(
    mouse_x::Real, mouse_y::Real,
    element_x::Real, element_y::Real,
    element_right::Real, element_bottom::Real,
)::Bool
    if UIHitTestModule.use_static_ui_hit_scalar_debug()
        return UIHitTestModule.is_mouse_inside_element_scalar_static(
            mouse_x, mouse_y, element_x, element_y, element_right, element_bottom,
        )
    end
    return UIHitTestModule.is_mouse_inside_element_julia(
        mouse_x, mouse_y, element_x, element_y, element_right, element_bottom,
    )
end

function _handle_ui_hit_on_element!(
    this::Input,
    element,
    evt,
    prof,
    t_hi::UInt64,
    clickedAnElementAlready::Ref{Bool},
    hoveredAnElementAlready::Ref{Bool},
)
    clicked_down_here = clicked_down_on_this_element(this, element)
    _input_ui_hit_span!(prof, t_hi, :hit_inside_1_clicked_down_query)
    t_hi = time_ns()

    canClickOnThisElement = (!clickedAnElementAlready[] || element.forceClickCheck) && clicked_down_here
    @debug "  -> canClickOnThisElement: $canClickOnThisElement, clickedAnElementAlready: $(clickedAnElementAlready[]), forceClickCheck: $(element.forceClickCheck), clicked_down_on_this_element: $clicked_down_here"
    _input_ui_hit_span!(prof, t_hi, :hit_inside_2_can_click_bools)
    t_hi = time_ns()

    if !clickedAnElementAlready[] || element.forceClickCheck
        shouldHandleEvent = (!hoveredAnElementAlready[] && evt.type == SDL2.SDL_MOUSEMOTION) ||
            (element.forceClickCheck && evt.type == SDL2.SDL_MOUSEMOTION) ||
            (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && !clickedAnElementAlready[]) ||
            (evt.type == SDL2.SDL_MOUSEBUTTONDOWN && element.forceClickCheck) ||
            (canClickOnThisElement && evt.type == SDL2.SDL_MOUSEBUTTONUP)

        @debug "  -> shouldHandleEvent: $shouldHandleEvent (event type: $(evt.type), hoveredAnElementAlready: $(hoveredAnElementAlready[]))"
        _input_ui_hit_span!(prof, t_hi, :hit_inside_3a_should_handle_expr)
        t_hi = time_ns()

        if shouldHandleEvent
            @debug "  -> Handling event for element '$(element.name)'"
            JulGame.UI.handle_event(element, evt, this.mousePosition.x, this.mousePosition.y)
            t_hi = time_ns()
            if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
                push!(this.elementsBeingClickedDownOn, element)
                @debug "  -> Added '$(element.name)' to elementsBeingClickedDownOn"
            end
            _input_ui_hit_span!(prof, t_hi, :hit_inside_5_push_clicked_down_optional)
            t_hi = time_ns()
        else
            _input_ui_hit_span!(prof, t_hi, :hit_inside_4_skip_should_handle_false)
            t_hi = time_ns()
        end
        if element.isHovered
            hoveredAnElementAlready[] = true
        end
        _input_ui_hit_span!(prof, t_hi, :hit_inside_6_hover_an_element_already)
        t_hi = time_ns()
    else
        _input_ui_hit_span!(prof, t_hi, :hit_inside_3b_skip_clicked_guard)
        t_hi = time_ns()
    end

    if evt.type == SDL2.SDL_MOUSEBUTTONDOWN
        @debug "Mouse button down at $(this.mousePosition) on element '$(element.name)'"
    elseif evt.type == SDL2.SDL_MOUSEBUTTONUP
        @debug "Mouse button up at $(this.mousePosition) on element '$(element.name)'"
        if canClickOnThisElement
            @debug "CLICKED on '$(element.name)' at $(this.mousePosition), skipping rest of event loop"
        else
            @debug "  -> Button up on '$(element.name)' but canClickOnThisElement is false"
        end
        clickedAnElementAlready[] = true
    end
    _input_ui_hit_span!(prof, t_hi, :hit_inside_7_mouse_btn_tail)
    return nothing
end

function _run_ui_hit_test_loop!(
    this::Input,
    evt,
    prof,
    canvases,
    elementsOrderedByLayerDescending,
)
    return _input_ui_hit_maybe_without_gc() do
        _run_ui_hit_test_loop_body!(
            this, evt, prof, canvases, elementsOrderedByLayerDescending,
        )
    end
end

function _run_ui_hit_test_loop_body!(
    this::Input,
    evt,
    prof,
    canvases,
    elementsOrderedByLayerDescending,
)
    clickedAnElementAlready = Ref(false)
    hoveredAnElementAlready = Ref(false)
    mouseX = this.mousePosition.x
    mouseY = this.mousePosition.y

    if UIHitTestModule.use_static_ui_hit_batch()
        buf = this.uiHitTestBuffer
        UIHitTestModule.clear!(buf)
        trace_gc = _input_ui_hit_gc_trace_logs()
        gc_event = trace_gc ? _ui_hit_gc_snapshot() : nothing

        gc_gather = trace_gc ? _ui_hit_gc_snapshot() : nothing
        detail = _input_ui_hit_gather_detail_logs()
        ms_skip = 0.0
        ms_pos = 0.0
        ms_size = 0.0
        ms_unpack = 0.0
        ms_push = 0.0
        n_walked = 0
        n_skipped = 0
        n_entity = 0
        n_ui = 0
        t_gather = time_ns()
        for element in elementsOrderedByLayerDescending
            n_walked += 1
            t_step = time_ns()
            if _should_skip_ui_hit_element(element, canvases)
                if detail
                    ms_skip += _ui_hit_elapsed_ms(t_step)
                    n_skipped += 1
                end
                continue
            end
            if detail
                ms_skip += _ui_hit_elapsed_ms(t_step)
                t_step = time_ns()
                if isa(element, JulGame.IEntity)
                    n_entity += 1
                else
                    n_ui += 1
                end
            end
            elementPosition = get_element_position(element)
            if detail
                ms_pos += _ui_hit_elapsed_ms(t_step)
                t_step = time_ns()
            end
            elementSize = get_element_size(element)
            if detail
                ms_size += _ui_hit_elapsed_ms(t_step)
                t_step = time_ns()
            end
            ex = elementPosition.x
            ey = elementPosition.y
            er = ex + elementSize.x
            eb = ey + elementSize.y
            if detail
                ms_unpack += _ui_hit_elapsed_ms(t_step)
                t_step = time_ns()
            end
            UIHitTestModule.push_rect!(buf, element, ex, ey, er, eb)
            if detail
                ms_push += _ui_hit_elapsed_ms(t_step)
            end
        end
        gather_ms = (time_ns() - t_gather) / 1e6
        if trace_gc
            _input_ui_hit_record_gc!(prof, :hit_batch_gather_gc, :hit_batch_gather_alloc, gc_gather)
        end
        if detail
            _input_ui_hit_record_gather_ms!(prof, :hit_batch_gather_skip, ms_skip)
            _input_ui_hit_record_gather_ms!(prof, :hit_batch_gather_get_position, ms_pos)
            _input_ui_hit_record_gather_ms!(prof, :hit_batch_gather_get_size, ms_size)
            _input_ui_hit_record_gather_ms!(prof, :hit_batch_gather_unpack, ms_unpack)
            _input_ui_hit_record_gather_ms!(prof, :hit_batch_gather_push_rect, ms_push)
            @debug "batch gather detail" total_ms=round(gather_ms, digits=3) skip_ms=round(ms_skip, digits=3) pos_ms=round(ms_pos, digits=3) size_ms=round(ms_size, digits=3) unpack_ms=round(ms_unpack, digits=3) push_ms=round(ms_push, digits=3) walked=n_walked skipped=n_skipped probed=buf.count entities=n_entity ui=n_ui
        end
        @debug "time batch gather: $(gather_ms) ms n=$(buf.count)$(_input_ui_hit_gc_suffix(gc_gather))"

        gc_hit = trace_gc ? _ui_hit_gc_snapshot() : nothing
        t_hit = time_ns()
        hit_idx = UIHitTestModule.run_static_hit_test_batch!(buf, mouseX, mouseY)
        hit_ms = (time_ns() - t_hit) / 1e6
        if trace_gc
            _input_ui_hit_record_gc!(prof, :hit_batch_static_gc, :hit_batch_static_alloc, gc_hit)
        end
        @debug "time static batch: $(hit_ms) ms n=$(buf.count) hit=$(hit_idx)$(_input_ui_hit_gc_suffix(gc_hit))"

        gc_julia = trace_gc ? _ui_hit_gc_snapshot() : nothing
        t_julia = time_ns()
        julia_idx = UIHitTestModule.first_hit_index_julia(buf, mouseX, mouseY)
        julia_ms = (time_ns() - t_julia) / 1e6
        if trace_gc
            _input_ui_hit_record_gc!(prof, :hit_batch_julia_gc, :hit_batch_julia_alloc, gc_julia)
        end
        @debug "time julia batch: $(julia_ms) ms n=$(buf.count) hit=$(julia_idx)$(_input_ui_hit_gc_suffix(gc_julia))"
        if julia_idx != hit_idx
            @warn "batch hit mismatch" static=hit_idx julia=julia_idx
        end

        t_hover = time_ns()
        for i in 1:buf.count
            element = buf.elements[i]
            t_iter = time_ns()
            if i != hit_idx
                element.isHovered = false
                _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_miss_hover_counter_inc)
                continue
            end
            t_hi = time_ns()
            @debug "  -> Mouse is INSIDE element '$(element.name)' (batch idx=$i)"
            _handle_ui_hit_on_element!(
                this, element, evt, prof, t_hi,
                clickedAnElementAlready, hoveredAnElementAlready,
            )
        end
        if detail
            hover_ms = (time_ns() - t_hover) / 1e6
            _input_ui_hit_record_gather_ms!(prof, :hit_batch_hover_pass, hover_ms)
            @info "batch hover pass" ms=round(hover_ms, digits=3) n=buf.count hit=hit_idx
        end
        if trace_gc
            gc_ms, alloc_bytes = _input_ui_hit_record_gc!(
                prof, :hit_batch_event_gc, :hit_batch_event_alloc, gc_event,
            )
            @info "time batch event total gc_ms=$(round(gc_ms, digits=3)) alloc_bytes=$alloc_bytes n=$(buf.count)"
        end
        return nothing
    end

    for element in elementsOrderedByLayerDescending
        t_iter = time_ns()
        if _should_skip_ui_hit_element(element, canvases)
            @debug "Skipping element $(element.name) - isActive: $(element.isActive), ignoreInputEvents: $(isa(element, JulGame.IEntity) ? element.ignoreInputEvents : "N/A")"
            _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_skip_early)
            continue
        end

        _input_ui_hit_span!(prof, t_iter, :hit_ui_iter_probe_active_filter)
        t_prep0 = time_ns()
        _input_ui_hit_span!(prof, t_prep0, :hit_ui_iter_probe_prep_hitbox)
        t_geom0 = time_ns()

        elementPosition = get_element_position(element)
        _input_ui_hit_span!(prof, t_geom0, :hit_ui_iter_probe_get_position)
        t_sz0 = time_ns()

        elementSize = get_element_size(element)
        _input_ui_hit_span!(prof, t_sz0, :hit_ui_iter_probe_get_size)
        t_unpk0 = time_ns()

        screenElementX = elementPosition.x
        screenElementY = elementPosition.y
        screenElementRight = screenElementX + elementSize.x
        screenElementBottom = screenElementY + elementSize.y

        @debug "Checking element '$(element.name)': mouse($mouseX, $mouseY) vs element($screenElementX, $screenElementY, $screenElementRight, $screenElementBottom)"

        _input_ui_hit_span!(prof, t_unpk0, :hit_ui_iter_probe_unpack_layout)
        t_aabb = time_ns()
        gc_aabb = _input_ui_hit_gc_trace_logs() ? _ui_hit_gc_snapshot() : nothing

        if UIHitTestModule.use_static_ui_hit_scalar_debug()
            eventWasInsideThisElement = _mouse_inside_ui_rect(
                mouseX, mouseY,
                screenElementX, screenElementY, screenElementRight, screenElementBottom,
            )
            aabb_ms = (time_ns() - t_aabb) / 1e6
            @info "time static scalar: $(aabb_ms) ms$(_input_ui_hit_gc_suffix(gc_aabb))"
        else
            eventWasInsideThisElement = UIHitTestModule.is_mouse_inside_element_julia(
                mouseX, mouseY,
                screenElementX, screenElementY, screenElementRight, screenElementBottom,
            )
            aabb_ms = (time_ns() - t_aabb) / 1e6
            @debug "time julia: $(aabb_ms) ms$(_input_ui_hit_gc_suffix(gc_aabb))"
        end

        _input_ui_hit_span!(prof, t_aabb, :hit_ui_iter_probe_aabb)

        if !eventWasInsideThisElement
            element.isHovered = false
            t_ctr = time_ns()
            _input_ui_hit_span!(prof, t_ctr, :hit_ui_iter_miss_hover_counter_inc)
            continue
        end

        t_hi = time_ns()
        @debug "  -> Mouse is INSIDE element '$(element.name)'"
        _handle_ui_hit_on_element!(
            this, element, evt, prof, t_hi,
            clickedAnElementAlready, hoveredAnElementAlready,
        )
    end
    return nothing
end
