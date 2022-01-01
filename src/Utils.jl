using SimpleDirectMediaLayer.LibSDL2

function hireTimeInSeconds()
    t = SDL_GetTicks()
    t *= 0.001
    
    return t
end