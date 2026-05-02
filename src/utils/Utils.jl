
"""JuliaC `--trim`: direct call (no `Core._apply_iterate` / `Vararg{Any}`) for this SDL entry point."""
function sdl_create_texture_from_surface(renderer::Ptr{SDL2.SDL_Renderer}, surface::Ptr{SDL2.SDL_Surface})::Ptr{SDL2.SDL_Texture}
	SDL2.SDL_ClearError()
	ret = SDL2.SDL_CreateTextureFromSurface(renderer, surface)::Ptr{SDL2.SDL_Texture}
	if ret == C_NULL
		@error "SDL_CreateTextureFromSurface failed: $(unsafe_string(SDL2.SDL_GetError()))"
	end
	return ret
end

function CallSDLFunction(func::Function, args...)
    SDL2.SDL_ClearError()

    # Call SDL function and check for errors
    ret = func(args...)
    if (isa(ret, Number) && ret < 0) || ret == C_NULL
        @error "SDL Error: $(unsafe_string(SDL2.SDL_GetError())) 
        || with function $(func) 
        || with args $(args)" 
    end

    return ret
end