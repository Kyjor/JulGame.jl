
    // using UUIDs
    // using ..JulGame.AnimationModule
    // using ..JulGame.AnimatorModule
    // using ..JulGame.ColliderModule
    // using ..JulGame.CircleColliderModule
    // using ..JulGame.Math
    // using ..JulGame.RigidbodyModule
    // using ..JulGame.ShapeModule
    // using ..JulGame.SoundSourceModule
    // using ..JulGame.SpriteModule
    // using ..JulGame.TransformModule
    // using ..JulGame.Mesh3DModule
    // using ..JulGame.SoftwareRenderer3DModule
    // import ..JulGame: Component
    // import ..JulGame

    
    class Entity extends JulGame.IEntity {
        id: string
        name: string
        isActive: boolean
        persistentBetweenScenes: boolean
        transform: Transform
        scripts: any[]
        parent: Entity | Nothing
        animator: InternalAnimator | null
        collider: InternalCollider | null
        circleCollider: InternalCircleCollider | null
        mesh3d: Mesh3D | null
        softwareRenderer3d: SoftwareRenderer3D | null
        rigidbody: InternalRigidbody | null
        shape: InternalShape | null
        soundSource: InternalSoundSource | null
        sprite: InternalSprite | null

        clickEvents: Function[]
        hoverEnterEvents: Function[]
        hoverExitEvents: Function[]
        isHovered: boolean
        forceClickCheck: boolean
        ignoreInputEvents: boolean

        function Entity(name: string = "New entity",  id: string = JulGame.generate_uuid(), transform::Transform = Transform(), scripts::Vector = []; clickEvents = Function[], forceClickCheck: boolean = false, ignoreInputEvents: boolean = false)
            

            this.id = id
            this.name = name
            this.animator = null
            this.circleCollider = null
            this.collider = null
            this.isActive = true
            this.mesh3d = null
            this.softwareRenderer3d = null
            this.scripts = []
            this.transform = transform
            this.transform.parent = this
            for (const script of scripts) {
                JulGame.add_script(this, script)
            }
            this.shape = null
            this.soundSource = null
            this.sprite = null
            this.persistentBetweenScenes = false
            this.rigidbody = null
            this.parent = nothing
            this.isHovered = false
            this.clickEvents = clickEvents
            this.hoverEnterEvents = Function[]
            this.hoverExitEvents = Function[]
            this.forceClickCheck = forceClickCheck
            this.ignoreInputEvents = ignoreInputEvents

        }
    }

    function JulGame.add_script(this: Entity,  script) {
        @debug(string("Adding script of type: ", typeof(script), " to entity named " , this.name))
        this.scripts.push(script)
        script.parent = this
        try
            JulGame.initialize(script)
        catch e
            @error string(e)
            Base.show_backtrace(stdout, catch_backtrace())
        }
    }

    function JulGame.update(this: Entity,  deltaTime) {
        if (!this.isActive) {
            this.isHovered = false
            return
        }

        for (const script of this.scripts) {
            try
                Base.invokelatest(JulGame.update, script, deltaTime) 
            catch e
                JulGame.ErrorLoggingModule.log_error(JulGame.MAIN.errorLogger, string(e), current_exceptions())
            }
        }
    }

    function JulGame.add_animator(this: Entity,  animator: Animator = Animator(Animation[JulGameAnimation(Vector4[Vector4(0, 0, 0, 0)], 60)]))
        if (this.animator != null) {
            println("Animator already exists on entity named ", this.name)
            return
        }

        this.animator = InternalAnimator(this::Entity, animator.animations)
        if (this.sprite != null) {
            this.animator.sprite = this.sprite
        }

        return this.animator
    }

    function JulGame.add_collider(this: Entity,  collider: Collider = Collider(true,  false,  false,  Vector2f(0, 0), Vector2f(1,1), "Default"))
        if (this.collider != null || this.circleCollider != null) {
            println("Collider already exists on entity named ", this.name)
            return
        }
            
        this.collider = InternalCollider(this::Entity, collider.size::Vector2f, collider.offset::Vector2f, collider.tag: string, collider.isTrigger: boolean, collider.isPlatformerCollider: boolean, collider.enabled: boolean)

        return this.collider
    }

    function JulGame.add_circle_collider(this: Entity,  collider: CircleCollider = CircleCollider(1.0,  true,  false,  Vector2f(0, 0), "Default"))
        if (this.collider != null || this.circleCollider != null) {
            println("Collider already exists on entity named ", this.name)
            return
        }

        this.circleCollider = InternalCircleCollider(this::Entity, collider.diameter, collider.offset::Vector2f, collider.tag: string, collider.isTrigger: boolean, collider.enabled: boolean)

        return this.circleCollider
    }

    function JulGame.add_rigidbody(this: Entity,  rigidbody: Rigidbody = Rigidbody())
        if (this.rigidbody != null) {
            println("Rigidbody already exists on entity named ", this.name)
            return
        }

        this.rigidbody = InternalRigidbody(this::Entity; rigidbody.mass, rigidbody.useGravity)
        
        return this.rigidbody
    }

    function JulGame.add_sound_source(this: Entity,  soundSource: SoundSource = SoundSource(-1,  false,  "",  false,  50))
        if (this.soundSource != null) {
            println("SoundSource already exists on entity named ", this.name)
            return
        }

        this.soundSource = InternalSoundSource(this::Entity, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)

        return this.soundSource
    }

    function JulGame.create_sound_source(this: Entity,  soundSource: SoundSource = SoundSource(-1,  false,  "",  false,  50))
        newSoundSource: InternalSoundSource = InternalSoundSource(this::Entity, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)
        return newSoundSource
    }

    function JulGame.add_sprite(this: Entity,  isCreatedInEditor: boolean = false,  sprite: Sprite = Sprite((255,  255,  255,  255), null, false, "", 0, Math.Vector2f(0,0), Math.Vector2f(0,0), 0, -1, Math.Vector2f(0.5,0.5), :center, false))
        if (this.sprite != null) {
            println("Sprite already exists on entity named ", this.name)
            return
        }

        this.sprite = InternalSprite(this::Entity, sprite.imagePath, sprite.crop, sprite.isFlipped, sprite.color, isCreatedInEditor; pixelsPerUnit=sprite.pixelsPerUnit, position=sprite.position, rotation=sprite.rotation, layer=sprite.layer, center=sprite.center, anchor=sprite.anchor, offset=sprite.offset, isStatic=sprite.isStatic)
        if (this.animator != null) {
            this.animator.sprite = this.sprite
        }
        Component_initialize(this.sprite)

        return this.sprite
    }

    function JulGame.add_shape(this: Entity,  shape: Shape = Shape(Math.Vector3(255, 0, 0), true, true, 0, Math.Vector2f(0,0), Math.Vector2f(0,0), Math.Vector2f(1,1), 255))
        if (this.shape != null) {
            println("Shape already exists on entity named ", this.name)
            return
        }

        this.shape = InternalShape(this::Entity, shape.color, shape.isFilled, shape.offset, shape.size; isWorldEntity = shape.isWorldEntity, position = shape.position, layer = shape.layer, alpha = shape.alpha)
        
        return this.shape
    }

    function JulGame.add_mesh3d(this: Entity,  mesh3d: Mesh3D = Mesh3D())
        if (this.mesh3d != null) {
            println("Mesh3D already exists on entity named ", this.name)
            return
        }

        this.mesh3d = mesh3d
        mesh3d.parent = this
        Component_initialize(mesh3d, JulGame.MAIN)

        return this.mesh3d
    }

    function JulGame.add_software_renderer3d(this: Entity,  softwareRenderer3d: SoftwareRenderer3D = SoftwareRenderer3D())
        if (this.softwareRenderer3d != null) {
            println("SoftwareRenderer3D already exists on entity named ", this.name)
            return
        }

        this.softwareRenderer3d = softwareRenderer3d
        softwareRenderer3d.parent = this
        Component_initialize(softwareRenderer3d, JulGame.MAIN)

        return this.softwareRenderer3d
    }

    function JulGame.duplicate(this: Entity,  id: string = JulGame.generate_uuid())
        let newEntity = Entity(this.name, id, Component_duplicate(this.transform, nothing))
        // animator: InternalAnimator | null
        if (this.animator != null && this.animator !== nothing) {
            newEntity.animator = Component_duplicate(this.animator, newEntity)
        }
        // collider: InternalCollider | null
        if (this.collider != null && this.collider !== nothing) {
            newEntity.collider = Component_duplicate(this.collider, newEntity)
        }
        // circleCollider: InternalCircleCollider | null
        // if this.circleCollider != null && this.circleCollider !== nothing
        //     newEntity.circleCollider = Component_duplicate(this.circleCollider, newEntity)
        // }
        // isActive: boolean
        newEntity.isActive = this.isActive
        // mesh3d: Mesh3D | null
        if (this.mesh3d != null && this.mesh3d !== nothing) {
            //newEntity.mesh3d = Component_duplicate(this.mesh3d, newEntity)
        }
        // softwareRenderer3d: SoftwareRenderer3D | null
        if (this.softwareRenderer3d != null && this.softwareRenderer3d !== nothing) {
            newEntity.softwareRenderer3d = this.softwareRenderer3d
        }
        // persistentBetweenScenes: boolean
        newEntity.persistentBetweenScenes = this.persistentBetweenScenes
        // rigidbody: InternalRigidbody | null
        if (this.rigidbody != null && this.rigidbody !== nothing) {
            newEntity.rigidbody = Component_duplicate(this.rigidbody, newEntity)
        }
        // scripts: any[]
        // for script in this.scripts
        //     JulGame.add_script(newEntity, script)
        // }
        // shape: InternalShape | null
        if (this.shape != null && this.shape !== nothing) {
            newEntity.shape = Component_duplicate(this.shape, newEntity)
        }
        // soundSource: InternalSoundSource | null
        if (this.soundSource != null && this.soundSource !== nothing) {
            newEntity.soundSource = Component_duplicate(this.soundSource, newEntity)
        }
        // sprite: InternalSprite | null
        if (this.sprite != null && this.sprite !== nothing) {
            newEntity.sprite = Component_duplicate(this.sprite, newEntity)
        }
        
        JulGame.MAIN.scene.entities.push(newEntity)
        return newEntity
    }

    function JulGame.generate_uuid() {
        return string(UUIDs.uuid4())
    }
