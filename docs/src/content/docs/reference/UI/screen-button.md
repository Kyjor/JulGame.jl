---
title: ScreenButton
description: Create interactive buttons for your JulGame UI
---

# ScreenButton

The ScreenButton component allows you to create clickable buttons in your game's user interface. It supports different button states (up/down), text labels, and click event handling.

## Overview

ScreenButton provides interactive UI elements that:
- Can be clicked by the user
- Show different visual states (normal/pressed)
- Can contain text labels
- Support custom click event handlers

## Import

```julia
using JulGame.UI.ScreenButtonModule
```

## Basic Usage

```julia
# Create a button
ScreenButtonModule.create(
    "start_button",                      # Name/identifier
    "Start Game",                        # Button text
    "Arial.ttf",                         # Font path
    24,                                  # Font size
    Math.Vector2(400, 300),              # Position
    200,                                 # Width
    50,                                  # Height
    true,                                # Is centered?
    startGame                            # Click callback function
)

# Define the callback function
function startGame()
    println("Game started!")
    # Your game start logic here
end
```

## Function Reference

### create()

```julia
ScreenButtonModule.create(
    name::String,                        # Name/identifier for this button
    text::String,                        # The text label on the button
    fontPath::String,                    # Path to the font file
    fontSize::Number,                    # Size of the font
    position::Math.Vector2,              # Position of the button
    width::Number,                       # Width of the button
    height::Number,                      # Height of the button
    isCentered::Bool,                    # Whether the button is centered at its position
    callback::Function;                  # Function to call when the button is clicked
    buttonUpPath::String = "",           # Image for button normal state (optional)
    buttonDownPath::String = "",         # Image for button pressed state (optional)
    textOffset::Math.Vector2 = Math.Vector2(0, 0), # Offset for positioning the text
    alpha::Number = 255,                 # Transparency (0-255)
    persistentBetweenScenes::Bool = false # Whether to persist when changing scenes
)
```

## Properties

| Property | Type | Description |
|----------|------|-------------|
| `name` | `String` | Identifier for the button |
| `text` | `String` | The text label on the button |
| `fontPath` | `String` | Path to the font file |
| `position` | `Math.Vector2` | Position of the button |
| `size` | `Math.Vector2` | Size (width and height) of the button |
| `buttonUpSpritePath` | `String` | Path to the normal state image |
| `buttonDownSpritePath` | `String` | Path to the pressed state image |
| `textOffset` | `Math.Vector2` | Offset for positioning the text |
| `clickEvents` | `Vector{Function}` | Functions to call when clicked |
| `isHovered` | `Bool` | Whether the button is currently being hovered |
| `persistentBetweenScenes` | `Bool` | Whether the button persists between scene changes |

## Examples

### Simple Text Button

```julia
# Create a simple button with text only
ScreenButtonModule.create(
    "quit_button",                       # Name
    "Quit Game",                         # Text
    "Arial.ttf",                         # Font
    24,                                  # Size
    Math.Vector2(400, 400),              # Position
    200,                                 # Width
    50,                                  # Height
    true,                                # Is centered
    quitGame                             # Callback function
)

function quitGame()
    # Handle quit logic
    MAIN.isRunning = false
end
```

### Button with Custom Sprites

```julia
# Create a button with custom up/down state sprites
ScreenButtonModule.create(
    "settings_button",                   # Name
    "Settings",                          # Text
    "Arial.ttf",                         # Font
    20,                                  # Size
    Math.Vector2(700, 50),               # Position (top right)
    150,                                 # Width
    40,                                  # Height
    false,                               # Not centered
    openSettings;                        # Callback function
    buttonUpPath="button_normal.png",    # Normal state sprite
    buttonDownPath="button_pressed.png", # Pressed state sprite
    textOffset=Math.Vector2(0, -2)       # Slight text offset for better appearance
)

function openSettings()
    # Open settings menu logic
    println("Opening settings menu")
end
```

### Menu with Multiple Buttons

```julia
# Create a row of menu buttons
menuOptions = ["New Game", "Load Game", "Options", "Quit"]
menuCallbacks = [newGame, loadGame, options, quitGame]

for (index, option) in enumerate(menuOptions)
    ScreenButtonModule.create(
        "menu_$(option)",                    # Unique name
        option,                              # Button text
        "Arial.ttf",                         # Font
        24,                                  # Size
        Math.Vector2(400, 200 + (index * 60)), # Stacked vertically
        250,                                 # Width
        50,                                  # Height
        true,                                # Centered
        menuCallbacks[index]                 # Corresponding callback
    )
end
```

## Managing Buttons

### Adding Click Events

You can add additional click events to an existing button:

```julia
ScreenButtonModule.addClickEvent("start_button", logButtonClick)

function logButtonClick()
    println("Button was clicked!")
end
```

### Removing Buttons

To remove a button when it's no longer needed:

```julia
ScreenButtonModule.remove("start_button")
```

## Best Practices

- **Consistent Styling**: Use consistent button sizes and styles throughout your UI
- **Clear Labels**: Use clear and concise text labels
- **Feedback**: Provide visual feedback when buttons are pressed
- **Positioning**: Use centering for main menu buttons, and edge alignment for utility buttons

## See Also

- [TextBox](/JulGame.jl/reference/UI/text-box/) - For text display
- [ImmediateText](/JulGame.jl/reference/UI/immediate-text/) - For temporary text
- [UI Overview](/JulGame.jl/reference/UI/) - Overview of UI components in JulGame 