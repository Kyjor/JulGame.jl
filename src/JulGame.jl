module JulGame
    using SimpleDirectMediaLayer
    const SDL2 = SimpleDirectMediaLayer

    function __init__()
        SDL2.init()
    end

    include("ModuleExtensions/SDL2Extension.jl")
    const SDL2E = SDL2Extension
    export SDL2, SDL2E

    include("Utils.jl")
    export CallSDLFunction

    include("Constants.jl")
    export SCALE_UNITS, GRAVITY

    PIXELS_PER_UNIT = -1
    export PIXELS_PER_UNIT
    
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
    export AnimationModule, AnimatorModule, ColliderModule, CircleColliderModule, RigidbodyModule, ShapeModule, SoundSourceModule, SpriteModule, TransformModule

    include("Entity.jl") 
    using .EntityModule   
    export Entity

    include("SceneManagement/SceneManagement.jl")
    using .SceneManagement
    export SceneBuilderModule, SceneLoaderModule, SceneReaderModule, SceneWriterModule 
end