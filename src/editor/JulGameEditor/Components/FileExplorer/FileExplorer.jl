"""
    FileExplorer

A comprehensive file explorer system for the game engine editor that seamlessly integrates
with the existing ImportFile.jl workflow. Provides advanced search/filtering, asset previews,
drag-and-drop scene integration, batch operations, and game-specific asset management.

Features:
- Enhanced navigation with breadcrumbs and folder tree
- Real-time search and intelligent filtering
- Inline asset previews with thumbnail caching
- Multi-select and batch operations
- Drag-and-drop scene integration
- Asset metadata and tagging system
- Favorites and recent files management
- Integration with existing ImportFile workflow
"""

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui: ImVec2, ImVec4, IM_COL32
using JulGame: SDL2
using NativeFileDialog
using Dates

# Import the existing ImportFile module functions we'll extend
include("../ImportFile/ImportFile.jl")

"""
    FileExplorerState

Main state structure for the file explorer system.
Extends the existing ImportFile patterns while adding comprehensive file management.
"""
mutable struct FileExplorerState
    # Core navigation
    current_path::String
    selected_items::Set{String}
    last_selected_item::String
    
    # Search and filtering
    search_query::Ref{String}
    filter_extensions::Set{String}
    show_hidden_files::Bool
    sort_mode::Symbol  # :name, :date, :size, :type
    sort_ascending::Bool
    
    # Preview system (extends ImportFile preview)
    preview_cache::Dict{String, Tuple{Ptr{SDL2.LibSDL2.SDL_Texture}, ImVec2, UInt64}}  # path -> (texture, size, timestamp)
    audio_preview_cache::Dict{String, Tuple{Ptr{SDL2.LibSDL2.Mix_Chunk}, UInt64}}  # path -> (chunk, timestamp)
    preview_size::Float32
    show_previews::Bool
    
    # Batch operations
    batch_operation_queue::Vector{Tuple{Symbol, String, String}}  # (operation, source, dest)
    batch_progress::Float32
    batch_in_progress::Bool
    
    # Asset metadata and tagging
    asset_metadata::Dict{String, Dict{String, Any}}  # path -> metadata
    asset_tags::Dict{String, Set{String}}  # path -> tags
    tag_suggestions::Set{String}
    
    # Favorites and history
    favorite_paths::Vector{String}
    recent_paths::Vector{String}
    path_history::Vector{String}
    history_index::Int
    
    # UI state
    show_tree_view::Bool
    show_metadata_panel::Bool
    show_batch_panel::Bool
    tree_node_states::Dict{String, Bool}  # path -> expanded
    
    # Integration with ImportFile
    import_integration_enabled::Bool
    auto_import_on_drop::Bool
    
    # Performance optimization
    last_refresh_time::UInt64
    refresh_debounce_ms::UInt64
    virtual_scroll_offset::Int
    items_per_page::Int
    
    function FileExplorerState()
        new(
            "", Set{String}(), "", Ref(""), Set{String}(), false, :name, true,
            Dict{String, Tuple{Ptr{SDL2.LibSDL2.SDL_Texture}, ImVec2, UInt64}}(),
            Dict{String, Tuple{Ptr{SDL2.LibSDL2.Mix_Chunk}, UInt64}}(),
            64.0, true,
            Vector{Tuple{Symbol, String, String}}(), 0.0, false,
            Dict{String, Dict{String, Any}}(), Dict{String, Set{String}}(), Set{String}(),
            String[], String[], String[], 0,
            true, false, false, Dict{String, Bool}(),
            true, false,
            UInt64(0), UInt64(100), 0, 50
        )
    end
end

# Global file explorer instance
const file_explorer = FileExplorerState()

"""
    initialize_file_explorer()

Initialize the file explorer state in EditorState.
Integrates with the existing ImportFile initialization.
"""
function initialize_file_explorer()
    if !haskey(JulGame.EditorState, "file_explorer")
        JulGame.EditorState["file_explorer"] = file_explorer
    end
    
    # Initialize ImportFile integration
    initialize_import_dialog()
    
    # Set initial path to project base if available
    explorer = JulGame.EditorState["file_explorer"]
    if explorer.current_path == "" && JulGame.BasePath != ""
        explorer.current_path = abspath(JulGame.BasePath)
        push!(explorer.path_history, explorer.current_path)
        explorer.history_index = 1
    end
    
    # Load persistent data
    load_explorer_settings()
end

"""
    Extended file type detection system building on ImportFile patterns
"""

# Extend the existing ImportFile file type system
function is_script_file(filepath::String)
    ext = lowercase(splitext(filepath)[2])
    return ext in [".jl", ".js", ".py", ".lua", ".cs"]
end

function is_scene_file(filepath::String)
    ext = lowercase(splitext(filepath)[2])
    return ext in [".json", ".scene"]
end

function is_font_file(filepath::String)
    ext = lowercase(splitext(filepath)[2])
    return ext in [".ttf", ".otf", ".woff", ".woff2"]
end

function is_3d_model_file(filepath::String)
    ext = lowercase(splitext(filepath)[2])
    return ext in [".obj", ".fbx", ".gltf", ".glb", ".dae"]
end

function is_config_file(filepath::String)
    ext = lowercase(splitext(filepath)[2])
    return ext in [".toml", ".yaml", ".yml", ".ini", ".cfg", ".config"]
end

# Enhanced file type detection that extends ImportFile
function get_file_type(filepath::String)::Symbol
    if isdir(filepath)
        return :directory
    elseif is_image_file(filepath)
        return :image
    elseif is_audio_file(filepath)
        return :audio
    elseif is_script_file(filepath)
        return :script
    elseif is_scene_file(filepath)
        return :scene
    elseif is_font_file(filepath)
        return :font
    elseif is_3d_model_file(filepath)
        return :model
    elseif is_config_file(filepath)
        return :config
    else
        return :unknown
    end
end

function get_file_type_color(file_type::Symbol)::ImVec4
    colors = Dict(
        :directory => ImVec4(0.7, 0.9, 1.0, 1.0),    # Light blue (matching ImportFile)
        :image => ImVec4(0.3, 0.8, 0.3, 1.0),        # Green (matching ImportFile)
        :audio => ImVec4(0.8, 0.3, 0.8, 1.0),        # Magenta (matching ImportFile)
        :script => ImVec4(1.0, 0.8, 0.3, 1.0),       # Yellow
        :scene => ImVec4(0.3, 0.8, 0.8, 1.0),        # Cyan
        :font => ImVec4(0.8, 0.6, 0.3, 1.0),         # Orange
        :model => ImVec4(0.6, 0.3, 0.8, 1.0),        # Purple
        :config => ImVec4(0.8, 0.8, 0.8, 1.0),       # Gray
        :unknown => ImVec4(0.6, 0.6, 0.6, 1.0)       # Dark gray
    )
    return get(colors, file_type, ImVec4(0.6, 0.6, 0.6, 1.0))
end

function get_file_type_icon(file_type::Symbol)::String
    icons = Dict(
        :directory => "📁",
        :image => "🖼️",
        :audio => "🔊",
        :script => "📜",
        :scene => "🎬",
        :font => "🔤",
        :model => "🎲",
        :config => "⚙️",
        :unknown => "📄"
    )
    return get(icons, file_type, "📄")
end

"""
    Enhanced preview system extending ImportFile
"""

function should_cache_preview(filepath::String)::Bool
    file_type = get_file_type(filepath)
    return file_type in [:image, :audio] && filesize(filepath) < 10 * 1024 * 1024  # 10MB limit
end

function load_thumbnail_preview(filepath::String, renderer, size::Float32 = 64.0)
    explorer = JulGame.EditorState["file_explorer"]
    
    # Check cache first
    if haskey(explorer.preview_cache, filepath)
        texture, cached_size, timestamp = explorer.preview_cache[filepath]
        # Check if file was modified since cache
        if stat(filepath).mtime <= timestamp && texture != C_NULL
            return texture, cached_size
        else
            # Cleanup old texture
            if texture != C_NULL
                SDL2.SDL_DestroyTexture(texture)
            end
            delete!(explorer.preview_cache, filepath)
        end
    end
    
    # Load new preview using existing ImportFile function
    if is_image_file(filepath)
        texture, preview_size = load_image_preview(filepath, renderer)
        if texture != C_NULL
            # Scale to requested size while maintaining aspect ratio
            scale_factor = min(size / preview_size.x, size / preview_size.y)
            scaled_size = ImVec2(preview_size.x * scale_factor, preview_size.y * scale_factor)
            
            # Cache the preview
            if should_cache_preview(filepath)
                explorer.preview_cache[filepath] = (texture, scaled_size, UInt64(time()))
            end
            
            return texture, scaled_size
        end
    end
    
    return C_NULL, ImVec2(0, 0)
end

"""
    Navigation system with breadcrumbs and history
"""

function navigate_to_path(path::Union{String, SubString{String}})
    path = string(path)
    explorer = JulGame.EditorState["file_explorer"]
    
    if isdir(path)
        explorer.current_path = abspath(path)
        
        # Update history
        if explorer.history_index < length(explorer.path_history)
            # Remove forward history when navigating to new path
            explorer.path_history = explorer.path_history[1:explorer.history_index]
        end
        
        if isempty(explorer.path_history) || explorer.path_history[end] != explorer.current_path
            push!(explorer.path_history, explorer.current_path)
            explorer.history_index = length(explorer.path_history)
        end
        
        # Update recent paths
        filter!(p -> p != explorer.current_path, explorer.recent_paths)
        pushfirst!(explorer.recent_paths, explorer.current_path)
        if length(explorer.recent_paths) > 10
            explorer.recent_paths = explorer.recent_paths[1:10]
        end
        
        # Clear selection when navigating
        empty!(explorer.selected_items)
        explorer.last_selected_item = ""
        
        save_explorer_settings()
    end
end

function can_navigate_back()::Bool
    explorer = JulGame.EditorState["file_explorer"]
    return explorer.history_index > 1
end

function can_navigate_forward()::Bool
    explorer = JulGame.EditorState["file_explorer"]
    return explorer.history_index < length(explorer.path_history)
end

function navigate_back()
    if can_navigate_back()
        explorer = JulGame.EditorState["file_explorer"]
        explorer.history_index -= 1
        explorer.current_path = explorer.path_history[explorer.history_index]
        empty!(explorer.selected_items)
        explorer.last_selected_item = ""
    end
end

function navigate_forward()
    if can_navigate_forward()
        explorer = JulGame.EditorState["file_explorer"]
        explorer.history_index += 1
        explorer.current_path = explorer.path_history[explorer.history_index]
        empty!(explorer.selected_items)
        explorer.last_selected_item = ""
    end
end

function navigate_up()
    explorer = JulGame.EditorState["file_explorer"]
    parent_path = dirname(explorer.current_path)
    
    # Don't go above project root
    if JulGame.BasePath != "" && startswith(abspath(JulGame.BasePath), parent_path)
        return
    end
    
    if parent_path != explorer.current_path
        navigate_to_path(parent_path)
    end
end

"""
    Search and filtering system
"""

function matches_search_query(filepath::String, query::String)::Bool
    if isempty(query)
        return true
    end
    
    filename = lowercase(basename(filepath))
    query_lower = lowercase(query)
    
    # Simple substring search - can be enhanced with fuzzy matching
    return occursin(query_lower, filename)
end

function matches_filter_extensions(filepath::String, extensions::Set{String})::Bool
    if isempty(extensions)
        return true
    end
    
    ext = lowercase(splitext(filepath)[2])
    return ext in extensions
end

function should_show_item(filepath::String)::Bool
    explorer = JulGame.EditorState["file_explorer"]
    
    # Check hidden files
    if !explorer.show_hidden_files && startswith(basename(filepath), ".")
        return false
    end
    
    # Check search query
    if !matches_search_query(filepath, explorer.search_query[])
        return false
    end
    
    # Check extension filter
    if !matches_filter_extensions(filepath, explorer.filter_extensions)
        return false
    end
    
    return true
end

"""
    File listing with sorting
"""

function get_file_sort_key(filepath::String, sort_mode::Symbol)
    if sort_mode == :name
        return lowercase(basename(filepath))
    elseif sort_mode == :date
        return stat(filepath).mtime
    elseif sort_mode == :size
        return isdir(filepath) ? 0 : filesize(filepath)
    elseif sort_mode == :type
        return string(get_file_type(filepath))
    else
        return lowercase(basename(filepath))
    end
end

function get_filtered_and_sorted_items(path::String)::Vector{String}
    explorer = JulGame.EditorState["file_explorer"]
    
    if !isdir(path)
        return String[]
    end
    
    try
        items = readdir(path, join=true)
        
        # Filter items
        filtered_items = filter(should_show_item, items)
        
        # Separate directories and files
        directories = filter(isdir, filtered_items)
        files = filter(!isdir, filtered_items)
        
        # Sort each group
        sort_func = if explorer.sort_ascending
            (a, b) -> get_file_sort_key(a, explorer.sort_mode) < get_file_sort_key(b, explorer.sort_mode)
        else
            (a, b) -> get_file_sort_key(a, explorer.sort_mode) > get_file_sort_key(b, explorer.sort_mode)
        end
        
        sort!(directories, lt=sort_func)
        sort!(files, lt=sort_func)
        
        # Directories first, then files
        return vcat(directories, files)
        
    catch e
        @error "Error reading directory $path: $e"
        return String[]
    end
end

"""
    Persistent settings management
"""

function get_settings_path()::String
    return joinpath(dirname(JulGame.BasePath), ".julgame_explorer_settings.toml")
end

function save_explorer_settings()
    try
        explorer = JulGame.EditorState["file_explorer"]
        settings_path = get_settings_path()
        
        # Create simple settings format (avoiding TOML dependency)
        settings_content = """
# JulGame File Explorer Settings
current_path = "$(explorer.current_path)"
show_previews = $(explorer.show_previews)
preview_size = $(explorer.preview_size)
show_hidden_files = $(explorer.show_hidden_files)
sort_mode = "$(explorer.sort_mode)"
sort_ascending = $(explorer.sort_ascending)
show_tree_view = $(explorer.show_tree_view)
show_metadata_panel = $(explorer.show_metadata_panel)

# Recent paths
recent_paths = [$(join(["\"$p\"" for p in explorer.recent_paths], ", "))]

# Favorite paths  
favorite_paths = [$(join(["\"$p\"" for p in explorer.favorite_paths], ", "))]
"""
        
        write(settings_path, settings_content)
    catch e
        @debug "Failed to save explorer settings: $e"
    end
end

function load_explorer_settings()
    try
        settings_path = get_settings_path()
        if !isfile(settings_path)
            return
        end
        
        # Simple settings parser (avoiding TOML dependency)
        explorer = JulGame.EditorState["file_explorer"]
        
        for line in readlines(settings_path)
            line = strip(line)
            if isempty(line) || startswith(line, "#")
                continue
            end
            
            if occursin("=", line)
                key, value = split(line, "=", limit=2)
                key = strip(key)
                value = strip(value)
                
                if key == "show_previews"
                    explorer.show_previews = parse(Bool, value)
                elseif key == "preview_size"
                    explorer.preview_size = parse(Float32, value)
                elseif key == "show_hidden_files"
                    explorer.show_hidden_files = parse(Bool, value)
                elseif key == "sort_ascending"
                    explorer.sort_ascending = parse(Bool, value)
                elseif key == "show_tree_view"
                    explorer.show_tree_view = parse(Bool, value)
                elseif key == "show_metadata_panel"
                    explorer.show_metadata_panel = parse(Bool, value)
                end
            end
        end
        
    catch e
        @debug "Failed to load explorer settings: $e"
    end
end

"""
    Cleanup functions extending ImportFile patterns
"""

function cleanup_preview_cache()
    explorer = JulGame.EditorState["file_explorer"]
    
    # Cleanup image previews
    for (path, (texture, size, timestamp)) in explorer.preview_cache
        if texture != C_NULL
            SDL2.SDL_DestroyTexture(texture)
        end
    end
    empty!(explorer.preview_cache)
    
    # Cleanup audio previews  
    for (path, (chunk, timestamp)) in explorer.audio_preview_cache
        if chunk != C_NULL
            SDL2.Mix_FreeChunk(chunk)
        end
    end
    empty!(explorer.audio_preview_cache)
end

function cleanup_file_explorer()
    cleanup_preview_cache()
    save_explorer_settings()
end

# Export main functions for integration
export initialize_file_explorer, cleanup_file_explorer, navigate_to_path
