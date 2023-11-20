module MainLoop
	using ..JulGame
	using ..JulGame: Input, Math, UI

	include("Enums.jl")
	include("Constants.jl")
	include("Scene.jl")

	export Main
	mutable struct Main
		assets
		cameraBackgroundColor
		debugTextBoxes
		entities::Array
		events
		font
		globals
		heightMultiplier
		input
		isDraggingEntity
		lastMousePosition
		lastMousePositionWorld
		level
		mousePositionWorld
		mousePositionWorldRaw
		panCounter
		panThreshold
		renderer
		rigidbodies
		scene::Scene
		screenButtons
		selectedEntityIndex
		selectedEntityUpdated
		selectedTextBoxIndex
		screenDimensions
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
			this.debugTextBoxes = []
			this.events = []
			this.input.scene = this.scene
			this.mousePositionWorld = Math.Vector2f()
			this.mousePositionWorldRaw = Math.Vector2f()
			this.lastMousePositionWorld = Math.Vector2f()
			this.selectedEntityIndex = -1
			this.selectedTextBoxIndex = -1
			this.selectedEntityUpdated = false
			this.screenDimensions = C_NULL
			this.globals = []
			
			return this
		end
	end

	function Base.getproperty(this::Main, s::Symbol)
		if s == :init 											
			function(isUsingEditor = false, dimensions = C_NULL)
				
				this.screenDimensions = dimensions != C_NULL ? dimensions : this.scene.camera.dimensions
				if isUsingEditor
					this.window = SDL2.SDL_CreateWindow("Game", SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, this.screenDimensions.x, this.screenDimensions.y, SDL2.SDL_WINDOW_POPUP_MENU | SDL2.SDL_WINDOW_ALWAYS_ON_TOP | SDL2.SDL_WINDOW_BORDERLESS | SDL2.SDL_WINDOW_RESIZABLE)
				else
					this.window = SDL2.SDL_CreateWindow("Game", SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, this.screenDimensions.x, this.screenDimensions.y, SDL2.SDL_RENDERER_ACCELERATED | SDL2.SDL_WINDOW_RESIZABLE)
				end

				this.renderer = SDL2.SDL_CreateRenderer(this.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
				SDL2.SDL_RenderSetViewport(this.renderer, Ref(SDL2.SDL_Rect(dimensions.x/2 - this.scene.camera.dimensions.x/2, dimensions.y/2 - this.scene.camera.dimensions.y/2, this.scene.camera.dimensions.x, this.scene.camera.dimensions.y)))
				windowInfo = unsafe_wrap(Array, SDL2.SDL_GetWindowSurface(this.window), 1; own = false)[1]

				referenceHeight = this.screenDimensions.x
				referenceWidth = this.screenDimensions.y
				fontSize = 50
				
				SDL2.SDL_RenderSetScale(this.renderer, this.zoom, this.zoom)
				fontPath = joinpath(this.assets, "fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")
				this.font = SDL2.TTF_OpenFont(fontPath, fontSize)
				
				scripts = []
				for entity in this.scene.entities
					for script in entity.scripts
						push!(scripts, script)
					end
				end
				
				for screenButton in this.scene.screenButtons
					screenButton.injectRenderer(this.renderer, this.font)
				end
				
				this.entities = this.scene.entities
				this.rigidbodies = this.scene.rigidbodies
				this.screenButtons = this.scene.screenButtons
				this.textBoxes = this.scene.textBoxes
				this.lastMousePosition = Math.Vector2(0, 0)
				this.panCounter = Math.Vector2f(0, 0)
				this.panThreshold = .1

				if !isUsingEditor
					for script in scripts
						try
							script.initialize()
						catch e
							if typeof(e) != ErrorException || !contains(e.msg, "initialize")
								println("Error initializing script")
								println(e)
								Base.show_backtrace(stdout, catch_backtrace())
							end
						end	
					end
				end

				if !isUsingEditor
					this.fullLoop()
					return
				end
			end
		elseif s == :loadScene
			function (scene)
				this.scene = scene
			end
		elseif s == :fullLoop
			function ()
				try
					DEBUG = false
					close = Ref(Bool(false))
					startTime = Ref(UInt64(0))
					lastPhysicsTime = Ref(UInt32(SDL2.SDL_GetTicks()))

					while !close[]
						this.gameLoop(startTime, lastPhysicsTime, close)
					end
				finally
					for entity in this.scene.entities
						for script in entity.scripts
							try
								script.onShutDown()
							catch e
								if typeof(e) != ErrorException || !contains(e.msg, "onShutDown")
									println("Error shutting down script")
									println(e)
									Base.show_backtrace(stdout, catch_backtrace())
								end
							end	
						end
					end
					SDL2.Mix_Quit()
					SDL2.SDL_Quit()
				end
			end
		elseif s == :gameLoop
			function (startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt32} = Ref(UInt32(0)), close::Ref{Bool} = Ref(Bool(false)), isEditor::Bool = false, update::Union{Ptr{Nothing}, Array{Any}} = C_NULL)
				try
					lastStartTime = startTime[]
					startTime[] = SDL2.SDL_GetPerformanceCounter()

					x,y,w,h = Int[1], Int[1], Int[1], Int[1]
					if isEditor && update != C_NULL
						SDL2.SDL_GetWindowPosition(this.window, pointer(x), pointer(y))
						SDL2.SDL_GetWindowSize(this.window, pointer(w), pointer(h))

						if update[2] != x[1] || update[3] != y[1]
								SDL2.SDL_SetWindowPosition(this.window, update[2], update[3])
						end
						if update[4] != w[1] || update[5] != h[1]
							SDL2.SDL_SetWindowSize(this.window, update[4], update[5])
							referenceHeight = 1080
							referenceWidth = 1920
							#this.widthMultiplier = update[4]/referenceWidth
							#this.heightMultiplier = update[5]/referenceHeight
						
							SDL2.SDL_RenderSetScale(this.renderer, this.zoom, this.zoom)
						end
					end

					DEBUG = false
					#region =============    Input
					this.lastMousePosition = this.input.mousePosition
					this.input.pollInput()
					
					if this.input.quit && !isEditor
						close[] = true
					end
					DEBUG = this.input.debug

					cameraPosition = Math.Vector2f()
					if isEditor
						cameraPosition = this.handleEditorInputsCamera()
					end

					#endregion ============= Input

					#region =============    Physics
					if !isEditor
						currentPhysicsTime = SDL2.SDL_GetTicks()
						deltaTime = (currentPhysicsTime - lastPhysicsTime[]) / 1000.0
						if deltaTime > .25
							lastPhysicsTime[] =  SDL2.SDL_GetTicks()
							return
						end
						for rigidbody in this.rigidbodies
							rigidbody.update(deltaTime)
						end
						lastPhysicsTime[] =  SDL2.SDL_GetTicks()
					end
					#endregion ============= Physics


					#region =============    Rendering
					currentRenderTime = SDL2.SDL_GetTicks()
					SDL2.SDL_SetRenderDrawColor(this.renderer, 0, 0, 0, SDL2.SDL_ALPHA_OPAQUE)
					# Clear the current render target before rendering again
					SDL2.SDL_RenderClear(this.renderer)

					this.scene.camera.update()
				
					
					SDL2.SDL_SetRenderDrawColor(this.renderer, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
					for entity in this.entities
						if !entity.isActive
							continue
						end

						if !isEditor
							entity.update(deltaTime)
							entityAnimator = entity.getAnimator()
							if entityAnimator != C_NULL
								entityAnimator.update(currentRenderTime, deltaTime)
							end
						end
						
						entitySprite = entity.getSprite()
						if entitySprite != C_NULL
							entitySprite.draw()
						end
						entityShape = entity.getShape()
						if entityShape != C_NULL
							entityShape.draw()
						end

						if DEBUG && entity.getCollider() != C_NULL
							pos = entity.getTransform().getPosition()
							colSize = entity.getCollider().getSize()
							colOffset = entity.getCollider().offset
							SDL2.SDL_RenderDrawRect( this.renderer, Ref(SDL2.SDL_Rect(round((pos.x + colOffset.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y + colOffset.y - this.scene.camera.position.y) * SCALE_UNITS), round(colSize.x * SCALE_UNITS), round(colSize.y * SCALE_UNITS))))
						end
					end
					#endregion ============= Rendering

					#region ============= UI
					for screenButton in this.screenButtons
						screenButton.render()
					end

					for textBox in this.textBoxes
						textBox.render(DEBUG)
					end
					#endregion ============= UI

					SDL2.SDL_SetRenderDrawColor(this.renderer, 255, 0, 0, SDL2.SDL_ALPHA_OPAQUE)
					if isEditor && update != C_NULL
						selectedEntity = update[7] > 0 ? this.scene.entities[update[7]] : C_NULL
						if selectedEntity != C_NULL
							pos = selectedEntity.getTransform().getPosition()
							size = selectedEntity.getCollider() != C_NULL ? selectedEntity.getCollider().getSize() : selectedEntity.getTransform().getScale()
							offset = selectedEntity.getCollider() != C_NULL ? selectedEntity.getCollider().getOffset : Math.Vector2f()
							SDL2.SDL_RenderDrawRect( this.renderer, Ref(SDL2.SDL_Rect(round((pos.x + offset.x - this.scene.camera.position.x) * SCALE_UNITS), round((pos.y + offset.y - this.scene.camera.position.y) * SCALE_UNITS), round(size.x * SCALE_UNITS), round(size.x * SCALE_UNITS))))
						end
					end
					this.lastMousePositionWorld = this.mousePositionWorld
					this.mousePositionWorldRaw = Math.Vector2f((this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom, ( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom)
					this.mousePositionWorld = Math.Vector2(floor(Int,(this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom), floor(Int,( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom))
					
					#region ================ Debug
					if DEBUG
						# Stats to display
						statTexts = [
							"FPS: $(round(1000 / round((startTime[] - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0)))",
							"Frame time: $(round((startTime[] - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0)) ms",
							"Raw Mouse pos: $(this.input.mousePosition.x),$(this.input.mousePosition.y)",
							"Mouse pos world: $(this.mousePositionWorld.x),$(this.mousePositionWorld.y)"
						]

						if length(this.debugTextBoxes) == 0
							fontPath = joinpath(this.assets, "fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")

							for i = 1:length(statTexts)
								push!(this.debugTextBoxes, UI.TextBoxModule.TextBox("Debug text", "", fontPath, 40, Math.Vector2(0, 35 * i), Math.Vector2(100, 10 * i), Math.Vector2(0, 0), statTexts[i], false, true))
							end
						else
							for i = 1:length(this.debugTextBoxes)
								this.debugTextBoxes[i].updateText(statTexts[i])
								this.debugTextBoxes[i].render(false)
							end
						end
					end
					#endregion ============= Debug

					SDL2.SDL_RenderPresent(this.renderer)
					endTime = SDL2.SDL_GetPerformanceCounter()
					elapsedMS = (endTime - startTime[]) / SDL2.SDL_GetPerformanceFrequency() * 1000.0
					targetFrameTime = 1000/this.targetFrameRate
			
					if elapsedMS < targetFrameTime && !isEditor
						SDL2.SDL_Delay(round(targetFrameTime - elapsedMS))
					end

					if isEditor && update != C_NULL
						returnData = [[this.entities, this.textBoxes, this.screenButtons], this.mousePositionWorld, cameraPosition, !this.selectedEntityUpdated ? update[7] : this.selectedEntityIndex, this.input.isWindowFocused]	
						this.selectedEntityUpdated = false
						return returnData
					end
				catch e
					println("$(e)")
					Base.show_backtrace(stderr, catch_backtrace())
				end
			end
		elseif s == :handleEditorInputsCamera
			function (update::Union{Ptr{Nothing}, Array{Any}} = C_NULL)
				#Rendering
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
					if this.input.getButtonHeldDown("LCTRL")
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
				elseif !this.input.getMouseButton(SDL2.SDL_BUTTON_LEFT) && (this.selectedEntityIndex != -1)
					if this.input.getButtonHeldDown("LCTRL") && this.input.getButtonPressed("D")
						push!(this.entities, deepcopy(this.entities[this.selectedEntityIndex]))
						this.selectedEntityIndex = length(this.entities)
					end
				elseif SDL2.SDL_BUTTON_LEFT in this.input.mouseButtonsReleased
				end

				if "SPACE" in this.input.buttonsHeldDown
					if "LEFT" in this.input.buttonsHeldDown
						this.zoom -= .01
						SDL2.SDL_RenderSetScale(this.renderer, this.widthMultiplier * this.zoom, this.zoom)
					elseif "RIGHT" in this.input.buttonsHeldDown
						this.zoom += .01
						SDL2.SDL_RenderSetScale(this.renderer, this.widthMultiplier * this.zoom, this.zoom)
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
		
				if update != C_NULL && update[6] 
					cameraPosition = Math.Vector2f()
				end
				this.scene.camera.update(cameraPosition)
				
				return cameraPosition
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
				entityIndex = 0
				for entity in this.entities
					entityIndex += 1
					size = entity.getCollider() != C_NULL ? entity.getCollider().getSize() : entity.getTransform().getScale()
					if this.mousePositionWorldRaw.x >= entity.getTransform().getPosition().x && this.mousePositionWorldRaw.x <= entity.getTransform().getPosition().x + size.x && this.mousePositionWorldRaw.y >= entity.getTransform().getPosition().y && this.mousePositionWorldRaw.y <= entity.getTransform().getPosition().y + size.y
						
						# println("pos x: $(entity.getTransform().getPosition().x)")
						# println("mouse pos raw x: $(this.mousePositionWorldRaw.x)")
						# println("mouse pos x: $(this.mousePositionWorld.x)")
						# println("size x: $(size.x)")
						# println("pos y: $(entity.getTransform().getPosition().y)")
						# println("mouse pos raw y: $(this.mousePositionWorldRaw.y)")
						# println("mouse pos y: $(this.mousePositionWorld.y)")
						# println("size y: $(size.y)")
						if this.selectedEntityIndex == entityIndex
							continue
						end
						this.selectedEntityIndex = entityIndex
						this.selectedTextBoxIndex = -1
						this.selectedEntityUpdated = true
						return
					end
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
		elseif s == :minimizeWindow
			function ()
				SDL2.SDL_MinimizeWindow(this.window)
			end
		elseif s == :restoreWindow
			function ()
				SDL2.SDL_RestoreWindow(this.window)
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