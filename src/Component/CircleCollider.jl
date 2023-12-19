
module CircleColliderModule
    using ..Component.JulGame
    using ..Component.ColliderModule

    export CircleCollider
    mutable struct CircleCollider
        collisionEvents::Array{Any}
        currentCollisions::Array{Collider}
        currentRests::Array{Collider}
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
            this.currentRests = []
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
                
                this.isGrounded = this.parent.getRigidbody().grounded
                

                for i in 1:length(colliders)
                    #TODO: Skip any out of a certain range of this. This will prevent a bunch of unnecessary collision checks
                    if !colliders[i].getParent().isActive || !colliders[i].enabled
                        if this.parent.getRigidbody().grounded && i == length(colliders)
                            this.parent.getRigidbody().grounded = false
                        end
                        continue
                    end
                    if this != colliders[i] && this.parent.getRigidbody().getVelocity().y >= 0
                        println(this.parent.getRigidbody().getVelocity().y)
                        collision = CheckCollision(this, colliders[i])
                        if CheckIfResting(this, colliders[i])[1] == true && length(this.currentRests) > 0 && !(colliders[i] in this.currentRests)
                            # if this collider isn't already in the list of current rests, check if it is on the same Y level and the same size as any of the current rests, if it is, then add it to current rests
                            for j in 1:length(this.currentRests)
                                if this.currentRests[j].getParent().getTransform().getPosition().y == colliders[i].getParent().getTransform().getPosition().y && this.currentRests[j].getSize().y == colliders[i].getSize().y
                                    push!(this.currentRests, colliders[i])
                                    break
                                end
                            end
                        end
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
                            println("Collided with: ", colliders[i].getParent().name, " at ", colliders[i].getParent().getTransform().getPosition())
                            push!(this.currentRests, colliders[i])
                            for eventToCall in this.collisionEvents
                                eventToCall()
                            end
                            #Begin to overlap, correct position
                            transform.setPosition(Math.Vector2f(transform.getPosition().x, transform.getPosition().y - collision[2]))
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
                for i in 1:length(this.currentRests)
                    if CheckIfResting(this, this.currentRests[i])[1] == false
                        deleteat!(this.currentRests, i)
                        break
                    end
                end
           
                this.parent.getRigidbody().grounded = length(this.currentRests) > 0 && this.parent.getRigidbody().getVelocity().y >= 0
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
        elseif posA.x > posB.x + b.size.x
            cX = posB.x + b.size.x
        else
            cX = posA.x
        end

        # Find closest y offset
        if posA.y < posB.y
            cY = posB.y
        elseif posA.y > posB.y + b.size.y
            cY = posB.y + b.size.y
        else
            cY = posA.y
        end

        distanceSquared::Float64 = DistanceSquared(posA.x, posA.y, cX, cY)
        # If the closest point is inside the circle
        if distanceSquared < (a.diameter / 2)^2
            # This circle and the rectangle have collided
            return [true, distanceSquared]
        end

        # If the shapes have not collided
        return [false, distanceSquared]
    end

    function CheckIfResting(a::CircleCollider, b::Collider)
        # Closest point on collision box
        cX = 0

        posA = a.getParent().getTransform().getPosition() + a.offset
        posB = b.getParent().getTransform().getPosition() + b.offset
        radius = a.diameter / 2

        # Find closest x offset
        if posA.x < posB.x
            cX = posB.x
        elseif posA.x > posB.x + b.size.x
            cX = posB.x + b.size.x
        else
            cX = posA.x
        end

        distance = (cX - posA.x)^2
        # # If the closest point is inside the circle
        if distance < (radius / 2)^2
            # This circle and the rectangle have collided
            return [true, distance]
        end

        # If the shapes have not collided
        return [false, distance]
    end

    function DistanceSquared(x1::Number, y1::Number, x2::Number, y2::Number)
        deltaX = x2 - x1
        deltaY = y2 - y1
        return deltaX^2 + deltaY^2
    end
end
