include("Collider.jl")
include("Enums.jl")
using SimpleDirectMediaLayer.LibSDL2

function hireTimeInSeconds()
    t = SDL_GetTicks()
    t *= 0.001
    return t
end

function checkCollision(colliderA::Collider, colliderB::Collider)
    nameA = colliderA.getParent().getName()
    nameB = colliderB.getParent().getName()
    posA = colliderA.getParent().getTransform().getPosition()
    posB = colliderB.getParent().getTransform().getPosition()
    #Calculate the sides of rect A
    leftA = posA.x
    rightA = posA.x + colliderA.getSize().x
    topA = posA.y
    bottomA = posA.y + colliderA.getSize().y
    #Calculate the sides of rect B
    leftB = posB.x
    rightB = posB.x + colliderB.getSize().x
    topB = posB.y
    bottomB = posB.y + colliderB.getSize().y
    
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
        return (left ? LeftSide::ColliderLocation : None::CollisionDirection, dist)
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
        #println("Collision from below")
        return (Bottom::CollisionDirection, collisionSide)
    elseif collisionSide == depthTop
        #println("Collision from above")
        return (Top::CollisionDirection, collisionSide)
    elseif collisionSide == depthLeft
        #println("Collision from the left")
        return (Left::CollisionDirection, collisionSide)
    elseif collisionSide == depthRight
        #println("Collision from the right")
        return (Right::CollisionDirection, collisionSide)
    end 
    
    throw
end