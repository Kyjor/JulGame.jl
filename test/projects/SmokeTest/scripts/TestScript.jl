using Test
mutable struct TestScript
    parent
    function TestScript()
        this = new()
        
        return this
    end
end

function JulGame.initialize(this::TestScript)
    try
        newAnimation = C_NULL
        newAnimator = C_NULL
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
        end

        newCircleCollider = C_NULL
        newCollider = C_NULL
        @testset "Engine Collider Tests" begin
            @testset "CircleCollider constructor" begin
                newCircleCollider = CircleColliderModule.CircleCollider(1.0, true, false, Math.Vector2f(0,0), "Default")
                @test newCircleCollider != C_NULL && newCircleCollider !== nothing
            end

            @testset "Collider constructor" begin
                newCollider = ColliderModule.Collider(true, false, false, Math.Vector2f(0,0), Math.Vector2f(1,1), "Default")
                @test newCollider != C_NULL && newCollider !== nothing
            end
        end

        newRigidbody = C_NULL
        @testset "Engine Rigidbody Tests" begin
            @testset "Rigidbody constructor" begin
                newRigidbody = RigidbodyModule.Rigidbody()
                @test newRigidbody != C_NULL && newRigidbody !== nothing
            end
        end

        newShape = C_NULL
        @testset "Engine Shape Tests" begin
            @testset "Shape constructor" begin
                newShape = ShapeModule.Shape(Math.Vector3(255,0,0), Math.Vector2f(1,1), true, true, Math.Vector2f(0,0), Math.Vector2f(0,0))
                @test newShape != C_NULL && newShape !== nothing
            end
        end

        newEntity = C_NULL
        @testset "Engine Entity Tests" begin
            @testset "Entity constructor" begin
                newEntity = EntityModule.Entity()
                @test newEntity != C_NULL && newEntity !== nothing
            end
                
            @testset "Entity addAnimator" begin
                JulGame.add_animator(newEntity, newAnimator)
                @test newEntity.animator != C_NULL && newEntity.animator !== nothing
            end

            @testset "Entity addCircleCollider" begin
                JulGame.add_circle_collider(newEntity, newCircleCollider)
                @test newEntity.circleCollider != C_NULL && newEntity.circleCollider !== nothing
                newEntity.circleCollider = C_NULL # Reset for next test
            end

            @testset "Entity addCollider" begin
                JulGame.add_collider(newEntity, newCollider)
                @test newEntity.collider != C_NULL && newEntity.collider !== nothing
            end

            @testset "Entity addRigidbody" begin
                JulGame.add_rigidbody(newEntity, newRigidbody)
                @test newEntity.rigidbody != C_NULL && newEntity.rigidbody !== nothing
            end

            @testset "Entity addShape" begin
                JulGame.add_shape(newEntity, newShape)
                @test newEntity.shape != C_NULL && newEntity.shape !== nothing
            end
        end

        @testset "UI Tests" begin
            @testset "ScreenButton constructor" begin
                
                newScreenButton = ScreenButtonModule.ScreenButton("Name", "ButtonUp.png", "ButtonDown.png", Vector2(256, 64), Vector2(), joinpath("FiraCode-Regular.ttf"), "test")
                push!(MAIN.scene.screenButtons, newScreenButton)
                push!(MAIN.scene.uiElements, newScreenButton)
                @test newScreenButton != C_NULL && newScreenButton !== nothing
            end

            @testset "TextBox constructor" begin
                newTextBox = TextBoxModule.TextBox("test", joinpath("FiraCode-Regular.ttf"), 64, Math.Vector2(), "test", true, true; isWorldEntity=true)
                push!(MAIN.scene.uiElements, newTextBox)
                @test newTextBox != C_NULL && newTextBox !== nothing
            end
        end
        catch e
            rethrow(e)
        end
end

function JulGame.update(this::TestScript, deltaTime)
end 

function JulGame.on_shutdown(this::TestScript)
end