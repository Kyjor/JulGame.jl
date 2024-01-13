---
title: Animation.frames 
description: An array of `Vector4` that holds data about cropping the current `sprite`.
---

An array of `Vector4` that holds data about cropping the current `sprite`.

#### Type<span style="color:red;">:</span> Array{Vector4}<br/>

### Example

```julia del={4-6} ins={12} ins="this was inserted" del=/ye[sp]/
spriteFrames = [
    [0, 0, 16, 16],   # First frame cropping 
    [17, 0, 16, 16],  # Second frame cropping 
    # Additional frames and cropping information...
]
```
In the provided code, we have a array called `spriteFrames` that contains multiple subarrays. Each subarray represents a frame in an animation and contains four values: `[x, y, w, h]`.

Let's break down what each value represents:

`x`: This value represents the starting x-coordinate of the cropping area on the image. It specifies the leftmost point from where the cropping should begin. <br/>
`y`: This value represents the starting y-coordinate of the cropping area on the image. It specifies the topmost point from where the cropping should begin. <br/>
`w`: This value represents the width of the cropping area. It specifies how many pixels wide the cropped portion should be. <br/>
`h`: This value represents the height of the cropping area. It specifies how many pixels tall the cropped portion should be. <br/> <br/>
By using these four values, we can define a rectangular region on an image that we want to extract or crop. The cropping area starts at the point `(x, y)` and extends `w` pixels to the right and `h` pixels downwards.

In the provided code, each subarray in the `spriteFrames` array represents a frame in an animation. The first subarray `[0, 0, 16, 16]` indicates that the first frame should be cropped from the image starting at the top-left corner `(0, 0)` with a width and height of 16 pixels each. Similarly, the second subarray `[17, 0, 16, 16]` indicates that the second frame should be cropped starting at `(17, 0)` with the same width and height.

This cropping information is useful when working with sprite sheets or image sequences where different frames of an animation are stored in a single image. By specifying the cropping area for each frame, we can extract individual frames from the image to create animations or perform other image processing tasks.