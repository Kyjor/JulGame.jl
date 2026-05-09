export {}
import { vecAdd, vecSub, vecMul, vecDiv, vecNeg } from "../../../../src/engine/core/vectorOps";


    // include("../../utils/Enums.jl")
    // using ..Component.JulGame
    // import ..Component 

    
    class Collider {
        enabled: boolean
        isPlatformerCollider: boolean
        isTrigger: boolean
        offset: Vector2f
        size: Vector2f
        tag: string
    }


    
    class InternalCollider {
        collisionEvents: Function[]
        currentCollisions: InternalCollider[]
        currentRests: InternalCollider[]
        enabled: boolean
        isTrigger: boolean
        isPlatformerCollider: boolean
        offset: Vector2f
        parent: any
        size: Vector2f
        tag: string
        
        constructor(parent: any,  size: Vector2f = {x: 1, y: 1}, offset = {x: 0, y: 0}, tag: string="Default", isTrigger: boolean=false, isPlatformerCollider: boolean = false, enabled: boolean=true) {
            

            this.collisionEvents = []
            this.currentCollisions = []
            this.currentRests = []
            this.enabled = enabled
            this.isTrigger = isTrigger
            this.isPlatformerCollider = isPlatformerCollider
            this.offset = offset
            this.parent = parent
            this.size = size
            this.tag = tag

            if (this.size.x < 0 || this.size.y < 0) {
                console.log("Collider size cannot be negative")
                this.size = {x: 1, y: 1}
            }

        }
    }

    function Component_get_size(this: InternalCollider) {
        return this.size
    }

    function Component_set_size(this: InternalCollider,  size: Vector2f) {
        this.size = size
    }

    function Component_get_offset(this: InternalCollider) {
        return this.offset
    }

    function Component_set_offset(this: InternalCollider,  offset: Vector2f) {
        this.offset = offset
    }

    function Component_get_tag(this: InternalCollider) {
        return this.tag
    }

    function Component_check_collisions(this: InternalCollider) {
        let colliders = MAIN.scene.colliders
        //Only check the player against other colliders
        let colliderSkipCount = 0
        let colliderCheckedCount = 0
        let i = 0
        let onGround = false
        if (!this.parent.isActive || !this.enabled) {
            return
        }

        for (const collider of colliders) {
            i += 1
            
            if (!collider.parent.isActive || !collider.enabled) {
                continue
            }
            
            if (this != collider) {
                // check if other collider is within range of this collider, if it isn't then skip it
                if (collider.parent.transform.position.x > this.parent.transform.position.x + Component_get_size(this).x || collider.parent.transform.position.x + Component_get_size(collider).x < this.parent.transform.position.x && MAIN.optimizeSpriteRendering) {
                    colliderSkipCount += 1
                    continue
                }

                colliderCheckedCount += 1
                let transform = this.parent.transform
                let collision = check_collision(this, collider)
                    transform = this.parent.transform
                    if (collision[0] == Top) {
                        this.currentCollisions.push(collider)
                        for (const eventToCall of this.collisionEvents) {
                            eventToCall({ collider, direction: collision[0] })
                        }
                        //Begin to overlap, correct position
                        if (!collider.isTrigger && !this.isTrigger) {
                                this.parent.transform.position = {x: transform.position.x, y: transform.position.y + collision[1]}
                        }
                    }
                    if (collision[0] == Left) {
                        this.currentCollisions.push(collider)
                        for (const eventToCall of this.collisionEvents) {
                            eventToCall({ collider, direction: collision[0] })
                        }
                        
                        if (!collider.isTrigger && !this.isTrigger) {
                                //Begin to overlap, correct position
                                this.parent.transform.position = {x: transform.position.x + collision[1], y: transform.position.y}
                        }
                    }
                    if (collision[0] == Right) {
                        this.currentCollisions.push(collider)
                        for (const eventToCall of this.collisionEvents) {
                            eventToCall({ collider, direction: collision[0] })
                        }
                        //Begin to overlap, correct position
                        if (!collider.isTrigger && !this.isTrigger) {
                                this.parent.transform.position = {x: transform.position.x - collision[1], y: transform.position.y}
                        }
                    }
                    if (collision[0] == Bottom) {
                        this.currentCollisions.push(collider)
                        for (const eventToCall of this.collisionEvents) {
                            eventToCall({ collider, direction: collision[0] })
                        }
                        //Begin to overlap, correct position
                        
                        if (!collider.isTrigger && !this.isTrigger) {
                                this.parent.transform.position = {x: transform.position.x, y: transform.position.y - collision[1]}
                                if (this.parent.rigidbody.velocity.y >= 0) {
                                        this.parent.rigidbody.grounded = true
                                }
                        }
                    }
                    if (collision[0] == Below) {
                        this.currentCollisions.push(collider)
                        for (const eventToCall of this.collisionEvents) {
                            eventToCall({ collider, direction: collision[0] })
                        }
                    }
                    if (collision[2] && this.parent.rigidbody.grounded) {
                        onGround = true
                    }
                }

            }

            this.parent.rigidbody.grounded = onGround

        return this.currentCollisions.length > 0
    }

    function Component_add_collision_event(this: InternalCollider,  event) {
        this.collisionEvents.push(event)
    }        

    function check_collision(colliderA: InternalCollider,  colliderB: InternalCollider) {
        let posA = vecMul(vecAdd(colliderA.parent.transform.position, colliderA.offset), (globalThis as any).JulGame.SCALE_UNITS) as Vector2f
        let posB = vecMul(vecAdd(colliderB.parent.transform.position, colliderB.offset), (globalThis as any).JulGame.SCALE_UNITS) as Vector2f
        let colliderAXSize = colliderA.parent.transform.scale.x * colliderA.size.x * (globalThis as any).JulGame.SCALE_UNITS
        let colliderAYSize = colliderA.parent.transform.scale.y * colliderA.size.y * (globalThis as any).JulGame.SCALE_UNITS
        let colliderBXSize = colliderB.parent.transform.scale.x * colliderB.size.x * (globalThis as any).JulGame.SCALE_UNITS
        let colliderBYSize = colliderB.parent.transform.scale.y * colliderB.size.y * (globalThis as any).JulGame.SCALE_UNITS

        let a = (globalThis as any).JulGameSdl.glue_SDL_Rect(Math.round(posA.x), Math.round(posA.y), Math.round(colliderAXSize), Math.round(colliderAYSize))
        let b = (globalThis as any).JulGameSdl.glue_SDL_Rect(Math.round(posB.x), Math.round(posB.y), Math.round(colliderBXSize), Math.round(colliderBYSize))

        // (globalThis as any).JulGameSdl.glue_SDL_GetRenderDrawColor((globalThis as any).JulGame.Renderer, rgba.r, rgba.g, rgba.b, rgba.a)
        // (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, 0, 255, 255, SDL2.SDL_ALPHA_OPAQUE)
        
        let result = (globalThis as any).JulGameSdl.glue_SDL_Rect(0,0,0,0)
        let isIntersection = (globalThis as any).JulGameSdl.glue_SDL_IntersectRect(a, b, result)

        let camera = MAIN.scene.camera
        let camS = (globalThis as any).JulGame.pixels_per_world_unit(camera)
        let cameraDiff = camera !== null ? 
        Vector2((camera.position.x + camera.offset.x) * camS, (camera.position.y + camera.offset.y) * camS) : 
        {x: 0, y: 0}
        let isLineIntersectionL = (globalThis as any).JulGameSdl.glue_SDL_IntersectRectAndLine(b, Math.round(posA.x), Math.round(posA.y + 32), Math.round(posA.x), Math.round(posA.y + 80))
        //(globalThis as any).JulGameSdl.glue_SDL_RenderDrawLine((globalThis as any).JulGame.Renderer, Math.round(posA.x - cameraDiff.x), Math.round(posA.y + 32 - cameraDiff.y), Math.round(posA.x - cameraDiff.x), Math.round(posA.y + 80 - cameraDiff.y))

        let isLineIntersectionR = (globalThis as any).JulGameSdl.glue_SDL_IntersectRectAndLine(b, Math.round(posA.x + colliderAXSize), Math.round(posA.y + 32), Math.round(posA.x + colliderAXSize), Math.round(posA.y + 80))
        //(globalThis as any).JulGameSdl.glue_SDL_RenderDrawLine((globalThis as any).JulGame.Renderer, Math.round(posA.x - cameraDiff.x + colliderAXSize), Math.round(posA.y + 32 - cameraDiff.y), Math.round(posA.x - cameraDiff.x + colliderAXSize), Math.round(posA.y + 80 - cameraDiff.y))
        if (isLineIntersectionL == 1) {
            isLineIntersectionL = true
        } else {
            isLineIntersectionL = false
        }

        if (isLineIntersectionR == 1) {
            isLineIntersectionR = true
        } else {
            isLineIntersectionR = false
        }

        if (isIntersection == 1) {
            let a1 = (globalThis as any).JulGameSdl.glue_SDL_FRect(posA.x, posA.y, colliderAXSize, colliderAYSize)
            let b1 = (globalThis as any).JulGameSdl.glue_SDL_FRect(posB.x, posB.y, colliderBXSize, colliderBYSize)
            // (globalThis as any).JulGameSdl.glue_SDL_RenderDrawRectF((globalThis as any).JulGame.Renderer, a1)
            // (globalThis as any).JulGameSdl.glue_SDL_RenderDrawRectF((globalThis as any).JulGame.Renderer, b1)
            // (globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, rgba.r, rgba.g, rgba.b, rgba.a);

            // console.log("col a (me): $(a)")
            // console.log("col b (other): $(b)")
            // console.log("result: $(result)")
            // console.log("$(colliderA.parent.name) is colliding with $(colliderB.parent.name)")

            let depthHorizontal = result.w
            let depthVertical = result.h
            let horizontalCollisionDir = None
            let verticalCollisionDir = None
            if (result.x == b.x && !colliderB.isPlatformerCollider) {
                console.debug("colliding from left at depth $(depthHorizontal)")
                horizontalCollisionDir = Left
            } else if (result.x == a.x && !colliderB.isPlatformerCollider) {
                console.debug("colliding from right at depth $(depthHorizontal)")
                horizontalCollisionDir = Right
            }
            if (result.y == b.y) {
                console.debug("colliding from top at depth $(depthVertical)")
                // Check if moving upward through a platformer - if so, ignore to prevent snap-to-top
                if (colliderB.isPlatformerCollider && colliderA.parent.rigidbody !== null) {
                    // If moving upward (negative velocity in SDL coords), ignore collision
                    if (colliderA.parent.rigidbody.velocity.y < 0) {
                        return (None, 0.0, isLineIntersectionL || isLineIntersectionR)
                    }
                }
                verticalCollisionDir = Bottom
            } else if (result.y == a.y) {
                console.debug("colliding from bottom at depth $(depthVertical)") 
                // Platformer colliders allow pass-through from below
                if (colliderB.isPlatformerCollider) {
                    return (None, 0.0, isLineIntersectionL || isLineIntersectionR)
                }
                verticalCollisionDir = Top
            }
            
            if (min(depthHorizontal, depthVertical) == depthHorizontal) {
                return (horizontalCollisionDir, -depthHorizontal/(globalThis as any).JulGame.SCALE_UNITS, isLineIntersectionL || isLineIntersectionR)
            } else {
                return (verticalCollisionDir, depthVertical/(globalThis as any).JulGame.SCALE_UNITS, isLineIntersectionL || isLineIntersectionR)
            }
        }

        //(globalThis as any).JulGameSdl.glue_SDL_SetRenderDrawColor((globalThis as any).JulGame.Renderer, rgba.r, rgba.g, rgba.b, rgba.a);

        return (None, 0.0, isLineIntersectionL || isLineIntersectionR)
    }

    function Component_duplicate(this: InternalCollider,  parent: any) {
        let newCollider = new InternalCollider(parent, this.size, this.offset, this.tag, this.isTrigger, this.isPlatformerCollider, this.enabled)
        newCollider.collisionEvents = this.collisionEvents
        return newCollider
    }
   