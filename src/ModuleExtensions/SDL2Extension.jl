module SDL2Extension
    using ..JulGame
    export SDL_RenderDrawCircle, SDL_RenderFillCircle
    function SDL_RenderDrawCircle(x::Int, y::Int, radius::Int)
        offsetx = 0
        offsety = radius
        d = radius - 1
        status = 0

        SDL2.SDL_SetRenderDrawColor(Renderer, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
        SDL2.SDL_RenderDrawPoint(Renderer, 100, 100)
        count = 0
        while offsety >= offsetx
            status += SDL2.SDL_RenderDrawPoint(Renderer, x + offsetx, y + offsety)
            status += SDL2.SDL_RenderDrawPoint(Renderer, x + offsety, y + offsetx)
            status += SDL2.SDL_RenderDrawPoint(Renderer, x - offsetx, y + offsety)
            status += SDL2.SDL_RenderDrawPoint(Renderer, x - offsety, y + offsetx)
            status += SDL2.SDL_RenderDrawPoint(Renderer, x + offsetx, y - offsety)
            status += SDL2.SDL_RenderDrawPoint(Renderer, x + offsety, y - offsetx)
            status += SDL2.SDL_RenderDrawPoint(Renderer, x - offsetx, y - offsety)
            status += SDL2.SDL_RenderDrawPoint(Renderer, x - offsety, y - offsetx)

            if status < 0
                status = -1
                break
            end

            if d >= 2 * offsetx
                d -= 2 * offsetx + 1
                offsetx += 1
            elseif d < 2 * (radius - offsety)
                d += 2 * offsety - 1
                offsety -= 1
            else
                d += 2 * (offsety - offsetx - 1)
                offsety -= 1
                offsetx += 1
            end
            count += 1
        end
        return status
    end

    function SDL_RenderFillCircle(x::Int, y::Int, radius::Int)
        offsetx = 0
        offsety = radius
        d = radius - 1
        status = 0

        while offsety >= offsetx
            status += SDL2.SDL_RenderDrawLine(Renderer, x - offsety, y + offsetx, x + offsety, y + offsetx)
            status += SDL2.SDL_RenderDrawLine(Renderer, x - offsetx, y + offsety, x + offsetx, y + offsety)
            status += SDL2.SDL_RenderDrawLine(Renderer, x - offsetx, y - offsety, x + offsetx, y - offsety)
            status += SDL2.SDL_RenderDrawLine(Renderer, x - offsety, y - offsetx, x + offsety, y - offsetx)

            if status < 0
                status = -1
                break
            end

            if d >= 2 * offsetx
                d -= 2 * offsetx + 1
                offsetx += 1
            elseif d < 2 * (radius - offsety)
                d += 2 * offsety - 1
                offsety -= 1
            else
                d += 2 * (offsety - offsetx - 1)
                offsety -= 1
                offsetx += 1
            end
        end

        return status
    end
end


