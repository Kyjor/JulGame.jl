module JulGame
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer 
    export SDL2
    
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
    
    include("Particle/Particle.jl") 
    using .ParticleModule
    export ParticleModule

    include("Main.jl") 
    using .MainLoop: Main   
    const MAIN = Main(Float64(1.0))
    export MAIN
    
    include("Particle/Dot.jl")
    using .DotModule
    export DotModule

    include("Component/Component.jl")
    using .Component
    export AnimationModule, AnimatorModule, ColliderModule, RigidbodyModule, ShapeModule, SoundSourceModule, SpriteModule, TransformModule

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