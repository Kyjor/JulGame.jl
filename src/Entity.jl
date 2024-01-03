module EntityModule
    using ..JulGame.AnimationModule
    using ..JulGame.AnimatorModule
    using ..JulGame.ColliderModule
    using ..JulGame.CircleColliderModule
    using ..JulGame.Math
    using ..JulGame.RigidbodyModule
    using ..JulGame.ShapeModule
    using ..JulGame.SoundSourceModule
    using ..JulGame.SpriteModule
    using ..JulGame.TransformModule

    export Entity
    mutable struct Entity
        id::Int
        animator::Union{InternalAnimator, Ptr{Nothing}}
        collider::Union{InternalCollider, Ptr{Nothing}}
        circleCollider::Union{InternalCircleCollider, Ptr{Nothing}}
        rigidbody::Union{InternalRigidbody, Ptr{Nothing}}
        shape::Union{InternalShape, Ptr{Nothing}}
        soundSource::Union{InternalSoundSource, Ptr{Nothing}}
        sprite::Union{InternalSprite, Ptr{Nothing}}
        transform::Transform
        isActive::Bool
        name::String
        persistentBetweenScenes::Bool
        scripts::Vector{Any}
        
        function Entity(name::String = "New entity", transform::Transform = Transform(), scripts::Vector = [])
            this = new()

            this.id = 1
            this.name = name
            this.animator = C_NULL
            this.circleCollider = C_NULL
            this.collider = C_NULL
            this.isActive = true
            this.scripts = []
            this.transform = transform
            for script in scripts
                this.addScript(script)
            end
            this.shape = C_NULL
            this.soundSource = C_NULL
            this.sprite = C_NULL
            this.persistentBetweenScenes = false
            this.rigidbody = C_NULL

            return this
        end
    end

    function Base.getproperty(this::Entity, s::Symbol)
        if s == :addScript
            function(script)
                #println(string("Adding script of type: ", typeof(script), " to entity named " , this.name))
                push!(this.scripts, script)
                script.setParent(this)
                try
                    script.initialize()
                catch e
                    println(e)
                    Base.show_backtrace(stdout, catch_backtrace())
                end
            end
        elseif s == :update
            function(deltaTime)
                for script in this.scripts
                    try
                        script.update(deltaTime)
                    catch e
                        println(e)
                        Base.show_backtrace(stdout, catch_backtrace())
                    end
                end
            end
        elseif s == :addAnimator
            function(animator::Animator = Animator(Animation[Animation(Vector4[Vector4(0,0,0,0)], 60)]))
                if this.animator != C_NULL
                    println("Animator already exists on entity named ", this.name)
                    return
                end

                this.animator = InternalAnimator(this::Entity, animator.animations)
                if this.sprite != C_NULL 
                    this.animator.setSprite(this.sprite)
                end

                return this.animator
            end
        elseif s == :addCollider
            function(collider::Collider = Collider(true, false, false, Vector2f(0,0), Vector2f(1,1), "Default"))
                if this.collider != C_NULL || this.circleCollider != C_NULL
                    println("Collider already exists on entity named ", this.name)
                    return
                end
                    
                this.collider = InternalCollider(this::Entity, collider.size::Vector2f, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.isPlatformerCollider::Bool, collider.enabled::Bool)

                return this.collider
            end
        elseif s == :addCircleCollider
            function(collider::CircleCollider = CircleCollider(1.0, true, false, Vector2f(0,0), "Default"))
                if this.collider != C_NULL || this.circleCollider != C_NULL
                    println("Collider already exists on entity named ", this.name)
                    return
                end

                this.circleCollider = InternalCircleCollider(this::Entity, collider.diameter, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.enabled::Bool)

                return this.circleCollider
            end
        elseif s == :addRigidbody
            function(rigidbody::Rigidbody = Rigidbody(1.0))
                if this.rigidbody != C_NULL
                    println("Rigidbody already exists on entity named ", this.name)
                    return
                end

                this.rigidbody = InternalRigidbody(this::Entity, rigidbody.mass)

                return this.rigidbody
            end
        elseif s == :addSoundSource
            function(soundSource::SoundSource = SoundSource(-1, false, "", 50))
                if this.soundSource != C_NULL
                    println("SoundSource already exists on entity named ", this.name)
                    return
                end

                this.soundSource = InternalSoundSource(this::Entity, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic)

                return this.soundSource
            end
        elseif s == :createSoundSource
            function(soundSource::SoundSource = SoundSource(-1, false, "", 50))
                newSoundSource::InternalSoundSource = InternalSoundSource(this::Entity, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic)

                return newSoundSource
            end
        elseif s == :addSprite
            function(isCreatedInEditor::Bool = false, sprite::Sprite = Sprite(Math.Vector3(255, 255, 255), C_NULL, false, "", true, 0, Math.Vector2f(0,0), Math.Vector2f(0,0), 0, -1))
                if this.sprite != C_NULL
                    println("Sprite already exists on entity named ", this.name)
                    return
                end

                this.sprite = InternalSprite(this::Entity, sprite.imagePath, sprite.crop, sprite.isFlipped, sprite.color, isCreatedInEditor; pixelsPerUnit=sprite.pixelsPerUnit, isWorldEntity=sprite.isWorldEntity, position=sprite.position, rotation=sprite.rotation, layer=sprite.layer)
                if this.animator != C_NULL
                    this.animator.setSprite(this.sprite)
                end
                this.sprite.initialize()

                return this.sprite
            end
        elseif s == :addShape
            function(shape::Shape = Shape(Math.Vector3(255,0,0), Math.Vector2f(1,1), true, false, Math.Vector2f(0,0), Math.Vector2f(0,0)))
                if this.shape != C_NULL
                    println("Shape already exists on entity named ", this.name)
                    return
                end

                this.shape = InternalShape(this::Entity, shape.dimensions, shape.color, shape.isFilled, shape.offset; isWorldEntity = shape.isWorldEntity, position = shape.position)
                
                return this.shape
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
                Base.show_backtrace(stdout, catch_backtrace())
                println("")
                println("")
                println("")
            end
        end
    end
end