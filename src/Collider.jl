include("SceneInstance.jl")
include("Math/Vector2f.jl")
using SimpleDirectMediaLayer.LibSDL2

mutable struct Collider
    
   size::Vector2f
   offset::Vector2f
   parent
   tag::String
    
    function Collider(size::Vector2f, offset::Vector2f, tag::String)
        this = new()

        this.size = size
        this.offset = offset
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
        function(size::Vector2f)
            this.size = size
        end
    elseif s == :getOffset
        function()
            return this.offset
        end
    elseif s == :setOffset
        function(offset::Vector2f)
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
            colliders = SceneInstance.colliders
            #Only check the player against other colliders
            counter = 1
            for colliderB in colliders
                #TODO: Skip any out of a certain range of the player. This will prevent a bunch of unnecessary collision checks
                if !colliderB.getParent().isActive
                    continue
                end
                if colliders[1] != colliderB
                    collision = checkCollision(colliders[1], colliderB)
                    transform = colliders[1].getParent().getTransform()
                    if collision[1] == Top::CollisionDirection
                        #Begin to overlap, correct position
                        transform.setPosition(Vector2f(transform.getPosition().x, transform.getPosition().y + collision[2]))
                    elseif collision[1] == Left::CollisionDirection
                        #Begin to overlap, correct position
                        transform.setPosition(Vector2f(transform.getPosition().x + collision[2], transform.getPosition().y))
                    elseif collision[1] == Right::CollisionDirection
                        #Begin to overlap, correct position
                        transform.setPosition(Vector2f(transform.getPosition().x - collision[2], transform.getPosition().y))
                    elseif collision[1] == Bottom::CollisionDirection
                        #Begin to overlap, correct position
                        transform.setPosition(Vector2f(transform.getPosition().x, transform.getPosition().y - collision[2]))
                        this.parent.getRigidbody().grounded = true
                        break
                    elseif collision[1] == Below::ColliderLocation
                        println("hit")
                    elseif this.parent.getRigidbody().grounded && counter == length(colliders) && collision[1] != Bottom::CollisionDirection # If we're on the last collider to check and we haven't collided with anything yet
                        this.parent.getRigidbody().grounded = false
                    end
                end
                counter += 1
            end
        end
    elseif s == :update
        function()
            
        end
    else
        try
            getfield(this, s)
        catch e
            println(e)
        end
    end
end