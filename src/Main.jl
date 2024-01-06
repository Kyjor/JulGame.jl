module MainLoop
	using ..JulGame
	using ..JulGame: Input, Math, UI

	include("Enums.jl")
	include("Constants.jl")
	include("Scene.jl")

	export Main
	mutable struct Main
		assets::String
		autoScaleZoom::Bool
		cameraBackgroundColor
		close::Bool
		currentTestTime::Float64
		debugTextBoxes
		events
		globals
		input
		isDraggingEntity::Bool
		lastMousePosition
		lastMousePositionWorld
		level
		mousePositionWorld
		mousePositionWorldRaw
		optimizeSpriteRendering::Bool
		panCounter
		panThreshold
		renderer
		scene::Scene
		selectedEntityIndex
		selectedEntityUpdated
		selectedTextBoxIndex
		screenDimensions
		shouldChangeScene::Bool
		spriteLayers::Dict
		targetFrameRate
		testLength::Float64
		testMode::Bool
		window
		windowName::String
		zoom::Float64

		function Main(zoom::Float64)
			this = new()

			this.zoom = zoom
			this.scene = Scene()
			this.input = Input()

			this.cameraBackgroundColor = [0,0,0]
			this.close = false
			this.debugTextBoxes = []
			this.events = []
			this.input.scene = this.scene
			this.mousePositionWorld = Math.Vector2f()
			this.mousePositionWorldRaw = Math.Vector2f()
			this.lastMousePositionWorld = Math.Vector2f()
			this.optimizeSpriteRendering = false
			this.selectedEntityIndex = -1
			this.selectedTextBoxIndex = -1
			this.selectedEntityUpdated = false
			this.screenDimensions = C_NULL
			this.shouldChangeScene = false
			this.globals = []
			this.input.main = this

			this.currentTestTime = 0.0
			this.testMode = false
			this.testLength = 0.0

			return this
		end
	end

	function Base.getproperty(this::Main, s::Symbol)
		if s == :init
			function(isUsingEditor = false, dimensions = C_NULL, isResizable::Bool = false, autoScaleZoom::Bool = true)

				PrepareWindow(this, isUsingEditor, dimensions, isResizable, autoScaleZoom)
				InitializeScriptsAndComponents(this, isUsingEditor)

				if !isUsingEditor
					this.fullLoop()
					return
				end
			end
		elseif s == :initializeNewScene
			function()
				this.level.changeScene()
				InitializeScriptsAndComponents(this, false)

				if true
					this.fullLoop()
					return
				end
			end
		elseif s == :fullLoop
			function ()
				try
					DEBUG = false
					this.close = false
					startTime = Ref(UInt64(0))
					lastPhysicsTime = Ref(UInt64(SDL2.SDL_GetTicks()))

					while !this.close
						try
							GameLoop(this, startTime, lastPhysicsTime, false, C_NULL)
						catch e
							if this.testMode
								throw(e)
							else
								println(e)
								Base.show_backtrace(stdout, catch_backtrace())
							end
						end
						if this.testMode && this.currentTestTime >= this.testLength
							break
						end
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
					if !this.shouldChangeScene
						SDL2.SDL_DestroyRenderer(this.renderer)
						SDL2.SDL_DestroyWindow(this.window)
						SDL2.SDL_Quit()
					else
						this.shouldChangeScene = false
						this.initializeNewScene()
					end
				end
			end
		elseif s == :gameLoop
			function (startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), isEditor::Bool = false, update::Union{Ptr{Nothing}, Vector{Any}} = C_NULL)
				return GameLoop(this, startTime, lastPhysicsTime, isEditor, update)
			end
		elseif s == :handleEditorInputsCamera
			function (update::Union{Ptr{Nothing}, Vector{Any}} = C_NULL)
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
		
					entityToMoveTransform = this.scene.entities[this.selectedEntityIndex].transform
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
						push!(this.scene.entities, deepcopy(this.scene.entities[this.selectedEntityIndex]))
						this.selectedEntityIndex = length(this.scene.entities)
					end
				elseif SDL2.SDL_BUTTON_LEFT in this.input.mouseButtonsReleased
				end
		
				if "SPACE" in this.input.buttonsHeldDown
					if "LEFT" in this.input.buttonsHeldDown
						this.zoom -= .01
						SDL2.SDL_RenderSetScale(this.renderer, this.zoom, this.zoom)
					elseif "RIGHT" in this.input.buttonsHeldDown
						this.zoom += .01
						SDL2.SDL_RenderSetScale(this.renderer, this.zoom, this.zoom)
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
				for entity in this.scene.entities
					entityIndex += 1
					size = entity.collider != C_NULL ? entity.collider.getSize() : entity.transform.getScale()
					if this.mousePositionWorldRaw.x >= entity.transform.getPosition().x && this.mousePositionWorldRaw.x <= entity.transform.getPosition().x + size.x && this.mousePositionWorldRaw.y >= entity.transform.getPosition().y && this.mousePositionWorldRaw.y <= entity.transform.getPosition().y + size.y
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
				for textBox in this.scene.textBoxes
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
		elseif s == :updateViewport
			function (x,y)
				if !this.autoScaleZoom
					return
				end
				this.scaleZoom(x,y)
				SDL2.SDL_RenderClear(this.renderer)
				SDL2.SDL_RenderSetScale(this.renderer, 1.0, 1.0)	
				this.scene.camera.startingCoordinates = Math.Vector2f(round(x/2) - round(this.scene.camera.dimensions.x/2*this.zoom), round(y/2) - round(this.scene.camera.dimensions.y/2*this.zoom))																																				
				SDL2.SDL_RenderSetViewport(this.renderer, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.dimensions.x*this.zoom), round(this.scene.camera.dimensions.y*this.zoom))))
				SDL2.SDL_RenderSetScale(this.renderer, this.zoom, this.zoom)
			end
		elseif s == :scaleZoom
			function (x,y)
				if this.autoScaleZoom
					targetRatio = this.scene.camera.dimensions.x/this.scene.camera.dimensions.y
					if this.scene.camera.dimensions.x == max(this.scene.camera.dimensions.x, this.scene.camera.dimensions.y)
						for i in x:-1:this.scene.camera.dimensions.x
							value = i/targetRatio
							isInt = isinteger(value) || (isa(value, AbstractFloat) && trunc(value) == value)
							if isInt && value <= y
								this.zoom = i/this.scene.camera.dimensions.x
								break
							end
						end
					else
						for i in y:-1:this.scene.camera.dimensions.y
							value = i*targetRatio
							isInt = isinteger(value) || (isa(value, AbstractFloat) && trunc(value) == value)
							if isInt && value <= x
								this.zoom = i/this.scene.camera.dimensions.y
								break
							end
						end
					end
				end
			end
		else
			try
				getfield(this, s)
			catch e
				println(e)
				Base.show_backtrace(stdout, catch_backtrace())
			end
		end
	end

	function PrepareWindow(this::Main, isUsingEditor::Bool = false, dimensions = C_NULL, isResizable::Bool = false, autoScaleZoom::Bool = true)
		if dimensions == Math.Vector2()
			displayMode = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
			SDL2.SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			dimensions = Math.Vector2(displayMode[1].w, displayMode[1].h)
		end
		this.autoScaleZoom = autoScaleZoom
		this.scaleZoom(dimensions.x,dimensions.y)

		this.screenDimensions = dimensions != C_NULL ? dimensions : this.scene.camera.dimensions

		flags = SDL2.SDL_RENDERER_ACCELERATED |
		(isUsingEditor ? (SDL2.SDL_WINDOW_POPUP_MENU | SDL2.SDL_WINDOW_ALWAYS_ON_TOP | SDL2.SDL_WINDOW_BORDERLESS) : 0) |
		(isResizable || isUsingEditor ? SDL2.SDL_WINDOW_RESIZABLE : 0) |
		(dimensions == Math.Vector2() ? SDL2.SDL_WINDOW_FULLSCREEN_DESKTOP : 0)

		this.window = SDL2.SDL_CreateWindow(this.windowName, SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, this.screenDimensions.x, this.screenDimensions.y, flags)

		this.renderer = SDL2.SDL_CreateRenderer(this.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
		JulGame.Renderer = this.renderer 

		this.scene.camera.startingCoordinates = Math.Vector2f(round(dimensions.x/2) - round(this.scene.camera.dimensions.x/2*this.zoom), round(dimensions.y/2) - round(this.scene.camera.dimensions.y/2*this.zoom))																																				
		SDL2.SDL_RenderSetViewport(this.renderer, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.dimensions.x*this.zoom), round(this.scene.camera.dimensions.y*this.zoom))))
		# windowInfo = unsafe_wrap(Array, SDL2.SDL_GetWindowSurface(this.window), 1; own = false)[1]

		SDL2.SDL_RenderSetScale(this.renderer, this.zoom, this.zoom)
	end

function InitializeScriptsAndComponents(this::Main, isUsingEditor::Bool = false)
	scripts = []
	for entity in this.scene.entities
		for script in entity.scripts
			push!(scripts, script)
		end
	end

	for textBox in this.scene.textBoxes
		textBox.initialize()
	end
	for screenButton in this.scene.screenButtons
		screenButton.initialize()
	end

	this.lastMousePosition = Math.Vector2(0, 0)
	this.panCounter = Math.Vector2f(0, 0)
	this.panThreshold = .1

	this.spriteLayers = BuildSpriteLayers(this)

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
end

export ChangeScene
function ChangeScene(sceneFileName::String)
	MAIN.close = true
	MAIN.shouldChangeScene = true
	#destroy current scene 
	#println("Entities before destroying: ", length(MAIN.scene.entities))
	count = 0
	skipcount = 0
	persistentEntities = []	
	for entity in MAIN.scene.entities
		if entity.persistentBetweenScenes
			#println("Persistent entity: ", entity.name, " with id: ", entity.id)
			push!(persistentEntities, entity)
			skipcount += 1
			continue
		end

		DestroyEntityComponents(entity)
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
		count += 1
	end
	# println("Destroyed $count entities")
	# println("Skipped $skipcount entities")

	# println("Entities left after destroying: ", length(persistentEntities))

	#Todo
	#delete all textboxes
	# for textBox in MAIN.scene.textBoxes
	# 	textBox.destroy()
	# 	delete!(MAIN.scene.textBoxes, textBox)
	# end

	#Todo
	# #delete all screen buttons
	# for screenButton in MAIN.scene.screenButtons
	# 	screenButton.destroy()
	# 	delete!(MAIN.scene.screenButtons, screenButton)
	# end

	#load new scene 
	camera = MAIN.scene.camera
	MAIN.scene = Scene()
	MAIN.scene.entities = persistentEntities
	MAIN.scene.camera = camera
	MAIN.level.scene = sceneFileName
end

"""
BuildSpriteLayers(main::Main)

Builds the sprite layers for the main game.

# Arguments
- `main::Main`: The main game object.

"""
function BuildSpriteLayers(main::Main)
	layerDict = Dict{String, Array}()
	layerDict["sort"] = []
	for entity in main.scene.entities
		entitySprite = entity.sprite
		if entitySprite != C_NULL
			if !haskey(layerDict, "$(entitySprite.layer)")
				push!(layerDict["sort"], entitySprite.layer)
				layerDict["$(entitySprite.layer)"] = [entitySprite]
			else
				push!(layerDict["$(entitySprite.layer)"], entitySprite)
			end
		end
	end
	sort!(layerDict["sort"])

	return layerDict
end

export DestroyEntity
"""
DestroyEntity(entity)

Destroy the specified entity. This removes the entity's sprite from the sprite layers so that it is no longer rendered. It also removes the entity's rigidbody from the main game's rigidbodies array.

# Arguments
- `entity`: The entity to be destroyed.
"""
function DestroyEntity(entity)
	for i = 1:length(MAIN.scene.entities)
		if MAIN.scene.entities[i] == entity
			#	println("Destroying entity: ", entity.name, " with id: ", entity.id, " at index: ", index)
			DestroyEntityComponents(entity)
			deleteat!(MAIN.scene.entities, i)
			break
		end
	end
end

function DestroyEntityComponents(entity)
	entitySprite = entity.sprite
	if entitySprite != C_NULL
		for j = 1:length(MAIN.spriteLayers["$(entitySprite.layer)"])
			if MAIN.spriteLayers["$(entitySprite.layer)"][j] == entitySprite
				entitySprite.destroy()
				deleteat!(MAIN.spriteLayers["$(entitySprite.layer)"], j)
				break
			end
		end
	end

	entityRigidbody = entity.rigidbody
	if entityRigidbody != C_NULL
		for j = 1:length(MAIN.scene.rigidbodies)
			if MAIN.scene.rigidbodies[j] == entityRigidbody
				deleteat!(MAIN.scene.rigidbodies, j)
				break
			end
		end
	end

	entityCollider = entity.collider
	if entityCollider != C_NULL
		for j = 1:length(MAIN.scene.colliders)
			if MAIN.scene.colliders[j] == entityCollider
				deleteat!(MAIN.scene.colliders, j)
				break
			end
		end
	end

	entitySoundSource = entity.soundSource
	if entitySoundSource != C_NULL
		entitySoundSource.unloadSound()
	end
end

export CreateEntity
"""
CreateEntity(entity)

Create a new entity. Adds the entity to the main game's entities array and adds the entity's sprite to the sprite layers so that it is rendered.

# Arguments
- `entity`: The entity to create.

"""
function CreateEntity(entity)
	push!(MAIN.scene.entities, entity)
	if entity.sprite != C_NULL
		if !haskey(MAIN.spriteLayers, "$(entity.sprite.layer)")
			push!(MAIN.spriteLayers["sort"], entity.sprite.layer)
			MAIN.spriteLayers["$(entity.sprite.layer)"] = [entity.sprite]
			sort!(MAIN.spriteLayers["sort"])
		else
			push!(MAIN.spriteLayers["$(entity.sprite.layer)"], entity.sprite)
		end
	end

	if entity.rigidbody != C_NULL
		push!(MAIN.scene.rigidbodies, entity.rigidbody)
	end

	if entity.collider != C_NULL
		push!(MAIN.scene.colliders, entity.collider)
	end

	return entity
end

"""
GameLoop(this, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), close::Ref{Bool} = Ref(Bool(false)), isEditor::Bool = false, update::Union{Ptr{Nothing}, Vector{Any}} = C_NULL)

Runs the game loop.

Parameters:
- `this`: The main struct.
- `startTime`: A reference to the start time of the game loop.
- `lastPhysicsTime`: A reference to the last physics time of the game loop.
- `isEditor`: A boolean indicating whether the game loop is running in editor mode.
- `update`: An array containing information to pass back to the editor.

"""
function GameLoop(this, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), isEditor::Bool = false, update::Union{Ptr{Nothing}, Vector{Any}} = C_NULL)
        try
			lastStartTime = startTime[]
			startTime[] = SDL2.SDL_GetPerformanceCounter()

			x,y,w,h = Int32[1], Int32[1], Int32[1], Int32[1]
			if isEditor && update != C_NULL
				SDL2.SDL_GetWindowPosition(this.window, pointer(x), pointer(y))
				SDL2.SDL_GetWindowSize(this.window, pointer(w), pointer(h))

				if update[2] != x[1] || update[3] != y[1]
					if (update[2] < 2147483648 && update[3] < 2147483648)
						SDL2.SDL_SetWindowPosition(this.window, round(update[2]), round(update[3]))
					end
				end
				if update[4] != w[1] || update[5] != h[1]
					SDL2.SDL_SetWindowSize(this.window, round(update[4]), round(update[5]))
					SDL2.SDL_RenderSetScale(this.renderer, this.zoom, this.zoom)
				end
			end

			DEBUG = false
			#region =============    Input
			this.lastMousePosition = this.input.mousePosition
			this.input.pollInput()

			if this.input.quit && !isEditor
				this.close = true
			end
			DEBUG = this.input.debug

			cameraPosition = Math.Vector2f()
			if isEditor
				cameraPosition = this.handleEditorInputsCamera()
			end

			#endregion ============= Input

			SDL2.SDL_RenderClear(this.renderer)

			#region =============    Physics
			if !isEditor
				currentPhysicsTime = SDL2.SDL_GetTicks()
				deltaTime = (currentPhysicsTime - lastPhysicsTime[]) / 1000.0

				this.currentTestTime += deltaTime
				if deltaTime > .25
					lastPhysicsTime[] =  SDL2.SDL_GetTicks()
					return
				end
				for rigidbody in this.scene.rigidbodies
					try
						rigidbody.update(deltaTime)
					catch e
						println(rigidbody.parent.name, " with id: ", rigidbody.parent.id, " has a problem with it's rigidbody")
						rethrow(e)
					end
				end
				lastPhysicsTime[] =  currentPhysicsTime
			end
			#endregion ============= Physics


			#region =============    Rendering
			currentRenderTime = SDL2.SDL_GetTicks()
			SDL2.SDL_SetRenderDrawColor(this.renderer, 0, 0, 0, SDL2.SDL_ALPHA_OPAQUE)
			this.scene.camera.update()

			for entity in this.scene.entities
				if !entity.isActive
					continue
				end

				if !isEditor
					try
						entity.update(deltaTime)
						if this.close
							return
						end
					catch e
						println(entity.name, " with id: ", entity.id, " has a problem with it's update")
						rethrow(e)
					end
					entityAnimator = entity.animator
					if entityAnimator != C_NULL
						entityAnimator.update(currentRenderTime, deltaTime)
					end
				end
			end

			if !isEditor
				skipcount = 0
				rendercount = 0
				# println("position: $(this.scene.camera.position) offset: $(this.scene.camera.offset) dimensions: $(this.scene.camera.dimensions)")
				 #println("dimensions: $(this.scene.camera.dimensions)")
				for layer in this.spriteLayers["sort"]
					for sprite in this.spriteLayers["$(layer)"]
						# get camera size and position and only render if the sprite is within the camera's view
						cameraPosition = this.scene.camera.position
						cameraSize = this.scene.camera.dimensions
						spritePosition = sprite.parent.transform.getPosition()
						spriteSize = sprite.parent.transform.getScale()
						
						if ((spritePosition.x + spriteSize.x) < cameraPosition.x || spritePosition.y < cameraPosition.y || spritePosition.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || spritePosition.y > cameraPosition.y + cameraSize.y/SCALE_UNITS) && sprite.isWorldEntity && this.optimizeSpriteRendering 
							skipcount += 1
							continue
						end
						rendercount += 1
						try
							sprite.draw()
						catch e
							println(sprite.parent.name, " with id: ", sprite.parent.id, " has a problem with it's sprite")
							rethrow(e)
						end
					end
				end
				#println("Skipped $skipcount, rendered $rendercount")
			end

			for entity in this.scene.entities
				if !entity.isActive
					continue
				end


				if isEditor
					entitySprite = entity.sprite
					if entitySprite != C_NULL
						try
							entitySprite.draw()
						catch e
							println(entity.name, " with id: ", entity.id, " has an error in its sprite")
							rethrow(e)
						end
					end
				end

				entityShape = entity.shape
				if entityShape != C_NULL
					entityShape.draw()
				end

				if DEBUG && entity.collider != C_NULL
					SDL2.SDL_SetRenderDrawColor(this.renderer, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
					pos = entity.transform.getPosition()
					collider = entity.collider
					if collider.getType() == "CircleCollider"
						SDL2E.SDL_RenderDrawCircle(
							round(Int32, (pos.x - this.scene.camera.position.x) * SCALE_UNITS - ((entity.transform.getScale().x * SCALE_UNITS - SCALE_UNITS) / 2)), 
							round(Int32, (pos.y - this.scene.camera.position.y) * SCALE_UNITS - ((entity.transform.getScale().y * SCALE_UNITS - SCALE_UNITS) / 2)), 
							round(Int32, collider.diameter/2 * SCALE_UNITS))
					else
						colSize = collider.getSize()
						colOffset = collider.offset
						SDL2.SDL_RenderDrawRect( this.renderer, 
						Ref(SDL2.SDL_Rect(round((pos.x + colOffset.x - this.scene.camera.position.x) * SCALE_UNITS - ((entity.transform.getScale().x * SCALE_UNITS - SCALE_UNITS) / 2) - ((colSize.x * SCALE_UNITS - SCALE_UNITS) / 2)), 
						round((pos.y + colOffset.y - this.scene.camera.position.y) * SCALE_UNITS - ((entity.transform.getScale().y * SCALE_UNITS - SCALE_UNITS) / 2) - ((colSize.y * SCALE_UNITS - SCALE_UNITS) / 2)), 
						round(colSize.x * SCALE_UNITS), 
						round(colSize.y * SCALE_UNITS))))
					end
				end
			end

			#endregion ============= Rendering

			#region ============= UI
			for screenButton in this.scene.screenButtons
				screenButton.render()
			end

			for textBox in this.scene.textBoxes
				textBox.render(DEBUG)
			end
			#endregion ============= UI

			SDL2.SDL_SetRenderDrawColor(this.renderer, 255, 0, 0, SDL2.SDL_ALPHA_OPAQUE)
			if isEditor && update != C_NULL
				selectedEntity = update[7] > 0 ? this.scene.entities[update[7]] : C_NULL
				try
					if selectedEntity != C_NULL
						if this.input.getButtonPressed("Delete")
							println("delete entity with name $(selectedEntity.name) and id $(selectedEntity.id)")
						end

						pos = selectedEntity.transform.getPosition()
						size = selectedEntity.collider != C_NULL ? selectedEntity.collider.getSize() : selectedEntity.transform.getScale()
						offset = selectedEntity.collider != C_NULL ? selectedEntity.collider.offset : Math.Vector2f()
						SDL2.SDL_RenderDrawRect( this.renderer, Ref(SDL2.SDL_Rect(
						round((pos.x + offset.x - this.scene.camera.position.x) * SCALE_UNITS - (selectedEntity.transform.getScale().x * SCALE_UNITS - SCALE_UNITS) / 2), 
						round((pos.y + offset.y - this.scene.camera.position.y) * SCALE_UNITS - (selectedEntity.transform.getScale().y * SCALE_UNITS - SCALE_UNITS) / 2), 
						round(size.x * SCALE_UNITS), 
						round(size.y * SCALE_UNITS))))
					end
				catch e
					rethrow(e)
				end
			end
			SDL2.SDL_SetRenderDrawColor(this.renderer, 0, 0, 0, SDL2.SDL_ALPHA_OPAQUE)

			this.lastMousePositionWorld = this.mousePositionWorld
			this.mousePositionWorldRaw = Math.Vector2f((this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom, ( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom)
			this.mousePositionWorld = Math.Vector2(floor(Int32,(this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom), floor(Int32,( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom))

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
						textBox = UI.TextBoxModule.TextBox("Debug text", fontPath, 40, Math.Vector2(0, 35 * i), statTexts[i], false, false, true)
						push!(this.debugTextBoxes, textBox)
						textBox.initialize()
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
				returnData = [[this.scene.entities, this.scene.textBoxes, this.scene.screenButtons], this.mousePositionWorld, cameraPosition, !this.selectedEntityUpdated ? update[7] : this.selectedEntityIndex, this.input.isWindowFocused]
				this.selectedEntityUpdated = false
				return returnData
			end
		catch e
			if this.testMode || isEditor
				rethrow(e)
			else
				println("$(e)")
				Base.show_backtrace(stderr, catch_backtrace())
			end
		end
    end
end