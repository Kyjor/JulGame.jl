module MainLoopModule
	using ..JulGame
	using ..JulGame.ErrorLoggingModule
	using ..JulGame: Camera, Component, Input, Math, UI, SceneModule, WindowManager
    import ..JulGame: Component
    import ..JulGame.SceneManagement: SceneBuilderModule
	import ..JulGame
	using Statistics

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

	export MainLoop, mark_input_layer_order_dirty!
	mutable struct MainLoop
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
		selectedEntities::Union{Vector{Any}, Nothing}
		shouldChangeScene::Bool
		spriteLayers::NamedTuple{(:layers, :sorted), Tuple{Dict{Int, Vector{Any}}, Vector{Int}}}
		testLength::Float64
		testMode::Bool
		windowManager::WindowManager
		
		
		cachedInputLayerOrder::Vector{Any}
		# Cached input layer order (rebuilt only when layers change)
		inputLayerOrderDirty::Bool
		# Scratch buffers for input hit-testing (avoid per-event allocations)
		scratchInputCanvases::Vector{Any}
		scratchInputHiddenCanvasChildIds::Set{UInt}

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
			this.selectedEntities = []
			this.shouldChangeScene = false
			this.input.main = this
			this.isGameModeRunningInEditor = false

			this.currentTestTime = 0.0
			this.testMode = false
			this.testLength = 0.0
			this.coroutine_condition = Condition()
			this.errorLogger = ErrorLoggingModule.ErrorLogger()
			this.spriteLayers = (layers = Dict{Int, Vector{Any}}(), sorted = Int[])

			this.windowManager = WindowManager()
			
			# Initialize cached input layer order
			this.cachedInputLayerOrder = Vector{Any}()
			sizehint!(this.cachedInputLayerOrder, 100)  # Pre-allocate
			this.inputLayerOrderDirty = true  # Build on first use
			this.scratchInputCanvases = Vector{Any}()
			sizehint!(this.scratchInputCanvases, 16)
			this.scratchInputHiddenCanvasChildIds = Set{UInt}()
			
			# Initialize script tracking

			return this
		end
	end

	JulGame.main_loop() = (JulGame.MAIN)::MainLoop

	"""
		mark_input_layer_order_dirty!(this::MainLoop)
	
	Mark the input layer order cache as dirty, forcing a rebuild on next access.
	Call this when adding/removing UI elements or entities, or when changing layers.
	"""
	function mark_input_layer_order_dirty!(this::MainLoop)
		this.inputLayerOrderDirty = true
	end
	
	# ============================================================================
	# SCRIPT LIFECYCLE CALLS
	# Wrapper functions for calling dynamically-loaded script methods.
	# Uses JulGame.dispatch, which handles world age issues (and `juliac --trim`).
	# ============================================================================
	
	"""
		call_script_initialize(this::MainLoop, script)
	
	Call script initialization method.
	"""
	@inline function call_script_initialize(this::MainLoop, script::Script)
		JulGame.dispatch(JulGame.initialize, script)
	end
	
	"""
		call_script_update(this::MainLoop, script, deltaTime)
	
		Call script update method.
	"""
	@inline function call_script_update(this::MainLoop, script::Script, deltaTime::Float64)
		JulGame.dispatch_over_subtypes(JulGame.update, Val{Script}(), JulGame.ErasedTarget(script), deltaTime)
	end
	
	"""
		call_script_shutdown(this::MainLoop, script)
	
	Call script shutdown/cleanup method.
	"""
	@inline function call_script_shutdown(this::MainLoop, script::Script)
		JulGame.dispatch(JulGame.on_shutdown, script)
	end

	@inline function call_ui_initialize(this::MainLoop, uiElement::JulGame.IUIElement)
		JulGame.dispatch(JulGame.initialize, uiElement)
	end

	function prepare_window_scripts_and_start_loop(size)
		@debug "Preparing window"
		JulGame.main_loop().windowManager.windowSize = size

		@debug "Initializing scripts and components"
		@timed_step "scene init: total (scripts and components)" initialize_scripts_and_components()

		if !JulGame.IS_EDITOR && !JulGame.IS_WEB
			@debug "Starting non editor loop"
			full_loop(JulGame.main_loop())
			return
		end
	end
	
    function initialize_new_scene(this::MainLoop)
		@debug "Initializing new scene"
		@debug "Deserializing and building scene"
        @timed_step "Deserializing and building scene: $(this.level.scene)" SceneBuilderModule.deserialize_and_build_scene(this.level)

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
        this.scene.camera.position = Math.Vector3f(0.0, 0.0, 0.0)
    end
	
    function full_loop(this::MainLoop)
        try
			this.close = false
            startTime = Ref(UInt64(0))
            lastPhysicsTime = Ref(UInt64(SDL2.SDL_GetTicks()))
            isFirstFrame = true
            while !this.close
                try
                    if isFirstFrame
                        # First frame lazily bakes effect textures for visible
                        # elements and JIT-compiles the render path.
                        @timed_step "first frame" game_loop(this, startTime, lastPhysicsTime)
                        isFirstFrame = false
                    else
                        game_loop(this, startTime, lastPhysicsTime)
                    end
                catch e
                    if this.testMode
                        throw(e)
                    else
						if this.testMode
							rethrow(e)
						else
							JulGame.log_exception("Error in MainLoop.jl", e)
						end
                    end
                end
                if this.testMode && this.currentTestTime >= this.testLength
					@info "Test mode complete"
                    break
                end
            end
        finally
            for entity in this.scene.entities
                for script in entity.scripts
                    try
                        call_script_shutdown(this, script)
                    catch e
						if this.testMode
							rethrow(e)
						else
							if typeof(e) != ErrorException
								JulGame.log_exception("Error shutting down script: $(typeof(script))", e)
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

	function create_new_image(this::MainLoop)
		@debug "Creating new image"
		SceneBuilderModule.create_new_image(this.level)
	end

	function create_new_rectangle(this::MainLoop)
		@debug "Creating new rectangle"
		SceneBuilderModule.create_new_rectangle(this.level)
	end

	function create_new_canvas(this::MainLoop)
		@debug "Creating new canvas"
		canvas = SceneBuilderModule.create_new_canvas(this.level)
		return canvas
	end

	function create_new_canvas()
		canvas = create_new_canvas(JulGame.main_loop())
		return canvas
	end

	function initialize_scripts_and_components()
		this::MainLoop = MAIN
		scripts = Script[]
		for entity in this.scene.entities
			for script in entity.scripts
				push!(scripts, script)
			end
		end

		if !this.isGameModeRunningInEditor
			@timed_step "scene init: uiElements ($(length(this.scene.uiElements)))" for uiElement in this.scene.uiElements
				call_ui_initialize(this, uiElement)
			end
		end

		this.spriteLayers = build_sprite_layers()

		if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor

			for script in scripts
				try
					@timed_step "scene init: script $(typeof(script))" call_script_initialize(this, script)
				catch e
					if this.testMode
						rethrow(e)
					else
						JulGame.log_exception("Failed to initialize script $(typeof(script))", e)
					end
				end
			end
			build_sprite_layers()

			@timed_step "scene init: play-on-start sounds" for entity in JulGame.main_loop().scene.entities
				@debug "Checking for a soundSource that needs to be activated"
				if entity.soundSource != C_NULL && entity.soundSource !== nothing && entity.soundSource.playOnStart && !entity.soundSource.isPlaying
					@debug("Playing $(entity.name)'s ($(entity.id)) sound source on start: $(entity.soundSource.path)")
					Component.toggle_sound(entity.soundSource)
				end
			end 
		end
				
		JulGame.main_loop().scene.rigidbodies = JulGame.RigidbodyModule.InternalRigidbody[]
		JulGame.main_loop().scene.colliders = JulGame.ColliderModule.InternalCollider[]
		for entity in JulGame.main_loop().scene.entities
			@debug "adding rigidbodies to global list"
			if entity.rigidbody != C_NULL
				push!(JulGame.main_loop().scene.rigidbodies, entity.rigidbody)
					end
			@debug "adding colliders to global list"
			if entity.collider != C_NULL
				push!(JulGame.main_loop().scene.colliders, entity.collider)
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
					call_script_shutdown(this, script)
				catch e
					if this.testMode
						rethrow(e)
					else
						if typeof(e) != ErrorException
							JulGame.log_exception("Error shutting down script: $(typeof(script))", e)
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
		if uiElement.persistentBetweenScenes && (!JulGame.IS_EDITOR || this.isGameModeRunningInEditor)
			#println("Persistent uiElement: ", uiElement.name)
			push!(persistentUIElements, uiElement)
			skipcount += 1
			continue
		end
		if uiElement isa UI.UIImageModule.UIImage
			JulGame.destroy(uiElement)
		elseif uiElement isa UI.TextBoxModule.TextBox
			JulGame.destroy(uiElement)
		elseif uiElement isa UI.ScreenButtonModule.ScreenButton
			JulGame.destroy(uiElement)
		elseif uiElement isa UI.RectangleModule.Rectangle
			JulGame.destroy(uiElement)
		elseif uiElement isa UI.CanvasModule.Canvas
			JulGame.destroy(uiElement)
		end
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
Returns a named tuple with (layers = Dict{Int, Vector}, sorted = Vector{Int})

"""
function build_sprite_layers()
	@debug "Building sprite layers"
	layerDict = Dict{Int, Vector{Any}}()  # Int keys instead of String - no allocations!
	sortedLayers = Int[]
	
	for entity in JulGame.main_loop().scene.entities
		entitySprite = entity.sprite
		if entitySprite != C_NULL
			layer = entitySprite.layer
			if !haskey(layerDict, layer)  # No string interpolation!
				push!(sortedLayers, layer)
				layerDict[layer] = [entitySprite]
			else
				push!(layerDict[layer], entitySprite)
			end
		end
	end
	sort!(sortedLayers)
	
	return (layers = layerDict, sorted = sortedLayers)  # Return named tuple
end

function JulGame.initialize(this::Any)
	#@warn "⚠️  FALLBACK initialize called for: $(typeof(this))"
end

function JulGame.update(this::Any, deltaTime::Any)
	#@warn "⚠️  FALLBACK update called for: $(typeof(this))"
end

function JulGame.on_shutdown(this::Any)
	#@warn "⚠️  FALLBACK on_shutdown called for: $(typeof(this))"
end

export destroy_entity
"""
destroy_entity(entity)

Destroy the specified entity. This removes the entity's sprite from the sprite layers so that it is no longer rendered. It also removes the entity's rigidbody from the main game's rigidbodies array.

# Arguments
- `entity`: The entity to be destroyed.
"""
function JulGame.destroy_entity(this::MainLoop, @nospecialize(entity::JulGame.IEntity))
	for i = eachindex(this.scene.entities)
		if this.scene.entities[i] === entity
			destroy_entity_components(this, entity)
			deleteat!(this.scene.entities, i)
			selectedEntities = this.selectedEntities
			if selectedEntities isa Vector{Any}
				entity_index = findfirst(x -> x === entity, selectedEntities)
				if entity_index !== nothing
					deleteat!(selectedEntities, entity_index)
				end
			end
			mark_input_layer_order_dirty!(this)  # Cache needs rebuild
			break
		end
	end
end

function JulGame.destroy(this::MainLoop, entity::JulGame.Entity)
	JulGame.destroy_entity(this, entity)
end

function JulGame.destroy(entity::JulGame.Entity)
	JulGame.destroy(JulGame.main_loop(), entity)
end

function JulGame.destroy_entity(@nospecialize(entity::JulGame.IEntity))
    JulGame.destroy_entity(JulGame.main_loop(), entity)
end

function JulGame.destroy_ui_element(this::MainLoop, uiElement)
	for i = eachindex(this.scene.uiElements)
		if this.scene.uiElements[i] == uiElement
			deleteat!(this.scene.uiElements, i)
			JulGame.destroy(uiElement)
			mark_input_layer_order_dirty!(this)  # Cache needs rebuild
			break
		end
	end
end

function destroy_entity_components(this::MainLoop, @nospecialize(entity::JulGame.IEntity))
	entitySprite = entity.sprite
	if entitySprite != C_NULL
		layer = entitySprite.layer
		if haskey(this.spriteLayers.layers, layer)  # No string interpolation!
			for j = eachindex(this.spriteLayers.layers[layer])
				if this.spriteLayers.layers[layer][j] === entitySprite
					Component.destroy(entitySprite)
					deleteat!(this.spriteLayers.layers[layer], j)
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
end

export create_entity
"""
create_entity(entity)

Create a new entity. Adds the entity to the main game's entities array and adds the entity's sprite to the sprite layers so that it is rendered.

# Arguments
- `entity`: The entity to create.

"""
function JulGame.create_entity(@nospecialize(entity::JulGame.IEntity))
	this::MainLoop = MAIN
	push!(this.scene.entities, entity)
	if entity.sprite != C_NULL
		layer = entity.sprite.layer
		if !haskey(this.spriteLayers.layers, layer)  # No string interpolation!
			push!(this.spriteLayers.sorted, layer)
			this.spriteLayers.layers[layer] = [entity.sprite]
			sort!(this.spriteLayers.sorted)
		else
			push!(this.spriteLayers.layers[layer], entity.sprite)
		end
	end

	if entity.rigidbody != C_NULL
		push!(this.scene.rigidbodies, entity.rigidbody)
	end

	if entity.collider != C_NULL
		push!(this.scene.colliders, entity.collider)
	end
	
	mark_input_layer_order_dirty!(this)  # Cache needs rebuild

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
@inline function _accum_ui_render_breakdown_ms!(prof, t0::Ref{UInt64}, key::Symbol)
	prof === nothing && return
	t1 = time_ns()
	t0[] = t1
	return
end

function game_loop(this::MainLoop, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), windowPos::Math.Vector2 = Math.Vector2(0,0), windowSize::Math.Vector2 = Math.Vector2(0,0))
	JulGame.FrameCount += 1
	if this.shouldChangeScene && !JulGame.IS_EDITOR
		this.shouldChangeScene = false
		initialize_new_scene(this)
		return
	end
	try
			# Upload any effect textures finished by the async prewarm worker
			if !JulGame.IS_EDITOR
				Component.SpriteModule.pump_effect_prewarm!()
				UI.TextBoxModule.pump_text_effect_prewarm!()
				UI.UIImageModule.pump_effect_bakes!()
			end
			lastStartTime = startTime[]
			startTime[] = SDL2.SDL_GetPerformanceCounter()

			DEBUG = false
			#region Input
			if !JulGame.IS_EDITOR && !JulGame.IS_WEB
				JulGame.InputModule.poll_input(this.input)

				this.close = this.input.quit
				if this.close
					JulGame.engine_states.current_state = :quit
				end

				SDL2.SDL_RenderClear(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
			end

			DEBUG = this.input.debug
			cameraPosition = this.scene.camera !== nothing ? (this.scene.camera.position + this.scene.camera.offset) : Math.Vector2f(0,0)
			cameraSize = this.scene.camera !== nothing ? this.scene.camera.size : Math.Vector2(0,0)
			S_mouse_now = JulGame.pixels_per_world_unit(this.scene.camera)
			this.input.mousePositionWorld = Math.Vector2f((this.input.mousePosition.x + (cameraPosition.x * S_mouse_now)) / S_mouse_now, (this.input.mousePosition.y + (cameraPosition.y * S_mouse_now)) / S_mouse_now)

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
				if this.testMode
					this.currentTestTime += deltaTime
				end
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
							JulGame.log_exception(string(rigidbody.parent.name, " with id: ", rigidbody.parent.id, " has a problem with it's rigidbody"), e)
						end
					end
				end
				lastPhysicsTime[] =  currentPhysicsTime
				
			end

		#region Rendering
		currentRenderTime::UInt32 = SDL2.SDL_GetTicks()
		if this.scene.camera !== nothing && !JulGame.IS_EDITOR && !JulGame.IS_WEB
			JulGame.CameraModule.update(this.scene.camera)
		end
		
			for entity in this.scene.entities
				if !entity.isActive
					continue
				end

				if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor
					for script in entity.scripts
						try
							call_script_update(this, script, deltaTime)
						catch e
							if this.testMode
								rethrow(e)
							else
								JulGame.log_exception(string(entity.name, " ", string(nameof(typeof(script))), " update"), e)
							end
						end
					end
					if this.close && !this.isGameModeRunningInEditor
						@debug "Closing game"
						JulGame.engine_states.current_state = :quit
						return
					end
					entityAnimator = entity.animator
					if entityAnimator isa Component.AnimatorModule.InternalAnimator
						JulGame.update(entityAnimator, currentRenderTime)
					end
				end
			end

			coroutines_to_remove = JulGame.CoroutineModule.Coroutine[]
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
			
			if !JulGame.IS_EDITOR	
				render_scene_sprites_and_shapes(this, this.scene.camera)
			end
			
			if JulGame.IS_DEBUG
				render_scene_debug(this, cameraPosition, cameraSize)
			end

			uiRenderingOrder = Tuple{Int, Union{JulGame.IUIElement, JulGame.RenderFunction}}[]
			canvases = UI.CanvasModule.Canvas[]
			for uiElement in this.scene.uiElements
				if uiElement isa UI.CanvasModule.Canvas
					push!(canvases, uiElement)
				end
			end
			immediate_scene_skip = UI.ImmediateUIModule.immediate_ui_managed_scene_skip_ids()
			for uiElement in this.scene.uiElements
				if Base.objectid(uiElement) in immediate_scene_skip
					continue
				end
				# TODO: Only render UI elements that are not children of a Canvas
				# Canvas children will be rendered by their parent Canvas
				#if uiElement.parent === nothing || !isa(uiElement.parent, UI.Canvas)
					push!(uiRenderingOrder, (uiElement.layer, uiElement))
				#end
			end
			render_functions_to_call = filter(x -> !x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
			filter!(x -> x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
			for render_function in render_functions_to_call
				push!(uiRenderingOrder, (render_function.layer, render_function))
			end
			immediateUIComponents = UI.ImmediateUIModule.manage_all_immediate_components()
			for immediateUIComponent in immediateUIComponents
				push!(uiRenderingOrder, (immediateUIComponent.layer, immediateUIComponent))
			end

			sort!(uiRenderingOrder, by = x -> x[1])
			for i = eachindex(uiRenderingOrder)
				try
					skipCanvasChild = false
					for canvas in canvases
						if uiRenderingOrder[i][2] in canvas.children && !canvas.isActive
							skipCanvasChild = true
							break
						end
					end
					if skipCanvasChild
						continue
					end
					tgt = uiRenderingOrder[i][2]
					if tgt isa JulGame.RenderFunction
						tgt.function_to_call()
					else
						JulGame.dispatch(JulGame.render, tgt::JulGame.IUIElement)
					end
				catch e
					if this.testMode
						rethrow(e)
					else
						parent_info = ""
						if isa(uiRenderingOrder[i][2], JulGame.RenderFunction)
							parent_info = "a queued render function"
						elseif isa(uiRenderingOrder[i][2], UI.UIElement) 
							parent_info = "a ui element of type $(typeof(uiRenderingOrder[i][2]))"
						end
						JulGame.log_exception(string(parent_info, " has a problem with it's render function"), e)
					end
				end
			end
			
			pos1::Math.Vector2 = windowPos !== nothing ? windowPos : Math.Vector2(0, 0)
			S_mouse = JulGame.pixels_per_world_unit(this.scene.camera)
			this.input.mousePositionWorld = Math.Vector2f((this.input.mousePosition.x + (cameraPosition.x * S_mouse)) / S_mouse, (this.input.mousePosition.y + (cameraPosition.y * S_mouse)) / S_mouse)
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

			errorLoggerTask = this.errorLogger.task
			if errorLoggerTask isa Task && !istaskdone(errorLoggerTask)
				notify(this.errorLogger.condition)
				yield()
			end

			if !JulGame.IS_EDITOR
				SDL2.SDL_RenderPresent(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
				SDL2.SDL_framerateDelay(this.windowManager.fpsManager)
			end
		catch e
			if this.testMode
				rethrow(e)
			else
				JulGame.log_exception("Error in MainLoop.jl", e)
			end
		end
		
    end

	function render_scene_sprites_and_shapes(this::MainLoop, camera::Camera)
		cameraPosition = camera !== nothing ? camera.position : Math.Vector2f(0,0)
		cameraSize = camera !== nothing ? camera.size : Math.Vector2(0,0)
		S = JulGame.pixels_per_world_unit(camera)
			
		skipcount = 0
		rendercount = 0
		renderOrder = Tuple{Int, Union{Component.SpriteModule.InternalSprite, Component.ShapeModule.InternalShape, JulGame.RenderFunction}}[]
		for entity in this.scene.entities
			sprite = entity.sprite
			shape = entity.shape
			if !entity.isActive || !(sprite isa Component.SpriteModule.InternalSprite || shape isa Component.ShapeModule.InternalShape)
				continue
			end

			position = entity.transform.position
			size = entity.transform.scale
			# TODO: consider offset
			isOutsideCamera = (position.x + size.x) < cameraPosition.x || position.y < cameraPosition.y || position.x > cameraPosition.x + cameraSize.x/S || (position.y - size.y) > cameraPosition.y + cameraSize.y/S

			if sprite isa Component.SpriteModule.InternalSprite
				if isOutsideCamera && this.optimizeSpriteRendering
					sprite.lastRenderedScreenPosition = nothing
					sprite.lastRenderedScreenSize = nothing
				else
					push!(renderOrder, (sprite.layer, sprite))
				end
			end
			if shape isa Component.ShapeModule.InternalShape
				if !(isOutsideCamera && shape.isWorldEntity && this.optimizeSpriteRendering)
					push!(renderOrder, (shape.layer, shape))
				end
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
			item = renderOrder[i][2]
			if item isa JulGame.RenderFunction
				item.function_to_call()
			else
				Component.draw(item, camera)
			end
			catch e
				if this.testMode
					rethrow(e)
				else
					parent_info = ""
					failedItem = renderOrder[i][2]
					if failedItem isa JulGame.RenderFunction
						parent_info = "a queued render function"
					else
						parent_info = "$(failedItem.parent.name) with id: $(failedItem.parent.id)"
					end
					JulGame.log_exception(string(parent_info, " has a problem with rendering"), e)
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
		S = JulGame.pixels_per_world_unit(this.scene.camera)
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
	
				if ((pos.x + scale.x) < cameraPosition.x || pos.y < cameraPosition.y || pos.x > cameraPosition.x + cameraSize.x/S || (pos.y - scale.y) > cameraPosition.y + cameraSize.y/S)  && this.optimizeSpriteRendering 
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
				Ref(SDL2.SDL_FRect((pos.x + colOffset.x - cameraPosition.x) * S, 
				(pos.y + colOffset.y - cameraPosition.y) * S, 
				entity.transform.scale.x * colSize.x * S, 
				entity.transform.scale.y * colSize.y * S)))
				SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);
			end
		end
	end

	function JulGame.cleanup_sdl_resources()
		SDL2.SDL_ClearError()
		@debug "Closing window"
		if JulGame.Renderer != Ptr{SDL2.SDL_Renderer}(C_NULL) && JulGame.Renderer != C_NULL
			@debug "Destroying renderer: $(JulGame.Renderer)"
			SDL2.SDL_DestroyRenderer(JulGame.Renderer)
			if unsafe_string(SDL2.SDL_GetError()) != ""
				@error "Failed to destroy renderer, $(unsafe_string(SDL2.SDL_GetError()))"
			end
			JulGame.Renderer = C_NULL
		else
			@debug "Renderer is already destroyed"
			return
		end
		SDL2.SDL_ClearError()
		
		# Use the WindowManager to close the window
		if JulGame.main_loop().windowManager !== nothing
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

