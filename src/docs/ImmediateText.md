# Immediate Text Feature

The Immediate Text feature in JulGame allows you to easily create and update text elements in your game without having to manually manage their lifecycle. This is particularly useful for debugging information, UI labels, tooltips, or any text that changes frequently.

## Basic Usage

```julia
using JulGame
using JulGame.UI.ImmediateTextModule

# In your update function:
function update()
    # Create or update an immediate text
    immediate("my_text_id",             # Unique identifier
              "Hello, World!",          # Text content
              "FiraCode-Regular.ttf",   # Font path
              24,                       # Font size
              Math.Vector2(100, 100),   # Position
              false,                    # Center horizontally?
              false)                    # Center vertically?
end
```

## Key Features

1. **Easy Creation and Updates**: Call the `immediate()` function to create or update text elements
2. **Automatic Management**: Immediate texts are automatically cleaned up if not used for 5 seconds
3. **Unique Identifiers**: Each immediate text is identified by a unique string ID
4. **Efficient Updates**: Only regenerates textures when properties change
5. **World Space Support**: Can be positioned in world space or screen space

## Function Parameters

The `immediate()` function takes the following parameters:

```julia
immediate(id::String,                     # Unique identifier for this text
          text::String,                   # The text content to display
          fontPath::String,               # Path to the font file
          fontSize::Number,               # Size of the font
          position::Math.Vector2,         # Position of the text
          isCenteredX::Bool = false,      # Whether to center the text horizontally
          isCenteredY::Bool = false;      # Whether to center the text vertically
          anchorOffset::Math.Vector2 = Math.Vector2(0,0),  # Offset from the anchor point
          isWorldEntity::Bool = false)    # Whether this text is positioned in world space
```

## Examples

### Dynamic Debug Information

```julia
function update()
    mousePos = MAIN.input.mousePosition
    
    immediate("mouse_pos", 
              "Mouse Position: ($(mousePos.x), $(mousePos.y))", 
              "FiraCode-Regular.ttf", 
              20, 
              Math.Vector2(mousePos.x, mousePos.y - 30), 
              true,  # center horizontally
              false) # don't center vertically
    
    immediate("fps_counter", 
              "FPS: $(round(1000 / DELTA_TIME))", 
              "FiraCode-Regular.ttf", 
              24, 
              Math.Vector2(MAIN.windowWidth / 2, 50), 
              true,   # center horizontally
              false)  # don't center vertically
end
```

### Entity Labels in World Space

```julia
function update()
    # For each entity that needs a label
    for entity in entities
        immediate("entity_$(entity.id)_label", 
                  entity.name, 
                  "FiraCode-Regular.ttf", 
                  18, 
                  entity.position + Math.Vector2(0, -30),  # Position above entity
                  true,   # center horizontally
                  false;  # don't center vertically
                  isWorldEntity=true)  # Position in world space
    end
end
```

### Multiple Elements Created in a Loop

```julia
function update()
    # Create multiple numbered texts in a row
    for i in 1:5
        immediate("number_$(i)", 
                  "Text #$(i)", 
                  "FiraCode-Regular.ttf", 
                  18, 
                  Math.Vector2(100, 100 + (i * 30)), 
                  false, 
                  false)
    end
end
```

## Performance Considerations

- Immediate texts are designed to be efficient, only updating textures when properties change
- They are automatically cleaned up if not used for 5 seconds to prevent memory leaks
- For very text-heavy applications, consider using a texture atlas for better performance

## Full Example

See the `examples/ImmediateTextExample.jl` file for a complete example of how to use immediate text in your game. 