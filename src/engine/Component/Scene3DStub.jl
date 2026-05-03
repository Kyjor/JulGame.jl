# Minimal Mesh3D / SoftwareRenderer3D stand-ins when `JulGame.ENABLE_SCENE_3D == false`
# (2D-only builds, smaller IR for JuliaC `--trim`). Set `ENABLE_SCENE_3D = true` in JulGame.jl to restore full implementations.

module Mesh3DModule
    using ..JulGame
    using ..JulGame.Component

    export vec3d, Mesh3D

    mutable struct vec3d
        x::Float64
        y::Float64
        z::Float64
        w::Float64
        function vec3d(x::Number, y::Number, z::Number, w::Number = 1.0)
            new(convert(Float64, x), convert(Float64, y), convert(Float64, z), convert(Float64, w))
        end
    end

    mutable struct Mesh3D
        parent::Union{JulGame.IEntity, Nothing}
        layer::Int
        isWorldEntity::Bool
        fNear::Float64
        fFar::Float64
        fFov::Float64
        fYaw::Float64
        fTheta::Float64
        fAspectRatio::Float64
        vCamera::vec3d
        vLookDir::vec3d
        function Mesh3D()
            z = vec3d(0.0, 0.0, 0.0, 1.0)
            new(nothing, 0, true, 0.1, 1000.0, 90.0, 0.0, 0.0, 0.0, z, z)
        end
    end

    function Component.initialize(::Mesh3D, @nospecialize(main))::Nothing end
    function Component.update(::Mesh3D, ::Float64)::Nothing end
    function Component.render(::Mesh3D, @nospecialize(main))::Nothing end
    function Component.destroy(::Mesh3D)::Nothing end
end

module SoftwareRenderer3DModule
    using ..JulGame
    using ..JulGame.Component

    export SoftwareRenderer3D

    mutable struct SoftwareRenderer3D
        parent::Union{JulGame.IEntity, Nothing}
        layer::Int
        function SoftwareRenderer3D()
            new(nothing, 0)
        end
    end

    function Component.initialize(::SoftwareRenderer3D, @nospecialize(main))::Nothing end
    function Component.update(::SoftwareRenderer3D, ::Float64)::Nothing end
    function Component.render(::SoftwareRenderer3D, @nospecialize(main))::Nothing end
    function Component.destroy(::SoftwareRenderer3D)::Nothing end
end
