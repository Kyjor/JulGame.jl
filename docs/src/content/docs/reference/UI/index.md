---
title: UI Components
description: Overview of UI and text components in JulGame
---

# UI Components

JulGame provides a set of UI components for creating both in-game interfaces and debug overlays. These components allow you to display information, create interactive elements, and manage user input.

## Available UI Components

JulGame includes several UI components for different use cases:

| Component | Description | Use Case |
|-----------|-------------|----------|
| [ImmediateText](/JulGame.jl/reference/UI/immediate-text/) | Dynamic text without lifecycle management | Debug info, temporary labels |
| [TextBox](/JulGame.jl/reference/UI/text-box/) | Static text elements with more formatting options | Dialogue, UI labels |
| [ScreenButton](/JulGame.jl/reference/UI/screen-button/) | Clickable buttons for user interaction | UI menus, clickable elements |

## UI Namespaces

The UI components in JulGame are organized in the following namespaces:

```julia
using JulGame.UI                      # Access all UI components
using JulGame.UI.ImmediateTextModule  # For ImmediateText only
using JulGame.UI.TextBoxModule        # For TextBox only 
using JulGame.UI.ScreenButtonModule   # For ScreenButton only
```

## Coordinate Systems

JulGame UI components can operate in two coordinate systems:

1. **Screen Space** - Coordinates are relative to the screen, independent of camera position
2. **World Space** - Coordinates are in the game world, affected by camera position and zoom

Most UI components default to screen space, but can be configured to use world space when needed (using the `isWorldEntity` parameter where available).

## Example: Creating a Simple UI

Here's an example of how to combine multiple UI components:

```julia
using JulGame
using JulGame.UI
using JulGame.Math

# In your update function
function update()
    # Show player health as immediate text
    immediate("health_display", 
              "Health: $(player.health)",
              "Arial.ttf", 
              20, 
              Math.Vector2(20, 20), 
              false, 
              false)
    
    # Display a text box for dialogue
    if isDialogueActive
        TextBoxModule.create("dialogue_box",
                             currentDialogueText,
                             "Arial.ttf",
                             18,
                             Math.Vector2(MAIN.windowWidth / 2, MAIN.windowHeight - 100),
                             400,  # width
                             100,  # height
                             true,  # centered horizontally
                             true)  # centered vertically
    end
    
    # Create a button for menu options
    ScreenButtonModule.create("quit_button",
                              "Quit Game",
                              "Arial.ttf",
                              24,
                              Math.Vector2(MAIN.windowWidth / 2, MAIN.windowHeight / 2),
                              200,  # width
                              50,   # height
                              true, # centered
                              quitGame)  # callback function
end

function quitGame()
    # Handle quit game logic
    println("Quitting game...")
    # Add your quit logic here
end
```

## Best Practices

- **Screen Space UI**: For HUD elements, use screen space coordinates
- **World Space UI**: For labels attached to entities, use world space coordinates
- **Text Optimization**: Avoid creating new text elements every frame if the content doesn't change
- **Responsive UI**: Calculate positions based on screen dimensions for responsive layouts

## Advanced Topics

- **Custom UI Components**: You can create custom UI components by extending the base UI classes
- **UI Animations**: Animate UI properties like position, size, and opacity
- **Input Handling**: UI components can respond to mouse and keyboard input 