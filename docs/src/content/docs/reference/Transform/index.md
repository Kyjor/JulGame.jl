---
title: Transform Component
description: Position and scale your entities in JulGame
---

# Transform Component

The Transform component defines the position and scale of an entity in the game world. Every entity in JulGame automatically has a Transform component.

## Overview

The Transform component handles:
- Positioning entities in the world
- Scaling entities
- Parent-child relationships (inherited transformations)

## Accessing the Transform Component

Since every entity has a Transform component by default, you can access it directly:

```julia
# Create a new entity
entity = Entity("Player")

# Access its transform component
entity.transform.position = Math.Vector2f(100, 100)
entity.transform.scale = Math.Vector2f(2.0, 2.0)

# Add to scene
scene.addEntity(entity)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `position` | `Math.Vector2f` | Position of the entity in world space |
| `scale` | `Math.Vector2f` | Scale of the entity (1.0, 1.0 is normal size) |

## Examples

### Setting Position

```julia
# Set the entity's position
entity.transform.position = Math.Vector2f(200, 150)

# Or set individual components
entity.transform.position.x = 200
entity.transform.position.y = 150
```

### Scaling an Entity

```julia
# Scale the entity to be twice as large
entity.transform.scale = Math.Vector2f(2.0, 2.0)

# Make the entity wider but not taller
entity.transform.scale = Math.Vector2f(2.0, 1.0)

# Flip the entity horizontally
entity.transform.scale.x = -1.0
```

### Moving an Entity

```julia
# Move the entity right by 5 units per second (in a script)
function update(script::PlayerController, entity)
    entity.transform.position.x += 5 * DELTA_TIME
end
```

## Transform Hierarchy

When an entity is a child of another entity, its transform is relative to the parent:

```julia
# Create parent and child entities
parent = Entity("Parent")
child = Entity("Child")

# Set up parent transform
parent.transform.position = Math.Vector2f(100, 100)
parent.transform.scale = Math.Vector2f(2.0, 2.0)

# Set up child transform (relative to parent)
child.transform.position = Math.Vector2f(50, 0)  # 50 units to the right of parent

# Make child a child of parent
parent.addChild(child)

# Add parent to scene (child is automatically added)
scene.addEntity(parent)
```

In this example:
- The parent is at position (100, 100) with scale (2.0, 2.0)
- The child is at local position (50, 0)
- The child's world position is (100 + 50*2, 100 + 0*2) = (200, 100)
- The child inherits the parent's scale, effectively having scale (2.0, 2.0)

## Working with Transforms in Scripts

```julia
function update(script::YourScript, entity)
    # Get current position
    currentPos = entity.transform.position
    
    # Calculate movement
    moveVector = Math.Vector2f(5 * DELTA_TIME, 0)
    
    # Apply movement
    entity.transform.position += moveVector
end
```

## Tips and Best Practices

- **Origin**: The origin (0,0) of the world is typically at the top-left corner
- **Scale vs Size**: Transform scale affects the rendering size, not the collider size
- **Flipping**: Set scale.x to -1 to flip horizontally, scale.y to -1 to flip vertically
- **Hierarchy**: Use parent-child relationships to organize related entities

## See Also

- [Entity](/JulGame.jl/reference/Entity/) - For entity management
- [Sprite](/JulGame.jl/reference/Sprite/) - For visual representation
- [Collider](/JulGame.jl/reference/Collider/) - For collision detection 