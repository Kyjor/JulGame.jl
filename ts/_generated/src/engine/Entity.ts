export {}
import { InternalAnimator } from "./Component/Animator"
import { InternalCollider } from "./Component/Collider"
import { InternalRigidbody } from "./Component/Rigidbody"
import { InternalSoundSource } from "./Component/SoundSource"
import { InternalSprite, Component_initialize } from "./Component/Sprite"
import { Transform } from "./Component/Transform"

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
        circleCollider: any | null
        mesh3d: IMesh3D | null
        softwareRenderer3d: ISoftwareRenderer3D | null
        rigidbody: InternalRigidbody | null
        shape: any | null
        soundSource: InternalSoundSource | null
        sprite: InternalSprite | null

        clickEvents: Function[]
        hoverEnterEvents: Function[]
        hoverExitEvents: Function[]
        isHovered: boolean
        forceClickCheck: boolean
        ignoreInputEvents: boolean

        constructor(name: string = "New entity", id: string = (globalThis as any).JulGame.generate_uuid(), transform: ITransform = new Transform(), scripts: any[] = [], clickEvents = [], forceClickCheck: boolean = false, ignoreInputEvents: boolean = false) {
            

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

    function JulGame_add_script(self: Entity, script: unknown) {
        console.debug(["Adding script of type: ", typeof(script), " to entity named ", self.name].join(""))
        self.scripts.push(script)
        ;(script as { parent: Entity }).parent = self
        try {
            (globalThis as any).JulGame.initialize(script)
        } catch (e) {
            console.error(String(e))
        }
    }

    function JulGame_update(self: Entity, deltaTime: number) {
        if (!self.isActive) {
            self.isHovered = false
            return
        }

        for (const script of self.scripts) {
            try {
                (globalThis as any).JulGame.update(script, deltaTime) 
            } catch (e) {
                (globalThis as any).JulGame.ErrorLoggingModule.log_error((globalThis as any).JulGame.MAIN.errorLogger, String(e), undefined)
            }
        }
    }

    function JulGame_add_animator(self: Entity, _animator?: unknown) {
        if (self.animator != null) {
            console.log("Animator already exists on entity named ", self.name)
            return
        }
        console.warn("JulGame_add_animator: not supported in stripped TS runtime")
        return null
    }

    function JulGame_add_collider(self: Entity, collider: any) {
        if (self.collider != null || self.circleCollider != null) {
            console.log("Collider already exists on entity named ", self.name)
            return
        }
            
        self.collider = new InternalCollider(self, collider.size, collider.offset, collider.tag, collider.isTrigger, collider.isPlatformerCollider, collider.enabled)

        return self.collider
    }

    function JulGame_add_circle_collider(self: Entity, _collider: any) {
        if (self.collider != null || self.circleCollider != null) {
            console.log("Collider already exists on entity named ", self.name)
            return
        }

        console.warn("JulGame_add_circle_collider: not supported in stripped TS runtime")
        return null
    }

    function JulGame_add_rigidbody(self: Entity, rigidbody: any) {
        if (self.rigidbody != null) {
            console.log("Rigidbody already exists on entity named ", self.name)
            return
        }

        self.rigidbody = new InternalRigidbody(self, rigidbody.mass, rigidbody.useGravity)
        
        return self.rigidbody
    }

    function JulGame_add_sound_source(self: Entity, soundSource: any) {
        if (self.soundSource != null) {
            console.log("SoundSource already exists on entity named ", self.name)
            return
        }

        self.soundSource = new InternalSoundSource(self, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)

        return self.soundSource
    }

    function JulGame_create_sound_source(self: Entity, soundSource: any) {
        const newSoundSource = new InternalSoundSource(self, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)
        return newSoundSource
    }

    function JulGame_add_sprite(self: Entity, isCreatedInEditor: boolean = false, sprite: any) {
        if (self.sprite != null) {
            console.log("Sprite already exists on entity named ", self.name)
            return
        }

        self.sprite = new InternalSprite(self, sprite.imagePath, sprite.crop, sprite.isFlipped, sprite.color, isCreatedInEditor, sprite.pixelsPerUnit, sprite.position, sprite.rotation, sprite.layer, sprite.center, sprite.anchor, sprite.offset, sprite.isStatic)
        if (self.animator != null) {
            self.animator.sprite = self.sprite
        }
        Component_initialize(self.sprite)

        return self.sprite
    }

    function JulGame_add_shape(self: Entity, _shape: any) {
        if (self.shape != null) {
            console.log("Shape already exists on entity named ", self.name)
            return
        }
        console.warn("JulGame_add_shape: not supported in stripped TS runtime")
        return null
    }

    function JulGame_duplicate(self: Entity, id: string = (globalThis as any).JulGame.generate_uuid()) {
        let newEntity = new Entity(self.name, id, Component_duplicate(self.transform, null))
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
        newEntity.isActive = self.isActive
        // mesh3d: Mesh3D | null
        // if (this.mesh3d != null && this.mesh3d !== null) {
        //     //newEntity.mesh3d = Component_duplicate(this.mesh3d, newEntity)
        // }
        // // softwareRenderer3d: SoftwareRenderer3D | null
        // if (this.softwareRenderer3d != null && this.softwareRenderer3d !== null) {
        //     newEntity.softwareRenderer3d = this.softwareRenderer3d
        // }
        // persistentBetweenScenes: boolean
        newEntity.persistentBetweenScenes = self.persistentBetweenScenes
        // rigidbody: InternalRigidbody | null
        if (self.rigidbody != null && self.rigidbody !== null) {
            newEntity.rigidbody = Component_duplicate(self.rigidbody, newEntity)
        }
        // scripts: any[]
        // for script in this.scripts
        //     (globalThis as any).JulGame.add_script(newEntity, script)
        // }
        // shape: InternalShape | null
        if (self.shape != null && self.shape !== null) {
            newEntity.shape = Component_duplicate(self.shape, newEntity)
        }
        // soundSource: InternalSoundSource | null
        if (self.soundSource != null && self.soundSource !== null) {
            newEntity.soundSource = Component_duplicate(self.soundSource, newEntity)
        }
        // sprite: InternalSprite | null
        if (self.sprite != null && self.sprite !== null) {
            newEntity.sprite = Component_duplicate(self.sprite, newEntity)
        }
        
        (globalThis as any).JulGame.MAIN.scene.entities.push(newEntity)
        return newEntity
    }

    function JulGame_generate_uuid() {
        if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
            return (crypto as Crypto).randomUUID()
        }
        return `id-${Math.random().toString(36).slice(2, 11)}`
    }

export { Entity, JulGame_add_script, JulGame_add_sprite, JulGame_update }
