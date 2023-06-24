module MainLoop
	using ..JulGame
	using ..JulGame: Input, Math

	include("Enums.jl")

	include("Constants.jl")
	include("Scene.jl")

	export Main
	mutable struct Main
		assets
		cameraBackgroundColor
		entities
		events
		font
		heightMultiplier
		input
		isDraggingEntity
		lastMousePosition
		lastMousePositionWorld
		level
		mousePositionWorld
		panCounter
		panThreshold
		renderer
		rigidbodies
		scene::Scene
		screenButtons
		selectedEntityIndex
		selectedEntityUpdated
		selectedTextBoxIndex
		targetFrameRate
		textBoxes
		widthMultiplier
		window
		zoom::Float64

		function Main(zoom::Float64)
			this = new()
			
			this.zoom = zoom
			this.scene = Scene()
			this.input = Input()
			
			this.cameraBackgroundColor = [0,0,0]
			this.events = []
			this.input.scene = this.scene
			this.mousePositionWorld = Math.Vector2f()
			this.lastMousePositionWorld = Math.Vector2f()
			this.selectedEntityIndex = -1
			this.selectedTextBoxIndex = -1
			this.selectedEntityUpdated = false

			return this
		end
	end

	function Base.getproperty(this::Main, s::Symbol)
		if s == :init 
			function(isUsingEditor = false)
				

				if isUsingEditor
					this.window = SDL2.SDL_CreateWindow("Game", SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, this.scene.camera.dimensions.x, this.scene.camera.dimensions.y, SDL2.SDL_WINDOW_POPUP_MENU | SDL2.SDL_WINDOW_ALWAYS_ON_TOP | SDL2.SDL_WINDOW_BORDERLESS | SDL2.SDL_WINDOW_RESIZABLE)
				else
					this.window = SDL2.SDL_CreateWindow("Game", SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, this.scene.camera.dimensions.x, this.scene.camera.dimensions.y, SDL2.SDL_RENDERER_ACCELERATED)
				end

				SDL2.SDL_SetWindowResizable(this.window, SDL2.SDL_FALSE)
				this.renderer = SDL2.SDL_CreateRenderer(this.window, -1, SDL2.SDL_RENDERER_ACCELERATED | SDL2.SDL_RENDERER_PRESENTVSYNC)
				windowInfo = unsafe_wrap(Array, SDL2.SDL_GetWindowSurface(this.window), 1; own = false)[1]

				referenceHeight = 1080
				referenceWidth = 1920
				referenceScale = referenceHeight*referenceWidth
				currentScale = windowInfo.w*windowInfo.h
				this.heightMultiplier = windowInfo.h/referenceHeight
				this.widthMultiplier = windowInfo.w/referenceWidth
				scaleMultiplier = currentScale/referenceScale
				fontSize = 50
				
				SDL2.SDL_RenderSetScale(this.renderer, this.widthMultiplier * this.zoom, this.heightMultiplier * this.zoom)
				fontPath = joinpath(this.assets, "fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")
				this.font = SDL2.TTF_OpenFont(fontPath, fontSize)
				
				scripts = []
				for entity in this.scene.entities
					if entity.getSprite() != C_NULL
						entity.getSprite().injectRenderer(this.renderer)
					end
					for script in entity.scripts
						push!(scripts, script)
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

				this.lastMousePosition = Math.Vector2(0, 0)
				this.panCounter = Math.Vector2f(0, 0)
				this.panThreshold = .1

				if !isUsingEditor
					for script in scripts
						if script.initialize != C_NULL
							try
								script.initialize()
							catch e
								println("Error initializing script")
								Base.show_backtrace(stdout, catch_backtrace())
							end
						end
					end
				end

				if !isUsingEditor
					this.run()
					return
				end
			end
		elseif s == :loadScene
			function (scene)
				this.scene = scene
			end
		elseif s == :run
			function ()
				try

					DEBUG = false
					close = false
					startTime = 0.0
					totalFrames = 0

					#physics vars
					lastPhysicsTime = SDL2.SDL_GetTicks()
					
					while !close
						# Start frame timing
						totalFrames += 1
						lastStartTime = startTime
						startTime = SDL2.SDL_GetPerformanceCounter()
						#region ============= Input
						this.input.pollInput()
						
						if this.input.quit
							close = true
						end
						DEBUG = this.input.debug
						
						#endregion ============== Input
							
						#Physics
						currentPhysicsTime = SDL2.SDL_GetTicks()
						deltaTime = (currentPhysicsTime - lastPhysicsTime) / 1000.0
						if deltaTime > .25
							lastPhysicsTime =  SDL2.SDL_GetTicks()
							continue
						end
						for rigidbody in this.rigidbodies
							rigidbody.update(deltaTime)
						end
						lastPhysicsTime =  SDL2.SDL_GetTicks()

						#Rendering
						currentRenderTime = SDL2.SDL_GetTicks()
						SDL2.SDL_SetRenderDrawColor(this.renderer, this.cameraBackgroundColor[1], this.cameraBackgroundColor[2], this.cameraBackgroundColor[3], SDL2.SDL_ALPHA_OPAQUE)
						# Clear the current render target before rendering again
						SDL2.SDL_RenderClear(this.renderer)

						this.scene.camera.update()
						
						SDL2.SDL_SetRenderDrawColor(this.renderer, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
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
								SDL2.SDL_RenderDrawLines(this.renderer, [
									SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS)), 
									SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS)),
									SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS + colSize.y * SCALE_UNITS)), 
									SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS  + colSize.y * SCALE_UNITS)), 
									SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS))], 5)
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
							text = SDL2.TTF_RenderText_Blended( this.font, string("FPS: ", round(1000 / round((startTime - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0))), SDL2.SDL_Color(0,255,0,255) )
							text1 = SDL2.TTF_RenderText_Blended( this.font, string("Frame time: ", round((startTime - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0), "ms"), SDL2.SDL_Color(0,255,0,255) )
							mousePositionText = SDL2.TTF_RenderText_Blended( this.font, "Raw Mouse pos: $(this.input.mousePosition.x),$(this.input.mousePosition.y)", SDL2.SDL_Color(0,255,0,255) )
							scaledMousePositionText = SDL2.TTF_RenderText_Blended( this.font, "Scaled Mouse pos: $(round(this.input.mousePosition.x/this.widthMultiplier)),$(round(this.input.mousePosition.y/this.heightMultiplier))", SDL2.SDL_Color(0,255,0,255) )
							mousePositionWorldText = SDL2.TTF_RenderText_Blended( this.font, "Mouse pos world: $(floor(Int,(this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.widthMultiplier * this.zoom)) / SCALE_UNITS / this.widthMultiplier / this.zoom)),$(floor(Int,( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.heightMultiplier * this.zoom)) / SCALE_UNITS / this.heightMultiplier / this.zoom))", SDL2.SDL_Color(0,255,0,255) )
							textTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer,text)
							textTexture1 = SDL2.SDL_CreateTextureFromSurface(this.renderer,text1)
							mousePositionTextTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer,mousePositionText)
							scaledMousePositionTextTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer,scaledMousePositionText)
							mousePositionWorldTextTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer,mousePositionWorldText)
							SDL2.SDL_RenderCopy(this.renderer, textTexture, C_NULL, Ref(SDL2.SDL_Rect(0,0,150,50)))
							SDL2.SDL_RenderCopy(this.renderer, textTexture1, C_NULL, Ref(SDL2.SDL_Rect(0,50,200,50)))
							SDL2.SDL_RenderCopy(this.renderer, mousePositionTextTexture, C_NULL, Ref(SDL2.SDL_Rect(0,100,200,50)))
							SDL2.SDL_RenderCopy(this.renderer, scaledMousePositionTextTexture, C_NULL, Ref(SDL2.SDL_Rect(0,150,200,50)))
							SDL2.SDL_RenderCopy(this.renderer, mousePositionWorldTextTexture, C_NULL, Ref(SDL2.SDL_Rect(0,200,200,50)))
							SDL2.SDL_FreeSurface(text)
							SDL2.SDL_FreeSurface(text1)
							SDL2.SDL_FreeSurface(mousePositionText)
							SDL2.SDL_FreeSurface(mousePositionWorldText)
							SDL2.SDL_FreeSurface(scaledMousePositionText)
							SDL2.SDL_DestroyTexture(textTexture)
							SDL2.SDL_DestroyTexture(textTexture1)
							SDL2.SDL_DestroyTexture(mousePositionTextTexture)
							SDL2.SDL_DestroyTexture(scaledMousePositionTextTexture)
							SDL2.SDL_DestroyTexture(mousePositionWorldTextTexture)
						end
				
						SDL2.SDL_RenderPresent(this.renderer)
						endTime = SDL2.SDL_GetPerformanceCounter()
						elapsedMS = (endTime - startTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0
						targetFrameTime = 1000/this.targetFrameRate
				
						if elapsedMS < targetFrameTime
							SDL2.SDL_Delay(round(targetFrameTime - elapsedMS))
						end
					end
				finally
					SDL2.Mix_Quit()
					SDL2.SDL_Quit()
				end
			end
		elseif s == :editorLoop
			function (update)
				try
					x,y,w,h = Int[1], Int[1], Int[1], Int[1]
					SDL2.SDL_GetWindowPosition(this.window, pointer(x), pointer(y))
					SDL2.SDL_GetWindowSize(this.window, pointer(w), pointer(h))

					if update[2] != x[1] || update[3] != y[1]
							SDL2.SDL_SetWindowPosition(this.window, update[2], update[3])
					end
					if update[4] != w[1] || update[5] != h[1]
						SDL2.SDL_SetWindowSize(this.window, update[4], update[5])
						referenceHeight = 1080
						referenceWidth = 1920
						this.widthMultiplier = update[4]/referenceWidth
						this.heightMultiplier = update[5]/referenceHeight
					
						SDL2.SDL_RenderSetScale(this.renderer, this.widthMultiplier * this.zoom, this.heightMultiplier * this.zoom)
					end
					
					DEBUG = false
					close = false

					this.lastMousePosition = this.input.mousePosition
					#region ============= Input
					this.input.pollInput()
					
					if this.input.quit
						close = true
					end
					DEBUG = this.input.debug
					
					#endregion ============== Input
						
					#Rendering
					currentRenderTime = SDL2.SDL_GetTicks()
					SDL2.SDL_SetRenderDrawColor(this.renderer, 0, 0, 0, SDL2.SDL_ALPHA_OPAQUE)
					# Clear the current render target before rendering again
					SDL2.SDL_RenderClear(this.renderer)

					cameraPosition = this.scene.camera.position
					if SDL2.SDL_BUTTON_MIDDLE in this.input.mouseButtonsHeldDown
						xDiff = this.lastMousePosition.x - this.input.mousePosition.x
						xDiff = xDiff == 0 ? 0 : (xDiff > 0 ? 0.1 : -0.1)
						yDiff = this.lastMousePosition.y - this.input.mousePosition.y
						yDiff = yDiff == 0 ? 0 : (yDiff > 0 ? 0.1 : -0.1)

						this.panCounter = Math.Vector2f(this.panCounter.x + xDiff, this.panCounter.y + yDiff)

						if this.panCounter.x > this.panThreshold || this.panCounter.x < -this.panThreshold
							diff = this.panCounter.x > this.panThreshold ? 0.2 : -0.2
							cameraPosition = Math.Vector2f(cameraPosition.x + diff, cameraPosition.y)
							this.panCounter = Math.Vector2f(0, this.panCounter.y)
						end
						if this.panCounter.y > this.panThreshold || this.panCounter.y < -this.panThreshold
							diff = this.panCounter.y > this.panThreshold ? 0.2 : -0.2
							cameraPosition = Math.Vector2f(cameraPosition.x, cameraPosition.y + diff)
							this.panCounter = Math.Vector2f(this.panCounter.x, 0)
						end
					elseif this.input.getMouseButtonPressed(SDL2.SDL_BUTTON_LEFT)
						# function that selects an entity if we click on it	
						this.selectEntityWithClick()
					elseif this.input.getMouseButton(SDL2.SDL_BUTTON_LEFT) && (this.selectedEntityIndex != -1 || this.selectedTextBoxIndex != -1) && this.selectedEntityIndex != this.selectedTextBoxIndex
						# TODO: Make this work for textboxes
						snapping = false
						if this.input.getButtonHeldDown("Button_LCTRL")
							snapping = true
						end
						xDiff = this.lastMousePositionWorld.x - this.mousePositionWorld.x
						yDiff = this.lastMousePositionWorld.y - this.mousePositionWorld.y

						this.panCounter = Math.Vector2f(this.panCounter.x + xDiff, this.panCounter.y + yDiff)

						entityToMoveTransform = this.entities[this.selectedEntityIndex].getTransform()
						if this.panCounter.x > this.panThreshold || this.panCounter.x < -this.panThreshold
							diff = this.panCounter.x > this.panThreshold ? -1 : 1
							entityToMoveTransform.position = Math.Vector2f(entityToMoveTransform.getPosition().x + diff, entityToMoveTransform.getPosition().y)
							this.panCounter = Math.Vector2f(0, this.panCounter.y)
						end
						if this.panCounter.y > this.panThreshold || this.panCounter.y < -this.panThreshold
							diff = this.panCounter.y > this.panThreshold ? -1 : 1
							entityToMoveTransform.position = Math.Vector2f(entityToMoveTransform.getPosition().x, entityToMoveTransform.getPosition().y + diff)
							this.panCounter = Math.Vector2f(this.panCounter.x, 0)
						end
					elseif SDL2.SDL_BUTTON_LEFT in this.input.mouseButtonsReleased
					end

					if "SPACE" in this.input.buttonsHeldDown
						if "LEFT" in this.input.buttonsHeldDown
							this.zoom -= .01
							SDL2.SDL_RenderSetScale(this.renderer, this.widthMultiplier * this.zoom, this.heightMultiplier * this.zoom)
						elseif "RIGHT" in this.input.buttonsHeldDown
							this.zoom += .01
							SDL2.SDL_RenderSetScale(this.renderer, this.widthMultiplier * this.zoom, this.heightMultiplier * this.zoom)
						end
					elseif this.input.getButtonHeldDown("LEFT")
						cameraPosition = Math.Vector2f(cameraPosition.x - 0.25, cameraPosition.y)
					elseif this.input.getButtonHeldDown("RIGHT")
						cameraPosition = Math.Vector2f(cameraPosition.x + 0.25, cameraPosition.y)
					elseif this.input.getButtonHeldDown("DOWN")
						cameraPosition = Math.Vector2f(cameraPosition.x, cameraPosition.y + 0.25)
					elseif this.input.getButtonHeldDown("UP")
						cameraPosition = Math.Vector2f(cameraPosition.x, cameraPosition.y - 0.25)
					end
			
					if update[6] 
						cameraPosition = Math.Vector2f()
					end
					this.scene.camera.update(cameraPosition)
					
					SDL2.SDL_SetRenderDrawColor(this.renderer, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
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
							SDL2.SDL_RenderDrawLines(this.renderer, [
								SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS)), 
								SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS)),
								SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS + colSize.x * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS + colSize.y * SCALE_UNITS)), 
								SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS  + colSize.y * SCALE_UNITS)), 
								SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS))], 5)
						end
					end
					for screenButton in this.screenButtons
						screenButton.render()
					end

					for textBox in this.textBoxes
						textBox.render(DEBUG)
					end
			
					SDL2.SDL_SetRenderDrawColor(this.renderer, 255, 0, 0, SDL2.SDL_ALPHA_OPAQUE)
					selectedEntity = update[7] > 0 ? this.scene.entities[update[7]] : C_NULL
					if selectedEntity != C_NULL
						pos = selectedEntity.getTransform().getPosition()
						size = selectedEntity.getCollider() != C_NULL ? selectedEntity.getCollider().getSize() : selectedEntity.getTransform().getScale()
						SDL2.SDL_RenderDrawLines(this.renderer, [
							SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS)), 
							SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS + size.x * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS)),
							SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS + size.x * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS + size.y * SCALE_UNITS)), 
							SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS  + size.y * SCALE_UNITS)), 
							SDL2.SDL_Point(round((pos.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y - this.scene.camera.position.y) * SCALE_UNITS))], 5)
					end

					this.lastMousePositionWorld = this.mousePositionWorld
					this.mousePositionWorld = Math.Vector2(floor(Int,(this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.widthMultiplier * this.zoom)) / SCALE_UNITS / this.widthMultiplier / this.zoom), floor(Int,( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.heightMultiplier * this.zoom)) / SCALE_UNITS / this.heightMultiplier / this.zoom))
					if DEBUG
						mousePositionText = SDL2.TTF_RenderText_Blended( this.font, "Raw Mouse pos: $(this.input.mousePosition.x),$(this.input.mousePosition.y)", SDL2.SDL_Color(0,255,0,255) )
						scaledMousePositionText = SDL2.TTF_RenderText_Blended( this.font, "Scaled Mouse pos: $(round(this.input.mousePosition.x/this.widthMultiplier)),$(round(this.input.mousePosition.y/this.heightMultiplier))", SDL2.SDL_Color(0,255,0,255) )
						mousePositionWorldText = SDL2.TTF_RenderText_Blended( this.font, "Mouse pos world: $(this.mousePositionWorld.x),$(this.mousePositionWorld.y)", SDL2.SDL_Color(0,255,0,255) )
						mousePositionTextTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer,mousePositionText)
						scaledMousePositionTextTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer,scaledMousePositionText)
						mousePositionWorldTextTexture = SDL2.SDL_CreateTextureFromSurface(this.renderer,mousePositionWorldText)
						SDL2.SDL_RenderCopy(this.renderer, mousePositionTextTexture, C_NULL, Ref(SDL2.SDL_Rect(0,100,200,50)))
						SDL2.SDL_RenderCopy(this.renderer, scaledMousePositionTextTexture, C_NULL, Ref(SDL2.SDL_Rect(0,150,200,50)))
						SDL2.SDL_RenderCopy(this.renderer, mousePositionWorldTextTexture, C_NULL, Ref(SDL2.SDL_Rect(0,200,200,50)))
						SDL2.SDL_FreeSurface(mousePositionText)
						SDL2.SDL_FreeSurface(mousePositionWorldText)
						SDL2.SDL_FreeSurface(scaledMousePositionText)
						SDL2.SDL_DestroyTexture(mousePositionTextTexture)
						SDL2.SDL_DestroyTexture(scaledMousePositionTextTexture)
						SDL2.SDL_DestroyTexture(mousePositionWorldTextTexture)
					end
					
					SDL2.SDL_RenderPresent(this.renderer)
					returnData = [[this.entities, this.textBoxes, this.screenButtons], this.mousePositionWorld, cameraPosition, !this.selectedEntityUpdated ? update[7] : this.selectedEntityIndex]	
					this.selectedEntityUpdated = false
					return returnData
				catch e
					@error "$(e)"
					Base.show_backtrace(stderr, catch_backtrace())
				end
			end
		elseif s == :createNewEntity
			function ()
				this.level.createNewEntity()
			end
		elseif s == :createNewTextBox
			function (fontPath)
				this.level.createNewTextBox(fontPath)
			end
		elseif s == :selectEntityWithClick
			function ()
				entityIndex = 1
				for entity in this.entities
					size = entity.getCollider() != C_NULL ? entity.getCollider().getSize() : entity.getTransform().getScale()
					if this.mousePositionWorld.x >= entity.getTransform().getPosition().x && this.mousePositionWorld.x <= entity.getTransform().getPosition().x + size.x - 1.0 && this.mousePositionWorld.y >= entity.getTransform().getPosition().y && this.mousePositionWorld.y <= entity.getTransform().getPosition().y + size.y
						this.selectedEntityIndex = entityIndex
						this.selectedTextBoxIndex = -1
						this.selectedEntityUpdated = true
						return
					end
					entityIndex += 1
				end
				textBoxIndex = 1
				for textBox in this.textBoxes
					if this.mousePositionWorld.x >= textBox.position.x && this.mousePositionWorld.x <= textBox.position.x + textBox.size.x && this.mousePositionWorld.y >= textBox.position.y && this.mousePositionWorld.y <= textBox.position.y + textBox.size.y
						this.selectedTextBoxIndex = textBoxIndex
						this.selectedEntityIndex = -1

						return
					end
					textBoxIndex += 1
				end
				this.selectedEntityIndex = -1
			end
		else
			try
				getfield(this, s)
			catch e
				println(e)
			end
		end
	end
end
