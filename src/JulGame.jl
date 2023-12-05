module JulGame
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 
    export SDL2
    const SCALE_UNITS = 64.0
    export SCALE_UNITS 
    BasePath = ""
    export BasePath
    
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
    const MAIN = Main(1.0)
    export MAIN

    include("Component/Component.jl")
    using .Component
    export AnimationModule, AnimatorModule, ColliderModule, RigidbodyModule, ShapeModule, SoundSourceModule, SpriteModule, TransformModule

    include("Entity.jl") 
    using .EntityModule   
    export Entity

    include("SceneManagement/SceneManagement.jl")
    using .SceneManagement
    export SceneBuilderModule, SceneLoaderModule, SceneReaderModule, SceneWriterModule 

    include("../editor/Editor/Editor.jl")
    using .Editor
    export Editor 
end