module MainLoopModule
	using JSON3
	using ..JulGame
	using ..JulGame.ErrorLoggingModule
	using ..JulGame: Camera, Component, Entity, Input, Math, UI, SceneModule, WindowManager
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
		for coroutine::JulGame.Coroutine in JulGame.Coroutines
			t = getfield(coroutine, :task)
			if t !== nothing && !istaskdone(t)
				try
					schedule(t, InterruptException(), error=true)
				catch e
					@debug "Error interrupting coroutine: $e"
				end
			end
		end
		empty!(JulGame.Coroutines)
	end

	@Base.noinline function _invoke_queued_render_fn_juliac(rf::JulGame.RenderQueuedFunction)::Nothing
		fn = getfield(rf, :function_to_call)::Function
		Base.invokelatest(fn)
		return nothing
	end

	@Base.noinline function _render_ui_target_juliac(@nospecialize(tgt))::Nothing
		if tgt isa JulGame.UI.TextBoxModule.TextBox
			JulGame.UI.render(tgt::JulGame.UI.TextBoxModule.TextBox)
		elseif tgt isa JulGame.UI.ScreenButtonModule.ScreenButton
			JulGame.UI.render(tgt::JulGame.UI.ScreenButtonModule.ScreenButton)
		elseif tgt isa JulGame.UI.RectangleModule.Rectangle
			JulGame.UI.render(tgt::JulGame.UI.RectangleModule.Rectangle)
		elseif tgt isa JulGame.UI.CircleModule.Circle
			JulGame.UI.render(tgt::JulGame.UI.CircleModule.Circle)
		elseif tgt isa JulGame.UI.CanvasModule.Canvas
			JulGame.UI.render(tgt::JulGame.UI.CanvasModule.Canvas)
		elseif tgt isa JulGame.UI.UIImageModule.UIImage
			JulGame.UI.render(tgt::JulGame.UI.UIImageModule.UIImage)
		elseif tgt isa JulGame.UI.ProgressBarModule.ProgressBar
			JulGame.UI.render(tgt::JulGame.UI.ProgressBarModule.ProgressBar)
		elseif tgt isa JulGame.UI.LineModule.Line
			JulGame.UI.render(tgt::JulGame.UI.LineModule.Line)
		else
			JulGame.render(tgt)
		end
		return nothing
	end

	export enable_profiling, disable_profiling, print_profiling_report, export_profiling_data
	export maybe_enable_latency_profiling_from_env!

	const _latency_env_session_started = Ref(false)
	const _latency_env_atexit_registered = Ref(false)

	"""
		enable_profiling(;buffer_size=10000, report_interval=5.0)

	Enable latency profiling for the game loop. This will track frame times,
	section times, allocations, and GC pauses.

	# Arguments
	- `buffer_size::Int`: Number of frames to buffer (default: 10000)
	- `report_interval::Float64`: Seconds between real-time reports (default: 5.0)

	# Example
	```julia
	enable_profiling(buffer_size=5000, report_interval=10.0)
	# Run your game...
	print_profiling_report()
	export_profiling_data("results.csv")
	```
	"""
	function enable_profiling(;buffer_size::Int=10000, report_interval::Float64=5.0)
		this = JulGame.current_main()
		this.latencyProfiler = JulGame.LatencyProfilerModule.LatencyProfiler(
			enabled=true,
			buffer_size=buffer_size,
			report_interval=report_interval
		)
		println("✅ Latency profiling enabled (buffer: $buffer_size frames, reports every $(report_interval)s)")
	end

	"""
		disable_profiling()

	Disable latency profiling and print final report.
	"""
	function disable_profiling()
		this = JulGame.current_main()
		if this.latencyProfiler !== nothing
			JulGame.LatencyProfilerModule.print_latency_report(this.latencyProfiler)
			this.latencyProfiler = nothing
			println("✅ Latency profiling disabled")
		end
	end

	"""
		print_profiling_report()

	Print a comprehensive latency profiling report including per-script performance.
	"""
	function print_profiling_report()
		this = JulGame.current_main()
		if this.latencyProfiler !== nothing
			JulGame.LatencyProfilerModule.print_latency_report(this.latencyProfiler)
			
			# Also print script-specific profiling if data is available
			if !isempty(this.scriptTimings)
				println("\n")  # Spacing
				print_script_profiling_report(this)
			end
		else
			@warn "Profiling is not enabled. Call enable_profiling() first."
		end
	end

	"""
		export_profiling_data(filename::String)

	Export profiling data to CSV file for external analysis.
	"""
	function export_profiling_data(filename::String)
		this = JulGame.current_main()
		if this.latencyProfiler !== nothing
			JulGame.LatencyProfilerModule.export_profiling_data(this.latencyProfiler, filename)
		else
			@warn "Profiling is not enabled. Call enable_profiling() first."
		end
	end

	"""
		maybe_enable_latency_profiling_from_env!()

	Start latency profiling once per process when `JULGAME_LATENCY_PROFILE` is set (`1`/`true`/`yes`/`on`).
	Optional `JULGAME_LATENCY_REPORT_SEC` sets the periodic report interval in seconds.

	Safe from any script module (e.g. title screen) whether loaded via the game package or editor
	`include` into `JulGame.ScriptModule`, where sibling Battler-only modules may not exist.
	"""
	function maybe_enable_latency_profiling_from_env!()
		v = strip(get(ENV, "JULGAME_LATENCY_PROFILE", ""))
		isempty(v) && return
		lowercase(v) in ("1", "true", "yes", "on") || return
		_latency_env_session_started[] && return
		interval = 5.0
		try
			vs = strip(get(ENV, "JULGAME_LATENCY_REPORT_SEC", ""))
			if !isempty(vs)
				interval = parse(Float64, vs)
			end
		catch
		end
		enable_profiling(; buffer_size=10_000, report_interval=max(0.5, interval))
		_latency_env_session_started[] = true
		@info "JulGame latency profiling (session): reports every $(max(0.5, interval))s; JulGame.print_profiling_report(); JulGame.export_profiling_data(\"latency.csv\")."
		if !_latency_env_atexit_registered[]
			atexit() do
				try
					if JulGame.MAIN !== nothing
						this = JulGame.current_main()
						if this.latencyProfiler !== nothing
							disable_profiling()
						end
					end
				catch
				end
			end
			_latency_env_atexit_registered[] = true
		end
		return
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
		
		uiRenderBuffer::Vector{Tuple{Int, Any}}
		# Pre-allocated buffers to reduce GC pressure
		spriteRenderBuffer::Vector{Tuple{Int, Any}}
		coroutineRemovalBuffer::Vector{Any}
		
		cachedInputLayerOrder::Vector{Union{Entity, UI.UIElement}}
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

			# Initialize pre-allocated buffers for rendering (reduces GC pressure)
			this.uiRenderBuffer = Vector{Tuple{Int, Any}}()
			sizehint!(this.uiRenderBuffer, 100)  # Pre-allocate for ~100 UI elements
			
			this.spriteRenderBuffer = Vector{Tuple{Int, Any}}()
			sizehint!(this.spriteRenderBuffer, 500)  # Pre-allocate for ~500 sprites
			
			this.coroutineRemovalBuffer = Vector{Any}()
			sizehint!(this.coroutineRemovalBuffer, 10)  # Pre-allocate for ~10 coroutines
			
			# Initialize cached input layer order
			this.cachedInputLayerOrder = Vector{Union{Entity, UI.UIElement}}()
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
		get_input_layer_order(this::MainLoop)
	
	Get the cached input layer order, rebuilding if dirty.
	This avoids sorting on every mouse event - only rebuilds when layers change.
	"""
	function get_input_layer_order(this::MainLoop)
		n_ent_with_sprite = 0
		for e in this.scene.entities
			if e.sprite !== nothing && e.sprite !== C_NULL
				n_ent_with_sprite += 1
			end
		end
		expected_len = length(this.scene.uiElements) + n_ent_with_sprite
		if this.inputLayerOrderDirty || length(this.cachedInputLayerOrder) != expected_len
			empty!(this.cachedInputLayerOrder)
			ui_sorted = sort(this.scene.uiElements, by = el -> el.layer, rev = true)
			for el in ui_sorted
				push!(this.cachedInputLayerOrder, el)
			end
			entitiesWithSprites = filter(e -> e.sprite !== nothing && e.sprite !== C_NULL, this.scene.entities)
			sort!(entitiesWithSprites, by = e -> e.sprite.layer, rev = true)
			for e in entitiesWithSprites
				push!(this.cachedInputLayerOrder, e)
			end
			this.inputLayerOrderDirty = false
		end
		return this.cachedInputLayerOrder
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
	
	@Base.noinline function _juliac_script_update_json(o::JSON3.Object, deltaTime::Float64)::Nothing
		JulGame.update(o, deltaTime)
		return nothing
	end
	
	@Base.noinline function _juliac_script_update_user(s::JulGame.Script, deltaTime::Float64)::Nothing
		JulGame.update(s, deltaTime)
		return nothing
	end

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
			if script isa JSON3.Object
				_juliac_script_update_json(script::JSON3.Object, deltaTime)
			else
				_juliac_script_update_user(script::JulGame.Script, deltaTime)
			end
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
			if script isa JSON3.Object
				_juliac_script_update_json(script::JSON3.Object, deltaTime)
			else
				_juliac_script_update_user(script::JulGame.Script, deltaTime)
			end
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
		main = JulGame.current_main()
		main.windowManager.windowSize = size
		
		@debug "Initializing scripts and components"
        initialize_scripts_and_components()

        if !JulGame.IS_EDITOR && !JulGame.IS_WEB
			@debug "Starting non editor loop"
            full_loop(main)
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
								@error "Error shutting down script: $(typeof(script))"
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
		canvas = create_new_canvas(JulGame.current_main())
		return canvas
	end

	function initialize_scripts_and_components()
		this = JulGame.current_main()
		scripts = Union{JulGame.Script, JSON3.Object}[]
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
					call_script_initialize(this, script)
				catch e
					if this.testMode
						rethrow(e)
					else
						@error string(e)
					end
				end
			end
			build_sprite_layers()

			for entity in this.scene.entities
				@debug "Checking for a soundSource that needs to be activated"
				if entity.soundSource != C_NULL && entity.soundSource !== nothing && entity.soundSource.playOnStart && !entity.soundSource.isPlaying
					@debug("Playing $(entity.name)'s ($(entity.id)) sound source on start: $(entity.soundSource.path)")
					Component.toggle_sound(entity.soundSource)
				end
			end 
		end
				
		this.scene.rigidbodies = []
		this.scene.colliders = JulGame.ColliderModule.InternalCollider[]
		for entity in this.scene.entities
			@debug "adding rigidbodies to global list"
			if entity.rigidbody != C_NULL
				push!(this.scene.rigidbodies, entity.rigidbody)
					end
			@debug "adding colliders to global list"
			if entity.collider != C_NULL
				push!(this.scene.colliders, entity.collider)
			end
		end 
		
		# Batch static sprites for performance
		if !JulGame.IS_EDITOR || this.isGameModeRunningInEditor
			@debug "Batching static sprites"
			this.scene.batchedLayers = JulGame.StaticSpriteBatcherModule.batch_static_sprites(this.scene)
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
	this = JulGame.current_main()
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
	persistentEntities = Entity[]
	entitiesToDestroy = Entity[]

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
							@error "Error shutting down script: $(typeof(script))"
							@error string(e)
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

	persistentUIElements = JulGame.IUIElement[]
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
	
	for entity in JulGame.current_main().scene.entities
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
	JulGame.destroy(JulGame.current_main(), entity)
end

function JulGame.destroy_entity(entity)
    JulGame.destroy_entity(JulGame.current_main(), entity)
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
	this = JulGame.current_main()
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
	game_loop(this, startTime, lastPhysicsTime, windowPos, windowSize)

Runs the game loop.

Parameters:
- `this`: The main struct.
- `startTime`: Start time counter ref (`SDL_GetPerformanceCounter`).
- `lastPhysicsTime`: Last physics tick ref (`SDL_GetTicks`).
- `windowPos` / `windowSize`: Window position and size in pixels (`_Vector2{Int32}`).
"""
@inline function _accum_ui_render_breakdown_ms!(prof, t0::Ref{UInt64}, key::Symbol)
	prof === nothing && return
	t1 = time_ns()
	JulGame.LatencyProfilerModule.accumulate_ui_render_breakdown_ms!(prof, key, (t1 - t0[]) / 1e6)
	t0[] = t1
	return
end

function game_loop(this::MainLoop, startTime::Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime::Ref{UInt64} = Ref(UInt64(0)), windowPos::JulGame.Math._Vector2{Int32} = JulGame.Math._Vector2{Int32}(0, 0), windowSize::JulGame.Math._Vector2{Int32} = JulGame.Math._Vector2{Int32}(0, 0))
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
			cam = this.scene.camera
			local cameraPosition::JulGame.Math._Vector2{Float64}
			local cameraSize::JulGame.Math._Vector2{Int32}
			if cam === nothing
				cameraPosition = JulGame.Math._Vector2{Float64}(0.0, 0.0)
				cameraSize = JulGame.Math._Vector2{Int32}(0, 0)
			else
				p = getfield(cam, :position)::JulGame.Math._Vector3{Float64}
				o = getfield(cam, :offset)::JulGame.Math._Vector2{Float64}
				cameraPosition = JulGame.Math._Vector2{Float64}(p.x + o.x, p.y + o.y)
				cameraSize = getfield(cam, :size)::JulGame.Math._Vector2{Int32}
			end

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
						rb_i = rigidbody::JulGame.RigidbodyModule.InternalRigidbody
						Component.update(rb_i, deltaTime)
					catch e
						if this.testMode
							rethrow(e)
						else
							par = getfield(rigidbody, :parent)
							if par isa Entity
								@error "$(getfield(par, :name)) with id: $(getfield(par, :id)) has a problem with it's rigidbody"
							else
								@error "Rigidbody has a problem (parent not Entity)"
							end
							@error string(e)
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
		
		currentRenderTime = SDL2.SDL_GetTicks()
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
							@error "$(entity.name) with id: $(entity.id) has a problem with it's update"
							@error string(e)
						end
					end
					entityAnimator = entity.animator
					if entityAnimator isa JulGame.AnimatorModule.InternalAnimator
						an = entityAnimator::JulGame.AnimatorModule.InternalAnimator
						Component.update(an, currentRenderTime, deltaTime)
					end
				end
			end

			coroutines_to_remove = JulGame.Coroutine[]
			for coroutine::JulGame.Coroutine in JulGame.Coroutines
				t = getfield(coroutine, :task)
				if t === nothing || istaskdone(t)
					push!(coroutines_to_remove, coroutine)
					continue
				end
				cnd = getfield(coroutine, :condition)
				if cnd isa Base.Condition
					notify(cnd)
				end
				yield()
			end
			coroutine_vec = JulGame.Coroutines
			for coroutine_to_remove in coroutines_to_remove
				@debug("coroutine done, removing")
				n_cv = length(coroutine_vec)
				@inbounds for j in n_cv:-1:1
					if coroutine_vec[j] === coroutine_to_remove
						deleteat!(coroutine_vec, j)
						break
					end
				end
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
			
			# Sort UI elements by layer before rendering (typed + insertion sort for JuliaC `--trim`)
			uiRenderingOrder = Tuple{Int, Any}[]
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
					push!(uiRenderingOrder, (UI.input_ui_layer(uiElement), uiElement))
				#end
			end
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_scene_elements_scan)
			render_functions_to_call = JulGame.RenderQueuedFunction[]
			rf_ui = JulGame.RENDER_FUNCTIONS
			i_rf = 1
			while i_rf <= length(rf_ui)
				if !rf_ui[i_rf].isWorldEntity
					push!(render_functions_to_call, rf_ui[i_rf])
					deleteat!(rf_ui, i_rf)
				else
					i_rf += 1
				end
			end
			for render_function in render_functions_to_call
				push!(uiRenderingOrder, (render_function.layer, render_function))
			end
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_render_functions_push)
			immediateUIComponents = UI.ImmediateUIModule.manage_all_immediate_components()
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_immediate_manage_all)
			for immediateUIComponent in immediateUIComponents
				push!(uiRenderingOrder, (UI.input_ui_layer(immediateUIComponent), immediateUIComponent))
			end
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_immediate_append_order)

			n_ur = length(uiRenderingOrder)
			@inbounds for si in 2:n_ur
				cur_u = uiRenderingOrder[si]
				cl_u = cur_u[1]
				ju = si
				while ju > 1 && uiRenderingOrder[ju - 1][1] > cl_u
					uiRenderingOrder[ju] = uiRenderingOrder[ju - 1]
					ju -= 1
				end
				uiRenderingOrder[ju] = cur_u
			end
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_sort_render_order)
			for i = eachindex(uiRenderingOrder)
				try
					skipCanvasChild = false
					elem = uiRenderingOrder[i][2]
					for cv in canvases
						if cv isa JulGame.UI.CanvasModule.Canvas && !getfield(cv, :isActive)
							children = getfield(cv, :children)::Vector{JulGame.IUIElement}
							for child in children
								if child === elem
									skipCanvasChild = true
									break
								end
							end
						end
						skipCanvasChild && break
					end
					if skipCanvasChild
						continue
					end
					tgt = elem
					t_r = prof_ui === nothing ? UInt64(0) : time_ns()
					if tgt isa JulGame.RenderQueuedFunction
						_invoke_queued_render_fn_juliac(tgt::JulGame.RenderQueuedFunction)
					else
						_render_ui_target_juliac(tgt)
					end
					if prof_ui !== nothing
						rk = (tgt isa JulGame.RenderQueuedFunction || tgt isa NamedTuple) ? :ui_queued_render_fn : :ui_render_element
						JulGame.LatencyProfilerModule.accumulate_ui_render_invoke_ms!(prof_ui, rk, (time_ns() - t_r) / 1e6)
					end
				catch e
					if this.testMode
						rethrow(e)
					elseif JulGame.IS_PACKAGE_COMPILED
						@error "UI render failed"
						@error string(e)
					else
						parent_info = ""
						if uiRenderingOrder[i][2] isa JulGame.RenderQueuedFunction
							parent_info = "a queued render function"
						elseif isa(uiRenderingOrder[i][2], UI.UIElement) 
							parent_info = "a ui element of type $(typeof(uiRenderingOrder[i][2]))"
						end
						@error "$(parent_info) has a problem with its render function"
						@error string(e)
					end
				end
			end
			_accum_ui_render_breakdown_ms!(prof_ui, t_ui, :ui_invoke_render_loop)
			
			if this.latencyProfiler !== nothing
				JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
			end
			
			S_mouse = JulGame.pixels_per_world_unit(this.scene.camera)
			mp = getfield(this.input, :mousePosition)::JulGame.Math._Vector2{Int32}
			cpx = getfield(cameraPosition, :x)::Float64
			cpy = getfield(cameraPosition, :y)::Float64
			mpx = getfield(mp, :x)::Int32
			mpy = getfield(mp, :y)::Int32
			this.input.mousePositionWorld = JulGame.Math._Vector2{Float64}(
				(Float64(mpx) + (cpx * S_mouse)) / S_mouse,
				(Float64(mpy) + (cpy * S_mouse)) / S_mouse,
			)
			wpx = getfield(windowPos, :x)::Int32
			wpy = getfield(windowPos, :y)::Int32
			rawMousePos = JulGame.Math._Vector2{Float64}(Float64(mpx - wpx), Float64(mpy - wpy))
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
				 		textBox = UI.TextBoxModule.TextBox(statTexts[i]; fontSize = 24, position = JulGame.Math._Vector2{Int32}(0, Int32(35 * i)))
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
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :present_and_delay)
				end
				
				SDL2.SDL_RenderPresent(JulGame.Renderer::Ptr{SDL2.SDL_Renderer})
				JulGame.WindowManagerModule._sdl_gfx_framerate_delay!(this.windowManager.fpsManagerPtr)
				
				if this.latencyProfiler !== nothing
					JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				end
			elseif JulGame.IS_WEB
				JulGame.WindowManagerModule._sdl_gfx_framerate_delay!(this.windowManager.fpsManagerPtr)
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
			end
		end
		
		# End frame profiling
		if this.latencyProfiler !== nothing
			JulGame.LatencyProfilerModule.end_frame(this.latencyProfiler)
		end
    end

	function render_scene_sprites_and_shapes(this::MainLoop, camera::Union{Nothing, Camera})
		local cameraPosition::JulGame.Math._Vector2{Float64}
		local cameraSize::JulGame.Math._Vector2{Int32}
		if camera === nothing
			cameraPosition = JulGame.Math._Vector2{Float64}(0.0, 0.0)
			cameraSize = JulGame.Math._Vector2{Int32}(0, 0)
		else
			p = getfield(camera, :position)::JulGame.Math._Vector3{Float64}
			cameraPosition = JulGame.Math._Vector2{Float64}(p.x, p.y)
			cameraSize = getfield(camera, :size)::JulGame.Math._Vector2{Int32}
		end
		S = JulGame.pixels_per_world_unit(camera)
			
		skipcount = 0
		rendercount = 0
		renderOrder = Tuple{Int, Any}[]
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

	render_functions_to_call = JulGame.RenderQueuedFunction[]
	rf_world = JulGame.RENDER_FUNCTIONS
	i_rw = 1
	while i_rw <= length(rf_world)
		if rf_world[i_rw].isWorldEntity
			push!(render_functions_to_call, rf_world[i_rw])
			deleteat!(rf_world, i_rw)
		else
			i_rw += 1
		end
	end
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
	
	# Stable insertion sort by layer (index 1); avoids Base.sort! for JuliaC --trim.
	nro = length(renderOrder)
	@inbounds for i in 2:nro
		cur = renderOrder[i]
		cl = cur[1]
		j = i
		while j > 1 && renderOrder[j - 1][1] > cl
			renderOrder[j] = renderOrder[j - 1]
			j -= 1
		end
		renderOrder[j] = cur
	end
		
		for i = eachindex(renderOrder)
			try
				rendercount += 1
			if renderOrder[i][2] isa Component.Mesh3DModule.Mesh3D
				Component.render(renderOrder[i][2], this)
			elseif renderOrder[i][2] isa Component.SoftwareRenderer3DModule.SoftwareRenderer3D
				Component.render(renderOrder[i][2], this)
			elseif renderOrder[i][2] isa Component.SpriteModule.InternalSprite || renderOrder[i][2] isa Component.ShapeModule.InternalShape 
				Component.draw(renderOrder[i][2], camera)
			elseif renderOrder[i][2] isa JulGame.RenderQueuedFunction
				rf = renderOrder[i][2]::JulGame.RenderQueuedFunction
				_invoke_queued_render_fn_juliac(rf)
			elseif renderOrder[i][2] isa JulGame.StaticSpriteBatcherModule.BatchedLayer
				JulGame.StaticSpriteBatcherModule.render_batched_layer(renderOrder[i][2]::JulGame.StaticSpriteBatcherModule.BatchedLayer, camera)
			else
				@debug "Unknown item type: $(typeof(renderOrder[i][2]))"
			end
			catch e
				if this.testMode
					rethrow(e)
				elseif JulGame.IS_PACKAGE_COMPILED
					@error "render failed for scene object"
					@error string(e)
				else
					parent_info = ""
					if renderOrder[i][2] isa JulGame.RenderQueuedFunction
						parent_info = "a queued render function"
					elseif renderOrder[i][2] isa Component.SpriteModule.InternalSprite || renderOrder[i][2] isa Component.ShapeModule.InternalShape
						p = getfield(renderOrder[i][2], :parent)::JulGame.IEntity
						if p isa Entity
							ent = p::Entity
							parent_info = "$(getfield(ent, :name)) with id: $(getfield(ent, :id))"
						else
							parent_info = "a component of type $(typeof(renderOrder[i][2]))"
						end
					else 
						parent_info = "a component of type $(typeof(renderOrder[i][2]))"
					end
					@error "$(parent_info) has a problem with rendering"
					@error string(e)
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
				px = getfield(pos, :x)::Float64
				py = getfield(pos, :y)::Float64
				sx = getfield(scale, :x)::Float64
				sy = getfield(scale, :y)::Float64
				camx = getfield(cameraPosition, :x)::Float64
				camy = getfield(cameraPosition, :y)::Float64
				cs_x = getfield(cameraSize, :x)::Int32
				cs_y = getfield(cameraSize, :y)::Int32
	
				if ((px + sx) < camx || py < camy || px > camx + cs_x/S || (py - sy) > camy + cs_y/S)  && this.optimizeSpriteRendering 
					colliderSkipCount += 1
					continue
				end
				colliderRenderCount += 1
				collider = entity.collider
	
				colSize = getfield(collider, :size)::JulGame.Math._Vector2{Float64}
				colOffset = getfield(collider, :offset)::JulGame.Math._Vector2{Float64}
				csizex = getfield(colSize, :x)::Float64
				csizey = getfield(colSize, :y)::Float64
				coffx = getfield(colOffset, :x)::Float64
				coffy = getfield(colOffset, :y)::Float64
						
				SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 
				Ref(SDL2.SDL_FRect((px + coffx - camx) * S, 
				(py + coffy - camy) * S, 
				sx * csizex * S, 
				sy * csizey * S)))
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
		if JulGame.MAIN !== nothing
			main = JulGame.current_main()
			if main.windowManager !== nothing
				JulGame.WindowManagerModule.close_window()
			end
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

