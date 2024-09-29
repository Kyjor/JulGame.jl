module ColliderModule
    include("../../utils/Enums.jl")
    using ..Component.JulGame
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

    function Component.check_collisions(this::InternalCollider)
        # colliders = MAIN.scene.colliders
        # #Only check the player against other colliders
        # counter = 0
        # onGround = this.parent.rigidbody.grounded 
        # colliderSkipCount = 0
        # colliderCheckedCount = 0
        # i = 0
        # for collider in colliders
        #     i += 1
        #     #TODO: Skip any out of a certain range of this. This will prevent a bunch of unnecessary collision checks
        #     if !Component.get_parent(collider).isActive || !collider.enabled
        #         if this.parent.rigidbody.grounded && i == length(colliders)
        #             this.parent.rigidbody.grounded = false
        #         end
        #         continue
        #     end
            
        #     if this != collider
        #         # check if other collider is within range of this collider, if it isn't then skip it
        #         if Component.get_parent(collider).transform.position.x > Component.get_parent(this).transform.position.x + Component.get_size(this).x || Component.get_parent(collider).transform.position.x + Component.get_size(collider).x < Component.get_parent(this).transform.position.x && MAIN.optimizeSpriteRendering
        #             colliderSkipCount += 1
        #             continue
        #         end

        #         colliderCheckedCount += 1
        #         collision = check_collision(this, collider)
        #         if CheckIfResting(this, collider)[1] == true && length(this.currentRests) > 0 && !(collider in this.currentRests)
        #             # if this collider isn't already in the list of current rests, check if it is on the same Y level and the same size as any of the current rests, if it is, then add it to current rests
        #             for j in eachindex(this.currentRests)
        #                 if Component.get_parent(this.currentRests[j]).transform.position.y == Component.get_parent(collider).transform.position.y && Component.get_size(this.currentRests[j]).y == Component.get_size(collider).y
        #                     push!(this.currentRests, collider)
        #                     break
        #                 end
        #             end
        #         end
                
        #         transform = Component.get_parent(this).transform
        #         if collision[1] == Top::CollisionDirection
        #             push!(this.currentCollisions, collider)
        #             for eventToCall::Function in this.collisionEvents
        #                 eventToCall(collider)
        #             end
        #             #Begin to overlap, correct position
        #             Component.set_position(transform, Math.Vector2f(transform.position.x, transform.position.y + collision[2]))
        #         end
        #         if collision[1] == Left::CollisionDirection
        #             push!(this.currentCollisions, collider)
        #             for eventToCall::Function in this.collisionEvents
        #                 eventToCall(collider)
        #             end
        #             #Begin to overlap, correct position
        #             Component.set_position(transform, Math.Vector2f(transform.position.x + collision[2], transform.position.y))
        #         end
        #         if collision[1] == Right::CollisionDirection
        #             push!(this.currentCollisions, collider)
        #             for eventToCall::Function in this.collisionEvents
        #                 eventToCall(collider)
        #             end
        #             #Begin to overlap, correct position
        #             Component.set_position(transform, Math.Vector2f(transform.position.x - collision[2], transform.position.y))
        #         end
        #         if collision[1] == Bottom::CollisionDirection && Component.get_velocity(this.parent.rigidbody).y >= 0
        #             push!(this.currentCollisions, collider)
        #             if !collider.isTrigger
        #                 push!(this.currentRests, collider)
        #             end
        #             for eventToCall::Function in this.collisionEvents
        #                 try
        #                     eventToCall(collider)
        #                 catch e
        #                     @error string(e)
		# 				    Base.show_backtrace(stdout, catch_backtrace())
		# 				    rethrow(e)
        #                 end
        #             end
        #             #Begin to overlap, correct position
        #             Component.set_position(transform, Math.Vector2f(transform.position.x, transform.position.y - collision[2]))
        #             if !collider.isTrigger
        #                 onGround = true
        #             end
        #         end
        #         if collision[1] == Below::ColliderLocation
        #             push!(this.currentCollisions, collider)
        #             for eventToCall in this.collisionEvents
        #                 eventToCall(collider)
        #             end
        #         end
        #     end
            colliders = MAIN.scene.colliders
            #Only check the player against other colliders
            counter = 0
            onGround = false
            i = 1
            for collider in colliders
                #TODO: Skip any out of a certain range of this. This will prevent a bunch of unnecessary collision checks
                if !Component.get_parent(collider).isActive || !collider.enabled
                    if this.parent.rigidbody != C_NULL && this.parent.rigidbody !== nothing && this.parent.rigidbody.grounded && i == length(colliders)
                        this.parent.rigidbody.grounded = false
                    end
                    continue
                end
                if this != collider
                    collision = check_collision(this, collider)
                    transform = Component.get_parent(this).transform
                    if collision[1] == Top::CollisionDirection
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                        #Begin to overlap, correct position
                        Component.get_parent(this).transform.position = Math.Vector2f(transform.position.x, transform.position.y + collision[2])
                    end
                    if collision[1] == Left::CollisionDirection
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                        #Begin to overlap, correct position
                        Component.get_parent(this).transform.position = Math.Vector2f(transform.position.x + collision[2], transform.position.y)
                    end
                    if collision[1] == Right::CollisionDirection
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                        #Begin to overlap, correct position
                        Component.get_parent(this).transform.position = Math.Vector2f(transform.position.x - collision[2], transform.position.y)
                    end
                    if collision[1] == Bottom::CollisionDirection
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                        #Begin to overlap, correct position
                        Component.get_parent(this).transform.position = Math.Vector2f(transform.position.x, transform.position.y - collision[2])
                        onGround = true
                    end
                    if collision[1] == Below::ColliderLocation
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                    end
                end
                i += 1
            end
            if this.parent.rigidbody != C_NULL && this.parent.rigidbody !== nothing
                this.parent.rigidbody.grounded = onGround
            end
            this.currentCollisions = []
        

        #println("Skipped $colliderSkipCount colliders, checked $colliderCheckedCount")

        # for i in eachindex(this.currentRests)
        #     if CheckIfResting(this, this.currentRests[i])[1] == false
        #         deleteat!(this.currentRests, i)
        #         break
        #     end
        # end

        # this.parent.rigidbody.grounded = length(this.currentRests) > 0 && Component.get_velocity(this.parent.rigidbody).y >= 0
        # this.currentCollisions = InternalCollider[]
        return length(this.currentCollisions) > 0
    end

    function Component.add_collision_event(this::InternalCollider, event)
        push!(this.collisionEvents, event)
    end        

    function Component.get_type(this::InternalCollider)
        return "Collider"
    end
    
    function check_collision(colliderA::InternalCollider, colliderB::InternalCollider)
        posA = Component.get_parent(colliderA).transform.position * SCALE_UNITS - ((Component.get_size(colliderA) * SCALE_UNITS - SCALE_UNITS) / 2)
        posB = Component.get_parent(colliderB).transform.position * SCALE_UNITS - ((Component.get_size(colliderB) * SCALE_UNITS - SCALE_UNITS) / 2)
        offsetAX = colliderA.offset.x * SCALE_UNITS
        offsetAY = colliderA.offset.y * SCALE_UNITS
        offsetBX = colliderB.offset.x * SCALE_UNITS
        offsetBY = colliderB.offset.y * SCALE_UNITS
        colliderAXSize = Component.get_parent(colliderA).transform.scale.x * Component.get_size(colliderA).x * SCALE_UNITS
        colliderAYSize = Component.get_parent(colliderA).transform.scale.y * Component.get_size(colliderA).y * SCALE_UNITS
        colliderBXSize = Component.get_parent(colliderB).transform.scale.x * Component.get_size(colliderB).x * SCALE_UNITS
        colliderBYSize = Component.get_parent(colliderB).transform.scale.y * Component.get_size(colliderB).y * SCALE_UNITS

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
            #println(depthTop)
        end
    
        if rightA <= leftB
            dist = leftB - rightA
            right = dist == 0.0 && rightA > leftB && leftA < rightB
            return (right == 0.0 ? RightSide::ColliderLocation : None::CollisionDirection, dist)
        elseif rightA > leftB
            depthRight = rightA - leftB
        end
        
        if leftA >= rightB
            dist = leftA - rightB
            left = dist == 0.0 && rightA > leftB && leftA < rightB
            return (left == 0.0 ? LeftSide::ColliderLocation : None::CollisionDirection, dist)
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

        posA = Component.get_parent(colliderA).transform.position * SCALE_UNITS - ((Component.get_parent(colliderA).transform.scale * SCALE_UNITS - SCALE_UNITS) / 2) - ((Component.get_size(colliderA) * SCALE_UNITS - SCALE_UNITS) / 2)
        posB = Component.get_parent(colliderB).transform.position * SCALE_UNITS - ((Component.get_parent(colliderB).transform.scale * SCALE_UNITS - SCALE_UNITS) / 2) - ((Component.get_size(colliderB) * SCALE_UNITS - SCALE_UNITS) / 2)
        offsetAX = colliderA.offset.x * SCALE_UNITS
        offsetBX = colliderB.offset.x * SCALE_UNITS
        colliderAXSize = Component.get_size(colliderA).x * SCALE_UNITS
        colliderBXSize = Component.get_size(colliderB).x * SCALE_UNITS

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
