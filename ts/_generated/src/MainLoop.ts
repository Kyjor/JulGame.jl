export {}

	// using ..JulGame
	// using ..(globalThis as any).JulGame.ErrorLoggingModule
	// using ..JulGame: Camera, Component, Input, Math, UI, SceneModule, WindowManager
    // import ..JulGame: Component
    // import ..(globalThis as any).JulGame.SceneManagement: SceneBuilderModule
	// import ..JulGame
	// using Statistics

	include("utils/Enums.jl")
	include("utils/Constants.jl")

	/*
		cleanup_coroutines()

	Cleans up all active coroutines by attempting to gracefully terminate them and then clearing the coroutines array.
	This function should be called when changing scenes, exiting the game, or stopping the game in editor mode.
	*/
	function cleanup_coroutines() {
		console.debug("Cleaning up coroutines")
		for (const coroutine of (globalThis as any).JulGame.Coroutines) {
			if (!istaskdone(coroutine.task)) {
				try {
					schedule(coroutine.task, InterruptException(), error=true)
				} catch (e) {
					console.debug("Error interrupting coroutine: $e")
				}
			}
		}
		empty((globalThis as any).JulGame.Coroutines)
	}

	include("profiling/profiling_functions.jl")

	
	class MainLoop {
		close: boolean
		coroutine_condition: Condition
		currentTestTime: number
		debugTextBoxes: TextBox[]
		errorLogger: ErrorLogger
		input: Input
		isGameModeRunningInEditor: boolean
		latencyProfiler: LatencyProfiler | null
		level: Scene
		optimizeSpriteRendering: boolean
		scene: Scene
		selectedEntities//: Entity[] | UIElement[] | null
		shouldChangeScene: boolean
		spriteLayers: NamedTuple{(:layers, :sorted), Tuple{Dict{Int, Vector{Any}}, Vector{Int}}}
		testLength: number
		testMode: boolean
		windowManager: WindowManager
		
		// Script tracking for profiling and debugging
		knownScriptTypes: Set{DataType}
		scriptTimings: Dict{DataType, Vector{Float64}}  // For profiling per script type
		
		cachedInputLayerOrder: any[]
		// Cached input layer order (rebuilt only when layers change)
		inputLayerOrderDirty: boolean
		// Scratch buffers for input hit-testing (avoid per-event allocations)
		scratchInputCanvases: any[]
		scratchInputHiddenCanvasChildIds: Set{UInt}

		constructor() {
			this = new()

			console.debug("Initializing SDL")
			if ((globalThis as any).JulGameSdl.glue_SDL_Init(SDL2.SDL_INIT_EVERYTHING) != 0) {
				console.error("Failed to initialize SDL, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
			}
			if (SDL2.TTF_Init() != 0) {
				console.error("Failed to initialize TTF, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
			}
			if (SDL2.Mix_OpenAudio(22050, SDL2.MIX_DEFAULT_FORMAT, 2, 1024) != 0) {
				console.error("Failed to open audio, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
			}
			(globalThis as any).JulGameSdl.glue_SDL_ClearError()

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
			this.latencyProfiler = null  // Disabled by default, enable with enable_profiling()

			this.windowManager = WindowManager()
			
			// Initialize cached input layer order
			this.cachedInputLayerOrder = Vector{Any}()
			sizehint(this.cachedInputLayerOrder, 100)  // Pre-allocate
			this.inputLayerOrderDirty = true  // Build on first use
			this.scratchInputCanvases = Vector{Any}()
			sizehint(this.scratchInputCanvases, 16)
			this.scratchInputHiddenCanvasChildIds = Set{UInt}()
			
			// Initialize script tracking
			this.knownScriptTypes = Set{DataType}()
			this.scriptTimings = Dict{DataType, Vector{Float64}}()

		}
	}

	/*
		mark_input_layer_order_dirty(this)
	
	Mark the input layer order cache as dirty, forcing a rebuild on next access.
	Call this when adding/removing UI elements or entities, or when changing layers.
	*/
	function mark_input_layer_order_dirty(this: MainLoop) {
		this.inputLayerOrderDirty = true
	}
	
	// ============================================================================
	// SCRIPT LIFECYCLE CALLS
	// Wrapper functions for calling dynamically-loaded script methods.
	// Uses Base.invokelatest to handle world age issues. Tracks first calls for profiling.
	// ============================================================================
	
	/*
		call_script_initialize(this, script)
	
	Call script initialization method. Tracks first call for profiling/debugging.
	*/
	function call_script_initialize(this, script) {
		let script_type = typeof(script)
		
		if ((script_type in this.knownScriptTypes)) {
			// First time: JIT compiles the method (slow but only once)
			console.debug("First initialize call for $(script_type) - compiling...")
			this.knownScriptTypes.push(script_type)
			this.scriptTimings[script_type] = Float64[]
		}
		
		Base.invokelatest((globalThis as any).JulGame.initialize, script)
	}
	
	/*
		call_script_update(this, script, deltaTime, profile: boolean=false)
	
	Call script update method with optional per-script profiling.
	When profiling is enabled, tracks execution time per script type.
	*/
	function call_script_update(this, script, deltaTime: number, profile: boolean=false) {
		script_type = typeof(script)
		
		if ((script_type in this.knownScriptTypes)) {
			// First call: register type (compilation happens here)
			console.debug("First update call for $(script_type) - compiling...")
			this.knownScriptTypes.push(script_type)
			this.scriptTimings[script_type] = Float64[]
		}
		
		// Profile if requested
		if (profile && haskey(this.scriptTimings, script_type)) {
			let start_time = time_ns()
			Base.invokelatest((globalThis as any).JulGame.update, script, deltaTime)
			let elapsed = (time_ns() - start_time) / 1e6
			if (this.latencyProfiler !== null) {
				(globalThis as any).JulGame.LatencyProfilerModule.accumulate_script_update_ms(this.latencyProfiler, script_type, elapsed)
			}
			let v = this.scriptTimings[script_type]
			v.push(elapsed)
			// Cap growth when profiling stays on for long sessions (avoids unbounded vectors / GC pressure).
			if (v.length > 25_000) {
				deleteat(v, 1:10_000)
			}
		else
			Base.invokelatest((globalThis as any).JulGame.update, script, deltaTime)
		}
	}
	
	/*
		call_script_shutdown(this, script)
	
	Call script shutdown/cleanup method.
	*/
	function call_script_shutdown(this, script) {
		script_type = typeof(script)
		
		if ((script_type in this.knownScriptTypes)) {
			this.knownScriptTypes.push(script_type)
			console.debug("First shutdown call for $(script_type) - compiling...")
		}
		
		// Always use invokelatest (fast after first compilation)
		Base.invokelatest((globalThis as any).JulGame.on_shutdown, script)
	}
	
	
	/*
		print_script_profiling_report(this)
	
	Print profiling statistics for each script type showing mean, P95, P99, and max execution times.
	*/
	function print_script_profiling_report(this: MainLoop) {
		if (isempty(this.scriptTimings)) {
			console.log("No script profiling data available")
			return
		}
		
		console.log("\n" * "="^80)
		console.log("📊 SCRIPT PERFORMANCE REPORT")
		console.log("="^80)
		
		// Sort by mean time (slowest first)
		let sorted_scripts = sort(collect(this.scriptTimings), by = kv -> isempty(kv[1]) ? 0.0 : Statistics.mean(kv[1]), rev=true)
		
		for (script_type, timings) in sorted_scripts
			if (isempty(timings)) {
				continue
			}
			
			let mean_time = mean(timings)
			let p95 = quantile(timings, 0.95)
			let p99 = quantile(timings, 0.99)
			let max_time = maximum(timings)
			
			console.log("\n📜 $(script_type)")
			console.log("  ├─ Calls: $(timings.length)")
			console.log("  ├─ Mean:  $(round(mean_time, digits=3)) ms")
			console.log("  ├─ P95:   $(round(p95, digits=3)) ms")
			console.log("  ├─ P99:   $(round(p99, digits=3)) ms")
			console.log("  └─ Max:   $(round(max_time, digits=3)) ms")
		}
		
		console.log("\n" * "="^80)
	}
	
	/*
		clear_script_profiling_data(this)
	
	Clear all script profiling data.
	*/
	function clear_script_profiling_data(this: MainLoop) {
		for (_, timings) in this.scriptTimings
			empty(timings)
		}
	}
	
	
	

    function prepare_window_scripts_and_start_loop(size) {
        console.debug("Preparing window")
		MAIN.windowManager.windowSize = size
		
		console.debug("Initializing scripts and components")
        initialize_scripts_and_components()

        if ((globalThis as any).JulGame.IS_EDITOR && (globalThis as any).JulGame.IS_WEB) {
			console.debug("Starting non editor loop")
            full_loop(MAIN)
            return
        }
    }

    function initialize_new_scene(this: MainLoop) {
		console.debug("Initializing new scene")
		console.debug("Deserializing and building scene")
        SceneBuilderModule.deserialize_and_build_scene(this.level)

        initialize_scripts_and_components()
        
        if ((globalThis as any).JulGame.IS_EDITOR) {
			console.debug("Starting non editor loop")
            full_loop(this)
            return
        }
    }

    function reset_camera_position(this: MainLoop) {
		console.debug("Resetting camera position")
		if (this.scene.camera === null return }) {

        let cameraPosition = {x: 0.0, y: 0.0, z: 0.0}
        (globalThis as any).JulGame.CameraModule.update(this.scene.camera, cameraPosition)
    }
	
    function full_loop(this: MainLoop) {
        try {
			this.close = false
            let startTime = Ref(UInt64(0))
            let lastPhysicsTime = Ref(UInt64((globalThis as any).JulGameSdl.glue_SDL_GetTicks()))
            while !this.close
                try {
                    game_loop(this, startTime, lastPhysicsTime)
                } catch (e) {
                    if (this.testMode) {
                        throw(e)
                    else
						if (this.testMode) {
							rethrow(e)
						else
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
						}
                    }
                }
                if (this.testMode && this.currentTestTime >= this.testLength) {
					console.info("Test mode complete")
                    break
                }
            }
        finally
            for (const entity of this.scene.entities) {
                for (const script of entity.scripts) {
                    try {
                        call_script_shutdown(this, script)
                    } catch (e) {
						if (this.testMode) {
							rethrow(e)
						else
							if (typeof(e) != ErrorException) {
								console.log("Error shutting down script: $(typeof(script))")
								Base.show_backtrace(stdout, catch_backtrace())
							}
						}
                    }
                }
            }
			
            // Clean up all coroutines when game exits
            console.debug("Cleaning up coroutines during game exit")
            cleanup_coroutines()
			
            if (!this.shouldChangeScene) {
                // Clean up all immediate UI components on game shutdown
                (globalThis as any).JulGame.UI.ImmediateUIModule.cleanup_all_immediate_components()
				console.debug("Cleaning up immediate UI components")
				(globalThis as any).JulGame.cleanup_sdl_resources()
				return
            else
				console.debug("Changing scene")
                this.shouldChangeScene = false
                initialize_new_scene(this)
            }
        }
    }

    function create_new_entity(this: MainLoop) {
		console.debug("Creating new entity")
        SceneBuilderModule.create_new_entity(this.level)
    }

    function create_new_text_box(this: MainLoop) {
		console.debug("Creating new text box")
        SceneBuilderModule.create_new_text_box(this.level)
    }

	function create_new_screen_button(this: MainLoop) {
		console.debug("Creating new screen button")
		SceneBuilderModule.create_new_screen_button(this.level)
	}

	function create_new_image(this: MainLoop) {
		console.debug("Creating new image")
		SceneBuilderModule.create_new_image(this.level)
	}

	function create_new_rectangle(this: MainLoop) {
		console.debug("Creating new rectangle")
		SceneBuilderModule.create_new_rectangle(this.level)
	}

	function create_new_canvas(this: MainLoop) {
		console.debug("Creating new canvas")
		let canvas = SceneBuilderModule.create_new_canvas(this.level)
		return canvas
	}

	function create_new_canvas() {
		canvas = create_new_canvas(MAIN)
		return canvas
	}

	function initialize_scripts_and_components() {
		this = MAIN
		let scripts = []
		for (const entity of this.scene.entities) {
			for (const script of entity.scripts) {
				scripts.push(script)
			}
		}

		if (!this.isGameModeRunningInEditor) {
			for (const uiElement of this.scene.uiElements) {
				(globalThis as any).JulGame.initialize(uiElement)
			}
		}

		this.spriteLayers = build_sprite_layers()
		
		if ((globalThis as any).JulGame.IS_EDITOR || this.isGameModeRunningInEditor) {

			for (const script of scripts) {
				try {
					call_script_initialize(this, script)
				} catch (e) {
					if (this.testMode) {
						rethrow(e)
					else
						@error string(e)
						Base.show_backtrace(stdout, catch_backtrace())
					}
				}
			}
			build_sprite_layers()

			for (const entity of MAIN.scene.entities) {
				console.debug("Checking for a soundSource that needs to be activated")
				if (entity.soundSource != null && entity.soundSource !== null && entity.soundSource.playOnStart && !entity.soundSource.isPlaying) {
					console.debug("Playing $(entity.name)'s ($(entity.id)) sound source on start: $(entity.soundSource.path)")
					Component_toggle_sound(entity.soundSource)
				}
			} 
		}
				
		MAIN.scene.rigidbodies = []
		MAIN.scene.colliders = []
		for (const entity of MAIN.scene.entities) {
			console.debug("adding rigidbodies to global list")
			if (entity.rigidbody != null) {
				MAIN.scene.rigidbodies.push(entity.rigidbody)
					}
			console.debug("adding colliders to global list")
			if (entity.collider != null) {
				MAIN.scene.colliders.push(entity.collider)
			}
		} 
		
		// Batch static sprites for performance
		if ((globalThis as any).JulGame.IS_EDITOR || this.isGameModeRunningInEditor) {
			console.debug("Batching static sprites")
			MAIN.scene.batchedLayers = (globalThis as any).JulGame.StaticSpriteBatcherModule.batch_static_sprites(MAIN.scene)
		}
		
		// Mark input layer order dirty after initialization
		mark_input_layer_order_dirty(this)
	}


/*
	change_scene(sceneFileName: string)

Change the scene to the specified `sceneFileName`. This function destroys the current scene, including all entities, textboxes, and screen buttons, except for the ones marked as persistent. It then loads the new scene and sets the camera and persistent entities, textboxes, and screen buttons.

// Arguments
- `sceneFileName: string`: The name of the scene file to load.
*/
function JulGame_change_scene(sceneFileName: string) {
	(globalThis as any).JulGame.IS_CHANGING_SCENE = true
	this = MAIN
	console.debug("Changing scene to: $(sceneFileName)")
	this.close = true
	this.shouldChangeScene = true
	
	// Clean up all immediate UI components
	(globalThis as any).JulGame.UI.ImmediateUIModule.cleanup_all_immediate_components()
	
	// Clean up all coroutines
	console.debug("Cleaning up coroutines during scene change")
	cleanup_coroutines()
	
	//destroy current scene 
	console.debug("Entity count before destroying: $(this.scene.entities.length)") 
	let count = 0
	let skipcount = 0
	let persistentEntities = []	
	let entitiesToDestroy = []

	for (const entity of this.scene.entities) {
		if (entity.persistentBetweenScenes && ((globalThis as any).JulGame.IS_EDITOR || this.isGameModeRunningInEditor)) {
			console.debug("Persistent entity: ", entity.name, " with id: ", entity.id)
			persistentEntities.push(entity)
			skipcount += 1
			continue
		}

		destroy_entity_components(this, entity)
		if ((globalThis as any).JulGame.IS_EDITOR) {
			for (const script of entity.scripts) {
				try {
					call_script_shutdown(this, script)
				} catch (e) {
					if (this.testMode) {
						rethrow(e)
					else
						if (typeof(e) != ErrorException) {
							console.log("Error shutting down script: $(typeof(script))")
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
						}
					}
				}
			}
		}

		entitiesToDestroy.push(entity)
		count += 1
	}

	for (const entity of entitiesToDestroy) {
		(globalThis as any).JulGame.destroy_entity(this, entity)
	}
	console.debug("Destroyed $count entities while changing scenes")
	console.debug("Skipped $skipcount entities while changing scenes")

	console.debug("Entities left after destroying while changing scenes (persistent): $(persistentEntities.length) ")

	let persistentUIElements = []
	// delete all UIElements
	for (const uiElement of this.scene.uiElements) {
		if (uiElement.persistentBetweenScenes) {
			//console.log("Persistent uiElement: ", uiElement.name)
			persistentUIElements.push(uiElement)
			skipcount += 1
			continue
		}
        (globalThis as any).JulGame.destroy(uiElement)
	}
	
	// Clean up batched static sprite textures
	console.debug("Cleaning up batched sprite layers")
	(globalThis as any).JulGame.StaticSpriteBatcherModule.cleanup_batched_layers(this.scene.batchedLayers)
	
	//load new scene 
	let camera = this.scene.camera
	this.scene = SceneModule.Scene()
	this.scene.name = split(sceneFileName, ".")[1]
	this.scene.entities = persistentEntities
	this.scene.uiElements = persistentUIElements
	this.scene.camera = camera
	this.level.scene = sceneFileName
	
	if ((globalThis as any).JulGame.IS_EDITOR) {
		initialize_new_scene(this)
	}
	(globalThis as any).JulGame.IS_CHANGING_SCENE = false
}

/*
build_sprite_layers()

Builds the sprite layers for the main game.
Returns a named tuple with (layers = Dict{Int, Vector}, sorted = Vector{Int})

*/
function build_sprite_layers() {
	console.debug("Building sprite layers")
	let layerDict = Dict{Int, Vector{Any}}()  // Int keys instead of String - no allocations!
	let sortedLayers = Int[]
	
	for (const entity of MAIN.scene.entities) {
		let entitySprite = entity.sprite
		if (entitySprite != null) {
			let layer = entitySprite.layer
			if (!haskey(layerDict, layer)  // No string interpolation!) {
				sortedLayers.push(layer)
				layerDict[layer] = [entitySprite]
			else
				layerDict[layer].push(entitySprite)
			}
		}
	}
	sort(sortedLayers)
	
	return (layers = layerDict, sorted = sortedLayers)  // Return named tuple
}

function JulGame_initialize(this: any) {
	//console.warn("⚠️  FALLBACK initialize called for: $(typeof(this))")
}

function JulGame_update(this: any,  deltaTime: any) {
	//console.warn("⚠️  FALLBACK update called for: $(typeof(this))")
}

function JulGame_on_shutdown(this: any) {
	//console.warn("⚠️  FALLBACK on_shutdown called for: $(typeof(this))")
}


/*
destroy_entity(entity)

Destroy the specified entity. This removes the entity's sprite from the sprite layers so that it is no longer rendered. It also removes the entity's rigidbody from the main game's rigidbodies array.

// Arguments
- `entity`: The entity to be destroyed.
*/
function JulGame_destroy_entity(this: MainLoop,  entity) {
	for i = eachindex(this.scene.entities)
		if (this.scene.entities[i] == entity) {
			destroy_entity_components(this, entity)
			deleteat(this.scene.entities, i)
			let entity_index = findfirst(x -> x == entity, this.selectedEntities)
			if (entity_index !== null) {
				deleteat(this.selectedEntities, entity_index)
			}
			mark_input_layer_order_dirty(this)  // Cache needs rebuild
			break
		}
	}
}

function JulGame_destroy(this: MainLoop,  entity: Entity) {
	(globalThis as any).JulGame.destroy_entity(this, entity)
}

function JulGame_destroy(entity: Entity) {
	(globalThis as any).JulGame.destroy(MAIN, entity)
}

function JulGame_destroy_entity(entity) {
    (globalThis as any).JulGame.destroy_entity(MAIN, entity)
}

function JulGame_destroy_ui_element(this: MainLoop,  uiElement) {
	for i = eachindex(this.scene.uiElements)
		if (this.scene.uiElements[i] == uiElement) {
			deleteat(this.scene.uiElements, i)
			(globalThis as any).JulGame.destroy(uiElement)
			mark_input_layer_order_dirty(this)  // Cache needs rebuild
			break
		}
	}
}

function destroy_entity_components(this: MainLoop,  entity) {
	entitySprite = entity.sprite
	if (entitySprite != null) {
		layer = entitySprite.layer
		if (haskey(this.spriteLayers.layers, layer)  // No string interpolation!) {
			for j = eachindex(this.spriteLayers.layers[layer])
				if (this.spriteLayers.layers[layer][j] == entitySprite) {
					Component_destroy(entitySprite)
					deleteat(this.spriteLayers.layers[layer], j)
					break
				}
			}
		}
	}

	let entityRigidbody = entity.rigidbody
	if (entityRigidbody != null) {
		filter(rb -> rb != entityRigidbody, this.scene.rigidbodies)
	}

	let entityCollider = entity.collider
	if (entityCollider != null) {
		filter(col -> col != entityCollider, this.scene.colliders)
	}

	let entitySoundSource = entity.soundSource
	if (entitySoundSource != null) {
		Component_unload_sound(entitySoundSource)
	}

	let entityMesh3D = entity.mesh3d
	if (entityMesh3D != null) {
		Component_destroy(entityMesh3D)
	}

	let entitySoftwareRenderer3D = entity.softwareRenderer3d
	if (entitySoftwareRenderer3D != null) {
		Component_destroy(entitySoftwareRenderer3D)
	}
}


/*
create_entity(entity)

Create a new entity. Adds the entity to the main game's entities array and adds the entity's sprite to the sprite layers so that it is rendered.

// Arguments
- `entity`: The entity to create.

*/
function JulGame_create_entity(entity) {
	this = MAIN
	this.scene.entities.push(entity)
	if (entity.sprite != null) {
		layer = entity.sprite.layer
		if (!haskey(this.spriteLayers.layers, layer)  // No string interpolation!) {
			this.spriteLayers.sorted.push(layer)
			this.spriteLayers.layers[layer] = [entity.sprite]
			sort(this.spriteLayers.sorted)
		else
			this.spriteLayers.layers[layer].push(entity.sprite)
		}
	}

	if (entity.rigidbody != null) {
		this.scene.rigidbodies.push(entity.rigidbody)
	}

	if (entity.collider != null) {
		this.scene.colliders.push(entity.collider)
	}
	
	mark_input_layer_order_dirty(this)  // Cache needs rebuild

	return entity
}

/*
game_loop(this, startTime = Ref(UInt64(0)), lastPhysicsTime = Ref(UInt64(0)), close = Ref(Bool(false)), Vector{Any}} = null)

Runs the game loop.

Parameters:
- `this`: The main struct.
- `startTime`: A reference to the start time of the game loop.
- `lastPhysicsTime`: A reference to the last physics time of the game loop.
*/
function _accum_ui_render_breakdown_ms(prof, t0, key: symbol) {
	if (prof === null) { return let t1 = time_ns() }
	(globalThis as any).JulGame.LatencyProfilerModule.accumulate_ui_render_breakdown_ms(prof, key, (t1 - t0[]) / 1e6)
	t0[] = t1
	return
}

function game_loop(this: MainLoop,  startTime: Ref{UInt64} = Ref(UInt64(0)), lastPhysicsTime = Ref(UInt64(0)), windowPos = {x: 0, y: 0}, windowSize = {x: 0, y: 0})
	// Start frame profiling
	if (this.latencyProfiler !== null) {
		(globalThis as any).JulGame.LatencyProfilerModule.start_frame(this.latencyProfiler)
	}

	(globalThis as any).JulGame.FrameCount += 1
	if (this.shouldChangeScene && (globalThis as any).JulGame.IS_EDITOR) {
		this.shouldChangeScene = false
		initialize_new_scene(this)
		return
	}
	try {
			let lastStartTime = startTime[]
			startTime[] = (globalThis as any).JulGameSdl.glue_SDL_GetPerformanceCounter()

			let DEBUG = false
			//region Input
			if ((globalThis as any).JulGame.IS_EDITOR && (globalThis as any).JulGame.IS_WEB) {
				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :input_poll)
				}

				(globalThis as any).JulGame.InputModule.poll_input(this.input)

				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				}

				this.close = this.input.quit
				if (this.close) {
					(globalThis as any).JulGame.engine_states.current_state = :quit
				}

				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :render_clear)
				}
				(globalThis as any).JulGameSdl.glue_SDL_RenderClear((globalThis as any).JulGame.Renderer)
				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				}
			}

			DEBUG = this.input.debug
			cameraPosition = this.scene.camera !== null ? (this.scene.camera.position + this.scene.camera.offset) : {x: 0, y: 0}
			let cameraSize = this.scene.camera !== null ? this.scene.camera.size : {x: 0, y: 0}

			let x = 0
			let y = 0
			if ((globalThis as any).JulGame.InputModule.get_button_held_down(this.input, "Right")) {
				x = 1
			elseif (globalThis as any).JulGame.InputModule.get_button_held_down(this.input, "Left")
				x = -1
			}

			if ((globalThis as any).JulGame.InputModule.get_button_held_down(this.input, "Up")) {
				y = 1
			elseif (globalThis as any).JulGame.InputModule.get_button_held_down(this.input, "Down")
				y = -1
			}
			
			//region Physics
			if ((globalThis as any).JulGame.IS_EDITOR || this.isGameModeRunningInEditor) {
				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :physics)
				}
				
				let currentPhysicsTime = (globalThis as any).JulGameSdl.glue_SDL_GetTicks()
				deltaTime = (currentPhysicsTime - lastPhysicsTime[]) / 1000.0
				(globalThis as any).JulGame.DELTA_TIME = deltaTime
				if (this.testMode) {
					this.currentTestTime += deltaTime
				}
				if (deltaTime > .25) {
					lastPhysicsTime[] =  (globalThis as any).JulGameSdl.glue_SDL_GetTicks()
					// TODO: pause simulation
					//return
				}
				for (const rigidbody of this.scene.rigidbodies) {
					try {
						Base.invokelatest((globalThis as any).JulGame.update, rigidbody, deltaTime)
					} catch (e) {
						if (this.testMode) {
							rethrow(e)
						else
							console.log(rigidbody.parent.name, " with id: ", rigidbody.parent.id, " has a problem with it's rigidbody")
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
						}
					}
				}
				lastPhysicsTime[] =  currentPhysicsTime
				
				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				}
			}

		//region Rendering
		if (this.latencyProfiler !== null) {
			(globalThis as any).JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :entity_updates)
		}
		
		let currentRenderTime = (globalThis as any).JulGameSdl.glue_SDL_GetTicks()
		if (this.scene.camera !== null && (globalThis as any).JulGame.IS_EDITOR && (globalThis as any).JulGame.IS_WEB) {
			(globalThis as any).JulGame.CameraModule.update(this.scene.camera)
		}
		
		// Check if static sprite batches need regeneration
		if ((globalThis as any).JulGame.IS_EDITOR || this.isGameModeRunningInEditor) {
			(globalThis as any).JulGame.StaticSpriteBatcherModule.check_and_rebatch_if_needed(this.scene)
		}

			for (const entity of this.scene.entities) {
				if (!entity.isActive) {
					continue
				}

				if ((globalThis as any).JulGame.IS_EDITOR || this.isGameModeRunningInEditor) {
					try {
						// Call scripts with optional per-script profiling
						for (const script of entity.scripts) {
							let profile_scripts = this.latencyProfiler !== null
							call_script_update(this, script, deltaTime, profile_scripts)
						}
						if (this.close && !this.isGameModeRunningInEditor) {
							console.debug("Closing game")
							(globalThis as any).JulGame.engine_states.current_state = :quit
							return
						}
					} catch (e) {
						if (this.testMode) {
							rethrow(e)
						else
							console.log(entity.name, " with id: ", entity.id, " has a problem with it's update")
							@error string(e)
							Base.show_backtrace(stdout, catch_backtrace())
						}
					}
					let entityAnimator = entity.animator
					if (entityAnimator != null) {
                        Base.invokelatest((globalThis as any).JulGame.update, entityAnimator, currentRenderTime, deltaTime)
					}
				}
			}

			let coroutines_to_remove = []
			for (const coroutine of (globalThis as any).JulGame.Coroutines) {
				if (istaskdone(coroutine.task)) {
					coroutines_to_remove.push(coroutine)
					continue
				}

				notify(coroutine.condition)
				yield()
			}

			for (const coroutine_to_remove of coroutines_to_remove) {
				console.debug("coroutine done, removing")
				deleteat((globalThis as any).JulGame.Coroutines, findfirst(x -> x == coroutine_to_remove, (globalThis as any).JulGame.Coroutines))
			}
			
			if (this.latencyProfiler !== null) {
				(globalThis as any).JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
			}
			
			if ((globalThis as any).JulGame.IS_EDITOR && (globalThis as any).JulGame.IS_WEB) {
				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :sprite_rendering)
				}
				
				render_scene_sprites_and_shapes(this, this.scene.camera)
				
				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				}
			}
			
			if ((globalThis as any).JulGame.IS_DEBUG) {
				render_scene_debug(this, cameraPosition, cameraSize)
			}

			//region UI
			if (this.latencyProfiler !== null) {
				(globalThis as any).JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :ui_rendering)
			}
			
			// Sort UI elements by layer before rendering
			let uiRenderingOrder = []
			let prof_ui = this.latencyProfiler
			let t_ui = Ref(time_ns())
			let canvases = filter(x -> isa(x, (globalThis as any).JulGame.ICanvas), this.scene.uiElements)
			_accum_ui_render_breakdown_ms(prof_ui, t_ui, :ui_filter_canvases)
			let immediate_scene_skip = UI.ImmediateUIModule.immediate_ui_managed_scene_skip_ids()
			_accum_ui_render_breakdown_ms(prof_ui, t_ui, :ui_immediate_skip_ids_build)
			for (const uiElement of this.scene.uiElements) {
				if (Base.objectid(uiElement) in immediate_scene_skip) {
					continue
				}
				// TODO: Only render UI elements that are not children of a Canvas
				// Canvas children will be rendered by their parent Canvas
				//if uiElement.parent === null || !isa(uiElement.parent, UI.Canvas)
					uiRenderingOrder.push((uiElement.layer, uiElement))
				//}
			}
			_accum_ui_render_breakdown_ms(prof_ui, t_ui, :ui_scene_elements_scan)
			let render_functions_to_call = filter(x -> !x.isWorldEntity, (globalThis as any).JulGame.RENDER_FUNCTIONS)
			filter(x -> x.isWorldEntity, (globalThis as any).JulGame.RENDER_FUNCTIONS)
			for (const render_function of render_functions_to_call) {
				uiRenderingOrder.push((render_function.layer, render_function))
			}
			_accum_ui_render_breakdown_ms(prof_ui, t_ui, :ui_render_functions_push)
			let immediateUIComponents = UI.ImmediateUIModule.manage_all_immediate_components()
			_accum_ui_render_breakdown_ms(prof_ui, t_ui, :ui_immediate_manage_all)
			for (const immediateUIComponent of immediateUIComponents) {
				uiRenderingOrder.push((immediateUIComponent.layer, immediateUIComponent))
			}
			_accum_ui_render_breakdown_ms(prof_ui, t_ui, :ui_immediate_append_order)

			sort(uiRenderingOrder, by = x -> x[0])
			_accum_ui_render_breakdown_ms(prof_ui, t_ui, :ui_sort_render_order)
			for i = eachindex(uiRenderingOrder)
				try {
					let skipCanvasChild = false
					for (const canvas of canvases) {
						if (uiRenderingOrder[i][2] in canvas.children && !canvas.isActive) {
							skipCanvasChild = true
							break
						}
					}
					if (skipCanvasChild) {
						continue
					}
					let tgt = uiRenderingOrder[i][2]
					let t_r = prof_ui === null ? UInt64(0) : time_ns()
					if (tgt isa NamedTuple) {
						let func = tgt.function_to_call
						Base.invokelatest(func)
					else
						(globalThis as any).JulGame.render(tgt)
					}
					if (prof_ui !== null) {
						(globalThis as any).JulGame.LatencyProfilerModule.accumulate_ui_render_invoke_ms(prof_ui, tgt, (time_ns() - t_r) / 1e6)
					}
				} catch (e) {
					if (this.testMode) {
						rethrow(e)
					else
						let parent_info = ""
						if (isa(uiRenderingOrder[i][2], NamedTuple) && hasfield(typeof(uiRenderingOrder[i][2]), :function_to_call)) {
							parent_info = "a queued render function ($(uiRenderingOrder[i][2].function_to_call))"
						elseif isa(uiRenderingOrder[i][2], UI.UIElement) 
							parent_info = "a ui element of type $(typeof(uiRenderingOrder[i][2]))"
						}
						console.log(parent_info, " has a problem with it's render function")
						@error string(e)
						Base.show_backtrace(stdout, catch_backtrace())
					}
				}
			}
			_accum_ui_render_breakdown_ms(prof_ui, t_ui, :ui_invoke_render_loop)
			
			if (this.latencyProfiler !== null) {
				(globalThis as any).JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
			}
			
			pos1 = windowPos !== null ? windowPos : {x: 0, y: 0}
			let S_mouse = (globalThis as any).JulGame.pixels_per_world_unit(this.scene.camera)
			this.input.mousePositionWorld = Math.Vector2f((this.input.mousePosition.x + (cameraPosition.x * S_mouse)) / S_mouse, (this.input.mousePosition.y + (cameraPosition.y * S_mouse)) / S_mouse)
			let rawMousePos = {x: this.input.mousePosition.x - pos1.x , y: this.input.mousePosition.y - pos1.y}
			//region Debug
			if ((globalThis as any).JulGame.IS_DEBUG) {
				// Stats to display
				let statTexts = [
					"FPS: $(round(1000 / round((startTime[] - lastStartTime) / (globalThis as any).JulGameSdl.glue_SDL_GetPerformanceFrequency() * 1000.0)))",
					"Frame time: $(round((startTime[] - lastStartTime) / (globalThis as any).JulGameSdl.glue_SDL_GetPerformanceFrequency() * 1000.0)) ms",
					"Raw Mouse pos: $(rawMousePos.x),$(rawMousePos.y)",
					"Mouse pos world: $(this.input.mousePositionWorld.x),$(this.input.mousePositionWorld.y)"
				]

				// Draw a gray rect under the debug textboxes

				let currentColor = [r = rgba.r, g = rgba.g, b = rgba.b, a = rgba.a]
				(globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, 100, 100, 100, 255)
				(globalThis as any).JulGameSdl.glue_SDL_RenderFillRect((globalThis as any).JulGame.Renderer, Ref((globalThis as any).JulGameSdl.glue_SDL_Rect(0, 35, 400, 35 * statTexts.length)))
				(globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, currentColor[0], currentColor[1], currentColor[2], currentColor[3])

				if (this.debugTextBoxes.length == 0) {
					for i = eachindex(statTexts)
				 		let textBox = UI.TextBoxModule.TextBox(statTexts[i]; fontSize = 24, position = {x: 0, y: 35 * i})
				 		this.debugTextBoxes.push(textBox)
                         (globalThis as any).JulGame.initialize(textBox)
				 	}
				 else
				 	for i = eachindex(this.debugTextBoxes)
                         let db_textbox = this.debugTextBoxes[i]
                         db_textbox.text = statTexts[i]
                         (globalThis as any).JulGame.render(db_textbox)
			 	  	}
				 }
			}

			if (!istaskdone(this.errorLogger.task)) {
				notify(this.errorLogger.condition)
				yield()
			}

			if ((globalThis as any).JulGame.IS_EDITOR) {
				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.start_section(this.latencyProfiler, :present_and_delay)
				}
				
				(globalThis as any).JulGameSdl.glue_SDL_RenderPresent((globalThis as any).JulGame.Renderer)
				(globalThis as any).JulGameSdl.glue_SDL_framerateDelay(this.windowManager.fpsManager)
				
				if (this.latencyProfiler !== null) {
					(globalThis as any).JulGame.LatencyProfilerModule.end_section(this.latencyProfiler)
				}
			}
		} catch (e) {
			if (this.testMode) {
				rethrow(e)
			else
				@error string(e)
				Base.show_backtrace(stdout, catch_backtrace())
			}
		}
		
		// End frame profiling
		if (this.latencyProfiler !== null) {
			(globalThis as any).JulGame.LatencyProfilerModule.end_frame(this.latencyProfiler)
		}
    }

	function render_scene_sprites_and_shapes(this: MainLoop,  camera: Camera) {
		cameraPosition = camera !== null ? camera.position : {x: 0, y: 0}
		cameraSize = camera !== null ? camera.size : {x: 0, y: 0}
		let S = (globalThis as any).JulGame.pixels_per_world_unit(camera)
			
		skipcount = 0
		let rendercount = 0
		let renderOrder = []
		for (const entity of this.scene.entities) {
			let spriteExists = entity.sprite != null && entity.sprite !== null
			let shapeExists = entity.shape != null && entity.shape !== null
			let mesh3dExists = entity.mesh3d != null && entity.mesh3d !== null
			let softwareRenderer3dExists = entity.softwareRenderer3d != null && entity.softwareRenderer3d !== null
			if (!entity.isActive || (!spriteExists && !shapeExists && !mesh3dExists && !softwareRenderer3dExists)) {
				continue
			}

			let position = entity.transform.position
			size = entity.transform.scale
			let sprite = entity.sprite
			let shape = entity.shape
			let mesh3d = entity.mesh3d
			let softwareRenderer3d = entity.softwareRenderer3d

			let skipSprite = false
			let skipShape = false
			let skipMesh3d = false
			let skipSoftwareRenderer3d = false

			// TODO: consider offset
			if (spriteExists && ((position.x + size.x) < cameraPosition.x || position.y < cameraPosition.y || position.x > cameraPosition.x + cameraSize.x/S || (position.y - size.y) > cameraPosition.y + cameraSize.y/S) && this.optimizeSpriteRendering) {
				skipSprite = true
			}

			// TODO: consider offset
			if (shapeExists && ((position.x + size.x) < cameraPosition.x || position.y < cameraPosition.y || position.x > cameraPosition.x + cameraSize.x/S || (position.y - size.y) > cameraPosition.y + cameraSize.y/S) && shape.isWorldEntity && this.optimizeSpriteRendering) {
				skipShape = true
			}

			if (!skipSprite && spriteExists) {
				// Skip static sprites in-game (they're rendered via batched textures)
				// BUT always render them in editor scene viewer for manipulation
				let should_batch = sprite.isStatic && ((globalThis as any).JulGame.IS_EDITOR || this.isGameModeRunningInEditor)
				if (!should_batch) {
					renderOrder.push((sprite.layer, sprite))
				}
			}
			if (!skipShape && shapeExists) {
				renderOrder.push((shape.layer, shape))
			}
			if (!skipMesh3d && mesh3dExists) {
				renderOrder.push((mesh3d.layer, mesh3d))
			}
			if (!skipSoftwareRenderer3d && softwareRenderer3dExists) {
				renderOrder.push((softwareRenderer3d.layer, softwareRenderer3d))
			}
			if (skipSprite && spriteExists) {
				sprite.lastRenderedScreenPosition = null
				sprite.lastRenderedScreenSize = null
			}
		}

	render_functions_to_call = filter(x -> x.isWorldEntity, (globalThis as any).JulGame.RENDER_FUNCTIONS)
	filter(x -> !x.isWorldEntity, (globalThis as any).JulGame.RENDER_FUNCTIONS)
	for (const render_function of render_functions_to_call) {
		renderOrder.push((render_function.layer, render_function))
	}
	
	// Add batched static sprite layers to render order
	// Only render batched layers when NOT in editor scene viewer
	if ((globalThis as any).JulGame.IS_EDITOR || this.isGameModeRunningInEditor) {
		for (layer, batched_layer) in this.scene.batchedLayers
			renderOrder.push((layer, batched_layer))
		}
	}
	
	sort(renderOrder, by = x -> x[0])
		
		for i = eachindex(renderOrder)
			try {
				rendercount += 1
			if (renderOrder[i][2] isa Component.Mesh3DModule.Mesh3D) {
				Component_render(renderOrder[i][2], this)
			elseif renderOrder[i][2] isa Component.SoftwareRenderer3DModule.SoftwareRenderer3D
				Component_render(renderOrder[i][2], this)
			elseif renderOrder[i][2] isa Component.SpriteModule.InternalSprite || renderOrder[i][2] isa Component.ShapeModule.InternalShape 
				Component_draw(renderOrder[i][2], camera)
			elseif renderOrder[i][2] isa NamedTuple
				// get the params	
				func = renderOrder[i][2].function_to_call
				Base.invokelatest(func)
			elseif hasproperty(renderOrder[i][2], :textures) && hasproperty(renderOrder[i][2], :layer)
				// Render batched static sprite layer
				(globalThis as any).JulGame.StaticSpriteBatcherModule.render_batched_layer(renderOrder[i][2], camera)
			else
				console.log("Unknown item type: ", typeof(renderOrder[i][2]))
			}
			} catch (e) {
				if (this.testMode) {
					rethrow(e)
				else
					parent_info = ""
					if (isa(renderOrder[i][2], NamedTuple) && hasfield(typeof(renderOrder[i][2]), :function_to_call)) {
						parent_info = "a queued render function ($(renderOrder[i][2].function_to_call))"
					elseif hasproperty(renderOrder[i][2], :parent) && renderOrder[i][2].parent !== null && isa(renderOrder[i][2].parent, (globalThis as any).JulGame.EntityModule.Entity)
						parent_info = "$(renderOrder[i][2].parent.name) with id: $(renderOrder[i][2].parent.id)"
					else 
						parent_info = "a component of type $(typeof(renderOrder[i][2]))"
					}
					console.log(parent_info, " has a problem with rendering")
					@error string(e)
					Base.show_backtrace(stdout, catch_backtrace())
				}
			}
		}
	}

	function start_game_in_editor(this: MainLoop,  path: string) {
		this.isGameModeRunningInEditor = true
		SceneBuilderModule.add_scripts_to_entities(path)
		initialize_scripts_and_components()
	}

	function stop_game_in_editor(this: MainLoop) {
		this.isGameModeRunningInEditor = false
		SDL2.Mix_HaltMusic()
		
		// Clean up all immediate UI components when stopping the game in editor
		(globalThis as any).JulGame.UI.ImmediateUIModule.cleanup_all_immediate_components()
		
		// Clean up all coroutines when stopping the game in editor
		console.debug("Cleaning up coroutines when stopping game in editor")
		cleanup_coroutines()
		
		if (this.scene.camera !== null && this.scene.camera != null) {
			this.scene.camera.target = null
		}
	}

	function render_scene_debug(this: MainLoop,  cameraPosition,  cameraSize) {
		S = (globalThis as any).JulGame.pixels_per_world_unit(this.scene.camera)
		let colliderSkipCount = 0
		let colliderRenderCount = 0
		for (const entity of this.scene.entities) {
			if (!entity.isActive) {
				continue
			}
	
			if (entity.collider != null) {
				rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))

				(globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, 0, 255, 0, SDL2.SDL_ALPHA_OPAQUE)
				let pos = entity.transform.position
				let scale = entity.transform.scale
	
				if (((pos.x + scale.x) < cameraPosition.x || pos.y < cameraPosition.y || pos.x > cameraPosition.x + cameraSize.x/S || (pos.y - scale.y) > cameraPosition.y + cameraSize.y/S)  && this.optimizeSpriteRendering) {
					colliderSkipCount += 1
					continue
				}
				colliderRenderCount += 1
				let collider = entity.collider
	
				
				let colSize = collider.size
				colSize = {x: colSize.x, y: colSize.y}
				let colOffset = collider.offset
				colOffset = {x: colOffset.x, y: colOffset.y}
						
				(globalThis as any).JulGameSdl.glue_SDL_RenderDrawRectF((globalThis as any).JulGame.Renderer, 
				Ref((globalThis as any).JulGameSdl.glue_SDL_FRect((pos.x + colOffset.x - cameraPosition.x) * S, 
				(pos.y + colOffset.y - cameraPosition.y) * S, 
				entity.transform.scale.x * colSize.x * S, 
				entity.transform.scale.y * colSize.y * S)))
				(globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, rgba.r, rgba.g, rgba.b, rgba.a);
			}
		}
	}

	function JulGame_cleanup_sdl_resources() {
		(globalThis as any).JulGameSdl.glue_SDL_ClearError()
		console.debug("Closing window")
		if ((globalThis as any).JulGame.Renderer != Ptr{SDL2.SDL_Renderer}(null) && (globalThis as any).JulGame.Renderer != null) {
			console.debug("Destroying renderer: $((globalThis as any).JulGame.Renderer)")
			(globalThis as any).JulGameSdl.glue_SDL_DestroyRenderer((globalThis as any).JulGame.Renderer)
			if (unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()) != "") {
				console.error("Failed to destroy renderer, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
			}
			(globalThis as any).JulGame.Renderer = null
		else
			console.debug("Renderer is already destroyed")
			return
		}
		(globalThis as any).JulGameSdl.glue_SDL_ClearError()
		
		// Use the WindowManager to close the window
		if ((globalThis as any).JulGame.MAIN.windowManager !== null) {
			(globalThis as any).JulGame.WindowManagerModule.close_window()
		}
		
		(globalThis as any).JulGameSdl.glue_SDL_ClearError()
        // Reset any OpenGL-related attributes that might have been set
        console.debug("Resetting GL attributes")
        (globalThis as any).JulGameSdl.glue_SDL_GL_ResetAttributes()
		if (unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()) != "") {
			console.error("Failed to reset GL attributes, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
		}
		(globalThis as any).JulGameSdl.glue_SDL_ClearError()
		console.debug("Quitting Mix")
        SDL2.Mix_Quit()
		if (unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()) != "") {
			console.error("Failed to quit Mix, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
		}
		(globalThis as any).JulGameSdl.glue_SDL_ClearError()
		console.debug("Quitting TTF")
        SDL2.TTF_Quit()
		if (unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()) != "") {
			console.error("Failed to quit TTF, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
		}
		(globalThis as any).JulGameSdl.glue_SDL_ClearError()
		console.debug("Quitting SDL")
        (globalThis as any).JulGameSdl.glue_SDL_Quit()
		if (unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()) != "") {
			console.error("Failed to quit SDL, $(unsafe_string((globalThis as any).JulGameSdl.glue_SDL_GetError()))")
		}
	}
