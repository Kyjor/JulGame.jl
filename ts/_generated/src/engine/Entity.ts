export {}
import { InternalAnimator } from "./Component/Animator";
import { InternalCollider } from "./Component/Collider";
import { InternalRigidbody } from "./Component/Rigidbody";
import { InternalSoundSource } from "./Component/SoundSource";
import { Component_initialize, InternalSprite } from "./Component/Sprite";
import { Transform } from "./Component/Transform";


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
        mesh3d: Mesh3D | null
        softwareRenderer3d: SoftwareRenderer3D | null
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
            console.error(String(e))

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
                (globalThis as any).JulGame.ErrorLoggingModule.log_error((globalThis as any).JulGame.MAIN.errorLogger, String(e), undefined)
            }
        }
    }

    function JulGame_add_animator(self: Entity, animator?: unknown) {
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

    function JulGame_add_collider(self: Entity, collider?: unknown) {
        if (self.collider != null || self.circleCollider != null) {
            console.log("Collider already exists on entity named ", self.name)
            return
        }
            
        self.collider = new InternalCollider(self, collider.size, collider.offset, collider.tag, collider.isTrigger, collider.isPlatformerCollider, collider.enabled)

        return self.collider
    }

    function JulGame_add_circle_collider(self: Entity, _arg?: unknown) {
        console.warn("JulGame_add_circle_collider: not transpiled yet")
        return null
    }

    function JulGame_add_rigidbody(self: Entity, rigidbody?: unknown) {
        if (self.rigidbody != null) {
            console.log("Rigidbody already exists on entity named ", self.name)
            return
        }

        self.rigidbody = new InternalRigidbody(self, rigidbody.mass, rigidbody.useGravity)
        
        return self.rigidbody
    }

    function JulGame_add_sound_source(self: Entity, soundSource?: unknown) {
        if (self.soundSource != null) {
            console.log("SoundSource already exists on entity named ", self.name)
            return
        }

        self.soundSource = new InternalSoundSource(self, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)

        return self.soundSource
    }

    function JulGame_create_sound_source(self: Entity, soundSource?: unknown) {
        let newSoundSource = new InternalSoundSource(self, soundSource.path, soundSource.channel, soundSource.volume, soundSource.isMusic, soundSource.playOnStart)
        return newSoundSource
    }

    function JulGame_add_sprite(self: Entity, isCreatedInEditor: boolean = false, sprite?: unknown) {
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

    function JulGame_add_shape(self: Entity, _arg?: unknown) {
        console.warn("JulGame_add_shape: not transpiled yet")
        return null
    }

    function JulGame_add_mesh3d(self: Entity, mesh3d?: unknown) {
        if (self.mesh3d != null) {
            console.log("Mesh3D already exists on entity named ", self.name)
            return
        }

        self.mesh3d = mesh3d
        mesh3d.parent = self
        Component_initialize(mesh3d, (globalThis as any).JulGame.MAIN)

        return self.mesh3d
    }

    function JulGame_add_software_renderer3d(self: Entity, softwareRenderer3d?: unknown) {
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
        let newEntity = new Entity(self.name, id, Component_duplicate(self.transform, null))
        // animator: InternalAnimator | null
        if (self.animator != null && self.animator !== null) {
            newEntity.animator = Component_duplicate(self.animator, newEntity)
        }
        // collider: InternalCollider | null
        if (self.collider != null && self.collider !== null) {
            newEntity.collider = Component_duplicate(self.collider, newEntity)
        }
        // circleCollider: any | null
        // if self.circleCollider != null && self.circleCollider !== null
        //     newEntity.circleCollider = Component_duplicate(self.circleCollider, newEntity)
        // }
        // isActive: boolean
        newEntity.isActive = self.isActive
        // mesh3d: Mesh3D | null
        if (self.mesh3d != null && self.mesh3d !== null) {
            //newEntity.mesh3d = Component_duplicate(self.mesh3d, newEntity)
        }
        // softwareRenderer3d: SoftwareRenderer3D | null
        if (self.softwareRenderer3d != null && self.softwareRenderer3d !== null) {
            newEntity.softwareRenderer3d = self.softwareRenderer3d
        }
        // persistentBetweenScenes: boolean
        newEntity.persistentBetweenScenes = self.persistentBetweenScenes
        // rigidbody: InternalRigidbody | null
        if (self.rigidbody != null && self.rigidbody !== null) {
            newEntity.rigidbody = Component_duplicate(self.rigidbody, newEntity)
        }
        // scripts: any[]
        // for script in self.scripts
        //     (globalThis as any).JulGame.add_script(newEntity, script)
        // }
        // shape: any | null
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
        return (typeof crypto !== "undefined" && "randomUUID" in crypto ? (crypto as Crypto).randomUUID() : `id-${Math.random().toString(36).slice(2, 11)}`)
    }
export { Entity, JulGame_add_animator, JulGame_add_circle_collider, JulGame_add_collider, JulGame_add_mesh3d, JulGame_add_rigidbody, JulGame_add_script, JulGame_add_shape, JulGame_add_software_renderer3d, JulGame_add_sound_source, JulGame_add_sprite, JulGame_create_sound_source, JulGame_duplicate, JulGame_generate_uuid, JulGame_update }
