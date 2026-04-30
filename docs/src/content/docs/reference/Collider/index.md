---
title: Collider Component
description: Add collision detection to your game objects in JulGame
---

# Collider Component

The Collider component allows you to add collision detection to your game entities. It defines a rectangular area that can interact with other colliders in the game world.

## Overview

The Collider component handles:
- Collision detection between entities
- Trigger zones for event handling
- Platformer-specific collision behavior
- Collision callbacks

## Adding a Collider Component

```julia
# Create a new entity
entity = Entity("Player")

# Create and add a collider component
collider = ColliderModule.create(64, 64)  # width, height
entity.addComponent(collider)

# Add to scene
scene.addEntity(entity)
```

## Function Reference

### create()

```julia
ColliderModule.create(
    width::Number,                         # Width of the collider
    height::Number,                        # Height of the collider
    offsetX::Number = 0,                   # X offset from entity center
    offsetY::Number = 0,                   # Y offset from entity center
    tag::String = "Default",               # Collision tag for filtering
    isTrigger::Bool = false,               # Whether it's a trigger collider
    isPlatformerCollider::Bool = false,    # Whether it's a platformer collider
    enabled::Bool = true                   # Whether the collider is active
)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `size` | `Math.Vector2f` | Width and height of the collider |
| `offset` | `Math.Vector2f` | Offset from the entity's center |
| `tag` | `String` | Collision tag for filtering collisions |
| `isTrigger` | `Bool` | Whether the collider triggers events without physical response |
| `isPlatformerCollider` | `Bool` | Whether the collider uses platformer-specific behavior |
| `enabled` | `Bool` | Whether the collider is active |

## Collision Events

Collision events are handled through script functions:

```julia
# Define collision handlers in your script struct
function onCollisionEnter(script::YourScript, entity, other)
    println("Collision started with $(other.name)")
    # Handle collision start
end

function onCollisionStay(script::YourScript, entity, other)
    # Handle ongoing collision
end

function onCollisionExit(script::YourScript, entity, other)
    println("Collision ended with $(other.name)")
    # Handle collision end
end

function onTriggerEnter(script::YourScript, entity, other)
    println("Entered trigger zone $(other.name)")
    # Handle trigger entry
end

function onTriggerExit(script::YourScript, entity, other)
    println("Exited trigger zone $(other.name)")
    # Handle trigger exit
end
```

## Examples

### Basic Collider

```julia
# Create a simple collider
collider = ColliderModule.create(
    50,                 # Width
    50,                 # Height
    0,                  # No X offset
    0                   # No Y offset
)
entity.addComponent(collider)
```

### Offset Collider

```julia
# Create a collider with an offset (useful for characters)
collider = ColliderModule.create(
    40,                 # Width
    80,                 # Height
    0,                  # No X offset
    10                  # Y offset (moves collider down by 10 units)
)
entity.addComponent(collider)
```

### Trigger Zone

```julia
# Create a trigger zone (doesn't cause physical collision)
triggerZone = ColliderModule.create(
    100,                # Width
    100,                # Height
    0,                  # No X offset
    0,                  # No Y offset
    "TriggerZone",      # Custom tag
    true                # Is a trigger
)
entity.addComponent(triggerZone)
```

### Platformer Collider

```julia
# Create a collider optimized for platformer games
platformerCollider = ColliderModule.create(
    32,                 # Width
    64,                 # Height
    0,                  # No X offset
    0,                  # No Y offset
    "Player",           # Custom tag
    false,              # Not a trigger
    true                # Is a platformer collider
)
entity.addComponent(platformerCollider)
```

## Collision Detection and Response

When non-trigger colliders intersect, JulGame automatically handles basic collision response:

1. Collision is detected between two colliders
2. `onCollisionEnter` is called on both entities' scripts
3. Entities are prevented from overlapping (if not triggers)
4. While overlapping, `onCollisionStay` is called each frame
5. When entities separate, `onCollisionExit` is called

## Collision Filtering with Tags

You can use tags to filter which colliders should interact:

```julia
function onCollisionEnter(script::YourScript, entity, other)
    collider = other.getComponent("Collider")
    
    if collider.tag == "Enemy"
        # Handle enemy collision
    elseif collider.tag == "Collectible"
        # Handle collectible collision
    end
end
```

## Performance Considerations

- **Simpler is Better**: Use the simplest collision shapes possible
- **Disable When Not Needed**: Set `enabled = false` for colliders that don't need to be checked
- **Limit Colliders**: Keep the number of active colliders reasonable for performance
- **Broad Phase**: JulGame uses a spatial partitioning system for efficient collision detection

## See Also

- [CircleCollider](/JulGame.jl/reference/CircleCollider/) - For circular collision areas
- [Rigidbody](/JulGame.jl/reference/Rigidbody/) - For physics-based movement
- [Transform](/JulGame.jl/reference/Transform/) - For positioning entities 