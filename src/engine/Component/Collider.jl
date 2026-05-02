module ColliderModule
    include("../../utils/Enums.jl")
    using ..Component.JulGame
    import ..Component

    @inline function _c_transform(ent::JulGame.IEntity)::Component.TransformModule.Transform
        getfield(ent, :transform)::Component.TransformModule.Transform
    end

    @inline function _c_rigidbody(ent::JulGame.IEntity)::Union{Component.RigidbodyModule.InternalRigidbody, Ptr{Nothing}}
        getfield(ent, :rigidbody)::Union{Component.RigidbodyModule.InternalRigidbody, Ptr{Nothing}}
    end

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
        parent::JulGame.IEntity
        size::Math.Vector2f
        tag::String
        
        function InternalCollider(parent::JulGame.IEntity, size::Math.Vector2f = Math.Vector2f(1,1), offset::Math.Vector2f = Math.Vector2f(), tag::String="Default", isTrigger::Bool=false, isPlatformerCollider::Bool = false, enabled::Bool=true)
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
        main = JulGame.MAIN
        scene = getfield(main, :scene)
        colliders = getfield(scene, :colliders)
        optimize = getfield(main, :optimizeSpriteRendering)::Bool
        onGround = false
        this_ent = this.parent::JulGame.IEntity
        if !(getfield(this_ent, :isActive)::Bool) || !this.enabled
            return
        end

        this_transform = _c_transform(this_ent)
        this_pos_x = (getfield(this_transform, :position)::Math._Vector3{Float64}).x
        this_size_x = Component.get_size(this).x

        for collider_any in colliders
            collider = collider_any::InternalCollider
            other_ent = collider.parent::JulGame.IEntity
            if !(getfield(other_ent, :isActive)::Bool) || !collider.enabled
                continue
            end

            if this != collider
                other_tf = _c_transform(other_ent)
                other_pos_x = (getfield(other_tf, :position)::Math._Vector3{Float64}).x
                other_size_x = Component.get_size(collider).x
                if (other_pos_x > this_pos_x + this_size_x) || ((other_pos_x + other_size_x < this_pos_x) && optimize)
                    continue
                end

                transform = this_transform
                collision = check_collision(this, collider)
                transform = this_transform
                tp = getfield(transform, :position)::Math._Vector3{Float64}
                if collision[1] == Top::CollisionDirection
                    push!(this.currentCollisions, collider)
                    for eventToCall in this.collisionEvents
                        Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                    end
                    if !collider.isTrigger && !this.isTrigger
                        Component.set_position(transform, Math.Vector2f(tp.x, tp.y + collision[2]))
                    end
                end
                if collision[1] == Left::CollisionDirection
                    push!(this.currentCollisions, collider)
                    for eventToCall in this.collisionEvents
                        Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                    end
                    if !collider.isTrigger && !this.isTrigger
                        Component.set_position(transform, Math.Vector2f(tp.x + collision[2], tp.y))
                    end
                end
                if collision[1] == Right::CollisionDirection
                    push!(this.currentCollisions, collider)
                    for eventToCall in this.collisionEvents
                        Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                    end
                    if !collider.isTrigger && !this.isTrigger
                        Component.set_position(transform, Math.Vector2f(tp.x - collision[2], tp.y))
                    end
                end
                if collision[1] == Bottom::CollisionDirection
                    push!(this.currentCollisions, collider)
                    for eventToCall in this.collisionEvents
                        Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                    end
                    rb_this = _c_rigidbody(this_ent)
                    if !collider.isTrigger && !this.isTrigger
                        Component.set_position(transform, Math.Vector2f(tp.x, tp.y - collision[2]))
                        if rb_this !== C_NULL && (getfield(rb_this, :velocity)::Math._Vector2{Float64}).y >= 0
                            setfield!(rb_this, :grounded, true)
                        end
                    end
                end
                if collision[1] == Below::ColliderLocation
                    push!(this.currentCollisions, collider)
                    for eventToCall in this.collisionEvents
                        Base.invokelatest(eventToCall,(collider=collider, direction=collision[1]))
                    end
                end
                # Read ground state after handlers may have set `grounded` on the rigidbody.
                rb_chk = _c_rigidbody(this_ent)
                if collision[3] && rb_chk !== C_NULL && (getfield(rb_chk, :grounded)::Bool)
                    onGround = true
                end
            end

            rb_loop = _c_rigidbody(this_ent)
            if rb_loop !== C_NULL
                setfield!(rb_loop, :grounded, onGround)
            end
        end

        return length(this.currentCollisions) > 0
    end

    function Component.add_collision_event(this::InternalCollider, event)
        push!(this.collisionEvents, event)
    end        

    function check_collision(colliderA::InternalCollider, colliderB::InternalCollider)
        su = JulGame.scale_units()::Float64
        ta = _c_transform(colliderA.parent::JulGame.IEntity)
        tb = _c_transform(colliderB.parent::JulGame.IEntity)
        posA = (getfield(ta, :position)::Math._Vector3{Float64} + colliderA.offset) * su
        posB = (getfield(tb, :position)::Math._Vector3{Float64} + colliderB.offset) * su
        sca = getfield(ta, :scale)::Math._Vector3{Float64}
        scb = getfield(tb, :scale)::Math._Vector3{Float64}
        colliderAXSize = sca.x * colliderA.size.x * su
        colliderAYSize = sca.y * colliderA.size.y * su
        colliderBXSize = scb.x * colliderB.size.x * su
        colliderBYSize = scb.y * colliderB.size.y * su

        ri32(x::Float64)::Int32 = Core.Int32(Base.round(x))

        a = SDL2.SDL_Rect(ri32(posA.x), ri32(posA.y), ri32(colliderAXSize), ri32(colliderAYSize))
        b = SDL2.SDL_Rect(ri32(posB.x), ri32(posB.y), ri32(colliderBXSize), ri32(colliderBYSize))

        rgba = (r = Ref(UInt8(0)), g = Ref(UInt8(0)), b = Ref(UInt8(0)), a = Ref(UInt8(255)))
        # SDL2.SDL_GetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r, rgba.g, rgba.b, rgba.a)
        # SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, 0, 255, 255, SDL2.SDL_ALPHA_OPAQUE)

        result = Base.Ref(SDL2.SDL_Rect(0, 0, 0, 0))
        isIntersection = SDL2.SDL_IntersectRect(Base.Ref(a), Base.Ref(b), result)

        main = JulGame.MAIN
        scene = getfield(main, :scene)
        camera = getfield(scene, :camera)
        camS = JulGame.pixels_per_world_unit(camera)
        cameraDiff = camera !== nothing ?
                     Math.Vector2((camera.position.x + camera.offset.x) * camS, (camera.position.y + camera.offset.y) * camS) :
                     Math.Vector2(0, 0)
        isLineIntersectionL = SDL2.SDL_IntersectRectAndLine(
            Base.Ref(b),
            Base.Ref(Math.TypeConversions.safe_int32_convert(Base.round(posA.x))),
            Base.Ref(Math.TypeConversions.safe_int32_convert(Base.round(posA.y + 32.0))),
            Base.Ref(Math.TypeConversions.safe_int32_convert(Base.round(posA.x))),
            Base.Ref(Math.TypeConversions.safe_int32_convert(Base.round(posA.y + 80.0))),
        )
        #SDL2.SDL_RenderDrawLine(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, round(posA.x - cameraDiff.x), round(posA.y + 32 - cameraDiff.y), round(posA.x - cameraDiff.x), round(posA.y + 80 - cameraDiff.y))

        isLineIntersectionR = SDL2.SDL_IntersectRectAndLine(
            Base.Ref(b),
            Base.Ref(Math.TypeConversions.safe_int32_convert(Base.round(posA.x + colliderAXSize))),
            Base.Ref(Math.TypeConversions.safe_int32_convert(Base.round(posA.y + 32.0))),
            Base.Ref(Math.TypeConversions.safe_int32_convert(Base.round(posA.x + colliderAXSize))),
            Base.Ref(Math.TypeConversions.safe_int32_convert(Base.round(posA.y + 80.0))),
        )
        #SDL2.SDL_RenderDrawLine(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, round(posA.x - cameraDiff.x + colliderAXSize), round(posA.y + 32 - cameraDiff.y), round(posA.x - cameraDiff.x + colliderAXSize), round(posA.y + 80 - cameraDiff.y))
        if isLineIntersectionL == SDL2.SDL_TRUE
            isLineIntersectionL = true
        else
            isLineIntersectionL = false
        end

        if isLineIntersectionR == SDL2.SDL_TRUE
            isLineIntersectionR = true
        else
            isLineIntersectionR = false
        end

        if isIntersection == SDL2.SDL_TRUE
            a1 = SDL2.SDL_FRect(posA.x, posA.y, colliderAXSize, colliderAYSize)
            b1 = SDL2.SDL_FRect(posB.x, posB.y, colliderBXSize, colliderBYSize)
            # SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(a1))
            # SDL2.SDL_RenderDrawRectF(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, Ref(b1))
            # SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);

            # println("col a (me): $(a)")
            # println("col b (other): $(b)")
            # println("result: $(result)")
            # println("$(colliderA.parent.name) is colliding with $(colliderB.parent.name)")

            depthHorizontal = result[].w
            depthVertical = result[].h
            horizontalCollisionDir = None::CollisionDirection
            verticalCollisionDir = None::CollisionDirection
            if result[].x == b.x && !colliderB.isPlatformerCollider
                @debug "colliding from left at depth $(depthHorizontal)"
                horizontalCollisionDir = Left::CollisionDirection
            elseif result[].x == a.x && !colliderB.isPlatformerCollider
                @debug "colliding from right at depth $(depthHorizontal)"
                horizontalCollisionDir = Right::CollisionDirection
            end
            if result[].y == b.y
                @debug "colliding from top at depth $(depthVertical)"
                rbA = _c_rigidbody(colliderA.parent::JulGame.IEntity)
                if colliderB.isPlatformerCollider && rbA !== C_NULL
                    if (getfield(rbA, :velocity)::Math._Vector2{Float64}).y < 0
                        return (None::CollisionDirection, 0.0, isLineIntersectionL || isLineIntersectionR)
                    end
                end
                verticalCollisionDir = Bottom::CollisionDirection
            elseif result[].y == a.y
                @debug "colliding from bottom at depth $(depthVertical)"
                if colliderB.isPlatformerCollider
                    return (None::CollisionDirection, 0.0, isLineIntersectionL || isLineIntersectionR)
                end
                verticalCollisionDir = Top::CollisionDirection
            end

            if min(depthHorizontal, depthVertical) == depthHorizontal
                return (horizontalCollisionDir, -depthHorizontal/su, isLineIntersectionL || isLineIntersectionR)
            else
                return (verticalCollisionDir, depthVertical/su, isLineIntersectionL || isLineIntersectionR)
            end
        end

        #SDL2.SDL_SetRenderDrawColor(JulGame.Renderer::Ptr{SDL2.SDL_Renderer}, rgba.r[], rgba.g[], rgba.b[], rgba.a[]);

        return (None::CollisionDirection, 0.0, isLineIntersectionL || isLineIntersectionR)
    end

    function Component.duplicate(this::InternalCollider, parent::JulGame.IEntity)
        newCollider = InternalCollider(parent, this.size, this.offset, this.tag, this.isTrigger, this.isPlatformerCollider, this.enabled)
        newCollider.collisionEvents = this.collisionEvents
        return newCollider
    end
end
