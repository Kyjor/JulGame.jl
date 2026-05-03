
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
        JulGame.juliac_trim_active() && return nothing
        for eventToCall in events
            JulGame.trim_call0(eventToCall)
        end
        return nothing
    end

    @inline function _circle_dispatch_collision_events!(events::Vector{Function})::Nothing
        _circle_collider_invoke_collision_events!(events)
        return nothing
    end

    @inline function _ccircle_world_xy(ent::JulGame.IEntity, off::Math.Vector2f)::Math._Vector2{Float64}
        tf = getfield(ent, :transform)::Component.TransformModule.Transform
        p = getfield(tf, :position)::Math._Vector3{Float64}
        return Math._Vector2{Float64}(Float64(p.x) + Float64(off.x), Float64(p.y) + Float64(off.y))
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
                if CheckIfResting(this, oc)[1] === true && length(this.currentRests) > 0 && !(oc in this.currentRests)
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
                if collision[1] === true
                    push!(this.currentRests, oc)
                    _circle_dispatch_collision_events!(this.collisionEvents)
                    pos = getfield(transform, :position)::Math._Vector3{Float64}
                    Component.set_position(transform, Math._Vector2{Float64}(pos.x, pos.y - collision[2]))
                    this.isGrounded = true
                end
            end
        end
        for i in eachindex(this.currentRests)
            if CheckIfResting(this, this.currentRests[i])[1] === false
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
        if DistanceSquared(Float64(a.offset.x), Float64(a.offset.y), Float64(b.offset.x), Float64(b.offset.y)) < totalRadiusSquared
            # The circles have collided
            return true
        end
        # If not
        return false
    end

    function check_collision(a::InternalCircleCollider, b::InternalCollider)::Tuple{Bool, Float64}
        posA = _ccircle_world_xy(a.parent::JulGame.IEntity, a.offset)
        posB = _ccircle_world_xy(b.parent::JulGame.IEntity, b.offset)
        bx = Float64(b.size.x)
        by = Float64(b.size.y)

        cX::Float64 = 0.0
        cY::Float64 = 0.0

        # Find closest x offset
        if posA.x < posB.x
            cX = posB.x
        elseif posA.x > posB.x + bx
            cX = posB.x + bx
        else
            cX = posA.x
        end

        # Find closest y offset
        if posA.y < posB.y
            cY = posB.y
        elseif posA.y > posB.y + by
            cY = posB.y + by
        else
            cY = posA.y
        end

        distanceSquared::Float64 = DistanceSquared(posA.x, posA.y, cX, cY)
        rad = Float64(a.diameter) * 0.5
        rsq = rad * rad
        if distanceSquared < rsq
            return (true, distanceSquared)
        end
        return (false, distanceSquared)
    end

    function CheckIfResting(a::InternalCircleCollider, b::InternalCollider)::Tuple{Bool, Float64}
        posA = _ccircle_world_xy(a.parent::JulGame.IEntity, a.offset)
        posB = _ccircle_world_xy(b.parent::JulGame.IEntity, b.offset)
        bx = Float64(b.size.x)
        radius = Float64(a.diameter) * 0.5

        cX::Float64 = 0.0

        if posA.x < posB.x
            cX = posB.x
        elseif posA.x > posB.x + bx
            cX = posB.x + bx
        else
            cX = posA.x
        end

        dx = cX - posA.x
        distance = dx * dx
        # If the closest point is inside the circle
        rrest = radius * 0.5
        thr = rrest * rrest
        if distance < thr
            return (true, distance)
        end
        return (false, distance)
    end

    function DistanceSquared(x1::Float64, y1::Float64, x2::Float64, y2::Float64)::Float64
        dx = x2 - x1
        dy = y2 - y1
        return dx * dx + dy * dy
    end
end
