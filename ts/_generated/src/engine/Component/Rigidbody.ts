export {}
import { clamp } from "../../../../src/engine/core/juliaHelpers";
import { vecAdd, vecSub, vecMul, vecDiv, vecNeg } from "../../../../src/engine/core/vectorOps";


    // using ..Component.JulGame
    // import ..Component
    
    class InternalRigidbody { 
        acceleration: Vector2f
        drag: number
        grounded: boolean
        mass: number
        offset: Vector2f
        parent: any
        useGravity: boolean
        velocity: Vector2f

        constructor(parent: any, mass: number = 1.0, useGravity: boolean = true) {
            
            
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

    function Component_update(self: InternalRigidbody, dt: number) {
        dt = clamp(dt, 0, .5)
        let velocityMultiplier = {x: 1.0, y: 1.0}
        let transform = self.parent.transform
        let currentPosition = transform.position
        
        let newPosition = vecAdd(vecAdd(transform.position, vecMul(self.velocity, dt)), vecMul(self.acceleration, vecMul(vecMul(dt, dt), 0.5))) as Vector3f
        if (self.grounded) {
            newPosition = {x: newPosition.x, y: currentPosition.y, z: newPosition.z}
            velocityMultiplier = {x: 1.0, y: 0.0}
        }
        let newAcceleration = Component_apply_forces(self)
        let newVelocity = vecAdd(self.velocity, vecMul(vecAdd(self.acceleration, newAcceleration), vecMul(dt, 0.5))) as Vector2f

        transform.position = newPosition
        self.velocity = vecMul(newVelocity, velocityMultiplier) as Vector2f
        self.acceleration = newAcceleration

        if (self.parent.collider != null) {
            Component_check_collisions(self.parent.collider)
        }
    }

    function Component_apply_forces(self: InternalRigidbody) {
        let gravityAcceleration = {x: 0.0, y: self.useGravity ? (globalThis as any).JulGame.GRAVITY : 0.0}
        let dragForce = vecMul(vecMul(0.5, self.drag), vecMul(self.velocity, self.velocity)) as Vector2f
        let dragAcceleration = vecDiv(dragForce, self.mass) as Vector2f
        return vecSub(gravityAcceleration, dragAcceleration) as Vector2f
    }

    function Component_get_velocity(self: InternalRigidbody) {
        return self.velocity
    }

    /*
    add_velocity(this, velocity)

    Add the given velocity to the Rigidbody's current velocity. If the y-component of the velocity is positive, set the `grounded` flag to false.
    
    // Arguments
    - `this`: The Rigidbody component to set the velocity for.
    - `velocity`: The velocity to set.
    */
    function add_velocity(self: InternalRigidbody, velocity: Vector2f) {
        self.velocity = vecAdd(self.velocity, velocity) as Vector2f
        if (velocity.y < 0) {
            self.grounded = false
            if (self.parent.collider != null) {
                self.parent.collider.currentRests = []
            }
        }
    }
    

    function Component_duplicate(self: InternalRigidbody, parent: any) {
        let newRigidbody = new InternalRigidbody(parent, self.mass, self.useGravity)
        newRigidbody.acceleration = self.acceleration
        newRigidbody.drag = self.drag
        newRigidbody.grounded = self.grounded
        newRigidbody.mass = self.mass
        newRigidbody.offset = self.offset
        return newRigidbody
    }

export { InternalRigidbody }
