module ColliderModule
    include("../Enums.jl")
    using ..Component.JulGame
    import ..Component.JulGame: deprecated_get_property
    import ..Component 

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
        size::Math.Vector2f
        tag::String
        
        function InternalCollider(parent::Any, size::Math.Vector2f = Math.Vector2f(1,1), offset::Math.Vector2f = Math.Vector2f(), tag::String="Default", isTrigger::Bool=false, isPlatformerCollider::Bool = false, enabled::Bool=true)
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

            if this.size.x < 0 || this.size.y < 0
                println("Collider size cannot be negative")
                return C_NULL
            end

            return this
        end
    end

    function Base.getproperty(this::InternalCollider, s::Symbol)
        method_props = (
            getSize = Component.get_size,
            setSize = Component.set_size,
            getOffset = Component.get_offset,
            setOffset = Component.set_offset,
            getTag = Component.get_tag,
            setTag = Component.set_tag,
            getParent = Component.get_parent,
            setParent = Component.set_parent,
            checkCollisions = Component.check_collisions,
            update = Component.update,
            addCollisionEvent = Component.add_collision_event,
            setVector2fValue = Component.set_vector2f_value,
            getType = Component.get_type
        )
        deprecated_get_property(method_props, this, s)
    end
    
    function Component.get_size(this::InternalCollider)
        return this.size
    end

    function Component.set_size(this::InternalCollider, size::Math.Vector2f)
        this.size = size
    end

    function Component.get_offset(this::InternalCollider)
        return this.offset
    end

    function Component.set_offset(this::InternalCollider, offset::Math.Vector2f)
        this.offset = offset
    end

    function Component.get_tag(this::InternalCollider)
        return this.tag
    end

    function Component.set_tag(this::InternalCollider, tag::String)
        this.tag = tag
    end

    function Component.get_parent(this::InternalCollider)
        return this.parent
    end

    function Component.set_parent(this::InternalCollider, parent::Any)
        this.parent = parent
    end

    function Component.check_collisions(this::InternalCollider, main)
        colliders = main.scene.colliders
        #Only check the player against other colliders
        counter = 0
        onGround = this.parent.rigidbody.grounded 
        colliderSkipCount = 0
        colliderCheckedCount = 0
        i = 0
        for collider in colliders
            i += 1
            #TODO: Skip any out of a certain range of this. This will prevent a bunch of unnecessary collision checks
            if !collider.getParent().isActive || !collider.enabled
                if this.parent.rigidbody.grounded && i == length(colliders)
                    this.parent.rigidbody.grounded = false
                end
                continue
            end
            
            if this != collider
                # check if other collider is within range of this collider, if it isn't then skip it
                if collider.getParent().transform.position.x > this.getParent().transform.position.x + this.getSize().x || collider.getParent().transform.position.x + collider.getSize().x < this.getParent().transform.position.x && main.optimizeSpriteRendering
                    colliderSkipCount += 1
                    continue
                end

                colliderCheckedCount += 1
                collision = CheckCollision(this, collider)
                if CheckIfResting(this, collider)[1] == true && length(this.currentRests) > 0 && !(collider in this.currentRests)
                    # if this collider isn't already in the list of current rests, check if it is on the same Y level and the same size as any of the current rests, if it is, then add it to current rests
                    for j in eachindex(this.currentRests)
                        if this.currentRests[j].getParent().transform.position.y == collider.getParent().transform.position.y && this.currentRests[j].getSize().y == collider.getSize().y
                            push!(this.currentRests, collider)
                            break
                        end
                    end
                end
                
                transform = this.getParent().transform
                if collision[1] == Top::CollisionDirection
                    push!(this.currentCollisions, collider)
                    for eventToCall in this.collisionEvents
                        eventToCall(collider)
                    end
                    #Begin to overlap, correct position
                    transform.setPosition(Math.Vector2f(transform.position.x, transform.position.y + collision[2]))
                end
                if collision[1] == Left::CollisionDirection
                    push!(this.currentCollisions, collider)
                    for eventToCall in this.collisionEvents
                        eventToCall(collider)
                    end
                    #Begin to overlap, correct position
                    transform.setPosition(Math.Vector2f(transform.position.x + collision[2], transform.position.y))
                end
                if collision[1] == Right::CollisionDirection
                    push!(this.currentCollisions, collider)
                    for eventToCall in this.collisionEvents
                        eventToCall(collider)
                    end
                    #Begin to overlap, correct position
                    transform.setPosition(Math.Vector2f(transform.position.x - collision[2], transform.position.y))
                end
                if collision[1] == Bottom::CollisionDirection && this.parent.rigidbody.getVelocity().y >= 0
                    push!(this.currentCollisions, collider)
                    if !collider.isTrigger
                        push!(this.currentRests, collider)
                    end
                    for eventToCall in this.collisionEvents
                        try
                            eventToCall(collider)
                        catch e
                            println(e)
						    Base.show_backtrace(stdout, catch_backtrace())
						    rethrow(e)
                        end
                    end
                    #Begin to overlap, correct position
                    transform.setPosition(Math.Vector2f(transform.position.x, transform.position.y - collision[2]))
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

        #println("Skipped $colliderSkipCount colliders, checked $colliderCheckedCount")

        for i in eachindex(this.currentRests)
            if CheckIfResting(this, this.currentRests[i])[1] == false
                deleteat!(this.currentRests, i)
                break
            end
        end

        this.parent.rigidbody.grounded = length(this.currentRests) > 0 && this.parent.rigidbody.getVelocity().y >= 0
        this.currentCollisions = InternalCollider[]
    end

    function Component.update(this::InternalCollider)
        
    end

    function Component.add_collision_event(this::InternalCollider, event)
        push!(this.collisionEvents, event)
    end        

    function Component.set_vector2f_value(this::InternalCollider, field, x, y)
        setfield!(this, field, Math.Vector2f(x,y))
    end

    function Component.get_type(this::InternalCollider)
        return "Collider"
    end
    
    function CheckCollision(colliderA::InternalCollider, colliderB::InternalCollider)
        # nameA = colliderA.getParent().name
        # nameB = colliderB.getParent().name
        posA = colliderA.getParent().transform.position * SCALE_UNITS - ((colliderA.getParent().transform.scale * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderA.getSize() * SCALE_UNITS - SCALE_UNITS) / 2)
        posB = colliderB.getParent().transform.position * SCALE_UNITS - ((colliderB.getParent().transform.scale * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderB.getSize() * SCALE_UNITS - SCALE_UNITS) / 2)
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

        posA = colliderA.getParent().transform.position * SCALE_UNITS - ((colliderA.getParent().transform.scale * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderA.getSize() * SCALE_UNITS - SCALE_UNITS) / 2)
        posB = colliderB.getParent().transform.position * SCALE_UNITS - ((colliderB.getParent().transform.scale * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderB.getSize() * SCALE_UNITS - SCALE_UNITS) / 2)
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
