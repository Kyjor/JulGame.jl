module EntityModule
    using UUIDs
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
    import ..JulGame: Component
    import ..JulGame

    export Entity
    mutable struct Entity
        id::String
        animator::Union{InternalAnimator, Ptr{Nothing}}
        collider::Union{InternalCollider, Ptr{Nothing}}
        circleCollider::Union{InternalCircleCollider, Ptr{Nothing}}
        isActive::Bool
        name::String
        parent::Union{Entity, Ptr{Nothing}}
        persistentBetweenScenes::Bool
        rigidbody::Union{InternalRigidbody, Ptr{Nothing}}
        scripts::Vector{Any}
        shape::Union{InternalShape, Ptr{Nothing}}
        soundSource::Union{InternalSoundSource, Ptr{Nothing}}
        sprite::Union{InternalSprite, Ptr{Nothing}}
        transform::Transform

        function Entity(name::String = "New entity", id::String = JulGame.generate_uuid(), transform::Transform = Transform(), scripts::Vector = [])
            this = new()

            this.id = id
            this.name = name
            this.animator = C_NULL
            this.circleCollider = C_NULL
            this.collider = C_NULL
            this.isActive = true
            this.scripts = []
            this.transform = transform
            for script in scripts
                add_script(this, script)
            end
            this.shape = C_NULL
            this.soundSource = C_NULL
            this.sprite = C_NULL
            this.persistentBetweenScenes = false
            this.rigidbody = C_NULL
            this.parent = C_NULL

            return this
        end
    end

    function JulGame.add_script(this::Entity, script)
        #println(string("Adding script of type: ", typeof(script), " to entity named " , this.name))
        push!(this.scripts, script)
        script.parent = this
        try
            script.initialize()
        catch e
            @error string(e)
            Base.show_backtrace(stdout, catch_backtrace())
            rethrow(e)
        end
    end

    function JulGame.update(this::Entity, deltaTime)
        for script in this.scripts
            try
                # TODO: only call latest if in editor and in game mode
                Base.invokelatest(JulGame.update, script, deltaTime)
            catch e
                @error string(e)
                Base.show_backtrace(stdout, catch_backtrace())
                rethrow(e)
            end
        end
    end

    function JulGame.add_animator(this::Entity, animator::Animator = Animator(Animation[Animation(Vector4[Vector4(0,0,0,0)], Int32(60))]))
        if this.animator != C_NULL
            println("Animator already exists on entity named ", this.name)
            return
        end

        this.animator = InternalAnimator(this::Entity, animator.animations)
        if this.sprite != C_NULL 
            Component.set_sprite(this.animator, this.sprite)
        end

        return this.animator
    end

    function JulGame.add_collider(this::Entity, collider::Collider = Collider(true, false, false, Vector2f(0,0), Vector2f(1,1), "Default"))
        if this.collider != C_NULL || this.circleCollider != C_NULL
            println("Collider already exists on entity named ", this.name)
            return
        end
            
        this.collider = InternalCollider(this::Entity, collider.size::Vector2f, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.isPlatformerCollider::Bool, collider.enabled::Bool)

        return this.collider
    end

    function JulGame.add_circle_collider(this::Entity, collider::CircleCollider = CircleCollider(1.0, true, false, Vector2f(0,0), "Default"))
        if this.collider != C_NULL || this.circleCollider != C_NULL
            println("Collider already exists on entity named ", this.name)
            return
        end

        this.circleCollider = InternalCircleCollider(this::Entity, collider.diameter, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.enabled::Bool)

        return this.circleCollider
    end

    function JulGame.add_rigidbody(this::Entity, rigidbody::Rigidbody = Rigidbody())
        if this.rigidbody != C_NULL
            println("Rigidbody already exists on entity named ", this.name)
            return
        end

        this.rigidbody = InternalRigidbody(this::Entity; rigidbody.mass, rigidbody.useGravity)
        
        return this.rigidbody
    end

    function JulGame.add_sound_source(this::Entity, soundSource::SoundSource = SoundSource(Int32(-1), false, "", Int32(50)))
        if this.soundSource != C_NULL
            println("SoundSource already exists on entity named ", this.name)
            return
        end

        this.soundSource = InternalSoundSource(this::Entity, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic)

        return this.soundSource
    end

    function JulGame.create_sound_source(this::Entity, soundSource::SoundSource = SoundSource(Int32(-1), false, "", Int32(50)))
        newSoundSource::InternalSoundSource = InternalSoundSource(this::Entity, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic)
        return newSoundSource
    end

    function JulGame.add_sprite(this::Entity, isCreatedInEditor::Bool = false, sprite::Sprite = Sprite(Math.Vector3(255, 255, 255), C_NULL, false, "", true, 0, Math.Vector2f(0,0), Math.Vector2f(0,0), 0, -1, Math.Vector2f(0.5,0.5)))
        if this.sprite != C_NULL
            println("Sprite already exists on entity named ", this.name)
            return
        end

        this.sprite = InternalSprite(this::Entity, sprite.imagePath, sprite.crop, sprite.isFlipped, sprite.color, isCreatedInEditor; pixelsPerUnit=sprite.pixelsPerUnit, isWorldEntity=sprite.isWorldEntity, position=sprite.position, rotation=sprite.rotation, layer=sprite.layer, center=sprite.center)
        if this.animator != C_NULL
            Component.set_sprite(this.animator, this.sprite)
        end
        Component.initialize(this.sprite)

        return this.sprite
    end

    function JulGame.add_shape(this::Entity, shape::Shape = Shape(Math.Vector3(255,0,0), true, true, 0, Math.Vector2f(0,0), Math.Vector2f(0,0), Math.Vector2f(1,1)))
        if this.shape != C_NULL
            println("Shape already exists on entity named ", this.name)
            return
        end

        this.shape = InternalShape(this::Entity, shape.color, shape.isFilled, shape.offset, shape.size; isWorldEntity = shape.isWorldEntity, position = shape.position, layer = shape.layer)
        
        return this.shape
    end

    function JulGame.generate_uuid()
        return string(UUIDs.uuid4())
    end
end
