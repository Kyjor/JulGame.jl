---
title: Component System
description: Understanding the component-based architecture in JulGame
---

# Component System

The Component system is the backbone of JulGame's entity-component architecture. It provides the foundational structure that enables modular game development, allowing you to build complex game objects by combining simple, reusable components.

## Overview

JulGame uses a component-based architecture where:

- **Entities** are game objects represented by an ID
- **Components** are modules that add specific functionality to entities
- **Systems** process entities with specific component combinations

This approach follows the Entity Component System (ECS) pattern, which promotes composition over inheritance for greater flexibility and code reuse.

## Available Components

JulGame provides the following built-in components:

| Component | Purpose |
|-----------|---------|
| [Transform](/docs/reference/Transform/) | Handles position, scale, and hierarchy |
| [Sprite](/docs/reference/Sprite/) | Renders 2D images |
| [Animation](/docs/reference/Animation/) | Stores animation frame sequences |
| [Animator](/docs/reference/Animator/) | Controls animation playback |
| [Collider](/docs/reference/Collider/) | Provides rectangle collision detection |
| [CircleCollider](/docs/reference/CircleCollider/) | Provides circle collision detection |
| [Rigidbody](/docs/reference/Rigidbody/) | Adds physics simulation |
| [Shape](/docs/reference/Shape/) | Renders simple geometric shapes |
| [SoundSource](/docs/reference/SoundSource/) | Plays sounds and music |

## Common Component Functions

Many components implement a standard set of functions:

| Function | Description |
|----------|-------------|
| `update()` | Called each frame to update component state |
| `draw()` | Renders the component's visual elements |
| `initialize()` | Sets up the component when added to an entity |
| `destroy()` | Cleans up resources when the component is removed |
| `get_position()` | Returns the component's position |
| `set_position()` | Sets the component's position |
| `get_scale()` | Returns the component's scale factor |
| `set_scale()` | Sets the component's scale factor |
| `get_rotation()` | Returns the component's rotation angle |
| `set_rotation()` | Sets the component's rotation angle |

## Creating a Component

To create a custom component, you should:

1. Create a new module that extends the base Component functionality
2. Define the component's data structure (struct)
3. Implement any required component functions
4. Register the component with the Entity system

Here's a simple example of a custom Health component:

```julia
module HealthModule
    using ..JulGame

    struct Health
        maxHealth::Int
        currentHealth::Int
    end

    # Constructor
    function create(maxHealth::Int)
        return Health(maxHealth, maxHealth)
    end

    # Update function called every frame
    function Component.update(health::Health, deltaTime::Float64)
        # Logic for health regeneration could go here
    end

    # Utility functions
    function damage(health::Health, amount::Int)
        health.currentHealth = max(0, health.currentHealth - amount)
    end

    function heal(health::Health, amount::Int)
        health.currentHealth = min(health.maxHealth, health.currentHealth + amount)
    end

    function is_alive(health::Health)
        return health.currentHealth > 0
    end
end

# Usage example:
entity = Entity.create()
healthComponent = Entity.add_component(entity, HealthModule, 100)
HealthModule.damage(healthComponent, 20)
```

## Component Workflow

The typical workflow for using components is:

1. Create an entity
2. Add required components
3. Configure component properties
4. Update components in the game loop
5. Remove components or destroy the entity when no longer needed

```julia
# Create entity and add components
player = Entity.create()
transform = Entity.add_component(player, TransformModule)
sprite = Entity.add_component(player, SpriteModule, "assets/player.png")

# Configure components
TransformModule.set_position(transform, Math.Vector2(100, 100))
SpriteModule.set_scale(sprite, Math.Vector2(2, 2))

# Later in the game loop
function update(deltaTime)
    # Components are automatically updated
end

# When done
Entity.destroy(player)
```

## Best Practices

When working with components:

- **Keep components focused**: Each component should handle a single aspect of functionality
- **Minimize component dependencies**: Components should be as independent as possible
- **Use message passing**: For communication between components, use events rather than direct references
- **Prefer composition**: Build complex behaviors by combining simple components
- **Cache component references**: Store references to frequently accessed components

## See Also

- [Entity System](/docs/reference/Entity/)
- [Math Library](/docs/reference/Math/)
- [Macros](/docs/reference/Macros/) 