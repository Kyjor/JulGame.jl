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
    using ..JulGame.Mesh3DModule
    using ..JulGame.SoftwareRenderer3DModule
    using ..JulGame.InteractionComponentsModule
    import ..JulGame: Component
    import ..JulGame
    import Ark

    export Entity

    mutable struct Entity <: JulGame.IEntity
        const _arkid::Ark.Entity
        id::String
        name::String
        isActive::Bool
        persistentBetweenScenes::Bool
        scripts::Vector{Any}
        parent::Union{Entity, Nothing}

        function Entity(name::String = "New entity", id::String = JulGame.generate_uuid(), transform::Transform = Transform(), scripts::Vector = []; clickEvents = Function[], forceClickCheck::Bool = false, ignoreInputEvents::Bool = false)
            # The interaction state lives in always-present Ark components, seeded here.
            arkid = Ark.new_entity!(JulGame.ECS_WORLD, (
                transform,
                ClickEvents(clickEvents), HoverEnterEvents(Function[]), HoverExitEvents(Function[]),
                IsHovered(false), ForceClickCheck(forceClickCheck), IgnoreInputEvents(ignoreInputEvents),
            ))
            this = new(arkid, id, name, true, false, Any[], nothing)
            Ark.get_components(JulGame.ECS_WORLD, arkid, (Transform,))[1].parent = this
            for script in scripts
                JulGame.add_script(this, script)
            end
            return this
        end
    end

    @inline ark_id(this::Entity) = getfield(this, :_arkid)

    @inline function _get_or_nothing(::Type{T}, this::Entity) where {T}
        w = JulGame.ECS_WORLD
        id = getfield(this, :_arkid)
        return Ark.has_components(w, id, (T,)) ? Ark.get_components(w, id, (T,))[1] : nothing
    end

    @inline function _get_transform(this::Entity)
        return Ark.get_components(JulGame.ECS_WORLD, getfield(this, :_arkid), (Transform,))[1]
    end

    @inline function _set_slot!(::Type{T}, this::Entity, value) where {T}
        w = JulGame.ECS_WORLD
        id = getfield(this, :_arkid)
        if value === nothing || value === C_NULL
            Ark.has_components(w, id, (T,)) && Ark.remove_components!(w, id, (T,))
        elseif Ark.has_components(w, id, (T,))
            Ark.set_components!(w, id, (value,))
        else
            Ark.add_components!(w, id, (value,))
        end
        return value
    end

    @inline function _set_transform!(this::Entity, value)
        Ark.set_components!(JulGame.ECS_WORLD, getfield(this, :_arkid), (value,))
        return value
    end

    @inline function _get_meta(::Type{T}, this::Entity) where {T}
        return Ark.get_components(JulGame.ECS_WORLD, getfield(this, :_arkid), (T,))[1].value
    end

    @inline function _set_meta!(::Type{T}, this::Entity, value) where {T}
        Ark.get_components(JulGame.ECS_WORLD, getfield(this, :_arkid), (T,))[1].value = value
        return value
    end

    Base.@constprop :aggressive function Base.getproperty(this::Entity, name::Symbol)
        if name === :transform
            return _get_transform(this)
        elseif name === :sprite
            return _get_or_nothing(InternalSprite, this)
        elseif name === :rigidbody
            return _get_or_nothing(InternalRigidbody, this)
        elseif name === :collider
            return _get_or_nothing(InternalCollider, this)
        elseif name === :circleCollider
            return _get_or_nothing(InternalCircleCollider, this)
        elseif name === :animator
            return _get_or_nothing(InternalAnimator, this)
        elseif name === :shape
            return _get_or_nothing(InternalShape, this)
        elseif name === :soundSource
            return _get_or_nothing(InternalSoundSource, this)
        elseif name === :mesh3d
            return _get_or_nothing(Mesh3D, this)
        elseif name === :softwareRenderer3d
            return _get_or_nothing(SoftwareRenderer3D, this)
        elseif name === :clickEvents
            return _get_meta(ClickEvents, this)
        elseif name === :hoverEnterEvents
            return _get_meta(HoverEnterEvents, this)
        elseif name === :hoverExitEvents
            return _get_meta(HoverExitEvents, this)
        elseif name === :isHovered
            return _get_meta(IsHovered, this)
        elseif name === :forceClickCheck
            return _get_meta(ForceClickCheck, this)
        elseif name === :ignoreInputEvents
            return _get_meta(IgnoreInputEvents, this)
        else
            return getfield(this, name)
        end
    end

    Base.@constprop :aggressive function Base.setproperty!(this::Entity, name::Symbol, value)
        if name === :transform
            return _set_transform!(this, value)
        elseif name === :sprite
            return _set_slot!(InternalSprite, this, value)
        elseif name === :rigidbody
            return _set_slot!(InternalRigidbody, this, value)
        elseif name === :collider
            return _set_slot!(InternalCollider, this, value)
        elseif name === :circleCollider
            return _set_slot!(InternalCircleCollider, this, value)
        elseif name === :animator
            return _set_slot!(InternalAnimator, this, value)
        elseif name === :shape
            return _set_slot!(InternalShape, this, value)
        elseif name === :soundSource
            return _set_slot!(InternalSoundSource, this, value)
        elseif name === :mesh3d
            return _set_slot!(Mesh3D, this, value)
        elseif name === :softwareRenderer3d
            return _set_slot!(SoftwareRenderer3D, this, value)
        elseif name === :clickEvents
            return _set_meta!(ClickEvents, this, value)
        elseif name === :hoverEnterEvents
            return _set_meta!(HoverEnterEvents, this, value)
        elseif name === :hoverExitEvents
            return _set_meta!(HoverExitEvents, this, value)
        elseif name === :isHovered
            return _set_meta!(IsHovered, this, value)
        elseif name === :forceClickCheck
            return _set_meta!(ForceClickCheck, this, value)
        elseif name === :ignoreInputEvents
            return _set_meta!(IgnoreInputEvents, this, value)
        else
            ty = fieldtype(Entity, name)
            return setfield!(this, name, value isa ty ? value : convert(ty, value))
        end
    end

    function JulGame.free_entity!(this::Entity)
        id = getfield(this, :_arkid)
        Ark.is_alive(JulGame.ECS_WORLD, id) && Ark.remove_entity!(JulGame.ECS_WORLD, id)
        return nothing
    end

    function JulGame.add_script(this::Entity, script)
        @debug(string("Adding script of type: ", typeof(script), " to entity named " , this.name))
        push!(this.scripts, script)
        script.parent = this
        try
            JulGame.initialize(script)
        catch e
            @error string(e)
            Base.show_backtrace(stdout, catch_backtrace())
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
        if this.animator !== nothing
            println("Animator already exists on entity named ", this.name)
            return
        end

        this.animator = InternalAnimator(this::Entity, animator.animations)
        if this.sprite !== nothing 
            this.animator.sprite = this.sprite
        end

        return this.animator
    end

    function JulGame.add_collider(this::Entity, collider::Collider = Collider(true, false, false, Vector2f(0,0), Vector2f(1,1), "Default"))
        if this.collider !== nothing || this.circleCollider !== nothing
            println("Collider already exists on entity named ", this.name)
            return
        end
            
        this.collider = InternalCollider(this::Entity, collider.size::Vector2f, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.isPlatformerCollider::Bool, collider.enabled::Bool)

        return this.collider
    end

    function JulGame.add_circle_collider(this::Entity, collider::CircleCollider = CircleCollider(1.0, true, false, Vector2f(0,0), "Default"))
        if this.collider !== nothing || this.circleCollider !== nothing
            println("Collider already exists on entity named ", this.name)
            return
        end

        this.circleCollider = InternalCircleCollider(this::Entity, collider.diameter, collider.offset::Vector2f, collider.tag::String, collider.isTrigger::Bool, collider.enabled::Bool)

        return this.circleCollider
    end

    function JulGame.add_rigidbody(this::Entity, rigidbody::Rigidbody = Rigidbody(1.0, true))
        if this.rigidbody !== nothing
            println("Rigidbody already exists on entity named ", this.name)
            return
        end

        this.rigidbody = InternalRigidbody(this::Entity, rigidbody.mass, rigidbody.useGravity)
        
        return this.rigidbody
    end

    function JulGame.add_sound_source(this::Entity, soundSource::SoundSource = SoundSource(-1, false, "", false, 50))
        if this.soundSource !== nothing
            println("SoundSource already exists on entity named ", this.name)
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
        if this.sprite !== nothing
            println("Sprite already exists on entity named ", this.name)
            return
        end

        this.sprite = InternalSprite(this::Entity, sprite.imagePath, sprite.crop, sprite.isFlipped, sprite.color, isCreatedInEditor; pixelsPerUnit=sprite.pixelsPerUnit, position=sprite.position, rotation=sprite.rotation, layer=sprite.layer, center=sprite.center, anchor=sprite.anchor, offset=sprite.offset, isStatic=sprite.isStatic)
        if this.animator !== nothing
            this.animator.sprite = this.sprite
        end
        Component.initialize(this.sprite)

        return this.sprite
    end

    function JulGame.add_shape(this::Entity, shape::Shape = Shape(Math.Vector3(255,0,0), true, true, 0, Math.Vector2f(0,0), Math.Vector2f(0,0), Math.Vector2f(1,1), 255))
        if this.shape !== nothing
            println("Shape already exists on entity named ", this.name)
            return
        end

        this.shape = InternalShape(this::Entity, shape.color, shape.isFilled, shape.offset, shape.size; isWorldEntity = shape.isWorldEntity, position = shape.position, layer = shape.layer, alpha = shape.alpha)
        
        return this.shape
    end

    function JulGame.add_mesh3d(this::Entity, mesh3d::Mesh3D = Mesh3D())
        if this.mesh3d !== nothing
            println("Mesh3D already exists on entity named ", this.name)
            return
        end

        this.mesh3d = mesh3d
        mesh3d.parent = this
        Component.initialize(mesh3d, JulGame.MAIN)

        return this.mesh3d
    end

    function JulGame.add_software_renderer3d(this::Entity, softwareRenderer3d::SoftwareRenderer3D = SoftwareRenderer3D())
        if this.softwareRenderer3d !== nothing
            println("SoftwareRenderer3D already exists on entity named ", this.name)
            return
        end

        this.softwareRenderer3d = softwareRenderer3d
        softwareRenderer3d.parent = this
        Component.initialize(softwareRenderer3d, JulGame.MAIN)

        return this.softwareRenderer3d
    end

    function JulGame.duplicate(this::Entity, id::String = JulGame.generate_uuid())
        newEntity = Entity(this.name, id, Component.duplicate(this.transform, nothing))
        if this.animator !== nothing
            newEntity.animator = Component.duplicate(this.animator, newEntity)
        end
        if this.collider !== nothing
            newEntity.collider = Component.duplicate(this.collider, newEntity)
        end
        # if this.circleCollider !== nothing
        #     newEntity.circleCollider = Component.duplicate(this.circleCollider, newEntity)
        # end
        newEntity.isActive = this.isActive
        # if this.mesh3d !== nothing
        #     newEntity.mesh3d = Component.duplicate(this.mesh3d, newEntity)
        # end
        if this.softwareRenderer3d !== nothing
            newEntity.softwareRenderer3d = this.softwareRenderer3d
        end
        newEntity.persistentBetweenScenes = this.persistentBetweenScenes
        if this.rigidbody !== nothing
            newEntity.rigidbody = Component.duplicate(this.rigidbody, newEntity)
        end
        # for script in this.scripts
        #     JulGame.add_script(newEntity, script)
        # end
        if this.shape !== nothing
            newEntity.shape = Component.duplicate(this.shape, newEntity)
        end
        if this.soundSource !== nothing
            newEntity.soundSource = Component.duplicate(this.soundSource, newEntity)
        end
        if this.sprite !== nothing
            newEntity.sprite = Component.duplicate(this.sprite, newEntity)
        end
        
        push!(JulGame.MAIN.scene.entities, newEntity)
        return newEntity
    end

    function JulGame.generate_uuid()
        return string(UUIDs.uuid4())
    end
end
