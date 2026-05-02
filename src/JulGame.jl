module JulGame
    include("utils/CommonFunctions.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    MAIN = nothing

    IS_WEB::Bool = false
    IS_DEBUG::Bool = false
    IS_PACKAGE_COMPILED::Bool = false
    IS_CHANGING_SCENE::Bool = false
    SCALE_QUALITY::String = "2"

    # Temporary variable for recent project path selection
    TEMP_SELECTED_PATH::String = ""
    
    DELTA_TIME = 0.0
    # TODO: Create a globals file
    
    SCENE_CACHE::Dict{String, Any} = Dict{String, Any}()
    IMAGE_CACHE::Dict{String, Vector{UInt8}} = Dict{String, Vector{UInt8}}()
    FONT_CACHE::Dict{String, Any} = Dict{String, Any}()
    AUDIO_CACHE::Dict{String, Vector{UInt8}} = Dict{String, Vector{UInt8}}()
    
    BUILT_IN_ASSETS::Dict{String, Any} = Dict{String, Any}()
    BUILT_IN_ASSETS["Font"] = read(joinpath(@__DIR__, "engine", "Assets", "Fonts", "FiraCode-Regular.ttf"))
    
    IS_EDITOR::Bool = false
    IS_EDITOR_PLAY_MODE::Bool = false
    
    Coroutines::Vector = []
    RENDER_FUNCTIONS::Vector = []

    ProjectModule = ""
    ScriptModule = Module(:Scripts)
    const LoadedScripts::Set{String} = Set{String}()

    include("utils/Interfaces.jl")
    export IEntity, IUIElement, ITransform, IShape, ISoundSource, ISprite, IAnimator, ICollider, ICircleCollider, IMesh3D, ISoftwareRenderer3D, IObserver, IHistory, ICanvas
   
    include("engine/Events/Events.jl")
    using .EventsModule
    export EventsModule, ObserverModule, add_observer, remove_observer, notify_observer

    EditorState = Dict{String, Any}(
        "HistoryData" => Dict{String, IHistory}(),
        "HistoryStack" => [],
        "HistoryStackIndex" => 0,
    )

    # Typed SDL drop staging (Input polls into these; editor merges into EditorState).
    const EDITOR_SDL_DROP_FILE_PATHS = String[]
    const EDITOR_SDL_DROP_TEXT_PATHS = String[]

    function sync_editor_sdl_drops_to_editor_state!()::Nothing
        if !isempty(EDITOR_SDL_DROP_FILE_PATHS)
            if !haskey(EditorState, "dropped_files")
                EditorState["dropped_files"] = String[]
            end
            df = EditorState["dropped_files"]::Vector{String}
            append!(df, EDITOR_SDL_DROP_FILE_PATHS)
            empty!(EDITOR_SDL_DROP_FILE_PATHS)
        end
        if !isempty(EDITOR_SDL_DROP_TEXT_PATHS)
            if !haskey(EditorState, "dropped_texts")
                EditorState["dropped_texts"] = String[]
            end
            dt = EditorState["dropped_texts"]::Vector{String}
            append!(dt, EDITOR_SDL_DROP_TEXT_PATHS)
            empty!(EDITOR_SDL_DROP_TEXT_PATHS)
        end
        return nothing
    end

    include("engine/History/History.jl")
    using .HistoryModule
    export HistoryModule, undo, redo

    FrameCount = 0
    UserGlobals = Dict{String, Any}()

    include("engine/Logging/Logging.jl")
    using .Logging
    export ErrorLoggerModule

    include("engine/Diagnostics/Diagnostics.jl")
    using .Diagnostics
    export LatencyProfilerModule

    include("ModuleExtensions/SDL2Extension.jl")
    const SDL2E = SDL2Extension
    export DELTA_TIME, IS_EDITOR, SDL2, SDL2E, MAIN

    include("utils/Structs.jl")
    export EditorExport, Enum

    const engine_states = Enum{Any}(
        :startup, 
        :scene_change,
        :game_mode,
        :editor_mode,
        :quit
    )
    engine_states.current_state = :startup

    export engine_states

    include("Coroutine/Coroutine.jl")
    using .CoroutineModule
    export Coroutine
    
    include("utils/Types.jl")
    export Script

    include("utils/Helpers.jl")
    export get_comma_separated_path

    include("utils/Utils.jl")
    export CallSDLFunction

    include("utils/Constants.jl")
    export SCALE_UNITS, GRAVITY

    PIXELS_PER_UNIT = 16
    export PIXELS_PER_UNIT
    
    global BasePath::String = ""
    export BasePath
    
    global Renderer::Ptr{SDL2.SDL_Renderer} = Ptr{SDL2.SDL_Renderer}(C_NULL)
    export Renderer

    Headless = false
    export Headless
    
    include("utils/Macros.jl")
    using .Macros: @event, @argevent
    export @event, @argevent

    include("Math/Math.jl")
    using .Math: Math, Vector2f, Vector3f, Vector4f, Vector2, Vector3, Vector4, Lerp, SmoothLerp, to_vector3
    export Math

    EditorGameWindowSize::Math.Vector2 = Math.Vector2(0, 0)

    """
        EditorGameViewPosition::Math.Vector2

    Stores the top-left screen coordinate of the editor's game view panel. Updated by `GameViewer.jl`.
    """
    EditorGameViewPosition::Math.Vector2 = Math._Vector2{Int32}(0, 0)

    """
        EditorGameViewSize::Math.Vector2

    Stores the rendered size (potentially scaled/letterboxed) of the editor's game view panel. Updated by `GameViewer.jl`.
    """
    EditorGameViewSize::Math.Vector2 = Math._Vector2{Int32}(0, 0) # Holds the size of the rendered game texture (could be letterboxed)

    include("engine/DataManagement/DataManagement.jl")
    using .DataManagement: PrefHandlerModule
    export PrefHandlerModule

    include("engine/Resource/Resource.jl")
    using .ResourceModule
    export ImageModule

    include("engine/Window/WindowManager.jl")
    using .WindowManagerModule: WindowManager
    export WindowManager

    include("engine/Input/Input.jl")
    using .InputModule: Input
    export Input

    include("engine/Component/Component.jl")
    using .Component
    export AnimationModule, AnimatorModule, ColliderModule, CircleColliderModule, RigidbodyModule, ShapeModule, SoundSourceModule, SpriteModule, TransformModule, SoftwareRenderer3DModule

    include("engine/Effects/Effects.jl")
    using .Effects
    export EffectsModule, EffectRendererModule, EffectCacheModule, EffectAlgorithmsModule, EffectExamplesModule

    include("engine/UI/UI.jl")
    using .UI
    export ScreenButtonModule, TextBoxModule, ImmediateUIModule, CanvasModule, UIImageModule

    include("engine/FX/FX.jl")
    using .FX
    export ImageFXModule, BackgroundFXModule
    
    include("engine/Camera/Camera.jl")
    using .CameraModule: Camera, pixels_per_world_unit, apply_zoom_to_center!
    export pixels_per_world_unit, apply_zoom_to_center!
    
    include("engine/Entity.jl") 
    using .EntityModule   
    export Entity

    """Stable id for observers / trim-verifier paths (`Transform.parent` is untyped elsewhere)."""
    scene_entity_id(e::Entity)::String = e.id::String
    export scene_entity_id

    const PreloadedSceneData = @NamedTuple{entities::Vector{Entity}, uiElements::Vector{IUIElement}, camera::Camera}
    const PRELOADED_SCENES = Dict{String, PreloadedSceneData}()

    include("engine/Scene.jl")
    using .SceneModule: Scene

    include("engine/SceneManagement/SceneManagement.jl")
    using .SceneManagement
    export SceneBuilderModule, SceneLoaderModule, SceneReaderModule, SceneWriterModule 

    include("engine/Rendering/Rendering.jl")
    using .Rendering
    export Rendering

    include("engine/Rendering/StaticSpriteBatcher.jl")
    using .StaticSpriteBatcherModule
    export StaticSpriteBatcherModule
    
    include("engine/Rendering/StaticSpriteBatcherHelpers.jl")
    export set_batched_layer_offset, get_batched_layer_offset, get_batched_layer_info, list_batched_layers

    include("MainLoop.jl") 
    using .MainLoopModule: MainLoop, enable_profiling, disable_profiling, print_profiling_report, export_profiling_data, maybe_enable_latency_profiling_from_env!, mark_input_layer_order_dirty!
    export MainLoop, enable_profiling, disable_profiling, print_profiling_report, export_profiling_data, maybe_enable_latency_profiling_from_env!, mark_input_layer_order_dirty!

    """
        current_main() -> MainLoop

    Active main loop after `JulGame.MAIN` is assigned. Prefer this over raw `MAIN` in library code so return type is `MainLoop` for inference (helps JuliaC `--trim` verification).
    """
    function current_main()::MainLoop
        m = MAIN
        m === nothing && error("JulGame.MAIN is not set; start the game loop / load a scene first")
        return m::MainLoop
    end
    export current_main

    # JuliaC `--trim` static verifier: SDL/ccall edges and `invokelatest` script calls may remain unresolved
    # until the engine exposes more concrete types or JuliaC adds trim hooks. Prefer `current_main()` over
    # raw `MAIN` in library code so `MainLoop` return type is known to inference.

    include("utils/Exports.jl")
end