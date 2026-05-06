# Profiling helper functions
export enable_profiling, disable_profiling, print_profiling_report, export_profiling_data
export maybe_enable_latency_profiling_from_env!

const _latency_env_session_started = Ref(false)
const _latency_env_atexit_registered = Ref(false)

"""
    enable_profiling(;buffer_size=10000, report_interval=5.0)

Enable latency profiling for the game loop. This will track frame times,
section times, allocations, and GC pauses.

# Arguments
- `buffer_size::Int`: Number of frames to buffer (default: 10000)
- `report_interval::Float64`: Seconds between real-time reports (default: 5.0)

# Example
```julia
enable_profiling(buffer_size=5000, report_interval=10.0)
# Run your game...
print_profiling_report()
export_profiling_data("results.csv")
```
"""
function enable_profiling(;buffer_size::Int=10000, report_interval::Float64=5.0)
    this::MainLoop = MAIN
    this.latencyProfiler = JulGame.LatencyProfilerModule.LatencyProfiler(
        enabled=true,
        buffer_size=buffer_size,
        report_interval=report_interval
    )
    println("✅ Latency profiling enabled (buffer: $buffer_size frames, reports every $(report_interval)s)")
end

"""
    disable_profiling()

Disable latency profiling and print final report.
"""
function disable_profiling()
    this::MainLoop = MAIN
    if this.latencyProfiler !== nothing
        JulGame.LatencyProfilerModule.print_latency_report(this.latencyProfiler)
        this.latencyProfiler = nothing
        println("✅ Latency profiling disabled")
    end
end

"""
    print_profiling_report()

Print a comprehensive latency profiling report including per-script performance.
"""
function print_profiling_report()
    this::MainLoop = MAIN
    if this.latencyProfiler !== nothing
        JulGame.LatencyProfilerModule.print_latency_report(this.latencyProfiler)
        
        # Also print script-specific profiling if data is available
        if !isempty(this.scriptTimings)
            println("\n")  # Spacing
            print_script_profiling_report(this)
        end
    else
        @warn "Profiling is not enabled. Call enable_profiling() first."
    end
end

"""
    export_profiling_data(filename::String)

Export profiling data to CSV file for external analysis.
"""
function export_profiling_data(filename::String)
    this::MainLoop = MAIN
    if this.latencyProfiler !== nothing
        JulGame.LatencyProfilerModule.export_profiling_data(this.latencyProfiler, filename)
    else
        @warn "Profiling is not enabled. Call enable_profiling() first."
    end
end

"""
    maybe_enable_latency_profiling_from_env!()

Start latency profiling once per process when `JULGAME_LATENCY_PROFILE` is set (`1`/`true`/`yes`/`on`).
Optional `JULGAME_LATENCY_REPORT_SEC` sets the periodic report interval in seconds.

Safe from any script module (e.g. title screen) whether loaded via the game package or editor
`include` into `JulGame.ScriptModule`, where sibling Battler-only modules may not exist.
"""
function maybe_enable_latency_profiling_from_env!()
    v = strip(get(ENV, "JULGAME_LATENCY_PROFILE", ""))
    isempty(v) && return
    lowercase(v) in ("1", "true", "yes", "on") || return
    _latency_env_session_started[] && return
    interval = 5.0
    try
        vs = strip(get(ENV, "JULGAME_LATENCY_REPORT_SEC", ""))
        if !isempty(vs)
            interval = parse(Float64, vs)
        end
    catch
    end
    enable_profiling(; buffer_size=10_000, report_interval=max(0.5, interval))
    _latency_env_session_started[] = true
    @info "JulGame latency profiling (session): reports every $(max(0.5, interval))s; JulGame.print_profiling_report(); JulGame.export_profiling_data(\"latency.csv\")."
    if !_latency_env_atexit_registered[]
        atexit() do
            try
                if JulGame.MAIN !== nothing && JulGame.MAIN.latencyProfiler !== nothing
                    disable_profiling()
                end
            catch
            end
        end
        _latency_env_atexit_registered[] = true
    end
    return
end