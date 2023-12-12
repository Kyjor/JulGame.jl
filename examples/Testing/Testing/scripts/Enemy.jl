using JulGame.Macros
using JulGame.MainLoop

mutable struct Enemy
    animator
    isFacingRight
    parent

    function Enemy()
        this = new()
        
        this.parent = C_NULL

        return this
    end
end

function Base.getproperty(this::Enemy, s::Symbol)
    if s == :initialize
        function()
            this.animator = this.parent.getAnimator()
            this.animator.currentAnimation = this.animator.animations[1]
            this.animator.currentAnimation.animatedFPS = 2
            this.parent.getSprite().isFlipped = true
        end
    elseif s == :update
        function(deltaTime)
           
        end
    elseif s == :setParent
        function(parent)
            this.parent = parent
            collisionEvent = @event begin
                this.handleCollisions()
            end
            this.parent.getComponent(Collider).addCollisionEvent(collisionEvent)
        end
    elseif s == :handleCollisions
        function()
            return
            collider = this.parent.getComponent(Collider)
            for collision in collider.currentCollisions
                if collision.tag == "ground"
                end
            end
        end
    else
        getfield(this, s)
    end
end