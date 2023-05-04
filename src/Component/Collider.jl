module ColliderModule
include("../Enums.jl")
using ..Component.engine
global const SCALE_UNITS = Ref{Float64}(64.0)[]
global const GRAVITY = Ref{Float64}(9.81)[]

export Collider
mutable struct Collider
    collisionEvents
    currentCollisions
    enabled::Bool
    offset::Math.Vector2f
    parent
    size::Math.Vector2f
    tag::String
    
    function Collider(size::Math.Vector2f, offset::Math.Vector2f, tag::String)
        this = new()

        this.collisionEvents = []
        this.currentCollisions = []
        this.enabled = true
        this.offset = offset
        this.size = size
        this.tag = tag

        return this
    end

    function Collider(size::Math.Vector2f, tag::String)
        this = new()

        this.collisionEvents = []
        this.currentCollisions = []
        this.enabled = true
        this.offset = Math.Vector2f()
        this.size = size
        this.tag = tag

        return this
    end
end

function Base.getproperty(this::Collider, s::Symbol)
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
        function(parent)
            this.parent = parent
        end
    elseif s == :checkCollisions
        function()
            colliders = MAIN.scene.colliders
            #Only check the player against other colliders
            counter = 0
            onGround = false
            for i in 1:length(colliders)
                #TODO: Skip any out of a certain range of this. This will prevent a bunch of unnecessary collision checks
                if !colliders[i].getParent().isActive || !colliders[i].enabled
                    if this.parent.getRigidbody().grounded && i == length(colliders)
                        this.parent.getRigidbody().grounded = false
                    end
                    continue
                end
                if this != colliders[i]
                    collision = this.checkCollision(this, colliders[i])
                    transform = this.getParent().getTransform()
                    if collision[1] == Top::CollisionDirection
                        push!(this.currentCollisions, colliders[i])
                        for eventToCall in this.collisionEvents
                            eventToCall()
                        end
                        #Begin to overlap, correct position
                        transform.setPosition(Math.Vector2f(transform.getPosition().x, transform.getPosition().y + collision[2]))
                    end
                    if collision[1] == Left::CollisionDirection
                        push!(this.currentCollisions, colliders[i])
                        for eventToCall in this.collisionEvents
                            eventToCall()
                        end
                        #Begin to overlap, correct position
                        transform.setPosition(Math.Vector2f(transform.getPosition().x + collision[2], transform.getPosition().y))
                    end
                    if collision[1] == Right::CollisionDirection
                        push!(this.currentCollisions, colliders[i])
                        for eventToCall in this.collisionEvents
                            eventToCall()
                        end
                        #Begin to overlap, correct position
                        transform.setPosition(Math.Vector2f(transform.getPosition().x - collision[2], transform.getPosition().y))
                    end
                    if collision[1] == Bottom::CollisionDirection
                        push!(this.currentCollisions, colliders[i])
                        for eventToCall in this.collisionEvents
                            eventToCall()
                        end
                        #Begin to overlap, correct position
                        transform.setPosition(Math.Vector2f(transform.getPosition().x, transform.getPosition().y - collision[2]))
                        onGround = true
                    end
                    if collision[1] == Below::ColliderLocation
                        push!(this.currentCollisions, colliders[i])
                        for eventToCall in this.collisionEvents
                            eventToCall()
                        end
                    end
                end
            end
            this.parent.getRigidbody().grounded = onGround
            this.currentCollisions = []
        end
    elseif s == :update
        function()
            
        end
    elseif s == :addCollisionEvent
        function(event)
            push!(this.collisionEvents, event)
        end
    elseif s == :checkCollision
        function checkCollision(colliderA::Collider, colliderB::Collider)
            nameA = colliderA.getParent().getName()
            nameB = colliderB.getParent().getName()
            posA = colliderA.getParent().getTransform().getPosition() * SCALE_UNITS
            posB = colliderB.getParent().getTransform().getPosition() * SCALE_UNITS
            #Calculate the sides of rect A
            leftA = posA.x
            rightA = posA.x + colliderA.getSize().x * SCALE_UNITS
            topA = posA.y
            bottomA = posA.y + colliderA.getSize().y * SCALE_UNITS
            #Calculate the sides of rect B
            leftB = posB.x
            rightB = posB.x + colliderB.getSize().x * SCALE_UNITS
            topB = posB.y
            bottomB = posB.y + colliderB.getSize().y * SCALE_UNITS
            
            # println("ColliderA: $nameA ColliderB: $nameB")
            # println("bottomA: $bottomA , topB: $topB" )
            # println("topA: $topA , bottomB: $bottomB" )
            # println("rightA: $rightA , leftB: $leftB" )
            # println("leftA: $leftA , rightB: $rightB" )
        
             #If any of the sides from A are outside of B
            depthBottom = 0.0
            depthTop = 0.0
            depthRight = 0.0
            depthLeft = 0.0
            if bottomA <= topB
                dist = topB - bottomA 
                below = dist == 0.0 && rightA > leftB && leftA < rightB
                #println(below)
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
            
            if collisionSide == depthBottom
                #println("Collision from below ", collisionSide/SCALE_UNITS)
                return (Bottom::CollisionDirection, collisionSide/SCALE_UNITS)
            elseif collisionSide == depthTop
                #println("Collision from above")
                return (Top::CollisionDirection, collisionSide/SCALE_UNITS)
            elseif collisionSide == depthLeft
                #println("Collision from the left")
                return (Left::CollisionDirection, collisionSide/SCALE_UNITS)
            elseif collisionSide == depthRight
                #println("Collision from the right")
                return (Right::CollisionDirection, collisionSide/SCALE_UNITS)
            end 
            
            throw
        end
    elseif s == :setVector2fValue
        function(field, x, y)
            setfield!(this, field, Math.Vector2f(x,y))
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end
end