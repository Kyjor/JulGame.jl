export {}

    // using UUIDs
    // using ..(globalThis as any).JulGame.AnimationModule
    // using ..(globalThis as any).JulGame.AnimatorModule
    // using ..(globalThis as any).JulGame.ColliderModule
    // using ..(globalThis as any).JulGame.CircleColliderModule
    // using ..(globalThis as any).JulGame.Math
    // using ..(globalThis as any).JulGame.RigidbodyModule
    // using ..(globalThis as any).JulGame.ShapeModule
    // using ..(globalThis as any).JulGame.SoundSourceModule
    // using ..(globalThis as any).JulGame.SpriteModule
    // using ..(globalThis as any).JulGame.TransformModule
    // using ..(globalThis as any).JulGame.Mesh3DModule
    // using ..(globalThis as any).JulGame.SoftwareRenderer3DModule
    // import ..JulGame: Component
    // import ..JulGame

    
    class Entity extends (globalThis as any).JulGame.IEntity {
        id: string
        name: string
        isActive: boolean
        persistentBetweenScenes: boolean
        transform: ITransform
        scripts: any[]
        parent: Entity | null
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

        function Entity(name: string = "New entity",  id: string = (globalThis as any).JulGame.generate_uuid(), transform: ITransform = Transform(), scripts = []; clickEvents = Function[], forceClickCheck: boolean = false, ignoreInputEvents: boolean = false)
            

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
                (globalThis as any).JulGame.add_script(this, script)
            }
            this.shape = null
            this.soundSource = null
            this.sprite = null
            this.persistentBetweenScenes = false
            this.rigidbody = null
            this.parent = null
            this.isHovered = false
            this.clickEvents = clickEvents
            this.hoverEnterEvents = Function[]
            this.hoverExitEvents = Function[]
            this.forceClickCheck = forceClickCheck
            this.ignoreInputEvents = ignoreInputEvents

        }
    }

    function JulGame_add_script(this: Entity,  script) {
        console.debug(string("Adding script of type: ", typeof(script), " to entity named " , this.name))
        this.scripts.push(script)
        script.parent = this
        try {
            (globalThis as any).JulGame.initialize(script)
        } catch (e) {
            @error string(e)
            Base.show_backtrace(stdout, catch_backtrace())
        }
    }

    function JulGame_update(this: Entity,  deltaTime) {
        if (!this.isActive) {
            this.isHovered = false
            return
        }

        for (const script of this.scripts) {
            try {
                Base.invokelatest((globalThis as any).JulGame.update, script, deltaTime) 
            } catch (e) {
                (globalThis as any).JulGame.ErrorLoggingModule.log_error((globalThis as any).JulGame.MAIN.errorLogger, string(e), current_exceptions())
            }
        }
    }

    function JulGame_add_animator(this: Entity,  animator: Animator = Animator(Animation[JulGameAnimation(Vector4[Vector4(0, 0, 0, 0)], 60)])) 
        if (this.animator != null) {
            console.log("Animator already exists on entity named ", this.name)
            return
        }

        this.animator = InternalAnimator(this, animator.animations)
        if (this.sprite != null) {
            this.animator.sprite = this.sprite
        }

        return this.animator
    }

    function JulGame_add_collider(this: Entity,  collider: Collider = Collider(true,  false,  false,  {x: 0, y: 0}, {x: 1, y: 1}, "Default"))
        if (this.collider != null || this.circleCollider != null) {
            console.log("Collider already exists on entity named ", this.name)
            return
        }
            
        this.collider = InternalCollider(this, collider.size, collider.offset, collider.tag: string, collider.isTrigger: boolean, collider.isPlatformerCollider: boolean, collider.enabled: boolean)

        return this.collider
    }

    function JulGame_add_circle_collider(this: Entity,  collider: CircleCollider = CircleCollider(1.0,  true,  false,  {x: 0, y: 0}, "Default"))
        if (this.collider != null || this.circleCollider != null) {
            console.log("Collider already exists on entity named ", this.name)
            return
        }

        this.circleCollider = InternalCircleCollider(this, collider.diameter, collider.offset, collider.tag: string, collider.isTrigger: boolean, collider.enabled: boolean)

        return this.circleCollider
    }

    function JulGame_add_rigidbody(this: Entity,  rigidbody: Rigidbody = Rigidbody())
        if (this.rigidbody != null) {
            console.log("Rigidbody already exists on entity named ", this.name)
            return
        }

        this.rigidbody = InternalRigidbody(this; rigidbody.mass, rigidbody.useGravity)
        
        return this.rigidbody
    }

    function JulGame_add_sound_source(this: Entity,  soundSource: SoundSource = SoundSource(-1,  false,  "",  false,  50))
        if (this.soundSource != null) {
            console.log("SoundSource already exists on entity named ", this.name)
            return
        }

        this.soundSource = InternalSoundSource(this, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)

        return this.soundSource
    }

    function JulGame_create_sound_source(this: Entity,  soundSource: SoundSource = SoundSource(-1,  false,  "",  false,  50))
        newSoundSource: InternalSoundSource = InternalSoundSource(this, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)
        return newSoundSource
    }

    function JulGame_add_sprite(this: Entity,  isCreatedInEditor: boolean = false,  sprite: Sprite = Sprite((255,  255,  255,  255), null, false, "", 0, {x: 0, y: 0}, {x: 0, y: 0}, 0, -1, {x: 0.5, y: 0.5}, :center, false))
        if (this.sprite != null) {
            console.log("Sprite already exists on entity named ", this.name)
            return
        }

        this.sprite = InternalSprite(this, sprite.imagePath, sprite.crop, sprite.isFlipped, sprite.color, isCreatedInEditor; pixelsPerUnit=sprite.pixelsPerUnit, position=sprite.position, rotation=sprite.rotation, layer=sprite.layer, center=sprite.center, anchor=sprite.anchor, offset=sprite.offset, isStatic=sprite.isStatic)
        if (this.animator != null) {
            this.animator.sprite = this.sprite
        }
        Component_initialize(this.sprite)

        return this.sprite
    }

    function JulGame_add_shape(this: Entity,  shape: Shape = Shape(Math.Vector3(255, 0, 0), true, true, 0, {x: 0, y: 0}, {x: 0, y: 0}, {x: 1, y: 1}, 255))
        if (this.shape != null) {
            console.log("Shape already exists on entity named ", this.name)
            return
        }

        this.shape = InternalShape(this, shape.color, shape.isFilled, shape.offset, shape.size; isWorldEntity = shape.isWorldEntity, position = shape.position, layer = shape.layer, alpha = shape.alpha)
        
        return this.shape
    }

    function JulGame_add_mesh3d(this: Entity,  mesh3d: Mesh3D = Mesh3D())
        if (this.mesh3d != null) {
            console.log("Mesh3D already exists on entity named ", this.name)
            return
        }

        this.mesh3d = mesh3d
        mesh3d.parent = this
        Component_initialize(mesh3d, (globalThis as any).JulGame.MAIN)

        return this.mesh3d
    }

    function JulGame_add_software_renderer3d(this: Entity,  softwareRenderer3d: SoftwareRenderer3D = SoftwareRenderer3D())
        if (this.softwareRenderer3d != null) {
            console.log("SoftwareRenderer3D already exists on entity named ", this.name)
            return
        }

        this.softwareRenderer3d = softwareRenderer3d
        softwareRenderer3d.parent = this
        Component_initialize(softwareRenderer3d, (globalThis as any).JulGame.MAIN)

        return this.softwareRenderer3d
    }

    function JulGame_duplicate(this: Entity,  id: string = (globalThis as any).JulGame.generate_uuid())
        let newEntity = Entity(this.name, id, Component_duplicate(this.transform, null))
        // animator: InternalAnimator | null
        if (this.animator != null && this.animator !== null) {
            newEntity.animator = Component_duplicate(this.animator, newEntity)
        }
        // collider: InternalCollider | null
        if (this.collider != null && this.collider !== null) {
            newEntity.collider = Component_duplicate(this.collider, newEntity)
        }
        // circleCollider: InternalCircleCollider | null
        // if this.circleCollider != null && this.circleCollider !== null
        //     newEntity.circleCollider = Component_duplicate(this.circleCollider, newEntity)
        // }
        // isActive: boolean
        newEntity.isActive = this.isActive
        // mesh3d: Mesh3D | null
        if (this.mesh3d != null && this.mesh3d !== null) {
            //newEntity.mesh3d = Component_duplicate(this.mesh3d, newEntity)
        }
        // softwareRenderer3d: SoftwareRenderer3D | null
        if (this.softwareRenderer3d != null && this.softwareRenderer3d !== null) {
            newEntity.softwareRenderer3d = this.softwareRenderer3d
        }
        // persistentBetweenScenes: boolean
        newEntity.persistentBetweenScenes = this.persistentBetweenScenes
        // rigidbody: InternalRigidbody | null
        if (this.rigidbody != null && this.rigidbody !== null) {
            newEntity.rigidbody = Component_duplicate(this.rigidbody, newEntity)
        }
        // scripts: any[]
        // for script in this.scripts
        //     (globalThis as any).JulGame.add_script(newEntity, script)
        // }
        // shape: InternalShape | null
        if (this.shape != null && this.shape !== null) {
            newEntity.shape = Component_duplicate(this.shape, newEntity)
        }
        // soundSource: InternalSoundSource | null
        if (this.soundSource != null && this.soundSource !== null) {
            newEntity.soundSource = Component_duplicate(this.soundSource, newEntity)
        }
        // sprite: InternalSprite | null
        if (this.sprite != null && this.sprite !== null) {
            newEntity.sprite = Component_duplicate(this.sprite, newEntity)
        }
        
        (globalThis as any).JulGame.MAIN.scene.entities.push(newEntity)
        return newEntity
    }

    function JulGame_generate_uuid() {
        return string(UUIDs.uuid4())
    }
