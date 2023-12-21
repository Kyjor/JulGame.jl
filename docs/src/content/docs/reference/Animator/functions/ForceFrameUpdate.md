---
title: ForceFrameUpdate(Animator)
description: Updates the sprite crop of the animator to the specified frame index.
---

Updates the sprite crop of the animator to the specified frame index.

### Properties

| Parameter | Description                    |
|-------------------------------------------------------------------------------|---------------------------------------------------------------------------|
| this           | The [animator](/JulGame.jl/reference/animator/animator/) object |
| animations           | An array of [Animations](/JulGame.jl/reference/animation/animation/). |

### Example
```
    animations = [Animation([Math.Vector4(0,0,16,16), Math.Vector4(0,17,16,16)], 60)]
    animator = Animator(animations)
    ForceFrameUpdate(animator, 1) # forces the animation to be at frame 1
```