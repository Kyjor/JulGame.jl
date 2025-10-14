"""
    LatencyProfiler

A comprehensive profiling system for measuring frame-time latency in game loops.
Focuses on worst-case execution times, GC pauses, and allocation tracking.

# Usage
```julia
profiler = LatencyProfiler(enabled=true, buffer_size=1000)

# In your game loop:
@profile_section profiler :input begin
    # input processing code
end

@profile_section profiler :physics begin
    # physics code
end

# Print statistics:
print_latency_report(profiler)

# Export to CSV for analysis:
export_profiling_data(profiler, "profiling_results.csv")
```
"""
module LatencyProfilerModule
using ...JulGame
using Statistics
using Dates

export LatencyProfiler, ProfileSection, start_frame, end_frame, start_section, end_section
export print_latency_report, print_realtime_stats, export_profiling_data, clear_profiling_data
export get_worst_frames, @profile_section

"""
    ProfileSection

Tracks timing data for a specific section of the game loop.
"""
mutable struct ProfileSection
    name::Symbol
    times::Vector{Float64}          # Execution times in milliseconds
    frame_indices::Vector{Int}      # Which frame this measurement belongs to
    allocation_counts::Vector{Int}  # Allocations during this section
    gc_times::Vector{Float64}       # Time spent in GC during section
    
    function ProfileSection(name::Symbol, buffer_size::Int=1000)
        this = new()
        this.name = name
        this.times = Float64[]
        this.frame_indices = Int[]
        this.allocation_counts = Int[]
        this.gc_times = Float64[]
        
        # Pre-allocate to avoid allocations during profiling
        sizehint!(this.times, buffer_size)
        sizehint!(this.frame_indices, buffer_size)
        sizehint!(this.allocation_counts, buffer_size)
        sizehint!(this.gc_times, buffer_size)
        
        return this
    end
end

"""
    LatencyProfiler

Main profiler that tracks frame timings and subsystem performance.
"""
mutable struct LatencyProfiler
    enabled::Bool
    buffer_size::Int
    
    # Frame-level tracking
    frame_count::Int
    frame_start_time::UInt64
    frame_times::Vector{Float64}
    frame_allocations::Vector{Int}
    frame_gc_times::Vector{Float64}
    
    # Section-level tracking
    sections::Dict{Symbol, ProfileSection}
    current_section::Union{Symbol, Nothing}
    section_start_time::UInt64
    section_start_gc_time::Float64
    section_start_allocs::Int
    
    # Real-time monitoring
    last_report_time::Float64
    report_interval::Float64  # Seconds between real-time reports
    
    # Performance thresholds (in milliseconds)
    warning_frame_time::Float64  # Warn if frame exceeds this
    critical_frame_time::Float64  # Critical if frame exceeds this
    
    function LatencyProfiler(;
        enabled::Bool=true,
        buffer_size::Int=10000,
        report_interval::Float64=5.0,
        warning_frame_time::Float64=16.67,  # ~60 FPS
        critical_frame_time::Float64=33.33   # ~30 FPS
    )
        this = new()
        this.enabled = enabled
        this.buffer_size = buffer_size
        this.frame_count = 0
        this.frame_start_time = 0
        this.report_interval = report_interval
        this.warning_frame_time = warning_frame_time
        this.critical_frame_time = critical_frame_time
        this.last_report_time = time()
        
        this.frame_times = Float64[]
        this.frame_allocations = Int[]
        this.frame_gc_times = Float64[]
        sizehint!(this.frame_times, buffer_size)
        sizehint!(this.frame_allocations, buffer_size)
        sizehint!(this.frame_gc_times, buffer_size)
        
        this.sections = Dict{Symbol, ProfileSection}()
        this.current_section = nothing
        this.section_start_time = 0
        this.section_start_gc_time = 0.0
        this.section_start_allocs = 0
        
        return this
    end
end

# Get GC stats helper
function get_gc_time_ms()
    gc_stats = Base.gc_num()
    return gc_stats.total_time / 1e6  # Convert to milliseconds
end

function get_allocation_count()
    gc_stats = Base.gc_num()
    return Int(gc_stats.allocd)
end

"""
    start_frame(profiler::LatencyProfiler)

Mark the beginning of a frame. Call this at the start of your game loop.
"""
function start_frame(profiler::LatencyProfiler)
    if !profiler.enabled
        return
    end
    
    profiler.frame_count += 1
    profiler.frame_start_time = time_ns()
end

"""
    end_frame(profiler::LatencyProfiler)

Mark the end of a frame and record timing data.
"""
function end_frame(profiler::LatencyProfiler)
    if !profiler.enabled
        return
    end
    
    frame_end = time_ns()
    frame_time_ms = (frame_end - profiler.frame_start_time) / 1e6
    
    push!(profiler.frame_times, frame_time_ms)
    
    # Track GC and allocations at frame level
    # Note: These are cumulative, so we're tracking increases
    push!(profiler.frame_gc_times, get_gc_time_ms())
    push!(profiler.frame_allocations, get_allocation_count())
    
    # Check for problematic frames
    if frame_time_ms > profiler.critical_frame_time
        @warn "CRITICAL: Frame $(profiler.frame_count) took $(round(frame_time_ms, digits=2))ms (>$(profiler.critical_frame_time)ms threshold)"
    elseif frame_time_ms > profiler.warning_frame_time
        @debug "WARNING: Frame $(profiler.frame_count) took $(round(frame_time_ms, digits=2))ms (>$(profiler.warning_frame_time)ms threshold)"
    end
    
    # Real-time reporting
    current_time = time()
    if current_time - profiler.last_report_time >= profiler.report_interval
        print_realtime_stats(profiler)
        profiler.last_report_time = current_time
    end
end

"""
    start_section(profiler::LatencyProfiler, section_name::Symbol)

Mark the beginning of a profiled section (e.g., :input, :physics, :render).
"""
function start_section(profiler::LatencyProfiler, section_name::Symbol)
    if !profiler.enabled
        return
    end
    
    # Create section if it doesn't exist
    if !haskey(profiler.sections, section_name)
        profiler.sections[section_name] = ProfileSection(section_name, profiler.buffer_size)
    end
    
    profiler.current_section = section_name
    profiler.section_start_time = time_ns()
    profiler.section_start_gc_time = get_gc_time_ms()
    profiler.section_start_allocs = get_allocation_count()
end

"""
    end_section(profiler::LatencyProfiler)

Mark the end of the current profiled section.
"""
function end_section(profiler::LatencyProfiler)
    if !profiler.enabled || profiler.current_section === nothing
        return
    end
    
    section_end = time_ns()
    section_time_ms = (section_end - profiler.section_start_time) / 1e6
    
    section = profiler.sections[profiler.current_section]
    push!(section.times, section_time_ms)
    push!(section.frame_indices, profiler.frame_count)
    
    # Track allocations and GC time during this section
    gc_time_delta = get_gc_time_ms() - profiler.section_start_gc_time
    alloc_delta = get_allocation_count() - profiler.section_start_allocs
    
    push!(section.gc_times, gc_time_delta)
    push!(section.allocation_counts, alloc_delta)
    
    profiler.current_section = nothing
end

"""
    @profile_section profiler section_name body

Macro for convenient section profiling.

# Example
```julia
@profile_section profiler :physics begin
    update_physics(scene, deltaTime)
end
```
"""
macro profile_section(profiler, section_name, body)
    return quote
        start_section($(esc(profiler)), $(esc(section_name)))
        try
            $(esc(body))
        finally
            end_section($(esc(profiler)))
        end
    end
end

"""
    calculate_percentile(data::Vector{Float64}, percentile::Float64)

Calculate the given percentile of the data.
"""
function calculate_percentile(data::Vector{Float64}, percentile::Float64)
    if isempty(data)
        return 0.0
    end
    return quantile(data, percentile)
end

"""
    print_section_stats(section::ProfileSection, total_frames::Int)

Print statistics for a single profiled section.
"""
function print_section_stats(section::ProfileSection, total_frames::Int)
    if isempty(section.times)
        println("  $(section.name): No data collected")
        return
    end
    
    println("\n📊 Section: $(section.name)")
    println("  ├─ Sample count: $(length(section.times))")
    println("  ├─ Mean:   $(round(mean(section.times), digits=3)) ms")
    println("  ├─ Median: $(round(median(section.times), digits=3)) ms")
    println("  ├─ Std:    $(round(std(section.times), digits=3)) ms")
    println("  ├─ P95:    $(round(calculate_percentile(section.times, 0.95), digits=3)) ms")
    println("  ├─ P99:    $(round(calculate_percentile(section.times, 0.99), digits=3)) ms")
    println("  ├─ Max:    $(round(maximum(section.times), digits=3)) ms")
    
    # Allocation analysis
    if !isempty(section.allocation_counts)
        total_allocs = sum(section.allocation_counts)
        mean_allocs = mean(section.allocation_counts)
        max_allocs = maximum(section.allocation_counts)
        
        println("  ├─ Allocations:")
        println("  │  ├─ Total:   $(total_allocs)")
        println("  │  ├─ Mean:    $(round(mean_allocs, digits=1)) per call")
        println("  │  └─ Max:     $(max_allocs) in a single call")
    end
    
    # GC analysis
    if !isempty(section.gc_times)
        total_gc = sum(section.gc_times)
        max_gc = maximum(section.gc_times)
        frames_with_gc = count(x -> x > 0.01, section.gc_times)
        
        if total_gc > 0.0
            println("  └─ GC Impact:")
            println("     ├─ Total GC time: $(round(total_gc, digits=3)) ms")
            println("     ├─ Max GC pause:  $(round(max_gc, digits=3)) ms")
            println("     └─ Frames w/ GC:  $(frames_with_gc) ($(round(100*frames_with_gc/length(section.times), digits=1))%)")
        end
    end
end

"""
    print_latency_report(profiler::LatencyProfiler)

Print a comprehensive latency analysis report.
"""
function print_latency_report(profiler::LatencyProfiler)
    if profiler.frame_count == 0
        println("⚠️  No profiling data collected yet")
        return
    end
    
    println("\n" * "="^80)
    println("🎮 LATENCY PROFILING REPORT")
    println("="^80)
    println("Total frames analyzed: $(profiler.frame_count)")
    println("Duration: $(round(sum(profiler.frame_times)/1000, digits=2)) seconds")
    println()
    
    # Overall frame statistics
    println("📈 FRAME TIME ANALYSIS")
    println("  ├─ Mean:   $(round(mean(profiler.frame_times), digits=3)) ms ($(round(1000/mean(profiler.frame_times), digits=1)) FPS)")
    println("  ├─ Median: $(round(median(profiler.frame_times), digits=3)) ms ($(round(1000/median(profiler.frame_times), digits=1)) FPS)")
    println("  ├─ Std:    $(round(std(profiler.frame_times), digits=3)) ms")
    println("  ├─ P95:    $(round(calculate_percentile(profiler.frame_times, 0.95), digits=3)) ms")
    println("  ├─ P99:    $(round(calculate_percentile(profiler.frame_times, 0.99), digits=3)) ms")
    println("  └─ Max:    $(round(maximum(profiler.frame_times), digits=3)) ms")
    
    # Frame budget analysis
    println("\n⏱️  FRAME BUDGET ANALYSIS")
    frames_under_16ms = count(x -> x <= 16.67, profiler.frame_times)
    frames_under_33ms = count(x -> x <= 33.33, profiler.frame_times)
    frames_over_33ms = count(x -> x > 33.33, profiler.frame_times)
    
    println("  ├─ ≤16.67ms (60 FPS): $(frames_under_16ms) frames ($(round(100*frames_under_16ms/profiler.frame_count, digits=1))%)")
    println("  ├─ ≤33.33ms (30 FPS): $(frames_under_33ms) frames ($(round(100*frames_under_33ms/profiler.frame_count, digits=1))%)")
    println("  └─ >33.33ms (<30 FPS): $(frames_over_33ms) frames ($(round(100*frames_over_33ms/profiler.frame_count, digits=1))%)")
    
    # Section breakdown
    println("\n🔍 SUBSYSTEM BREAKDOWN")
    
    # Sort sections by mean time (highest first)
    sorted_sections = sort(collect(values(profiler.sections)), by=s -> mean(s.times), rev=true)
    
    for section in sorted_sections
        print_section_stats(section, profiler.frame_count)
    end
    
    # Identify worst frames
    println("\n⚠️  WORST FRAMES")
    worst_frames = get_worst_frames(profiler, 10)
    for (i, (frame_idx, frame_time)) in enumerate(worst_frames)
        println("  $i. Frame $(frame_idx): $(round(frame_time, digits=3)) ms")
    end
    
    println("\n" * "="^80)
end

"""
    print_realtime_stats(profiler::LatencyProfiler)

Print real-time statistics (called periodically during profiling).
"""
function print_realtime_stats(profiler::LatencyProfiler)
    if profiler.frame_count < 10
        return  # Need some data first
    end
    
    # Get last N frames for recent performance
    recent_count = min(120, length(profiler.frame_times))  # Last ~2 seconds at 60fps
    recent_times = profiler.frame_times[end-recent_count+1:end]
    
    recent_mean = mean(recent_times)
    recent_max = maximum(recent_times)
    recent_p99 = calculate_percentile(recent_times, 0.99)
    
    println("\n📊 [$(Dates.format(now(), "HH:MM:SS"))] Frame $(profiler.frame_count) | Recent performance:")
    println("   Mean: $(round(recent_mean, digits=2))ms | P99: $(round(recent_p99, digits=2))ms | Max: $(round(recent_max, digits=2))ms")
end

"""
    get_worst_frames(profiler::LatencyProfiler, n::Int=10)

Get the N worst frames by execution time.
Returns vector of (frame_index, frame_time) tuples.
"""
function get_worst_frames(profiler::LatencyProfiler, n::Int=10)
    if isempty(profiler.frame_times)
        return Tuple{Int, Float64}[]
    end
    
    # Create pairs of (frame_index, frame_time)
    frame_pairs = [(i, time) for (i, time) in enumerate(profiler.frame_times)]
    
    # Sort by time (descending) and take top N
    sort!(frame_pairs, by=x -> x[2], rev=true)
    
    return frame_pairs[1:min(n, length(frame_pairs))]
end

"""
    export_profiling_data(profiler::LatencyProfiler, filename::String)

Export profiling data to CSV for external analysis.
"""
function export_profiling_data(profiler::LatencyProfiler, filename::String)
    if profiler.frame_count == 0
        @warn "No profiling data to export"
        return
    end
    
    try
        open(filename, "w") do io
            # Write header
            section_names = sort(collect(keys(profiler.sections)))
            header = "frame,frame_time_ms," * join(["$(name)_ms" for name in section_names], ",")
            println(io, header)
            
            # Write data
            for frame_idx in 1:profiler.frame_count
                if frame_idx > length(profiler.frame_times)
                    break
                end
                
                row = "$(frame_idx),$(profiler.frame_times[frame_idx])"
                
                # Add section times for this frame
                for section_name in section_names
                    section = profiler.sections[section_name]
                    # Find the measurement for this frame
                    matching_indices = findall(x -> x == frame_idx, section.frame_indices)
                    if !isempty(matching_indices)
                        row *= ",$(section.times[matching_indices[1]])"
                    else
                        row *= ",0.0"
                    end
                end
                
                println(io, row)
            end
        end
        
        println("✅ Profiling data exported to: $(filename)")
    catch e
        @error "Failed to export profiling data: $(e)"
    end
end

"""
    clear_profiling_data(profiler::LatencyProfiler)

Clear all collected profiling data.
"""
function clear_profiling_data(profiler::LatencyProfiler)
    profiler.frame_count = 0
    empty!(profiler.frame_times)
    empty!(profiler.frame_allocations)
    empty!(profiler.frame_gc_times)
    
    for section in values(profiler.sections)
        empty!(section.times)
        empty!(section.frame_indices)
        empty!(section.allocation_counts)
        empty!(section.gc_times)
    end
    
    println("✅ Profiling data cleared")
end

end # module

