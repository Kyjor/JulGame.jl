# src/editor/JulGameEditor/Windows/FileExplorerWindow.jl
module FileExplorerWindow

using CImGui
using CImGui.CSyntax
using JulGame
using NativeFileDialog

# State variables for the file explorer
const current_path = Ref("")
const selected_item_path = Ref("")
const rename_buffer = Ref("")
const show_rename_popup = Ref(false)
const show_new_folder_popup = Ref(false)
const new_folder_name_buffer = Ref("")
const show_delete_confirmation = Ref(false)
const item_to_delete = Ref("")

# Function to get a display name for the path
function get_display_name(path::String)
    # Simple basename for now
    return basename(path)
end

# Function to show the main file explorer window
function show_window(show_file_explorer::Ref{Bool})
    if !show_file_explorer[]
        return
    end

    # Initialize current_path if it's empty and BasePath is set
    if current_path[] == "" && JulGame.BasePath != ""
        current_path[] = abspath(JulGame.BasePath)
    elseif JulGame.BasePath == "" # Don't show if no project is loaded
         CImGui.Begin("File Explorer", show_file_explorer)
         CImGui.Text("No project loaded. Please select a project.")
         CImGui.End()
         return
    end

    # Ensure current_path is always absolute
    # This helps prevent issues with relative paths
    if !isabspath(current_path[]) && JulGame.BasePath != ""
        current_path[] = abspath(joinpath(JulGame.BasePath, current_path[]))
    end

    # Define the upper boundary (one level above BasePath)
    # Handle potential edge cases where BasePath might be the root
    base_path_abs = abspath(JulGame.BasePath)
    parent_of_base = dirname(base_path_abs)
    boundary_path = parent_of_base == base_path_abs ? base_path_abs : parent_of_base # Avoid going above root if BasePath is root itself


    CImGui.SetNextWindowSize((400, 400), CImGui.ImGuiCond_FirstUseEver)
    if CImGui.Begin("File Explorer", show_file_explorer)
        # --- Navigation ---
        # Display current path
        CImGui.Text("Current Path: $(current_path[])")
        CImGui.Separator()

        # "Up" button - prevent going above the boundary
        current_path_abs = abspath(current_path[])
        parent_path = dirname(current_path_abs)

        can_go_up = current_path_abs != base_path_abs && current_path_abs != boundary_path && startswith(current_path_abs, boundary_path)

        if !can_go_up
            CImGui.PushStyleVar(CImGui.ImGuiStyleVar_Alpha, unsafe_load(CImGui.GetStyle().Alpha) * 0.5)
            CImGui.Button(".. (Up)") # Disabled look
            CImGui.PopStyleVar()
        else
            if CImGui.Button(".. (Up)")
                current_path[] = parent_path
                selected_item_path[] = "" # Clear selection when navigating
            end
        end
        CImGui.SameLine()

        # "New Folder" button
        if CImGui.Button("+ New Folder")
             show_new_folder_popup[] = true
             new_folder_name_buffer[] = "" # Clear buffer
             CImGui.OpenPopup("Create New Folder")
        end

        CImGui.Separator()

        # --- File/Folder Listing ---
        items = []
        try
            items = readdir(current_path[])
        catch e
            CImGui.TextColored((1.0, 0.0, 0.0, 1.0), "Error reading directory: $e")
            # Potentially reset path or show error message
            # For now, just display error and stop listing
            if !isdir(current_path[]) && current_path[] != base_path_abs
                 current_path[] = base_path_abs # Go back to base path if current is invalid
            elseif !isdir(current_path[]) && current_path[] == base_path_abs && JulGame.BasePath != ""
                 # If BasePath itself became invalid, maybe prompt user?
                 # For now, just stay put and show error.
            end
             items = [] # Ensure items is empty on error
        end

        CImGui.BeginChild("FileList", CImGui.ImVec2(0, -CImGui.GetFrameHeightWithSpacing()), true) # Scrollable region

        # Directories first
        for item in items
            full_path = joinpath(current_path[], item)
            if isdir(full_path)
                 # Prepend folder icon/indicator
                display_text = "[D] $(item)"
                if CImGui.Selectable(display_text, selected_item_path[] == full_path)
                    # Single click selects, double click navigates (or just single click navigates for now)
                    current_path[] = full_path
                    selected_item_path[] = "" # Clear selection after navigation
                    break # Exit loop because directory changed
                end
                 # Right-click context menu for folders
                 if CImGui.BeginPopupContextItem(item) # Use item name as ID for context menu
                     selected_item_path[] = full_path # Ensure item is selected on right click
                     CImGui.Text("Folder: $item")
                     CImGui.Separator()
                     if CImGui.MenuItem("Rename")
                          show_rename_popup[] = true
                          rename_buffer[] = item # Pre-fill with current name
                          CImGui.OpenPopup("Rename Item")
                     end
                     if CImGui.MenuItem("Delete")
                          item_to_delete[] = full_path
                          show_delete_confirmation[] = true
                          CImGui.OpenPopup("Delete Confirmation")
                     end
                     # TODO: Add 'Copy' if needed
                     CImGui.EndPopup()
                 end

                 # Drag and Drop Target (Folders)
                 if CImGui.BeginDragDropTarget()
                     payload_ptr = CImGui.AcceptDragDropPayload("FILE_PATH")
                     if payload_ptr != C_NULL
                         payload = unsafe_load(payload_ptr)
                         source_path_bytes = unsafe_wrap(Array{UInt8}, convert(Ptr{UInt8}, payload.Data), payload.DataSize)
                         source_path = String(source_path_bytes)
                         target_folder_path = full_path

                         # Perform the move operation
                         try
                             dest_path = joinpath(target_folder_path, basename(source_path))
                             @debug "Moving '$source_path' to '$dest_path'"
                             mv(source_path, dest_path; force=true) # Use force to overwrite if needed? Be careful.
                             # Maybe add confirmation for overwrite?
                             selected_item_path[] = "" # Clear selection after move
                         catch e
                             @error "Error moving item: $e"
                             # Show error popup?
                         end
                     end
                     CImGui.EndDragDropTarget()
                 end
            end
        end

        # Then files
        for item in items
             full_path = joinpath(current_path[], item)
            if isfile(full_path)
                 # Prepend file icon/indicator
                 display_text = "[F] $(item)"
                 if CImGui.Selectable(display_text, selected_item_path[] == full_path)
                      selected_item_path[] = full_path
                     # Potentially handle double-click to open/edit?
                 end

                 # Right-click context menu for files
                 if CImGui.BeginPopupContextItem(item) # Use item name as ID
                     selected_item_path[] = full_path # Ensure item is selected
                     CImGui.Text("File: $item")
                     CImGui.Separator()
                     if CImGui.MenuItem("Rename")
                          show_rename_popup[] = true
                          rename_buffer[] = item # Pre-fill with current name
                          CImGui.OpenPopup("Rename Item")
                     end
                     if CImGui.MenuItem("Delete")
                          item_to_delete[] = full_path
                          show_delete_confirmation[] = true
                          CImGui.OpenPopup("Delete Confirmation")
                     end
                     # TODO: Add 'Copy' if needed
                     CImGui.EndPopup()
                 end

                 # Drag and Drop Source (Files)
                 if CImGui.BeginDragDropSource()
                     # Set payload to the file path
                     payload_bytes = Vector{UInt8}(full_path) # Convert string to bytes
                     payload_ptr = pointer(payload_bytes)
                     payload_size = length(payload_bytes)

                     CImGui.SetDragDropPayload("FILE_PATH", payload_ptr, payload_size)

                     # Display tooltip while dragging
                     CImGui.Text("Moving: $item")
                     CImGui.EndDragDropSource()
                 end
            end
        end

        CImGui.EndChild() # End FileList

         # --- Popups ---
         handle_popups()

    end
    CImGui.End() # End File Explorer window
end


# Helper function to handle popups
function handle_popups()
    # Rename Popup
    if show_rename_popup[]
        CImGui.SetNextWindowSize((300, 100))
        if CImGui.BeginPopupModal("Rename Item", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            CImGui.Text("Enter new name for '$(basename(selected_item_path[]))':")
            CImGui.InputText("##RenameInput", rename_buffer)
            CImGui.Separator()

            if CImGui.Button("Rename")
                new_name = rename_buffer[]
                if !isempty(new_name) && new_name != basename(selected_item_path[])
                    try
                        old_path = selected_item_path[]
                        new_path = joinpath(dirname(old_path), new_name)
                        mv(old_path, new_path)
                        @debug "Renamed '$old_path' to '$new_path'"
                        selected_item_path[] = new_path # Update selection to new path
                    catch e
                        @error "Error renaming item: $e"
                        # Show error popup?
                    end
                end
                show_rename_popup[] = false
                CImGui.CloseCurrentPopup()
            end

            CImGui.SameLine()
            if CImGui.Button("Cancel")
                show_rename_popup[] = false
                CImGui.CloseCurrentPopup()
            end
            CImGui.EndPopup()
        else
            # If the popup wasn't opened (e.g., closed implicitly), reset the flag
            show_rename_popup[] = false
        end
    end

    # New Folder Popup
    if show_new_folder_popup[]
        CImGui.SetNextWindowSize((300, 100))
        if CImGui.BeginPopupModal("Create New Folder", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            CImGui.Text("Enter name for the new folder:")
            CImGui.InputText("##NewFolderInput", new_folder_name_buffer)
            CImGui.Separator()

            if CImGui.Button("Create")
                folder_name = new_folder_name_buffer[]
                if !isempty(folder_name)
                    try
                        new_folder_path = joinpath(current_path[], folder_name)
                        if !exists(new_folder_path)
                             mkdir(new_folder_path)
                             @debug "Created folder: $new_folder_path"
                        else
                            @warn "Folder '$folder_name' already exists."
                            # Show warning popup?
                        end
                    catch e
                        @error "Error creating folder: $e"
                        # Show error popup?
                    end
                end
                show_new_folder_popup[] = false
                CImGui.CloseCurrentPopup()
            end

            CImGui.SameLine()
            if CImGui.Button("Cancel")
                show_new_folder_popup[] = false
                CImGui.CloseCurrentPopup()
            end
            CImGui.EndPopup()
        else
             show_new_folder_popup[] = false
        end
    end

    # Delete Confirmation Popup
    if show_delete_confirmation[]
        CImGui.SetNextWindowSize((350, 120))
        if CImGui.BeginPopupModal("Delete Confirmation", C_NULL, CImGui.ImGuiWindowFlags_AlwaysAutoResize)
            item_name = basename(item_to_delete[])
            item_type = isdir(item_to_delete[]) ? "folder" : "file"
            CImGui.TextWrapped("Are you sure you want to permanently delete the $item_type '$item_name'?")
            CImGui.TextColored((1.0, 0.5, 0.5, 1.0), "This action cannot be undone!")
            CImGui.Separator()

            if CImGui.Button("Delete", (120, 0))
                try
                    path_to_delete = item_to_delete[]
                    rm(path_to_delete; recursive=true, force=true) # Use recursive for folders, force for potential issues
                    @debug "Deleted: $path_to_delete"
                    # Clear selection if the deleted item was selected
                    if selected_item_path[] == path_to_delete
                        selected_item_path[] = ""
                    end
                catch e
                    @error "Error deleting item: $e"
                    # Show error popup?
                end
                item_to_delete[] = ""
                show_delete_confirmation[] = false
                CImGui.CloseCurrentPopup()
            end

            CImGui.SetItemDefaultFocus()
            CImGui.SameLine()
            if CImGui.Button("Cancel", (120, 0))
                item_to_delete[] = ""
                show_delete_confirmation[] = false
                CImGui.CloseCurrentPopup()
            end
            CImGui.EndPopup()
        else
             show_delete_confirmation[] = false
        end
    end
end


end # module FileExplorerWindow 