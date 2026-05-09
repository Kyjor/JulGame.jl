export {}
import { clamp } from "../../../../src/engine/core/juliaHelpers";
import { vecAdd, vecSub, vecMul, vecDiv, vecNeg } from "../../../../src/engine/core/vectorOps";


    // using ..Component.JulGame
    // import ..Component
    
    class Rigidbody {
        mass: number
        useGravity: boolean
    }

    
    class InternalRigidbody { 
        acceleration: Vector2f
        drag: number
        grounded: boolean
        mass: number
        offset: Vector2f
        parent: any
        useGravity: boolean
        velocity: Vector2f

        constructor(parent: Any; mass: number = 1.0,  useGravity: boolean = true) {
            
            
            this.acceleration = {x: 0, y: 0}
            this.drag = 0.1
            this.grounded = false
            this.mass = mass
            this.offset = {x: 0, y: 0}
            this.parent = parent
            this.useGravity = useGravity
            this.velocity = {x: 0.0, y: 0.0}

        }
    }

    function Component_update(this: InternalRigidbody,  dt) {
        dt = clamp(dt, 0, .5)
        let velocityMultiplier = {x: 1.0, y: 1.0}
        let transform = this.parent.transform
        let currentPosition = transform.position
        
        let newPosition = vecAdd(vecAdd(transform.position, vecMul(this.velocity, dt)), vecMul(this.acceleration, vecMul(vecMul(dt, dt), 0.5))) as Vector3f
        if (this.grounded) {
            newPosition = {x: newPosition.x, y: currentPosition.y, z: newPosition.z}
            velocityMultiplier = {x: 1.0, y: 0.0}
        }
        let newAcceleration = Component_apply_forces(this)
        let newVelocity = vecAdd(this.velocity, vecMul(vecAdd(this.acceleration, newAcceleration), vecMul(dt, 0.5))) as Vector2f

        transform.position = newPosition
        this.velocity = vecMul(newVelocity, velocityMultiplier) as Vector2f
        this.acceleration = newAcceleration

        if (this.parent.collider != null) {
            Component_check_collisions(this.parent.collider)
        }
    }

    function Component_apply_forces(this: InternalRigidbody) {
        let gravityAcceleration = {x: 0.0, y: this.useGravity ? (globalThis as any).JulGame.GRAVITY : 0.0}
        let dragForce = vecMul(vecMul(0.5, this.drag), vecMul(this.velocity, this.velocity)) as Vector2f
        let dragAcceleration = vecDiv(dragForce, this.mass) as Vector2f
        return vecSub(gravityAcceleration, dragAcceleration) as Vector2f
    }

    function Component_get_velocity(this: InternalRigidbody) {
        return this.velocity
    }

    /*
    add_velocity(this, velocity)

    Add the given velocity to the Rigidbody's current velocity. If the y-component of the velocity is positive, set the `grounded` flag to false.
    
    // Arguments
    - `this`: The Rigidbody component to set the velocity for.
    - `velocity`: The velocity to set.
    */
    function add_velocity(this: InternalRigidbody,  velocity: Vector2f) {
        this.velocity = vecAdd(this.velocity, velocity) as Vector2f
        if (velocity.y < 0) {
            this.grounded = false
            if (this.parent.collider != null) {
                this.parent.collider.currentRests = []
            }
        }
    }
    

    function Component_duplicate(this: InternalRigidbody,  parent: any) {
        let newRigidbody = new InternalRigidbody(parent, mass=this.mass, useGravity=this.useGravity)
        newRigidbody.acceleration = this.acceleration
        newRigidbody.drag = this.drag
        newRigidbody.grounded = this.grounded
        newRigidbody.mass = this.mass
        newRigidbody.offset = this.offset
        return newRigidbody
    }
