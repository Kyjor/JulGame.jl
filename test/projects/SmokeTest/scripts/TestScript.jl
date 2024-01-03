using JulGame.AnimationModule
using JulGame.Component 
using JulGame.EntityModule 
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
                newAnimation = AnimationModule.Animation(Vector4[Vector4(0,0,0,0)], 60)
                @testset "Animation constructor" begin
                    @test newAnimation != C_NULL && newAnimation !== nothing
                    @test newAnimation.animatedFPS == 60
                end

                @testset "Animator constructor" begin
                    newAnimator = AnimatorModule.Animator(AnimationModule.Animation[newAnimation])
                    @test newAnimator != C_NULL && newAnimator !== nothing
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