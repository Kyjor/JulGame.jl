module EntityModule
    using JSON3
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
    using ..JulGame.Mesh3DModule
    using ..JulGame.SoftwareRenderer3DModule
    import ..JulGame: Component
    import ..JulGame

    export Entity
    mutable struct Entity <: JulGame.IEntity
        id::String
        name::String
        isActive::Bool
        persistentBetweenScenes::Bool
        transform::Transform
        scripts::Vector{Union{JulGame.Script, JSON3.Object}}
        parent::Union{Entity, Nothing}
        animator::Union{InternalAnimator, Ptr{Nothing}}
        collider::Union{InternalCollider, Ptr{Nothing}}
        circleCollider::Union{InternalCircleCollider, Ptr{Nothing}}
        mesh3d::Union{Mesh3D, Ptr{Nothing}}
        softwareRenderer3d::Union{SoftwareRenderer3D, Ptr{Nothing}}
        rigidbody::Union{InternalRigidbody, Ptr{Nothing}}
        shape::Union{InternalShape, Ptr{Nothing}}
        soundSource::Union{InternalSoundSource, Ptr{Nothing}}
        sprite::Union{InternalSprite, Ptr{Nothing}}

        clickEvents::Vector{Function}
        hoverEnterEvents::Vector{Function}
        hoverExitEvents::Vector{Function}
        isHovered::Bool
        forceClickCheck::Bool
        ignoreInputEvents::Bool

        function Entity(
            name::String,
            id::String,
            transform::Transform;
            clickEvents::Vector{Function} = Function[],
            forceClickCheck::Bool = false,
            ignoreInputEvents::Bool = false,
        )
            this = new()

            this.id = id
            this.name = name
            this.animator = C_NULL
            this.circleCollider = C_NULL
            this.collider = C_NULL
            this.isActive = true
            this.mesh3d = C_NULL
            this.softwareRenderer3d = C_NULL
            this.scripts = Union{JulGame.Script, JSON3.Object}[]
            this.transform = transform
            this.transform.parent = this
            this.shape = C_NULL
            this.soundSource = C_NULL
            this.sprite = C_NULL
            this.persistentBetweenScenes = false
            this.rigidbody = C_NULL
            this.parent = nothing
            this.isHovered = false
            this.clickEvents = clickEvents
            this.hoverEnterEvents = Function[]
            this.hoverExitEvents = Function[]
            this.forceClickCheck = forceClickCheck
            this.ignoreInputEvents = ignoreInputEvents

            return this
        end
    end

    function _attach_scripts!(this::Entity, scripts::Vector)
        isempty(scripts) && return this
        for script in scripts
            @debug(string("Adding script of type: ", typeof(script), " to entity named ", this.name))
            push!(this.scripts, script)
            script.parent = this
            try
                JulGame.initialize(script)
            catch e
                @error sprint(showerror, e)
            end
        end
        return this
    end

    Entity(; kwargs...) = Entity("New entity", JulGame.generate_uuid(), Transform(); kwargs...)
    Entity(name::String; kwargs...) = Entity(name, JulGame.generate_uuid(), Transform(); kwargs...)
    Entity(name::String, id::String; kwargs...) = Entity(name, id, Transform(); kwargs...)

    function Entity(name::String, id::String, scripts::Vector; kwargs...)
        return _attach_scripts!(Entity(name, id; kwargs...), scripts)
    end

    function Entity(name::String, id::String, transform::Transform, scripts::Vector; kwargs...)
        return _attach_scripts!(Entity(name, id, transform; kwargs...), scripts)
    end

    function JulGame.add_script(this::Entity, script)
        @debug(string("Adding script of type: ", typeof(script), " to entity named " , this.name))
        push!(this.scripts, script)
        script.parent = this
        try
            JulGame.initialize(script)
        catch e
            @error sprint(showerror, e)
        end
    end

    function JulGame.update(this::Entity, deltaTime)
        if !this.isActive 
            this.isHovered = false
            return
        end

        for script in this.scripts
            try
                Base.invokelatest(JulGame.update, script, deltaTime) 
            catch e
                JulGame.ErrorLoggingModule.log_error(JulGame.MAIN.errorLogger, string(e), current_exceptions())
            end
        end
    end

    function JulGame.add_animator(this::Entity, animator::Animator = Animator(Animation[Animation(Vector4[Vector4(0,0,0,0)], 60)]))
        if this.animator != C_NULL
            return
        end

        this.animator = InternalAnimator(this::Entity, animator.animations)
        if this.sprite != C_NULL 
            this.animator.sprite = this.sprite
        end

        return this.animator
    end

    function JulGame.add_collider(this::Entity, collider::Collider = Collider(true, false, false, Vector2f(0,0), Vector2f(1,1), "Default"))
        if this.collider != C_NULL || this.circleCollider != C_NULL
            return
        end
            
        setfield!(this, :collider, InternalCollider(this::Entity, collider.size::Vector2f, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.isPlatformerCollider::Bool, collider.enabled::Bool))

        return this.collider
    end

    function JulGame.add_circle_collider(this::Entity, collider::CircleCollider = CircleCollider(1.0, true, false, Vector2f(0,0), "Default"))
        if this.collider != C_NULL || this.circleCollider != C_NULL
            return
        end

        this.circleCollider = InternalCircleCollider(this::Entity, collider.diameter, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.enabled::Bool)

        return this.circleCollider
    end

    function JulGame.add_rigidbody(this::Entity, rigidbody::Rigidbody = Rigidbody())
        if this.rigidbody != C_NULL
            return
        end

        this.rigidbody = InternalRigidbody(this::Entity; rigidbody.mass, rigidbody.useGravity)
        
        return this.rigidbody
    end

    function JulGame.add_sound_source(this::Entity, soundSource::SoundSource = SoundSource(-1, false, "", false, 50))
        if this.soundSource != C_NULL
            return
        end

        this.soundSource = InternalSoundSource(this::Entity, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)

        return this.soundSource
    end

    function JulGame.create_sound_source(this::Entity, soundSource::SoundSource = SoundSource(-1, false, "", false, 50))
        newSoundSource::InternalSoundSource = InternalSoundSource(this::Entity, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)
        return newSoundSource
    end

    function JulGame.add_sprite(this::Entity, isCreatedInEditor::Bool = false, sprite::Sprite = Sprite((255, 255, 255, 255), C_NULL, false, "", 0, Math.Vector2f(0,0), Math.Vector2f(0,0), 0, -1, Math.Vector2f(0.5,0.5), :center, false))
        if this.sprite != C_NULL
            return
        end

        this.sprite = InternalSprite(this::Entity, sprite.imagePath, sprite.crop, sprite.isFlipped, sprite.color, isCreatedInEditor; pixelsPerUnit=sprite.pixelsPerUnit, position=sprite.position, rotation=sprite.rotation, layer=sprite.layer, center=sprite.center, anchor=sprite.anchor, offset=sprite.offset, isStatic=sprite.isStatic)
        if this.animator != C_NULL
            this.animator.sprite = this.sprite
        end
        Component.initialize(this.sprite)

        return this.sprite
    end

    function JulGame.add_shape(this::Entity, shape::Shape = Shape(Math.Vector3(255,0,0), true, true, 0, Math.Vector2f(0,0), Math.Vector2f(0,0), Math.Vector2f(1,1), 255))
        if this.shape != C_NULL
            return
        end

        this.shape = InternalShape(this::Entity, shape.color, shape.isFilled, shape.offset, shape.size; isWorldEntity = shape.isWorldEntity, position = shape.position, layer = shape.layer, alpha = shape.alpha)
        
        return this.shape
    end

    function JulGame.add_mesh3d(this::Entity, mesh3d::Mesh3D = Mesh3D())
        if this.mesh3d != C_NULL
            return
        end

        this.mesh3d = mesh3d
        mesh3d.parent = this
        Component.initialize(mesh3d, JulGame.MAIN)

        return this.mesh3d
    end

    function JulGame.add_software_renderer3d(this::Entity, softwareRenderer3d::SoftwareRenderer3D = SoftwareRenderer3D())
        if this.softwareRenderer3d != C_NULL
            return
        end

        this.softwareRenderer3d = softwareRenderer3d
        softwareRenderer3d.parent = this
        Component.initialize(softwareRenderer3d, JulGame.MAIN)

        return this.softwareRenderer3d
    end

    function JulGame.duplicate(this::Entity, id::String = JulGame.generate_uuid())
        newEntity = Entity(this.name, id, Component.duplicate(this.transform, nothing))
        # animator::Union{InternalAnimator, Ptr{Nothing}}
        if this.animator != C_NULL && this.animator !== nothing
            newEntity.animator = Component.duplicate(this.animator, newEntity)
        end
        # collider::Union{InternalCollider, Ptr{Nothing}}
        if this.collider != C_NULL && this.collider !== nothing
            newEntity.collider = Component.duplicate(this.collider, newEntity)
        end
        # circleCollider::Union{InternalCircleCollider, Ptr{Nothing}}
        # if this.circleCollider != C_NULL && this.circleCollider !== nothing
        #     newEntity.circleCollider = Component.duplicate(this.circleCollider, newEntity)
        # end
        # isActive::Bool
        newEntity.isActive = this.isActive
        # mesh3d::Union{Mesh3D, Ptr{Nothing}}
        if this.mesh3d != C_NULL && this.mesh3d !== nothing
            #newEntity.mesh3d = Component.duplicate(this.mesh3d, newEntity)
        end
        # softwareRenderer3d::Union{SoftwareRenderer3D, Ptr{Nothing}}
        if this.softwareRenderer3d != C_NULL && this.softwareRenderer3d !== nothing
            newEntity.softwareRenderer3d = this.softwareRenderer3d
        end
        # persistentBetweenScenes::Bool
        newEntity.persistentBetweenScenes = this.persistentBetweenScenes
        # rigidbody::Union{InternalRigidbody, Ptr{Nothing}}
        if this.rigidbody != C_NULL && this.rigidbody !== nothing
            newEntity.rigidbody = Component.duplicate(this.rigidbody, newEntity)
        end
        # scripts::Vector{Any}
        # for script in this.scripts
        #     JulGame.add_script(newEntity, script)
        # end
        # shape::Union{InternalShape, Ptr{Nothing}}
        if this.shape != C_NULL && this.shape !== nothing
            newEntity.shape = Component.duplicate(this.shape, newEntity)
        end
        # soundSource::Union{InternalSoundSource, Ptr{Nothing}}
        if this.soundSource != C_NULL && this.soundSource !== nothing
            newEntity.soundSource = Component.duplicate(this.soundSource, newEntity)
        end
        # sprite::Union{InternalSprite, Ptr{Nothing}}
        if this.sprite != C_NULL && this.sprite !== nothing
            newEntity.sprite = Component.duplicate(this.sprite, newEntity)
        end
        
        push!(JulGame.MAIN.scene.entities, newEntity)
        return newEntity
    end

    function JulGame.generate_uuid()
        return string(UUIDs.uuid4())
    end
end
