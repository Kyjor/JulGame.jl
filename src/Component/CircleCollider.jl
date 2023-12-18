
module CircleColliderModule
    using ..Component.JulGame
    using ..Component.ColliderModule

    export CircleCollider
    mutable struct CircleCollider
        collisionEvents::Array{Any}
        currentCollisions::Array{Collider}
        diameter::Float64
        enabled::Bool
        isGrounded::Bool
        isTrigger::Bool
        offset::Math.Vector2f
        parent::Any
        tag::String

        function CircleCollider(diameter::Float64, offset::Math.Vector2f, tag::String)
            this = new()
    
            this.collisionEvents = []
            this.currentCollisions = []
            this.diameter = diameter
            this.enabled = true
            this.isGrounded = false
            this.isTrigger = false
            this.offset = offset
            this.tag = tag
    
            return this
        end
    end


    function Base.getproperty(this::CircleCollider, s::Symbol)
        if s == :getSize
            function()
                return this.size
            end
        elseif s == :checkCollisions
            function()
                colliders = MAIN.scene.colliders
                #Only check the player against other colliders
                counter = 0
                
                for i in 1:length(colliders)
                    #TODO: Skip any out of a certain range of this. This will prevent a bunch of unnecessary collision checks
                    if !colliders[i].getParent().isActive || !colliders[i].enabled
                        if this.parent.getRigidbody().grounded && i == length(colliders)
                            this.parent.getRigidbody().grounded = false
                        end
                        continue
                    end
                    this.isGrounded = false
                    if this != colliders[i]
                        collision = CheckCollision(this, colliders[i])
                        transform = this.getParent().getTransform()
                        # if collision[1] == Top::CollisionDirection
                        #     push!(this.currentCollisions, colliders[i])
                        #     for eventToCall in this.collisionEvents
                        #         eventToCall()
                        #     end
                        #     #Begin to overlap, correct position
                        #     transform.setPosition(Math.Vector2f(transform.getPosition().x, transform.getPosition().y + collision[2]))
                        # end
                        # if collision[1] == Left::CollisionDirection
                        #     push!(this.currentCollisions, colliders[i])
                        #     for eventToCall in this.collisionEvents
                        #         eventToCall()
                        #     end
                        #     #Begin to overlap, correct position
                        #     transform.setPosition(Math.Vector2f(transform.getPosition().x + collision[2], transform.getPosition().y))
                        # end
                        # if collision[1] == Right::CollisionDirection
                        #     push!(this.currentCollisions, colliders[i])
                        #     for eventToCall in this.collisionEvents
                        #         eventToCall()
                        #     end
                        #     #Begin to overlap, correct position
                        #     transform.setPosition(Math.Vector2f(transform.getPosition().x - collision[2], transform.getPosition().y))
                        # end
                        # if collision[1] == Bottom::CollisionDirection
                        #this.isGrounded = collision[1]
                        if collision[1] == true
                            push!(this.currentCollisions, colliders[i])
                            for eventToCall in this.collisionEvents
                                eventToCall()
                            end
                            #Begin to overlap, correct position
                            transform.setPosition(Math.Vector2f(transform.getPosition().x, transform.getPosition().y)) #- collision[2]))
                            this.isGrounded = true
                        end
                        # end
                        # if collision[1] == Below::ColliderLocation
                        #     push!(this.currentCollisions, colliders[i])
                        #     for eventToCall in this.collisionEvents
                        #         eventToCall()
                        #     end
                        # end
                    end
                end
                this.parent.getRigidbody().grounded = this.isGrounded
                this.currentCollisions = []
            end
        elseif s == :setParent
            function(parent::Any)
                this.parent = parent
            end
        elseif s == :getParent
            function()
                return this.parent
            end
        elseif s == :addCollisionEvent
            function(event)
                push!(this.collisionEvents, event)
            end   
        elseif s == :getType
            function()
                return "CircleCollider"
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
            end
        end
    end

    function CheckCollision(colliderA::CircleCollider, colliderB::CircleCollider)
            # Calculate total radius squared
            totalRadiusSquared::Float64 = (a.diameter + b.diameter)^2

            # If the distance between the centers of the circles is less than the sum of their radii
            if DistanceSquared(a.offset.x, a.offset.y, b.offset.x, b.offset.y)::Float64 < totalRadiusSquared
                # The circles have collided
                return true
            end

            # If not
            return false
    end

    function CheckCollision(a::CircleCollider, b::Collider)
        # Closest point on collision box
        cX, cY = 0, 0

        posA = a.getParent().getTransform().getPosition() + a.offset
        posB = b.getParent().getTransform().getPosition() + b.offset

        # Find closest x offset
        if posA.x < posB.x
            cX = posB.x
        elseif posA.x > posB.x + b.size.x * SCALE_UNITS
            cX = posB.x + b.size.x * SCALE_UNITS
        else
            cX = posA.x
        end

        # Find closest y offset
        if posA.y < posB.y
            cY = posB.y
        elseif posA.y > posB.y + b.size.y * SCALE_UNITS
            cY = posB.y + b.size.y  * SCALE_UNITS
        else
            cY = posA.y
        end

        distanceSquared::Float64 = DistanceSquared(posA.x, posA.y, cX, cY)
        # If the closest point is inside the circle
        if distanceSquared < (a.diameter / 2)^2
            # This circle and the rectangle have collided
            println("Collision")
            println(distanceSquared)
            return [true, distanceSquared]
        end

        println("No Collision")
        # If the shapes have not collided
        return [false, distanceSquared]
    end

    function DistanceSquared(x1::Number, y1::Number, x2::Number, y2::Number)
        deltaX = x2 - x1
        deltaY = y2 - y1
        return deltaX^2 + deltaY^2
    end
end
