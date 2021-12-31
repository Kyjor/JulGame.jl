# ref: https://www.geeksforgeeks.org/sdl-library-in-c-c-with-examples/
using SimpleDirectMediaLayer.LibSDL2
include("Entity.jl")
include("Input/Input.jl")
include("Math/Vector2f.jl")
include("RenderWindow.jl")

SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 16)
SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 16)

@assert SDL_Init(SDL_INIT_EVERYTHING) == 0 "error initializing SDL: $(unsafe_string(SDL_GetError()))"

window = RenderWindow("GAME v1.0", 1280, 720);

catTexture = window.loadTexture(joinpath(@__DIR__, "..", "assets", "cat.png"))
grassTexture = window.loadTexture(joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"))
input = Input()

entities = [
    Entity(Vector2f(0, 200), grassTexture),
    Entity(Vector2f(25, 200), grassTexture),
    Entity(Vector2f(50, 200), grassTexture),
    Entity(Vector2f(75, 200), grassTexture),
    Entity(Vector2f(100, 200), grassTexture),
    Entity(Vector2f(125, 200), grassTexture),
    Entity(Vector2f(150, 200), grassTexture),
    Entity(Vector2f(175, 200), grassTexture),
    Entity(Vector2f(200, 200), grassTexture),
    Entity(Vector2f(225, 200), grassTexture),
    ]

playerEntity = Entity(Vector2f(0,0), catTexture)
    w = window.width
    h = window.height
try
    x = (1000 - w) ÷ 2
    y = (1000 - h) ÷ 2
    # dest_ref = Ref(SDL_Rect(x, y, w, h))
    # grass_dest = Ref(SDL_Rect(x, y, w, h))
    
    close = false
    speed = 300
    while !close
        event_ref = Ref{SDL_Event}()
        while Bool(SDL_PollEvent(event_ref))
            evt = event_ref[]
            evt_ty = evt.type
            if evt_ty == SDL_QUIT
                close = true
                break
            elseif evt_ty == SDL_KEYDOWN
                scan_code = evt.key.keysym.scancode
                if scan_code == SDL_SCANCODE_W || scan_code == SDL_SCANCODE_UP
                    y -= speed / 30
                    break
                elseif scan_code == SDL_SCANCODE_A || scan_code == SDL_SCANCODE_LEFT
                    x -= speed / 30
                    break
                elseif scan_code == SDL_SCANCODE_S || scan_code == SDL_SCANCODE_DOWN
                    y += speed / 30
                    break
                elseif scan_code == SDL_SCANCODE_D || scan_code == SDL_SCANCODE_RIGHT
                    x += speed / 30
                    break
                else
                    break
                end
            end
        end

        x + w > 1000 && (x = 1000 - w;)
        x < 0 && (x = 0;)
        y + h > 1000 && (y = 1000 - h;)
        y < 0 && (y = 0;)
        playerEntity.setPosition(Vector2f(x,y))
        window.clear()

        for entity in entities
            window.render(entity)
        end
        window.render(playerEntity)

        window.display()
        # dest = dest_ref[]
        # x, y, w, h = dest.x, dest.y, dest.w, dest.h

    end
finally
    # SDL_DestroyTexture(tex)
    # SDL_DestroyRenderer(renderer)
    # SDL_DestroyWindow(win)
    window.cleanUp()
    SDL_Quit()
end
