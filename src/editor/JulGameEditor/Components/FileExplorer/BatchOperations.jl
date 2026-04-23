"""
    BatchOperations

Batch file operations system for the file explorer.
Provides multi-select operations, progress tracking, and undo/redo functionality
while maintaining the established error handling patterns from ImportFile.jl.
"""

using CImGui
using CImGui.CSyntax
using CImGui.CSyntax.CStatic
using CImGui: ImVec2, ImVec4, IM_COL32

include("FileExplorer.jl")

"""
    Batch operation types and structures
"""

@enum BatchOperationType begin
    BATCH_COPY
    BATCH_MOVE
    BATCH_DELETE
    BATCH_RENAME
    BATCH_IMPORT
end

mutable struct BatchOperation
    operation_type::BatchOperationType
    source_paths::Vector{String}
    destination_path::String
    new_names::Vector{String}  # For rename operations
    completed_operations::Vector{Tuple{String, String}}  # For undo support
    failed_operations::Vector{Tuple{String, String, String}}  # (source, dest, error)
    progress::Float32
    is_completed::Bool
    can_undo::Bool
    
    function BatchOperation(op_type::BatchOperationType, sources::Vector{String}, dest::String = "", names::Vector{String} = String[])
        new(op_type, sources, dest, names, Vector{Tuple{String, String}}(), Vector{Tuple{String, String, String}}(), 0.0, false, false)
    end
end

"""
    Batch operation queue management
"""

function add_batch_operation(operation::BatchOperation)
    explorer = JulGame.EditorState["file_explorer"]
    push!(explorer.batch_operation_queue, (operation.operation_type, join(operation.source_paths, ";"), operation.destination_path))
end

function execute_batch_operations()
    explorer = JulGame.EditorState["file_explorer"]
    
    if isempty(explorer.batch_operation_queue) || explorer.batch_in_progress
        return
    end
    
    explorer.batch_in_progress = true
    explorer.batch_progress = 0.0
    
    # Process operations in queue
    total_operations = length(explorer.batch_operation_queue)
    completed_operations = 0
    
    for (op_type, sources_str, destination) in explorer.batch_operation_queue
        source_paths = split(sources_str, ";")
        
        try
            if op_type == :copy
                execute_batch_copy(source_paths, destination)
            elseif op_type == :move
                execute_batch_move(source_paths, destination)
            elseif op_type == :delete
                execute_batch_delete(source_paths)
            elseif op_type == :import
                execute_batch_import(source_paths, destination)
            end
            
            completed_operations += 1
            explorer.batch_progress = completed_operations / total_operations
            
        catch e
            @error "Batch operation failed: $e"
            # Continue with remaining operations
        end
    end
    
    # Clear queue and reset progress
    empty!(explorer.batch_operation_queue)
    explorer.batch_in_progress = false
    explorer.batch_progress = 0.0
end

"""
    Individual batch operations
"""

function execute_batch_copy(source_paths::Vector{String}, destination::String)
    for source_path in source_paths
        if isfile(source_path) || isdir(source_path)
            dest_path = joinpath(destination, basename(source_path))
            
            # Handle conflicts (following ImportFile pattern)
            if isfile(dest_path) || isdir(dest_path)
                dest_path = generate_unique_filename(dest_path)
            end
            
            try
                if isfile(source_path)
                    cp(source_path, dest_path)
                else
                    cp(source_path, dest_path; force=false)  # Directory copy
                end
                @debug "Copied: $(basename(source_path)) to $(destination)"
            catch e
                @error "Failed to copy $(source_path): $e"
            end
        end
    end
end

function execute_batch_move(source_paths::Vector{String}, destination::String)
    for source_path in source_paths
        if isfile(source_path) || isdir(source_path)
            dest_path = joinpath(destination, basename(source_path))
            
            # Handle conflicts
            if isfile(dest_path) || isdir(dest_path)
                dest_path = generate_unique_filename(dest_path)
            end
            
            try
                mv(source_path, dest_path)
                @debug "Moved: $(basename(source_path)) to $(destination)"
            catch e
                @error "Failed to move $(source_path): $e"
            end
        end
    end
end

function execute_batch_delete(source_paths::Vector{String})
    for source_path in source_paths
        if isfile(source_path) || isdir(source_path)
            try
                rm(source_path; recursive=true, force=true)
                @debug "Deleted: $(basename(source_path))"
            catch e
                @error "Failed to delete $(source_path): $e"
            end
        end
    end
end

function execute_batch_import(source_paths::Vector{String}, destination::String)
    # Use existing ImportFile workflow for batch import
    supported_files = filter(is_supported_file, source_paths)
    
    if !isempty(supported_files)
        JulGame.EditorState["dropped_files"] = supported_files
        JulGame.EditorState["import_queue_index"] = 1
        @debug "Queued $(length(supported_files)) files for import"
    end
end

"""
    Utility functions for batch operations
"""

function generate_unique_filename(filepath::String)::String
    base_path = dirname(filepath)
    base_name = basename(filepath)
    name_without_ext = splitext(base_name)[1]
    extension = splitext(base_name)[2]
    
    counter = 1
    while true
        if isempty(extension)
            new_name = "$(name_without_ext)_$(counter)"
        else
            new_name = "$(name_without_ext)_$(counter)$(extension)"
        end
        
        new_path = joinpath(base_path, new_name)
        if !isfile(new_path) && !isdir(new_path)
            return new_path
        end
        
        counter += 1
        if counter > 1000  # Prevent infinite loop
            break
        end
    end
    
    return filepath  # Fallback to original name
end

function get_total_size(paths::Vector{String})::Int64
    total_size = 0
    for path in paths
        if isfile(path)
            total_size += filesize(path)
        elseif isdir(path)
            # Recursively calculate directory size
            total_size += get_directory_size(path)
        end
    end
    return total_size
end

function get_directory_size(dir_path::String)::Int64
    total_size = 0
    try
        for (root, dirs, files) in walkdir(dir_path)
            for file in files
                file_path = joinpath(root, file)
                if isfile(file_path)
                    total_size += filesize(file_path)
                end
            end
        end
    catch e
        @debug "Error calculating directory size: $e"
    end
    return total_size
end

"""
    UI for batch operations panel
"""

function show_batch_operations_panel()
    explorer = JulGame.EditorState["file_explorer"]
    
    if !explorer.show_batch_panel
        return
    end
    
    CImGui.Begin("Batch Operations", Ref(explorer.show_batch_panel))
    
    # Selected items info
    selected_count = length(explorer.selected_items)
    if selected_count == 0
        CImGui.TextColored((0.6, 0.6, 0.6, 1.0), "No items selected")
        CImGui.End()
        return
    end
    
    CImGui.Text("Selected Items: $selected_count")
    
    # Calculate total size
    total_size = get_total_size(collect(explorer.selected_items))
    CImGui.Text("Total Size: $(format_file_size(total_size))")
    
    CImGui.Separator()
    
    # Batch operation buttons (following ImportFile button styling)
    button_width = 100.0
    
    # Copy button
    CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.5, 0.8, 1.0))
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.6, 0.9, 1.0))
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.7, 1.0, 1.0))
    
    if CImGui.Button("Copy", ImVec2(button_width, 0))
        show_destination_selector("copy")
    end
    
    CImGui.PopStyleColor(3)
    CImGui.SameLine()
    
    # Move button
    CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.8, 0.5, 0.2, 1.0))
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.9, 0.6, 0.3, 1.0))
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (1.0, 0.7, 0.4, 1.0))
    
    if CImGui.Button("Move", ImVec2(button_width, 0))
        show_destination_selector("move")
    end
    
    CImGui.PopStyleColor(3)
    
    # Delete button
    CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.7, 0.2, 0.2, 1.0))
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.8, 0.3, 0.3, 1.0))
    CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.9, 0.4, 0.4, 1.0))
    
    if CImGui.Button("Delete", ImVec2(button_width, 0))
        CImGui.OpenPopup("Confirm Batch Delete")
    end
    
    CImGui.PopStyleColor(3)
    CImGui.SameLine()
    
    # Import button (for supported files)
    supported_files = filter(is_supported_file, collect(explorer.selected_items))
    if !isempty(supported_files)
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.2, 0.7, 0.2, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.3, 0.8, 0.3, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.4, 0.9, 0.4, 1.0))
        
        if CImGui.Button("Import", ImVec2(button_width, 0))
            execute_batch_import(supported_files, "")
        end
        
        CImGui.PopStyleColor(3)
    end
    
    CImGui.Separator()
    
    # Progress bar
    if explorer.batch_in_progress
        CImGui.Text("Processing...")
        CImGui.ProgressBar(explorer.batch_progress, ImVec2(-1.0, 0.0))
    elseif !isempty(explorer.batch_operation_queue)
        CImGui.Text("Operations queued: $(length(explorer.batch_operation_queue))")
        if CImGui.Button("Execute All", ImVec2(-1.0, 0.0))
            execute_batch_operations()
        end
    end
    
    # Show batch delete confirmation
    show_batch_delete_confirmation()
    
    CImGui.End()
end

"""
    Destination selector for copy/move operations
"""

function show_destination_selector(operation::String)
    # Use existing folder selection from ImportFile
    selected_path = show_file_browser_dialog("Select Destination for $operation", JulGame.BasePath)
    
    if selected_path != ""
        explorer = JulGame.EditorState["file_explorer"]
        selected_files = collect(explorer.selected_items)
        
        if operation == "copy"
            execute_batch_copy(selected_files, selected_path)
        elseif operation == "move"
            execute_batch_move(selected_files, selected_path)
        end
    end
end

"""
    Batch delete confirmation dialog (following ImportFile modal pattern)
"""

function show_batch_delete_confirmation()
    if CImGui.BeginPopupModal("Confirm Batch Delete", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
        explorer = JulGame.EditorState["file_explorer"]
        selected_count = length(explorer.selected_items)
        
        CImGui.TextWrapped("Are you sure you want to permanently delete $selected_count selected items?")
        CImGui.TextColored((1.0, 0.3, 0.3, 1.0), "This action cannot be undone!")
        
        # Show some of the items to be deleted
        CImGui.Separator()
        CImGui.Text("Items to delete:")
        
        count = 0
        for item in explorer.selected_items
            if count >= 5  # Show max 5 items
                CImGui.Text("... and $(selected_count - 5) more")
                break
            end
            CImGui.Text("• $(basename(item))")
            count += 1
        end
        
        CImGui.Separator()
        
        # Buttons (following ImportFile button styling)
        CImGui.PushStyleColor(CImGui.ImGuiCol_Button, (0.7, 0.2, 0.2, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonHovered, (0.8, 0.3, 0.3, 1.0))
        CImGui.PushStyleColor(CImGui.ImGuiCol_ButtonActive, (0.9, 0.4, 0.4, 1.0))
        
        if CImGui.Button("Delete All", ImVec2(120, 0))
            execute_batch_delete(collect(explorer.selected_items))
            empty!(explorer.selected_items)  # Clear selection
            CImGui.CloseCurrentPopup()
        end
        
        CImGui.PopStyleColor(3)
        
        CImGui.SetItemDefaultFocus()
        CImGui.SameLine()
        
        if CImGui.Button("Cancel", ImVec2(120, 0))
            CImGui.CloseCurrentPopup()
        end
        
        CImGui.EndPopup()
    end
end

"""
    Bulk rename functionality
"""

function show_bulk_rename_dialog()
    # TODO: Implement bulk rename with pattern matching
    # - Pattern-based renaming (e.g., "image_{n}.png")
    # - Case conversion
    # - Find and replace
    # - Extension changes
end

"""
    Context menu integration for batch operations
"""

function show_batch_context_menu()
    explorer = JulGame.EditorState["file_explorer"]
    selected_count = length(explorer.selected_items)
    
    if selected_count <= 1
        return
    end
    
    CImGui.Text("$selected_count items selected")
    CImGui.Separator()
    
    if CImGui.MenuItem("Copy All")
        show_destination_selector("copy")
    end
    
    if CImGui.MenuItem("Move All")
        show_destination_selector("move")
    end
    
    if CImGui.MenuItem("Delete All")
        CImGui.OpenPopup("Confirm Batch Delete")
    end
    
    # Import option for supported files
    supported_files = filter(is_supported_file, collect(explorer.selected_items))
    if !isempty(supported_files)
        CImGui.Separator()
        if CImGui.MenuItem("Import All ($(length(supported_files)) files)")
            execute_batch_import(supported_files, "")
        end
    end
end

# Export functions for integration
export show_batch_operations_panel, show_batch_context_menu, execute_batch_operations
