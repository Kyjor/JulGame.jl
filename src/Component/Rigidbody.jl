module RigidbodyModule
    using ..Component.JulGame

    export Rigidbody
    mutable struct Rigidbody 
        acceleration::Math.Vector2f
        drag::Float64
        grounded::Bool
        mass::Float64
        offset::Math.Vector2f
        parent::Any
        useGravity::Bool
        velocity::Math.Vector2f

        function Rigidbody(mass::Float64)
            this = new()
            
            this.acceleration = Math.Vector2f()
            this.drag = 0.1
            this.grounded = false
            this.mass = mass
            this.offset = Math.Vector2f()
            this.useGravity = true
            this.velocity = Math.Vector2f(0.0, 0.0)

            return this
        end
    end

    function Base.getproperty(this::Rigidbody, s::Symbol)
        # Todo: update this based on offset and scale
        if s == :update
            function(dt)
                velocityMultiplier = Math.Vector2f(1.0, 1.0)
                transform = this.parent.getTransform()
                currentPosition = transform.getPosition()
                
                newPosition = transform.getPosition() + this.velocity*dt + this.acceleration*(dt*dt*0.5)
                if this.grounded
                    newPosition = Math.Vector2f(newPosition.x, currentPosition.y)
                    velocityMultiplier = Math.Vector2f(1.0, 0.0)
                end
                newAcceleration = this.applyForces()
                newVelocity = this.velocity + (this.acceleration+newAcceleration)*(dt*0.5)

                transform.setPosition(newPosition)
                SetVelocity(this, newVelocity * velocityMultiplier)
                this.acceleration = newAcceleration

                if this.parent.getCollider() != C_NULL
                    this.parent.getCollider().checkCollisions()
                end
            end
        elseif s == :applyForces
            function()
                gravityAcceleration = Math.Vector2f(0.0, GRAVITY)
                dragForce = 0.5 * this.drag * (this.velocity * this.velocity)
                dragAcceleration = dragForce / this.mass
                return gravityAcceleration - dragAcceleration
            end
        elseif s == :getVelocity
            function()
                return this.velocity
            end
        elseif s == :getParent
            function()
                return this.parent
            end
        elseif s == :setParent
            function(parent)
                this.parent = parent
            end
        elseif s == :setVector2fValue
            function(field, x, y)
                setfield!(this, field, Math.Vector2f(x,y))
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
            end
        end
    end

    """
    AddVelocity(this::Rigidbody, velocity::Math.Vector2f)

    Add the given velocity to the Rigidbody's current velocity. If the y-component of the velocity is positive, set the `grounded` flag to false.
    
    # Arguments
    - `this::Rigidbody`: The Rigidbody component to set the velocity for.
    - `velocity::Math.Vector2f`: The velocity to set.
    """
    function AddVelocity(this::Rigidbody, velocity::Math.Vector2f)
        this.velocity = this.velocity + velocity
        if(velocity.y < 0)
            this.grounded = false
            if this.parent.getCollider() != C_NULL
                this.parent.getCollider().currentRests = []
            end
        end
    end
    export AddVelocity
    
    """
    SetVelocity(this::Rigidbody, velocity::Math.Vector2f)

    Set the velocity of the Rigidbody component.

    # Arguments
    - `this::Rigidbody`: The Rigidbody component to set the velocity for.
    - `velocity::Vector2f`: The velocity to set.
    """
    function SetVelocity(this::Rigidbody, velocity::Math.Vector2f)
        this.velocity = velocity
        if(velocity.y < 0)
            #this.grounded = false
        end
    end
    export SetVelocity
end
