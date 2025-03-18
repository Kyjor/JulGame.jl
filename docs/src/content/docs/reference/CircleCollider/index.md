---
title: CircleCollider Component
description: Add circular collision detection to your game objects in JulGame
---

# CircleCollider Component

The CircleCollider component allows you to add circular collision detection to your game entities. It defines a circular area that can interact with other colliders in the game world.

## Overview

The CircleCollider component handles:
- Circular collision detection between entities
- Circular trigger zones for event handling
- Precise circular collisions for objects like balls, coins, etc.

## Adding a CircleCollider Component

```julia
# Create a new entity
entity = Entity("Ball")

# Create and add a circle collider component
circleCollider = CircleColliderModule.create(32)  # diameter
entity.addComponent(circleCollider)

# Add to scene
scene.addEntity(entity)
```

## Function Reference

### create()

```julia
CircleColliderModule.create(
    diameter::Number,                      # Diameter of the circle collider
    offsetX::Number = 0,                   # X offset from entity center
    offsetY::Number = 0,                   # Y offset from entity center
    tag::String = "Default",               # Collision tag for filtering
    isTrigger::Bool = false,               # Whether it's a trigger collider
    enabled::Bool = true                   # Whether the collider is active
)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `diameter` | `Float64` | Diameter of the circle collider |
| `offset` | `Math.Vector2f` | Offset from the entity's center |
| `tag` | `String` | Collision tag for filtering collisions |
| `isTrigger` | `Bool` | Whether the collider triggers events without physical response |
| `enabled` | `Bool` | Whether the collider is active |

## Collision Events

Collision events work the same way as with the regular Collider component:

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

### Basic CircleCollider

```julia
# Create a simple circle collider
circleCollider = CircleColliderModule.create(
    50                  # Diameter of 50 units
)
entity.addComponent(circleCollider)
```

### Offset CircleCollider

```julia
# Create a circle collider with an offset
circleCollider = CircleColliderModule.create(
    20,                 # Diameter
    0,                  # No X offset
    10                  # Y offset (moves collider down by 10 units)
)
entity.addComponent(circleCollider)
```

### Circular Trigger Zone

```julia
# Create a circular trigger zone
triggerZone = CircleColliderModule.create(
    100,                # Diameter
    0,                  # No X offset
    0,                  # No Y offset
    "TriggerZone",      # Custom tag
    true                # Is a trigger
)
entity.addComponent(triggerZone)
```

## Use Cases

Circle colliders are particularly useful for:

1. **Spherical Objects**: Balls, coins, projectiles
2. **Detection Ranges**: Enemy sight ranges, pick-up radiuses
3. **Explosions**: Area of effect damage
4. **Character Collisions**: For more natural character movement

## CircleCollider vs Regular Collider

| Feature | CircleCollider | Collider (Box) |
|---------|---------------|----------------|
| **Shape** | Circular | Rectangular |
| **Precision** | More precise for round objects | More precise for rectangular objects |
| **Performance** | Slightly more expensive | Slightly more efficient |
| **Use Case** | Round objects, ranges | Most game objects, platforms |

## Collision Types

CircleCollider can collide with:

- Other CircleColliders (circle-to-circle collision)
- Regular Colliders (circle-to-rectangle collision)

JulGame automatically handles the appropriate collision detection algorithm based on the collider types.

## Performance Considerations

- **Size Matters**: Keep the diameter appropriate to your game's scale
- **Disable When Not Needed**: Set `enabled = false` for colliders that don't need to be checked
- **Limit Colliders**: Keep the number of active colliders reasonable for performance

## See Also

- [Collider](/JulGame.jl/reference/Collider/) - For rectangular collision areas
- [Rigidbody](/JulGame.jl/reference/Rigidbody/) - For physics-based movement
- [Transform](/JulGame.jl/reference/Transform/) - For positioning entities 