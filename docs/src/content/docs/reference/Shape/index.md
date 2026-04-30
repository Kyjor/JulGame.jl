---
title: Shape Component
description: Create primitive geometric shapes in JulGame
---

# Shape Component

The Shape component allows you to create and display primitive geometric shapes in your game without requiring image assets. It's useful for prototyping, debug visuals, and simple UI elements.

## Overview

The Shape component handles:
- Drawing rectangular shapes
- Setting colors and transparency
- Controlling whether shapes are filled or outlined
- Positioning in screen or world space

## Adding a Shape Component

```julia
# Create a new entity
entity = Entity("Rectangle")

# Create and add a shape component
shape = ShapeModule.create(
    Math.Vector3(255, 0, 0),  # Red color
    true,                     # Filled
    Math.Vector2f(50, 50)     # Size
)
entity.addComponent(shape)

# Add to scene
scene.addEntity(entity)
```

## Function Reference

### create()

```julia
ShapeModule.create(
    color::Math.Vector3 = Math.Vector3(255, 0, 0),  # RGB color
    isFilled::Bool = true,                          # Whether shape is filled
    size::Math.Vector2f = Math.Vector2f(1, 1),      # Width and height
    offset::Math.Vector2f = Math.Vector2f(0, 0);    # Offset from entity center
    isWorldEntity::Bool = true,                     # Whether in world or screen space
    position::Math.Vector2f = Math.Vector2f(0, 0),  # Local position offset
    layer::Int32 = Int32(0),                        # Render layer
    alpha::Int32 = Int32(255)                       # Transparency (0-255)
)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `color` | `Math.Vector3` | RGB color (each component 0-255) |
| `isFilled` | `Bool` | Whether the shape is filled or outlined |
| `size` | `Math.Vector2f` | Width and height of the shape |
| `offset` | `Math.Vector2f` | Offset from the entity's center |
| `isWorldEntity` | `Bool` | Whether the shape is in world or screen space |
| `position` | `Math.Vector2f` | Local position offset from the entity |
| `layer` | `Int32` | Render layer (higher numbers render on top) |
| `alpha` | `Int32` | Transparency (0-255, where 0 is invisible and 255 is opaque) |

## Examples

### Basic Shape

```julia
# Create a simple red square
shape = ShapeModule.create(
    Math.Vector3(255, 0, 0),    # Red color
    true,                       # Filled
    Math.Vector2f(50, 50)       # 50x50 size
)
entity.addComponent(shape)
```

### Outlined Shape

```julia
# Create an outlined blue rectangle
shape = ShapeModule.create(
    Math.Vector3(0, 0, 255),    # Blue color
    false,                      # Not filled (outline only)
    Math.Vector2f(100, 50)      # 100x50 size
)
entity.addComponent(shape)
```

### UI Shape (Screen Space)

```julia
# Create a semi-transparent green UI panel
uiShape = ShapeModule.create(
    Math.Vector3(0, 255, 0),    # Green color
    true,                       # Filled
    Math.Vector2f(200, 100);    # 200x100 size
    isWorldEntity=false,        # Screen space (not affected by camera)
    position=Math.Vector2f(400, 300), # Center of the screen
    alpha=128                   # 50% transparency
)
uiEntity.addComponent(uiShape)
```

## Use Cases

### Prototyping

Shapes are excellent for quickly prototyping game mechanics before creating final art:

```julia
# Create player, enemies, and platforms with simple shapes
playerShape = ShapeModule.create(Math.Vector3(0, 255, 0), true, Math.Vector2f(32, 32))
enemyShape = ShapeModule.create(Math.Vector3(255, 0, 0), true, Math.Vector2f(32, 32))
platformShape = ShapeModule.create(Math.Vector3(100, 100, 100), true, Math.Vector2f(200, 20))
```

### Debug Visualization

Shapes can help visualize collision areas, paths, or other debug information:

```julia
# Create a shape to visualize a collider
colliderVisualization = ShapeModule.create(
    Math.Vector3(255, 255, 0),  # Yellow color
    false,                      # Outline only
    Math.Vector2f(32, 64)       # Size matching collider
)
```

### UI Elements

Simple UI elements like panels, bars, or buttons can be created with shapes:

```julia
# Create a health bar background
healthBarBg = ShapeModule.create(
    Math.Vector3(50, 50, 50),   # Dark gray color
    true,                       # Filled
    Math.Vector2f(200, 20);     # Size
    isWorldEntity=false         # Screen space
)

# Create a health bar foreground
healthBarFg = ShapeModule.create(
    Math.Vector3(255, 0, 0),    # Red color
    true,                       # Filled
    Math.Vector2f(150, 16);     # Size (slightly smaller)
    isWorldEntity=false,        # Screen space
    position=Math.Vector2f(-2, 0) # Slight offset for border effect
)
```

## Performance Considerations

- **Efficiency**: Shapes are more efficient than sprites for simple geometric elements
- **Batching**: Shapes with the same properties are automatically batched for rendering
- **Layer Management**: Use layers to control render order when using multiple shapes

## See Also

- [Sprite](/JulGame.jl/reference/Sprite/) - For image-based visuals
- [UI Components](/JulGame.jl/reference/UI/) - For user interface elements
- [Transform](/JulGame.jl/reference/Transform/) - For positioning entities 