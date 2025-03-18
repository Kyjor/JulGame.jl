---
title: JulGame Tutorials
description: Step-by-step guides to create games with JulGame
---

# JulGame Tutorials

Learn how to create games with JulGame through these step-by-step tutorials. Each tutorial builds on the previous one, gradually introducing more complex concepts.

## Tutorial 1: Creating a Simple Game

In this tutorial, we'll create a basic game where the player controls a character that collects coins.

### Prerequisites

- JulGame installed
- Basic knowledge of Julia
- Editor installed (see [Getting Started](/JulGame.jl/guides/getting-started/))

### Step 1: Project Setup

1. Create a new folder for your project
2. Open the JulGame Editor
3. Open your project folder in the editor
4. Create the following directory structure:

```
MyGame/
├── assets/
│   ├── images/
│   └── audio/
├── scenes/
└── scripts/
```

### Step 2: Preparing Assets

For this tutorial, you'll need:
- A player sprite (e.g., `player.png`)
- A coin sprite (e.g., `coin.png`)
- Optional: background music and sound effects

Place these files in the appropriate folders under `assets/`.

### Step 3: Creating the Main Scene

1. In the editor, create a new scene (File > New Scene)
2. Save it as `MainScene.json` in the `scenes` folder

### Step 4: Creating the Player

1. Click the "+" button in the Hierarchy panel
2. Select "Create Entity"
3. Name it "Player"
4. In the Inspector panel, set its position to (0, 0)
5. Add a Sprite component:
   - Click "Add Component" > "Sprite"
   - Select your player sprite
6. Add a Collider component:
   - Click "Add Component" > "Collider"
   - Set Width and Height to match your sprite
7. We'll add a script later

### Step 5: Creating Coins

1. Create a new empty entity named "Coin"
2. Add a Sprite component with your coin sprite
3. Add a Collider component
4. Position it somewhere in the scene
5. Duplicate this coin a few times and place them around the scene

### Step 6: Creating Player Script

1. Create a new file in `scripts/PlayerController.jl` with the following code:

```julia
using JulGame
using JulGame.Math

struct PlayerController <: Script
    speed::Float64
    score::Int
    
    PlayerController() = new(200.0, 0)
end

function update(script::PlayerController, entity)
    # Handle movement
    moveDirection = Math.Vector2(0, 0)
    
    if MAIN.input.isKeyPressed(SDL2.SDLK_RIGHT)
        moveDirection.x += 1
    end
    if MAIN.input.isKeyPressed(SDL2.SDLK_LEFT)
        moveDirection.x -= 1
    end
    if MAIN.input.isKeyPressed(SDL2.SDLK_DOWN)
        moveDirection.y += 1
    end
    if MAIN.input.isKeyPressed(SDL2.SDLK_UP)
        moveDirection.y -= 1
    end
    
    # Normalize and apply movement
    if moveDirection.x != 0 || moveDirection.y != 0
        moveDirection = Math.normalize(moveDirection)
        entity.transform.position += moveDirection * script.speed * DELTA_TIME
    end
    
    # Display score
    using JulGame.UI.ImmediateUIModule
    immediate_text("score_display", 
              "Score: $(script.score)", 
              "Arial.ttf", 
              24, 
              Math.Vector2(20, 20))
end

function onCollisionEnter(script::PlayerController, entity, other)
    # Check if we collided with a coin
    if startswith(other.name, "Coin")
        # Increase score
        script.score += 1
        
        # Remove the coin
        MAIN.scene.removeEntity(other)
    end
end
```

### Step 7: Adding the Script to the Player

1. Select the Player entity
2. In the Inspector, click "Add Component" > "Script"
3. Enter "PlayerController" as the script name

### Step 8: Running the Game

1. Save your scene
2. Create a `Run.jl` file in your project root with:

```julia
using JulGame
using JulGame.SceneManagement.SceneLoaderModule

function main()
    # Define window properties
    windowConfig = WindowConfig(
        width = 800,
        height = 600,
        title = "My First JulGame",
        fullscreen = false
    )
    
    # Load the main scene
    initialScene = loadScene("scenes/MainScene.json")
    
    # Start the game
    MainLoop.startMainLoop(windowConfig, initialScene)
end

main()
```

3. Run your game:

```bash
cd path/to/your/project
julia Run.jl
```

Congratulations! You've created a simple game with JulGame.

## Tutorial 2: Adding Animation

Building on our simple game, let's add animations to make it more dynamic.

### Step 1: Prepare Animation Frames

For animation, you'll need a sprite sheet or multiple frames. Place these in your `assets/images/` folder.

### Step 2: Add an Animator Component

1. Select the Player entity
2. Click "Add Component" > "Animator"
3. Create a new animation:
   - Name: "Walk"
   - Select your sprite frames
   - Set frame duration (e.g., 0.1 seconds per frame)
   - Set to loop

### Step 3: Update the Player Script

Modify `PlayerController.jl` to handle animations:

```julia
function update(script::PlayerController, entity)
    # Get references to components
    animator = entity.getComponent("Animator")
    
    # Handle movement
    moveDirection = Math.Vector2(0, 0)
    
    if MAIN.input.isKeyPressed(SDL2.SDLK_RIGHT)
        moveDirection.x += 1
    end
    if MAIN.input.isKeyPressed(SDL2.SDLK_LEFT)
        moveDirection.x -= 1
    end
    if MAIN.input.isKeyPressed(SDL2.SDLK_DOWN)
        moveDirection.y += 1
    end
    if MAIN.input.isKeyPressed(SDL2.SDLK_UP)
        moveDirection.y -= 1
    end
    
    # Normalize and apply movement
    if moveDirection.x != 0 || moveDirection.y != 0
        moveDirection = Math.normalize(moveDirection)
        entity.transform.position += moveDirection * script.speed * DELTA_TIME
        
        # Play walk animation
        AnimatorModule.play(animator, "Walk")
    else
        # Stop animation when not moving
        AnimatorModule.stop(animator)
    end
    
    # Flip sprite based on direction
    if moveDirection.x < 0
        entity.transform.scale.x = -1  # Flip horizontally
    elseif moveDirection.x > 0
        entity.transform.scale.x = 1   # Normal orientation
    end
    
    # Score display code (same as before)
    using JulGame.UI.ImmediateUIModule
    immediate_text("score_display", 
              "Score: $(script.score)", 
              "Arial.ttf", 
              24, 
              Math.Vector2(20, 20))
end
```

## Tutorial 3: Adding Sound

Let's add sound effects and background music to our game.

### Step 1: Prepare Audio Files

Place your audio files in the `assets/audio/` folder:
- Background music (e.g., `music.mp3`)
- Coin collection sound (e.g., `coin.wav`)

### Step 2: Add Background Music

1. Create a new empty entity named "BackgroundMusic"
2. Add a SoundSource component:
   - Click "Add Component" > "SoundSource"
   - Select your music file
   - Check "Loop" to make it play continuously
   - Set the volume (e.g., 0.5)

### Step 3: Update the Player Script for Sound Effects

Modify `PlayerController.jl` to play a sound when collecting coins:

```julia
function onCollisionEnter(script::PlayerController, entity, other)
    # Check if we collided with a coin
    if startswith(other.name, "Coin")
        # Increase score
        script.score += 1
        
        # Play coin sound
        SoundSourceModule.playSoundOnce("assets/audio/coin.wav", 1.0)
        
        # Remove the coin
        MAIN.scene.removeEntity(other)
    end
end
```

## Next Steps

Now that you've completed these basic tutorials, you can:

1. Add more game mechanics like enemies, obstacles, or power-ups
2. Create additional levels using different scenes
3. Add a UI with buttons for restarting or changing levels
4. Implement a simple scoring system with high scores

For more advanced tutorials and examples, check out the [Examples](/JulGame.jl/guides/examples/) section. 