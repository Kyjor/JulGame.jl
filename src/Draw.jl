using SimpleDirectMediaLayer.LibSDL2

function drawText(message::string, x::Integer, y::Integer, r::int, g::Integer, b::Integer, size::Integer)
    font = TTF_OpenFont("OpenSans.ttf", size)
    color = SDL_Color(r, g, b, 255)
    surface = TTF_RenderText_Solid(font, message, color)
    texture = SDL_CreateTextureFromSurface(surface)
    
    SDL_FreeSurface(surface)
    SDL_RenderCopy(re)
end