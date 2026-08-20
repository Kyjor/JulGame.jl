module Component
    using ..JulGame
    include("ComponentFunctions.jl")
    include("Transform.jl")
    include("Sprite.jl")
    include("Animation.jl")
    include("Animator.jl")
    include("Collider.jl")
    include("Rigidbody.jl")
    include("Shape.jl")
    include("SoundSource.jl")
    include("Mesh3D.jl")
    include("SoftwareRenderer3D.jl")

    export AnimationModule
    export AnimatorModule
    export ColliderModule
    export RigidbodyModule
    export ShapeModule
    export SoundSourceModule
    export SpriteModule
    export TransformModule
    export Mesh3DModule
    export SoftwareRenderer3DModule
end
