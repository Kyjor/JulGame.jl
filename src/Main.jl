include("Animator.jl")
include("Camera.jl")
include("Constants.jl")
include("Entity.jl")
include("Enums.jl")
include("Input/Input.jl")
include("Input/InputInstance.jl")
include("Macros.jl")
include("RenderWindow.jl")
include("Rigidbody.jl")
include("SceneInstance.jl")
include("UI/ScreenButton.jl")
include("SoundSource.jl")
include("Sprite.jl")
include("UI/TextBox.jl")
include("Transform.jl")
include("Utils.jl")
include("Math/Vector2.jl")
include("Math/Vector2f.jl")
include("Math/Vector4.jl")

using SimpleDirectMediaLayer
const SDL2 = SimpleDirectMediaLayer 

mutable struct MainLoop
    scene::Scene
    
    function MainLoop(scene)
        this = new()
		
		SDL2.init()
		this.scene = scene
		
        return this
    end

	function MainLoop()
        this = new()
		
		SDL2.init()
		
        return this
    end
end

function Base.getproperty(this::MainLoop, s::Symbol)
    if s == :start 
        function()
			window = SDL_CreateWindow("Game", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, SceneInstance.camera.dimensions.x, SceneInstance.camera.dimensions.y, SDL_WINDOW_POPUP_MENU | SDL_WINDOW_MAXIMIZED)
			SDL_SetWindowResizable(window, SDL_FALSE)
			renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)
			windowInfo = unsafe_wrap(Array, SDL_GetWindowSurface(window), 1; own = false)[1]

			referenceHeight = 1080
			referenceWidth = 1920
			referenceScale = referenceHeight*referenceWidth
			currentScale = windowInfo.w*windowInfo.h
			heightMultiplier = windowInfo.h/referenceHeight
			widthMultiplier = windowInfo.w/referenceWidth
			scaleMultiplier = currentScale/referenceScale
			targetFontSize = 50
			
			SDL_RenderSetScale(renderer, widthMultiplier*2, heightMultiplier*2)
			fontPath = @path joinpath(ENGINE_ASSETS, "fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")
			font = TTF_OpenFont(fontPath, targetFontSize)

			for entity in this.scene.entities
				if entity.getSprite() != C_NULL
					entity.getSprite().injectRenderer(renderer)
				end
			end
			
			for screenButton in this.scene.screenButtons
				screenButton.injectRenderer(renderer, font)
			end
			
			for textBox in this.scene.textBoxes
				textBox.initialize(renderer, font, windowInfo)
			end
			
			targetFrameRate = 60
			rigidbodies = this.scene.rigidbodies
			entities = this.scene.entities
			screenButtons = this.scene.screenButtons
			textBoxes = this.scene.textBoxes

            try

				DEBUG = false
				close = false
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
					DEBUG = InputInstance.debug
					
					#endregion ============== Input
						
					#Physics
					currentPhysicsTime = SDL_GetTicks()
					deltaTime = (currentPhysicsTime - lastPhysicsTime) / 1000.0
					if deltaTime > .25
						lastPhysicsTime =  SDL_GetTicks()
						continue
					end
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
					
					SDL_SetRenderDrawColor(renderer, 0, 255, 0, SDL_ALPHA_OPAQUE)
					for entity in entities
						entity.update()
						entityAnimator = entity.getAnimator()
						if entityAnimator != C_NULL
							entityAnimator.update(currentRenderTime, deltaTime)
						end
						entitySprite = entity.getSprite()
						if entitySprite != C_NULL
							entitySprite.draw()
						end

						if DEBUG && entity.getCollider() != C_NULL
							pos = entity.getTransform().getPosition()
							colSize = entity.getCollider().getSize()
							SDL_RenderDrawLines(renderer, [
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS)), 
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS)),
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS + colSize.y * SCALE_UNITS)), 
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS  + colSize.y * SCALE_UNITS)), 
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS))], 5)
						end
					end
					for screenButton in screenButtons
						screenButton.render()
					end

					for textBox in textBoxes
						textBox.render(DEBUG)
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
				SDL2.Mix_Quit()
				SDL2.SDL_Quit()
			end
        end
	elseif s == :loadScene
		function (scene)
			this.scene = scene
		end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end