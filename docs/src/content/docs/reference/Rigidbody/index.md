---
title: Rigidbody Component
description: Add physics-based movement to your game objects in JulGame
---

# Rigidbody Component

The Rigidbody component allows you to add physics-based movement to your game entities. It simulates physics properties like velocity, acceleration, gravity, and mass.

## Overview

The Rigidbody component handles:
- Physics-based movement
- Gravity simulation
- Velocity and acceleration
- Mass-based physics interactions

## Adding a Rigidbody Component

```julia
# Create a new entity
entity = Entity("Player")

# Create and add a rigidbody component
rigidbody = RigidbodyModule.create()
entity.addComponent(rigidbody)

# Add to scene
scene.addEntity(entity)
```

## Function Reference

### create()

```julia
RigidbodyModule.create(;
    mass::Float64 = 1.0,                  # Mass of the rigidbody
    useGravity::Bool = true               # Whether gravity affects this rigidbody
)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `mass` | `Float64` | Mass of the rigidbody (affects physics interactions) |
| `useGravity` | `Bool` | Whether gravity affects this rigidbody |
| `velocity` | `Math.Vector2f` | Current velocity (can be modified directly) |
| `acceleration` | `Math.Vector2f` | Current acceleration |
| `drag` | `Float64` | Resistance to movement (slows the object over time) |
| `grounded` | `Bool` | Whether the rigidbody is on the ground (read-only) |

## Examples

### Basic Rigidbody

```julia
# Create a simple rigidbody with default settings
rigidbody = RigidbodyModule.create()
entity.addComponent(rigidbody)
```

### Heavy Object Without Gravity

```julia
# Create a heavy rigidbody that isn't affected by gravity
rigidbody = RigidbodyModule.create(
    mass = 10.0,            # Heavy mass
    useGravity = false      # No gravity
)
entity.addComponent(rigidbody)
```

### Moving an Object with Force

```julia
# Apply force to a rigidbody (in a script)
function update(script::PlayerController, entity)
    rigidbody = entity.getComponent("Rigidbody")
    
    # Apply a force to the right
    rigidbody.velocity += Math.Vector2f(5.0 * DELTA_TIME, 0.0)
end
```

### Jumping

```julia
# Implement jumping in a script
function update(script::PlayerController, entity)
    rigidbody = entity.getComponent("Rigidbody")
    
    # Jump when space is pressed and the player is on the ground
    if MAIN.input.isKeyPressed(SDL2.SDLK_SPACE) && rigidbody.grounded
        rigidbody.velocity += Math.Vector2f(0.0, -10.0)  # Negative Y is up
    end
end
```

## Physics Simulation

JulGame's physics system updates rigidbodies each frame:

1. Gravity is applied (if `useGravity` is true)
2. Acceleration is applied to velocity
3. Velocity is applied to position
4. Drag is applied to slow the object
5. Collisions are resolved (if a collider is present)

## Using with Colliders

Rigidbodies work best when paired with collider components:

```julia
# Create a physical object with both components
entity = Entity("PhysicsObject")

# Add a collider
collider = ColliderModule.create(32, 32)
entity.addComponent(collider)

# Add a rigidbody
rigidbody = RigidbodyModule.create()
entity.addComponent(rigidbody)

# Add to scene
scene.addEntity(entity)
```

## Grounded State

The `grounded` property indicates whether the rigidbody is on the ground. This is useful for:

- Allowing jumping only when grounded
- Applying different physics when on the ground vs. in the air
- Animating based on grounded state (walking vs. jumping animations)

```julia
function update(script::PlayerController, entity)
    rigidbody = entity.getComponent("Rigidbody")
    animator = entity.getComponent("Animator")
    
    if rigidbody.grounded
        AnimatorModule.play(animator, "Walk")
    else
        AnimatorModule.play(animator, "Jump")
    end
end
```

## Performance Considerations

- **Limited Use**: Only add rigidbodies to objects that need physics
- **Sleeping**: Rigidbodies automatically "sleep" when not moving
- **Simplify Colliders**: Use simple collider shapes with rigidbodies
- **Mass Ratios**: Maintain reasonable mass ratios between interacting objects

## See Also

- [Collider](/JulGame.jl/reference/Collider/) - For collision detection
- [CircleCollider](/JulGame.jl/reference/CircleCollider/) - For circular collision areas
- [Transform](/JulGame.jl/reference/Transform/) - For positioning entities 