module MainLoopModule
	using ..JulGame
	using ..JulGame.ErrorLoggingModule
	using ..JulGame: Camera, Component, Input, Math, UI, SceneModule, WindowManager
    import ..JulGame: Component
    import ..JulGame.SceneManagement: SceneBuilderModule
	import ..JulGame

	include("utils/Enums.jl")
	include("utils/Constants.jl")

	"""
		cleanup_coroutines()

	Cleans up all active coroutines by attempting to gracefully terminate them and then clearing the coroutines array.
	This function should be called when changing scenes, exiting the game, or stopping the game in editor mode.
	"""
	function cleanup_coroutines()
		@debug "Cleaning up coroutines"
		for coroutine in JulGame.Coroutines
			if !istaskdone(coroutine.task)
				try
					schedule(coroutine.task, InterruptException(), error=true)
				catch e
					@debug "Error interrupting coroutine: $e"
				end
			end
		end
		empty!(JulGame.Coroutines)
	end

	export MainLoop
	mutable struct MainLoop
		assets::String
		close::Bool
		coroutine_condition::Condition
		currentTestTime::Float64
		debugTextBoxes::Vector{UI.TextBoxModule.TextBox}
		errorLogger::ErrorLoggingModule.ErrorLogger
		input::Input
		isGameModeRunningInEditor::Bool
		level::JulGame.SceneManagement.SceneBuilderModule.Scene
		optimizeSpriteRendering::Bool
		scene::SceneModule.Scene
		selectedEntity::Union{Entity, Nothing}
		selectedUIElementIndex::Int64
		shouldChangeScene::Bool
		spriteLayers::Dict
		testLength::Float64
		testMode::Bool
		windowManager::WindowManager

		function MainLoop()
			this::MainLoop = new()

			@debug "Initializing SDL"
			if SDL2.SDL_Init(SDL2.SDL_INIT_EVERYTHING) != 0
				@error "Failed to initialize SDL, $(unsafe_string(SDL2.SDL_GetError()))"
			end
			if SDL2.TTF_Init() != 0
				@error "Failed to initialize TTF, $(unsafe_string(SDL2.SDL_GetError()))"
			end
			if SDL2.Mix_OpenAudio(22050, SDL2.MIX_DEFAULT_FORMAT, 2, 1024) != 0
				@error "Failed to open audio, $(unsafe_string(SDL2.SDL_GetError()))"
			end
			SDL2.SDL_ClearError()

			this.scene = SceneModule.Scene()
			this.input = Input()

			this.close = false
			this.debugTextBoxes = UI.TextBoxModule.TextBox[]
			this.optimizeSpriteRendering = false
			this.selectedEntity = nothing
			this.selectedUIElementIndex = -1
			this.shouldChangeScene = false
			this.input.main = this
			this.isGameModeRunningInEditor = false

			this.currentTestTime = 0.0
			this.testMode = false
			this.testLength = 0.0
			this.coroutine_condition = Condition()
			this.errorLogger = ErrorLoggingModule.ErrorLogger()
			this.spriteLayers = Dict()

			this.windowManager = WindowManager()

			return this
		end
	end

    function prepare_window_scripts_and_start_loop(size)
        @debug "Preparing window"
		MAIN.windowManager.windowSize = size
		
		@debug "Initializing scripts and components"
        initialize_scripts_and_components()

        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
			@debug "Starting non editor loop"
            full_loop(MAIN)
            return
        end
    end

    function initialize_new_scene(this::MainLoop)
		@debug "Initializing new scene"
		@debug "Deserializing and building scene"
        SceneBuilderModule.deserialize_and_build_scene(this.level)

        initialize_scripts_and_components()
        
        if !JulGame.IS_EDITOR
			@debug "Starting non editor loop"
            full_loop(this)
            return
        end
    end

    function reset_camera_position(this::MainLoop)
		@debug "Resetting camera position"
		if this.scene.camera === nothing return end

        cameraPosition = Math.Vector3f(0.0, 0.0, 0.0)
        JulGame.CameraModule.update(this.scene.camera, cameraPosition)
    end
	
    function full_loop(this::MainLoop)
        try
			this.close = false
            startTime = Ref(UInt64(0))
            lastPhysicsTime = Ref(UInt64(SDL2.SDL_GetTicks()))
            while !this.close
                try
                    game_loop(this, startTime, lastPhysicsTime)
                catch e
                    if this.testMode
                        throw(e)
                    else
						if this.testMode
							rethrow(e)
						else
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
						end
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
                        Base.invokelatest(JulGame.on_shutdown, script)
                    catch e
						if this.testMode
							rethrow(e)
						else
							if typeof(e) != ErrorException
								println("Error shutting down script: $(typeof(script))")
								Base.show_backtrace(stdout, catch_backtrace())
							end
						end
                    end
                end
            end
			
            # Clean up all coroutines when game exits
            @debug "Cleaning up coroutines during game exit"
            cleanup_coroutines()
			
            if !this.shouldChangeScene
                # Clean up all immediate UI components on game shutdown
                JulGame.UI.ImmediateUIModule.cleanup_all_immediate_components()
				@debug "Cleaning up immediate UI components"
				JulGame.cleanup_sdl_resources()
				return
            else
				@debug "Changing scene"
                this.shouldChangeScene = false
                initialize_new_scene(this)
            end
        end
    end

    function create_new_entity(this::MainLoop)
		@debug "Creating new entity"
        SceneBuilderModule.create_new_entity(this.level)
    end

    function create_new_text_box(this::MainLoop)
		@debug "Creating new text box"
        SceneBuilderModule.create_new_text_box(this.level)
    end

	function create_new_screen_button(this::MainLoop)
		@debug "Creating new screen button"
		SceneBuilderModule.create_new_screen_button(this.level)
	end


	function initialize_scripts_and_components()
		this::MainLoop = MAIN
		scripts = []
		for entity in this.scene.entities
			for script in entity.scripts
				push!(scripts, script)
			end
		end

		if !this.isGameModeRunningInEditor
			for uiElement in this.scene.uiElements
				JulGame.initialize(uiElement)
			end
		end

		this.spriteLayers = build_sprite_layers()
		
		if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor

			for script in scripts
				try
					Base.invokelatest(JulGame.initialize, script)
				catch e
					if this.testMode
						rethrow(e)
					else
						@error string(e)
						Base.show_backtrace(stdout, catch_backtrace())
					end
				end
			end
			build_sprite_layers()

			for entity in MAIN.scene.entities
				@debug "Checking for a soundSource that needs to be activated"
				if entity.soundSource != C_NULL && entity.soundSource !== nothing && entity.soundSource.playOnStart
					Component.toggle_sound(entity.soundSource)
					@debug("Playing $(entity.name)'s ($(entity.id)) sound source on start")
				end
			end 
		end
				
		MAIN.scene.rigidbodies = []
		MAIN.scene.colliders = []
		for entity in MAIN.scene.entities
			@debug "adding rigidbodies to global list"
			if entity.rigidbody != C_NULL
				push!(MAIN.scene.rigidbodies, entity.rigidbody)
					end
			@debug "adding colliders to global list"
			if entity.collider != C_NULL
				push!(MAIN.scene.colliders, entity.collider)
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
function JulGame.change_scene(sceneFileName::String)
	JulGame.IS_CHANGING_SCENE = true
	this::MainLoop = MAIN
	@debug "Changing scene to: $(sceneFileName)"
	this.close = true
	this.shouldChangeScene = true
	
	# Clean up all immediate UI components
	JulGame.UI.ImmediateUIModule.cleanup_all_immediate_components()
	
	# Clean up all coroutines
	@debug "Cleaning up coroutines during scene change"
	cleanup_coroutines()
	
	#destroy current scene 
	@debug "Entity count before destroying: $(length(this.scene.entities))" 
	count = 0
	skipcount = 0
	persistentEntities = []	
	entitiesToDestroy = []

	for entity in this.scene.entities
		if entity.persistentBetweenScenes && (!JulGame.IS_EDITOR || this.isGameModeRunningInEditor)
			@debug("Persistent entity: ", entity.name, " with id: ", entity.id)
			push!(persistentEntities, entity)
			skipcount += 1
			continue
		end

		destroy_entity_components(this, entity)
		if !JulGame.IS_EDITOR
			for script in entity.scripts
				try
					Base.invokelatest(JulGame.on_shutdown, script)
				catch e
					if this.testMode
						rethrow(e)
					else
						if typeof(e) != ErrorException
							println("Error shutting down script: $(typeof(script))")
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
						end
					end
				end
			end
		end

		push!(entitiesToDestroy, entity)
		count += 1
	end

	for entity in entitiesToDestroy
		JulGame.destroy_entity(this, entity)
	end
	@debug "Destroyed $count entities while changing scenes"
	@debug "Skipped $skipcount entities while changing scenes"

	@debug "Entities left after destroying while changing scenes (persistent): $(length(persistentEntities)) "

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
	this.scene.name = split(sceneFileName, ".")[1]
	this.scene.entities = persistentEntities
	this.scene.uiElements = persistentUIElements
	this.scene.camera = camera
	this.level.scene = sceneFileName
	
	if JulGame.IS_EDITOR
		initialize_new_scene(this)
	end
	JulGame.IS_CHANGING_SCENE = false
end

"""
build_sprite_layers()

Builds the sprite layers for the main game.

"""
function build_sprite_layers()
	@debug "Building sprite layers"
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
function JulGame.destroy_entity(this::MainLoop, entity)
	for i = eachindex(this.scene.entities)
		if this.scene.entities[i] == entity
			destroy_entity_components(this, entity)
			deleteat!(this.scene.entities, i)
			this.selectedEntity = nothing
			break
		end
	end
end

function JulGame.destroy_entity(entity)
    JulGame.destroy_entity(MAIN, entity)
end

function JulGame.destroy_ui_element(this::MainLoop, uiElement)
	for i = eachindex(this.scene.uiElements)
		if this.scene.uiElements[i] == uiElement
			deleteat!(this.scene.uiElements, i)
			JulGame.destroy(uiElement)
			break
		end
	end
end

function destroy_entity_components(this::MainLoop, entity)
	entitySprite = entity.sprite
	if entitySprite != C_NULL
		if haskey(this.spriteLayers, "$(entitySprite.layer)")	
			for j = eachindex(this.spriteLayers["$(entitySprite.layer)"])
				if this.spriteLayers["$(entitySprite.layer)"][j] == entitySprite
					Component.destroy(entitySprite)
					deleteat!(this.spriteLayers["$(entitySprite.layer)"], j)
					break
				end
			end
		end
	end

	entityRigidbody = entity.rigidbody
	if entityRigidbody != C_NULL
		filter!(rb -> rb != entityRigidbody, this.scene.rigidbodies)
	end

	entityCollider = entity.collider
	if entityCollider != C_NULL
		filter!(col -> col != entityCollider, this.scene.colliders)
	end

	entitySoundSource = entity.soundSource
	if entitySoundSource != C_NULL
		Component.unload_sound(entitySoundSource)
	end

	entityMesh3D = entity.mesh3d
	if entityMesh3D != C_NULL
		Component.destroy(entityMesh3D)
	end
end

export create_entity
"""
create_entity(entity)

Create a new entity. Adds the entity to the main game's entities array and adds the entity's sprite to the sprite layers so that it is rendered.

# Arguments
- `entity`: The entity to create.

"""
function JulGame.create_entity(entity)
	this::MainLoop = MAIN
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
game_loop(this::MainLoop, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), close::Ref{Bool} = Ref(Bool(false)), Vector{Any}} = C_NULL)

Runs the game loop.

Parameters:
- `this`: The main struct.
- `startTime`: A reference to the start time of the game loop.
- `lastPhysicsTime`: A reference to the last physics time of the game loop.
"""
function game_loop(this::MainLoop, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), windowPos::Math.Vector2 = Math.Vector2(0,0), windowSize::Math.Vector2 = Math.Vector2(0,0))
	if this.shouldChangeScene && !JulGame.IS_EDITOR
		this.shouldChangeScene = false
		initialize_new_scene(this)
		return
	end
	try
			lastStartTime = startTime[]
			startTime[] = SDL2.SDL_GetPerformanceCounter()

			DEBUG = false
			#region Input
			if !JulGame.IS_EDITOR && !JulGame.IS_WEB
				JulGame.InputModule.poll_input(this.input)

				this.close = this.input.quit
				SDL2.SDL_RenderClear(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
			end

			DEBUG = this.input.debug
			cameraPosition = this.scene.camera !== nothing ? (this.scene.camera.position + this.scene.camera.offset) : Math.Vector2f(0,0)
			cameraSize = this.scene.camera !== nothing ? this.scene.camera.size : Math.Vector2(0,0)

			x = 0
			y = 0
			if JulGame.InputModule.get_button_held_down(this.input, "Right")
				x = 1
			elseif JulGame.InputModule.get_button_held_down(this.input, "Left")
				x = -1
			end

			if JulGame.InputModule.get_button_held_down(this.input, "Up")
				y = 1
			elseif JulGame.InputModule.get_button_held_down(this.input, "Down")
				y = -1
			end
			
			#region Physics
			if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor
				currentPhysicsTime = SDL2.SDL_GetTicks()
				deltaTime = (currentPhysicsTime - lastPhysicsTime[]) / 1000.0
				JulGame.DELTA_TIME = deltaTime
				this.currentTestTime += deltaTime
				if deltaTime > .25
					lastPhysicsTime[] =  SDL2.SDL_GetTicks()
					# TODO: pause simulation
					#return
				end
				for rigidbody in this.scene.rigidbodies
					try
						JulGame.update(rigidbody, deltaTime)
					catch e
						if this.testMode
							rethrow(e)
						else
							println(rigidbody.parent.name, " with id: ", rigidbody.parent.id, " has a problem with it's rigidbody")
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
						end
					end
				end
				lastPhysicsTime[] =  currentPhysicsTime
			end

			#region Rendering
			currentRenderTime = SDL2.SDL_GetTicks()
			if this.scene.camera !== nothing && !JulGame.IS_EDITOR && !JulGame.IS_WEB
				JulGame.CameraModule.update(this.scene.camera)
			end

			for entity in this.scene.entities
				if !entity.isActive
					continue
				end

				if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor
					try
                        JulGame.update(entity, deltaTime)
						if this.close && !this.isGameModeRunningInEditor
							@debug "Closing game"
							return
						end
					catch e
						if this.testMode
							rethrow(e)
						else
							println(entity.name, " with id: ", entity.id, " has a problem with it's update")
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
						end
					end
					entityAnimator = entity.animator
					if entityAnimator != C_NULL
                        JulGame.update(entityAnimator, currentRenderTime, deltaTime)
					end
				end
			end

			coroutines_to_remove = []
			for coroutine in JulGame.Coroutines
				if istaskdone(coroutine.task)
					push!(coroutines_to_remove, coroutine)
					continue
				end

				notify(coroutine.condition)
				yield()
			end

			for coroutine_to_remove in coroutines_to_remove
				@debug("coroutine done, removing")
				deleteat!(JulGame.Coroutines, findfirst(x -> x == coroutine_to_remove, JulGame.Coroutines))
			end
			
			if !JulGame.IS_EDITOR && !JulGame.IS_WEB
				render_scene_sprites_and_shapes(this, this.scene.camera)
			end
			
			if JulGame.IS_DEBUG
				render_scene_debug(this, cameraPosition, cameraSize)
			end

			#region UI
			# Sort UI elements by layer before rendering
			uiRenderingOrder = []
			for uiElement in this.scene.uiElements
				push!(uiRenderingOrder, (uiElement.layer, uiElement))
			end
			render_functions_to_call = filter(x -> !x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
			filter!(x -> x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
			for render_function in render_functions_to_call
				push!(uiRenderingOrder, (render_function.layer, render_function))
			end

			sort!(uiRenderingOrder, by = x -> x[1])
			for i = eachindex(uiRenderingOrder)
				try
					if uiRenderingOrder[i][2] isa NamedTuple
						func = uiRenderingOrder[i][2].function_to_call
						Base.invokelatest(func)
					else
						JulGame.render(uiRenderingOrder[i][2])
					end
				catch e
					if this.testMode
						rethrow(e)
					else
						parent_info = ""
						if isa(uiRenderingOrder[i][2], NamedTuple) && hasfield(typeof(uiRenderingOrder[i][2]), :function_to_call)
							parent_info = "a queued render function ($(uiRenderingOrder[i][2].function_to_call))"
						elseif isa(uiRenderingOrder[i][2], UI.UIElement) 
							parent_info = "a ui element of type $(typeof(uiRenderingOrder[i][2]))"
						end
						println(parent_info, " has a problem with it's render function")
						@error string(e)
						Base.show_backtrace(stdout, catch_backtrace())
					end
				end
			end
			

			# Render all immediate UI components
			UI.ImmediateUIModule.render_all_immediate_components()

			pos1::Math.Vector2 = windowPos !== nothing ? windowPos : Math.Vector2(0, 0)
			this.input.mousePositionWorld = Math.Vector2f((this.input.mousePosition.x - this.input.mousePositionEditorGameWindowOffset.x + (cameraPosition.x * SCALE_UNITS)) / SCALE_UNITS, (this.input.mousePosition.y - this.input.mousePositionEditorGameWindowOffset.y + (cameraPosition.y * SCALE_UNITS)) / SCALE_UNITS)
			rawMousePos = Math.Vector2f(this.input.mousePosition.x - pos1.x , this.input.mousePosition.y - pos1.y)
			#region Debug
			if JulGame.IS_DEBUG
				# Stats to display
				statTexts = [
					"FPS: $(round(1000 / round((startTime[] - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0)))",
					"Frame time: $(round((startTime[] - lastStartTime) / SDL2.SDL_GetPerformanceFrequency() * 1000.0)) ms",
					"Raw Mouse pos: $(rawMousePos.x),$(rawMousePos.y)",
					"Mouse pos world: $(this.input.mousePositionWorld.x),$(this.input.mousePositionWorld.y)"
				]

				# Draw a gray rect under the debug textboxes
				rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
				SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
				currentColor = (r = rgba.r[], g = rgba.g[], b = rgba.b[], a = rgba.a[])
				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 100, 100, 100, 255)
				SDL2.SDL_RenderFillRect(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(SDL2.SDL_Rect(0, 35, 400, 35 * length(statTexts))))
				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, currentColor[1], currentColor[2], currentColor[3], currentColor[4])

				if length(this.debugTextBoxes) == 0
					for i = eachindex(statTexts)
				 		textBox = UI.TextBoxModule.TextBox(statTexts[i]; fontSize = 24, position = Math.Vector2(0, 35 * i))
				 		push!(this.debugTextBoxes, textBox)
                         JulGame.initialize(textBox)
				 	end
				 else
				 	for i = eachindex(this.debugTextBoxes)
                         db_textbox = this.debugTextBoxes[i]
                         db_textbox.text = statTexts[i]
                         JulGame.render(db_textbox)
			 	  	end
				 end
			end

			if !istaskdone(this.errorLogger.task)
				notify(this.errorLogger.condition)
				yield()
			end

			if !JulGame.IS_EDITOR && !JulGame.IS_WEB
				SDL2.SDL_RenderPresent(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
				SDL2.SDL_framerateDelay(this.windowManager.fpsManager)
			elseif JulGame.IS_WEB
				SDL2.SDL_framerateDelay(this.windowManager.fpsManager)
				entt = "["
				for i = 1:length(this.scene.entities)
					entt *= "{ \"x\": $(this.scene.entities[i].transform.position.x), \"y\": $(this.scene.entities[i].transform.position.y) }"

					if i < length(this.scene.entities)
						entt *= ","
					end
				end

				entt *= "]"

				return entt
			end
		catch e
			if this.testMode
				rethrow(e)
			else
				@error string(e)
				Base.show_backtrace(stdout, catch_backtrace())
			end
		end
    end

	function render_scene_sprites_and_shapes(this::MainLoop, camera::Camera)
		cameraPosition = camera !== nothing ? camera.position : Math.Vector2f(0,0)
		cameraSize = camera !== nothing ? camera.size : Math.Vector2(0,0)
			
		skipcount = 0
		rendercount = 0
		renderOrder = []
		for entity in this.scene.entities
			spriteExists = entity.sprite != C_NULL && entity.sprite !== nothing
			shapeExists = entity.shape != C_NULL && entity.shape !== nothing
			mesh3dExists = entity.mesh3d != C_NULL && entity.mesh3d !== nothing
			if !entity.isActive || (!spriteExists && !shapeExists && !mesh3dExists)
				continue
			end

			position = entity.transform.position
			size = entity.transform.scale
			sprite = entity.sprite
			shape = entity.shape
			mesh3d = entity.mesh3d

			skipSprite = false
			skipShape = false
			skipMesh3d = false

			# TODO: consider offset
			if spriteExists && ((position.x + size.x) < cameraPosition.x || position.y < cameraPosition.y || position.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || (position.y - size.y) > cameraPosition.y + cameraSize.y/SCALE_UNITS) && sprite.isWorldEntity && this.optimizeSpriteRendering 
				skipSprite = true
			end

			# TODO: consider offset
			if shapeExists && ((position.x + size.x) < cameraPosition.x || position.y < cameraPosition.y || position.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || (position.y - size.y) > cameraPosition.y + cameraSize.y/SCALE_UNITS) && shape.isWorldEntity && this.optimizeSpriteRendering 
				skipShape = true
			end

			if !skipSprite && spriteExists
				push!(renderOrder, (sprite.layer, sprite))
			end
			if !skipShape && shapeExists
				push!(renderOrder, (shape.layer, shape))
			end
			if !skipMesh3d && mesh3dExists
				push!(renderOrder, (mesh3d.layer, mesh3d))
			end
		end

		render_functions_to_call = filter(x -> x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
		filter!(x -> !x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
		for render_function in render_functions_to_call
			push!(renderOrder, (render_function.layer, render_function))
		end
		sort!(renderOrder, by = x -> x[1])
		
		for i = eachindex(renderOrder)
			try
				rendercount += 1
				if renderOrder[i][2] isa Component.Mesh3DModule.Mesh3D
					Component.render(renderOrder[i][2], this)
				elseif renderOrder[i][2] isa Component.SpriteModule.InternalSprite || renderOrder[i][2] isa Component.ShapeModule.InternalShape 
					Component.draw(renderOrder[i][2], camera)
				elseif renderOrder[i][2] isa NamedTuple
					# get the params	
					func = renderOrder[i][2].function_to_call
					Base.invokelatest(func)
				else
					println("Unknown item type: ", typeof(renderOrder[i][2]))
				end
			catch e
				if this.testMode
					rethrow(e)
				else
					parent_info = ""
					if isa(renderOrder[i][2], NamedTuple) && hasfield(typeof(renderOrder[i][2]), :function_to_call)
						parent_info = "a queued render function ($(renderOrder[i][2].function_to_call))"
					elseif hasproperty(renderOrder[i][2], :parent) && renderOrder[i][2].parent !== nothing && isa(renderOrder[i][2].parent, JulGame.EntityModule.Entity)
						parent_info = "$(renderOrder[i][2].parent.name) with id: $(renderOrder[i][2].parent.id)"
					else 
						parent_info = "a component of type $(typeof(renderOrder[i][2]))"
					end
					println(parent_info, " has a problem with rendering")
					@error string(e)
					Base.show_backtrace(stdout, catch_backtrace())
				end
			end
		end
	end

	function start_game_in_editor(this::MainLoop, path::String)
		this.isGameModeRunningInEditor = true
		SceneBuilderModule.add_scripts_to_entities(path)
		initialize_scripts_and_components()
	end

	function stop_game_in_editor(this::MainLoop)
		this.isGameModeRunningInEditor = false
		SDL2.Mix_HaltMusic()
		
		# Clean up all immediate UI components when stopping the game in editor
		JulGame.UI.ImmediateUIModule.cleanup_all_immediate_components()
		
		# Clean up all coroutines when stopping the game in editor
		@debug "Cleaning up coroutines when stopping game in editor"
		cleanup_coroutines()
		
		if this.scene.camera !== nothing && this.scene.camera != C_NULL
			this.scene.camera.target = C_NULL
		end
	end

	function render_scene_debug(this::MainLoop, cameraPosition, cameraSize)
		colliderSkipCount = 0
		colliderRenderCount = 0
		for entity in this.scene.entities
			if !entity.isActive
				continue
			end
	
			if entity.collider != C_NULL
				rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
        		SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
				pos = entity.transform.position
				scale = entity.transform.scale
	
				if ((pos.x + scale.x) < cameraPosition.x || pos.y < cameraPosition.y || pos.x > cameraPosition.x + cameraSize.x/SCALE_UNITS || (pos.y - scale.y) > cameraPosition.y + cameraSize.y/SCALE_UNITS)  && this.optimizeSpriteRendering 
					colliderSkipCount += 1
					continue
				end
				colliderRenderCount += 1
				collider = entity.collider
	
				
				colSize = collider.size
				colSize = Math.Vector2f(colSize.x, colSize.y)
				colOffset = collider.offset
				colOffset = Math.Vector2f(colOffset.x, colOffset.y)
						
				SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
				Ref(SDL2.SDL_FRect((pos.x + colOffset.x - cameraPosition.x) * SCALE_UNITS, 
				(pos.y + colOffset.y - cameraPosition.y) * SCALE_UNITS, 
				entity.transform.scale.x * colSize.x * SCALE_UNITS, 
				entity.transform.scale.y * colSize.y * SCALE_UNITS)))
				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);
			end
		end
	end

	function JulGame.cleanup_sdl_resources()
		SDL2.SDL_ClearError()
		@debug "Closing window"
		if JulGame.Renderer != C_NULL
			SDL2.SDL_DestroyRenderer(JulGame.Renderer)
			if unsafe_string(SDL2.SDL_GetError()) != ""
				@error "Failed to destroy renderer, $(unsafe_string(SDL2.SDL_GetError()))"
			end
		end
		SDL2.SDL_ClearError()
		
		# Use the WindowManager to close the window
		if JulGame.MAIN.windowManager !== nothing
			JulGame.WindowManagerModule.close_window()
		end
		
		SDL2.SDL_ClearError()
        # Reset any OpenGL-related attributes that might have been set
        @debug "Resetting GL attributes"
        SDL2.SDL_GL_ResetAttributes()
		if unsafe_string(SDL2.SDL_GetError()) != ""
			@error "Failed to reset GL attributes, $(unsafe_string(SDL2.SDL_GetError()))"
		end
		SDL2.SDL_ClearError()
		@debug "Quitting Mix"
        SDL2.Mix_Quit()
		if unsafe_string(SDL2.SDL_GetError()) != ""
			@error "Failed to quit Mix, $(unsafe_string(SDL2.SDL_GetError()))"
		end
		SDL2.SDL_ClearError()
		@debug "Quitting TTF"
        SDL2.TTF_Quit()
		if unsafe_string(SDL2.SDL_GetError()) != ""
			@error "Failed to quit TTF, $(unsafe_string(SDL2.SDL_GetError()))"
		end
		SDL2.SDL_ClearError()
		@debug "Quitting SDL"
        SDL2.SDL_Quit()
		if unsafe_string(SDL2.SDL_GetError()) != ""
			@error "Failed to quit SDL, $(unsafe_string(SDL2.SDL_GetError()))"
		end
	end
end # module

