---
title: Animator Component
description: Play and control sprite animations in JulGame
---

# Animator Component

The Animator component allows you to play and control animations on your game entities. It works in conjunction with the Animation component and a Sprite component to create animated characters and objects.

## Overview

The Animator component handles:
- Managing multiple animations for a sprite
- Playing, pausing, and stopping animations
- Transitioning between different animations
- Controlling animation playback (speed, one-shot vs looping)

## Adding an Animator Component

```julia
# Create a new entity with a sprite
entity = Entity("Player")
sprite = SpriteModule.create("assets/images/character_sheet.png")
entity.addComponent(sprite)

# Create and add an animator component
animator = AnimatorModule.create()
entity.addComponent(animator)

# Add an animation with 4 frames at 10 FPS
frames = [
    Math.Vector4(0, 0, 32, 32),    # Frame 1: x, y, width, height
    Math.Vector4(32, 0, 32, 32),   # Frame 2
    Math.Vector4(64, 0, 32, 32),   # Frame 3
    Math.Vector4(96, 0, 32, 32)    # Frame 4
]
AnimatorModule.addAnimation(animator, "Walk", frames, 10)
```

## Function Reference

### create()

```julia
AnimatorModule.create()  # No parameters needed
```

### addAnimation()

```julia
AnimatorModule.addAnimation(
    animator,            # The animator component
    name::String,        # Name of the animation
    frames::Vector{Math.Vector4},  # Vector of frame rectangles
    framesPerSecond::Number        # Animation speed in FPS
)
```

### play()

```julia
AnimatorModule.play(
    animator,            # The animator component
    animationName::String,  # Name of the animation to play
    playOnce::Bool = false  # Whether to play once or loop
)
```

### stop()

```julia
AnimatorModule.stop(animator)  # Stops the current animation
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `animations` | `Vector{Animation}` | List of animations available to this animator |
| `currentAnimation` | `Animation` | Currently playing animation |
| `playOnce` | `Bool` | Whether the animation plays once or loops |

## Examples

### Basic Animation Playback

```julia
# Create the animator with a walk animation
animator = AnimatorModule.create()
entity.addComponent(animator)

walkFrames = [
    Math.Vector4(0, 0, 32, 32),
    Math.Vector4(32, 0, 32, 32),
    Math.Vector4(64, 0, 32, 32),
    Math.Vector4(96, 0, 32, 32)
]
AnimatorModule.addAnimation(animator, "Walk", walkFrames, 10)

# Play the animation (looping)
AnimatorModule.play(animator, "Walk")
```

### Multiple Animations with State Switching

```julia
# Set up animator with multiple animations
animator = AnimatorModule.create()
entity.addComponent(animator)

# Add animations
AnimatorModule.addAnimation(animator, "Idle", idleFrames, 5)
AnimatorModule.addAnimation(animator, "Walk", walkFrames, 10)
AnimatorModule.addAnimation(animator, "Jump", jumpFrames, 8)

# In your script's update function, switch animations based on state
function update(script::PlayerController, entity)
    animator = entity.getComponent("Animator")
    
    if script.isJumping
        AnimatorModule.play(animator, "Jump", true)  # Play once
    elseif script.isMoving
        AnimatorModule.play(animator, "Walk")        # Loop
    else
        AnimatorModule.play(animator, "Idle")        # Loop
    end
end
```

### One-Shot Animation

```julia
# Play an attack animation once (not looping)
AnimatorModule.play(animator, "Attack", true)

# You might want to check when it's done
function update(script::PlayerController, entity)
    animator = entity.getComponent("Animator")
    
    # If attack animation is done, switch back to idle
    if script.isAttacking && animator.playOnce && 
       animator.lastFrame == length(animator.currentAnimation.frames)
        script.isAttacking = false
        AnimatorModule.play(animator, "Idle")
    end
end
```

## Working with Sprite Sheets

Animator works best with sprite sheets that have a consistent grid layout:

```
+--------+--------+--------+--------+
|        |        |        |        |
| Frame1 | Frame2 | Frame3 | Frame4 |
|        |        |        |        |
+--------+--------+--------+--------+
|        |        |
| Frame5 | Frame6 |
|        |        |
+--------+--------+
```

The frames are defined using `Math.Vector4(x, y, width, height)` coordinates on the sprite sheet.

## Best Practices

- **Organize by State**: Create separate animations for different states (Idle, Walk, Jump, etc.)
- **Consistent Frame Rate**: Keep a consistent frame rate within each animation
- **Animation Transitions**: Handle smooth transitions between animations in your scripts
- **Naming Convention**: Use clear, descriptive names for your animations

## Editor Support

The JulGame Editor provides a Sprite Cropping Tool that can help you:
1. Load sprite sheets
2. Define animation frames visually
3. Preview animations
4. Export animation data

## See Also

- [Animation Component](/JulGame.jl/reference/Animation/) - For defining animation frames
- [Sprite Component](/JulGame.jl/reference/Sprite/) - For displaying images and sprites
- [Editor](/JulGame.jl/general/editor/) - For using the Sprite Cropping Tool 