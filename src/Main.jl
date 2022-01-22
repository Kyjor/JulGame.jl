# ref: https://www.geeksforgeeks.org/sdl-library-in-c-c-with-examples/
using SimpleDirectMediaLayer.LibSDL2
include("Sprite.jl")
include("Collider.jl")
include("Entity.jl")
include("Enums.jl")
include("Input/Input.jl")
include("Math/Vector2f.jl")
include("RenderWindow.jl")
include("Rigidbody.jl")
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
colliders = [
	Collider(Vector2f(64, 64), Vector2f(), "none")
	Collider(Vector2f(64, 64), Vector2f(), "none")
]
sprites = [
    Sprite(7, joinpath(@__DIR__, "..", "assets", "images", "SkeletonWalk.png"), renderer),
    Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
    Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
    Sprite(1, joinpath(@__DIR__, "..", "assets", "ground_grass_1.png"), renderer),
	]
rigidbodies = [
	Rigidbody(1, 0)
]

entities = [
    Entity("player", Transform(),sprites[1], colliders[1], rigidbodies[1]) # playerEntity
    Entity("tile0", Transform(Vector2f(0, 650), Vector2f(), 0.0),sprites[2], colliders[2], C_NULL) 
    Entity("tile1", Transform(Vector2f(64, 650), Vector2f(), 0.0),sprites[3], C_NULL, C_NULL)
    Entity("tile2", Transform(Vector2f(128, 650), Vector2f(), 0.0),sprites[4], C_NULL, C_NULL)
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
	
	#physics vars
	lastPhysicsTime = SDL_GetTicks()
	
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
            x = -1
        elseif scan_code == SDL_SCANCODE_S || scan_code == SDL_SCANCODE_DOWN
            y += speed / 30
        elseif scan_code == SDL_SCANCODE_D || scan_code == SDL_SCANCODE_RIGHT
            x = 1
        end
        input.scan_code = nothing
        # SDL_PumpEvents()
        # event_ref = Ref{Int32}()
        # keystate = SDL_GetKeyboardState(C_NULL)
        # test = Base.unsafe_load(keystate)
        # println(test)
        # #println(SDL_SCANCODE_RETURN)

        # #continuous-response keys
        # if keystate == SDL_SCANCODE_LEFT
        #     println("left")
        # end
        # if keystate == SDL_SCANCODE_RIGHT
        #     println("right")
        # end
        # if keystate == SDL_SCANCODE_UP
        #     println("up")
        # end
        # if keystate == SDL_SCANCODE_DOWN
        #     println("down")
        # end
        #endregion ============== Input
			
		#Physics
		currentPhysicsTime = SDL_GetTicks()
		
        #Only check the player against other colliders
        for colliderB in colliders
            if colliders[1] != colliderB
                collision = checkCollision(colliders[1], colliderB)
                if collision == Bottom::CollisionDirection
                    rigidbodies[1].setVelocity(Vector2f(rigidbodies[1].getVelocity().x, 0))
                elseif collision == None::CollisionDirection
                    rigidbodies[1].setVelocity(Vector2f(rigidbodies[1].getVelocity().x, 1))
                end
            end
        end    


		deltaTime = (currentPhysicsTime - lastPhysicsTime) / 1000.0

        rigidbodies[1].setVelocity(Vector2f(x, rigidbodies[1].getVelocity().y))

		for rigidbody in rigidbodies
			position = rigidbody.getParent().getTransform().getPosition()
			rigidbody.getParent().getTransform().setPosition(Vector2f(round(position.x + rigidbody.velocity.x * deltaTime),round(position.y + rigidbody.velocity.y * deltaTime)))
		end
        
        #alpha = accumulator / timeStep
        
        x + w > window.width && (x = window.width - w;)
        x < 0 && (x = 0;)
        y + h > window.height && (y = window.height - h;)
        y < 0 && (y = 0;)
# 		entities[1].getTransform().setPosition(Vector2f(x,y))
		#Rendering
		currentRenderTime = SDL_GetTicks()
        window.clear()

        for entity in entities
            entity.update()
        end

 		for sprite in sprites
			deltaTime = (currentRenderTime  - sprite.getLastUpdate()) / 1000.0
			framesToUpdate = floor(deltaTime / (1.0 / animatedFPS))
			if framesToUpdate > 0
				sprite.setLastFrame(sprite.getLastFrame() + framesToUpdate)
				sprite.setLastFrame(sprite.getLastFrame() % sprite.getFrameCount())
				sprite.setLastUpdate(currentRenderTime)
        	end
			sprite.draw(Ref(SDL_Rect(sprite.getLastFrame() * 16,0,16,16)), Ref(SDL_Rect(64,64,64,64)))
 		end
		
		# Strings to display
        window.drawText(string("FPS: ", round(1000 / round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0))), 20, 0, 0, 255, 0, 24)
        window.drawText(string("Frame time: ", round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0)), 20, 20, 0, 255, 0, 24)
        window.display()
		endTime = SDL_GetPerformanceCounter()
		elapsedMS = (endTime - startTime) / SDL_GetPerformanceFrequency() * 1000.0
		targetFrameTime = 1000/windowRefreshRate

        x = 0
		if elapsedMS < targetFrameTime
			SDL_Delay(round(targetFrameTime - elapsedMS))
		end
    end
finally
    TTF_Quit()
    window.cleanUp()
    SDL_Quit()
end
