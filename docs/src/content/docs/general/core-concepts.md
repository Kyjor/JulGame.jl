---
title: Core Concepts
description: Understanding the fundamental architecture of JulGame
---

# Core Concepts

JulGame follows an entity-component architecture similar to other modern game engines. Understanding these core concepts will help you organize your game code effectively.

## Entity-Component System

JulGame uses an entity-component system (ECS) where:

- **Entities** are container objects that represent game objects
- **Components** add behavior or functionality to entities
- **Systems** process entities with specific components

### Entities

An entity in JulGame is a simple container that has:
- A unique ID
- A name
- A transform (position, rotation, scale)
- A list of components
- Optional parent-child relationships

```julia
# Create a new entity
player = Entity("Player")

# Set position
player.transform.position = Math.Vector2(100, 100)

# Add to scene
scene.addEntity(player)
```

### Components

Components are modules that add specific functionality to entities. JulGame provides several built-in components:

```julia
# Add a sprite component
sprite = SpriteModule.create("path/to/sprite.png")
player.addComponent(sprite)

# Add a collider component
collider = ColliderModule.create(50, 50)  # width, height
player.addComponent(collider) 

# Add an animator component
animator = AnimatorModule.create()
player.addComponent(animator)
```

### Scripting

Scripts are special components that let you define custom behavior:

```julia
# Define a script
struct PlayerController <: Script
    speed::Float64
    
    PlayerController() = new(5.0)
end

# Define behavior
function update(script::PlayerController, entity)
    if MAIN.input.isKeyPressed(SDL2.SDLK_RIGHT)
        entity.transform.position.x += script.speed
    end
end

# Add the script to an entity
player.addScript(PlayerController())
```

## Scene Management

JulGame organizes game objects into scenes:

- **Scenes** contain entities and manage their lifecycle
- **Scene Building** lets you construct scenes from code
- **Scene Loading** loads scenes from JSON files
- **Scene Management** handles scene transitions

```julia
# Create a new scene
scene = Scene("MainScene")

# Add entities
player = Entity("Player")
scene.addEntity(player)

# Save scene to file
SceneWriterModule.writeScene(scene, "scenes/MainScene.json")

# Load scene from file
loadedScene = SceneLoaderModule.loadScene("scenes/MainScene.json")
```

## Main Loop

The main loop handles the core update and rendering cycle:

1. Process input
2. Update game logic
3. Render the scene
4. Repeat

```julia
# Define window properties
windowConfig = WindowConfig(
    width = 800,
    height = 600,
    title = "My Game",
    fullscreen = false
)

# Start the main loop
MainLoop.startMainLoop(windowConfig, initialScene)
```

## Physics

JulGame includes a simple physics system with:

- **Colliders** for collision detection
- **Rigidbodies** for physics simulation
- **Raycasting** for detecting objects along a line

```julia
# Add physics components
rigidbody = RigidbodyModule.create()
collider = ColliderModule.create(50, 50)
entity.addComponent(rigidbody)
entity.addComponent(collider)
```

## Input System

The input system handles:

- Keyboard input
- Mouse input
- (Future) Controller input

```julia
function update(script::PlayerController, entity)
    # Check for key presses
    if MAIN.input.isKeyPressed(SDL2.SDLK_SPACE)
        jump()
    end
    
    # Get mouse position
    mousePos = MAIN.input.mousePosition
    
    # Check for mouse buttons
    if MAIN.input.isMouseButtonPressed(SDL2.BUTTON_LEFT)
        shoot()
    end
end
```

## UI System

JulGame provides UI components for creating interfaces:

- **ImmediateText** for dynamic text without lifecycle management
- **TextBox** for static text with more formatting options
- **ScreenButton** for clickable buttons

```julia
function update()
    # Display text
    immediate("score", 
              "Score: $(player.score)", 
              "Arial.ttf", 
              24, 
              Math.Vector2(20, 20))
    
    # Create a button
    ScreenButtonModule.create("start_button", 
                              "Start Game", 
                              "Arial.ttf", 
                              24, 
                              Math.Vector2(400, 300), 
                              200, 50, true, startGame)
end
```

## Editor Integration

JulGame includes a built-in editor that provides:

- Scene editing
- Entity inspector
- Component management
- Asset management
- Play mode testing

The editor saves scenes in a JSON format that can be loaded at runtime.

## Math and Utilities

JulGame provides various utility modules:

- **Math**: Vector2, Vector3, Quaternion, etc.
- **Coroutines**: For time-based operations
- **Logging**: For debug information
- **DataManagement**: For saving/loading preferences

```julia
# Vector operations
position = Math.Vector2(100, 100)
velocity = Math.Vector2(5, 0)
position += velocity * DELTA_TIME

# Start a coroutine
Coroutine.start() do
    # Do something
    Coroutine.yield()
    # Do something after a frame
    Coroutine.waitForSeconds(2.0)
    # Do something after 2 seconds
end
``` 