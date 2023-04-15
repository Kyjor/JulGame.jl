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
	assets
	entities
	font
	heightMultiplier
	lastMousePosition
	panCounter
	panThreshold
	renderer
	rigidbodies
	scene::Scene
	screenButtons
	targetFrameRate
	textBoxes
	widthMultiplier
	window
    zoom::Float64

    function MainLoop(scene)
        this = new()
		
		SDL2.init()
		this.scene = scene
		
        return this
    end

	function MainLoop(zoom::Float64)
        this = new()
		
		SDL2.init()
		this.zoom = zoom
		
        return this
    end

	function MainLoop()
        this = new()
		
		SDL2.init()
		
        return this
    end
end

function Base.getproperty(this::MainLoop, s::Symbol)
    if s == :init 
        function(isUsingEditor = false)
			if isUsingEditor
				this.window = SDL_CreateWindow("Game", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, SceneInstance.camera.dimensions.x, SceneInstance.camera.dimensions.y, SDL_WINDOW_POPUP_MENU | SDL_WINDOW_ALWAYS_ON_TOP | SDL_WINDOW_BORDERLESS | SDL_WINDOW_RESIZABLE)
			else
				this.window = SDL_CreateWindow("Game", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, SceneInstance.camera.dimensions.x, SceneInstance.camera.dimensions.y, SDL_WINDOW_POPUP_MENU)
			end

			SDL_SetWindowResizable(this.window, SDL_FALSE)
			this.renderer = SDL_CreateRenderer(this.window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC)
			windowInfo = unsafe_wrap(Array, SDL_GetWindowSurface(this.window), 1; own = false)[1]

			referenceHeight = 1080
			referenceWidth = 1920
			referenceScale = referenceHeight*referenceWidth
			currentScale = windowInfo.w*windowInfo.h
			this.heightMultiplier = windowInfo.h/referenceHeight
			this.widthMultiplier = windowInfo.w/referenceWidth
			scaleMultiplier = currentScale/referenceScale
			fontSize = 50
			
			SDL_RenderSetScale(this.renderer, this.widthMultiplier * this.zoom, this.heightMultiplier * this.zoom)
			fontPath = joinpath(this.assets, "fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")
			this.font = TTF_OpenFont(fontPath, fontSize)

			for entity in this.scene.entities
				if entity.getSprite() != C_NULL
					entity.getSprite().injectRenderer(this.renderer)
				end
			end
			
			for screenButton in this.scene.screenButtons
				screenButton.injectRenderer(this.renderer, this.font)
			end
			
			for textBox in this.scene.textBoxes
				textBox.initialize(this.renderer, this.zoom)
			end

			this.targetFrameRate = 60
			this.entities = this.scene.entities
			this.rigidbodies = this.scene.rigidbodies
			this.screenButtons = this.scene.screenButtons
			this.textBoxes = this.scene.textBoxes

			this.lastMousePosition = Vector2(0, 0)
			this.panCounter = Vector2(0, 0)
			this.panThreshold = 10

			if !isUsingEditor
				this.runMainLoop()
				return
			end
        end
	elseif s == :loadScene
		function (scene)
			this.scene = scene
		end
	elseif s == :runMainLoop
		function ()
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
					for rigidbody in this.rigidbodies
						rigidbody.update(deltaTime)
					end
					lastPhysicsTime =  SDL_GetTicks()

					#Rendering
					currentRenderTime = SDL_GetTicks()
					SDL_SetRenderDrawColor(this.renderer, 0, 0, 0, SDL_ALPHA_OPAQUE)
					# Clear the current render target before rendering again
					SDL_RenderClear(this.renderer)

					SceneInstance.camera.update()
					
					SDL_SetRenderDrawColor(this.renderer, 0, 255, 0, SDL_ALPHA_OPAQUE)
					for entity in this.entities
						if !entity.isActive
							continue
						end

						entity.update(deltaTime)
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
							SDL_RenderDrawLines(this.renderer, [
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS)), 
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS)),
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS + colSize.y * SCALE_UNITS)), 
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS  + colSize.y * SCALE_UNITS)), 
								SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS))], 5)
						end
					end
					for screenButton in this.screenButtons
						screenButton.render()
					end

					for textBox in this.textBoxes
						textBox.render(DEBUG)
					end
			
					if DEBUG
						# Stats to display
						text = TTF_RenderText_Blended( this.font, string("FPS: ", round(1000 / round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0))), SDL_Color(0,255,0,255) )
						text1 = TTF_RenderText_Blended( this.font, string("Frame time: ", round((startTime - lastStartTime) / SDL_GetPerformanceFrequency() * 1000.0), "ms"), SDL_Color(0,255,0,255) )
						mousePositionText = TTF_RenderText_Blended( this.font, "Raw Mouse pos: $(InputInstance.mousePosition.x),$(InputInstance.mousePosition.y)", SDL_Color(0,255,0,255) )
						scaledMousePositionText = TTF_RenderText_Blended( this.font, "Scaled Mouse pos: $(round(InputInstance.mousePosition.x/this.widthMultiplier)),$(round(InputInstance.mousePosition.y/this.heightMultiplier))", SDL_Color(0,255,0,255) )
						mousePositionWorldText = TTF_RenderText_Blended( this.font, "Mouse pos world: $(floor(Int,(InputInstance.mousePosition.x + (SceneInstance.camera.position.x * SCALE_UNITS * this.widthMultiplier * this.zoom)) / SCALE_UNITS / this.widthMultiplier / this.zoom)),$(floor(Int,( InputInstance.mousePosition.y + (SceneInstance.camera.position.y * SCALE_UNITS * this.heightMultiplier * this.zoom)) / SCALE_UNITS / this.heightMultiplier / this.zoom))", SDL_Color(0,255,0,255) )
						textTexture = SDL_CreateTextureFromSurface(this.renderer,text)
						textTexture1 = SDL_CreateTextureFromSurface(this.renderer,text1)
						mousePositionTextTexture = SDL_CreateTextureFromSurface(this.renderer,mousePositionText)
						scaledMousePositionTextTexture = SDL_CreateTextureFromSurface(this.renderer,scaledMousePositionText)
						mousePositionWorldTextTexture = SDL_CreateTextureFromSurface(this.renderer,mousePositionWorldText)
						SDL_RenderCopy(this.renderer, textTexture, C_NULL, Ref(SDL_Rect(0,0,150,50)))
						SDL_RenderCopy(this.renderer, textTexture1, C_NULL, Ref(SDL_Rect(0,50,200,50)))
						SDL_RenderCopy(this.renderer, mousePositionTextTexture, C_NULL, Ref(SDL_Rect(0,100,200,50)))
						SDL_RenderCopy(this.renderer, scaledMousePositionTextTexture, C_NULL, Ref(SDL_Rect(0,150,200,50)))
						SDL_RenderCopy(this.renderer, mousePositionWorldTextTexture, C_NULL, Ref(SDL_Rect(0,200,200,50)))
						SDL_FreeSurface(text)
						SDL_FreeSurface(text1)
						SDL_FreeSurface(mousePositionText)
						SDL_FreeSurface(mousePositionWorldText)
						SDL_FreeSurface(scaledMousePositionText)
						SDL_DestroyTexture(textTexture)
						SDL_DestroyTexture(textTexture1)
						SDL_DestroyTexture(mousePositionTextTexture)
						SDL_DestroyTexture(scaledMousePositionTextTexture)
						SDL_DestroyTexture(mousePositionWorldTextTexture)
					end
			
					SDL_RenderPresent(this.renderer)
					endTime = SDL_GetPerformanceCounter()
					elapsedMS = (endTime - startTime) / SDL_GetPerformanceFrequency() * 1000.0
					targetFrameTime = 1000/this.targetFrameRate
			
					if elapsedMS < targetFrameTime
    					SDL_Delay(round(targetFrameTime - elapsedMS))
					end
				end
			finally
				SDL2.Mix_Quit()
				SDL2.SDL_Quit()
			end
		end
	elseif s == :editorLoop
		function (update)
			x,y,w,h = Int[1], Int[1], Int[1], Int[1]
        	SDL_GetWindowPosition(this.window, pointer(x), pointer(y))
        	SDL_GetWindowSize(this.window, pointer(w), pointer(h))

			if update[2] != x[1] || update[3] != y[1]
				SDL_SetWindowPosition(this.window, update[2], update[3])
			end
			if update[4] != w[1] || update[5] != h[1]
				SDL_SetWindowSize(this.window, update[4], update[5])
				referenceHeight = 1080
				referenceWidth = 1920
				this.widthMultiplier = update[4]/referenceWidth
				this.heightMultiplier = update[5]/referenceHeight
			
				SDL_RenderSetScale(this.renderer, this.widthMultiplier * this.zoom, this.heightMultiplier * this.zoom)
			end
			if update[1][1] != C_NULL
				update[1][1].getTransform().position = Vector2f(update[1][1].getTransform().position.x, convert(Int64,update[1][2]))
			end

			DEBUG = false
			close = false

			this.lastMousePosition = InputInstance.mousePosition
			#region ============= Input
			InputInstance.pollInput()
			
			if InputInstance.quit
				close = true
			end
			DEBUG = InputInstance.debug
			
			#endregion ============== Input
				
			#Rendering
			currentRenderTime = SDL_GetTicks()
			SDL_SetRenderDrawColor(this.renderer, 0, 0, 0, SDL_ALPHA_OPAQUE)
			# Clear the current render target before rendering again
			SDL_RenderClear(this.renderer)

			cameraPosition = SceneInstance.camera.position
			if SDL_BUTTON_MIDDLE in InputInstance.mouseButtons
				xDiff = this.lastMousePosition.x - InputInstance.mousePosition.x
				xDiff = xDiff == 0 ? 0 : (xDiff > 0 ? 1 : -1)
				yDiff = this.lastMousePosition.y - InputInstance.mousePosition.y
				yDiff = yDiff == 0 ? 0 : (yDiff > 0 ? 1 : -1)

				this.panCounter = Vector2(this.panCounter.x + xDiff, this.panCounter.y + yDiff)

				if this.panCounter.x > this.panThreshold || this.panCounter.x < -this.panThreshold
					diff = this.panCounter.x > this.panThreshold ? 1 : -1
					cameraPosition = Vector2(cameraPosition.x + diff, cameraPosition.y)
					this.panCounter = Vector2(0, this.panCounter.y)
				end
				if this.panCounter.y > this.panThreshold || this.panCounter.y < -this.panThreshold
					diff = this.panCounter.y > this.panThreshold ? 1 : -1
					cameraPosition = Vector2(cameraPosition.x, cameraPosition.y + diff)
					this.panCounter = Vector2(this.panCounter.x, 0)
				end
			end
			if update[6] 
				cameraPosition = Vector2()
			end
			SceneInstance.camera.update(cameraPosition)
			
			SDL_SetRenderDrawColor(this.renderer, 0, 255, 0, SDL_ALPHA_OPAQUE)
			for entity in this.entities
				if !entity.isActive
					continue
				end

				entitySprite = entity.getSprite()
				if entitySprite != C_NULL
					entitySprite.draw()
				end

				if DEBUG && entity.getCollider() != C_NULL
					pos = entity.getTransform().getPosition()
					colSize = entity.getCollider().getSize()
					SDL_RenderDrawLines(this.renderer, [
						SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS)), 
						SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS)),
						SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS + colSize.y * SCALE_UNITS)), 
						SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS  + colSize.y * SCALE_UNITS)), 
						SDL_Point(round((pos.x - SceneInstance.camera.position.x) * SCALE_UNITS), round((pos.y - SceneInstance.camera.position.y) * SCALE_UNITS))], 5)
				end
			end
			for screenButton in this.screenButtons
				screenButton.render()
			end

			for textBox in this.textBoxes
				textBox.render(DEBUG)
			end
	
			mousePositionWorld = Vector2(floor(Int,(InputInstance.mousePosition.x + (SceneInstance.camera.position.x * SCALE_UNITS * this.widthMultiplier * this.zoom)) / SCALE_UNITS / this.widthMultiplier / this.zoom), floor(Int,( InputInstance.mousePosition.y + (SceneInstance.camera.position.y * SCALE_UNITS * this.heightMultiplier * this.zoom)) / SCALE_UNITS / this.heightMultiplier / this.zoom))
			if DEBUG
				mousePositionText = TTF_RenderText_Blended( this.font, "Raw Mouse pos: $(InputInstance.mousePosition.x),$(InputInstance.mousePosition.y)", SDL_Color(0,255,0,255) )
				scaledMousePositionText = TTF_RenderText_Blended( this.font, "Scaled Mouse pos: $(round(InputInstance.mousePosition.x/this.widthMultiplier)),$(round(InputInstance.mousePosition.y/this.heightMultiplier))", SDL_Color(0,255,0,255) )
				mousePositionWorldText = TTF_RenderText_Blended( this.font, "Mouse pos world: $(mousePositionWorld.x),$(mousePositionWorld.y)", SDL_Color(0,255,0,255) )
				mousePositionTextTexture = SDL_CreateTextureFromSurface(this.renderer,mousePositionText)
				scaledMousePositionTextTexture = SDL_CreateTextureFromSurface(this.renderer,scaledMousePositionText)
				mousePositionWorldTextTexture = SDL_CreateTextureFromSurface(this.renderer,mousePositionWorldText)
				SDL_RenderCopy(this.renderer, mousePositionTextTexture, C_NULL, Ref(SDL_Rect(0,100,200,50)))
				SDL_RenderCopy(this.renderer, scaledMousePositionTextTexture, C_NULL, Ref(SDL_Rect(0,150,200,50)))
				SDL_RenderCopy(this.renderer, mousePositionWorldTextTexture, C_NULL, Ref(SDL_Rect(0,200,200,50)))
				SDL_FreeSurface(mousePositionText)
				SDL_FreeSurface(mousePositionWorldText)
				SDL_FreeSurface(scaledMousePositionText)
				SDL_DestroyTexture(mousePositionTextTexture)
				SDL_DestroyTexture(scaledMousePositionTextTexture)
				SDL_DestroyTexture(mousePositionWorldTextTexture)
			end
			
			SDL_RenderPresent(this.renderer)
			return [this.entities, mousePositionWorld, cameraPosition]
		end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end