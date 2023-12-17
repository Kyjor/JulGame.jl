module JulGame
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer
    include("ModuleExtensions/SDL2Extension.jl")
    const SDL2E = SDL2Extension
    export SDL2, SDL2E

    include("Constants.jl")
    export SCALE_UNITS, GRAVITY
    
    BasePath = ""
    export BasePath

    Renderer = Ptr{SDL2.LibSDL2.SDL_Renderer}(C_NULL)
    export Renderer
    
    include("Macros.jl")
    using .Macros: @event
    export @event

    include("Math/Math.jl")
    using .Math: Math
    export Math

    include("Input/Input.jl")
    using .InputModule: Input
    export Input

    include("UI/UI.jl")
    using .UI
    export ScreenButtonModule, TextBoxModule

    include("Main.jl") 
    using .MainLoop: Main   
    const MAIN = Main(Float64(1.0))
    export MAIN

    include("Component/Component.jl")
    using .Component
    export AnimationModule, AnimatorModule, ColliderModule, CircleColliderModule, RigidbodyModule, ShapeModule, SoundSourceModule, SpriteModule, TransformModule

    include("Entity.jl") 
    using .EntityModule   
    export Entity

    include("SceneManagement/SceneManagement.jl")
    using .SceneManagement
    export SceneBuilderModule, SceneLoaderModule, SceneReaderModule, SceneWriterModule 

    include("editor/Editor/Editor.jl")
    using .Editor
    export Editor 
end