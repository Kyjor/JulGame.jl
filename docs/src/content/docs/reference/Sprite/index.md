---
title: Sprite Component
description: Display images and sprites in your JulGame project
---

# Sprite Component

The Sprite component allows you to display images in your game. It's one of the most fundamental components for creating visual elements in JulGame.

## Overview

The Sprite component handles:
- Loading and displaying images
- Cropping sprites from spritesheets
- Setting colors and transparency
- Positioning in screen or world space
- Layering (z-order) of visual elements

## Adding a Sprite Component

```julia
# Create a new entity
entity = Entity("MySprite")

# Create and add a sprite component
sprite = SpriteModule.create("path/to/image.png")
entity.addComponent(sprite)

# Add to scene
scene.addEntity(entity)
```

## Function Reference

### create()

```julia
SpriteModule.create(
    imagePath::String,                                  # Path to the image file
    crop::Union{Ptr{Nothing}, Math.Vector4}=C_NULL,     # Optional crop rectangle
    isFlipped::Bool=false,                              # Whether the sprite is flipped horizontally
    color::Tuple{Int64, Int64, Int64, Int64}=(255,255,255,255),  # Color tint (R,G,B,A)
    isCreatedInEditor::Bool=false;                      # Whether created in the editor
    pixelsPerUnit::Int32=Int32(-1),                     # Pixels per unit for scaling
    isWorldEntity::Bool=true,                           # Whether in world or screen space
    position::Math.Vector2f=Math.Vector2f(0,0),         # Local offset position
    rotation::Float64=0.0,                              # Rotation in degrees
    layer::Int32=Int32(0),                              # Render layer (higher = in front)
    center::Math.Vector2f=Math.Vector2f(0.5,0.5)        # Pivot point (0-1 range)
)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `imagePath` | `String` | Path to the image file |
| `color` | `Tuple{Int64, Int64, Int64, Int64}` | Color tint (R,G,B,A) |
| `crop` | `Union{Ptr{Nothing}, Math.Vector4}` | Cropping rectangle for spritesheets |
| `isFlipped` | `Bool` | Whether the sprite is horizontally flipped |
| `isWorldEntity` | `Bool` | Whether the sprite is in world or screen space |
| `layer` | `Int32` | Render layer (higher numbers render on top) |
| `position` | `Math.Vector2f` | Local position offset from the entity |
| `rotation` | `Float64` | Local rotation in degrees |
| `center` | `Math.Vector2f` | Pivot point (0-1 range, where 0.5,0.5 is center) |

## Examples

### Basic Sprite

```julia
# Create a simple sprite
sprite = SpriteModule.create("assets/images/player.png")
entity.addComponent(sprite)
```

### Sprite with Custom Properties

```julia
# Create a sprite with custom properties
sprite = SpriteModule.create(
    "assets/images/player.png",              # Image path
    Math.Vector4(0, 0, 32, 32),              # Crop a 32x32 region from the top-left
    false,                                   # Not flipped
    (255, 255, 255, 200);                    # Slightly transparent white
    layer=Int32(5),                          # Higher layer
    center=Math.Vector2f(0.5, 1.0)           # Pivot at bottom center
)
entity.addComponent(sprite)
```

### UI Sprite (Screen Space)

```julia
# Create a UI sprite in screen space
uiSprite = SpriteModule.create(
    "assets/images/button.png",
    C_NULL,                                  # No cropping
    false,                                   # Not flipped
    (255, 255, 255, 255);                    # Fully opaque
    isWorldEntity=false,                     # Screen space (not affected by camera)
    position=Math.Vector2f(100, 100)         # Position on screen
)
uiEntity.addComponent(uiSprite)
```

### Animated Sprite

For animated sprites, use the Sprite component in combination with the Animator component:

```julia
# Create a sprite for animation
sprite = SpriteModule.create("assets/images/character_sheet.png")
entity.addComponent(sprite)

# Create an animator component (see Animator documentation)
animator = AnimatorModule.create()
entity.addComponent(animator)

# Add animation frames
# ...
```

## Performance Considerations

- **Texture Atlases**: For better performance, combine multiple small sprites into a texture atlas
- **Sprite Batching**: Sprites using the same texture are automatically batched for better performance
- **Image Formats**: PNG is recommended for quality, but use JPG for large background images
- **Power of Two**: For best performance, use images with dimensions that are powers of two (e.g., 256×256, 512×512)

## See Also

- [Animator Component](/JulGame.jl/reference/Animator/) - For animating sprites
- [Shape Component](/JulGame.jl/reference/Shape/) - For creating primitive shapes
- [UI Components](/JulGame.jl/reference/UI/) - For user interface elements 