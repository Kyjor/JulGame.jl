module Diagnostics
    include("Logging.jl")
    include("LatencyProfiler.jl")
    
    export LoggingModule, LatencyProfilerModule
end
