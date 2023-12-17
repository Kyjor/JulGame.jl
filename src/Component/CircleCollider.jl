
module CircleColliderModule
    using ..Component.JulGame
    using ..Component.ColliderModule

    export CircleCollider
    mutable struct CircleCollider
        collisionEvents::Array{Any}
        currentCollisions::Array{Collider}
        diameter::Float64
        enabled::Bool
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
            end
        elseif s == :setParent
            function(parent::Any)
                this.parent = parent
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
            if distanceSquared(a.offset.x, a.offset.y, b.offset.x, b.offset.y)::Float64 < totalRadiusSquared
                # The circles have collided
                return true
            end

            # If not
            return false
    end

    function CheckCollision(a::CircleCollider, b::Collider)
        # Closest point on collision box
        cX, cY = 0, 0

        # Find closest x offset
        if a.offset.x < b.offset.x
            cX = b.offset.x
        elseif a.offset.x > b.offset.x + b.size.x
            cX = b.offset.x + b.size.x
        else
            cX = a.offset.x
        end

        # Find closest y offset
        if a.offset.y < b.offset.y
            cY = b.offset.y
        elseif a.offset.y > b.offset.y + b.size.y
            cY = b.offset.y + b.size.y
        else
            cY = a.offset.y
        end

        # If the closest point is inside the circle
        if distanceSquared(a.offset.x, a.offset.y, cX, cY)::Float64 < (a.diameter / 2)^2
            # This circle and the rectangle have collided
            return true
        end

        # If the shapes have not collided
        return false
    end

    function distanceSquared(x1::Int, y1::Int, x2::Int, y2::Int)
        deltaX = x2 - x1
        deltaY = y2 - y1
        return deltaX^2 + deltaY^2
    end
end
