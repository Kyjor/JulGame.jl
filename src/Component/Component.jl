module Component
    using ..julGame
    abstract type EntityComponent end
      include("Animation.jl")
      include("Animator.jl")
      include("Collider.jl")
      include("Rigidbody.jl")
      include("SoundSource.jl")
      include("Sprite.jl")
      include("Transform.jl")
    
    export AnimationModule
    export AnimatorModule
    export ColliderModule
    export RigidbodyModule
    export SoundSourceModule
    export SpriteModule
    export TransformModule
end