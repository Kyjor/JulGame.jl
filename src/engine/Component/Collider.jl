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
                return nothing
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

    function Component.check_collisions(this::InternalCollider)
        colliders = MAIN.scene.colliders
        #Only check the player against other colliders
        colliderSkipCount = 0
        colliderCheckedCount = 0
        i = 0
        onGround = false
        for collider in colliders
            i += 1
            
            if !collider.parent.isActive || !collider.enabled
                continue
            end
            
            if this != collider
                # check if other collider is within range of this collider, if it isn't then skip it
                if collider.parent.transform.position.x > this.parent.transform.position.x + Component.get_size(this).x || collider.parent.transform.position.x + Component.get_size(collider).x < this.parent.transform.position.x && MAIN.optimizeSpriteRendering
                    colliderSkipCount += 1
                    continue
                end

                colliderCheckedCount += 1
                #collision = check_collision(this, collider)
                # if CheckIfResting(this, collider)[1] == true && length(this.currentRests) > 0 && !(collider in this.currentRests)
                #     # if this collider isn't already in the list of current rests, check if it is on the same Y level and the same size as any of the current rests, if it is, then add it to current rests
                #     for j in eachindex(this.currentRests)
                #         if this.currentRests[j].parent.transform.position.y == collider.parent.transform.position.y && Component.get_size(this.currentRests[j]).y == Component.get_size(collider).y
                #             push!(this.currentRests, collider)
                #             break
                #         end
                #     end
                # end
                
                
                #continue
                transform = this.parent.transform
                collision = check_collision(this, collider)
                    transform = this.parent.transform
                    if collision[1] == Top::CollisionDirection
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                        #Begin to overlap, correct position
                        this.parent.transform.position = Math.Vector2f(transform.position.x, transform.position.y + collision[2])
                    end
                    if collision[1] == Left::CollisionDirection
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                        #Begin to overlap, correct position
                        this.parent.transform.position = Math.Vector2f(transform.position.x + collision[2], transform.position.y)
                    end
                    if collision[1] == Right::CollisionDirection
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                        #Begin to overlap, correct position
                        this.parent.transform.position = Math.Vector2f(transform.position.x - collision[2], transform.position.y)
                    end
                    if collision[1] == Bottom::CollisionDirection
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                        #Begin to overlap, correct position
                        this.parent.transform.position = Math.Vector2f(transform.position.x, transform.position.y - collision[2])
                        this.parent.rigidbody.grounded = true
                    end
                    if collision[1] == Below::ColliderLocation
                        push!(this.currentCollisions, collider)
                        for eventToCall in this.collisionEvents
                            Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                        end
                    end
                    if collision[3] && this.parent.rigidbody.grounded
                        onGround = true
                    end
                end

            end

            this.parent.rigidbody.grounded = onGround

        return length(this.currentCollisions) > 0
    end

    function Component.add_collision_event(this::InternalCollider, event)
        push!(this.collisionEvents, event)
    end        

    function check_collision(colliderA::InternalCollider, colliderB::InternalCollider)
        posA = (colliderA.parent.transform.position + colliderA.offset) * SCALE_UNITS
        posB = (colliderB.parent.transform.position + colliderB.offset) * SCALE_UNITS
        colliderAXSize = colliderA.parent.transform.scale.x * colliderA.size.x * SCALE_UNITS
        colliderAYSize = colliderA.parent.transform.scale.y * colliderA.size.y * SCALE_UNITS
        colliderBXSize = colliderB.parent.transform.scale.x * colliderB.size.x * SCALE_UNITS
        colliderBYSize = colliderB.parent.transform.scale.y * colliderB.size.y * SCALE_UNITS

        a = SDL2.SDL_Rect(round(posA.x), round(posA.y), round(colliderAXSize), round(colliderAYSize))
        b = SDL2.SDL_Rect(round(posB.x), round(posB.y), round(colliderBXSize), round(colliderBYSize))

        rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
        SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 0, 255, 255, SDL2.SDL_ALPHA_OPAQUE)
        
        result = Ref(SDL2.SDL_Rect(0,0,0,0))
        isIntersection = SDL2.SDL_IntersectRect(Ref(a), Ref(b), result)

        camera = MAIN.scene.camera
        cameraDiff = camera !== nothing ? 
        Math.Vector2((camera.position.x + camera.offset.x) * SCALE_UNITS, (camera.position.y + camera.offset.y) * SCALE_UNITS) : 
        Math.Vector2(0,0)
        isLineIntersectionL = SDL2.SDL_IntersectRectAndLine(Ref(b), Ref(Int32(round(posA.x))), Ref(Int32(round(posA.y + 32))), Ref(Int32(round(posA.x))), Ref(Int32(round(posA.y + 80))))
        SDL2.SDL_RenderDrawLine(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, round(posA.x - cameraDiff.x), round(posA.y + 32 - cameraDiff.y), round(posA.x - cameraDiff.x), round(posA.y + 80 - cameraDiff.y))

        isLineIntersectionR = SDL2.SDL_IntersectRectAndLine(Ref(b), Ref(Int32(round(posA.x + colliderAXSize))), Ref(Int32(round(posA.y + 32))), Ref(Int32(round(posA.x + colliderAXSize))), Ref(Int32(round(posA.y + 80))))
        SDL2.SDL_RenderDrawLine(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, round(posA.x - cameraDiff.x + colliderAXSize), round(posA.y + 32 - cameraDiff.y), round(posA.x - cameraDiff.x + colliderAXSize), round(posA.y + 80 - cameraDiff.y))
        if isLineIntersectionL == SDL2.SDL_TRUE
            println("line intersectionL")
            println(posA)
            isLineIntersectionL = true
        else
            isLineIntersectionL = false
        end

        if isLineIntersectionR == SDL2.SDL_TRUE
            println("line intersectionR")
            println(posA)
            isLineIntersectionR = true
        else
            isLineIntersectionR = false
        end

        if isIntersection == SDL2.SDL_TRUE
            a1 = SDL2.SDL_FRect(posA.x, posA.y, colliderAXSize, colliderAYSize)
            b1 = SDL2.SDL_FRect(posB.x, posB.y, colliderBXSize, colliderBYSize)
            SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(a1))
            SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(b1))
            SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);

            println("col a (me): $(a)")
            println("col b (other): $(b)")
            println("result: $(result)")
            println("$(colliderA.parent.name) is colliding with $(colliderB.parent.name)")

            depthHorizontal = result[].w
            depthVertical = result[].h
            horizontalCollisionDir = None::CollisionDirection
            verticalCollisionDir = None::CollisionDirection
            if result[].x == b.x 
                println("colliding from left at depth $(depthHorizontal)")
                horizontalCollisionDir = Left::CollisionDirection
            elseif result[].x == a.x
                println("colliding from right at depth $(depthHorizontal)")
                horizontalCollisionDir = Right::CollisionDirection
            end
            if result[].y == b.y
                println("colliding from top at depth $(depthVertical)")
                verticalCollisionDir = Bottom::CollisionDirection
            elseif result[].y == a.y
                println("colliding from bottom at depth $(depthVertical)") 
                verticalCollisionDir = Top::CollisionDirection
            end
            
            if min(depthHorizontal, depthVertical) == depthHorizontal
                return (horizontalCollisionDir, -depthHorizontal/SCALE_UNITS, isLineIntersectionL || isLineIntersectionR)
            else
                return (verticalCollisionDir, depthVertical/SCALE_UNITS, isLineIntersectionL || isLineIntersectionR)
            end
        end

        SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);

        return (None::CollisionDirection, 0.0, isLineIntersectionL || isLineIntersectionR)
    end

    function check_collision1(colliderA::InternalCollider, colliderB::InternalCollider)
        posA = colliderA.parent.transform.position * SCALE_UNITS - ((colliderA.size * SCALE_UNITS - SCALE_UNITS) / 2)
        posB = colliderB.parent.transform.position * SCALE_UNITS - ((colliderB.size * SCALE_UNITS - SCALE_UNITS) / 2)
        offsetAX = colliderA.offset.x * SCALE_UNITS
        offsetAY = colliderA.offset.y * SCALE_UNITS
        offsetBX = colliderB.offset.x * SCALE_UNITS
        offsetBY = colliderB.offset.y * SCALE_UNITS
        colliderAXSize = colliderA.parent.transform.scale.x * colliderA.size.x * SCALE_UNITS
        colliderAYSize = colliderA.parent.transform.scale.y * colliderA.size.y * SCALE_UNITS
        colliderBXSize = colliderB.parent.transform.scale.x * colliderB.size.x * SCALE_UNITS
        colliderBYSize = colliderB.parent.transform.scale.y * colliderB.size.y * SCALE_UNITS

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

        posA = colliderA.parent.transform.position * SCALE_UNITS - ((colliderA.parent.transform.scale * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderA.size * SCALE_UNITS - SCALE_UNITS) / 2)
        posB = colliderB.parent.transform.position * SCALE_UNITS - ((colliderB.parent.transform.scale * SCALE_UNITS - SCALE_UNITS) / 2) - ((colliderB.size * SCALE_UNITS - SCALE_UNITS) / 2)
        offsetAX = colliderA.offset.x * SCALE_UNITS
        offsetBX = colliderB.offset.x * SCALE_UNITS
        colliderAXSize = colliderA.size.x * SCALE_UNITS
        colliderBXSize = colliderB.size.x * SCALE_UNITS

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
