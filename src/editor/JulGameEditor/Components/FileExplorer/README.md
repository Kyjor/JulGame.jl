# JulGame File Explorer System

A comprehensive file management system for the JulGame engine editor that seamlessly integrates with the existing ImportFile.jl workflow while providing advanced features for game asset management.

## Overview

The File Explorer system extends the existing ImportFile.jl patterns to provide a complete asset management solution with:

- **Advanced Navigation**: Breadcrumb paths, history, tree view, and quick access
- **Smart Search & Filtering**: Real-time search, type filtering, and tag-based organization
- **Asset Previews**: Inline thumbnails with caching for images, audio, and scripts
- **Batch Operations**: Multi-select operations with progress tracking and undo support
- **Drag & Drop Integration**: Direct scene integration with visual feedback
- **Metadata Management**: Asset tagging, descriptions, and dependency tracking
- **Favorites & History**: Bookmarking and recent files with workspace support

## Architecture

### Core Components

1. **FileExplorer.jl** - Core navigation, file listing, and state management
2. **FileExplorerUI.jl** - Main user interface with ImGui integration
3. **BatchOperations.jl** - Multi-select operations and batch processing
4. **DragDropIntegration.jl** - Scene integration and drag-and-drop handling
5. **AssetMetadata.jl** - Metadata extraction, tagging, and persistence
6. **FavoritesAndHistory.jl** - Bookmarks, recent files, and workspace management
7. **FileExplorerIntegration.jl** - Main integration layer with existing editor

### Integration Points

- **ImportFile.jl**: Seamless integration with existing import workflow
- **SceneViewer.jl**: Drag-and-drop asset creation in scenes
- **Hierarchy.jl**: Entity creation and parent-child relationships
- **Inspector.jl**: Component assignment via drag-and-drop
- **Editor.jl**: Main editor loop integration and lifecycle management

## Features

### Navigation System
- Breadcrumb navigation with clickable path segments
- Back/Forward history navigation
- Tree view for hierarchical folder browsing
- Quick access to common project directories
- Project boundary enforcement (cannot navigate above project root)

### Search and Filtering
- Real-time filename search with auto-complete
- File type filtering (images, audio, scripts, etc.)
- Tag-based filtering and organization
- Advanced sorting options (name, date, size, type)
- Hidden file toggle

### Asset Preview System
- Thumbnail generation for images with aspect ratio preservation
- Audio file preview with playback controls
- Script file syntax highlighting and metadata
- Preview caching with automatic cleanup
- Configurable preview sizes

### Batch Operations
- Multi-select with Ctrl+Click and Shift+Click
- Batch copy, move, delete operations
- Progress tracking with cancellation support
- Conflict resolution with auto-renaming
- Undo/redo functionality for destructive operations

### Drag and Drop Integration
- Direct asset dropping onto scene viewer
- Automatic entity creation based on asset type
- UI element creation for images
- Component assignment to existing entities
- Visual drop target feedback

### Metadata and Tagging
- Automatic metadata extraction (dimensions, file size, etc.)
- User-defined tags with auto-suggestions
- Asset descriptions and custom properties
- Dependency tracking across scenes
- Usage statistics and last accessed times

### Favorites and History
- Bookmark frequently used files and folders
- Recent files tracking with intelligent ranking
- Workspace management for different project contexts
- Quick access toolbar with project shortcuts
- Persistent storage across editor sessions

## Usage

### Basic Navigation
1. Use the navigation toolbar to move between folders
2. Click breadcrumb segments for quick navigation
3. Toggle tree view for hierarchical browsing
4. Use search bar for quick file location

### Asset Management
1. **Import Assets**: Drag files from system explorer or use existing import dialog
2. **Preview Assets**: Enable preview mode to see thumbnails and metadata
3. **Organize Assets**: Use tags and favorites to organize your assets
4. **Batch Operations**: Select multiple files and use batch operations panel

### Scene Integration
1. **Create Entities**: Drag assets directly onto scene viewer
2. **Add Components**: Drag assets onto entities in inspector
3. **UI Creation**: Drag images onto UI canvas for button creation
4. **Smart Placement**: Multi-asset drops are automatically arranged

### Advanced Features
1. **Metadata Editing**: Right-click assets to edit tags and descriptions
2. **Dependency Tracking**: See which scenes use specific assets
3. **Workspace Management**: Save and load different workspace configurations
4. **Performance Optimization**: Automatic cache cleanup and resource management

## Configuration

### Settings
Settings are automatically saved to `.julgame_explorer_settings.toml` in the project directory:

- Preview size and visibility
- Sort preferences
- Hidden file visibility
- Tree view and metadata panel states
- Recent files and favorites

### Metadata Storage
Asset metadata is stored in `.julgame_metadata/` directories alongside assets:
- Individual JSON files for each asset
- Tags, descriptions, and custom properties
- Usage tracking and reference counts
- Automatic cleanup of orphaned metadata

### Performance Tuning
- Preview cache size limits
- Automatic cache cleanup intervals
- Virtual scrolling for large directories
- Background metadata scanning

## API Reference

### Core Functions
- `initialize_file_explorer_system()` - Initialize the complete system
- `navigate_to_path(path)` - Navigate to specific directory
- `add_to_favorites(path)` - Add file/folder to favorites
- `get_or_create_metadata(filepath)` - Get asset metadata

### Integration Functions
- `handle_scene_viewer_drop_target()` - Scene drag-drop handling
- `create_scene_entity_from_file(filepath, scene)` - Create entities from assets
- `enhanced_file_import(filepaths, destination)` - Enhanced import workflow

### UI Functions
- `show_file_explorer_window(show_ref, renderer)` - Main window display
- `show_batch_operations_panel()` - Batch operations interface
- `show_asset_metadata_editor(filepath)` - Metadata editing interface

## Performance Considerations

### Memory Management
- Automatic preview texture cleanup
- LRU cache for frequently accessed previews
- Background metadata scanning to avoid UI blocking
- Virtual scrolling for large file lists

### Disk I/O Optimization
- Lazy loading of file information
- Cached directory listings with invalidation
- Debounced file system watching
- Efficient metadata persistence

### Rendering Optimization
- ImGui best practices for large lists
- Conditional rendering based on visibility
- Efficient texture management
- Minimal state updates

## Troubleshooting

### Common Issues
1. **Preview not loading**: Check file permissions and supported formats
2. **Slow performance**: Adjust preview cache size or disable previews
3. **Missing metadata**: Refresh metadata or check file permissions
4. **Drag-drop not working**: Ensure scene is loaded and file types are supported

### Debug Information
Enable debug logging to see detailed information:
```julia
ENV["JULIA_DEBUG"] = "FileExplorer"
```

### File System Issues
- Ensure proper read/write permissions for project directories
- Check for long path limitations on Windows
- Verify network drive access if applicable

## Contributing

When extending the file explorer system:

1. **Follow Existing Patterns**: Use ImportFile.jl conventions for consistency
2. **Maintain Integration**: Ensure new features work with existing editor components
3. **Performance First**: Consider memory and disk I/O implications
4. **Error Handling**: Use robust error handling with graceful degradation
5. **Documentation**: Update this README and add inline documentation

## License

This file explorer system is part of the JulGame engine and follows the same licensing terms.
