using JulGame.AnimationModule
using JulGame.CircleColliderModule
using JulGame.ColliderModule
using JulGame.RigidbodyModule
using JulGame.ShapeModule
using JulGame.SoundSourceModule
using JulGame.SpriteModule
using JulGame.TransformModule 
using JulGame.MainLoop 
using JulGame.Math
using JulGame.UI
using Test 

mutable struct TestScript
    parent

    function TestScript()
        this = new()
        
        return this
    end
end

function Base.getproperty(this::TestScript, s::Symbol)
    if s == :initialize
        function()

            @testset "Engine Animation Tests" begin
                newAnimation = AnimationModule.Animation(Vector4[Vector4(0,0,0,0)], Int32(60))
                @testset "Animation constructor" begin
                    @test newAnimation != C_NULL && newAnimation !== nothing
                    @test newAnimation.animatedFPS == 60
                end

                @testset "Animator constructor" begin
                    newAnimator = AnimatorModule.Animator(AnimationModule.Animation[newAnimation])
                    @test newAnimator != C_NULL && newAnimator !== nothing
                end

                @testset "CircleCollider constructor" begin
                    newCircleCollider = CircleColliderModule.CircleCollider(1.0, true, false, Math.Vector2f(0,0), "Default")
                    @test newCircleCollider != C_NULL && newCircleCollider !== nothing
                end

                @testset "Collider constructor" begin
                    newCollider = ColliderModule.Collider(true, false, false, Math.Vector2f(0,0), Math.Vector2f(1,1), "Default")
                    @test newCollider != C_NULL && newCollider !== nothing
                end

                @testset "Rigidbody constructor" begin
                    newRigidbody = RigidbodyModule.Rigidbody(1.0)
                    @test newRigidbody != C_NULL && newRigidbody !== nothing
                end

                @testset "Shape constructor" begin
                    newShape = ShapeModule.Shape(Math.Vector3(255,0,0), Math.Vector2f(1,1), true, true, Math.Vector2f(0,0), Math.Vector2f(0,0))
                    @test newShape != C_NULL && newShape !== nothing
                end
            end
        end
    elseif s == :update
        function(deltaTime)
        end
    elseif s == :setParent 
        function(parent)
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end