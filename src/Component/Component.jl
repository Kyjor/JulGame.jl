module Component
    using ..engine
    abstract type EntityComponent end
    # include("Animation.jl")
    # include("Animator.jl")
      include("Collider.jl")
    # include("Rigidbody.jl")
    # include("SoundSource.jl")
    # include("Sprite.jl")
    # include("Transform.jl")
    
    export Collider
end