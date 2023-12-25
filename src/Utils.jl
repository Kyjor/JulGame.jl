
function CallSDLFunction(func::Function, args...)
    SDL2.SDL_ClearError()

    # Call SDL function and check for errors
    ret = func(args...)
    if (isa(ret, Number) && ret < 0) || ret == C_NULL
        println(unsafe_string(SDL2.SDL_GetError()))
    end

    return ret
end