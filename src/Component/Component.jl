module Component
    using ..JulGame
    abstract type EntityComponent end
      include("Animation.jl")
      include("Animator.jl")
      include("Collider.jl")
      include("CircleCollider.jl")
      include("Rigidbody.jl")
      include("Shape.jl")
      include("SoundSource.jl")
      include("Sprite.jl")
      include("Transform.jl")
    
    export AnimationModule
    export AnimatorModule
    export ColliderModule
    export CircleColliderModule
    export RigidbodyModule
    export ShapeModule
    export SoundSourceModule
    export SpriteModule
    export TransformModule
end