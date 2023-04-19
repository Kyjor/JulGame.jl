global const SCALE_UNITS = Ref{Float64}(64.0)[]
global const GRAVITY = Ref{Float64}(9.81)[]

mutable struct Rigidbody 
    acceleration
    drag
    grounded::Bool
    mass::Float64
    offset
    parent
    useGravity::Bool
    velocity::Vector2f
    
    function Rigidbody(mass::Float64, offset)
        this = new()
        
        this.acceleration = Vector2f()
        this.drag = 0.1
        this.grounded = false
        this.mass = mass
        this.offset = offset
        this.useGravity = true
        this.velocity = Vector2f(0.0, 0.0)

        return this
    end
end

function Base.getproperty(this::Rigidbody, s::Symbol)
    if s == :update
        function(dt)
            velocityMultiplier = Vector2f(1.0, 1.0)
            if this.grounded
                velocityMultiplier = Vector2f(1.0, 0)
            end
            parent = this.parent
            transform = this.parent.getTransform()

            newPosition = transform.getPosition() + this.velocity*dt + this.acceleration*(dt*dt*0.5)
            newAcceleration = this.applyForces()
            newVelocity = this.velocity + (this.acceleration+newAcceleration)*(dt*0.5)

            transform.setPosition(newPosition)
            this.setVelocity(newVelocity * velocityMultiplier)
            this.acceleration = newAcceleration

            if this.parent.getCollider() != C_NULL
                this.parent.getCollider().checkCollisions()
            end
        end
    elseif s == :applyForces
        function()
            gravityAcceleration = Vector2f(0.0, GRAVITY)
            dragForce = 0.5 * this.drag * (this.velocity * this.velocity)
            dragAcceleration = dragForce / this.mass
            return gravityAcceleration - dragAcceleration
        end
    elseif s == :getVelocity
        function()
            return this.velocity
        end
    elseif s == :setVelocity
        function(velocity::Vector2f)
            this.velocity = velocity
        end
    elseif s == :getParent
        function()
            return this.parent
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end