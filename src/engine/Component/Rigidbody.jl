module RigidbodyModule
    using ..Component.JulGame
    using ..Component.JulGame.Math: _Vector2
    import ..Component
    export Rigidbody
    struct Rigidbody
        mass::Float64
        useGravity::Bool

        function Rigidbody(;mass::Float64 = 1.0, useGravity::Bool = true)
            return new(mass, useGravity)
        end
    end

    export InternalRigidbody
    mutable struct InternalRigidbody 
        acceleration::_Vector2{Float64}
        drag::Float64
        grounded::Bool
        mass::Float64
        offset::_Vector2{Float64}
        parent::Any
        useGravity::Bool
        velocity::_Vector2{Float64}

        function InternalRigidbody(parent::Any; mass::Float64 = 1.0, useGravity::Bool = true)
            return new(
                _Vector2{Float64}(),
                0.1,
                false,
                mass,
                _Vector2{Float64}(),
                parent,
                useGravity,
                _Vector2{Float64}(0.0, 0.0),
            )
        end
    end

    function Component.update(this::InternalRigidbody, dt)
        dt = clamp(dt, 0, .5)
        velocityMultiplier = _Vector2{Float64}(1.0, 1.0)
        transform = this.parent.transform
        currentPosition = transform.position
        
        newPosition = transform.position + this.velocity*dt + this.acceleration*(dt*dt*0.5)
        if this.grounded
            newPosition = _Vector2{Float64}(newPosition.x, currentPosition.y)
            velocityMultiplier = _Vector2{Float64}(1.0, 0.0)
        end
        newAcceleration = Component.apply_forces(this)
        newVelocity = this.velocity + (this.acceleration+newAcceleration)*(dt*0.5)

        Component.set_position(transform, newPosition)
        set_velocity(this, newVelocity * velocityMultiplier)
        this.acceleration = newAcceleration

        if this.parent.collider != C_NULL
            Component.check_collisions(this.parent.collider)
        end
    end

    function Component.apply_forces(this::InternalRigidbody)
        gravityAcceleration = _Vector2{Float64}(0.0, this.useGravity ? GRAVITY : 0.0)
        dragForce = 0.5 * this.drag * (this.velocity * this.velocity)
        dragAcceleration = dragForce / this.mass
        return gravityAcceleration - dragAcceleration
    end

    function Component.get_velocity(this::InternalRigidbody)
        return this.velocity
    end

    """
    add_velocity(this::Rigidbody, velocity::Math.Vector2f)

    Add the given velocity to the Rigidbody's current velocity. If the y-component of the velocity is positive, set the `grounded` flag to false.
    
    # Arguments
    - `this::Rigidbody`: The Rigidbody component to set the velocity for.
    - `velocity::Math.Vector2f`: The velocity to set.
    """
    function add_velocity(this::InternalRigidbody, velocity::_Vector2{Float64})
        this.velocity = this.velocity + velocity
        if(velocity.y < 0)
            this.grounded = false
            if this.parent.collider != C_NULL
                this.parent.collider.currentRests = []
            end
        end
    end
    export add_velocity
    
    """
    set_velocity(this::Rigidbody, velocity::Math.Vector2f)

    Set the velocity of the Rigidbody component.

    # Arguments
    - `this::Rigidbody`: The Rigidbody component to set the velocity for.
    - `velocity::Vector2f`: The velocity to set.
    """
    function set_velocity(this::InternalRigidbody, velocity::_Vector2{Float64})
        this.velocity = velocity
        if(velocity.y < 0)
            #this.grounded = false
        end
    end
    export set_velocity

    function Component.duplicate(this::InternalRigidbody, parent::Any)
        newRigidbody = InternalRigidbody(parent, mass=this.mass, useGravity=this.useGravity)
        newRigidbody.acceleration = this.acceleration
        newRigidbody.drag = this.drag
        newRigidbody.grounded = this.grounded
        newRigidbody.mass = this.mass
        newRigidbody.offset = this.offset
        return newRigidbody
    end
end
