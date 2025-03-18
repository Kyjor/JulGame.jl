---
title: ImmediateUI
description: Create ephemeral UI elements with minimal code in JulGame
---

# ImmediateUI

The ImmediateUI system allows you to create temporary UI elements that automatically manage their lifecycle. It's ideal for debug overlays, tooltips, notifications, and other transient UI elements that don't need to be permanently added to your game scene.

## Overview

ImmediateUI provides a way to create UI elements that:
- Automatically clean up after a period of inactivity
- Can be created, updated, and rendered with minimal code
- Leverage existing UI components for consistency
- Don't require explicit entity creation

## Import

```julia
using JulGame.UI.ImmediateUIModule
```

## Basic Usage

### Creating immediate text:

```julia
# Display text that disappears after 5 seconds of not being updated
immediate_text(
    "fps_counter",                  # Unique identifier
    "FPS: $(round(Int, 1.0 / DELTA_TIME))",  # Text content
    "Arial.ttf",                    # Font
    18,                             # Font size
    Math.Vector2(10, 10)            # Position
)
```

### Creating immediate buttons:

```julia
# Create a temporary button that persists as long as it's updated
immediate_button(
    "restart_btn",                  # Unique identifier
    "Restart Level",                # Button text
    "Arial.ttf",                    # Font
    24,                             # Font size
    Math.Vector2(400, 300),         # Position (center of screen)
    200,                            # Width
    50,                             # Height
    true,                           # Center the button at this position
    () -> restart_level()           # Click callback function
)
```

## Function Reference

### immediate_text()

```julia
immediate_text(
    id::String,                          # Unique identifier
    text::String,                        # Text to display
    fontPath::String,                    # Path to font file
    fontSize::Number,                    # Font size
    position::Math.Vector2,              # Position
    width::Number = 0,                   # Width (0 for auto)
    height::Number = 0,                  # Height (0 for auto)
    isCenteredX::Bool = false,           # Center horizontally?
    isCenteredY::Bool = false;           # Center vertically?
    anchorOffset::Math.Vector2 = Math.Vector2(0,0),  # Offset from position
    isWorldEntity::Bool = false,         # In world space? (vs. screen space)
    alpha::Number = 255                  # Transparency (0-255)
)
```

### immediate_button()

```julia
immediate_button(
    id::String,                          # Unique identifier
    text::String,                        # Button label
    fontPath::String,                    # Path to font file
    fontSize::Number,                    # Font size
    position::Math.Vector2,              # Position
    width::Number,                       # Button width
    height::Number,                      # Button height
    isCentered::Bool = true,             # Center at position?
    callback::Function = () -> nothing;  # Click handler
    buttonUpPath::String = "",           # Normal state image
    buttonDownPath::String = "",         # Pressed state image
    textOffset::Math.Vector2 = Math.Vector2(0,0),  # Text offset
    alpha::Number = 255                  # Transparency (0-255)
)
```

### render_all_immediate_components()

```julia
render_all_immediate_components(debug::Bool = false)
```

Renders all active immediate UI components. This is automatically called by the JulGame engine every frame, so you don't typically need to call it directly.

### cleanup_all_immediate_components()

```julia
cleanup_all_immediate_components()
```

Explicitly cleans up all immediate UI components. Useful when changing scenes or when you want to remove all immediate UI elements at once.

## Lifecycle Management

ImmediateUI components are automatically managed:

1. When you first call `immediate_text()` or `immediate_button()` with a new ID, a component is created
2. When you call the same function with the same ID, the existing component is updated
3. If a component isn't updated for 5 seconds (default timeout), it's automatically removed
4. All components can be explicitly removed with `cleanup_all_immediate_components()`

## Examples

### Debug Overlay

```julia
function update()
    # Update debug information every frame
    immediate_text("fps", "FPS: $(round(Int, 1.0 / DELTA_TIME))", "Arial.ttf", 16, Math.Vector2(10, 10))
    immediate_text("position", "Player Pos: $(player.transform.position)", "Arial.ttf", 16, Math.Vector2(10, 30))
    immediate_text("health", "Health: $(player.health)/100", "Arial.ttf", 16, Math.Vector2(10, 50))
end
```

### Temporary Notification

```julia
function show_notification(message)
    # Show a centered notification
    immediate_text(
        "notification",
        message,
        "Arial.ttf",
        24,
        Math.Vector2(400, 100),    # Top center of screen
        0, 0,                      # Auto size
        true, false                # Center horizontally only
    )
    
    # The notification will disappear after 5 seconds
    # if not updated again with a new message
end
```

### Context-Sensitive Actions

```julia
function update()
    # Only show interaction button when near an interactable object
    if is_near_interactable()
        immediate_button(
            "interact_btn",
            "Press E to interact",
            "Arial.ttf",
            18,
            get_interactable_position() + Math.Vector2(0, -50), # Above object
            150, 30,
            true
        )
    end
    
    # Button disappears when player moves away
end
```

### Dialog System

```julia
function show_dialog(character_name, dialog_text)
    # Show character name
    immediate_text(
        "dialog_name",
        character_name,
        "Arial-Bold.ttf",
        20,
        Math.Vector2(400, 450),
        0, 0,
        true, false  # Center horizontally
    )
    
    # Show dialog text
    immediate_text(
        "dialog_text",
        dialog_text,
        "Arial.ttf",
        18,
        Math.Vector2(400, 480),
        600, 0,      # Fixed width, auto height
        true, false  # Center horizontally
    )
    
    # Show continue button
    immediate_button(
        "dialog_continue",
        "Continue",
        "Arial.ttf",
        16,
        Math.Vector2(650, 550),
        100, 30,
        true,
        () -> advance_dialog()
    )
end
```

## Advantages over Regular UI Components

ImmediateUI offers several advantages:

1. **No Entity Required**: Create UI without creating entities or adding components
2. **Automatic Lifecycle**: Components are automatically managed and cleaned up
3. **Simplified API**: Create and update UI in a single function call
4. **Less Boilerplate**: Reduce code required for temporary UI elements
5. **Stateless Approach**: Create UI as needed without tracking references

## Best Practices

- **Consistent IDs**: Use consistent, descriptive IDs for your immediate UI elements
- **Frame-to-Frame Updates**: Update elements every frame they should be visible
- **Screen vs World Space**: Use `isWorldEntity=true` for UI that follows world objects
- **Layering**: Create your immediate UI elements in a consistent order for predictable layering
- **Timeouts**: Remember components disappear after 5 seconds without updates

## Technical Details

Under the hood, ImmediateUI:
1. Reuses the TextBox and ScreenButton components
2. Manages a cache of active components
3. Tracks timestamps of last updates
4. Handles automatic garbage collection of unused components
5. Renders components with the same visual quality as regular UI

## See Also

- [TextBox](/JulGame.jl/reference/UI/text-box/) - For persistent text elements
- [ScreenButton](/JulGame.jl/reference/UI/screen-button/) - For persistent buttons
- [UI Overview](/JulGame.jl/reference/UI/) - For an overview of UI systems in JulGame 