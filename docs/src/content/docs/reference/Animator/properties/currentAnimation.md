---
title: Animator.currentAnimation
description: The current animation in use by the animator.
---
The current animation in use by the animator.

### Example
```
    animation1 = Animation([Math.Vector4(0,0,16,16), Math.Vector4(0,17,16,16)], 60)
    animation2 = Animation([Math.Vector4(0,0,16,16), Math.Vector4(0,17,16,16)], 30)
    animations = [animation1, animation2]
    animator = Animator(animations)

    currentAnimation = animator.currentAnimation
```