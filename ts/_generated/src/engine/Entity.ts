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

    
    class Entity {
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

        constructor(name: string = "New entity", id: string = (globalThis as any).JulGame.generate_uuid(), transform: ITransform = new Transform(), scripts = [], clickEvents = [], forceClickCheck: boolean = false, ignoreInputEvents: boolean = false) {
            

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
            this.hoverEnterEvents = []
            this.hoverExitEvents = []
            this.forceClickCheck = forceClickCheck
            this.ignoreInputEvents = ignoreInputEvents

        }
    }

    function JulGame_add_script(self: Entity, script) {
        console.debug(["Adding script of type: ", typeof(script), " to entity named ", self.name].join(""))
        self.scripts.push(script)
        script.parent = self
        try {
            (globalThis as any).JulGame.initialize(script)
        } catch (e) {


        }
    }

    function JulGame_update(self: Entity, deltaTime) {
        if (!self.isActive) {
            self.isHovered = false
            return
        }

        for (const script of self.scripts) {
            try {
                (globalThis as any).JulGame.update(script, deltaTime) 
            } catch (e) {
                (globalThis as any).JulGame.ErrorLoggingModule.log_error((globalThis as any).JulGame.MAIN.errorLogger, String(e), current_exceptions())
            }
        }
    }

    function JulGame_add_animator(self: Entity, animator: Animator = Animator(Animation[JulGameAnimation(Vector4[{x: 0, y: 0, z: 0, t: 0}], 60)])) {
        if (self.animator != null) {
            console.log("Animator already exists on entity named ", self.name)
            return
        }

        self.animator = new InternalAnimator(self, animator.animations)
        if (self.sprite != null) {
            self.animator.sprite = self.sprite
        }

        return self.animator
    }

    function JulGame_add_collider(self: Entity, collider: Collider = Collider(true, false, false, {x: 0, y: 0}, {x: 1, y: 1}, "Default")) {
        if (self.collider != null || self.circleCollider != null) {
            console.log("Collider already exists on entity named ", self.name)
            return
        }
            
        self.collider = new InternalCollider(self, collider.size, collider.offset, collider.tag: string, collider.isTrigger: boolean, collider.isPlatformerCollider: boolean, collider.enabled: boolean)

        return self.collider
    }

    function JulGame_add_circle_collider(self: Entity, collider: CircleCollider = CircleCollider(1.0, true, false, {x: 0, y: 0}, "Default")) {
        if (self.collider != null || self.circleCollider != null) {
            console.log("Collider already exists on entity named ", self.name)
            return
        }

        self.circleCollider = new InternalCircleCollider(self, collider.diameter, collider.offset, collider.tag: string, collider.isTrigger: boolean, collider.enabled: boolean)

        return self.circleCollider
    }

    function JulGame_add_rigidbody(self: Entity, rigidbody: Rigidbody = Rigidbody(1.0, true)) {
        if (self.rigidbody != null) {
            console.log("Rigidbody already exists on entity named ", self.name)
            return
        }

        self.rigidbody = new InternalRigidbody(self, rigidbody.mass, rigidbody.useGravity)
        
        return self.rigidbody
    }

    function JulGame_add_sound_source(self: Entity, soundSource: SoundSource = SoundSource(-1, false, "", false, 50)) {
        if (self.soundSource != null) {
            console.log("SoundSource already exists on entity named ", self.name)
            return
        }

        self.soundSource = new InternalSoundSource(self, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)

        return self.soundSource
    }

    function JulGame_create_sound_source(self: Entity, soundSource: SoundSource = SoundSource(-1, false, "", false, 50)) {
        newSoundSource: InternalSoundSource = new InternalSoundSource(self, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)
        return newSoundSource
    }

    function JulGame_add_sprite(self: Entity, isCreatedInEditor: boolean = false, sprite: Sprite = Sprite((255, 255, 255, 255), null, false, "", 0, {x: 0, y: 0}, {x: 0, y: 0}, 0, -1, {x: 0.5, y: 0.5}, "center", false)) {
        if (self.sprite != null) {
            console.log("Sprite already exists on entity named ", self.name)
            return
        }

        self.sprite = new InternalSprite(self, sprite.imagePath, sprite.crop, sprite.isFlipped, sprite.color, isCreatedInEditor; pixelsPerUnit=sprite.pixelsPerUnit, position=sprite.position, rotation=sprite.rotation, layer=sprite.layer, center=sprite.center, anchor=sprite.anchor, offset=sprite.offset, isStatic=sprite.isStatic)
        if (self.animator != null) {
            self.animator.sprite = self.sprite
        }
        Component_initialize(self.sprite)

        return self.sprite
    }

    function JulGame_add_shape(self: Entity, shape: Shape = Shape(Vector3(255,0,0), true, true, 0, {x: 0, y: 0}, {x: 0, y: 0}, {x: 1, y: 1}, 255)) {
        if (self.shape != null) {
            console.log("Shape already exists on entity named ", self.name)
            return
        }

        self.shape = new InternalShape(self, shape.color, shape.isFilled, shape.offset, shape.size; isWorldEntity = shape.isWorldEntity, position = shape.position, layer = shape.layer, alpha = shape.alpha)
        
        return self.shape
    }

    function JulGame_add_mesh3d(self: Entity, mesh3d: Mesh3D = Mesh3D()) {
        if (self.mesh3d != null) {
            console.log("Mesh3D already exists on entity named ", self.name)
            return
        }

        self.mesh3d = mesh3d
        mesh3d.parent = self
        Component_initialize(mesh3d, (globalThis as any).JulGame.MAIN)

        return self.mesh3d
    }

    function JulGame_add_software_renderer3d(self: Entity, softwareRenderer3d: SoftwareRenderer3D = SoftwareRenderer3D()) {
        if (self.softwareRenderer3d != null) {
            console.log("SoftwareRenderer3D already exists on entity named ", self.name)
            return
        }

        self.softwareRenderer3d = softwareRenderer3d
        softwareRenderer3d.parent = self
        Component_initialize(softwareRenderer3d, (globalThis as any).JulGame.MAIN)

        return self.softwareRenderer3d
    }

    function JulGame_duplicate(self: Entity, id: string = (globalThis as any).JulGame.generate_uuid()) {
        let newEntity = Entity(self.name, id, Component_duplicate(self.transform, null))
        // animator: InternalAnimator | null
        if (self.animator != null && self.animator !== null) {
            newEntity.animator = Component_duplicate(self.animator, newEntity)
        }
        // collider: InternalCollider | null
        if (self.collider != null && self.collider !== null) {
            newEntity.collider = Component_duplicate(self.collider, newEntity)
        }
        // circleCollider: InternalCircleCollider | null
        // if self.circleCollider != null && self.circleCollider !== null
        //     newEntity.circleCollider = Component_duplicate(self.circleCollider, newEntity)
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
        return String(UUIDs.uuid4())
    }
