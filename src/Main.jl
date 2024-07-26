module MainLoop
	using ..JulGame
	using ..JulGame: Component, Input, Math, UI
    import ..JulGame: deprecated_get_property, Component
    import ..JulGame.SceneManagement: SceneBuilderModule
	include("Enums.jl")
	include("Constants.jl")
	include("Scene.jl")

	export Main
	mutable struct Main
		assets::String
		autoScaleZoom::Bool
		cameraBackgroundColor::Tuple{Int64, Int64, Int64}
		close::Bool
		currentTestTime::Float64
		debugTextBoxes::Vector{UI.TextBoxModule.TextBox}
		fpsManager::Ref{SDL2.LibSDL2.FPSmanager}
		globals::Vector{Any}
		input::Input
		isDraggingEntity::Bool
		isWindowFocused::Bool
		lastMousePosition::Union{Math.Vector2, Math.Vector2f}
		lastMousePositionWorld::Union{Math.Vector2, Math.Vector2f}
		level::JulGame.SceneManagement.SceneBuilderModule.Scene
		mousePositionWorld::Union{Math.Vector2, Math.Vector2f}
		mousePositionWorldRaw::Union{Math.Vector2, Math.Vector2f}
		optimizeSpriteRendering::Bool
		panCounter::Union{Math.Vector2, Math.Vector2f}
		panThreshold::Float64
		scene::Scene
		selectedEntity::Union{Entity, Nothing}
		selectedUIElementIndex::Int64
		screenSize::Math.Vector2
		shouldChangeScene::Bool
		spriteLayers::Dict
		targetFrameRate::Int32
		testLength::Float64
		testMode::Bool
		window::Ptr{SDL2.SDL_Window}
		windowName::String
		zoom::Float64

		function Main(zoom::Float64)
			this = new()

			SDL2.init()

			this.zoom = zoom
			this.scene = Scene()
			this.input = Input()

			this.cameraBackgroundColor = (0,0,0)
			this.close = false
			this.debugTextBoxes = UI.TextBoxModule.TextBox[]
			this.input.scene = this.scene
			this.isWindowFocused = false
			this.mousePositionWorld = Math.Vector2f()
			this.mousePositionWorldRaw = Math.Vector2f()
			this.lastMousePositionWorld = Math.Vector2f()
			this.optimizeSpriteRendering = false
			this.selectedEntity = nothing
			this.selectedUIElementIndex = -1
			this.screenSize = Math.Vector2(0,0)
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
        method_props = (
            init = init,
            initializeNewScene = initialize_new_scene,
            resetCameraPosition = reset_camera_position,
            fullLoop = full_loop,
            gameLoop = game_loop,
            createNewEntity = create_new_entity,
            createNewTextBox = create_new_text_box,
			createNewScreenButton = create_new_screen_button,
            minimizeWindow = minimize_window,
            restoreWindow = restore_window,
            updateViewport = update_viewport,
            scaleZoom = scale_zoom
        )
		deprecated_get_property(method_props, this, s)
	end

    function init(this::Main, isUsingEditor = false, size = C_NULL, isResizable::Bool = false, autoScaleZoom::Bool = true, isNewEditor::Bool = false)
        if !isNewEditor
            prepare_window(this, isUsingEditor, size, isResizable, autoScaleZoom)
        end
        initialize_scripts_and_components(this, isUsingEditor)

        if !isUsingEditor
            this.fullLoop()
            return
        end
    end

    function initialize_new_scene(this::Main, isUsingEditor::Bool = false)
        SceneBuilderModule.change_scene(this.level, isUsingEditor)
        initialize_scripts_and_components(this, false)

        if !isUsingEditor
            this.fullLoop()
            return
        end
    end

    function reset_camera_position(this::Main)
        cameraPosition = Math.Vector2f()
        this.scene.camera.update(cameraPosition, this)
    end
	
    function full_loop(this::Main)
        try
            this.close = false
            startTime = Ref(UInt64(0))
            lastPhysicsTime = Ref(UInt64(SDL2.SDL_GetTicks()))

            while !this.close
                try
                    GameLoop(this, startTime, lastPhysicsTime, false)
                catch e
                    if this.testMode
                        throw(e)
                    else
                        println(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
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
                            Base.show_backtrace(stdout, catch_backtrace())
                            rethrow(e)
                        end
                    end
                end
            end
            if !this.shouldChangeScene
                SDL2.SDL_DestroyRenderer(JulGame.Renderer)
                SDL2.SDL_DestroyWindow(this.window)
                SDL2.Mix_Quit()
                SDL2.Mix_CloseAudio()
                SDL2.TTF_Quit() # TODO: Close all open fonts with TTF_CloseFont befor this
                SDL2.SDL_Quit()
			elseif !this.shouldChangeScene && this.testMode
				SDL2.SDL_DestroyRenderer(JulGame.Renderer)
                SDL2.SDL_DestroyWindow(this.window)
            else
                this.shouldChangeScene = false
                this.initializeNewScene(false)
            end
        end
    end

    function game_loop(this::Main, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), isEditor::Bool = false, windowPos::Math.Vector2 = Math.Vector2(0,0), windowSize::Math.Vector2 = Math.Vector2(0,0))
        if this.shouldChangeScene
            this.shouldChangeScene = false
            this.initializeNewScene(true)
            return
        end
        return GameLoop(this, startTime, lastPhysicsTime, isEditor, windowPos, windowSize)
    end

    function handle_editor_inputs_camera(this::Main, windowPos::Math.Vector2, windowSize::Math.Vector2)
        #Rendering
        cameraPosition = this.scene.camera.position
        if SDL2.SDL_BUTTON_MIDDLE in this.input.mouseButtonsHeldDown && this.isWindowFocused
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
			# check if mouse is within the window # TODO: fix magic numbers
			if this.input.mousePosition.x >= windowPos.x && this.input.mousePosition.x <= windowPos.x + windowSize.x - 25 && this.input.mousePosition.y >= windowPos.y && this.input.mousePosition.y <= windowPos.y + windowSize.y - 30
				select_entity_with_click(this)
				this.isWindowFocused = true
			else
				this.isWindowFocused = false
			end
        elseif this.input.getMouseButton(SDL2.SDL_BUTTON_LEFT) && (this.selectedEntity !== nothing || this.selectedUIElementIndex != -1) && this.isWindowFocused  # TODO: figure out what this meant && this.selectedEntityIndex != this.selectedUIElementIndex
            # TODO: Make this work for textboxes
			if "$(typeof(this.selectedEntity))" != "JulGame.EntityModule.Entity"
				return
			end
            snapping = false
            if this.input.getButtonHeldDown("LCTRL")
                snapping = true
            end
            xDiff = this.lastMousePositionWorld.x - this.mousePositionWorld.x
            yDiff = this.lastMousePositionWorld.y - this.mousePositionWorld.y

            this.panCounter = Math.Vector2f(this.panCounter.x + xDiff, this.panCounter.y + yDiff)

            entityToMoveTransform = this.selectedEntity.transform
            if this.panCounter.x > this.panThreshold || this.panCounter.x < -this.panThreshold
                diff = this.panCounter.x > this.panThreshold ? -1 : 1
                entityToMoveTransform.position = Math.Vector2f(entityToMoveTransform.position.x + diff, entityToMoveTransform.position.y)
                this.panCounter = Math.Vector2f(0, this.panCounter.y)
            end
            if this.panCounter.y > this.panThreshold || this.panCounter.y < -this.panThreshold
                diff = this.panCounter.y > this.panThreshold ? -1 : 1
                entityToMoveTransform.position = Math.Vector2f(entityToMoveTransform.position.x, entityToMoveTransform.position.y + diff)
                this.panCounter = Math.Vector2f(this.panCounter.x, 0)
            end
        elseif !this.input.getMouseButton(SDL2.SDL_BUTTON_LEFT) && (this.selectedEntity !== nothing)
            if this.input.getButtonHeldDown("LCTRL") && this.input.getButtonPressed("D")
                push!(this.scene.entities, deepcopy(this.selectedEntity))
                this.selectedEntity = this.scene.entities[end]
            end
        elseif SDL2.SDL_BUTTON_LEFT in this.input.mouseButtonsReleased
        end

		if this.isWindowFocused
			if "SPACE" in this.input.buttonsHeldDown
				if "LEFT" in this.input.buttonsPressedDown
					this.zoom -= .1
					this.zoom = round(clamp(this.zoom, 0.2, 3); digits=1)
					SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
				elseif "RIGHT" in this.input.buttonsPressedDown
					this.zoom += .1
					this.zoom = round(clamp(this.zoom, 0.2, 3); digits=1)

					SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
				end
			elseif this.input.getButtonHeldDown("LEFT")
				cameraPosition = Math.Vector2f(cameraPosition.x - 0.05, cameraPosition.y)
			elseif this.input.getButtonHeldDown("RIGHT")
				cameraPosition = Math.Vector2f(cameraPosition.x + 0.05, cameraPosition.y)
			elseif this.input.getButtonHeldDown("DOWN")
				cameraPosition = Math.Vector2f(cameraPosition.x, cameraPosition.y + 0.05)
			elseif this.input.getButtonHeldDown("UP")
				cameraPosition = Math.Vector2f(cameraPosition.x, cameraPosition.y - 0.05)
			end
		end

        this.scene.camera.update(cameraPosition, this)
        return cameraPosition
    end

    function create_new_entity(this::Main)
        SceneBuilderModule.create_new_entity(this.level)
    end

    function create_new_text_box(this::Main)
        SceneBuilderModule.create_new_text_box(this.level)
    end

	function create_new_screen_button(this::Main)
		SceneBuilderModule.create_new_screen_button(this.level)
	end

    function select_entity_with_click(this::Main)
        for entity in this.scene.entities
            size = entity.collider != C_NULL ? Component.get_size(entity.collider) : entity.transform.scale
            if this.mousePositionWorldRaw.x >= entity.transform.position.x && this.mousePositionWorldRaw.x <= entity.transform.position.x + size.x && this.mousePositionWorldRaw.y >= entity.transform.position.y && this.mousePositionWorldRaw.y <= entity.transform.position.y + size.y
                if this.selectedEntity == entity
                    continue
                end
                this.selectedEntity = entity
                # TODO: this.selectedTextBox = nothing
                return
            end
        end
        uiElementIndex = 1
        for uiElement in this.scene.uiElements
            if this.mousePositionWorld.x >= uiElement.position.x && this.mousePositionWorld.x <= uiElement.position.x + uiElement.size.x && this.mousePositionWorld.y >= uiElement.position.y && this.mousePositionWorld.y <= uiElement.position.y + uiElement.size.y
                this.selectedUIElementIndex = uiElementIndex

                return
            end
            uiElementIndex += 1
        end
    end

    function minimize_window(this::Main)
        SDL2.SDL_MinimizeWindow(this.window)
    end

    function restore_window(this::Main)
        SDL2.SDL_RestoreWindow(this.window)
    end

    function update_viewport(this::Main, x,y)
        if !this.autoScaleZoom
            return
        end
        this.scaleZoom(x,y)
        SDL2.SDL_RenderClear(JulGame.Renderer)
        SDL2.SDL_RenderSetScale(JulGame.Renderer, 1.0, 1.0)	
        this.scene.camera.startingCoordinates = Math.Vector2f(round(x/2) - round(this.scene.camera.size.x/2*this.zoom), round(y/2) - round(this.scene.camera.size.y/2*this.zoom))																																				
        SDL2.SDL_RenderSetViewport(JulGame.Renderer, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.size.x*this.zoom), round(this.scene.camera.size.y*this.zoom))))
        SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
    end

	function update_viewport_editor(this::Main, x,y)
        if !this.autoScaleZoom
            return
        end
        this.scaleZoom(x,y)
        SDL2.SDL_RenderClear(JulGame.Renderer)
        SDL2.SDL_RenderSetScale(JulGame.Renderer, 1.0, 1.0)	
        this.scene.camera.startingCoordinates = Math.Vector2f(round(x/2) - round(this.scene.camera.size.x/2*this.zoom), round(y/2) - round(this.scene.camera.size.y/2*this.zoom))																																				
        SDL2.SDL_RenderSetViewport(JulGame.Renderer, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.size.x*this.zoom), round(this.scene.camera.size.y*this.zoom))))
        SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
		println("Zoom: ", this.zoom)
    end
	

    function scale_zoom(this::Main, x,y)
        if this.autoScaleZoom
            targetRatio = this.scene.camera.size.x/this.scene.camera.size.y
            if this.scene.camera.size.x == max(this.scene.camera.size.x, this.scene.camera.size.y)
                for i in x:-1:this.scene.camera.size.x
                    value = i/targetRatio
                    isInt = isinteger(value) || (isa(value, AbstractFloat) && trunc(value) == value)
                    if isInt && value <= y
                        this.zoom = i/this.scene.camera.size.x
                        break
                    end
                end
            else
                for i in y:-1:this.scene.camera.size.y
                    value = i*targetRatio
                    isInt = isinteger(value) || (isa(value, AbstractFloat) && trunc(value) == value)
                    if isInt && value <= x
                        this.zoom = i/this.scene.camera.size.y
                        break
                    end
                end
            end
        end
    end
    
	function prepare_window(this::Main, isUsingEditor::Bool = false, size = C_NULL, isResizable::Bool = false, autoScaleZoom::Bool = true)
		if size == Math.Vector2()
			displayMode = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
			SDL2.SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			size = Math.Vector2(displayMode[1].w, displayMode[1].h)
		end
		this.autoScaleZoom = autoScaleZoom
		this.scaleZoom(size.x,size.y)

		this.screenSize = size != C_NULL ? size : this.scene.camera.size

		flags = SDL2.SDL_RENDERER_ACCELERATED |
		(isUsingEditor ? (SDL2.SDL_WINDOW_POPUP_MENU | SDL2.SDL_WINDOW_ALWAYS_ON_TOP | SDL2.SDL_WINDOW_BORDERLESS) : 0) |
		(isResizable || isUsingEditor ? SDL2.SDL_WINDOW_RESIZABLE : 0) |
		(size == Math.Vector2() ? SDL2.SDL_WINDOW_FULLSCREEN_DESKTOP : 0)

		this.window = SDL2.SDL_CreateWindow(this.windowName, SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, this.screenSize.x, this.screenSize.y, flags)

		JulGame.Renderer = SDL2.SDL_CreateRenderer(this.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
		this.scene.camera.startingCoordinates = Math.Vector2f(round(size.x/2) - round(this.scene.camera.size.x/2*this.zoom), round(size.y/2) - round(this.scene.camera.size.y/2*this.zoom))																																				
		SDL2.SDL_RenderSetViewport(JulGame.Renderer, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.size.x*this.zoom), round(this.scene.camera.size.y*this.zoom))))
		# windowInfo = unsafe_wrap(Array, SDL2.SDL_GetWindowSurface(this.window), 1; own = false)[1]

		SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)
		this.fpsManager = Ref(SDL2.LibSDL2.FPSmanager(UInt32(0), Cfloat(0.0), UInt32(0), UInt32(0), UInt32(0)))
		SDL2.SDL_initFramerate(this.fpsManager)
		SDL2.SDL_setFramerate(this.fpsManager, UInt32(60))
	end

function initialize_scripts_and_components(this::Main, isUsingEditor::Bool = false)
	scripts = []
	for entity in this.scene.entities
		for script in entity.scripts
			push!(scripts, script)
		end
	end

	for uiElement in this.scene.uiElements
        JulGame.initialize(uiElement, this)
	end

	this.lastMousePosition = Math.Vector2(0, 0)
	this.panCounter = Math.Vector2f(0, 0)
	this.panThreshold = .1

	this.spriteLayers = BuildSpriteLayers(this)
	
	if !isUsingEditor
		for script in scripts
			try
				script.initialize(this)
			catch e
				if typeof(e) != ErrorException || !contains(e.msg, "initialize")
					println(e)
					Base.show_backtrace(stdout, catch_backtrace())
					rethrow(e)
				end
			end
		end
	end
end

export change_scene
"""
	change_scene(sceneFileName::String)

Change the scene to the specified `sceneFileName`. This function destroys the current scene, including all entities, textboxes, and screen buttons, except for the ones marked as persistent. It then loads the new scene and sets the camera and persistent entities, textboxes, and screen buttons.

# Arguments
- `sceneFileName::String`: The name of the scene file to load.

"""
function change_scene(this::Main, sceneFileName::String)
	# println("Changing scene to: ", sceneFileName)
	this.close = true
	this.shouldChangeScene = true
	#destroy current scene 
	#println("Entities before destroying: ", length(this.scene.entities))
	count = 0
	skipcount = 0
	persistentEntities = []	
	for entity in this.scene.entities
		if entity.persistentBetweenScenes
			#println("Persistent entity: ", entity.name, " with id: ", entity.id)
			push!(persistentEntities, entity)
			skipcount += 1
			continue
		end

		destroy_entity_components(entity)
		for script in entity.scripts
			try
				script.onShutDown()
			catch e
				if typeof(e) != ErrorException || !contains(e.msg, "onShutDown")
					println("Error shutting down script")
					println(e)
					Base.show_backtrace(stdout, catch_backtrace())
					rethrow(e)
				end
			end
		end
		count += 1
	end
	# println("Destroyed $count entities")
	# println("Skipped $skipcount entities")

	# println("Entities left after destroying: ", length(persistentEntities))

	persistentUIElements = []
	# delete all UIElements
	for uiElement in this.scene.uiElements
		if uiElement.persistentBetweenScenes
			#println("Persistent uiElement: ", uiElement.name)
			push!(persistentUIElements, uiElement)
			skipcount += 1
			continue
		end
        JulGame.destroy(uiElement)
	end
	
	#load new scene 
	camera = this.scene.camera
	this.scene = Scene()
	this.scene.entities = persistentEntities
	this.scene.uiElements = persistentUIElements
	this.scene.camera = camera
	this.level.scene = sceneFileName
end

"""
BuildSpriteLayers(this::Main)

Builds the sprite layers for the main game.

# Arguments
- `this::Main`: The main game object.

"""
function BuildSpriteLayers(this::Main)
	layerDict = Dict{String, Array}()
	layerDict["sort"] = []
	for entity in this.scene.entities
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
function DestroyEntity(this::Main, entity)
	for i = eachindex(this.scene.entities)
		if this.scene.entities[i] == entity
			destroy_entity_components(entity)
			deleteat!(this.scene.entities, i)
			break
		end
	end
end

function DestroyUIElement(this::Main, uiElement)
	for i = eachindex(this.scene.uiElements)
		if this.scene.uiElements[i] == uiElement
			deleteat!(this.scene.uiElements, i)
			JulGame.destroy(uiElement)
			break
		end
	end
end

function destroy_entity_components(this::Main, entity)
	entitySprite = entity.sprite
	if entitySprite != C_NULL
		for j = eachindex(this.spriteLayers["$(entitySprite.layer)"])
			if this.spriteLayers["$(entitySprite.layer)"][j] == entitySprite
				entitySprite.destroy()
				deleteat!(this.spriteLayers["$(entitySprite.layer)"], j)
				break
			end
		end
	end

	entityRigidbody = entity.rigidbody
	if entityRigidbody != C_NULL
		for j = eachindex(this.scene.rigidbodies)
			if this.scene.rigidbodies[j] == entityRigidbody
				deleteat!(this.scene.rigidbodies, j)
				break
			end
		end
	end

	entityCollider = entity.collider
	if entityCollider != C_NULL
		for j = eachindex(this.scene.colliders)
			if this.scene.colliders[j] == entityCollider
				deleteat!(this.scene.colliders, j)
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
function CreateEntity(this::Main, entity)
	push!(this.scene.entities, entity)
	if entity.sprite != C_NULL
		if !haskey(this.spriteLayers, "$(entity.sprite.layer)")
			push!(this.spriteLayers["sort"], entity.sprite.layer)
			this.spriteLayers["$(entity.sprite.layer)"] = [entity.sprite]
			sort!(this.spriteLayers["sort"])
		else
			push!(this.spriteLayers["$(entity.sprite.layer)"], entity.sprite)
		end
	end

	if entity.rigidbody != C_NULL
		push!(this.scene.rigidbodies, entity.rigidbody)
	end

	if entity.collider != C_NULL
		push!(this.scene.colliders, entity.collider)
	end

	return entity
end

"""
GameLoop(this, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), close::Ref{Bool} = Ref(Bool(false)), isEditor::Bool = false, Vector{Any}} = C_NULL)

Runs the game loop.

Parameters:
- `this`: The main struct.
- `startTime`: A reference to the start time of the game loop.
- `lastPhysicsTime`: A reference to the last physics time of the game loop.
- `isEditor`: A boolean indicating whether the game loop is running in editor mode.

"""
function GameLoop(this::Main, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), isEditor::Bool = false, windowPos::Math.Vector2 = Math.Vector2(0,0), windowSize::Math.Vector2 = Math.Vector2(0,0))
        try
			SDL2.SDL_RenderSetScale(JulGame.Renderer, this.zoom, this.zoom)

			lastStartTime = startTime[]
			startTime[] = SDL2.SDL_GetPerformanceCounter()

			if isEditor
				this.scene.camera.size = Math.Vector2(windowSize.x, windowSize.y)
				# update_viewport_editor(this, windowSize.x, windowSize.y)
			end

			DEBUG = false
			#region =============    Input
			this.lastMousePosition = this.input.mousePosition
			if !isEditor
				this.input.pollInput(this)
			end

			if this.input.quit && !isEditor
				this.close = true
			end
			DEBUG = this.input.debug

			cameraPosition = Math.Vector2f()
			if isEditor
				cameraPosition = handle_editor_inputs_camera(this, windowPos, windowSize)
			end

			#endregion ============= Input

			if !isEditor
				SDL2.SDL_RenderClear(JulGame.Renderer)
			end

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
						JulGame.update(rigidbody, deltaTime, this)
					catch e
						println(rigidbody.parent.name, " with id: ", rigidbody.parent.id, " has a problem with it's rigidbody")
						println(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
					end
				end
				lastPhysicsTime[] =  currentPhysicsTime
			end
			#endregion ============= Physics


			#region =============    Rendering
			currentRenderTime = SDL2.SDL_GetTicks()
			SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 0, 200, 0, SDL2.SDL_ALPHA_OPAQUE)
			this.scene.camera.update(C_NULL, this)

			for entity in this.scene.entities
				if !entity.isActive
					continue
				end

				if !isEditor
					try
                        JulGame.update(entity, deltaTime)
						if this.close
							return
						end
					catch e
						println(entity.name, " with id: ", entity.id, " has a problem with it's update")
						println(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
					end
					entityAnimator = entity.animator
					if entityAnimator != C_NULL
                        JulGame.update(entityAnimator, currentRenderTime, deltaTime)
					end
				end
			end

			cameraPosition = this.scene.camera.position
			cameraSize = this.scene.camera.size
			
			skipcount = 0
			rendercount = 0
			renderOrder = []
			for entity in this.scene.entities
				if !entity.isActive || (entity.sprite == C_NULL && entity.shape == C_NULL)
					continue
				end

				shapeOrSprite = entity.sprite != C_NULL ? entity.sprite : entity.shape
				shapeOrSpritePosition = shapeOrSprite.parent.transform.position
				shapeOrSpriteSize = shapeOrSprite.parent.transform.scale

				if ((shapeOrSpritePosition.x + shapeOrSpriteSize.x) < cameraPosition.x || shapeOrSpritePosition.y < cameraPosition.y || shapeOrSpritePosition.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || (shapeOrSpritePosition.y - shapeOrSpriteSize.y) > cameraPosition.y + cameraSize.y/SCALE_UNITS) && shapeOrSprite.isWorldEntity && this.optimizeSpriteRendering 
					skipcount += 1
					continue
				end

				push!(renderOrder, (shapeOrSprite.layer, shapeOrSprite))
			end

			sort!(renderOrder, by = x -> x[1])

			for i = eachindex(renderOrder)
				try
					rendercount += 1
					Component.draw(renderOrder[i][2], this)
				catch e
					println(sprite.parent.name, " with id: ", sprite.parent.id, " has a problem with it's sprite")
					println(e)
					Base.show_backtrace(stdout, catch_backtrace())
					rethrow(e)
				end
			end

			#println("Skipped $skipcount, rendered $rendercount")

			colliderSkipCount = 0
			colliderRenderCount = 0
			for entity in this.scene.entities
				if !entity.isActive
					continue
				end

				entityShape = entity.shape
				if entityShape != C_NULL
					entityShape.draw(this)
				end
				
				if DEBUG && entity.collider != C_NULL
					SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
					pos = entity.transform.position
					scale = entity.transform.scale

					if ((pos.x + scale.x) < cameraPosition.x || pos.y < cameraPosition.y || pos.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || (pos.y - scale.y) > cameraPosition.y + cameraSize.y/SCALE_UNITS)  && this.optimizeSpriteRendering 
						colliderSkipCount += 1
						continue
					end
					colliderRenderCount += 1
					collider = entity.collider
					if JulGame.get_type(collider) == "CircleCollider"
						SDL2E.SDL_RenderDrawCircle(
							round(Int32, (pos.x - this.scene.camera.position.x) * SCALE_UNITS - ((entity.transform.scale.x * SCALE_UNITS - SCALE_UNITS) / 2)), 
							round(Int32, (pos.y - this.scene.camera.position.y) * SCALE_UNITS - ((entity.transform.scale.y * SCALE_UNITS - SCALE_UNITS) / 2)), 
							round(Int32, collider.diameter/2 * SCALE_UNITS))
					else
						colSize = JulGame.get_size(collider)
						colSize = Math.Vector2f(colSize.x, colSize.y)
						colOffset = collider.offset
						colOffset = Math.Vector2f(colOffset.x, colOffset.y)

						SDL2.SDL_RenderDrawRectF(JulGame.Renderer, 
						Ref(SDL2.SDL_FRect((pos.x + colOffset.x - this.scene.camera.position.x) * SCALE_UNITS - ((entity.transform.scale.x * SCALE_UNITS - SCALE_UNITS) / 2) - ((colSize.x * SCALE_UNITS - SCALE_UNITS) / 2), 
						(pos.y + colOffset.y - this.scene.camera.position.y) * SCALE_UNITS - ((entity.transform.scale.y * SCALE_UNITS - SCALE_UNITS) / 2) - ((colSize.y * SCALE_UNITS - SCALE_UNITS) / 2), 
						colSize.x * SCALE_UNITS, 
						colSize.y * SCALE_UNITS)))
					end
				end
			end
			#println("Skipped $colliderSkipCount, rendered $colliderRenderCount")

			#endregion ============= Rendering

			#region ============= UI
			for uiElement in this.scene.uiElements
                JulGame.render(uiElement, DEBUG, this)
			end
			#endregion ============= UI

			if isEditor
				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 255, 0, 0, SDL2.SDL_ALPHA_OPAQUE)
				
				selectedEntity = this.selectedEntity !== nothing ? this.selectedEntity : nothing
				try
					if selectedEntity != nothing
						if this.input.getButtonPressed("DELETE")
							# println("delete entity with name $(selectedEntity.name) and id $(selectedEntity.id)")
							index = findfirst(x -> x == selectedEntity, this.scene.entities)
							if index !== nothing
								MainLoop.DestroyEntity(this.scene.entities[index])
							end
						end

						pos = selectedEntity.transform.position
                        
						size = selectedEntity.collider != C_NULL ? JulGame.get_size(selectedEntity.collider) : selectedEntity.transform.scale
						size = Math.Vector2f(size.x, size.y)
						offset = selectedEntity.collider != C_NULL ? selectedEntity.collider.offset : Math.Vector2f()
						offset = Math.Vector2f(offset.x, offset.y)
						SDL2.SDL_RenderDrawRectF(JulGame.Renderer, 
						Ref(SDL2.SDL_FRect((pos.x + offset.x - this.scene.camera.position.x) * SCALE_UNITS - ((size.x * SCALE_UNITS - SCALE_UNITS) / 2) - ((size.x * SCALE_UNITS - SCALE_UNITS) / 2), 
						(pos.y + offset.y - this.scene.camera.position.y) * SCALE_UNITS - ((size.y * SCALE_UNITS - SCALE_UNITS) / 2) - ((size.y * SCALE_UNITS - SCALE_UNITS) / 2), 
						size.x * SCALE_UNITS, 
						size.y * SCALE_UNITS)))
					end
				catch e
					println(e)
					Base.show_backtrace(stdout, catch_backtrace())
					rethrow(e)
				end

				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer, 0, 200, 0, SDL2.SDL_ALPHA_OPAQUE)
			end

			this.lastMousePositionWorld = this.mousePositionWorld
			pos1::Math.Vector2 = windowPos !== nothing ? windowPos : Math.Vector2(0, 0)
			this.mousePositionWorldRaw = Math.Vector2f((this.input.mousePosition.x - pos1.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom, ( this.input.mousePosition.y - pos1.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom)
			this.mousePositionWorld = Math.Vector2(floor(Int32,(this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom), floor(Int32,( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom))
			rawMousePos = Math.Vector2f(this.input.mousePosition.x - pos1.x , this.input.mousePosition.y - pos1.y )
			#region ================ Debug
			if DEBUG
				# Stats to display
				statTexts = [
					"FPS: $(round(1000 / round((startTime[] - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0)))",
					"Frame time: $(round((startTime[] - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0)) ms",
					"Raw Mouse pos: $(rawMousePos.x),$(rawMousePos.y)",
					"Mouse pos world: $(this.mousePositionWorld.x),$(this.mousePositionWorld.y)"
				]

				if length(this.debugTextBoxes) == 0
					fontPath = joinpath(this.assets, "fonts", "FiraCode", "ttf", "FiraCode-Regular.ttf")

					for i = eachindex(statTexts)
						textBox = UI.TextBoxModule.TextBox("Debug text", fontPath, 40, Math.Vector2(0, 35 * i), statTexts[i], false, false)
						push!(this.debugTextBoxes, textBox)
                        JulGame.initialize(textBox, this)
					end
				else
					for i = eachindex(this.debugTextBoxes)
                        db_textbox = this.debugTextBoxes[i]
                        JulGame.update_text(db_textbox, statTexts[i], this)
                        JulGame.render(db_textbox, false, this)
					end
				end
			end

			#endregion ============= Debug

			endTime = SDL2.SDL_GetPerformanceCounter()
			elapsedMS = (endTime - startTime[]) / SDL2.SDL_GetPerformanceFrequency() * 1000.0
			
			if !isEditor
				SDL2.SDL_RenderPresent(JulGame.Renderer)
				SDL2.SDL_framerateDelay(this.fpsManager)
			end
		catch e
			println(e)
			Base.show_backtrace(stdout, catch_backtrace())
			rethrow(e)
		end
    end
end
