include("Collider.jl")
include("Constants.jl")
include("Enums.jl")
using SimpleDirectMediaLayer.LibSDL2

function hireTimeInSeconds()
    t = SDL_GetTicks()
    t *= 0.001
    return t
end

# Todo: move to a separate file specific to collisions
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
        println("Collision from above")
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