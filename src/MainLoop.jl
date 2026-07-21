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

	include("profiling/profiling_functions.jl")

	export MainLoop, mark_input_layer_order_dirty!
	mutable struct MainLoop
		close::Bool
		coroutine_condition::Condition
		currentTestTime::Float64
		debugTextBoxes::Vector{UI.TextBoxModule.TextBox}
		errorLogger::ErrorLoggingModule.ErrorLogger
		input::Input
		isGameModeRunningInEditor::Bool
		latencyProfiler::Union{JulGame.LatencyProfilerModule.LatencyProfiler, Nothing}
		level::JulGame.SceneManagement.SceneBuilderModule.Scene
		optimizeSpriteRendering::Bool
		scene::SceneModule.Scene
		selectedEntities#::Union{Vector{Entity}, Vector{UI.UIElement}, Nothing}
		shouldChangeScene::Bool
		spriteLayers::NamedTuple{(:layers, :sorted), Tuple{Dict{Int, Vector{Any}}, Vector{Int}}}
		testLength::Float64
		testMode::Bool
		windowManager::WindowManager
		
		# Script tracking for profiling and debugging
		knownScriptTypes::Set{DataType}
		scriptTimings::Dict{DataType, Vector{Float64}}  # For profiling per script type
		
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
			this.latencyProfiler = nothing  # Disabled by default, enable with enable_profiling()

			this.windowManager = WindowManager()
			
			# Initialize cached input layer order
			this.cachedInputLayerOrder = Vector{Any}()
			sizehint!(this.cachedInputLayerOrder, 100)  # Pre-allocate
			this.inputLayerOrderDirty = true  # Build on first use
			this.scratchInputCanvases = Vector{Any}()
			sizehint!(this.scratchInputCanvases, 16)
			this.scratchInputHiddenCanvasChildIds = Set{UInt}()
			
			# Initialize script tracking
			this.knownScriptTypes = Set{DataType}()
			this.scriptTimings = Dict{DataType, Vector{Float64}}()

			return this
		end
	end

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
	# Uses Base.invokelatest to handle world age issues. Tracks first calls for profiling.
	# ============================================================================
	
	"""
		call_script_initialize(this::MainLoop, script)
	
	Call script initialization method. Tracks first call for profiling/debugging.
	"""
	@inline function call_script_initialize(this::MainLoop, script)
		script_type = typeof(script)
		
		if !(script_type in this.knownScriptTypes)
			# First time: JIT compiles the method (slow but only once)
			@debug "First initialize call for $(script_type) - compiling..."
			push!(this.knownScriptTypes, script_type)
			this.scriptTimings[script_type] = Float64[]
		end
		
		Base.invokelatest(JulGame.initialize, script)
	end
	
	"""
		call_script_update(this::MainLoop, script, deltaTime, profile::Bool=false)
	
	Call script update method with optional per-script profiling.
	When profiling is enabled, tracks execution time per script type.
	"""
	@inline function call_script_update(this::MainLoop, script, deltaTime::Float64, profile::Bool=false)
		script_type = typeof(script)
		
		if !(script_type in this.knownScriptTypes)
			# First call: register type (compilation happens here)
			@debug "First update call for $(script_type) - compiling..."
			push!(this.knownScriptTypes, script_type)
			this.scriptTimings[script_type] = Float64[]
		end
		
		# Profile if requested
		if profile && haskey(this.scriptTimings, script_type)
			start_time = time_ns()
			Base.invokelatest(JulGame.update, script, deltaTime)
			elapsed = (time_ns() - start_time) / 1e6
			if this.latencyProfiler !== nothing
				JulGame.LatencyProfilerModule.accumulate_script_update_ms!(this.latencyProfiler, script_type, elapsed)
			end
			v = this.scriptTimings[script_type]
			push!(v, elapsed)
			# Cap growth when profiling stays on for long sessions (avoids unbounded vectors / GC pressure).
			if length(v) > 25_000
				deleteat!(v, 1:10_000)
			end
		else
			Base.invokelatest(JulGame.update, script, deltaTime)
		end
	end
	
	"""
		call_script_shutdown(this::MainLoop, script)
	
	Call script shutdown/cleanup method.
	"""
	@inline function call_script_shutdown(this::MainLoop, script)
		script_type = typeof(script)
		
		if !(script_type in this.knownScriptTypes)
			push!(this.knownScriptTypes, script_type)
			@debug "First shutdown call for $(script_type) - compiling..."
		end
		
		# Always use invokelatest (fast after first compilation)
		Base.invokelatest(JulGame.on_shutdown, script)
	end
	
	
	"""
		print_script_profiling_report(this::MainLoop)
	
	Print profiling statistics for each script type showing mean, P95, P99, and max execution times.
	"""
	function print_script_profiling_report(this::MainLoop)
		if isempty(this.scriptTimings)
			println("No script profiling data available")
			return
		end
		
		println("\n" * "="^80)
		println("📊 SCRIPT PERFORMANCE REPORT")
		println("="^80)
		
		# Sort by mean time (slowest first)
		sorted_scripts = sort(collect(this.scriptTimings), by = kv -> isempty(kv[2]) ? 0.0 : Statistics.mean(kv[2]), rev=true)
		
		for (script_type, timings) in sorted_scripts
			if isempty(timings)
				continue
			end
			
			mean_time = mean(timings)
			p95 = quantile(timings, 0.95)
			p99 = quantile(timings, 0.99)
			max_time = maximum(timings)
			
			println("\n📜 $(script_type)")
			println("  ├─ Calls: $(length(timings))")
			println("  ├─ Mean:  $(round(mean_time, digits=3)) ms")
			println("  ├─ P95:   $(round(p95, digits=3)) ms")
			println("  ├─ P99:   $(round(p99, digits=3)) ms")
			println("  └─ Max:   $(round(max_time, digits=3)) ms")
		end
		
		println("\n" * "="^80)
	end
	
	"""
		clear_script_profiling_data!(this::MainLoop)
	
	Clear all script profiling data.
	"""
	function clear_script_profiling_data!(this::MainLoop)
		for (_, timings) in this.scriptTimings
			empty!(timings)
		end
	end
	
	export call_script_initialize, call_script_update, call_script_shutdown
	export print_script_profiling_report, clear_script_profiling_data!

    function prepare_window_scripts_and_start_loop(size)
        @debug "Preparing window"
		MAIN.windowManager.windowSize = size

		@debug "Initializing scripts and components"
        @time "scene init: total (scripts and components)" initialize_scripts_and_components()

        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
			@debug "Starting non editor loop"
            full_loop(MAIN)
            return
        end
    end

    function initialize_new_scene(this::MainLoop)
		@debug "Initializing new scene"
		@debug "Deserializing and building scene"
        @timev "Deserializing and building scene: $(this.level.scene)" SceneBuilderModule.deserialize_and_build_scene(this.level)

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
            isFirstFrame = true
            while !this.close
                try
                    if isFirstFrame
                        # First frame lazily bakes effect textures for visible
                        # elements and JIT-compiles the render path.
                        @time "first frame" game_loop(this, startTime, lastPhysicsTime)
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
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
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
		canvas = create_new_canvas(MAIN)
		return canvas
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
			@time "scene init: uiElements ($(length(this.scene.uiElements)))" for uiElement in this.scene.uiElements
				JulGame.initialize(uiElement)
			end
		end

		this.spriteLayers = build_sprite_layers()

		if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor

			for script in scripts
				try
					@time "scene init: script $(typeof(script))" call_script_initialize(this, script)
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

			@time "scene init: play-on-start sounds" for entity in MAIN.scene.entities
				@debug "Checking for a soundSource that needs to be activated"
				if entity.soundSource != C_NULL && entity.soundSource !== nothing && entity.soundSource.playOnStart && !entity.soundSource.isPlaying
					@debug("Playing $(entity.name)'s ($(entity.id)) sound source on start: $(entity.soundSource.path)")
					Component.toggle_sound(entity.soundSource)
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
		
		# Batch static sprites for performance
		if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor
			@debug "Batching static sprites"
			MAIN.scene.batchedLayers = JulGame.StaticSpriteBatcherModule.batch_static_sprites(MAIN.scene)
		end
		
		# Mark input layer order dirty after initialization
		mark_input_layer_order_dirty!(this)
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
		if uiElement.persistentBetweenScenes && (!JulGame.IS_EDITOR || this.isGameModeRunningInEditor)
			#println("Persistent uiElement: ", uiElement.name)
			push!(persistentUIElements, uiElement)
			skipcount += 1
			continue
		end
        JulGame.destroy(uiElement)
	end
	
	# Clean up batched static sprite textures
	@debug "Cleaning up batched sprite layers"
	JulGame.StaticSpriteBatcherModule.cleanup_batched_layers(this.scene.batchedLayers)
	
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
	
	for entity in MAIN.scene.entities
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
function JulGame.destroy_entity(this::MainLoop, entity)
	for i = eachindex(this.scene.entities)
		if this.scene.entities[i] == entity
			destroy_entity_components(this, entity)
			deleteat!(this.scene.entities, i)
			entity_index = findfirst(x -> x == entity, this.selectedEntities)
			if entity_index !== nothing
				deleteat!(this.selectedEntities, entity_index)
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
	JulGame.destroy(MAIN, entity)
end

function JulGame.destroy_entity(entity)
    JulGame.destroy_entity(MAIN, entity)
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

function destroy_entity_components(this::MainLoop, entity)
	entitySprite = entity.sprite
	if entitySprite != C_NULL
		layer = entitySprite.layer
		if haskey(this.spriteLayers.layers, layer)  # No string interpolation!
			for j = eachindex(this.spriteLayers.layers[layer])
				if this.spriteLayers.layers[layer][j] == entitySprite
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

	entityMesh3D = entity.mesh3d
	if entityMesh3D != C_NULL
		Component.destroy(entityMesh3D)
	end

	entitySoftwareRenderer3D = entity.softwareRenderer3d
	if entitySoftwareRenderer3D != C_NULL
		Component.destroy(entitySoftwareRenderer3D)
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
	JulGame.LatencyProfilerModule.accumulate_ui_render_breakdown_ms!(prof, key, (t1 - t0[]) / 1e6)
	t0[] = t1
	return
end

function game_loop(this::MainLoop, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), windowPos::Math.Vector2 = Math.Vector2(0,0), windowSize::Math.Vector2 = Math.Vector2(0,0))
	# Start frame profiling
	if this.latencyProfiler !== nothing
		JulGame.LatencyProfilerModule.start_frame(this.latencyProfiler)
	end

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
			end
			lastStartTime = startTime[]
			startTime[] = SDL2.SDL_GetPerformanceCounter()

			DEBUG = false
			#region Input
			if !JulGame.IS_EDITOR && !JulGame.IS_WEB
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :input_poll)
				end

				JulGame.InputModule.poll_input(this.input)

				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				end

				this.close = this.input.quit
				if this.close
					JulGame.engine_states.current_state = :quit
				end

				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :render_clear)
				end
				SDL2.SDL_RenderClear(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				end
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
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :physics)
				end
				
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
						Base.invokelatest(JulGame.update, rigidbody, deltaTime)
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
				
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				end
			end

		#region Rendering
		if this.latencyProfiler !== nothing
			JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :entity_updates)
		end
		
		currentRenderTime::UInt32 = SDL2.SDL_GetTicks()
		if this.scene.camera !== nothing && !JulGame.IS_EDITOR && !JulGame.IS_WEB
			JulGame.CameraModule.update(this.scene.camera)
		end
		
		# Check if static sprite batches need regeneration
		if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor
			JulGame.StaticSpriteBatcherModule.check_and_rebatch_if_needed(this.scene)
		end

			for entity in this.scene.entities
				if !entity.isActive
					continue
				end

				if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor
					try
						# Call scripts with optional per-script profiling
						for script in entity.scripts
							profile_scripts = this.latencyProfiler !== nothing
							call_script_update(this, script, deltaTime, profile_scripts)
						end
						if this.close && !this.isGameModeRunningInEditor
							@debug "Closing game"
							JulGame.engine_states.current_state = :quit
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
                        Base.invokelatest(JulGame.update, entityAnimator, currentRenderTime)
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
			
			if this.latencyProfiler !== nothing
				JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
			end
			
			if !JulGame.IS_EDITOR && !JulGame.IS_WEB
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :sprite_rendering)
				end
				
				render_scene_sprites_and_shapes(this, this.scene.camera)
				
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				end
			end
			
			if JulGame.IS_DEBUG
				render_scene_debug(this, cameraPosition, cameraSize)
			end

			#region UI
			if this.latencyProfiler !== nothing
				JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :ui_rendering)
			end
			
			# Sort UI elements by layer before rendering
			uiRenderingOrder = []
			prof_ui = this.latencyProfiler
			t_ui = Ref(time_ns())
			canvases = filter(x -> isa(x, JulGame.ICanvas), this.scene.uiElements)
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_filter_canvases)
			immediate_scene_skip = UI.ImmediateUIModule.immediate_ui_managed_scene_skip_ids()
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_immediate_skip_ids_build)
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
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_scene_elements_scan)
			render_functions_to_call = filter(x -> !x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
			filter!(x -> x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
			for render_function in render_functions_to_call
				push!(uiRenderingOrder, (render_function.layer, render_function))
			end
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_render_functions_push)
			immediateUIComponents = UI.ImmediateUIModule.manage_all_immediate_components()
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_immediate_manage_all)
			for immediateUIComponent in immediateUIComponents
				push!(uiRenderingOrder, (immediateUIComponent.layer, immediateUIComponent))
			end
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_immediate_append_order)

			sort!(uiRenderingOrder, by = x -> x[1])
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_sort_render_order)
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
					t_r = prof_ui === nothing ? UInt64(0) : time_ns()
					if tgt isa NamedTuple
						func = tgt.function_to_call
						Base.invokelatest(func)
					else
						JulGame.render(tgt)
					end
					if prof_ui !== nothing
						JulGame.LatencyProfilerModule.accumulate_ui_render_invoke_ms!(prof_ui, tgt, (time_ns() - t_r) / 1e6)
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
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_invoke_render_loop)
			
			if this.latencyProfiler !== nothing
				JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
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

			if !istaskdone(this.errorLogger.task)
				notify(this.errorLogger.condition)
				yield()
			end

			if !JulGame.IS_EDITOR
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :present_and_delay)
				end
				
				SDL2.SDL_RenderPresent(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
				SDL2.SDL_framerateDelay(this.windowManager.fpsManager)
				
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				end
			end
		catch e
			if this.testMode
				rethrow(e)
			else
				@error string(e)
				Base.show_backtrace(stdout, catch_backtrace())
			end
		end
		
		# End frame profiling
		if this.latencyProfiler !== nothing
			JulGame.LatencyProfilerModule.end_frame(this.latencyProfiler)
		end
    end

	function render_scene_sprites_and_shapes(this::MainLoop, camera::Camera)
		cameraPosition = camera !== nothing ? camera.position : Math.Vector2f(0,0)
		cameraSize = camera !== nothing ? camera.size : Math.Vector2(0,0)
		S = JulGame.pixels_per_world_unit(camera)
			
		skipcount = 0
		rendercount = 0
		renderOrder = []
		for entity in this.scene.entities
			spriteExists = entity.sprite != C_NULL && entity.sprite !== nothing
			shapeExists = entity.shape != C_NULL && entity.shape !== nothing
			mesh3dExists = entity.mesh3d != C_NULL && entity.mesh3d !== nothing
			softwareRenderer3dExists = entity.softwareRenderer3d != C_NULL && entity.softwareRenderer3d !== nothing
			if !entity.isActive || (!spriteExists && !shapeExists && !mesh3dExists && !softwareRenderer3dExists)
				continue
			end

			position = entity.transform.position
			size = entity.transform.scale
			sprite = entity.sprite
			shape = entity.shape
			mesh3d = entity.mesh3d
			softwareRenderer3d = entity.softwareRenderer3d

			skipSprite = false
			skipShape = false
			skipMesh3d = false
			skipSoftwareRenderer3d = false

			# TODO: consider offset
			if spriteExists && ((position.x + size.x) < cameraPosition.x || position.y < cameraPosition.y || position.x > cameraPosition.x + cameraSize.x/S || (position.y - size.y) > cameraPosition.y + cameraSize.y/S) && this.optimizeSpriteRendering 
				skipSprite = true
			end

			# TODO: consider offset
			if shapeExists && ((position.x + size.x) < cameraPosition.x || position.y < cameraPosition.y || position.x > cameraPosition.x + cameraSize.x/S || (position.y - size.y) > cameraPosition.y + cameraSize.y/S) && shape.isWorldEntity && this.optimizeSpriteRendering 
				skipShape = true
			end

			if !skipSprite && spriteExists
				# Skip static sprites in-game (they're rendered via batched textures)
				# BUT always render them in editor scene viewer for manipulation
				should_batch = sprite.isStatic && (!JulGame.IS_EDITOR || this.isGameModeRunningInEditor)
				if !should_batch
					push!(renderOrder, (sprite.layer, sprite))
				end
			end
			if !skipShape && shapeExists
				push!(renderOrder, (shape.layer, shape))
			end
			if !skipMesh3d && mesh3dExists
				push!(renderOrder, (mesh3d.layer, mesh3d))
			end
			if !skipSoftwareRenderer3d && softwareRenderer3dExists
				push!(renderOrder, (softwareRenderer3d.layer, softwareRenderer3d))
			end
			if skipSprite && spriteExists
				sprite.lastRenderedScreenPosition = nothing
				sprite.lastRenderedScreenSize = nothing
			end
		end

	render_functions_to_call = filter(x -> x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
	filter!(x -> !x.isWorldEntity, JulGame.RENDER_FUNCTIONS)
	for render_function in render_functions_to_call
		push!(renderOrder, (render_function.layer, render_function))
	end
	
	# Add batched static sprite layers to render order
	# Only render batched layers when NOT in editor scene viewer
	if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor
		for (layer, batched_layer) in this.scene.batchedLayers
			push!(renderOrder, (layer, batched_layer))
		end
	end
	
	sort!(renderOrder, by = x -> x[1])
		
		for i = eachindex(renderOrder)
			try
				rendercount += 1
			if renderOrder[i][2] isa Component.Mesh3DModule.Mesh3D
				Component.render(renderOrder[i][2], this)
			elseif renderOrder[i][2] isa Component.SoftwareRenderer3DModule.SoftwareRenderer3D
				Component.render(renderOrder[i][2], this)
			elseif renderOrder[i][2] isa Component.SpriteModule.InternalSprite || renderOrder[i][2] isa Component.ShapeModule.InternalShape 
				Component.draw(renderOrder[i][2], camera)
			elseif renderOrder[i][2] isa NamedTuple
				# get the params	
				func = renderOrder[i][2].function_to_call
				Base.invokelatest(func)
			elseif hasproperty(renderOrder[i][2], :textures) && hasproperty(renderOrder[i][2], :layer)
				# Render batched static sprite layer
				JulGame.StaticSpriteBatcherModule.render_batched_layer(renderOrder[i][2], camera)
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

