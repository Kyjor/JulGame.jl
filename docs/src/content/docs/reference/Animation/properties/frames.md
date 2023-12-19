---
title: frames 
description: An array of `Vector4` that holds data about cropping the current `sprite`.
---

An array of `Vector4` that holds data about cropping the current `sprite`.

#### Type<span style="color:red;">:</span> Array{Vector4}<br/>

### In the editor


### In the code

```js del={4-6} ins={12} ins="this was inserted" del=/ye[sp]/
spriteFrames = [
    [0, 0, 50, 50],   # First frame cropping 
    [50, 0, 50, 50],  # Second frame cropping 
    # Additional frames and cropping information...
]
```