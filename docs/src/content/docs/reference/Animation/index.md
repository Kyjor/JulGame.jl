---
title: Animation Component
description: Define sprite animations for your game objects in JulGame
---

# Animation Component

The Animation component defines a sequence of frames that can be used to animate sprites in your game. It works together with the Animator component to create animated characters and objects.

## Overview

The Animation component handles:
- Storing sequences of animation frames
- Setting animation speed (in frames per second)
- Defining crop regions for sprite sheets

## How Animations Work

Animations in JulGame use sprite sheets where multiple frames are stored in a single image. The Animation component defines which regions of the sprite sheet should be displayed for each frame of the animation.

## Creating Animations

Animations are typically created through the Animator component:

```julia
# Create an animator component
animator = AnimatorModule.create()

# Add an animation with 4 frames at 10 FPS
frames = [
    Math.Vector4(0, 0, 32, 32),    # Frame 1: x, y, width, height
    Math.Vector4(32, 0, 32, 32),   # Frame 2
    Math.Vector4(64, 0, 32, 32),   # Frame 3
    Math.Vector4(96, 0, 32, 32)    # Frame 4
]
AnimatorModule.addAnimation(animator, "Walk", frames, 10)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `frames` | `Vector{Math.Vector4}` | Vector of frame rectangles (x, y, width, height) |
| `animatedFPS` | `Int32` | Speed of the animation in frames per second |

## Frame Format

Each frame is defined as a `Math.Vector4` with the following components:
- **x**: X position in the sprite sheet (in pixels)
- **y**: Y position in the sprite sheet (in pixels)
- **width**: Width of the frame (in pixels)
- **height**: Height of the frame (in pixels)

## Examples

### Creating a Walking Animation

```julia
# Create frames for a walking animation from a sprite sheet
walkFrames = [
    Math.Vector4(0, 0, 32, 32),
    Math.Vector4(32, 0, 32, 32),
    Math.Vector4(64, 0, 32, 32),
    Math.Vector4(96, 0, 32, 32)
]

# Add to animator with name "Walk" at 10 FPS
AnimatorModule.addAnimation(animator, "Walk", walkFrames, 10)
```

### Multiple Animations on One Sprite Sheet

```julia
# Create frames for different animations from the same sprite sheet
walkFrames = [
    Math.Vector4(0, 0, 32, 32),
    Math.Vector4(32, 0, 32, 32),
    Math.Vector4(64, 0, 32, 32),
    Math.Vector4(96, 0, 32, 32)
]

jumpFrames = [
    Math.Vector4(0, 32, 32, 32),
    Math.Vector4(32, 32, 32, 32)
]

idleFrames = [
    Math.Vector4(0, 64, 32, 32)
]

# Add all animations to the animator
AnimatorModule.addAnimation(animator, "Walk", walkFrames, 10)
AnimatorModule.addAnimation(animator, "Jump", jumpFrames, 5)
AnimatorModule.addAnimation(animator, "Idle", idleFrames, 1)
```

## Best Practices

- **Consistent Frame Size**: Keep all frames the same size for consistent animations
- **Power of Two**: Use sprite sheets with dimensions that are powers of two
- **Animation Speed**: Adjust the FPS to control the speed of animations
- **Frame Naming**: Use descriptive names for animations ("Walk", "Jump", "Attack", etc.)

## Editor Support

JulGame's built-in editor includes a Sprite Cropping Tool that makes it easy to create animation frames from sprite sheets. This tool allows you to:

1. Load a sprite sheet
2. Define frame regions visually
3. Export the frames as animations

## See Also

- [Animator Component](/JulGame.jl/reference/Animator/) - For playing and controlling animations
- [Sprite Component](/JulGame.jl/reference/Sprite/) - For displaying images and sprites
- [Editor](/JulGame.jl/general/editor/) - For using the built-in editor's Sprite Cropping Tool 