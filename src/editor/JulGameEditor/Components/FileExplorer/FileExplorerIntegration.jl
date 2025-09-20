"""
    FileExplorerIntegration

Main integration file for the comprehensive file explorer system.
Handles initialization, cleanup, and integration with the existing editor workflow.
This file ensures all components work together seamlessly with ImportFile.jl patterns.
"""

# Load all FileExplorer components in the correct order
include("FileExplorer.jl")
include("BatchOperations.jl")
include("DragDropIntegration.jl")
include("AssetMetadata.jl")
include("FavoritesAndHistory.jl")

"""
    initialize_file_explorer_system()

Initialize the complete file explorer system with all components.
This should be called during editor startup.
"""
function initialize_file_explorer_system()
    try
        # Initialize core file explorer
        initialize_file_explorer()
        
        # Initialize metadata system for existing assets
        if JulGame.BasePath != ""
            # Scan existing assets in background (non-blocking)
            @async begin
                try
                    assets_dir = joinpath(JulGame.BasePath, "assets")
                    if isdir(assets_dir)
                        refresh_all_metadata_in_directory(assets_dir)
                    end
                catch e
                    @debug "Error during initial metadata scan: $e"
                end
            end
        end
        
        # Load saved favorites and recent files
        load_explorer_settings()
        
        @info "File Explorer system initialized successfully"
        
    catch e
        @error "Failed to initialize File Explorer system: $e"
    end
end

"""
    cleanup_file_explorer_system()

Clean up the file explorer system on editor shutdown.
"""
function cleanup_file_explorer_system()
    try
        # Clean up preview caches
        cleanup_file_explorer()
        
        # Save current state
        save_explorer_settings()
        
        @info "File Explorer system cleaned up successfully"
        
    catch e
        @error "Error during File Explorer cleanup: $e"
    end
end

"""
    handle_project_change(new_project_path::String)

Handle project changes by updating the file explorer state.
"""
function handle_project_change(new_project_path::String)
    try
        if isdir(new_project_path)
            # Navigate to new project root
            navigate_to_path(new_project_path)
            
            # Clean up invalid paths from previous project
            cleanup_invalid_paths()
            
            # Add to recent projects
            add_to_recent_files(new_project_path)
            
            @info "File Explorer updated for new project: $new_project_path"
        end
    catch e
        @error "Error handling project change: $e"
    end
end

"""
    integrate_with_import_dialog(renderer, current_scene_main=nothing)

Enhanced integration with the existing ImportFile dialog system.
Provides seamless transition between file explorer and import workflow.
"""
function integrate_with_import_dialog(renderer, current_scene_main=nothing)
    # First, handle the existing ImportFile workflow
    import_dialog_active = handle_dropped_files(renderer, current_scene_main)
    
    # If no import dialog is active, handle file explorer operations
    if !import_dialog_active
        explorer = get(JulGame.EditorState, "file_explorer", nothing)
        if explorer !== nothing && explorer.batch_in_progress
            # Show batch operations progress
            show_batch_operations_panel()
        end
    end
    
    return import_dialog_active
end

"""
    setup_editor_integration()

Set up integration points with the existing editor components.
This creates the necessary connections between file explorer and other systems.
"""
function setup_editor_integration()
    # Make drag-drop functions available globally for SceneViewer integration
    if !isdefined(Main, :handle_scene_viewer_drop_target)
        Main.handle_scene_viewer_drop_target = handle_scene_viewer_drop_target
    end
    
    if !isdefined(Main, :handle_hierarchy_drop_target)
        Main.handle_hierarchy_drop_target = handle_hierarchy_drop_target
    end
    
    if !isdefined(Main, :handle_inspector_drop_target)
        Main.handle_inspector_drop_target = handle_inspector_drop_target
    end
    
    # Make file explorer functions available for menu integration
    if !isdefined(Main, :show_file_explorer_window)
        Main.show_file_explorer_window = show_file_explorer_window
    end
end

"""
    Enhanced file operations that integrate with existing systems
"""

function enhanced_file_import(filepaths::Vector{String}, destination::String="")
    """Enhanced file import that uses existing ImportFile workflow but with file explorer features"""
    
    # Filter supported files using existing ImportFile functions
    supported_files = filter(is_supported_file, filepaths)
    
    if !isempty(supported_files)
        # Add files to recent for quick access
        for filepath in supported_files
            add_to_recent_files(filepath)
        end
        
        # Use existing ImportFile dialog system
        JulGame.EditorState["dropped_files"] = supported_files
        JulGame.EditorState["import_queue_index"] = 1
        
        @info "Enhanced import: $(length(supported_files)) files queued for import"
        return true
    end
    
    return false
end

function enhanced_asset_creation(filepath::String, target_type::Symbol=:auto)
    """Enhanced asset creation that integrates with scene and metadata systems"""
    
    current_scene_main = get(JulGame.EditorState, "current_scene_main", nothing)
    if current_scene_main === nothing
        @warn "No scene loaded - cannot create asset"
        return nothing
    end
    
    # Determine creation type
    file_type = get_file_type(filepath)
    creation_type = target_type == :auto ? file_type : target_type
    
    try
        entity = nothing
        
        if creation_type == :image || (creation_type == :sprite && file_type == :image)
            entity = create_scene_entity_from_file(filepath, current_scene_main)
        elseif creation_type == :audio || (creation_type == :sound && file_type == :audio)
            entity = create_scene_entity_from_file(filepath, current_scene_main)
        elseif creation_type == :ui_button && file_type == :image
            ui_element = create_ui_element_from_file(filepath, current_scene_main, :button)
            return ui_element
        end
        
        if entity !== nothing
            # Update metadata
            metadata = get_or_create_metadata(filepath)
            current_scene_path = get(JulGame.EditorState, "current_scene_path", "")
            if current_scene_path != ""
                push!(metadata.used_in_scenes, current_scene_path)
                metadata.reference_count += 1
                metadata.last_accessed = now()
                save_metadata_to_disk(metadata)
            end
            
            # Add to recent files
            add_to_recent_files(filepath)
        end
        
        return entity
        
    catch e
        @error "Error in enhanced asset creation: $e"
        return nothing
    end
end

"""
    Performance optimization functions
"""

function optimize_file_explorer_performance()
    """Optimize file explorer performance by cleaning up unused resources"""
    
    explorer = get(JulGame.EditorState, "file_explorer", nothing)
    if explorer === nothing
        return
    end
    
    current_time = UInt64(time())
    cache_lifetime = 300_000  # 5 minutes in milliseconds
    
    # Clean up old preview cache entries
    paths_to_remove = String[]
    for (path, (texture, size, timestamp)) in explorer.preview_cache
        if current_time - timestamp > cache_lifetime
            push!(paths_to_remove, path)
        end
    end
    
    for path in paths_to_remove
        if haskey(explorer.preview_cache, path)
            texture, _, _ = explorer.preview_cache[path]
            if texture != C_NULL
                SDL2.SDL_DestroyTexture(texture)
            end
            delete!(explorer.preview_cache, path)
        end
    end
    
    # Clean up old audio cache entries
    audio_paths_to_remove = String[]
    for (path, (chunk, timestamp)) in explorer.audio_preview_cache
        if current_time - timestamp > cache_lifetime
            push!(audio_paths_to_remove, path)
        end
    end
    
    for path in audio_paths_to_remove
        if haskey(explorer.audio_preview_cache, path)
            chunk, _ = explorer.audio_preview_cache[path]
            if chunk != C_NULL
                SDL2.Mix_FreeChunk(chunk)
            end
            delete!(explorer.audio_preview_cache, path)
        end
    end
    
    if !isempty(paths_to_remove) || !isempty(audio_paths_to_remove)
        @debug "Cleaned up $(length(paths_to_remove)) image previews and $(length(audio_paths_to_remove)) audio previews"
    end
end

"""
    Context menu integration for existing components
"""

function add_file_explorer_context_menu_items(filepath::String)
    """Add file explorer specific items to existing context menus"""
    
    CImGui.Separator()
    CImGui.Text("File Explorer")
    
    # Favorites
    add_favorites_context_menu_items(filepath)
    
    # Metadata
    if CImGui.MenuItem("Edit Metadata")
        # TODO: Open metadata editor popup
        @info "Would open metadata editor for: $filepath"
    end
    
    # Show in file explorer
    if CImGui.MenuItem("Show in File Explorer")
        if isfile(filepath)
            navigate_to_path(dirname(filepath))
        elseif isdir(filepath)
            navigate_to_path(filepath)
        end
        
        # Select the item
        explorer = JulGame.EditorState["file_explorer"]
        empty!(explorer.selected_items)
        push!(explorer.selected_items, filepath)
    end
end

# Export main integration functions
export initialize_file_explorer_system, cleanup_file_explorer_system
export handle_project_change, integrate_with_import_dialog, setup_editor_integration
export enhanced_file_import, enhanced_asset_creation, optimize_file_explorer_performance
export add_file_explorer_context_menu_items
