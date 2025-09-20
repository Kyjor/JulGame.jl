"""
    FavoritesAndHistory

Favorites and history management system for the file explorer.
Provides persistent bookmarking, recent files tracking, and quick access
to frequently used assets and locations.
"""

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui: ImVec2, ImVec4, IM_COL32
using Dates

include("FileExplorer.jl")

"""
    Favorites management
"""

function add_to_favorites(path::String)
    explorer = JulGame.EditorState["file_explorer"]
    
    if path ∉ explorer.favorite_paths
        push!(explorer.favorite_paths, path)
        save_explorer_settings()
        @info "Added to favorites: $(basename(path))"
    end
end

function remove_from_favorites(path::String)
    explorer = JulGame.EditorState["file_explorer"]
    
    filter!(p -> p != path, explorer.favorite_paths)
    save_explorer_settings()
    @info "Removed from favorites: $(basename(path))"
end

function is_favorite(path::String)::Bool
    explorer = JulGame.EditorState["file_explorer"]
    return path in explorer.favorite_paths
end

function toggle_favorite(path::String)
    if is_favorite(path)
        remove_from_favorites(path)
    else
        add_to_favorites(path)
    end
end

"""
    Recent files management
"""

function add_to_recent_files(path::String)
    explorer = JulGame.EditorState["file_explorer"]
    
    # Remove if already in list
    filter!(p -> p != path, explorer.recent_paths)
    
    # Add to front
    pushfirst!(explorer.recent_paths, path)
    
    # Limit to 20 recent items
    if length(explorer.recent_paths) > 20
        explorer.recent_paths = explorer.recent_paths[1:20]
    end
    
    save_explorer_settings()
end

function clear_recent_files()
    explorer = JulGame.EditorState["file_explorer"]
    empty!(explorer.recent_paths)
    save_explorer_settings()
end

function get_recent_files_by_type(file_type::Symbol)::Vector{String}
    explorer = JulGame.EditorState["file_explorer"]
    return filter(path -> isfile(path) && get_file_type(path) == file_type, explorer.recent_paths)
end

"""
    Quick access UI components
"""

function show_favorites_panel()
    explorer = JulGame.EditorState["file_explorer"]
    
    CImGui.Text("Favorites")
    CImGui.Separator()
    
    if isempty(explorer.favorite_paths)
        CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "No favorites yet")
        CImGui.Text("Right-click files/folders to add")
        return
    end
    
    # Clean up invalid favorites
    valid_favorites = filter(isfile_or_isdir, explorer.favorite_paths)
    if length(valid_favorites) != length(explorer.favorite_paths)
        explorer.favorite_paths = valid_favorites
        save_explorer_settings()
    end
    
    for (i, fav_path) in enumerate(explorer.favorite_paths)
        file_type = get_file_type(fav_path)
        icon = get_file_type_icon(file_type)
        color = get_file_type_color(file_type)
        display_name = basename(fav_path)
        
        # Favorite item with icon
        CImGui.TextColored(color, icon)
        CImGui.SameLine()
        
        if CImGui.Selectable("$(display_name)##fav_$i")
            if isdir(fav_path)
                navigate_to_path(fav_path)
            else
                # Navigate to parent directory and select file
                navigate_to_path(dirname(fav_path))
                explorer = JulGame.EditorState["file_explorer"]
                empty!(explorer.selected_items)
                push!(explorer.selected_items, fav_path)
            end
        end
        
        # Context menu for favorites
        if CImGui.BeginPopupContextItem("FavContextMenu_$i")
            CImGui.Text(display_name)
            CImGui.Separator()
            
            if CImGui.MenuItem("Remove from Favorites")
                remove_from_favorites(fav_path)
            end
            
            if CImGui.MenuItem("Show in Explorer")
                if isdir(fav_path)
                    navigate_to_path(fav_path)
                else
                    navigate_to_path(dirname(fav_path))
                end
            end
            
            CImGui.EndPopup()
        end
        
        # Tooltip with full path
        if CImGui.IsItemHovered()
            CImGui.BeginTooltip()
            CImGui.Text(fav_path)
            CImGui.EndTooltip()
        end
    end
end

function show_recent_files_panel()
    explorer = JulGame.EditorState["file_explorer"]
    
    CImGui.Text("Recent Files")
    CImGui.SameLine()
    
    if CImGui.SmallButton("Clear")
        clear_recent_files()
    end
    
    CImGui.Separator()
    
    if isempty(explorer.recent_paths)
        CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "No recent files")
        return
    end
    
    # Clean up invalid recent files
    valid_recent = filter(isfile, explorer.recent_paths)
    if length(valid_recent) != length(explorer.recent_paths)
        explorer.recent_paths = valid_recent
        save_explorer_settings()
    end
    
    # Group recent files by type
    recent_by_type = Dict{Symbol, Vector{String}}()
    for path in explorer.recent_paths[1:min(10, length(explorer.recent_paths))]  # Show max 10
        file_type = get_file_type(path)
        if !haskey(recent_by_type, file_type)
            recent_by_type[file_type] = String[]
        end
        push!(recent_by_type[file_type], path)
    end
    
    # Show grouped recent files
    for (file_type, paths) in recent_by_type
        type_color = get_file_type_color(file_type)
        type_icon = get_file_type_icon(file_type)
        
        if CImGui.TreeNode("$type_icon $(string(file_type)) ($(length(paths)))")
            for (i, path) in enumerate(paths)
                display_name = basename(path)
                
                if CImGui.Selectable("$(display_name)##recent_$(file_type)_$i")
                    # Navigate to parent directory and select file
                    navigate_to_path(dirname(path))
                    explorer = JulGame.EditorState["file_explorer"]
                    empty!(explorer.selected_items)
                    push!(explorer.selected_items, path)
                    add_to_recent_files(path)  # Move to front
                end
                
                # Tooltip with full path and last accessed time
                if CImGui.IsItemHovered()
                    CImGui.BeginTooltip()
                    CImGui.Text(path)
                    
                    try
                        stat_info = stat(path)
                        modified_time = unix2datetime(stat_info.mtime)
                        CImGui.Text("Modified: $(Dates.format(modified_time, "yyyy-mm-dd HH:MM"))")
                    catch
                        # File might have been deleted
                    end
                    
                    CImGui.EndTooltip()
                end
            end
            CImGui.TreePop()
        end
    end
end

"""
    Quick access toolbar
"""

function show_quick_access_toolbar()
    explorer = JulGame.EditorState["file_explorer"]
    
    # Favorites dropdown
    if CImGui.Button("⭐ Favorites")
        CImGui.OpenPopup("FavoritesPopup")
    end
    
    if CImGui.BeginPopup("FavoritesPopup")
        show_favorites_popup_content()
        CImGui.EndPopup()
    end
    
    CImGui.SameLine()
    
    # Recent files dropdown
    if CImGui.Button("🕒 Recent")
        CImGui.OpenPopup("RecentPopup")
    end
    
    if CImGui.BeginPopup("RecentPopup")
        show_recent_files_popup_content()
        CImGui.EndPopup()
    end
    
    CImGui.SameLine()
    
    # Quick navigation buttons
    show_quick_navigation_buttons()
end

function show_favorites_popup_content()
    explorer = JulGame.EditorState["file_explorer"]
    
    if isempty(explorer.favorite_paths)
        CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "No favorites")
        return
    end
    
    for (i, fav_path) in enumerate(explorer.favorite_paths[1:min(10, length(explorer.favorite_paths))])
        if !isfile_or_isdir(fav_path)
            continue
        end
        
        file_type = get_file_type(fav_path)
        icon = get_file_type_icon(file_type)
        display_name = basename(fav_path)
        
        if CImGui.MenuItem("$icon $display_name")
            if isdir(fav_path)
                navigate_to_path(fav_path)
            else
                navigate_to_path(dirname(fav_path))
                empty!(explorer.selected_items)
                push!(explorer.selected_items, fav_path)
            end
            CImGui.CloseCurrentPopup()
        end
    end
    
    if length(explorer.favorite_paths) > 10
        CImGui.Separator()
        CImGui.Text("... and $(length(explorer.favorite_paths) - 10) more")
    end
end

function show_recent_files_popup_content()
    explorer = JulGame.EditorState["file_explorer"]
    
    if isempty(explorer.recent_paths)
        CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "No recent files")
        return
    end
    
    valid_recent = filter(isfile, explorer.recent_paths)
    
    for (i, path) in enumerate(valid_recent[1:min(10, length(valid_recent))])
        file_type = get_file_type(path)
        icon = get_file_type_icon(file_type)
        display_name = basename(path)
        
        if CImGui.MenuItem("$icon $display_name")
            navigate_to_path(dirname(path))
            explorer = JulGame.EditorState["file_explorer"]
            empty!(explorer.selected_items)
            push!(explorer.selected_items, path)
            add_to_recent_files(path)  # Move to front
            CImGui.CloseCurrentPopup()
        end
    end
    
    if length(valid_recent) > 10
        CImGui.Separator()
        CImGui.Text("... and $(length(valid_recent) - 10) more")
    end
end

function show_quick_navigation_buttons()
    # Common project directories
    project_dirs = [
        ("📁 Assets", joinpath(JulGame.BasePath, "assets")),
        ("🖼️ Images", joinpath(JulGame.BasePath, "assets", "images")),
        ("🔊 Audio", joinpath(JulGame.BasePath, "assets", "audio")),
        ("📜 Scripts", joinpath(JulGame.BasePath, "scripts")),
        ("🎬 Scenes", joinpath(JulGame.BasePath, "scenes"))
    ]
    
    for (label, path) in project_dirs
        if isdir(path)
            CImGui.SameLine()
            if CImGui.SmallButton(label)
                navigate_to_path(path)
            end
        end
    end
end

"""
    Context menu integration for favorites
"""

function add_favorites_context_menu_items(filepath::String)
    if is_favorite(filepath)
        if CImGui.MenuItem("⭐ Remove from Favorites")
            remove_from_favorites(filepath)
        end
    else
        if CImGui.MenuItem("⭐ Add to Favorites")
            add_to_favorites(filepath)
        end
    end
end

"""
    Smart suggestions based on usage patterns
"""

function get_suggested_assets(context::Symbol = :general)::Vector{String}
    explorer = JulGame.EditorState["file_explorer"]
    suggestions = String[]
    
    # Recent files of relevant types
    if context == :images
        suggestions = get_recent_files_by_type(:image)
    elseif context == :audio
        suggestions = get_recent_files_by_type(:audio)
    elseif context == :scripts
        suggestions = get_recent_files_by_type(:script)
    else
        # General suggestions - mix of recent and favorites
        suggestions = vcat(
            explorer.recent_paths[1:min(5, length(explorer.recent_paths))],
            filter(isfile, explorer.favorite_paths[1:min(5, length(explorer.favorite_paths))])
        )
    end
    
    # Remove duplicates and invalid files
    suggestions = unique(filter(isfile, suggestions))
    
    return suggestions[1:min(10, length(suggestions))]
end

function show_asset_suggestions(context::Symbol = :general)
    suggestions = get_suggested_assets(context)
    
    if isempty(suggestions)
        return
    end
    
    CImGui.Text("Suggested Assets:")
    CImGui.Separator()
    
    for (i, path) in enumerate(suggestions)
        file_type = get_file_type(path)
        icon = get_file_type_icon(file_type)
        display_name = basename(path)
        
        if CImGui.Selectable("$icon $display_name##suggestion_$i")
            navigate_to_path(dirname(path))
            explorer = JulGame.EditorState["file_explorer"]
            empty!(explorer.selected_items)
            push!(explorer.selected_items, path)
            add_to_recent_files(path)
        end
    end
end

"""
    Workspace management
"""

mutable struct Workspace
    name::String
    favorite_paths::Vector{String}
    recent_paths::Vector{String}
    current_path::String
    custom_settings::Dict{String, Any}
    
    function Workspace(name::String)
        new(name, String[], String[], "", Dict{String, Any}())
    end
end

function save_workspace(name::String)
    explorer = JulGame.EditorState["file_explorer"]
    
    workspace = Workspace(name)
    workspace.favorite_paths = copy(explorer.favorite_paths)
    workspace.recent_paths = copy(explorer.recent_paths)
    workspace.current_path = explorer.current_path
    workspace.custom_settings = Dict(
        "show_previews" => explorer.show_previews,
        "preview_size" => explorer.preview_size,
        "show_tree_view" => explorer.show_tree_view,
        "sort_mode" => explorer.sort_mode,
        "sort_ascending" => explorer.sort_ascending
    )
    
    # Save workspace to file
    workspace_path = joinpath(dirname(JulGame.BasePath), ".julgame_workspaces", "$(name).workspace")
    mkpath(dirname(workspace_path))
    
    try
        # Simple serialization (avoiding complex dependencies)
        workspace_data = """
# JulGame Workspace: $name
name = "$name"
current_path = "$(workspace.current_path)"

# Settings
show_previews = $(workspace.custom_settings["show_previews"])
preview_size = $(workspace.custom_settings["preview_size"])
show_tree_view = $(workspace.custom_settings["show_tree_view"])
sort_mode = "$(workspace.custom_settings["sort_mode"])"
sort_ascending = $(workspace.custom_settings["sort_ascending"])

# Favorites
favorites = [$(join(["\"$p\"" for p in workspace.favorite_paths], ", "))]

# Recent files  
recent = [$(join(["\"$p\"" for p in workspace.recent_paths], ", "))]
"""
        
        write(workspace_path, workspace_data)
        @info "Saved workspace: $name"
        
    catch e
        @error "Failed to save workspace $name: $e"
    end
end

function load_workspace(name::String)::Bool
    workspace_path = joinpath(dirname(JulGame.BasePath), ".julgame_workspaces", "$(name).workspace")
    
    if !isfile(workspace_path)
        @warn "Workspace not found: $name"
        return false
    end
    
    try
        explorer = JulGame.EditorState["file_explorer"]
        
        # Load and apply workspace settings
        # This is a simplified implementation - would need proper parsing
        content = read(workspace_path, String)
        
        # Extract settings (basic pattern matching)
        if occursin(r"current_path = \"([^\"]+)\"", content)
            match_result = match(r"current_path = \"([^\"]+)\"", content)
            if match_result !== nothing && isdir(match_result.captures[1])
                navigate_to_path(match_result.captures[1])
            end
        end
        
        @info "Loaded workspace: $name"
        return true
        
    catch e
        @error "Failed to load workspace $name: $e"
        return false
    end
end

"""
    Utility functions
"""

function isfile_or_isdir(path::String)::Bool
    return isfile(path) || isdir(path)
end

function cleanup_invalid_paths()
    explorer = JulGame.EditorState["file_explorer"]
    
    # Clean up favorites
    explorer.favorite_paths = filter(isfile_or_isdir, explorer.favorite_paths)
    
    # Clean up recent files
    explorer.recent_paths = filter(isfile, explorer.recent_paths)
    
    save_explorer_settings()
end

# Export functions for integration
export add_to_favorites, remove_from_favorites, is_favorite, toggle_favorite
export add_to_recent_files, show_favorites_panel, show_recent_files_panel
export show_quick_access_toolbar, add_favorites_context_menu_items
export get_suggested_assets, show_asset_suggestions, save_workspace, load_workspace
