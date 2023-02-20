using SimpleDirectMediaLayer.LibSDL2
include("Animator.jl")
include("Camera.jl")
include("Constants.jl")
include("Entity.jl")
include("Enums.jl")
include("Input/Input.jl")
include("Input/InputInstance.jl")
include("RenderWindow.jl")
include("Rigidbody.jl")
include("SceneInstance.jl")
include("Sprite.jl")
include("Transform.jl")
include("Utils.jl")
include("Math/Vector2f.jl")

mutable struct MainLoop
    scene::Scene
    
    function MainLoop(scene)
        this = new()
		
		this.scene = scene
		
        return this
    end
end

function Base.getproperty(this::MainLoop, s::Symbol)
    if s == :start 
        function()
			SDL_GL_SetAttribute(SDL_GL_MULTISAMPLEBUFFERS, 16)
			SDL_GL_SetAttribute(SDL_GL_MULTISAMPLESAMPLES, 16)
			
			#initializing
			@assert SDL_Init(SDL_INIT_EVERYTHING) == 0 "error initializing SDL: $(unsafe_string(SDL_GetError()))"
			@assert TTF_Init() == 0 "error initializing SDL: $(unsafe_string(TTF_GetError()))"
			font = TTF_OpenFont(joinpath(@__DIR__, "..","assets/fonts/FiraCode/ttf/FiraCode-Regular.ttf"), 150)

			window = SDL_CreateWindow("Game", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, SceneInstance.camera.dimensions.x, SceneInstance.camera.dimensions.y, SDL_WINDOW_SHOWN)
			SDL_SetWindowResizable(window, SDL_TRUE)
			renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)

			for entity in this.scene.entities
				if entity.getSprite() != C_NULL
					entity.getSprite().injectRenderer(renderer)
				end
			end
			
			targetFrameRate = 60
			rigidbodies = this.scene.rigidbodies
			entities = this.scene.entities

			w_ref, h_ref = Ref{Cint}(0), Ref{Cint}(0)
            try
				w, h = w_ref[], h_ref[]

				DEBUG = false
				close = false
				timeStep = 0.01
				startTime = 0.0
				totalFrames = 0

				#physics vars
				lastPhysicsTime = SDL_GetTicks()
				
				while !close
					# Start frame timing
					totalFrames += 1
					lastStartTime = startTime
					startTime = SDL_GetPerformanceCounter()
					#region ============= Input
					InputInstance.pollInput()
					if InputInstance.quit
						close = true
					end
# 					if scan_code == SDL_SCANCODE_F3
# 						println("debug toggled")
# 						DEBUG = !DEBUG
#					end
					#endregion ============== Input
						
					#Physics
					currentPhysicsTime = SDL_GetTicks()
					deltaTime = (currentPhysicsTime - lastPhysicsTime) / 1000.0

					for rigidbody in rigidbodies
						rigidbody.update(deltaTime)
					end
					lastPhysicsTime =  SDL_GetTicks()

					#Rendering
					currentRenderTime = SDL_GetTicks()
					SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE)
					# Clear the current render target before rendering again
					SDL_RenderClear(renderer)

					SceneInstance.camera.update()
					
					for entity in entities
						entity.update()
						if DEBUG && entity.getCollider() != C_NULL
							pos = entity.getTransform().getPosition()
							colSize = entity.getCollider().getSize()
							SDL_RenderDrawLines(renderer, [
								SDL_Point(round(pos.x * SCALE_UNITS), round(pos.y * SCALE_UNITS)), 
								SDL_Point(round(pos.x * SCALE_UNITS + colSize.x * SCALE_UNITS), round(pos.y * SCALE_UNITS)),
								SDL_Point(round(pos.x * SCALE_UNITS + colSize.x * SCALE_UNITS), round(pos.y * SCALE_UNITS + colSize.y * SCALE_UNITS)), 
								SDL_Point(round(pos.x * SCALE_UNITS), round(pos.y * SCALE_UNITS  + colSize.y * SCALE_UNITS)), 
								SDL_Point(round(pos.x * SCALE_UNITS), round(pos.y * SCALE_UNITS))], 5)
						end
						
						entityAnimator = entity.getAnimator()
						if entityAnimator != C_NULL
							entityAnimator.update(currentRenderTime, deltaTime)
						end
						entitySprite = entity.getSprite()
						if entitySprite != C_NULL
							entitySprite.draw()
						end
					end
			
					if DEBUG
						# Stats to display
						text = TTF_RenderText_Blended( font, string("FPS: ", round(1000 / round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0))), SDL_Color(0,255,0,255) )
						text1 = TTF_RenderText_Blended( font, string("Frame time: ", round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0), "ms"), SDL_Color(0,255,0,255) )
						textTexture = SDL_CreateTextureFromSurface(renderer,text)
						textTexture1 = SDL_CreateTextureFromSurface(renderer,text1)
						SDL_RenderCopy(renderer, textTexture, C_NULL, Ref(SDL_Rect(0,0,150,50)))
						SDL_RenderCopy(renderer, textTexture1, C_NULL, Ref(SDL_Rect(0,50,200,50)))
						SDL_FreeSurface(text)
						SDL_FreeSurface(text1)
						SDL_DestroyTexture(textTexture)
						SDL_DestroyTexture(textTexture1)
					end
			
					SDL_RenderPresent(renderer)
					endTime = SDL_GetPerformanceCounter()
					elapsedMS = (endTime - startTime) / SDL_GetPerformanceFrequency() * 1000.0
					targetFrameTime = 1000/targetFrameRate
			
					if elapsedMS < targetFrameTime
    					SDL_Delay(round(targetFrameTime - elapsedMS))
					end
				end
			finally
				TTF_CloseFont( font );
				TTF_Quit()
				SDL_DestroyRenderer(renderer)
				SDL_DestroyWindow(window)
				SDL_Quit()
			end
        end
    else
        getfield(this, s)
    end
end