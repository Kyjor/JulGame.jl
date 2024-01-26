
function CallSDLFunction(func::Function, args...)
    SDL2.SDL_ClearError()

    # Call SDL function and check for errors
    ret = func(args...)
    if (isa(ret, Number) && ret < 0) || ret == C_NULL
        println(unsafe_string(SDL2.SDL_GetError()))
        Base.show_backtrace(stdout, catch_backtrace())
    end

    return ret
end

function deprecated_get_property(method_lookup, this::T, s::Symbol) where T
    if haskey(method_lookup, s)
        f = method_lookup[s]
        # @warn "Using get_property to access the function $s from $T is deprecated. Please call $(typeof(f)) instead"
        return (args...; kwargs...) -> method_lookup[s](this, args...; kwargs...)
    end
    return getfield(this, s)
end
