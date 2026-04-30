---
title: JulGame Editor
description: A guide to using the built-in JulGame editor
---

# JulGame Editor

The JulGame Editor is a powerful tool for creating and managing your game projects. It provides a visual interface for scene creation, entity management, and component configuration.

![JulGame Editor](https://github.com/Kyjor/JulGame.jl/assets/13784123/c4ad139f-4d78-47f9-9d13-7bfd150e81bf)

## Getting Started with the Editor

### Installation

You can use the editor in two ways:

1. **Download the standalone editor** from the [releases page](https://github.com/Kyjor/JulGame.jl/releases)
2. **Run the editor from source**:
   ```bash
   cd ~/.julia/packages/JulGame/[version]/src/editor/Editor/src/
   julia Editor.jl
   ```

### Opening a Project

1. Start the editor
2. Click "Open Project" and navigate to your project folder
3. If you're starting from scratch, you can download the [example project](https://github.com/Kyjor/JulGame-Example) as a template

## Editor Interface

The editor interface is divided into several panels:

### Scene View

The main area where you can visually edit your scene:
- Pan the view by holding middle mouse button and dragging
- Zoom with the mouse wheel
- Select entities by clicking on them
- Move entities by dragging them

### Hierarchy Panel

Lists all entities in the current scene:
- Organize entities with parent-child relationships
- Select entities to edit their properties
- Right-click for context menu options
- Create new entities with the "+" button

### Inspector Panel

Shows properties of the selected entity:
- Edit transform (position, rotation, scale)
- Add, remove, and configure components
- Assign scripts to entities

### Project Panel

Navigate your project's files and assets:
- Drag assets into the scene to create entities
- Organize your project files
- Import new assets

### Console

Displays debug messages and errors:
- Monitor runtime errors
- See debug output from your game

## Working with Scenes

### Creating a New Scene

1. Click "File" > "New Scene"
2. Enter a name for your scene
3. The new scene will be created and opened in the editor

### Saving Scenes

1. Click "File" > "Save Scene" or press Ctrl+S
2. If it's a new scene, choose a location and filename
3. Scenes are saved as JSON files

### Loading Scenes

1. Click "File" > "Open Scene"
2. Navigate to your scene file (.json)
3. The scene will be loaded into the editor

## Working with Entities

### Creating Entities

1. Click the "+" button in the Hierarchy panel
2. Select the entity type (Empty, Sprite, etc.)
3. The new entity will appear in the scene

### Editing Entities

1. Select an entity in the hierarchy or scene view
2. Use the Inspector panel to edit its properties
3. Changes are applied immediately

### Organizing Entities

You can create parent-child relationships between entities:
1. Drag an entity onto another in the hierarchy
2. The dragged entity becomes a child of the target
3. Child entities inherit their parent's transform

## Working with Components

### Adding Components

1. Select an entity
2. In the Inspector panel, click "Add Component"
3. Choose a component type from the menu
4. Configure the component's properties

### Common Components

- **Sprite**: Displays an image
- **Animator**: Manages animations
- **Collider**: Handles collision detection
- **Rigidbody**: Adds physics simulation
- **SoundSource**: Plays audio
- **Scripts**: Adds custom behavior

### Component Properties

Each component has specific properties you can configure:
- Drag assets (images, sounds) to their respective fields
- Enter numeric values for properties like size, speed, etc.
- Toggle checkboxes for boolean properties

## Play Mode

Test your game directly in the editor:

1. Click the Play button (▶️) to enter Play mode
2. Your game will run in the editor
3. Click the Stop button (⏹️) to exit Play mode
4. Changes made during Play mode are temporary

## Sprite Cropping Tool

The editor includes a tool for creating sprite animations:

1. Select a sprite in the project panel
2. Click "Tools" > "Sprite Cropper"
3. Define frames by dragging on the image
4. Export the frames for use in animations

## Debug Console

The debug console provides information about your game:

1. Click the Console tab at the bottom of the editor
2. Runtime messages will appear here
3. Filter messages by type (Info, Warning, Error)
4. Clear the console with the "Clear" button

## Best Practices

- **Save Often**: The editor is still in development and might crash
- **Use Meaningful Names**: Name your entities and scenes clearly
- **Group Related Entities**: Use parent-child relationships to organize your scene
- **Test Frequently**: Use Play mode to test changes as you make them
- **Back Up Your Projects**: Keep backups of your important projects

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| Ctrl+S | Save Scene |
| Ctrl+O | Open Scene |
| Ctrl+N | New Scene |
| Delete | Delete Selected Entity |
| Ctrl+D | Duplicate Selected Entity |
| F | Frame Selected Entity |
| W | Translation Tool |
| E | Rotation Tool |
| R | Scale Tool |

## Troubleshooting

- **Editor Crashes**: The editor automatically attempts to save a backup when unhandled errors occur
- **Missing Assets**: Check that file paths are correct and assets are in the right folders
- **Script Errors**: Check the console for error messages
- **Performance Issues**: Large scenes may cause slowdowns; try breaking them into smaller scenes 