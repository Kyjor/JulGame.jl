
module CircleColliderModule
    using ..Component.JulGame
    using ..Component.ColliderModule
    import ..Component

    export CircleCollider
    struct CircleCollider
        diameter::Float64
        enabled::Bool
        isTrigger::Bool
        offset::Math.Vector2f
        tag::String
    end

    export InternalCircleCollider
    mutable struct InternalCircleCollider
        collisionEvents::Vector{Function}
        currentCollisions::Vector{InternalCollider}
        currentRests::Vector{InternalCollider}
        diameter::Float64
        enabled::Bool
        isGrounded::Bool
        isTrigger::Bool
        offset::Math.Vector2f
        parent::JulGame.IEntity
        tag::String

        function InternalCircleCollider(parent::JulGame.IEntity, diameter::Float64, offset::Math.Vector2f = Math.Vector2f(), tag::String="Default", isTrigger::Bool=false, enabled::Bool=true)
            this = new()

            this.collisionEvents = Function[]
            this.currentCollisions = InternalCollider[]
            this.currentRests = InternalCollider[]
            this.diameter = diameter
            this.enabled = enabled
            this.isGrounded = false
            this.isTrigger = isTrigger
            this.offset = offset
            this.parent = parent
            this.tag = tag

            return this
        end
    end

    @Base.noinline function _circle_collider_invoke_collision_events!(events::Vector{Function})::Nothing
        for eventToCall in events
            eventToCall()
        end
        return nothing
    end

    @inline function _circle_dispatch_collision_events!(events::Vector{Function})::Nothing
        JulGame.juliac_trim_active() && return nothing
        _circle_collider_invoke_collision_events!(events)
        return nothing
    end

    function Component.get_size(this::InternalCircleCollider)
        d = this.diameter
        return Math.Vector2f(d, d)
    end

    function Component.check_collisions(this::InternalCircleCollider)
        main = JulGame.current_main()
        scene = getfield(main, :scene)::JulGame.SceneModule.Scene
        colliders = getfield(scene, :colliders)
        this_ent = this.parent::JulGame.IEntity
        rb = getfield(this_ent, :rigidbody)::Union{Component.RigidbodyModule.InternalRigidbody, Ptr{Nothing}}
        rb === C_NULL && return
        this.isGrounded = (getfield(rb, :grounded)::Bool)

        for i in eachindex(colliders)
            oc = colliders[i]::InternalCollider
            oent = oc.parent::JulGame.IEntity
            if !(getfield(oent, :isActive)::Bool) || !oc.enabled
                if (getfield(rb, :grounded)::Bool) && i == length(colliders)
                    setfield!(rb, :grounded, false)
                end
                continue
            end
            if (getfield(rb, :velocity)::Math._Vector2{Float64}).y >= 0
                collision = check_collision(this, oc)
                if CheckIfResting(this, oc)[1] == true && length(this.currentRests) > 0 && !(oc in this.currentRests)
                    for j in eachindex(this.currentRests)
                        rj = this.currentRests[j]
                        rjp = rj.parent::JulGame.IEntity
                        otp_tf = getfield(oent, :transform)::Component.TransformModule.Transform
                        rt_tf = getfield(rjp, :transform)::Component.TransformModule.Transform
                        if (getfield(rt_tf, :position)::Math._Vector3{Float64}).y == (getfield(otp_tf, :position)::Math._Vector3{Float64}).y && Component.get_size(rj).y == Component.get_size(oc).y
                            push!(this.currentRests, oc)
                            break
                        end
                    end
                end
                transform = getfield(this_ent, :transform)::Component.TransformModule.Transform
                if collision[1] == true
                    push!(this.currentRests, oc)
                    _circle_dispatch_collision_events!(this.collisionEvents)
                    pos = getfield(transform, :position)::Math._Vector3{Float64}
                    Component.set_position(transform, Math._Vector2{Float64}(pos.x, pos.y - collision[2]))
                    this.isGrounded = true
                end
            end
        end
        for i in eachindex(this.currentRests)
            if CheckIfResting(this, this.currentRests[i])[1] == false
                deleteat!(this.currentRests, i)
                break
            end
        end

        setfield!(rb, :grounded, length(this.currentRests) > 0 && (getfield(rb, :velocity)::Math._Vector2{Float64}).y >= 0)
        this.currentCollisions = InternalCollider[]
    end

    function Component.add_collision_event(this::InternalCircleCollider, event)
        push!(this.collisionEvents, event)
    end   

    function check_collision(a::CircleCollider, b::CircleCollider)
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

    function check_collision(a::InternalCircleCollider, b::InternalCollider)
        # Closest point on collision box
        cX, cY = 0, 0

        posA = a.parent.transform.position + a.offset
        posB = b.parent.transform.position + b.offset

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

    function CheckIfResting(a::InternalCircleCollider, b::InternalCollider)
        # Closest point on collision box
        cX = 0

        posA = a.parent.transform.position + a.offset
        posB = b.parent.transform.position + b.offset
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

    function DistanceSquared(x1::Real, y1::Real, x2::Real, y2::Real)
        deltaX = x2 - x1
        deltaY = y2 - y1
        return deltaX^2 + deltaY^2
    end
end
