"""
    FileExplorerUI

User interface components for the file explorer system.
Implements ImGui-based interface following the established patterns from ImportFile.jl
and maintaining visual consistency with the existing editor.
"""

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui: ImVec2, ImVec4, IM_COL32
using JulGame: SDL2

include("FileExplorer.jl")
include("DragDropIntegration.jl")

"""
    show_file_explorer_window(show_file_explorer::Ref{Bool}, renderer)

Main file explorer window function that integrates with the existing editor layout.
Follows the same patterns as other editor windows.
"""
function show_file_explorer_window(show_file_explorer::Ref{Bool}, renderer)
    if !show_file_explorer[]
        return
    end
    
    # Initialize if needed
    initialize_file_explorer()
    explorer = JulGame.EditorState["file_explorer"]
    
    # Don't show if no project is loaded (matching existing FileExplorerWindow pattern)
    if JulGame.BasePath == ""
        CImGui.Begin("File Explorer", show_file_explorer)
        CImGui.Text("No project loaded. Please select a project.")
        CImGui.End()
        return
    end
    
    CImGui.SetNextWindowSize((800, 600), CImGui.ImGuiCond_FirstUseEver)
    if CImGui.Begin("File Explorer", show_file_explorer)
        
        # Navigation toolbar
        show_navigation_toolbar(renderer)
        CImGui.Separator()
        
        # Search and filter bar
        show_search_and_filter_bar()
        CImGui.Separator()
        
        # Main content area with splitters
        show_main_content_area(renderer)
        
    end
    CImGui.End()
end

"""
    Navigation toolbar with breadcrumbs, back/forward, and common actions
"""
function show_navigation_toolbar(renderer)
    explorer = JulGame.EditorState["file_explorer"]
    
    # Back/Forward buttons (matching ImportFile button styling)
    if !can_navigate_back()
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_Alpha, unsafe_load(CImGui.GetStyle().Alpha) * 0.5)
        CImGui.Button("Back", ImVec2(30, 0))
        CImGui.PopStyleVar()
    else
        if CImGui.Button("Back", ImVec2(30, 0))
            navigate_back()
        end
    end
    
    CImGui.SameLine()
    
    if !can_navigate_forward()
        CImGui.PushStyleVar(CImGui.ImGuiStyleVar_Alpha, unsafe_load(CImGui.GetStyle().Alpha) * 0.5)
        CImGui.Button("Forward", ImVec2(30, 0))
        CImGui.PopStyleVar()
    else
        if CImGui.Button("Forward", ImVec2(30, 0))
            navigate_forward()
        end
    end
    
    CImGui.SameLine()
    
    # Up button
    if CImGui.Button("Up", ImVec2(30, 0))
        navigate_up()
    end
    
    CImGui.SameLine()
    
    # Home button (go to project root)
    if CImGui.Button("Home", ImVec2(30, 0))
        navigate_to_path(JulGame.BasePath)
    end
    
    CImGui.SameLine()
    
    # Breadcrumb path display
    show_breadcrumb_path()
    
    # Right-aligned buttons
    CImGui.SameLine()
    available_width = CImGui.GetContentRegionAvail().x
    button_width = 30.0
    spacing = unsafe_load(CImGui.GetStyle().ItemSpacing.x)
    total_button_width = button_width * 4 + spacing * 3
    
    if available_width > total_button_width
        CImGui.SetCursorPosX(CImGui.GetCursorPosX() + available_width - total_button_width)
    end
    
    # View mode buttons
    if explorer.show_tree_view
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.7, 0.2, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.8, 0.3, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.9, 0.4, 1.0))
    end
    
    if CImGui.Button("Show Tree", ImVec2(button_width, 0))
        explorer.show_tree_view = !explorer.show_tree_view
    end
    
    if explorer.show_tree_view
        CImGui.PopStyleColor(3)
    end
    
    CImGui.SameLine()
    
    # Preview toggle
    if explorer.show_previews
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.7, 0.2, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.8, 0.3, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.9, 0.4, 1.0))
    end
    
    if CImGui.Button("Show Previews", ImVec2(button_width, 0))
        explorer.show_previews = !explorer.show_previews
    end
    
    if explorer.show_previews
        CImGui.PopStyleColor(3)
    end
    
    CImGui.SameLine()
    
    # Metadata panel toggle
    if explorer.show_metadata_panel
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.7, 0.2, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.8, 0.3, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.9, 0.4, 1.0))
    end
    
    if CImGui.Button("Show Metadata", ImVec2(button_width, 0))
        explorer.show_metadata_panel = !explorer.show_metadata_panel
    end
    
    if explorer.show_metadata_panel
        CImGui.PopStyleColor(3)
    end
    
    CImGui.SameLine()
    
    # Settings/Options button
    if CImGui.Button("Options", ImVec2(button_width, 0))
        CImGui.OpenPopup("Explorer Options")
    end
    
    show_options_popup()
end

"""
    Breadcrumb path display with clickable segments
"""
function show_breadcrumb_path()
    explorer = JulGame.EditorState["file_explorer"]
    
    if explorer.current_path == ""
        return
    end
    
    # Split path into segments
    base_path = abspath(JulGame.BasePath)
    current_path = abspath(explorer.current_path)
    
    # Get relative path from project root
    if startswith(current_path, base_path)
        relative_path = relpath(current_path, base_path)
        segments = relative_path == "." ? String[] : split(relative_path, ['/', '\\'])
    else
        segments = split(current_path, ['/', '\\'])
    end
    
    # Show project root
    CImGui.TextColored((0.7, 0.9, 1.0, 1.0), basename(JulGame.BasePath))
    
    # Show path segments as clickable buttons
    build_path = base_path
    for (i, segment) in enumerate(segments)
        if !isempty(segment)
            CImGui.SameLine()
            CImGui.Text("/")
            CImGui.SameLine()
            
            build_path = joinpath(build_path, segment)
            
            if CImGui.SmallButton(segment)
                navigate_to_path(build_path)
                break
            end
        end
    end
end

"""
    Search and filter bar
"""
function show_search_and_filter_bar()
    explorer = JulGame.EditorState["file_explorer"]
    
    # Search input (following ImportFile InputText pattern)
    CImGui.Text("Search:")
    CImGui.SameLine()
    CImGui.SetNextItemWidth(200)
    
    buf = "$(explorer.search_query[])" * "\0"^256
    if CImGui.InputText("##search", buf, length(buf))
        # Extract the string up to the first null character (ImportFile pattern)
        current_text = ""
        for character_index in eachindex(buf)
            if Int32(buf[character_index]) == 0 
                if character_index != 1
                    current_text = String(SubString(buf, 1, character_index-1))
                end
                break
            end
        end
        explorer.search_query[] = current_text
    end
    
    CImGui.SameLine()
    
    # Clear search button
    if CImGui.SmallButton("✖")
        explorer.search_query[] = ""
    end
    
    CImGui.SameLine()
    CImGui.Separator()
    CImGui.SameLine()
    
    # Sort options
    CImGui.Text("Sort:")
    CImGui.SameLine()
    CImGui.SetNextItemWidth(100)
    
    sort_options = ["Name", "Date", "Size", "Type"]
    sort_modes = [:name, :date, :size, :type]
    current_sort_index = findfirst(x -> x == explorer.sort_mode, sort_modes)
    current_sort_index = current_sort_index === nothing ? 1 : current_sort_index
    
    selected_index = Ref(Int32(current_sort_index - 1))
    if CImGui.Combo("##sort", selected_index, sort_options, length(sort_options))
        explorer.sort_mode = sort_modes[selected_index[] + 1]
    end
    
    CImGui.SameLine()
    
    # Sort direction
    sort_icon = explorer.sort_ascending ? "Ascending" : "Descending"
    if CImGui.SmallButton(sort_icon)
        explorer.sort_ascending = !explorer.sort_ascending
    end
    
    CImGui.SameLine()
    CImGui.Separator()
    CImGui.SameLine()
    
    # File type filters
    CImGui.Text("Show:")
    CImGui.SameLine()
    
    # Quick filter buttons
    file_type_filters = [
        ("All", Set{String}()),
        ("Images", Set([".png", ".jpg", ".jpeg", ".bmp", ".tga", ".gif"])),
        ("Audio", Set([".wav", ".mp3", ".ogg", ".flac", ".aiff"])),
        ("Scripts", Set([".jl", ".js", ".py", ".lua", ".cs"]))
    ]
    
    for (i, (label, extensions)) in enumerate(file_type_filters)
        if i > 1
            CImGui.SameLine()
        end
        
        is_active = explorer.filter_extensions == extensions
        if is_active
            CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.7, 0.2, 1.0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.8, 0.3, 1.0))
            CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.9, 0.4, 1.0))
        end
        
        if CImGui.SmallButton(label)
            explorer.filter_extensions = extensions
        end
        
        if is_active
            CImGui.PopStyleColor(3)
        end
    end
end

"""
    Main content area with optional tree view and metadata panel
"""
function show_main_content_area(renderer)
    explorer = JulGame.EditorState["file_explorer"]
    
    # Calculate layout
    available_width = CImGui.GetContentRegionAvail().x
    tree_width = explorer.show_tree_view ? 200.0 : 0.0
    metadata_width = explorer.show_metadata_panel ? 250.0 : 0.0
    main_width = available_width - tree_width - metadata_width
    
    if tree_width > 0
        main_width -= unsafe_load(CImGui.GetStyle().ItemSpacing.x)
    end
    if metadata_width > 0
        main_width -= unsafe_load(CImGui.GetStyle().ItemSpacing.x)
    end
    
    # Tree view panel
    if explorer.show_tree_view
        CImGui.BeginChild("TreeView", ImVec2(tree_width, 0), true)
        show_tree_view_panel()
        CImGui.EndChild()
        CImGui.SameLine()
    end
    
    # Main file list
    CImGui.BeginChild("FileList", ImVec2(main_width, 0), true)
    show_file_list_panel(renderer)
    CImGui.EndChild()
    
    # Metadata panel
    if explorer.show_metadata_panel
        CImGui.SameLine()
        CImGui.BeginChild("MetadataPanel", ImVec2(metadata_width, 0), true)
        show_metadata_panel()
        CImGui.EndChild()
    end
end

"""
    Tree view panel for hierarchical navigation
"""
function show_tree_view_panel()
    explorer = JulGame.EditorState["file_explorer"]
    
    # Show project root
    base_path = abspath(JulGame.BasePath)
    show_tree_node(base_path, basename(JulGame.BasePath), true)
end

function show_tree_node(path::String, display_name::String, is_root::Bool = false)
    explorer = JulGame.EditorState["file_explorer"]
    
    if !isdir(path)
        return
    end
    
    # Check if node should be expanded
    is_expanded = get(explorer.tree_node_states, path, is_root)
    
    # Tree node flags
    flags = CImGui.ImGuiTreeNodeFlags_OpenOnArrow | CImGui.ImGuiTreeNodeFlags_OpenOnDoubleClick
    
    if is_expanded
        flags |= CImGui.ImGuiTreeNodeFlags_DefaultOpen
    end
    
    # Highlight current path
    if path == explorer.current_path
        flags |= CImGui.ImGuiTreeNodeFlags_Selected
    end
    
    # Show tree node
    node_open = CImGui.TreeNodeEx(display_name, flags)
    
    # Handle selection
    if CImGui.IsItemClicked()
        navigate_to_path(path)
    end
    
    # Update expansion state
    explorer.tree_node_states[path] = node_open
    
    if node_open
        # Show child directories
        try
            items = readdir(path, join=true)
            directories = filter(isdir, items)
            sort!(directories, by=basename)
            
            for dir_path in directories
                if should_show_item(dir_path)
                    show_tree_node(dir_path, basename(dir_path))
                end
            end
        catch e
            @debug "Error reading directory for tree view: $e"
        end
        
        CImGui.TreePop()
    end
end

"""
    Main file list panel with grid/list view and previews
"""
function show_file_list_panel(renderer)
    explorer = JulGame.EditorState["file_explorer"]
    
    # Debug info
    if explorer.current_path == ""
        CImGui.TextColored((1.0, 0.5, 0.0, 1.0), "Current path is empty!")
        CImGui.Text("BasePath: $(JulGame.BasePath)")
        return
    elseif !isdir(explorer.current_path)
        CImGui.TextColored((1.0, 0.5, 0.0, 1.0), "Current path is not a directory!")
        CImGui.Text("Path: $(explorer.current_path)")
        return
    end
    
    items = get_filtered_and_sorted_items(explorer.current_path)
    
    # Debug info
    CImGui.Text("Found $(length(items)) items")
    
    CImGui.Text("Drop here")
    if CImGui.BeginDragDropTarget()
        payload = CImGui.AcceptDragDropPayload("TEST")
        if payload != C_NULL
            n = unsafe_load(Ptr{Cint}(payload.Data))
            println("Dropped $n!")
        end
        CImGui.EndDragDropTarget()
    end

    if isempty(items)
        CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "No items to display")
        return
    end
    
    # Calculate item size based on preview settings
    item_height = explorer.show_previews ? explorer.preview_size + 40.0 : 20.0
    items_per_row = explorer.show_previews ? max(1, Int(floor(CImGui.GetContentRegionAvail().x / (explorer.preview_size + 20.0)))) : 1
    
    # Display items (simplified without virtual scrolling for now)
    for (i, item) in enumerate(items)
        show_file_item(item, renderer, i)
    end
    
    # Handle drag and drop for scene integration
    handle_file_list_drag_drop()
end

"""
    Individual file item display with preview and metadata
"""
function show_file_item(filepath::String, renderer, index::Int)
    explorer = JulGame.EditorState["file_explorer"]
    
    file_type = get_file_type(filepath)
    filename = basename(filepath)
    is_selected = filepath in explorer.selected_items
    
    # Item selection background
    if is_selected
        CImGui.PushStyleColor(CImGui.ImGuiCol_ChildBg, (0.3, 0.5, 0.8, 0.3))
    end
    
    # Calculate item size
    item_width = explorer.show_previews ? explorer.preview_size + 10.0 : CImGui.GetContentRegionAvail().x
    item_height = explorer.show_previews ? explorer.preview_size + 40.0 : 20.0
    if CImGui.BeginChild("Item_$index", ImVec2(item_width, item_height), true)
        
        # Drag source wrapping the file elements
        is_multi_select = length(explorer.selected_items) > 1 && filepath in explorer.selected_items
        
        # Preview thumbnail
        if explorer.show_previews && file_type in [:image, :audio]
            show_file_preview(filepath, renderer, explorer.preview_size)
        else
            # File type icon
            icon = get_file_type_icon(file_type)
            color = get_file_type_color(file_type)
            CImGui.TextColored(color, icon)
        end
        if CImGui.IsItemClicked()
            handle_item_selection(filepath)
        elseif CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0)
            handle_item_double_click(filepath)
        end
        

        if explorer.show_previews
            if CImGui.Selectable(filename)
            end
            begin_file_drag_source(filepath, is_multi_select)
        else
            CImGui.SameLine()
            color = get_file_type_color(file_type)
            CImGui.TextColored(color, filename)
        end
        
        # Handle item interaction (must be after all content is drawn)
        if CImGui.IsItemClicked()
            handle_item_selection(filepath)
        elseif CImGui.IsItemHovered() && CImGui.IsMouseDoubleClicked(0)
            handle_item_double_click(filepath)
        end
        
        # Context menu
        if CImGui.BeginPopupContextItem("FileContextMenu_$index")
            show_file_context_menu(filepath)
            CImGui.EndPopup()
        end
        
    end
    
    CImGui.EndChild()
    if is_selected
        CImGui.PopStyleColor()
    end
    
    # Arrange items in grid if showing previews
    if explorer.show_previews
        items_per_row = max(1, Int(floor(CImGui.GetContentRegionAvail().x / item_width)))
        if index % items_per_row != 0
            CImGui.SameLine()
        end
    end
end

"""
    File preview display extending ImportFile preview system
"""
function show_file_preview(filepath::String, renderer, size::Float32)
    file_type = get_file_type(filepath)
    
    if file_type == :image
        texture, preview_size = load_thumbnail_preview(filepath, renderer, size)
        if texture != C_NULL
            # Center the preview
            available_width = size
            image_width = preview_size.x
            offset_x = max(0, (available_width - image_width) * 0.5)
            
            if offset_x > 0
                CImGui.SetCursorPosX(CImGui.GetCursorPosX() + offset_x)
            end
            
            CImGui.Image(texture, preview_size)
        else
            # Fallback icon
            CImGui.TextColored(get_file_type_color(file_type), get_file_type_icon(file_type))
        end
    elseif file_type == :audio
        # Audio waveform visualization (simplified)
        CImGui.TextColored(get_file_type_color(file_type), get_file_type_icon(file_type))
        # TODO: Implement audio waveform preview
    else
        # Default icon
        CImGui.TextColored(get_file_type_color(file_type), get_file_type_icon(file_type))
    end
end

"""
    Item selection handling with multi-select support
"""
function handle_item_selection(filepath::String)
    explorer = JulGame.EditorState["file_explorer"]
    io = CImGui.GetIO()
    
    ctrl_held = unsafe_load(io.KeyCtrl)
    shift_held = unsafe_load(io.KeyShift)
    
    if ctrl_held
        # Toggle selection
        if filepath in explorer.selected_items
            delete!(explorer.selected_items, filepath)
        else
            push!(explorer.selected_items, filepath)
        end
    elseif shift_held && !isempty(explorer.last_selected_item)
        # Range selection
        items = get_filtered_and_sorted_items(explorer.current_path)
        last_index = findfirst(x -> x == explorer.last_selected_item, items)
        current_index = findfirst(x -> x == filepath, items)
        
        if last_index !== nothing && current_index !== nothing
            start_idx = min(last_index, current_index)
            end_idx = max(last_index, current_index)
            
            empty!(explorer.selected_items)
            for i in start_idx:end_idx
                push!(explorer.selected_items, items[i])
            end
        end
    else
        # Single selection
        empty!(explorer.selected_items)
        push!(explorer.selected_items, filepath)
    end
    
    explorer.last_selected_item = filepath
end

"""
    Double-click handling for navigation and file opening
"""
function handle_item_double_click(filepath::String)
    if isdir(filepath)
        navigate_to_path(filepath)
    else
        # TODO: Implement file opening based on type
        # For now, just select the item
        file_type = get_file_type(filepath)
        @info "Double-clicked $file_type file: $filepath"
    end
end

"""
    Context menu for file operations
"""
function show_file_context_menu(filepath::String)
    filename = basename(filepath)
    file_type = get_file_type(filepath)
    
    CImGui.Text("$filename")
    CImGui.Separator()
    
    # Import to project (using existing ImportFile workflow)
    if file_type in [:image, :audio] && CImGui.MenuItem("Import to Project")
        # Trigger ImportFile dialog for this specific file
        JulGame.EditorState["dropped_files"] = [filepath]
        JulGame.EditorState["import_queue_index"] = 1
    end
    
    # Add to scene directly (if supported)
    current_scene_main = get(JulGame.EditorState, "current_scene_main", nothing)
    if current_scene_main !== nothing && file_type in [:image, :audio] && CImGui.MenuItem("Add to Scene")
        # Direct scene integration
        try
            if file_type == :image
                entity = create_entity_with_sprite(relpath(filepath, JulGame.BasePath), replace(splitext(filename)[1], " " => "_"))
                push!(current_scene_main.scene.entities, entity)
                @info "Added entity with sprite: $(entity.name)"
            elseif file_type == :audio
                entity = create_entity_with_sound(relpath(filepath, JulGame.BasePath), replace(splitext(filename)[1], " " => "_"))
                push!(current_scene_main.scene.entities, entity)
                @info "Added entity with sound: $(entity.name)"
            end
        catch e
            @error "Failed to add file to scene: $e"
        end
    end
    
    CImGui.Separator()
    
    # Standard file operations
    if CImGui.MenuItem("Rename")
        # TODO: Implement rename dialog
    end
    
    if CImGui.MenuItem("Delete")
        # TODO: Implement delete confirmation
    end
    
    if CImGui.MenuItem("Copy Path")
        # TODO: Implement clipboard copy
    end
    
    CImGui.Separator()
    
    if CImGui.MenuItem("Show in System Explorer")
        # TODO: Implement system file explorer opening
    end
end

"""
    Drag and drop handling for the file list area
"""
function handle_file_list_drag_drop()
    # Handle drops onto the file list (for moving files)
    if CImGui.BeginDragDropTarget()
        payload_ptr = CImGui.AcceptDragDropPayload("FILE_PATH")
        if payload_ptr != C_NULL
            payload = unsafe_load(payload_ptr)
            source_path_bytes = unsafe_wrap(Array{UInt8}, convert(Ptr{UInt8}, payload.Data), payload.DataSize)
            source_path = String(source_path_bytes)
            
            explorer = JulGame.EditorState["file_explorer"]
            target_folder_path = explorer.current_path
            
            # Perform the move operation
            try
                dest_path = joinpath(target_folder_path, basename(source_path))
                @info "Moving '$source_path' to '$dest_path'"
                mv(source_path, dest_path; force=false)  # Don't force overwrite
                
                # Update selection
                empty!(explorer.selected_items)
                push!(explorer.selected_items, dest_path)
            catch e
                @error "Error moving item: $e"
                # TODO: Show error dialog
            end
        end
        CImGui.EndDragDropTarget()
    end
end

"""
    Metadata panel for selected items
"""
function show_metadata_panel()
    explorer = JulGame.EditorState["file_explorer"]
    
    if isempty(explorer.selected_items)
        CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "No item selected")
        return
    end
    
    # Show metadata for the first selected item
    filepath = first(explorer.selected_items)
    filename = basename(filepath)
    file_type = get_file_type(filepath)
    
    CImGui.Text("Selected Item")
    CImGui.Separator()
    
    # Basic file information
    CImGui.Text("Name: $filename")
    CImGui.Text("Type: $(string(file_type))")
    
    if isfile(filepath)
        stat_info = stat(filepath)
        CImGui.Text("Size: $(format_file_size(stat_info.size))")
        CImGui.Text("Modified: $(Dates.format(unix2datetime(stat_info.mtime), "yyyy-mm-dd HH:MM:SS"))")
    end
    
    CImGui.Separator()
    
    # File-type specific metadata
    if file_type == :image && isfile(filepath)
        show_image_metadata(filepath)
    elseif file_type == :audio && isfile(filepath)
        show_audio_metadata(filepath)
    end
    
    # Multiple selection info
    if length(explorer.selected_items) > 1
        CImGui.Separator()
        CImGui.Text("$(length(explorer.selected_items)) items selected")
        
        total_size = sum(isfile(f) ? filesize(f) : 0 for f in explorer.selected_items)
        CImGui.Text("Total size: $(format_file_size(total_size))")
    end
end

"""
    Image metadata display
"""
function show_image_metadata(filepath::String)
    try
        # Basic image info (would need image processing library for full metadata)
        CImGui.Text("Image Properties:")
        CImGui.Text("Format: $(uppercase(splitext(filepath)[2][2:end]))")
        # TODO: Add width, height, color depth, etc.
    catch e
        @debug "Error reading image metadata: $e"
    end
end

"""
    Audio metadata display
"""
function show_audio_metadata(filepath::String)
    try
        # Basic audio info
        CImGui.Text("Audio Properties:")
        CImGui.Text("Format: $(uppercase(splitext(filepath)[2][2:end]))")
        # TODO: Add duration, bitrate, channels, etc.
    catch e
        @debug "Error reading audio metadata: $e"
    end
end

"""
    Options popup for explorer settings
"""
function show_options_popup()
    if CImGui.BeginPopup("Explorer Options")
        explorer = JulGame.EditorState["file_explorer"]
        
        CImGui.Text("Display Options")
        CImGui.Separator()
        
        # Show hidden files
        if CImGui.Checkbox("Show Hidden Files", Ref(explorer.show_hidden_files))
            explorer.show_hidden_files = !explorer.show_hidden_files
        end
        
        # Preview size slider
        CImGui.Text("Preview Size:")
        preview_size = Ref(explorer.preview_size)
        if CImGui.SliderFloat("##preview_size", preview_size, 32.0, 128.0, "%.0f")
            explorer.preview_size = preview_size[]
        end
        
        CImGui.Separator()
        
        # Import integration
        if CImGui.Checkbox("Auto-import on drop", Ref(explorer.auto_import_on_drop))
            explorer.auto_import_on_drop = !explorer.auto_import_on_drop
        end
        
        CImGui.EndPopup()
    end
end

"""
    Utility functions
"""
function format_file_size(size_bytes::Int64)::String
    units = ["B", "KB", "MB", "GB", "TB"]
    size = Float64(size_bytes)
    unit_index = 1
    
    while size >= 1024.0 && unit_index < length(units)
        size /= 1024.0
        unit_index += 1
    end
    
    if unit_index == 1
        return "$(Int(size)) $(units[unit_index])"
    else
        return "$(round(size, digits=1)) $(units[unit_index])"
    end
end

# Export main UI function
export show_file_explorer_window
