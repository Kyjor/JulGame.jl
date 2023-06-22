__precompile__(false)
module JulGame
    include("Macros.jl")
    using .Macros: @event
    export @event

    include("Math/Math.jl")
    using .Math: Math
    export Math

    include("Input/InputInstance.jl")
    using .InputInstance: Input
    export Input

    include("Main.jl") 
    using .MainLoop: Main   
    const MAIN = Main(2.0)
    export MAIN

    include("UI/UI.jl")
    using .UI
    export ScreenButtonModule, TextBoxModule

    export Component
    include("Component/Component.jl")
    using .Component
    export AnimationModule, AnimatorModule, ColliderModule, RigidbodyModule, SoundSourceModule, SpriteModule, TransformModule

    include("Entity.jl") 
    using .EntityModule   
    export Entity

    export SceneManagement
    include("SceneManagement/SceneManagement.jl")
    using .SceneManagement
    export SceneBuilderModule, SceneLoaderModule, SceneReaderModule, SceneWriterModule 

    include("../editor/Editor/Editor.jl")
    using .Editor
    export Editor 
end