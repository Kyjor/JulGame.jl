---
title: Components Reference
description: A comprehensive guide to JulGame's component system
---

# Components Reference

JulGame uses a component-based architecture for game development, allowing you to build complex game objects by combining simple, reusable components. This page provides an overview of all available components.

## Component System

The [Component System](/docs/reference/Component/) forms the foundation of JulGame's entity-component architecture. It provides the core infrastructure for adding functionality to game entities through modular components.

## Available Components

### Visual Components

| Component | Description |
|-----------|-------------|
| [Sprite](/docs/reference/Sprite/) | Renders 2D images and textures with support for cropping, flipping, and transparency |
| [Shape](/docs/reference/Shape/) | Renders simple geometric shapes like rectangles with customizable colors and fill |
| [Animation](/docs/reference/Animation/) | Stores animation frame sequences defined as crop regions from sprite sheets |
| [Animator](/docs/reference/Animator/) | Controls animation playback with support for multiple animations per entity |

### Physics Components

| Component | Description |
|-----------|-------------|
| [Collider](/docs/reference/Collider/) | Provides rectangle-based collision detection and response |
| [CircleCollider](/docs/reference/CircleCollider/) | Provides circle-based collision detection for more accurate representation of round objects |
| [Rigidbody](/docs/reference/Rigidbody/) | Adds physics simulation including velocity, forces, and dynamic movement |

### Audio Components

| Component | Description |
|-----------|-------------|
| [SoundSource](/docs/reference/SoundSource/) | Plays sound effects and music with support for looping, volume control, and spatial audio |

### UI Components

| Component | Description |
|-----------|-------------|
| [TextBox](/docs/reference/UI/TextBox/) | Displays text with support for different fonts, sizes, and styles |
| [ScreenButton](/docs/reference/UI/ScreenButton/) | Creates interactive buttons with click events and visual states |
| [ImmediateText](/docs/reference/UI/ImmediateText/) | Renders text directly to the screen without requiring an entity |

### Core Components

| Component | Description |
|-----------|-------------|
| [Transform](/docs/reference/Transform/) | Manages an entity's position, scale, rotation, and parent-child relationships |

## Creating Custom Components

The JulGame component system is designed to be extensible, allowing you to create custom components for your game's specific needs. See the [Component System](/docs/reference/Component/) documentation for a tutorial on creating custom components.

## Component Best Practices

For optimal performance and maintainability in your JulGame projects:

1. **Keep components focused** on a single responsibility
2. **Minimize dependencies** between components when possible
3. **Use message passing** for communication between components
4. **Cache component references** for frequently accessed components
5. **Compose behavior** by combining multiple simple components rather than creating complex monolithic ones

## See Also

- [Entity System](/docs/reference/Entity/) - Learn how to create and manage game objects
- [Math Library](/docs/reference/Math/) - Vector and matrix operations for game development
- [Input System](/docs/reference/Input/) - Handle keyboard, mouse, and controller input 