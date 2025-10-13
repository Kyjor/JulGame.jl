module JulGame
    include("utils/CommonFunctions.jl")
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    MAIN = nothing

    IS_WEB::Bool = false
    IS_DEBUG::Bool = false
    IS_PACKAGE_COMPILED::Bool = false
    IS_CHANGING_SCENE::Bool = false
    
    # Temporary variable for recent project path selection
    TEMP_SELECTED_PATH::String = ""
    
    DELTA_TIME = 0.0
    # TODO: Create a globals file
    
    SCENE_CACHE::Dict = Dict{String, Any}()
    PRELOADED_SCENES::Dict = Dict{String, Any}()
    IMAGE_CACHE::Dict = Dict{String, Any}()
    FONT_CACHE::Dict = Dict{String, Any}()
    AUDIO_CACHE::Dict = Dict{String, Any}()
    
    BUILT_IN_ASSETS::Dict = Dict{String, Any}()
    BUILT_IN_ASSETS["Font"] = read(joinpath(@__DIR__, "engine", "Assets", "Fonts", "FiraCode-Regular.ttf"))
    
    IS_EDITOR::Bool = false
    IS_EDITOR_PLAY_MODE::Bool = false
    
    Coroutines::Vector = []
    RENDER_FUNCTIONS::Vector = []

    ProjectModule = ""
    ScriptModule = Module(:Scripts)
    LoadedScripts = Set{String}()

    include("utils/Interfaces.jl")
    export IEntity, IUIElement, ITransform, IShape, ISoundSource, ISprite, IAnimator, ICollider, ICircleCollider, IMesh3D, ISoftwareRenderer3D, IObserver, IHistory
   
    include("engine/Events/Events.jl")
    using .EventsModule
    export EventsModule, ObserverModule, add_observer, remove_observer, notify_observer

    EditorState = Dict{String, Any}(
        "HistoryData" => Dict{String, IHistory}(),
        "HistoryStack" => [],
        "HistoryStackIndex" => 0,
    )
   
    include("engine/History/History.jl")
    using .HistoryModule
    export HistoryModule, undo, redo

    FrameCount = 0
    UserGlobals = Dict{String, Any}()

    include("engine/Logging/Logging.jl")
    using .Logging
    export ErrorLoggerModule

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
    
    BasePath = ""
    export BasePath
    
    Renderer = Ptr{SDL2.LibSDL2.SDL_Renderer}(C_NULL)
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
    EditorGameViewPosition = Math.Vector2(0,0)

    """
        EditorGameViewSize::Math.Vector2

    Stores the rendered size (potentially scaled/letterboxed) of the editor's game view panel. Updated by `GameViewer.jl`.
    """
    EditorGameViewSize = Math.Vector2(0,0) # Holds the size of the rendered game texture (could be letterboxed)

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

    include("engine/UI/UI.jl")
    using .UI
    export ScreenButtonModule, TextBoxModule, ImmediateUIModule, CanvasModule, UIImageModule

    include("engine/Component/Component.jl")
    using .Component
    export AnimationModule, AnimatorModule, ColliderModule, CircleColliderModule, RigidbodyModule, ShapeModule, SoundSourceModule, SpriteModule, TransformModule, SoftwareRenderer3DModule

    include("engine/FX/FX.jl")
    using .FX
    export ImageFXModule, BackgroundFXModule
    
    include("engine/Camera/Camera.jl")
    using .CameraModule: Camera
    
    include("engine/Entity.jl") 
    using .EntityModule   
    export Entity

    include("engine/Scene.jl")
    using .SceneModule: Scene

    include("engine/SceneManagement/SceneManagement.jl")
    using .SceneManagement
    export SceneBuilderModule, SceneLoaderModule, SceneReaderModule, SceneWriterModule 

    include("engine/Rendering/Rendering.jl")
    using .Rendering
    export Rendering

    include("MainLoop.jl") 
    using .MainLoopModule: MainLoop
    export MainLoop

    include("utils/Exports.jl")
end