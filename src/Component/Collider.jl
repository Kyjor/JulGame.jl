module ColliderModule
    include("../Enums.jl")
    using ..Component.JulGame

    export Collider
    struct Collider
        enabled::Bool
        isPlatformerCollider::Bool
        isTrigger::Bool
        offset::Math.Vector2f
        size::Math.Vector2f
        tag::String
    end


    export InternalCollider
    mutable struct InternalCollider
        collisionEvents::Vector{Function}
        currentCollisions::Vector{InternalCollider}
        currentRests::Vector{InternalCollider}
        enabled::Bool
        isTrigger::Bool
        isPlatformerCollider::Bool
        offset::Math.Vector2f
        parent::Any
        rigidbody::Any
        size::Math.Vector2f
        tag::String
        
        function InternalCollider(parent::Any, size::Math.Vector2f = Math.Vector2f(1,1), offset::Math.Vector2f = Math.Vector2f(), tag::String="Default", isTrigger::Bool=false, isPlatformerCollider::Bool = false, enabled::Bool=true, rigidbody::Any = C_NULL)
            this = new()

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

            return this
        end
    end

    function Base.getproperty(this::InternalCollider, s::Symbol)
        if s == :getSize
            function()
                return this.size
            end
        elseif s == :setSize
            function(size::Math.Vector2f)
                this.size = size
            end
        elseif s == :getOffset
            function()
                return this.offset
            end
        elseif s == :setOffset
            function(offset::Math.Vector2f)
                this.offset = offset
            end
        elseif s == :getTag
            function()
                return this.tag
            end
        elseif s == :setTag
            function(tag::String)
                this.tag = tag
            end
        elseif s == :getParent
            function()
                return this.parent
            end
        elseif s == :setParent
            function(parent::Any)
                this.parent = parent
            end
        elseif s == :checkCollisions
            function()
                colliders = MAIN.scene.colliders
                #Only check the player against other colliders
                counter = 0
                onGround = this.parent.getRigidbody().grounded
                for collider in colliders
                    #TODO: Skip any out of a certain range of this. This will prevent a bunch of unnecessary collision checks
                    if !collider.getParent().isActive || !collider.enabled
                        if this.parent.getRigidbody().grounded && i == length(colliders)
                            this.parent.getRigidbody().grounded = false
                        end
                        continue
                    end
                    if this != collider
                        collision = CheckCollision(this, collider)
                        if CheckIfResting(this, collider)[1] == true && length(this.currentRests) > 0 && !(collider in this.currentRests)
                            # if this collider isn't already in the list of current rests, check if it is on the same Y level and the same size as any of the current rests, if it is, then add it to current rests
                            for j in 1:length(this.currentRests)
                                if this.currentRests[j].getParent().getTransform().getPosition().y == collider.getParent().getTransform().getPosition().y && this.currentRests[j].getSize().y == collider.getSize().y
                                    push!(this.currentRests, collider)
                                    break
                                end
                            end
                        end
                        
                        transform = this.getParent().getTransform()
                        if collision[1] == Top::CollisionDirection
                            push!(this.currentCollisions, collider)
                            for eventToCall in this.collisionEvents
                                eventToCall(collider)
                            end
                            #Begin to overlap, correct position
                            transform.setPosition(Math.Vector2f(transform.getPosition().x, transform.getPosition().y + collision[2]))
                        end
                        if collision[1] == Left::CollisionDirection
                            push!(this.currentCollisions, collider)
                            for eventToCall in this.collisionEvents
                                eventToCall(collider)
                            end
                            #Begin to overlap, correct position
                            transform.setPosition(Math.Vector2f(transform.getPosition().x + collision[2], transform.getPosition().y))
                        end
                        if collision[1] == Right::CollisionDirection
                            push!(this.currentCollisions, collider)
                            for eventToCall in this.collisionEvents
                                eventToCall(collider)
                            end
                            #Begin to overlap, correct position
                            transform.setPosition(Math.Vector2f(transform.getPosition().x - collision[2], transform.getPosition().y))
                        end
                        if collision[1] == Bottom::CollisionDirection && this.parent.getRigidbody().getVelocity().y >= 0
                            push!(this.currentCollisions, collider)
                            if !collider.isTrigger
                                push!(this.currentRests, collider)
                            end
                            for eventToCall in this.collisionEvents
                                try
                                    eventToCall(collider)
                                catch e
                                    println(e)
                                end
                            end
                            #Begin to overlap, correct position
                            transform.setPosition(Math.Vector2f(transform.getPosition().x, transform.getPosition().y - collision[2]))
                            if !collider.isTrigger
                                onGround = true
                            end
                        end
                        if collision[1] == Below::ColliderLocation
                            push!(this.currentCollisions, collider)
                            for eventToCall in this.collisionEvents
                                eventToCall(collider)
                            end
                        end
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
        elseif s == :update
            function()
                
            end
        elseif s == :addCollisionEvent
            function(event)
                push!(this.collisionEvents, event)
            end        
        elseif s == :setVector2fValue
            function(field, x, y)
                setfield!(this, field, Math.Vector2f(x,y))
            end
        elseif s == :getType
            function()
                return "Collider"
            end
        else
            try
                getfield(this, s)
            catch e
                println(e)
            end
        end
    end

    function CheckCollision(colliderA::InternalCollider, colliderB::InternalCollider)
        # nameA = colliderA.getParent().name
        # nameB = colliderB.getParent().name
        posA = colliderA.getParent().getTransform().getPosition() * SCALE_UNITS - ((colliderA.getParent().getTransform().getScale() * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderA.getSize() * SCALE_UNITS - SCALE_UNITS) / 2)
        posB = colliderB.getParent().getTransform().getPosition() * SCALE_UNITS - ((colliderB.getParent().getTransform().getScale() * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderB.getSize() * SCALE_UNITS - SCALE_UNITS) / 2)
        offsetAX = colliderA.offset.x * SCALE_UNITS
        offsetAY = colliderA.offset.y * SCALE_UNITS
        offsetBX = colliderB.offset.x * SCALE_UNITS
        offsetBY = colliderB.offset.y * SCALE_UNITS
        colliderAXSize = colliderA.getSize().x * SCALE_UNITS
        colliderAYSize = colliderA.getSize().y * SCALE_UNITS
        colliderBXSize = colliderB.getSize().x * SCALE_UNITS
        colliderBYSize = colliderB.getSize().y * SCALE_UNITS

        #Calculate the sides of rect A
        leftA = posA.x + offsetAX
        rightA = posA.x + colliderAXSize + offsetAX
        topA = posA.y + offsetAY
        bottomA = posA.y + colliderAYSize + offsetAY
        #Calculate the sides of rect B
        leftB = posB.x + offsetBX
        rightB = posB.x + colliderBXSize + offsetBX
        topB = posB.y + offsetBY
        bottomB = posB.y + colliderBYSize + offsetBY
        
         #If any of the sides from A are outside of B
        depthBottom = 0.0
        depthTop = 0.0
        depthRight = 0.0
        depthLeft = 0.0
        if bottomA <= topB
            dist = topB - bottomA 
            below = dist == 0.0 && rightA > leftB && leftA < rightB
            return (below ? Below::ColliderLocation : None::CollisionDirection, dist)
        elseif bottomA > topB
            depthBottom = bottomA - topB
        end
        if topA >= bottomB
            dist = topA - bottomB
            above = dist == 0.0 && rightA > leftB && leftA < rightB
            return (above ? Above::ColliderLocation : None::CollisionDirection, dist)
        elseif topA < bottomB
            depthTop = bottomB - topA
        end
    
        if rightA <= leftB
            dist = leftB - rightA
            left = dist == 0.0 && rightA > leftB && leftA < rightB
            return (left == 0.0 ? LeftSide::ColliderLocation : None::CollisionDirection, dist)
        elseif rightA > leftB
            depthRight = rightA - leftB
        end
        
        if leftA >= rightB
            dist = leftA - rightB
            right = dist == 0.0 && rightA > leftB && leftA < rightB
            return (right == 0.0 ? RightSide::ColliderLocation : None::CollisionDirection, dist)
        elseif leftA < rightB
            depthLeft = rightB - leftA
        end
    
        #If none of the sides from A are outside B
        collisionSide = min(depthBottom, depthTop, depthLeft, depthRight)
        collisionDistance = colliderB.isTrigger ? 0.0 : collisionSide/SCALE_UNITS

        if collisionSide == depthBottom
            # println("Collision from below ", collisionDistance)
            if colliderB.isPlatformerCollider && collisionDistance > 0.25 #todo: make this a variable based on collider size. It's a magic number right now.
                return (None::CollisionDirection, 0.0)
            end
            return (Bottom::CollisionDirection, collisionDistance)
        elseif collisionSide == depthTop && !colliderB.isPlatformerCollider
            # println("Collision from above ", collisionDistance)
            return (Top::CollisionDirection, collisionDistance)
        elseif collisionSide == depthLeft && !colliderB.isPlatformerCollider
            # println("Collision from the left ", collisionDistance)
            return (Left::CollisionDirection, collisionDistance)
        elseif collisionSide == depthRight && !colliderB.isPlatformerCollider
            # println("Collision from the right ", collisionDistance)
            return (Right::CollisionDirection, collisionDistance)
        end 
        
        return (None::CollisionDirection, 0.0)
    end

    function CheckIfResting(colliderA::InternalCollider, colliderB::InternalCollider)
        if colliderB.isTrigger
            return (false, 0.0)
        end

        posA = colliderA.getParent().getTransform().getPosition() * SCALE_UNITS - ((colliderA.getParent().getTransform().getScale() * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderA.getSize() * SCALE_UNITS - SCALE_UNITS) / 2)
        posB = colliderB.getParent().getTransform().getPosition() * SCALE_UNITS - ((colliderB.getParent().getTransform().getScale() * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderB.getSize() * SCALE_UNITS - SCALE_UNITS) / 2)
        offsetAX = colliderA.offset.x * SCALE_UNITS
        offsetBX = colliderB.offset.x * SCALE_UNITS
        colliderAXSize = colliderA.getSize().x * SCALE_UNITS
        colliderBXSize = colliderB.getSize().x * SCALE_UNITS

        #Calculate the sides of rect A
        leftA = posA.x + offsetAX
        rightA = posA.x + colliderAXSize + offsetAX
        #Calculate the sides of rect B
        leftB = posB.x + offsetBX
        rightB = posB.x + colliderBXSize + offsetBX
        
         #If any of the sides from A are outside of B
        depthRight = 0.0
        depthLeft = 0.0
    
        if rightA <= leftB
            dist = leftB - rightA
            return (false, dist)
        elseif rightA > leftB
            depthRight = rightA - leftB
        end
        
        if leftA >= rightB
            dist = leftA - rightB
            return (false, dist)
        elseif leftA < rightB
            depthLeft = rightB - leftA
        end
        
        collisionSide = min(depthLeft, depthRight)
        
        if collisionSide == depthLeft
            return (true, collisionSide/SCALE_UNITS)
        elseif collisionSide == depthRight
            return (true, collisionSide/SCALE_UNITS)
        end 

    end
end