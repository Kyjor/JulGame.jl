# ref: https://www.geeksforgeeks.org/sdl-library-in-c-c-with-examples/
using SimpleDirectMediaLayer.LibSDL2
include("Entity.jl")
include("Input/Input.jl")
include("Math/Vector2f.jl")
include("RenderWindow.jl")
include("Utils.jl")

SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 16)
SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 16)

@assert SDL_Init(SDL_INIT_EVERYTHING) == 0 "error initializing SDL: $(unsafe_string(SDL_GetError()))"

window = RenderWindow("GAME v1.0", 1280, 720);
TTF_Init()

windowRefreshRate = window.getRefreshRate()
println(windowRefreshRate)
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

playerEntity = Entity(Vector2f(100,100), catTexture)
w_ref, h_ref = Ref{Cint}(0), Ref{Cint}(0)

try
    w, h = w_ref[], h_ref[]
    x = playerEntity.position.x
    y = playerEntity.position.y

    close = false
    speed = 300
    timeStep = 0.01
    accumulator = 0.0
    currentTime = hireTimeInSeconds()
    currentFrameTime::Float64 = hireTimeInSeconds()
    while !close
        
        startTicks = SDL_GetTicks()
        newTime = hireTimeInSeconds()
        frameTime = newTime - currentTime
        accumulator += frameTime
        
        while accumulator >= timeStep
            #region ============= Input
            input.pollInput()
            if input.quit
                close = true
            end
            
            scan_code = input.scan_code
            if scan_code == SDL_SCANCODE_W || scan_code == SDL_SCANCODE_UP
                y -= speed / 30
            elseif scan_code == SDL_SCANCODE_A || scan_code == SDL_SCANCODE_LEFT
                x -= speed / 30
            elseif scan_code == SDL_SCANCODE_S || scan_code == SDL_SCANCODE_DOWN
                y += speed / 30
            elseif scan_code == SDL_SCANCODE_D || scan_code == SDL_SCANCODE_RIGHT
                x += speed / 30
            end
            input.scan_code = nothing
            #endregion ============== Input
            
            accumulator -= timeStep
        end
        
        alpha = accumulator / timeStep
        
        x + w > window.width && (x = window.width - w;)
        x < 0 && (x = 0;)
        y + h > window.height && (y = window.height - h;)
        y < 0 && (y = 0;)
        playerEntity.setPosition(Vector2f(x,y))
        window.clear()

        for entity in entities
            window.render(entity)
        end
        window.render(playerEntity)
        
        cft::Float64 = round(hireTimeInSeconds() - currentFrameTime; digits=6)
        fps::Float64 = round(1/cft; digits=4)

        window.drawText("Frame time: $cft", 20, 30, 0, 255, 0, 24)
        window.drawText("FPS: $fps", 20, 60, 0, 255, 0, 24)
        currentFrameTime = hireTimeInSeconds()
        window.display()
        
        frameTicks = SDL_GetTicks() - startTicks
        
        if frameTicks < 1000 / windowRefreshRate
            delay = 1000 / windowRefreshRate - frameTicks
            SDL_Delay(round(delay))
        end
    end
finally
    TTF_Quit()
    window.cleanUp()
    SDL_Quit()
end
