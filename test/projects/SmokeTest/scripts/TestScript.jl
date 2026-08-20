module TestScriptModule
    # function conditional_using(pkg::Symbol)
    #     if !haskey(Base.loaded_modules, pkg)
    #         @eval using $(pkg)
    #     end
    # end
    # conditional_using(:JulGame)
    using JulGame
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
                newAnimation = AnimationModule.Animation(Math.Vector4[Math.Vector4(0,0,0,0)], 60)
                @testset "Animation constructor" begin
                    @test newAnimation != C_NULL && newAnimation !== nothing
                    @test newAnimation.animatedFPS == 60
                end

                @testset "Animator constructor" begin
                    newAnimator = AnimatorModule.Animator(AnimationModule.Animation[newAnimation])
                    @test newAnimator != C_NULL && newAnimator !== nothing
                end
            end

            newCollider = C_NULL
            @testset "Engine Collider Tests" begin
                @testset "Collider constructor" begin
                    newCollider = ColliderModule.Collider(true, false, false, Math.Vector2f(0,0), Math.Vector2f(1,1), "Default")
                    @test newCollider != C_NULL && newCollider !== nothing
                end
            end

            newRigidbody = C_NULL
            @testset "Engine Rigidbody Tests" begin
                @testset "Rigidbody constructor" begin
                    newRigidbody = RigidbodyModule.Rigidbody(1.0, true)
                    @test newRigidbody != C_NULL && newRigidbody !== nothing
                end
            end

            newShape = C_NULL
            @testset "Engine Shape Tests" begin
                @testset "Shape constructor" begin
                    newShape = ShapeModule.Shape(Math.Vector3(255,0,0), true, true, 0, Math.Vector2f(0,0), Math.Vector2f(0,0), Math.Vector2f(1,1), 255)
                    @test newShape != C_NULL && newShape !== nothing
                end
            end

            newEntity = C_NULL
            @testset "Engine Entity Tests" begin
                @testset "Entity constructor" begin
                    newEntity = JulGame.EntityModule.Entity()
                    @test newEntity != C_NULL && newEntity !== nothing
                    push!(MAIN.scene.entities, newEntity)
                end
                    
                @testset "Entity addAnimator" begin
                    JulGame.add_animator(newEntity, newAnimator)
                    @test newEntity.animator != C_NULL && newEntity.animator !== nothing
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

            @testset "Scene api tests" begin
                @test JulGame.SceneModule.get_entity_by_id(MAIN.scene, "test") === nothing
                @test JulGame.SceneModule.get_entity_by_id(MAIN.scene, newEntity.id) == newEntity
                @test JulGame.SceneModule.get_entity_by_name(MAIN.scene, "test") === nothing
                @test JulGame.SceneModule.get_entity_by_name(MAIN.scene, newEntity.name) == newEntity
                @test JulGame.SceneModule.get_entities_by_name(MAIN.scene, "test") == []
                @test JulGame.SceneModule.get_entities_by_name(MAIN.scene, newEntity.name) == [newEntity]
            end

            @testset "UI Tests" begin
                @testset "ScreenButton constructor" begin
                    
                    newScreenButton = ScreenButtonModule.ScreenButton(;
                        name="Name",
                        buttonUpSpritePath="ButtonUp.png",
                        buttonDownSpritePath="ButtonDown.png",
                        size=Math.Vector2(256, 64),
                        fontPath=joinpath("FiraCode-Regular.ttf"),
                        text="test"
                    )
                    push!(MAIN.scene.uiElements, newScreenButton)
                    @test newScreenButton != C_NULL && newScreenButton !== nothing
                end

                @testset "TextBox constructor" begin
                    newTextBox = TextBoxModule.TextBox("test";
                        fontPath=joinpath("FiraCode-Regular.ttf"),
                        fontSize=64,
                        position=Math.Vector2(),
                        name="test",
                        wrapWords=true,
                        isDynamic=true,
                        isWorldEntity=true
                    )
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
end # module