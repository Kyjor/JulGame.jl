#using Test 
using JulGame.AnimationModule
using JulGame.CircleColliderModule
using JulGame.ColliderModule
using JulGame.EntityModule
using JulGame.RigidbodyModule
using JulGame.ShapeModule
using JulGame.SoundSourceModule
using JulGame.SpriteModule
using JulGame.TransformModule 
using JulGame.MainLoop 
using JulGame.Math
using JulGame.UI

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

            try
                
            
            newAnimation = C_NULL
            newAnimator = C_NULL
            #@testset "Engine Animation Tests" begin
                newAnimation = AnimationModule.Animation(Vector4[Vector4(0,0,0,0)], Int32(60))
                #@testset "Animation constructor" begin
                    # @test 
newAnimation != C_NULL && newAnimation !== nothing
                    # @test 
newAnimation.animatedFPS == 60
                #end

                #@testset "Animator constructor" begin
                    newAnimator = AnimatorModule.Animator(AnimationModule.Animation[newAnimation])
                    # @test 
newAnimator != C_NULL && newAnimator !== nothing
                #end
            #end

            newCircleCollider = C_NULL
            newCollider = C_NULL
            #@testset "Engine Collider Tests" begin
                #@testset "CircleCollider constructor" begin
                    newCircleCollider = CircleColliderModule.CircleCollider(1.0, true, false, Math.Vector2f(0,0), "Default")
                    # @test 
newCircleCollider != C_NULL && newCircleCollider !== nothing
                #end

                #@testset "Collider constructor" begin
                    newCollider = ColliderModule.Collider(true, false, false, Math.Vector2f(0,0), Math.Vector2f(1,1), "Default")
                    # @test 
newCollider != C_NULL && newCollider !== nothing
                #end
            #end

            newRigidbody = C_NULL
            #@testset "Engine Rigidbody Tests" begin
                #@testset "Rigidbody constructor" begin
                    newRigidbody = RigidbodyModule.Rigidbody()
                    # @test 
newRigidbody != C_NULL && newRigidbody !== nothing
                #end
            #end

            newShape = C_NULL
            #@testset "Engine Shape Tests" begin
                #@testset "Shape constructor" begin
                    newShape = ShapeModule.Shape(Math.Vector3(255,0,0), Math.Vector2f(1,1), true, true, Math.Vector2f(0,0), Math.Vector2f(0,0))
                    # @test 
newShape != C_NULL && newShape !== nothing
                #end
            #end

            newEntity = C_NULL
            #@testset "Engine Entity Tests" begin
                #@testset "Entity constructor" begin
                    newEntity = EntityModule.Entity()
                    # @test 
newEntity != C_NULL && newEntity !== nothing
                #end

                #@testset "Entity addAnimator" begin
                    newEntity.addAnimator(newAnimator)
                    # @test 
newEntity.animator != C_NULL && newEntity.animator !== nothing
                #end

                # @testset "Entity addCircleCollider" begin
                    newEntity.addCircleCollider(newCircleCollider)
                    # @test 
newEntity.circleCollider != C_NULL && newEntity.circleCollider !== nothing
                    newEntity.circleCollider = C_NULL # Reset for next test
                #end

                #@testset "Entity addCollider" begin
                    println(typeof(newCollider))
                    newEntity.addCollider(newCollider)
                    # @test 
newEntity.collider != C_NULL && newEntity.collider !== nothing
                #end

                #@testset "Entity addRigidbody" begin
                    newEntity.addRigidbody(newRigidbody)
                    # @test 
newEntity.rigidbody != C_NULL && newEntity.rigidbody !== nothing
                #end

                #@testset "Entity addShape" begin
                    newEntity.addShape(newShape)
                    # @test 
newEntity.shape != C_NULL && newEntity.shape !== nothing
                #end
            #end

            #@testset "UI Tests" begin
                #@testset "ScreenButton constructor" begin
                    
                    newScreenButton = ScreenButtonModule.ScreenButton("ButtonUp.png", "ButtonDown.png", Vector2(256, 64), Vector2(), joinpath("FiraCode", "ttf", "FiraCode-Regular.ttf"), "test")
                    push!(MAIN.scene.screenButtons, newScreenButton)
                    # # @test 

                    newScreenButton != C_NULL && newScreenButton !== nothing
                #end

                # @testset "TextBox constructor" begin
                    newTextBox = TextBoxModule.TextBox("test", joinpath("FiraCode", "ttf", "FiraCode-Regular.ttf"), 64, Math.Vector2(), "test", true, true; isWorldEntity=true)
                    push!(MAIN.scene.textBoxes, newTextBox)
                    # # @test 

                    newTextBox != C_NULL && newTextBox !== nothing
                #end
            #end
            catch e
                rethrow(e)
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