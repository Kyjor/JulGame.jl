---
title: Animator.animations
description: An array of animations.
---
An array of animations.

### Example
```
    animation1 = Animation([Math.Vector4(0,0,16,16), Math.Vector4(0,17,16,16)], 60)
    animation2 = Animation([Math.Vector4(0,0,16,16), Math.Vector4(0,17,16,16)], 30)
    animations = [animation1, animation2]
    animator = Animator(animations)
```

The active selection of code is creating two `animations` and an `animator`.

The `Animation` class is being instantiated twice, each time with two arguments. The first argument is a array of `Math.Vector4` objects, and the second argument is an integer representing the frame rate.

A `Math.Vector4` object is a mathematical vector with four components. In this context, each `Math.Vector4` object represents a frame of an `animation`, with the four components corresponding to the x-coordinate, y-coordinate, width, and height of the frame on a sprite sheet. This is similar to the cropping of an image as explained earlier.

The first `animation`, `animation1`, is created with a frame rate of 60. This means that it will display 60 frames per second. The frames for this `animation` are defined by two `Math.Vector4` objects: (0,0,16,16) and (0,17,16,16). These vectors define two different regions on the sprite sheet that will be displayed as frames of the `animation`.

The second `animation`, `animation2`, is created in the same way as the first, but with a frame rate of 30. This means it will display 30 frames per second.

The animations array is then created, containing both `animation1` and `animation2`.

Finally, an `Animator` object is created with the animations array as an argument. The Animator class is likely responsible for managing and playing the animations at the correct frame rates. It may also handle tasks such as looping animations, transitioning between animations, and stopping or pausing animations.