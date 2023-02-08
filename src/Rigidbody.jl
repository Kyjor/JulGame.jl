include("Math/Vector2f.jl")

using SimpleDirectMediaLayer.LibSDL2

mutable struct Rigidbody
    acceleration
    drag
    mass
    offset
    parent
    useGravity::Bool
    velocity::Vector2f
    
    function Rigidbody(mass::Float64, offset)
        this = new()
        
        this.acceleration = Vector2f()
        this.drag = 0.1
        this.mass = mass
        this.offset = offset
        this.useGravity = true
        this.velocity = Vector2f(0.0, 0.0)

        return this
    end
end

function Base.getproperty(this::Rigidbody, s::Symbol)
    if s == :update
        function(dt, grounded, jump)
            if grounded && !jump
                this.velocity = Vector2f(this.velocity.x, 0)
            end
            parent = this.parent
            transform = this.parent.getTransform()

            newPosition = transform.getPosition() + this.velocity*dt + this.acceleration*(dt*dt*0.5)
            newAcceleration = this.applyForces()
            newVelocity = this.velocity + (this.acceleration+newAcceleration)*(dt*0.5)

            transform.setPosition(newPosition)
            this.setVelocity(newVelocity)
            this.acceleration = newAcceleration
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
            println("setting rigidbody parent")
            this.parent = parent
        end
    else
        getfield(this, s)
    end
end