# ref: https://www.geeksforgeeks.org/sdl-library-in-c-c-with-examples/
using SimpleDirectMediaLayer.LibSDL2
include("Sprite.jl")
include("Entity.jl")
include("Input/Input.jl")
include("Math/Vector2f.jl")
include("RenderWindow.jl")
include("Transform.jl")
include("Utils.jl")

SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 16)
SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 16)

#initializing
@assert SDL_Init(SDL_INIT_EVERYTHING) == 0 "error initializing SDL: $(unsafe_string(SDL_GetError()))"
TTF_Init()

window = RenderWindow("GAME v1.0", 1280, 720)
renderer = window.getRenderer()
windowRefreshRate = window.getRefreshRate()
println(windowRefreshRate)
catTexture = window.loadTexture(joinpath(@__DIR__, "..", "assets", "cat.png"))
grassTexture = window.loadTexture(joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"))
input = Input()
animatedEntities = [
    Sprite(7, joinpath(@__DIR__, "..", "assets", "images", "SkeletonWalk.png"), renderer),
	]

entities = [
    Entity(Transform(),animatedEntities[1], C_NULL, C_NULL)
    ]

# playerEntity = Entity(Vector2f(100,100), catTexture)
w_ref, h_ref = Ref{Cint}(0), Ref{Cint}(0)

try
    w, h = w_ref[], h_ref[]
     x = entities[1].getTransform().getPosition().x
     y = entities[1].getTransform().getPosition().y

    close = false
    speed = 300
    timeStep = 0.01
    startTime = 0.0
	totalFrames = 0
	
	#animation vars
	animatedFPS = 12.0
	
	
    while !close
        # Start frame timing
		totalFrames += 1
		lastStartTime = startTime
		startTime = SDL_GetPerformanceCounter()
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
            
        
        #alpha = accumulator / timeStep
        
        x + w > window.width && (x = window.width - w;)
        x < 0 && (x = 0;)
        y + h > window.height && (y = window.height - h;)
        y < 0 && (y = 0;)
        #playerEntity.setPosition(Vector2f(x,y))
		entities[1].getTransform().setPosition(Vector2f(x,y))
		#Rendering
		currentRenderTime = SDL_GetTicks()
        window.clear()

        for entity in entities
            entity.update()
        end
       # window.render(playerEntity)
 		for animatedEntity in animatedEntities
			deltaTime = (currentRenderTime  - animatedEntity.getLastUpdate()) / 1000.0
			framesToUpdate = floor(deltaTime / (1.0 / animatedFPS))
			if framesToUpdate > 0
				animatedEntity.setLastFrame(animatedEntity.getLastFrame() + framesToUpdate)
				animatedEntity.setLastFrame(animatedEntity.getLastFrame() % animatedEntity.getFrameCount())
				animatedEntity.setLastUpdate(currentRenderTime)
        	end
			animatedEntity.draw(Ref(SDL_Rect(animatedEntity.getLastFrame() * 16,0,16,16)), Ref(SDL_Rect(64,64,64,64)))
 		end
		
		# Strings to display
        window.drawText(string("FPS: ", round(1000 / round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0))), 20, 0, 0, 255, 0, 24)
        window.drawText(string("Frame time: ", round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0)), 20, 20, 0, 255, 0, 24)
        window.display()
		endTime = SDL_GetPerformanceCounter()
		elapsedMS = (endTime - startTime) / SDL_GetPerformanceFrequency() * 1000.0
		targetFrameTime = 1000/windowRefreshRate
		if elapsedMS < targetFrameTime
			SDL_Delay(round(targetFrameTime - elapsedMS))
		end
    end
finally
    TTF_Quit()
    window.cleanUp()
    SDL_Quit()
end
