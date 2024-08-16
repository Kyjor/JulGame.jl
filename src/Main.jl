module MainLoop
	using ..JulGame
	using ..JulGame: Camera, Component, Input, Math, UI, SceneModule
    import ..JulGame: Component
    import ..JulGame.SceneManagement: SceneBuilderModule
	include("Enums.jl")
	include("Constants.jl")

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
		isWindowFocused::Bool
		lastMousePosition::Union{Math.Vector2, Math.Vector2f}
		lastMousePositionWorld::Union{Math.Vector2, Math.Vector2f}
		level::JulGame.SceneManagement.SceneBuilderModule.Scene
		mousePositionWorld::Union{Math.Vector2, Math.Vector2f}
		mousePositionWorldRaw::Union{Math.Vector2, Math.Vector2f}
		optimizeSpriteRendering::Bool
		panCounter::Union{Math.Vector2, Math.Vector2f}
		panThreshold::Float64
		scene::SceneModule.Scene
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
			this::Main = new()

			SDL2.init()

			this.zoom = zoom
			this.scene = SceneModule.Scene()
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

    function prepare_window_scripts_and_start_loop(isUsingEditor = false, size = C_NULL, isResizable::Bool = false, autoScaleZoom::Bool = true, isNewEditor::Bool = false)
        if !isNewEditor
            prepare_window(isUsingEditor, size, isResizable, autoScaleZoom)
        end
        initialize_scripts_and_components(isUsingEditor)

        if !isUsingEditor
            full_loop(MAIN)
            return
        end
    end

    function initialize_new_scene(this::Main, isUsingEditor::Bool = false)
        SceneBuilderModule.deserialize_and_build_scene(this.level, isUsingEditor)
        initialize_scripts_and_components(false)

        if !isUsingEditor
            full_loop(this)
            return
        end
    end

    function reset_camera_position(this::Main)
        cameraPosition = Math.Vector2f()
        JulGame.CameraModule.update(this.scene.camera, cameraPosition)
    end
	
    function full_loop(this::Main)
        try
			this.close = false
            startTime = Ref(UInt64(0))
            lastPhysicsTime = Ref(UInt64(SDL2.SDL_GetTicks()))
            while !this.close
                try
                    game_loop(this, startTime, lastPhysicsTime, false)
                catch e
                    if this.testMode
                        throw(e)
                    else
                        @error string(e)
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
                SDL2.SDL_DestroyRenderer(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
                SDL2.SDL_DestroyWindow(this.window)
                SDL2.Mix_Quit()
                SDL2.Mix_CloseAudio()
                SDL2.TTF_Quit() # TODO: Close all open fonts with TTF_CloseFont befor this
                SDL2.SDL_Quit()
            else
                this.shouldChangeScene = false
                initialize_new_scene(this, false)
            end
        end
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

    function update_viewport(this::Main, x,y)
        if !this.autoScaleZoom
            return
        end
		scale_zoom(this, x, y)
        SDL2.SDL_RenderClear(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
        SDL2.SDL_RenderSetScale(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 1.0, 1.0)	
        this.scene.camera.startingCoordinates = Math.Vector2f(round(x/2) - round(this.scene.camera.size.x/2*this.zoom), round(y/2) - round(this.scene.camera.size.y/2*this.zoom))																																				
        @info string("Set viewport to: ", this.scene.camera.startingCoordinates)
		SDL2.SDL_RenderSetViewport(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.size.x*this.zoom), round(this.scene.camera.size.y*this.zoom))))
        SDL2.SDL_RenderSetScale(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.zoom, this.zoom)
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
    
	function prepare_window(isUsingEditor::Bool = false, size = C_NULL, isResizable::Bool = false, autoScaleZoom::Bool = true)
		this::Main = MAIN
		if size == Math.Vector2()
			displayMode = SDL2.SDL_DisplayMode[SDL2.SDL_DisplayMode(0x12345678, 800, 600, 60, C_NULL)]
			SDL2.SDL_GetCurrentDisplayMode(0, pointer(displayMode))
			size = Math.Vector2(displayMode[1].w, displayMode[1].h)
		end
		this.autoScaleZoom = autoScaleZoom
		scale_zoom(this, size.x, size.y)

		this.screenSize = size != C_NULL ? size : this.scene.camera.size

		flags = SDL2.SDL_RENDERER_ACCELERATED |
		(isUsingEditor ? (SDL2.SDL_WINDOW_POPUP_MENU | SDL2.SDL_WINDOW_ALWAYS_ON_TOP | SDL2.SDL_WINDOW_BORDERLESS) : 0) |
		(isResizable || isUsingEditor ? SDL2.SDL_WINDOW_RESIZABLE : 0) |
		(size == Math.Vector2() ? SDL2.SDL_WINDOW_FULLSCREEN_DESKTOP : 0)

		this.window = SDL2.SDL_CreateWindow(this.windowName, SDL2.SDL_WINDOWPOS_CENTERED, SDL2.SDL_WINDOWPOS_CENTERED, this.screenSize.x, this.screenSize.y, flags)

		JulGame.Renderer::Ptr{SDL2.SDL_Renderer} = SDL2.SDL_CreateRenderer(this.window, -1, SDL2.SDL_RENDERER_ACCELERATED)
		this.scene.camera.startingCoordinates = Math.Vector2f(round(size.x/2) - round(this.scene.camera.size.x/2*this.zoom), round(size.y/2) - round(this.scene.camera.size.y/2*this.zoom))																																				
		@info string("Set viewport to: ", this.scene.camera.startingCoordinates)
		SDL2.SDL_RenderSetViewport(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(SDL2.SDL_Rect(this.scene.camera.startingCoordinates.x, this.scene.camera.startingCoordinates.y, round(this.scene.camera.size.x*this.zoom), round(this.scene.camera.size.y*this.zoom))))
		# windowInfo = unsafe_wrap(Array, SDL2.SDL_GetWindowSurface(this.window), 1; own = false)[1]

		SDL2.SDL_RenderSetScale(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.zoom, this.zoom)
		this.fpsManager = Ref(SDL2.LibSDL2.FPSmanager(UInt32(0), Cfloat(0.0), UInt32(0), UInt32(0), UInt32(0)))
		SDL2.SDL_initFramerate(this.fpsManager)
		SDL2.SDL_setFramerate(this.fpsManager, UInt32(60))
	end

function initialize_scripts_and_components(isUsingEditor::Bool = false)
	this::Main = MAIN
	scripts = []
	for entity in this.scene.entities
		for script in entity.scripts
			push!(scripts, script)
		end
	end

	for uiElement in this.scene.uiElements
        JulGame.initialize(uiElement)
	end

	this.lastMousePosition = Math.Vector2(0, 0)
	this.panCounter = Math.Vector2f(0, 0)
	this.panThreshold = .1

	this.spriteLayers = build_sprite_layers()
	
	if !isUsingEditor
		for script in scripts
			try
				script.initialize()
			catch e
				if typeof(e) != ErrorException || !contains(e.msg, "initialize")
					@error string(e)
					Base.show_backtrace(stdout, catch_backtrace())
					rethrow(e)
				end
			end
		end
	end
end

export change_scene
"""
	change_scene(sceneFileName::String, isEditor::Bool = false)

Change the scene to the specified `sceneFileName`. This function destroys the current scene, including all entities, textboxes, and screen buttons, except for the ones marked as persistent. It then loads the new scene and sets the camera and persistent entities, textboxes, and screen buttons.

# Arguments
- `sceneFileName::String`: The name of the scene file to load.
- `isEditor::Bool`: Whether the scene is being loaded in the editor. Default is `false`.

"""
function change_scene(sceneFileName::String, isEditor::Bool = false)
	this::Main = MAIN
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

		destroy_entity_components(this, entity)
		for script in entity.scripts
			try
				script.onShutDown()
			catch e
				if typeof(e) != ErrorException || !contains(e.msg, "onShutDown")
					println("Error shutting down script")
					@error string(e)
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
	this.scene = SceneModule.Scene()
	this.scene.entities = persistentEntities
	this.scene.uiElements = persistentUIElements
	this.scene.camera = camera
	this.level.scene = sceneFileName
	
	if isEditor
		initialize_new_scene(this, true)
	end
end

"""
build_sprite_layers()

Builds the sprite layers for the main game.

"""
function build_sprite_layers()
	layerDict = Dict{String, Array}()
	layerDict["sort"] = []
	for entity in MAIN.scene.entities
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

export destroy_entity
"""
destroy_entity(entity)

Destroy the specified entity. This removes the entity's sprite from the sprite layers so that it is no longer rendered. It also removes the entity's rigidbody from the main game's rigidbodies array.

# Arguments
- `entity`: The entity to be destroyed.
"""
function destroy_entity(this::Main, entity)
	for i = eachindex(this.scene.entities)
		if this.scene.entities[i] == entity
			destroy_entity_components(this, entity)
			deleteat!(this.scene.entities, i)
			this.selectedEntity = nothing
			break
		end
	end
end

function destroy_ui_element(this::Main, uiElement)
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
				Component.destroy(entitySprite)
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
		Component.unload_sound(entitySoundSource)
	end
end

export create_entity
"""
create_entity(entity)

Create a new entity. Adds the entity to the main game's entities array and adds the entity's sprite to the sprite layers so that it is rendered.

# Arguments
- `entity`: The entity to create.

"""
function create_entity(entity)
	this::Main = MAIN
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
game_loop(this::Main, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), close::Ref{Bool} = Ref(Bool(false)), isEditor::Bool = false, Vector{Any}} = C_NULL)

Runs the game loop.

Parameters:
- `this`: The main struct.
- `startTime`: A reference to the start time of the game loop.
- `lastPhysicsTime`: A reference to the last physics time of the game loop.
- `isEditor`: A boolean indicating whether the game loop is running in editor mode.

"""
function game_loop(this::Main, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), isEditor::Bool = false, windowPos::Math.Vector2 = Math.Vector2(0,0), windowSize::Math.Vector2 = Math.Vector2(0,0))
	if this.shouldChangeScene
		this.shouldChangeScene = false
		initialize_new_scene(this, isEditor)
		return
	end
	try
			SDL2.SDL_RenderSetScale(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, this.zoom, this.zoom)

			lastStartTime = startTime[]
			startTime[] = SDL2.SDL_GetPerformanceCounter()

			if isEditor
				this.scene.camera.size = Math.Vector2(windowSize.x, windowSize.y)
			end

			DEBUG = false
			#region Input
			this.lastMousePosition = this.input.mousePosition
			if !isEditor
				JulGame.InputModule.poll_input(this.input)
			end

			if this.input.quit && !isEditor
				this.close = true
			end
			DEBUG = this.input.debug

			cameraPosition = Math.Vector2f()

			if !isEditor
				SDL2.SDL_RenderClear(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
			end

			#region Physics
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
						JulGame.update(rigidbody, deltaTime)
					catch e
						println(rigidbody.parent.name, " with id: ", rigidbody.parent.id, " has a problem with it's rigidbody")
						@error string(e)
						Base.show_backtrace(stdout, catch_backtrace())
						rethrow(e)
					end
				end
				lastPhysicsTime[] =  currentPhysicsTime
			end

			#region Rendering
			currentRenderTime = SDL2.SDL_GetTicks()
			SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 0, 200, 0, SDL2.SDL_ALPHA_OPAQUE)
			JulGame.CameraModule.update(this.scene.camera, C_NULL)

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
						@error string(e)
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
					Component.draw(renderOrder[i][2])
				catch e
					println(sprite.parent.name, " with id: ", sprite.parent.id, " has a problem with it's sprite")
					@error string(e)
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
					Component.draw(entityShape)
				end
				
				if DEBUG && entity.collider != C_NULL
					SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
					pos = entity.transform.position
					scale = entity.transform.scale

					if ((pos.x + scale.x) < cameraPosition.x || pos.y < cameraPosition.y || pos.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || (pos.y - scale.y) > cameraPosition.y + cameraSize.y/SCALE_UNITS)  && this.optimizeSpriteRendering 
						colliderSkipCount += 1
						continue
					end
					colliderRenderCount += 1
					collider = entity.collider
					if Component.get_type(collider) == "CircleCollider"
						SDL2E.SDL_RenderDrawCircle(
							round(Int32, (pos.x - this.scene.camera.position.x) * SCALE_UNITS - ((entity.transform.scale.x * SCALE_UNITS - SCALE_UNITS) / 2)), 
							round(Int32, (pos.y - this.scene.camera.position.y) * SCALE_UNITS - ((entity.transform.scale.y * SCALE_UNITS - SCALE_UNITS) / 2)), 
							round(Int32, collider.diameter/2 * SCALE_UNITS))
					else
						colSize = Component.get_size(collider)
						colSize = Math.Vector2f(colSize.x, colSize.y)
						colOffset = collider.offset
						colOffset = Math.Vector2f(colOffset.x, colOffset.y)

						SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
						Ref(SDL2.SDL_FRect((pos.x + colOffset.x - this.scene.camera.position.x) * SCALE_UNITS - ((entity.transform.scale.x * SCALE_UNITS - SCALE_UNITS) / 2) - ((colSize.x * SCALE_UNITS - SCALE_UNITS) / 2), 
						(pos.y + colOffset.y - this.scene.camera.position.y) * SCALE_UNITS - ((entity.transform.scale.y * SCALE_UNITS - SCALE_UNITS) / 2) - ((colSize.y * SCALE_UNITS - SCALE_UNITS) / 2), 
						colSize.x * SCALE_UNITS, 
						colSize.y * SCALE_UNITS)))
					end
				end
			end
			#println("Skipped $colliderSkipCount, rendered $colliderRenderCount")

			#region UI
			for uiElement in this.scene.uiElements
                JulGame.render(uiElement, DEBUG)
			end

			this.lastMousePositionWorld = this.mousePositionWorld
			pos1::Math.Vector2 = windowPos !== nothing ? windowPos : Math.Vector2(0, 0)
			this.mousePositionWorldRaw = Math.Vector2f((this.input.mousePosition.x - pos1.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom, ( this.input.mousePosition.y - pos1.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom)
			this.mousePositionWorld = Math.Vector2(floor(Int32,(this.input.mousePosition.x + (this.scene.camera.position.x * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom), floor(Int32,( this.input.mousePosition.y + (this.scene.camera.position.y * SCALE_UNITS * this.zoom)) / SCALE_UNITS / this.zoom))
			rawMousePos = Math.Vector2f(this.input.mousePosition.x - pos1.x , this.input.mousePosition.y - pos1.y )
			#region Debug
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
                        JulGame.initialize(textBox)
					end
				else
					for i = eachindex(this.debugTextBoxes)
                        db_textbox = this.debugTextBoxes[i]
                        JulGame.update_text(db_textbox, statTexts[i])
                        JulGame.render(db_textbox, false)
					end
				end
			end

			if !isEditor
				SDL2.SDL_RenderPresent(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
				SDL2.SDL_framerateDelay(this.fpsManager)
			end
		catch e
			@error string(e)
			Base.show_backtrace(stdout, catch_backtrace())
			rethrow(e)
		end
    end
end
