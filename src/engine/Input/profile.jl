@inline function _input_latency_profiler()
    m = JulGame.MAIN
    (m !== nothing && m.latencyProfiler !== nothing && m.latencyProfiler.enabled) || return nothing
    return m.latencyProfiler
end

@inline function _input_poll_accumulate!(prof, t0::Ref{UInt64}, key::Symbol)
    prof === nothing && return
    dt = (time_ns() - t0[]) / 1e6
    JulGame.LatencyProfilerModule.accumulate_input_poll_ms!(prof, key, dt)
    t0[] = time_ns()
    return
end

# UI hit-test: timings go to LatencyProfiler (summed per frame, printed only on slow-frame CRITICAL/WARNING reports).
# Optional live spam: JULGAME_TRACE_INPUT_UI_HIT=1 (every SDL mouse event). Per-element: JULGAME_TRACE_INPUT_UI_HIT_ITER=1.
# Cached: this is called from the per-element hit-test hot path, and an ENV
# read allocates and is slow (it was happening hundreds of times per mouse event)
const _trace_input_ui_hit_ref = Ref{Union{Nothing, Bool}}(nothing)
function _input_ui_hit_stream_logs()
    v = _trace_input_ui_hit_ref[]
    if v === nothing
        e = lowercase(strip(get(ENV, "JULGAME_TRACE_INPUT_UI_HIT", "")))
        _trace_input_ui_hit_ref[] = e in ("1", "true", "yes", "on")
    end
    return _trace_input_ui_hit_ref[]::Bool
end

const _trace_input_ui_hit_iter_ref = Ref{Union{Nothing, Bool}}(nothing)
function _input_ui_hit_iter_stream_logs()
    v = _trace_input_ui_hit_iter_ref[]
    if v === nothing
        s = lowercase(strip(get(ENV, "JULGAME_TRACE_INPUT_UI_HIT_ITER", "0")))
        _trace_input_ui_hit_iter_ref[] = s == "1" || s in ("true", "yes", "on")
    end
    return _trace_input_ui_hit_iter_ref[]::Bool
end

function _input_ui_hit_step!(prof, t_blk::Ref{UInt64}, key::Symbol; kvs...)
    if prof === nothing && !_input_ui_hit_stream_logs()
        return
    end
    t1 = time_ns()
    dt = (t1 - t_blk[]) / 1e6
    t_blk[] = t1
    if prof !== nothing
        JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_ms!(prof, key, dt)
    end
    if _input_ui_hit_stream_logs()
        if isempty(kvs)
            @info "[JulGame input/ui hit-test · stream]" key ms = round(dt, digits = 3)
        else
            @info "[JulGame input/ui hit-test · stream]" key ms = round(dt, digits = 3) (; kvs...)
        end
    end
    return
end

function _input_ui_hit_span!(prof, t0::UInt64, key::Symbol; kvs...)
    if prof === nothing && !_input_ui_hit_stream_logs()
        return
    end
    dt = (time_ns() - t0) / 1e6
    if prof !== nothing
        JulGame.LatencyProfilerModule.accumulate_input_ui_hit_detail_ms!(prof, key, dt)
    end
    if _input_ui_hit_stream_logs() && _input_ui_hit_iter_stream_logs()
        if isempty(kvs)
            @info "[JulGame input/ui hit-test · stream · iter]" key dur_ms = round(dt, digits = 3)
        else
            @info "[JulGame input/ui hit-test · stream · iter]" key dur_ms = round(dt, digits = 3) (; kvs...)
        end
    end
    return
end
